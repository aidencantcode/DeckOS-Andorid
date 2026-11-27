// DeckOS
// See Catalog.h

#include "Catalog.h"

#include "Log.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>

#include <algorithm>


namespace deckos {

const CatalogEmulator* CatalogSystem::emulator(const QString& emu_id) const
{
    for (const CatalogEmulator& emu : emulators) {
        if (emu.id == emu_id)
            return &emu;
    }
    return nullptr;
}

const Catalog& Catalog::instance()
{
    static const Catalog catalog = []() {
        Catalog c(QStringLiteral(":/deckos/catalog/systems.json"));
        c.merge(QStringLiteral(":/deckos/catalog/deckos-systems.json")); // DECKOS: our own additions
        return c;
    }();
    return catalog;
}

QString Catalog::normalized(const QString& text)
{
    QString out;
    for (const QChar ch : text.toLower()) {
        if (ch.isLetterOrNumber())
            out += ch;
    }
    return out;
}

Catalog::Catalog(const QString& json_path)
{
    QFile file(json_path);
    if (!file.open(QIODevice::ReadOnly)) {
        Log::warning(QStringLiteral("DeckOS"), LOGMSG("System catalog `%1` missing").arg(json_path));
        return;
    }
    const QJsonArray systems = QJsonDocument::fromJson(file.readAll()).object().value(QStringLiteral("systems")).toArray();
    m_systems.reserve(systems.size());
    for (const QJsonValue& sys_val : systems)
        addSystem(sys_val.toObject());
}

namespace {
CatalogEmulator read_emulator(const QJsonObject& e)
{
    CatalogEmulator emu;
    emu.id = e.value(QStringLiteral("id")).toString();
    emu.name = e.value(QStringLiteral("name")).toString();
    emu.package = e.value(QStringLiteral("package")).toString();
    emu.args = e.value(QStringLiteral("args")).toString();
    emu.isDefault = e.value(QStringLiteral("isDefault")).toBool();
    emu.retroArch = e.value(QStringLiteral("retroArch")).toBool();
    emu.achievements = e.value(QStringLiteral("achievements")).toBool();
    return emu;
}

void append_new(QStringList& list, const QJsonValue& values, bool lower)
{
    for (const QJsonValue& v : values.toArray()) {
        const QString s = lower ? v.toString().toLower() : v.toString();
        if (!s.isEmpty() && !list.contains(s))
            list << s;
    }
}
} // namespace

void Catalog::addSystem(const QJsonObject& obj)
{
    CatalogSystem sys;
    sys.id = obj.value(QStringLiteral("id")).toString();
    sys.name = obj.value(QStringLiteral("name")).toString();
    sys.shortName = obj.value(QStringLiteral("shortName")).toString();
    sys.multidisc = obj.value(QStringLiteral("multidisc")).toBool();
    sys.raConsoleId = obj.value(QStringLiteral("raConsoleId")).toInt();
    append_new(sys.folders, obj.value(QStringLiteral("folders")), false);
    append_new(sys.extensions, obj.value(QStringLiteral("extensions")), true);
    append_new(sys.gameFolders, obj.value(QStringLiteral("gameFolders")), false);
    for (const QJsonValue& emu_val : obj.value(QStringLiteral("emulators")).toArray())
        sys.emulators.append(read_emulator(emu_val.toObject()));
    if (sys.id.isEmpty())
        return;

    const int index = m_systems.size();
    m_by_id.insert(sys.id, index);
    // the id and the short name count as folder names too; the first system to claim a name keeps it
    QStringList names = sys.folders;
    names << sys.id << sys.shortName;
    for (const QString& name : names) {
        const QString key = normalized(name);
        if (!key.isEmpty() && !m_by_folder.contains(key))
            m_by_folder.insert(key, index);
    }
    m_systems.append(std::move(sys));
}

void Catalog::merge(const QString& json_path)
{
    QFile file(json_path);
    if (!file.open(QIODevice::ReadOnly)) {
        Log::warning(QStringLiteral("DeckOS"), LOGMSG("System catalog `%1` missing").arg(json_path));
        return;
    }
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &error);
    if (doc.isNull()) {
        Log::warning(QStringLiteral("DeckOS"), LOGMSG("System catalog `%1`: %2").arg(json_path, error.errorString()));
        return;
    }
    for (const QJsonValue& sys_val : doc.object().value(QStringLiteral("systems")).toArray()) {
        const QJsonObject obj = sys_val.toObject();
        const QString id = obj.value(QStringLiteral("id")).toString();
        const auto found = m_by_id.constFind(id);
        if (found == m_by_id.cend()) {
            addSystem(obj);
            continue;
        }
        const int index = found.value();
        CatalogSystem& sys = m_systems[index];
        if (obj.contains(QStringLiteral("name")))
            sys.name = obj.value(QStringLiteral("name")).toString();
        if (obj.contains(QStringLiteral("shortName")))
            sys.shortName = obj.value(QStringLiteral("shortName")).toString();
        if (obj.contains(QStringLiteral("raConsoleId")))
            sys.raConsoleId = obj.value(QStringLiteral("raConsoleId")).toInt();
        if (obj.contains(QStringLiteral("multidisc")))
            sys.multidisc = obj.value(QStringLiteral("multidisc")).toBool();
        append_new(sys.folders, obj.value(QStringLiteral("folders")), false);
        append_new(sys.extensions, obj.value(QStringLiteral("extensions")), true);
        append_new(sys.gameFolders, obj.value(QStringLiteral("gameFolders")), false);
        for (const QString& name : sys.folders) {
            const QString key = normalized(name);
            if (!key.isEmpty() && !m_by_folder.contains(key))
                m_by_folder.insert(key, index);
        }
        for (const QJsonValue& emu_val : obj.value(QStringLiteral("emulators")).toArray()) {
            const CatalogEmulator emu = read_emulator(emu_val.toObject());
            if (emu.id.isEmpty())
                continue;
            if (emu.isDefault) {
                for (CatalogEmulator& other : sys.emulators)
                    other.isDefault = false;
            }
            auto same = std::find_if(sys.emulators.begin(), sys.emulators.end(),
                                     [&emu](const CatalogEmulator& e) { return e.id == emu.id; });
            if (same != sys.emulators.end())
                *same = emu;
            else if (emu.isDefault)
                sys.emulators.prepend(emu);
            else
                sys.emulators.append(emu);
        }
    }
}

const CatalogSystem* Catalog::byId(const QString& id) const
{
    const auto it = m_by_id.constFind(id);
    return it == m_by_id.cend() ? nullptr : &m_systems.at(it.value());
}

const CatalogSystem* Catalog::byFolderName(const QString& folder_name) const
{
    const auto it = m_by_folder.constFind(normalized(folder_name));
    return it == m_by_folder.cend() ? nullptr : &m_systems.at(it.value());
}


QString launch_command(const CatalogEmulator& emu)
{
    QString args = emu.args;
    if (emu.retroArch && !emu.package.isEmpty()) {
        // --es LIBRETRO "snes9x" -> --es LIBRETRO "/data/data/<package>/cores/snes9x_libretro_android.so"
        static const QRegularExpression core(QStringLiteral("(--es\\s+LIBRETRO\\s+\")([^\"/][^\"]*)(\")"));
        const QRegularExpressionMatch m = core.match(args);
        if (m.hasMatch()) {
            QString name = m.captured(2);
            if (!name.endsWith(QLatin1String("_libretro_android.so")))
                name += QStringLiteral("_libretro_android.so");
            args.replace(m.capturedStart(2), m.capturedLength(2),
                         QStringLiteral("/data/data/") + emu.package + QStringLiteral("/cores/") + name);
        }
        // DECKOS: without CONFIGFILE, RetroArch starts from a blank default config - none of the user's
        // shaders, hotkeys, controller binds or paths. Its own launcher, ES-DE and Pegasus's metagen-android
        // (checked 2026-11-27) all pass the config RetroArch keeps in its app folder; almost every catalog
        // entry (NeoStation's) left it out.
        if (!args.contains(QLatin1String("CONFIGFILE"))) {
            args += QStringLiteral(" --es CONFIGFILE \"/storage/emulated/0/Android/data/") + emu.package
                  + QStringLiteral("/files/retroarch.cfg\"");
        }
    }
    // DECKOS: a few catalog entries lost the placeholder's opening brace ("file.path}")
    static const QRegularExpression broken_placeholder(QStringLiteral("(^|[^{])(file\\.(path|uri)\\})"));
    args.replace(broken_placeholder, QStringLiteral("\\1{\\2"));
    return QStringLiteral("am start ") + args;
}

} // namespace deckos
