// DeckOS
// See UserCollections.h

#include "UserCollections.h"

#include "GameOverrides.h"
#include "Log.h"
#include "Paths.h"
#include "model/Api.h"
#include "model/gaming/Collection.h"
#include "model/gaming/Game.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QVariantMap>
#include <algorithm>


namespace {
const QString LOGTAG = QStringLiteral("DeckOS");

bool same_name(const QString& a, const QString& b)
{
    return a.compare(b, Qt::CaseInsensitive) == 0;
}

bool has_collection(const model::Game& game, const model::Collection* coll)
{
    return game.collectionsModel() && game.collectionsModel()->contains(const_cast<model::Collection*>(coll));
}
} // namespace


namespace deckos {

UserCollections::UserCollections(model::ApiObject* api, QObject* parent)
    : UserCollections(api, defaultPath(), parent)
{}

UserCollections::UserCollections(model::ApiObject* api, QString path, QObject* parent)
    : QObject(parent)
    , m_api(api)
    , m_path(std::move(path))
{
    load();
}

QString UserCollections::defaultPath()
{
    return paths::writableConfigDir() + QStringLiteral("/deckos/collections.json");
}

void UserCollections::load()
{
    m_entries.clear();
    QFile file(m_path);
    if (!file.exists())
        return;
    if (!file.open(QIODevice::ReadOnly)) {
        Log::warning(LOGTAG, LOGMSG("Could not read `%1`, your collections are not loaded").arg(m_path));
        return;
    }
    const QJsonArray list = QJsonDocument::fromJson(file.readAll()).object()
        .value(QStringLiteral("collections")).toArray();
    for (const QJsonValue& value : list) {
        const QJsonObject obj = value.toObject();
        const QString name = obj.value(QStringLiteral("name")).toString().simplified();
        if (name.isEmpty())
            continue;
        Entry* existing = entry(name);
        if (!existing) {
            m_entries.push_back({ name, {} });
            existing = &m_entries.back();
        }
        for (const QJsonValue& key : obj.value(QStringLiteral("games")).toArray()) {
            const QString k = key.toString();
            if (!k.isEmpty() && !existing->keys.contains(k))
                existing->keys.append(k);
        }
    }
}

bool UserCollections::save() const
{
    QJsonArray list;
    for (const Entry& e : m_entries) {
        list.append(QJsonObject {
            { QStringLiteral("name"), e.name },
            { QStringLiteral("games"), QJsonArray::fromStringList(e.keys) },
        });
    }
    const QJsonObject root {
        { QStringLiteral("version"), 1 },
        { QStringLiteral("collections"), list },
    };

    QDir().mkpath(QFileInfo(m_path).absolutePath());
    QSaveFile file(m_path);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
        if (file.commit())
            return true;
    }
    Log::warning(LOGTAG, LOGMSG("Could not write `%1`, your collections are not saved").arg(m_path));
    return false;
}

UserCollections::Entry* UserCollections::entry(const QString& name)
{
    const auto it = std::find_if(m_entries.begin(), m_entries.end(),
        [&name](const Entry& e) { return same_name(e.name, name); });
    return it == m_entries.end() ? nullptr : &*it;
}

const UserCollections::Entry* UserCollections::entry(const QString& name) const
{
    return const_cast<UserCollections*>(this)->entry(name);
}

model::Collection* UserCollections::collection(const QString& name) const
{
    if (!m_api)
        return nullptr;
    for (model::Collection* const coll : m_api->collections()->entries()) {
        if (same_name(coll->name(), name))
            return coll;
    }
    return nullptr;
}

void UserCollections::apply(std::vector<model::Collection*>& collections, const std::vector<model::Game*>& games) const
{
    const QMutexLocker lock(&m_lock);
    if (m_entries.empty())
        return;

    QHash<QString, model::Game*> by_key;
    for (model::Game* const game : games) {
        const QString key = GameOverrides::keyFor(*game);
        if (!key.isEmpty())
            by_key.insert(key, game);
    }

    int added = 0;
    for (const Entry& e : m_entries) {
        std::vector<model::Game*> members;
        for (const QString& key : e.keys) {
            model::Game* const game = by_key.value(key);
            if (game && std::find(members.cbegin(), members.cend(), game) == members.cend())
                members.push_back(game);
        }
        if (members.empty())
            continue;

        const auto found = std::find_if(collections.cbegin(), collections.cend(),
            [&e](const model::Collection* c) { return same_name(c->name(), e.name); });
        model::Collection* coll = nullptr;
        if (found != collections.cend()) {
            coll = *found;
            coll->addGames(members);
        }
        else {
            coll = new model::Collection(e.name);
            coll->setGames(std::vector<model::Game*>(members));
            collections.push_back(coll);
        }
        for (model::Game* const game : members) {
            if (!has_collection(*game, coll)) {
                game->addCollection(coll);
                added++;
            }
        }
    }
    std::sort(collections.begin(), collections.end(), model::sort_collections);
    Log::info(LOGTAG, LOGMSG("Your collections: %1, %2 games put in them").arg(m_entries.size()).arg(added));
}

QVariantList UserCollections::forGame(QObject* obj) const
{
    QVariantList out;
    auto game = qobject_cast<model::Game*>(obj);
    if (!game || !m_api)
        return out;
    const QString key = GameOverrides::keyFor(*game);

    const QMutexLocker lock(&m_lock);
    for (model::Collection* const coll : m_api->collections()->entries()) {
        const Entry* e = entry(coll->name());
        out.append(QVariantMap {
            { QStringLiteral("name"), coll->name() },
            { QStringLiteral("member"), has_collection(*game, coll) },
            { QStringLiteral("mine"), e && !key.isEmpty() && e->keys.contains(key) },
            { QStringLiteral("count"), coll->gameList() ? coll->gameList()->count() : 0 },
        });
    }
    std::sort(out.begin(), out.end(), [](const QVariant& a, const QVariant& b) {
        return QString::localeAwareCompare(a.toMap().value(QStringLiteral("name")).toString(),
                                           b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return out;
}

QString UserCollections::existingName(const QString& name) const
{
    const QString clean = name.simplified();
    if (clean.isEmpty())
        return {};
    if (model::Collection* coll = collection(clean))
        return coll->name();
    return {};
}

QString UserCollections::add(QObject* obj, const QString& name)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game || !m_api)
        return tr("No game selected");
    const QString clean = name.simplified();
    if (clean.isEmpty())
        return tr("Type a name for the collection");
    if (clean.length() > MAX_NAME)
        return tr("That name is too long (%1 letters at most)").arg(MAX_NAME);
    const QString key = GameOverrides::keyFor(*game);
    if (key.isEmpty())
        return tr("This game has no file, so it can't be put in a collection");

    model::Collection* coll = collection(clean);
    if (coll && has_collection(*game, coll))
        return {}; // already in it

    const QString coll_name = coll ? coll->name() : clean;
    {
        const QMutexLocker lock(&m_lock);
        Entry* e = entry(coll_name);
        if (!e) {
            m_entries.push_back({ coll_name, {} });
            e = &m_entries.back();
        }
        if (!e->keys.contains(key))
            e->keys.append(key);
        if (!save())
            return tr("Could not save your collections");
    }

    if (coll) {
        coll->addGames({ game });
    }
    else {
        coll = new model::Collection(coll_name);
        coll->setGames({ game });
        m_api->addCollection(coll);
    }
    game->addCollection(coll);
    Log::info(LOGTAG, LOGMSG("`%1` put in your collection `%2`").arg(game->title(), coll_name));
    emit changed(game);
    return {};
}

bool UserCollections::remove(QObject* obj, const QString& name)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game || !m_api)
        return false;
    const QString key = GameOverrides::keyFor(*game);
    QString coll_name;
    {
        const QMutexLocker lock(&m_lock);
        Entry* e = entry(name);
        if (!e || key.isEmpty() || !e->keys.contains(key))
            return false; // there because of the library, not the user

        e->keys.removeAll(key);
        coll_name = e->name;
        if (e->keys.isEmpty()) {
            m_entries.erase(std::find_if(m_entries.begin(), m_entries.end(),
                [e](const Entry& x) { return &x == e; }));
        }
        save();
    }

    if (model::Collection* coll = collection(coll_name)) {
        coll->removeGames({ game });
        game->removeCollection(coll);
        if (!coll->gameList() || coll->gameList()->isEmpty())
            m_api->removeCollection(coll);
    }
    Log::info(LOGTAG, LOGMSG("`%1` taken out of your collection `%2`").arg(game->title(), coll_name));
    emit changed(game);
    return true;
}

} // namespace deckos
