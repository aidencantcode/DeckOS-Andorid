// DeckOS
// See RomLibrary.h

#include "RomLibrary.h"

#include "Catalog.h"
#include "Log.h"
#include "Paths.h"
#include "utils/PathTools.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QTextStream>
#include <QtConcurrent/QtConcurrent>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QAndroidJniEnvironment>
#include <QtAndroidExtras/QAndroidJniObject>
#endif


namespace {
const QString LOGTAG = QStringLiteral("ROM folders");
constexpr int MAX_DEPTH = 4;

QString settings_path()
{
    return paths::writableConfigDir() + QStringLiteral("/deckos/rom_library.json");
}

// folders inside system folders that hold artwork etc., not games
bool is_skipped_dir(const QString& name)
{
    static const QSet<QString> names {
        QStringLiteral("media"), QStringLiteral("images"), QStringLiteral("imgs"), QStringLiteral("videos"),
        QStringLiteral("manuals"), QStringLiteral("snaps"), QStringLiteral("snap"), QStringLiteral("screenshots"),
        QStringLiteral("boxart"), QStringLiteral("covers"), QStringLiteral("wheel"), QStringLiteral("marquees"),
        QStringLiteral("titles"), QStringLiteral("downloaded_images"), QStringLiteral("downloaded_media"),
        QStringLiteral("bios"), QStringLiteral("saves"), QStringLiteral("states"), QStringLiteral("cheats"),
    };
    return name.startsWith(QLatin1Char('.')) || names.contains(name.toLower());
}

// DECKOS: a game folder holds one of the system's marker paths ("PS3_GAME/USRDIR/EBOOT.BIN"); SD cards
// ignore case, Android's own storage doesn't, so the usual spellings are tried
bool is_game_folder(const QString& dir, const QStringList& markers)
{
    for (const QString& marker : markers) {
        if (QFileInfo::exists(dir + QLatin1Char('/') + marker)
            || QFileInfo::exists(dir + QLatin1Char('/') + marker.toLower())
            || QFileInfo::exists(dir + QLatin1Char('/') + marker.toUpper()))
            return true;
    }
    return false;
}

void collect_files(const QString& dir, const QSet<QString>& extensions, int depth, QStringList& out,
                   deckos::ScanProgress* progress, const QStringList& markers = {}, QSet<QString>* folder_games = nullptr)
{
    if (progress && progress->cancel.load())
        return;
    const QFileInfoList entries = QDir(dir).entryInfoList(
        QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable, QDir::Name | QDir::IgnoreCase);
    for (const QFileInfo& entry : entries) {
        if (entry.isDir()) {
            if (!markers.isEmpty() && folder_games && is_game_folder(entry.absoluteFilePath(), markers)) {
                const QString path = ::clean_abs_path(entry);
                out << path;
                folder_games->insert(path);
                if (progress)
                    progress->files++;
                continue; // its insides are the game's own files
            }
            if (depth < MAX_DEPTH && !is_skipped_dir(entry.fileName()))
                collect_files(entry.absoluteFilePath(), extensions, depth + 1, out, progress, markers, folder_games);
            continue;
        }
        if (entry.fileName().startsWith(QLatin1Char('.')))
            continue;
        if (extensions.contains(entry.suffix().toLower())) {
            out << ::clean_abs_path(entry);
            if (progress)
                progress->files++;
        }
    }
}

// files listed by playlists / cue sheets are parts of another game, not games of their own
QSet<QString> referenced_files(const QStringList& files)
{
    static const QRegularExpression cue_file(QStringLiteral("^\\s*FILE\\s+\"?([^\"]+?)\"?\\s+\\w+\\s*$"),
                                             QRegularExpression::CaseInsensitiveOption);
    QSet<QString> hidden;
    for (const QString& path : files) {
        const QString suffix = QFileInfo(path).suffix().toLower();
        if (suffix != QLatin1String("m3u") && suffix != QLatin1String("cue") && suffix != QLatin1String("gdi"))
            continue;
        QFile file(path);
        if (file.size() > 1024 * 1024 || !file.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;
        const QDir base = QFileInfo(path).dir();
        QTextStream stream(&file);
        QString line;
        while (stream.readLineInto(&line)) {
            line = line.trimmed();
            if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
                continue;
            QString ref;
            if (suffix == QLatin1String("m3u")) {
                ref = line;
            } else if (suffix == QLatin1String("cue")) {
                const QRegularExpressionMatch m = cue_file.match(line);
                if (m.hasMatch())
                    ref = m.captured(1);
            } else { // gdi: "1 0 4 2352 track01.bin 0"
                const QStringList parts = line.split(QRegularExpression(QStringLiteral("\\s+")));
                if (parts.size() >= 5)
                    ref = parts.at(4);
            }
            if (!ref.isEmpty())
                hidden.insert(::clean_abs_path(QFileInfo(base, ref)));
        }
    }
    return hidden;
}

QString metadata_escape(QString value)
{
    // one line per value; Pegasus treats leading spaces as continuation lines
    value.replace(QLatin1Char('\n'), QLatin1Char(' '));
    return value.trimmed();
}
} // namespace


namespace deckos {

std::vector<ScannedSystem> scan_rom_folders(const QStringList& rom_roots, const QSet<QString>& only_systems)
{
    return scan_rom_folders(Catalog::instance(), rom_roots, only_systems);
}

std::vector<ScannedSystem> scan_rom_folders(const Catalog& catalog, const QStringList& rom_roots, const QSet<QString>& only_systems)
{
    return scan_rom_folders(catalog, rom_roots, only_systems, {});
}

std::vector<ScannedSystem> scan_rom_folders(const Catalog& catalog, const QStringList& rom_roots, const QSet<QString>& only_systems,
                                            const std::map<QString, QString>& links, ScanProgress* progress)
{

    // system id -> folders holding its games
    std::map<QString, QStringList> targets;
    auto add_target = [&](const CatalogSystem* sys, const QString& dir) {
        if (!sys)
            return;
        if (!only_systems.isEmpty() && !only_systems.contains(sys->id))
            return;
        QStringList& dirs = targets[sys->id];
        if (!dirs.contains(dir))
            dirs << dir;
    };

    for (const QString& root : rom_roots) {
        const QFileInfo root_info(root);
        if (!root_info.isDir())
            continue;
        // the picked folder may itself be a system folder (".../ROMs/snes")
        if (const CatalogSystem* sys = catalog.byFolderName(root_info.fileName())) {
            add_target(sys, ::clean_abs_path(root_info));
            continue;
        }
        const QFileInfoList subdirs = QDir(root).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable, QDir::Name);
        for (const QFileInfo& sub : subdirs)
            add_target(catalog.byFolderName(sub.fileName()), ::clean_abs_path(sub));
    }

    // DECKOS: a folder linked to a system (Settings > Collections) is its only folder
    for (const auto& link : links) {
        const CatalogSystem* sys = catalog.byId(link.first);
        if (!sys || link.second.isEmpty() || (!only_systems.isEmpty() && !only_systems.contains(sys->id)))
            continue;
        targets[sys->id] = QStringList { ::clean_abs_path(QFileInfo(link.second)) };
    }

    if (progress)
        progress->systemsTotal = static_cast<int>(targets.size());

    std::vector<ScannedSystem> out;
    for (const auto& target : targets) {
        const CatalogSystem* sys = catalog.byId(target.first);
        const QSet<QString> extensions(sys->extensions.cbegin(), sys->extensions.cend());
        if (progress) {
            if (progress->cancel.load())
                return {};
            QMutexLocker locker(&progress->lock);
            progress->currentSystem = sys->name;
        }

        ScannedSystem result;
        result.id = sys->id;
        result.folders = target.second;
        QStringList files;
        for (const QString& dir : target.second)
            collect_files(dir, extensions, 1, files, progress, sys->gameFolders, &result.folderGames);
        if (progress) {
            if (progress->cancel.load())
                return {};
            progress->systemsDone++;
        }

        const QSet<QString> hidden = referenced_files(files);
        for (const QString& file : files) {
            if (!hidden.contains(file))
                result.files << file;
        }
        result.files.removeDuplicates();
        result.files.sort(Qt::CaseInsensitive);
        out.push_back(std::move(result));
    }
    return out;
}

QStringList game_titles(const QStringList& files, const QSet<QString>& folder_games)
{
    static const QRegularExpression tags(QStringLiteral("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]"));
    static const QRegularExpression article(QStringLiteral("^(.+?), (The|A|An)( - |: |$)"));
    const auto base_name = [&folder_games](const QString& file) {
        return folder_games.contains(file) ? QFileInfo(file).fileName() : QFileInfo(file).completeBaseName();
    };

    QStringList titles;
    QHash<QString, int> counts;
    for (const QString& file : files) {
        QString title = base_name(file);
        title.remove(tags);
        title = title.trimmed();
        const QRegularExpressionMatch m = article.match(title);
        if (m.hasMatch())
            title = m.captured(2) + QLatin1Char(' ') + m.captured(1) + m.captured(3) + title.mid(m.capturedEnd());
        title = title.trimmed();
        if (title.isEmpty())
            title = base_name(file);
        titles << title;
        counts[title.toLower()]++;
    }
    // two files, same clean name (USA + Europe...): those keep their full names
    for (int i = 0; i < titles.size(); i++) {
        if (counts.value(titles.at(i).toLower()) > 1)
            titles[i] = base_name(files.at(i));
    }
    return titles;
}


RomLibrary::RomLibrary(QObject* parent)
    : QObject(parent)
{
    connect(&m_watcher, &QFutureWatcher<std::vector<ScannedSystem>>::finished, this, &RomLibrary::onScanDone);
    m_progress_timer.setInterval(120);
    connect(&m_progress_timer, &QTimer::timeout, this, &RomLibrary::pollProgress);
    load();
}

void RomLibrary::pollProgress()
{
    if (!m_scan_progress)
        return;
    ScanProgress& p = *m_scan_progress;
    const int total = p.systemsTotal.load();
    const qreal value = total > 0 ? qreal(p.systemsDone.load()) / total : 0.0;
    QString system;
    {
        QMutexLocker locker(&p.lock);
        system = p.currentSystem;
    }
    const int found = p.files.load();
    if (found == m_found && qFuzzyCompare(1.0 + value, 1.0 + m_progress_value) && system == m_scan_system)
        return;
    m_found = found;
    m_progress_value = value;
    m_scan_system = system;
    emit scanProgressChanged();
}

void RomLibrary::cancelScan()
{
    if (!m_scanning || !m_scan_progress)
        return;
    Log::info(LOGTAG, LOGMSG("Scan cancelled"));
    m_scan_progress->cancel = true;
    m_pending = false;
    m_pending_scope.clear();
    setStatus(tr("Cancelling…"));
}

RomLibrary::~RomLibrary()
{
    m_watcher.waitForFinished();
}

QString RomLibrary::libraryDir()
{
    return paths::writableConfigDir() + QStringLiteral("/deckos/library");
}

void RomLibrary::setStatus(const QString& text)
{
    m_status = text;
    emit scanStateChanged();
}


// --- settings ---------------------------------------------------------------------------------------

void RomLibrary::load()
{
    QFile file(settings_path());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    for (const QJsonValue& v : root.value(QStringLiteral("romFolders")).toArray())
        m_rom_folders << v.toString();
    m_scan_on_start = root.value(QStringLiteral("scanOnStart")).toBool(true);
    const QJsonObject systems = root.value(QStringLiteral("systems")).toObject();
    for (auto it = systems.begin(); it != systems.end(); ++it) {
        const QJsonObject obj = it.value().toObject();
        SystemState& st = m_systems[it.key()];
        st.emulator = obj.value(QStringLiteral("emulator")).toString();
        st.command = obj.value(QStringLiteral("command")).toString();
        st.games = obj.value(QStringLiteral("games")).toInt();
        st.link = obj.value(QStringLiteral("link")).toString();
        for (const QJsonValue& f : obj.value(QStringLiteral("folders")).toArray())
            st.folders << f.toString();
    }
}

void RomLibrary::save() const
{
    QJsonObject systems;
    for (const auto& entry : m_systems) {
        const SystemState& st = entry.second;
        QJsonObject obj;
        if (!st.emulator.isEmpty()) obj.insert(QStringLiteral("emulator"), st.emulator);
        if (!st.command.isEmpty()) obj.insert(QStringLiteral("command"), st.command);
        if (!st.link.isEmpty()) obj.insert(QStringLiteral("link"), st.link);
        obj.insert(QStringLiteral("games"), st.games);
        obj.insert(QStringLiteral("folders"), QJsonArray::fromStringList(st.folders));
        systems.insert(entry.first, obj);
    }
    const QJsonObject root {
        { QStringLiteral("romFolders"), QJsonArray::fromStringList(m_rom_folders) },
        { QStringLiteral("scanOnStart"), m_scan_on_start },
        { QStringLiteral("systems"), systems },
    };
    QDir().mkpath(QFileInfo(settings_path()).absolutePath());
    QSaveFile file(settings_path());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
        file.commit();
    }
}

void RomLibrary::setScanOnStart(bool val)
{
    if (m_scan_on_start == val)
        return;
    m_scan_on_start = val;
    save();
    emit settingsChanged();
}

void RomLibrary::addRomFolder(const QString& path)
{
    const QString clean = ::clean_abs_path(QFileInfo(path));
    if (clean.isEmpty() || m_rom_folders.contains(clean))
        return;
    m_rom_folders << clean;
    save();
    emit romFoldersChanged();
    scan();
}

void RomLibrary::removeRomFolder(const QString& path)
{
    if (!m_rom_folders.removeAll(path))
        return;
    save();
    emit romFoldersChanged();
    scan(); // drops the systems that were only in that folder
}


// --- emulators --------------------------------------------------------------------------------------

void RomLibrary::refreshInstalled()
{
#ifdef Q_OS_ANDROID
    m_installed.clear();
    QAndroidJniEnvironment jni_env;
    const auto list_raw = QAndroidJniObject::callStaticObjectMethod(
        "org/pegasus_frontend/android/MainActivity", "appList", "()[Lorg/pegasus_frontend/android/App;");
    const auto list = list_raw.object<jobjectArray>();
    if (!list)
        return;
    const jsize count = jni_env->GetArrayLength(list);
    for (jsize i = 0; i < count; i++) {
        const QAndroidJniObject app = jni_env->GetObjectArrayElement(list, i);
        m_installed.insert(app.callObjectMethod<jstring>("packageName").toString());
    }
#endif
}

QString RomLibrary::chosenEmulator(const CatalogSystem& sys) const
{
    const auto it = m_systems.find(sys.id);
    if (it != m_systems.cend() && !it->second.emulator.isEmpty() && sys.emulator(it->second.emulator))
        return it->second.emulator;

    // automatic: an installed default (RetroArch core marked default) > any installed > the default
    for (const CatalogEmulator& emu : sys.emulators)
        if (emu.isDefault && m_installed.contains(emu.package)) return emu.id;
    for (const CatalogEmulator& emu : sys.emulators)
        if (m_installed.contains(emu.package)) return emu.id;
    for (const CatalogEmulator& emu : sys.emulators)
        if (emu.isDefault) return emu.id;
    return sys.emulators.isEmpty() ? QString() : sys.emulators.first().id;
}

QString RomLibrary::commandFor(const CatalogSystem& sys) const
{
    const auto it = m_systems.find(sys.id);
    if (it != m_systems.cend() && !it->second.command.isEmpty())
        return it->second.command;
    const CatalogEmulator* emu = sys.emulator(chosenEmulator(sys));
    return emu ? launch_command(*emu) : QString();
}

QVariantList RomLibrary::emulatorsFor(const QString& system_id) const
{
    const CatalogSystem* sys = Catalog::instance().byId(system_id);
    if (!sys)
        return {};
    QVariantList installed;
    QVariantList others;
    for (const CatalogEmulator& emu : sys->emulators) {
        const bool is_installed = m_installed.contains(emu.package);
        const QVariantMap item {
            { QStringLiteral("id"), emu.id },
            { QStringLiteral("name"), emu.name },
            { QStringLiteral("installed"), is_installed },
            { QStringLiteral("isDefault"), emu.isDefault },
            { QStringLiteral("achievements"), emu.achievements },
        };
        (is_installed ? installed : others) << item;
    }
    return installed + others;
}

void RomLibrary::setEmulator(const QString& system_id, const QString& emulator_id)
{
    m_systems[system_id].emulator = emulator_id;
    save();
    emit systemsChanged();
    scan({ system_id }); // rewrites that system's file with the new command
}

void RomLibrary::setCustomCommand(const QString& system_id, const QString& command)
{
    m_systems[system_id].command = command.trimmed();
    save();
    emit systemsChanged();
    scan({ system_id });
}

QVariantList RomLibrary::systemsList() const
{
    const Catalog& catalog = Catalog::instance();
    QVariantList out;
    for (const auto& entry : m_systems) {
        const SystemState& st = entry.second;
        const CatalogSystem* sys = catalog.byId(entry.first);
        if (!sys || st.games == 0)
            continue;
        const CatalogEmulator* emu = sys->emulator(chosenEmulator(*sys));
        out << QVariantMap {
            { QStringLiteral("id"), sys->id },
            { QStringLiteral("name"), sys->name },
            { QStringLiteral("shortName"), sys->shortName },
            { QStringLiteral("games"), st.games },
            { QStringLiteral("folders"), st.folders },
            { QStringLiteral("emulatorId"), emu ? emu->id : QString() },
            { QStringLiteral("emulatorName"), emu ? emu->name : QString() },
            { QStringLiteral("installed"), emu && m_installed.contains(emu->package) },
            { QStringLiteral("automatic"), st.emulator.isEmpty() },
            { QStringLiteral("command"), commandFor(*sys) },
            { QStringLiteral("customCommand"), st.command },
            { QStringLiteral("link"), st.link },
        };
    }
    return out;
}


// --- scanning ---------------------------------------------------------------------------------------

void RomLibrary::scan(const QStringList& system_ids)
{
    startScan(system_ids, true);
}

void RomLibrary::scanInBackground()
{
    startScan({}, false);
}

void RomLibrary::startScan(const QStringList& system_ids, bool foreground)
{
    const QSet<QString> scope(system_ids.cbegin(), system_ids.cend());
    if (m_scanning) {
        // run again afterwards; an empty scope means everything
        if (scope.isEmpty() || (m_pending && m_pending_scope.isEmpty()))
            m_pending_scope.clear();
        else
            m_pending_scope.unite(scope);
        m_pending = true;
        m_pending_foreground = m_pending_foreground || foreground;
        if (foreground && !m_foreground) { // the user is waiting for it now: show the loading screen
            m_foreground = true;
            emit scanStateChanged();
        }
        return;
    }
    if (m_rom_folders.isEmpty() && m_systems.empty())
        return;

    refreshInstalled();
    m_running_scope = scope;
    m_scanning = true;
    m_foreground = foreground;
    m_found = 0;
    m_progress_value = 0.0;
    m_scan_system.clear();
    m_scan_progress = std::make_shared<ScanProgress>();
    m_progress_timer.start();
    emit scanProgressChanged();
    setStatus(scope.isEmpty() ? tr("Scanning your ROM folders…") : tr("Rescanning…"));

    const QStringList roots = m_rom_folders;
    std::map<QString, QString> links;
    for (const auto& entry : m_systems) {
        if (!entry.second.link.isEmpty())
            links.emplace(entry.first, entry.second.link);
    }
    std::shared_ptr<ScanProgress> progress = m_scan_progress;
    m_watcher.setFuture(QtConcurrent::run([roots, scope, links, progress]() {
        return scan_rom_folders(Catalog::instance(), roots, scope, links, progress.get());
    }));
}

QVariantList RomLibrary::installedEmulators()
{
    refreshInstalled();
    struct Found {
        QString name;
        QStringList systems;
    };
    std::map<QString, Found> by_package;
    for (const CatalogSystem& sys : Catalog::instance().systems()) {
        for (const CatalogEmulator& emu : sys.emulators) {
            if (!m_installed.contains(emu.package))
                continue;
            Found& found = by_package[emu.package];
            if (found.name.isEmpty())
                found.name = emu.retroArch ? QStringLiteral("RetroArch") : emu.name;
            if (!found.systems.contains(sys.name))
                found.systems << sys.name;
        }
    }
    QVariantList out;
    for (const auto& entry : by_package) {
        out << QVariantMap {
            { QStringLiteral("name"), entry.second.name },
            { QStringLiteral("package"), entry.first },
            { QStringLiteral("systems"), entry.second.systems },
        };
    }
    std::sort(out.begin(), out.end(), [](const QVariant& a, const QVariant& b) {
        return QString::localeAwareCompare(a.toMap().value(QStringLiteral("name")).toString(),
                                           b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    Log::info(LOGTAG, LOGMSG("%1 emulators installed").arg(out.size()));
    emit systemsChanged(); // "Not installed" marks may have changed too
    return out;
}

void RomLibrary::linkFolder(const QString& system_id, const QString& folder)
{
    if (!Catalog::instance().byId(system_id))
        return;
    SystemState& st = m_systems[system_id];
    const QString clean = folder.isEmpty() ? QString() : ::clean_abs_path(QFileInfo(folder));
    if (st.link == clean)
        return;
    st.link = clean;
    Log::info(LOGTAG, clean.isEmpty() ? LOGMSG("`%1` uses the folders found by name again").arg(system_id)
                                      : LOGMSG("`%1` linked to `%2`").arg(system_id, clean));
    save();
    emit systemsChanged();
    scan({ system_id });
}

bool RomLibrary::writeSystemFile(const CatalogSystem& sys, const ScannedSystem& scanned) const
{
    const QString path = libraryDir() + QLatin1Char('/') + sys.id + QStringLiteral(".metadata.pegasus.txt");

    if (scanned.files.isEmpty())
        return QFile::exists(path) && QFile::remove(path);

    QString text;
    QTextStream out(&text);
    out << "# Generated by DeckOS from your ROM folders - rewritten on every scan, do not edit.\n"
        << "# Change the emulator or its command in DeckOS: Settings > Emulators.\n"
        << "collection: " << metadata_escape(sys.name) << '\n'
        << "shortname: " << sys.id << '\n';
    const QString command = commandFor(sys);
    if (!command.isEmpty())
        out << "launch: " << metadata_escape(command) << '\n';
    out << "x-deckos-emulator: " << chosenEmulator(sys) << '\n';
    if (sys.raConsoleId > 0)
        out << "x-ra-console: " << sys.raConsoleId << '\n';

    const QStringList titles = game_titles(scanned.files, scanned.folderGames);
    for (int i = 0; i < scanned.files.size(); i++) {
        out << '\n'
            << "game: " << metadata_escape(titles.at(i)) << '\n'
            << "file: " << scanned.files.at(i) << '\n';
    }
    out.flush();

    QFile current(path);
    if (current.open(QIODevice::ReadOnly) && QString::fromUtf8(current.readAll()) == text)
        return false; // unchanged: keep the file (and the game index cache) as it is
    current.close();

    QDir().mkpath(libraryDir());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(text.toUtf8()) < 0 || !file.commit()) {
        Log::warning(LOGTAG, LOGMSG("Could not write `%1`").arg(path));
        return false;
    }
    return true;
}

void RomLibrary::onScanDone()
{
    const Catalog& catalog = Catalog::instance();
    const std::vector<ScannedSystem> results = m_watcher.result();

    m_progress_timer.stop();
    pollProgress();
    const bool cancelled = m_scan_progress && m_scan_progress->cancel.load();
    m_scan_progress.reset();
    if (cancelled) { // nothing it found is used: every system file stays as it was
        m_scanning = false;
        m_foreground = false;
        m_pending = false;
        m_pending_foreground = false;
        m_pending_scope.clear();
        setStatus(tr("Scan cancelled - nothing was changed"));
        return;
    }

    QSet<QString> seen;
    int games = 0;
    int changed = 0;
    for (const ScannedSystem& result : results) {
        const CatalogSystem* sys = catalog.byId(result.id);
        if (!sys)
            continue;
        seen.insert(result.id);
        SystemState& st = m_systems[result.id];
        st.games = result.files.size();
        st.folders = result.folders;
        games += st.games;
        if (writeSystemFile(*sys, result))
            changed++;
    }

    // systems in scope that were not found any more (folder removed or emptied)
    for (auto& entry : m_systems) {
        if (seen.contains(entry.first))
            continue;
        if (!m_running_scope.isEmpty() && !m_running_scope.contains(entry.first))
            continue;
        entry.second.games = 0;
        entry.second.folders.clear();
        const CatalogSystem* sys = catalog.byId(entry.first);
        if (sys && writeSystemFile(*sys, ScannedSystem { entry.first, {}, {}, {} }))
            changed++;
    }

    save();
    m_scanning = false;
    const bool foreground = m_foreground;
    m_foreground = false;
    int total = 0;
    int system_count = 0;
    for (const auto& entry : m_systems) {
        total += entry.second.games;
        if (entry.second.games > 0)
            system_count++;
    }
    setStatus(tr("%1 games in %2 systems").arg(total).arg(system_count));
    Log::info(LOGTAG, LOGMSG("%1 games in %2 systems, %3 system files updated").arg(total).arg(system_count).arg(changed));
    emit systemsChanged();
    emit scanFinished(games, changed);

    if (m_pending) {
        m_pending = false;
        const QStringList scope(m_pending_scope.cbegin(), m_pending_scope.cend());
        m_pending_scope.clear();
        const bool next_foreground = m_pending_foreground || foreground;
        m_pending_foreground = false;
        startScan(scope, next_foreground);
    }
}

} // namespace deckos
