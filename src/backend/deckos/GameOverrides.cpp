// DeckOS
// See GameOverrides.h

#include "GameOverrides.h"

#include "Log.h"
#include "Paths.h"
#include "model/gaming/Assets.h"
#include "model/gaming/Game.h"
#include "model/gaming/GameFile.h"
#include "types/AssetType.h"
#include "utils/PathTools.h"

#include <QDate>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
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

QString GameOverrides::mediaDir()
{
    return paths::writableConfigDir() + QStringLiteral("/deckos/media");
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
    save_locked();
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
    for (const AssetName& asset : ASSET_NAMES) {
        const QJsonValue value = assets.value(QLatin1String(asset.name));
        if (value.isArray()) {
            // several files (screenshots): the scraped ones replace earlier scraped ones, after the
            // game's own (metadata) files
            const QString media_prefix = QUrl::fromLocalFile(mediaDir()).toString();
            const QStringList old = game.assets().urisOf(asset.type);
            for (const QString& uri : old)
                if (uri.startsWith(media_prefix))
                    game.assetsMut().remove_uri(asset.type, uri);
            for (const QJsonValue& v : value.toArray())
                if (!v.toString().isEmpty())
                    game.assetsMut().add_uri(asset.type, v.toString());
            emit game.assetsMut().changed(); // add_uri is silent; pages showing the game update
            continue;
        }
        const QString uri = value.toString();
        if (!uri.isEmpty())
            game.assetsMut().set_first(asset.type, uri);
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

    // scraped artwork files are not shown any more (other sources' files stay)
    const QString media_prefix = QUrl::fromLocalFile(mediaDir()).toString();
    for (const AssetName& asset : ASSET_NAMES) {
        const QStringList uris = game.assets().urisOf(asset.type); // copy: removing while iterating
        for (const QString& uri : uris) {
            if (uri.startsWith(media_prefix))
                game.assetsMut().remove_uri(asset.type, uri);
        }
    }

    if (changed)
        emit game.metadataChanged();
}

} // namespace deckos
