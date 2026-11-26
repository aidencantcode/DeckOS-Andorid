// DeckOS
// See GameOverrides.h

#include "GameOverrides.h"

#include "Log.h"
#include "Paths.h"
#include "model/gaming/Assets.h"
#include "model/gaming/Collection.h"
#include "model/gaming/Game.h"
#include "model/gaming/GameFile.h"
#include "types/AssetType.h"
#include "utils/PathTools.h"

#include <QDate>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUrl>


namespace {
const QString LOGTAG = QStringLiteral("DeckOS");

struct AssetName {
    const char* name;
    AssetType type;
};
const AssetName ASSET_NAMES[] = {
    { "boxFront", AssetType::BOX_FRONT },
    { "boxBack", AssetType::BOX_BACK },
    { "logo", AssetType::LOGO },
    { "poster", AssetType::POSTER },
    { "steam", AssetType::UI_STEAMGRID },
    { "banner", AssetType::UI_BANNER },
    { "tile", AssetType::UI_TILE },
    { "background", AssetType::BACKGROUND },
    { "screenshot", AssetType::SCREENSHOT },
    { "titlescreen", AssetType::TITLESCREEN },
    { "marquee", AssetType::ARCADE_MARQUEE },
    { "video", AssetType::VIDEO },
};

QStringList to_list(const QJsonValue& val)
{
    if (val.isArray()) {
        QStringList out;
        for (const QJsonValue& item : val.toArray())
            out << item.toString();
        return out;
    }
    if (val.isString() && !val.toString().isEmpty())
        return { val.toString() };
    return {};
}

void keep_original(model::Game& game, const char* field, const QString& value)
{
    const QString key = QStringLiteral("deckos_original_") + QLatin1String(field);
    QVariantMap& extra = game.extraMapMut();
    if (!extra.contains(key))
        extra.insert(key, value);
}
} // namespace


namespace deckos {

GameOverrides& GameOverrides::instance()
{
    static GameOverrides store(paths::writableConfigDir() + QStringLiteral("/deckos/game_overrides.json"));
    return store;
}

GameOverrides::GameOverrides(QString path)
    : m_path(std::move(path))
{
    const QMutexLocker lock(&m_lock);
    load_locked();
}

namespace {
QMutex s_media_lock;
QString s_media_dir; // MediaLibrary sets it; the library loads read it on their own thread
} // namespace

QString GameOverrides::mediaDir()
{
    const QMutexLocker lock(&s_media_lock);
    return s_media_dir.isEmpty() ? legacyMediaDir() : s_media_dir;
}

void GameOverrides::setMediaDir(const QString& dir)
{
    const QMutexLocker lock(&s_media_lock);
    s_media_dir = dir;
}

QString GameOverrides::legacyMediaDir()
{
    return paths::writableConfigDir() + QStringLiteral("/deckos/media");
}

bool GameOverrides::isOwnMedia(const QString& uri)
{
    if (!uri.startsWith(QLatin1String("file:")))
        return false;
    for (const QString& dir : { mediaDir(), legacyMediaDir() }) {
        if (uri.startsWith(QUrl::fromLocalFile(dir).toString() + QLatin1Char('/')))
            return true;
    }
    return false;
}

QString GameOverrides::safeName(QString name)
{
    static const QRegularExpression bad(QStringLiteral("[^\\w\\-. ()\\[\\]]"));
    name.replace(bad, QStringLiteral("_"));
    return name.left(120).trimmed();
}

QString GameOverrides::gameMediaDir(const QString& system, const QString& name)
{
    return mediaDir() + QLatin1Char('/') + safeName(system.isEmpty() ? QStringLiteral("other") : system)
         + QLatin1Char('/') + safeName(name);
}

QString GameOverrides::gameMediaDir(const model::Game& game)
{
    QString system;
    const auto& collections = game.collectionsModel()->entries();
    if (!collections.empty())
        system = collections.front()->shortName().toLower();
    QString name;
    const auto& files = game.filesModel()->entries();
    if (!files.empty() && !files.front()->path().isEmpty())
        name = files.front()->fileinfo().completeBaseName();
    return gameMediaDir(system, name.isEmpty() ? game.title() : name);
}

QString GameOverrides::fileStem(const QString& asset)
{
    static const QHash<QString, QString> stems {
        { QStringLiteral("background"), QStringLiteral("hero") },
        { QStringLiteral("poster"), QStringLiteral("capsule") },
        { QStringLiteral("steam"), QStringLiteral("wide-capsule") },
        { QStringLiteral("boxFront"), QStringLiteral("boxart") },
        { QStringLiteral("boxBack"), QStringLiteral("boxart-back") },
        { QStringLiteral("video"), QStringLiteral("trailer") },
    };
    return stems.value(asset, asset);
}

int GameOverrides::assetType(const QString& name)
{
    for (const AssetName& entry : ASSET_NAMES)
        if (name == QLatin1String(entry.name))
            return static_cast<int>(entry.type);
    return static_cast<int>(AssetType::UNKNOWN);
}

QStringList GameOverrides::assetNames()
{
    QStringList out;
    for (const AssetName& entry : ASSET_NAMES)
        out << QLatin1String(entry.name);
    return out;
}

QString GameOverrides::keyFor(const model::Game& game)
{
    const auto& files = game.filesModel()->entries();
    if (files.empty())
        return {};

    const model::GameFile* const file = files.front();
    if (!file->path().isEmpty() && file->fileinfo().exists())
        return QStringLiteral("file:") + ::clean_abs_path(file->fileinfo());
    if (!file->uri().isEmpty())
        return QStringLiteral("uri:") + file->uri();
    if (!file->path().isEmpty())
        return QStringLiteral("file:") + file->path();
    return {};
}

void GameOverrides::load_locked()
{
    m_data = {};
    QFile file(m_path);
    if (!file.exists())
        return;
    if (!file.open(QIODevice::ReadOnly)) {
        Log::warning(LOGTAG, LOGMSG("Could not read `%1`").arg(m_path));
        return;
    }
    QJsonParseError err {};
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        Log::warning(LOGTAG, LOGMSG("`%1` is not valid JSON (%2), ignored").arg(m_path, err.errorString()));
        return;
    }
    m_data = doc.object();
}

void GameOverrides::save_locked() const
{
    QDir().mkpath(QFileInfo(m_path).absolutePath());
    QSaveFile file(m_path);
    if (!file.open(QIODevice::WriteOnly)) {
        Log::warning(LOGTAG, LOGMSG("Could not write `%1`, game changes not saved").arg(m_path));
        return;
    }
    file.write(QJsonDocument(m_data).toJson(QJsonDocument::Indented));
    if (!file.commit())
        Log::warning(LOGTAG, LOGMSG("Could not write `%1`, game changes not saved").arg(m_path));
}

void GameOverrides::reload()
{
    const QMutexLocker lock(&m_lock);
    load_locked();
}

QJsonObject GameOverrides::entry(const QString& key) const
{
    const QMutexLocker lock(&m_lock);
    return m_data.value(key).toObject();
}

QStringList GameOverrides::keys() const
{
    const QMutexLocker lock(&m_lock);
    return m_data.keys();
}

void GameOverrides::update(const QString& key, const QJsonObject& fields)
{
    if (key.isEmpty())
        return;

    const QMutexLocker lock(&m_lock);
    merge_locked(key, fields);
    save_locked();
}

void GameOverrides::updateAll(const QHash<QString, QJsonObject>& changes)
{
    if (changes.isEmpty())
        return;

    const QMutexLocker lock(&m_lock);
    for (auto it = changes.begin(); it != changes.end(); ++it)
        if (!it.key().isEmpty())
            merge_locked(it.key(), it.value());
    save_locked();
}

void GameOverrides::merge_locked(const QString& key, const QJsonObject& fields)
{
    QJsonObject entry = m_data.value(key).toObject();
    for (auto it = fields.begin(); it != fields.end(); ++it) {
        if (it.key() == QLatin1String("assets") && it.value().isObject()) {
            QJsonObject assets = entry.value(QStringLiteral("assets")).toObject();
            const QJsonObject changes = it.value().toObject();
            for (auto a = changes.begin(); a != changes.end(); ++a) {
                if (a.value().isNull())
                    assets.remove(a.key());
                else
                    assets.insert(a.key(), a.value());
            }
            if (assets.isEmpty())
                entry.remove(QStringLiteral("assets"));
            else
                entry.insert(QStringLiteral("assets"), assets);
            continue;
        }
        if (it.value().isNull())
            entry.remove(it.key());
        else
            entry.insert(it.key(), it.value());
    }

    if (entry.isEmpty())
        m_data.remove(key);
    else
        m_data.insert(key, entry);
}

void GameOverrides::remove(const QString& key)
{
    const QMutexLocker lock(&m_lock);
    if (!m_data.contains(key))
        return;
    m_data.remove(key);
    save_locked();
}

void GameOverrides::apply(model::Game& game, const QJsonObject& entry, bool live)
{
    if (entry.isEmpty())
        return;

    bool meta_changed = false;

    const QString title = entry.value(QStringLiteral("title")).toString();
    if (!title.isEmpty()) {
        keep_original(game, "title", game.title());
        keep_original(game, "sortBy", game.sortBy());
        game.setTitle(title);
        game.setSortBy(title);
        meta_changed = true;
    }

    const QString description = entry.value(QStringLiteral("description")).toString();
    if (!description.isEmpty()) {
        keep_original(game, "description", game.description());
        keep_original(game, "summary", game.summary());
        game.setDescription(description);
        // themes show `summary || description`; an edited/scraped text has to win over an old summary
        game.setSummary(entry.value(QStringLiteral("summary")).toString(description));
        meta_changed = true;
    }

    const QStringList developers = to_list(entry.value(QStringLiteral("developer")));
    if (!developers.isEmpty()) { game.developerList() = developers; meta_changed = true; }
    const QStringList publishers = to_list(entry.value(QStringLiteral("publisher")));
    if (!publishers.isEmpty()) { game.publisherList() = publishers; meta_changed = true; }
    const QStringList genres = to_list(entry.value(QStringLiteral("genre")));
    if (!genres.isEmpty()) { game.genreList() = genres; meta_changed = true; }

    const QDate release = QDate::fromString(entry.value(QStringLiteral("release")).toString(), Qt::ISODate);
    if (release.isValid()) { game.setReleaseDate(release); meta_changed = true; }

    // a per-game launch command ("Launch with..." / edited in Properties)
    const QString launch = entry.value(QStringLiteral("launch")).toString();
    if (!launch.isEmpty()) {
        keep_original(game, "launch", game.launchCmd());
        game.setLaunchCmd(launch);
    }

    const int players = entry.value(QStringLiteral("players")).toInt(0);
    if (players > 0) { game.setPlayerCount(players); meta_changed = true; }

    const QJsonObject assets = entry.value(QStringLiteral("assets")).toObject();
    const QJsonObject custom = entry.value(QStringLiteral("custom")).toObject(); // the user's own files
    for (const AssetName& asset : ASSET_NAMES) {
        const QJsonValue value = assets.value(QLatin1String(asset.name));
        const QJsonValue mine = custom.value(QLatin1String(asset.name));
        if (value.isArray() || mine.isArray()) {
            // several files (screenshots): DeckOS's replace earlier ones of DeckOS's, after the game's
            // own (metadata) files - the user's first, then the scraped ones
            const QStringList old = game.assets().urisOf(asset.type);
            for (const QString& uri : old)
                if (isOwnMedia(uri))
                    game.assetsMut().remove_uri(asset.type, uri);
            for (const QJsonArray& list : { mine.toArray(), value.toArray() })
                for (const QJsonValue& v : list)
                    if (!v.toString().isEmpty())
                        game.assetsMut().add_uri(asset.type, v.toString());
            emit game.assetsMut().changed(); // add_uri is silent; pages showing the game update
            continue;
        }
        const QString uri = value.toString();
        if (!uri.isEmpty())
            game.assetsMut().set_first(asset.type, uri);
        const QString own = mine.toString();
        if (!own.isEmpty())
            game.assetsMut().set_first(asset.type, own); // first: the user's file wins
    }

    if (live && meta_changed)
        emit game.metadataChanged();
}

void GameOverrides::restore(model::Game& game)
{
    const QVariantMap& extra = game.extraMap();
    auto original = [&extra](const char* field, bool& found) {
        const QString key = QStringLiteral("deckos_original_") + QLatin1String(field);
        found = extra.contains(key);
        return extra.value(key).toString();
    };

    bool found = false;
    bool changed = false;
    QString value = original("title", found);
    if (found) { game.setTitle(value); changed = true; }
    value = original("sortBy", found);
    if (found) game.setSortBy(value);
    value = original("description", found);
    if (found) { game.setDescription(value); changed = true; }
    value = original("summary", found);
    if (found) game.setSummary(value);
    value = original("launch", found);
    if (found) game.setLaunchCmd(value);

    // DeckOS's artwork files (scraped or the user's) are not shown any more (other sources' files stay)
    for (const AssetName& asset : ASSET_NAMES) {
        const QStringList uris = game.assets().urisOf(asset.type); // copy: removing while iterating
        for (const QString& uri : uris) {
            if (isOwnMedia(uri))
                game.assetsMut().remove_uri(asset.type, uri);
        }
    }

    if (changed)
        emit game.metadataChanged();
}

} // namespace deckos
