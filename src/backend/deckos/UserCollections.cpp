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
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    for (const QJsonValue& v : root.value(QStringLiteral("hidden")).toArray()) {
        if (!v.toString().isEmpty())
            m_hidden_names << v.toString();
    }
    const QJsonObject renames = root.value(QStringLiteral("renames")).toObject();
    for (auto it = renames.begin(); it != renames.end(); ++it) {
        if (!it.key().isEmpty() && !it.value().toString().isEmpty())
            m_renames.insert(it.key(), it.value().toString());
    }
    const QJsonArray list = root.value(QStringLiteral("collections")).toArray();
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
    QJsonObject renames;
    for (auto it = m_renames.cbegin(); it != m_renames.cend(); ++it)
        renames.insert(it.key(), it.value());
    const QJsonObject root {
        { QStringLiteral("version"), 1 },
        { QStringLiteral("collections"), list },
        { QStringLiteral("hidden"), QJsonArray::fromStringList(m_hidden_names) },
        { QStringLiteral("renames"), renames },
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

model::Collection* UserCollections::hiddenCollection(const QString& name) const
{
    const QMutexLocker lock(&m_lock);
    for (const QPointer<model::Collection>& coll : m_hidden) {
        if (coll && same_name(coll->name(), name))
            return coll;
    }
    return nullptr;
}

QString UserCollections::originalName(const QString& name) const
{
    for (auto it = m_renames.cbegin(); it != m_renames.cend(); ++it) {
        if (same_name(it.value(), name))
            return it.key();
    }
    return m_library_names.contains(name.toLower()) ? name : QString();
}

void UserCollections::apply(std::vector<model::Collection*>& collections, const std::vector<model::Game*>& games)
{
    const QMutexLocker lock(&m_lock);
    m_hidden.clear();
    m_library_names.clear();
    for (model::Collection* const coll : collections)
        m_library_names.insert(coll->name().toLower());

    // the library's collections the user renamed
    for (model::Collection* const coll : collections) {
        for (auto it = m_renames.cbegin(); it != m_renames.cend(); ++it) {
            if (same_name(coll->name(), it.key())) {
                coll->setName(it.value());
                break;
            }
        }
    }

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

    // hidden ones leave the list; their games keep them (the first one may be a game's system). They
    // move to the UI thread now, as setGameData does with the others, so they can come back later
    if (!m_hidden_names.isEmpty()) {
        const auto new_end = std::remove_if(collections.begin(), collections.end(), [this](model::Collection* coll) {
            const bool hide = std::any_of(m_hidden_names.cbegin(), m_hidden_names.cend(),
                [coll](const QString& n) { return same_name(n, coll->name()); });
            if (hide) {
                if (m_api) {
                    coll->moveToThread(m_api->thread());
                    coll->setParent(m_api);
                }
                m_hidden.emplace_back(coll);
            }
            return hide;
        });
        collections.erase(new_end, collections.end());
    }

    std::sort(collections.begin(), collections.end(), model::sort_collections);
    if (!m_entries.empty() || !m_renames.isEmpty() || !m_hidden.empty()) {
        Log::info(LOGTAG, LOGMSG("Your collections: %1, %2 games put in them, %3 renamed, %4 hidden")
            .arg(m_entries.size()).arg(added).arg(m_renames.size()).arg(m_hidden.size()));
    }
}

QVariantList UserCollections::allCollections() const
{
    QVariantList out;
    if (!m_api)
        return out;
    auto row = [this](const model::Collection* coll, bool hidden) {
        return QVariantMap {
            { QStringLiteral("name"), coll->name() },
            { QStringLiteral("shortName"), coll->shortName() },
            { QStringLiteral("count"), coll->gameList() ? coll->gameList()->count() : 0 },
            { QStringLiteral("hidden"), hidden },
            { QStringLiteral("user"), originalName(coll->name()).isEmpty() },
        };
    };
    const QMutexLocker lock(&m_lock);
    for (const model::Collection* coll : m_api->collections()->entries())
        out << row(coll, false);
    for (const QPointer<model::Collection>& coll : m_hidden) {
        if (coll)
            out << row(coll, true);
    }
    std::sort(out.begin(), out.end(), [](const QVariant& a, const QVariant& b) {
        return QString::localeAwareCompare(a.toMap().value(QStringLiteral("name")).toString(),
                                           b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return out;
}

bool UserCollections::setHidden(const QString& name, bool hide)
{
    if (!m_api)
        return false;
    if (hide) {
        model::Collection* coll = collection(name);
        if (!coll)
            return false;
        m_api->removeCollection(coll);
        {
            const QMutexLocker lock(&m_lock);
            m_hidden.emplace_back(coll);
            if (!std::any_of(m_hidden_names.cbegin(), m_hidden_names.cend(), [&](const QString& n) { return same_name(n, name); }))
                m_hidden_names << coll->name();
            save();
        }
        Log::info(LOGTAG, LOGMSG("Collection `%1` hidden").arg(coll->name()));
    }
    else {
        model::Collection* coll = hiddenCollection(name);
        {
            const QMutexLocker lock(&m_lock);
            m_hidden_names.erase(std::remove_if(m_hidden_names.begin(), m_hidden_names.end(),
                [&](const QString& n) { return same_name(n, name); }), m_hidden_names.end());
            m_hidden.erase(std::remove_if(m_hidden.begin(), m_hidden.end(),
                [&](const QPointer<model::Collection>& c) { return !c || c == coll; }), m_hidden.end());
            save();
        }
        if (coll)
            m_api->addCollection(coll);
        Log::info(LOGTAG, LOGMSG("Collection `%1` shown again").arg(name));
    }
    emit listChanged();
    return true;
}

QString UserCollections::rename(const QString& name, const QString& new_name)
{
    if (!m_api)
        return tr("No library");
    const QString clean = new_name.simplified();
    if (clean.isEmpty())
        return tr("Type a name for the collection");
    if (clean.length() > MAX_NAME)
        return tr("That name is too long (%1 letters at most)").arg(MAX_NAME);
    model::Collection* coll = collection(name);
    if (!coll)
        coll = hiddenCollection(name);
    if (!coll)
        return tr("There is no collection called %1").arg(name);
    if (!same_name(name, clean) && (collection(clean) || hiddenCollection(clean)))
        return tr("There is a collection called %1 already").arg(clean);

    const QString old = coll->name();
    {
        const QMutexLocker lock(&m_lock);
        const QString original = originalName(old);
        if (!original.isEmpty()) {
            if (original == clean)
                m_renames.remove(original);
            else
                m_renames.insert(original, clean);
        }
        for (Entry& e : m_entries) {
            if (same_name(e.name, old))
                e.name = clean;
        }
        for (QString& hidden : m_hidden_names) {
            if (same_name(hidden, old))
                hidden = clean;
        }
        save();
    }
    coll->setName(clean);
    m_api->sortCollections();
    Log::info(LOGTAG, LOGMSG("Collection `%1` renamed to `%2`").arg(old, clean));
    emit listChanged();
    return {};
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
    if (model::Collection* coll = collection(clean) ? collection(clean) : hiddenCollection(clean))
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
    if (!coll)
        coll = hiddenCollection(clean); // hidden: the game goes in, the collection stays hidden
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
