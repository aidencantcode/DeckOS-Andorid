// DeckOS
// See MediaLibrary.h

#include "MediaLibrary.h"

#include "GameOverrides.h"
#include "Log.h"
#include "Paths.h"
#include "model/Api.h"
#include "model/gaming/Assets.h"
#include "model/gaming/Game.h"
#include "model/gaming/GameListModel.h"
#include "types/AssetType.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonObject>
#include <QMutex>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QtConcurrent/QtConcurrent>
#include <algorithm>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QAndroidJniEnvironment>
#include <QtAndroidExtras/QAndroidJniObject>
#include <QtAndroidExtras/QtAndroid>
#endif


namespace {
const QString LOGTAG = QStringLiteral("DeckOS");

QMutex s_lock;
QString s_folder; // the DeckOS folder, "" until one is picked

QString folder_file() { return paths::writableConfigDir() + QStringLiteral("/deckos/folder.txt"); }
QString keys_read_file() { return paths::writableConfigDir() + QStringLiteral("/deckos/keys-read.txt"); }

struct Row {
    const char* asset;
    const char* label;
    const char* hint;
};
// Customization's rows, in this order
const Row ROWS[] = {
    { "background", "Hero", "The wide picture at the top of the game page" },
    { "logo", "Logo", "Floats over the hero" },
    { "poster", "Capsule", "The portrait cover in Home and the Library" },
    { "steam", "Wide capsule", "Home's first, wide tile" },
    { "boxFront", "Box art", "Shown where there's no capsule" },
    { "icon", "Icon", "Home screen shortcuts" },
    { "video", "Trailer", "Plays behind the logo on the game page" },
    { "screenshot", "Screenshots", "The game page's Activity tab" },
};

bool is_row_asset(const QString& asset)
{
    for (const Row& row : ROWS)
        if (asset == QLatin1String(row.asset))
            return true;
    return false;
}

const QStringList& image_exts()
{
    static const QStringList exts { QStringLiteral("png"), QStringLiteral("jpg"), QStringLiteral("webp"),
                                    QStringLiteral("gif"), QStringLiteral("bmp") };
    return exts;
}
const QStringList& video_exts()
{
    static const QStringList exts { QStringLiteral("mp4"), QStringLiteral("webm"), QStringLiteral("mkv"),
                                    QStringLiteral("mov"), QStringLiteral("m4v"), QStringLiteral("3gp"),
                                    QStringLiteral("avi") };
    return exts;
}

AssetType type_of(const QString& asset)
{
    return static_cast<AssetType>(deckos::GameOverrides::assetType(asset));
}

/// a saved file as an asset URI. The same name as before (hero.png...): ?v= makes image caches load
/// the new file. Not for videos - a player may take the query for part of the file name.
QString uri_for(const QString& path, bool video)
{
    const QString uri = QUrl::fromLocalFile(path).toString();
    return video ? uri : uri + QStringLiteral("?v=") + QString::number(QDateTime::currentSecsSinceEpoch());
}

QString local_path(const QString& uri)
{
    return QUrl(uri).toLocalFile(); // the query is not part of it
}

bool move_file(const QString& from, const QString& to)
{
    if (QFileInfo(from).absoluteFilePath() == QFileInfo(to).absoluteFilePath())
        return true;
    QDir().mkpath(QFileInfo(to).absolutePath());
    QFile::remove(to);
    if (QFile::rename(from, to))
        return true;
    // another file system - or (Windows) the file is open, e.g. an animated cover on screen: the copy
    // is used, the old file stays behind
    if (!QFile::copy(from, to))
        return false;
    if (!QFile::remove(from))
        Log::warning(LOGTAG, LOGMSG("`%1` was copied, but the old file couldn't be deleted").arg(from));
    return true;
}

void remove_empty_dirs(const QString& root)
{
    QStringList dirs;
    QDirIterator it(root, QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext())
        dirs << it.next();
    std::sort(dirs.begin(), dirs.end(), [](const QString& a, const QString& b) { return a.size() > b.size(); });
    for (const QString& dir : dirs)
        QDir().rmdir(dir); // only empty ones go
    QDir().rmdir(root);
}

QString signature(const QString& path)
{
    const QFileInfo info(path);
    if (!info.isFile())
        return {};
    return QString::number(info.lastModified().toMSecsSinceEpoch()) + QLatin1Char(':') + QString::number(info.size());
}

bool write_text(const QString& path, const QByteArray& text)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(text) == text.size() && file.commit();
}

const char KEYS_TEMPLATE[] =
    "# DeckOS keys - one KEY=VALUE per line, nothing around the =. Lines starting with # are ignored.\n"
    "# DeckOS reads this file again whenever it changed (at start, or when you come back to it).\n"
    "# Keep it to yourself: it holds your accounts.\n"
    "\n"
    "# RetroAchievements: retroachievements.org > Settings > Keys (Web API Key)\n"
    "RA_USERNAME=\n"
    "RA_WEB_API_KEY=\n"
    "\n"
    "# SteamGridDB: steamgriddb.com > Preferences > API\n"
    "STEAMGRIDDB_API_KEY=\n"
    "\n"
    "# TheGamesDB: forums.thegamesdb.net (API key request)\n"
    "THEGAMESDB_API_KEY=\n";
} // namespace


namespace deckos {

MediaLibrary::MediaLibrary(model::ApiObject* api, QObject* parent)
    : QObject(parent)
    , m_api(api)
    , m_log_timer(new QTimer(this))
{
    QFile file(folder_file());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString path = QString::fromUtf8(file.readAll()).trimmed();
        if (!path.isEmpty() && QFileInfo(path).isDir()) {
            const QMutexLocker lock(&s_lock);
            s_folder = path;
        }
        else if (!path.isEmpty()) {
            Log::warning(LOGTAG, LOGMSG("The DeckOS folder `%1` is gone (a removed SD card?): pick it again").arg(path));
        }
    }
    if (folderSet())
        GameOverrides::setMediaDir(folder() + QStringLiteral("/media"));

    m_log_timer->setInterval(5 * 60 * 1000);
    connect(m_log_timer, &QTimer::timeout, this, &MediaLibrary::saveLog);
    m_log_timer->start();
    // Android can end DeckOS any time it's in the background: the log is copied before that
    connect(qApp, &QGuiApplication::applicationStateChanged, this, [this](Qt::ApplicationState state) {
        if (state != Qt::ApplicationActive)
            saveLog();
    });
}

MediaLibrary::~MediaLibrary()
{
    saveLog();
}

QString MediaLibrary::folder() const
{
    const QMutexLocker lock(&s_lock);
    return s_folder;
}

QString MediaLibrary::keysFilePath()
{
    const QMutexLocker lock(&s_lock);
    return s_folder.isEmpty() ? QString() : s_folder + QStringLiteral("/keys.txt");
}

QString MediaLibrary::defaultParent() const
{
#ifdef Q_OS_ANDROID
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation); // the shared storage
#else
    const QString parent = qEnvironmentVariable("DECKOS_FOLDER_PARENT"); // testing on PC
    return parent.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) : parent;
#endif
}

bool MediaLibrary::systemPicker() const
{
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
}


// --- the folder ------------------------------------------------------------------------------------

QString MediaLibrary::makeFolder(const QString& parent, const QString& name)
{
    const QString clean = GameOverrides::safeName(name.trimmed());
    if (parent.isEmpty() || clean.isEmpty() || clean == QLatin1String(".") || clean == QLatin1String(".."))
        return {};
    const QString path = QDir::cleanPath(QDir(parent).absoluteFilePath(clean));
    if (!QDir().mkpath(path)) {
        Log::warning(LOGTAG, LOGMSG("Could not create `%1`").arg(path));
        return {};
    }
    return path;
}

QString MediaLibrary::setFolder(const QString& input)
{
    if (input.trimmed().isEmpty())
        return tr("No folder chosen");
    const QString path = QDir::cleanPath(QDir(input).absolutePath());
    if (!QDir().mkpath(path))
        return tr("Can't create %1").arg(path);

    // can DeckOS write there? (some folders Android keeps for other apps)
    const QString probe = path + QStringLiteral("/.deckos-write-test");
    {
        QFile test(probe);
        if (!test.open(QIODevice::WriteOnly) || test.write("ok") != 2)
            return tr("DeckOS can't write to %1").arg(path);
    }
    QFile::remove(probe);

    const QString media = path + QStringLiteral("/media");
    QDir().mkpath(media);
    QDir().mkpath(path + QStringLiteral("/logs"));
    const QString keys = path + QStringLiteral("/keys.txt");
    if (!QFileInfo::exists(keys) && !write_text(keys, QByteArray(KEYS_TEMPLATE)))
        Log::warning(LOGTAG, LOGMSG("Could not write `%1`").arg(keys));

    // what was saved so far moves in, with tidy names (isOwnMedia still knows the old place here)
    moveMedia(QDir::cleanPath(GameOverrides::mediaDir()), media);

    {
        const QMutexLocker lock(&s_lock);
        s_folder = path;
    }
    GameOverrides::setMediaDir(media);
    if (!write_text(folder_file(), path.toUtf8()))
        Log::warning(LOGTAG, LOGMSG("Could not save the DeckOS folder in `%1`").arg(folder_file()));
    Log::info(LOGTAG, LOGMSG("DeckOS folder: `%1`").arg(path));

    emit folderChanged();
    saveLog();
    return {};
}

void MediaLibrary::moveMedia(const QString& from, const QString& to)
{
    // earlier builds named scraped files "<asset>-<time>[-<n>].<ext>"; they get the new names on the way
    // (also when `from` is `to`: picking the same folder again tidies the names)
    static const QRegularExpression old_name(QStringLiteral("^[A-Za-z]+-\\d{6,}(?:-\\d+)?\\.(\\w+)$"));
    const QString legacy = QDir::cleanPath(GameOverrides::legacyMediaDir());
    GameOverrides& store = GameOverrides::instance();

    int moved = 0, missing = 0;
    QHash<QString, QJsonObject> changes;
    QHash<QString, QString> renamed; // old URI -> new, for the games already loaded
    for (const QString& key : store.keys()) {
        const QJsonObject entry = store.entry(key);
        QJsonObject fields;
        for (const QString section : { QStringLiteral("assets"), QStringLiteral("custom") }) {
            const QJsonObject assets = entry.value(section).toObject();
            QJsonObject out = assets;
            bool changed = false;
            for (auto it = assets.begin(); it != assets.end(); ++it) {
                const QString asset = it.key();
                auto relocate = [&](const QString& uri, int number) -> QString {
                    if (!GameOverrides::isOwnMedia(uri))
                        return uri;
                    const QString file = local_path(uri);
                    if (!QFileInfo::exists(file)) {
                        missing++;
                        return uri;
                    }
                    const QString root = file.startsWith(from + QLatin1Char('/')) ? from : legacy;
                    const QFileInfo rel(QDir(root).relativeFilePath(file));
                    QString name = rel.fileName();
                    const QRegularExpressionMatch m = old_name.match(name);
                    if (m.hasMatch() && section == QLatin1String("assets")) {
                        if (asset == QLatin1String("screenshot") && number == 0)
                            number = 1; // an old single screenshot: screenshot-01 like the others
                        name = GameOverrides::fileStem(asset)
                             + (number > 0 ? QStringLiteral("-%1").arg(number, 2, 10, QLatin1Char('0')) : QString())
                             + QLatin1Char('.') + m.captured(1);
                    }
                    const QString dest = QDir::cleanPath(to + QLatin1Char('/') + rel.path() + QLatin1Char('/') + name);
                    if (QFileInfo(dest).absoluteFilePath() == QFileInfo(file).absoluteFilePath())
                        return uri; // already where and what it should be
                    if (!move_file(file, dest)) {
                        Log::warning(LOGTAG, LOGMSG("Could not move `%1` to `%2`").arg(file, dest));
                        return uri;
                    }
                    moved++;
                    changed = true;
                    const QString moved_uri = uri_for(dest, asset == QLatin1String("video"));
                    renamed.insert(uri, moved_uri);
                    return moved_uri;
                };
                if (it.value().isArray()) {
                    QJsonArray list;
                    int number = 0;
                    for (const QJsonValue& v : it.value().toArray())
                        list.append(relocate(v.toString(), ++number));
                    out.insert(asset, list);
                }
                else if (it.value().isString()) {
                    out.insert(asset, relocate(it.value().toString(), 0));
                }
            }
            if (changed)
                fields.insert(section, out);
        }
        if (!fields.isEmpty())
            changes.insert(key, fields);
    }
    store.updateAll(changes);

    // the games already loaded show the moved files at once (no library reload: Home would empty for a
    // moment), each asset list keeping its order
    if (m_api && !renamed.isEmpty()) {
        for (model::Game* const game : m_api->allGames()->entries()) {
            for (const QString& name : GameOverrides::assetNames()) {
                const AssetType type = type_of(name);
                const QStringList uris = game->assets().urisOf(type); // a copy: changed below
                bool hit = false;
                for (const QString& uri : uris)
                    hit = hit || renamed.contains(uri);
                if (!hit)
                    continue;
                for (const QString& uri : uris)
                    game->assetsMut().remove_uri(type, uri);
                for (const QString& uri : uris)
                    game->assetsMut().add_uri(type, renamed.value(uri, uri));
                emit game->assetsMut().changed(); // add_uri is silent
            }
        }
    }

    if (QFileInfo(from).isDir())
        remove_empty_dirs(from);
    if (from != legacy && QFileInfo(legacy).isDir())
        remove_empty_dirs(legacy);
    Log::info(LOGTAG, LOGMSG("Moved %1 media files to `%2`%3").arg(moved).arg(to)
        .arg(missing > 0 ? QStringLiteral(" (%1 were already gone)").arg(missing) : QString()));
}


// --- the user's own artwork -------------------------------------------------------------------------

QVariantList MediaLibrary::artwork(QObject* obj) const
{
    QVariantList out;
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return out;
    const QString key = GameOverrides::keyFor(*game);
    const QJsonObject custom = key.isEmpty()
        ? QJsonObject() : GameOverrides::instance().entry(key).value(QStringLiteral("custom")).toObject();

    for (const Row& row : ROWS) {
        const QString asset = QLatin1String(row.asset);
        const QStringList uris = game->assets().urisOf(type_of(asset));
        const QString url = uris.value(0);
        const QJsonValue mine = custom.value(asset);
        QString source;
        if (!url.isEmpty()) {
            if (mine.isArray() ? !mine.toArray().isEmpty() : !mine.toString().isEmpty())
                source = QStringLiteral("custom");
            else
                source = GameOverrides::isOwnMedia(url) ? QStringLiteral("scraped") : QStringLiteral("game");
        }
        QVariantMap item;
        item.insert(QStringLiteral("asset"), asset);
        item.insert(QStringLiteral("label"), tr(row.label));
        item.insert(QStringLiteral("hint"), tr(row.hint));
        item.insert(QStringLiteral("url"), url);
        item.insert(QStringLiteral("source"), source);
        item.insert(QStringLiteral("file"), url.startsWith(QLatin1String("file:")) ? local_path(url) : url);
        item.insert(QStringLiteral("count"), uris.size());
        item.insert(QStringLiteral("customCount"), mine.isArray() ? mine.toArray().size() : (mine.toString().isEmpty() ? 0 : 1));
        item.insert(QStringLiteral("video"), asset == QLatin1String("video"));
        out << item;
    }
    return out;
}

QString MediaLibrary::assignFile(QObject* obj, const QString& asset, const QString& path)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return tr("No game");
    return assign(*game, asset, path, false);
}

QString MediaLibrary::assign(model::Game& game, const QString& asset, const QString& path, bool move)
{
    if (!is_row_asset(asset))
        return tr("Unknown artwork");
    const QString key = GameOverrides::keyFor(game);
    if (key.isEmpty())
        return tr("This game has no file DeckOS can remember it by");
    const QFileInfo src(path);
    if (!src.isFile())
        return tr("No file at %1").arg(path);

    QString ext = src.suffix().toLower();
    if (ext == QLatin1String("jpeg"))
        ext = QStringLiteral("jpg");
    const bool video = asset == QLatin1String("video");
    if (video ? !video_exts().contains(ext) : !image_exts().contains(ext))
        return video ? tr("Pick a video (mp4, webm, mkv)") : tr("Pick a picture (png, jpg, webp, gif)");

    const QString dir = GameOverrides::gameMediaDir(game);
    if (!QDir().mkpath(dir))
        return tr("Can't write to %1").arg(dir);
    const QString stem = QStringLiteral("custom-") + GameOverrides::fileStem(asset);
    QString dest;
    if (asset == QLatin1String("screenshot")) {
        // added: the next free number
        static const QRegularExpression number(QStringLiteral("-(\\d+)\\.\\w+$"));
        int next = 1;
        for (const QFileInfo& info : QDir(dir).entryInfoList({ stem + QStringLiteral("-*") }, QDir::Files)) {
            const QRegularExpressionMatch m = number.match(info.fileName());
            if (m.hasMatch())
                next = std::max(next, m.captured(1).toInt() + 1);
        }
        dest = dir + QLatin1Char('/') + stem + QStringLiteral("-%1").arg(next, 2, 10, QLatin1Char('0')) + QLatin1Char('.') + ext;
    }
    else {
        dest = dir + QLatin1Char('/') + stem + QLatin1Char('.') + ext;
        // the earlier one goes, whatever its extension - unless it's the very file picked again
        for (const QFileInfo& old : QDir(dir).entryInfoList({ stem + QStringLiteral(".*") }, QDir::Files))
            if (old.absoluteFilePath() != src.absoluteFilePath())
                QFile::remove(old.absoluteFilePath());
    }
    if (src.absoluteFilePath() != QFileInfo(dest).absoluteFilePath()) {
        QFile::remove(dest);
        const bool ok = move ? move_file(src.absoluteFilePath(), dest) : QFile::copy(src.absoluteFilePath(), dest);
        if (!ok)
            return tr("Couldn't copy the file to %1").arg(dir);
    }

    const QString uri = uri_for(dest, video);
    GameOverrides& store = GameOverrides::instance();
    QJsonObject custom = store.entry(key).value(QStringLiteral("custom")).toObject();
    const QJsonValue old = custom.value(asset);
    if (asset == QLatin1String("screenshot")) {
        QJsonArray list = old.toArray();
        list.append(uri);
        custom.insert(asset, list);
    }
    else {
        custom.insert(asset, uri);
    }
    store.update(key, QJsonObject { { QStringLiteral("custom"), custom } });

    // shown at once: first in the game's list (scraped and the game's own files stay behind it)
    const AssetType type = type_of(asset);
    if (old.isString() && !old.toString().isEmpty())
        game.assetsMut().remove_uri(type, old.toString());
    game.assetsMut().set_first(type, uri);
    Log::info(LOGTAG, LOGMSG("Own %1 for `%2`: `%3`").arg(asset, game.title(), dest));
    emit artworkChanged(&game);
    return {};
}

void MediaLibrary::clearCustom(QObject* obj, const QString& asset)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return;
    const QString key = GameOverrides::keyFor(*game);
    if (key.isEmpty())
        return;
    GameOverrides& store = GameOverrides::instance();
    QJsonObject custom = store.entry(key).value(QStringLiteral("custom")).toObject();
    if (!custom.contains(asset))
        return;

    const QJsonValue old = custom.take(asset);
    QStringList uris;
    if (old.isArray()) {
        for (const QJsonValue& v : old.toArray())
            uris << v.toString();
    }
    else {
        uris << old.toString();
    }
    const AssetType type = type_of(asset);
    for (const QString& uri : uris) {
        if (GameOverrides::isOwnMedia(uri))
            QFile::remove(local_path(uri));
        game->assetsMut().remove_uri(type, uri);
    }
    store.update(key, QJsonObject { { QStringLiteral("custom"), custom.isEmpty() ? QJsonValue() : QJsonValue(custom) } });
    Log::info(LOGTAG, LOGMSG("Own %1 for `%2` removed").arg(asset, game->title()));
    emit artworkChanged(game);
}

void MediaLibrary::pickFile(QObject* obj, const QString& asset)
{
#ifdef Q_OS_ANDROID
    if (!qobject_cast<model::Game*>(obj) || !is_row_asset(asset))
        return;
    const QPointer<QObject> game(obj);
    const bool video = asset == QLatin1String("video");
    auto jstr = [](const char* s) { return QAndroidJniObject::fromString(QString::fromLatin1(s)); };
    QAndroidJniObject intent("android/content/Intent", "(Ljava/lang/String;)V",
                             jstr("android.intent.action.OPEN_DOCUMENT").object<jstring>());
    intent.callObjectMethod("addCategory", "(Ljava/lang/String;)Landroid/content/Intent;",
                            jstr("android.intent.category.OPENABLE").object<jstring>());
    intent.callObjectMethod("setType", "(Ljava/lang/String;)Landroid/content/Intent;",
                            jstr(video ? "video/*" : "image/*").object<jstring>());
    // the result arrives on Android's thread: only the picked file's address is taken there
    QtAndroid::startActivity(intent, 4711, [this, game, asset](int, int result, const QAndroidJniObject& data) {
        QString uri;
        if (result == -1 /* RESULT_OK */ && data.isValid()) {
            const QAndroidJniObject picked = data.callObjectMethod("getData", "()Landroid/net/Uri;");
            if (picked.isValid())
                uri = picked.toString();
        }
        QMetaObject::invokeMethod(this, [this, game, asset, uri]() { onPicked(game, asset, uri); }, Qt::QueuedConnection);
    });
#else
    emit picked(obj, asset, tr("Android's file manager is Android only"));
#endif
}

void MediaLibrary::onPicked(QPointer<QObject> obj, const QString& asset, const QString& uri)
{
    auto game = qobject_cast<model::Game*>(obj.data());
    if (!game)
        return;
    if (uri.isEmpty()) {
        emit picked(game, asset, QStringLiteral("cancelled"));
        return;
    }
#ifdef Q_OS_ANDROID
    const QString dir = GameOverrides::gameMediaDir(*game);
    QDir().mkpath(dir);
    const QString incoming = dir + QStringLiteral("/.incoming-") + asset; // Java adds the extension
    m_busy = true;
    emit busyChanged();
    // copied on another thread: a trailer can be large
    auto watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, obj, asset]() {
        const QString path = watcher->result();
        watcher->deleteLater();
        m_busy = false;
        emit busyChanged();
        auto g = qobject_cast<model::Game*>(obj.data());
        if (!g) {
            QFile::remove(path);
            return;
        }
        if (path.isEmpty()) {
            emit picked(g, asset, tr("Couldn't read that file"));
            return;
        }
        const QString error = assign(*g, asset, path, true);
        if (!error.isEmpty())
            QFile::remove(path);
        emit picked(g, asset, error);
    });
    watcher->setFuture(QtConcurrent::run([uri, incoming]() {
        QAndroidJniEnvironment env; // this thread talks to Java
        const QAndroidJniObject result = QAndroidJniObject::callStaticObjectMethod(
            "com/deckos/media/MediaFiles", "copy",
            "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
            QtAndroid::androidContext().object(),
            QAndroidJniObject::fromString(uri).object<jstring>(),
            QAndroidJniObject::fromString(incoming).object<jstring>());
        if (env->ExceptionCheck())
            env->ExceptionClear();
        return result.isValid() ? result.toString() : QString();
    }));
#else
    Q_UNUSED(asset);
#endif
}


// --- keys.txt and the log ---------------------------------------------------------------------------

bool MediaLibrary::keysChanged() const
{
    const QString now = signature(keysFilePath());
    if (now.isEmpty())
        return false;
    QFile file(keys_read_file());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return true;
    return QString::fromUtf8(file.readAll()).trimmed() != now;
}

void MediaLibrary::keysRead()
{
    write_text(keys_read_file(), signature(keysFilePath()).toUtf8());
}

void MediaLibrary::saveLog() const
{
    const QString dir = folder();
    if (dir.isEmpty())
        return;
    const QString src = paths::writableConfigDir() + QStringLiteral("/lastrun.log");
    if (!QFileInfo::exists(src))
        return;
    const QString dst = dir + QStringLiteral("/logs/lastrun.log");
    QDir().mkpath(dir + QStringLiteral("/logs"));
    QFile::remove(dst);
    QFile::copy(src, dst);
}

} // namespace deckos
