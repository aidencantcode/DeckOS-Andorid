// DeckOS
// Tests for deckos::UserCollections: the collections the user puts games in from the game page.

#include <QtTest/QtTest>

#include "CliArgs.h"
#include "Log.h"
#include "deckos/GameOverrides.h"
#include "deckos/UserCollections.h"
#include "model/Api.h"
#include "model/gaming/Collection.h"
#include "model/gaming/Game.h"
#include "providers/SearchContext.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>


namespace {
QString touch(const QTemporaryDir& dir, const QString& name)
{
    const QString path = dir.filePath(name);
    QFile f(path);
    f.open(QIODevice::WriteOnly);
    return path;
}

QStringList names(const model::CollectionListModel* list)
{
    QStringList out;
    for (const model::Collection* c : list->entries())
        out << c->name();
    return out;
}

model::Game* by_title(const std::vector<model::Game*>& games, const QString& title)
{
    for (model::Game* g : games)
        if (g->title() == title)
            return g;
    return nullptr;
}
} // namespace


class test_UserCollections : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { Log::init_qttest(); }

    void apply_puts_them_after_the_system();
    void add_and_remove_while_running();
    void hide_and_rename();

private:
    // a library with two GBA games (A, B) and one Android app (C)
    std::pair<std::vector<model::Collection*>, std::vector<model::Game*>> library(const QTemporaryDir& dir);
};

std::pair<std::vector<model::Collection*>, std::vector<model::Game*>> test_UserCollections::library(const QTemporaryDir& dir)
{
    providers::SearchContext sctx;
    model::Collection& gba = *sctx.get_or_create_collection(QStringLiteral("GBA"));
    model::Collection& android = *sctx.get_or_create_collection(QStringLiteral("Android"));

    model::Game* a = sctx.create_game_for(gba);
    a->setTitle(QStringLiteral("A"));
    sctx.game_add_filepath(*a, touch(dir, QStringLiteral("a.gba")));
    model::Game* b = sctx.create_game_for(gba);
    b->setTitle(QStringLiteral("B"));
    sctx.game_add_filepath(*b, touch(dir, QStringLiteral("b.gba")));
    model::Game* c = sctx.create_game_for(android);
    c->setTitle(QStringLiteral("C"));
    sctx.game_add_uri(*c, QStringLiteral("android:com.example.c"));

    return sctx.finalize(this->thread());
}

void test_UserCollections::apply_puts_them_after_the_system()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    auto [collections, games] = library(dir);
    model::Game* a = by_title(games, QStringLiteral("A"));
    model::Game* c = by_title(games, QStringLiteral("C"));
    QVERIFY(a && c);

    // "Zelda" is new; "android" adds A to the existing Android collection (any case); "Gone" has no game found
    const QString path = dir.filePath(QStringLiteral("collections.json"));
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(QJsonDocument(QJsonObject { { QStringLiteral("collections"), QJsonArray {
        QJsonObject { { QStringLiteral("name"), QStringLiteral("Zelda") },
                      { QStringLiteral("games"), QJsonArray { deckos::GameOverrides::keyFor(*a),
                                                              deckos::GameOverrides::keyFor(*c) } } },
        QJsonObject { { QStringLiteral("name"), QStringLiteral("android") },
                      { QStringLiteral("games"), QJsonArray { deckos::GameOverrides::keyFor(*a) } } },
        QJsonObject { { QStringLiteral("name"), QStringLiteral("Gone") },
                      { QStringLiteral("games"), QJsonArray { QStringLiteral("file:/nowhere.gba") } } },
    } } }).toJson());
    file.close();

    deckos::UserCollections user(nullptr, path);
    user.apply(collections, games);

    QStringList all;
    for (const model::Collection* coll : collections)
        all << coll->name();
    QCOMPARE(all, (QStringList { QStringLiteral("Android"), QStringLiteral("GBA"), QStringLiteral("Zelda") }));

    // the game's own collection stays first (its system), the user's follow
    QCOMPARE(names(a->collectionsModel()),
             (QStringList { QStringLiteral("GBA"), QStringLiteral("Zelda"), QStringLiteral("Android") }));
    QCOMPARE(names(c->collectionsModel()), (QStringList { QStringLiteral("Android"), QStringLiteral("Zelda") }));

    const model::Collection* zelda = collections.back();
    QCOMPARE(zelda->gameList()->count(), 2);
    const model::Collection* android = collections.front();
    QCOMPARE(android->gameList()->count(), 2);
}

void test_UserCollections::add_and_remove_while_running()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    auto [collections, games] = library(dir);
    model::Game* a = by_title(games, QStringLiteral("A"));
    model::Game* b = by_title(games, QStringLiteral("B"));
    QVERIFY(a && b);

    model::ApiObject api(backend::CliArgs {});
    api.setGameData(std::move(collections), std::vector<model::Game*>(games));
    const QString path = dir.filePath(QStringLiteral("deckos/collections.json"));
    deckos::UserCollections user(&api, path);
    QSignalSpy changed(&user, &deckos::UserCollections::changed);

    // a new collection: in the library's list at once, sorted, and saved
    QCOMPARE(user.add(a, QStringLiteral("  My   Games ")), QString());
    QCOMPARE(names(api.collections()),
             (QStringList { QStringLiteral("Android"), QStringLiteral("GBA"), QStringLiteral("My Games") }));
    QCOMPARE(names(a->collectionsModel()), (QStringList { QStringLiteral("GBA"), QStringLiteral("My Games") }));
    QCOMPARE(changed.count(), 1);
    QVERIFY(QFileInfo::exists(path));

    // the same name in another case is the same collection
    QCOMPARE(user.existingName(QStringLiteral("my games")), QStringLiteral("My Games"));
    QCOMPARE(user.add(b, QStringLiteral("MY GAMES")), QString());
    QCOMPARE(api.collections()->count(), 3);
    QCOMPARE(static_cast<model::Collection*>(api.collections()->get(2))->gameList()->count(), 2);

    // the picker's rows
    QVariantList rows = user.forGame(a);
    QCOMPARE(rows.size(), 3);
    QVariantMap mine = rows.at(2).toMap();
    QCOMPARE(mine.value(QStringLiteral("name")).toString(), QStringLiteral("My Games"));
    QVERIFY(mine.value(QStringLiteral("member")).toBool());
    QVERIFY(mine.value(QStringLiteral("mine")).toBool());
    QCOMPARE(mine.value(QStringLiteral("count")).toInt(), 2);
    QVariantMap system = rows.at(1).toMap();
    QVERIFY(system.value(QStringLiteral("member")).toBool());
    QVERIFY(!system.value(QStringLiteral("mine")).toBool());

    // the library's collection can't be taken away, an empty name is refused
    QVERIFY(!user.remove(a, QStringLiteral("GBA")));
    QVERIFY(!user.add(a, QStringLiteral("   ")).isEmpty());

    // another start: the saved file puts them back
    {
        deckos::UserCollections reloaded(nullptr, path);
        QCOMPARE(reloaded.forGame(a).size(), 0); // no api: nothing to list, but it loads
    }

    // out again; the emptied collection leaves the list
    QVERIFY(user.remove(a, QStringLiteral("My Games")));
    QCOMPARE(names(a->collectionsModel()), QStringList { QStringLiteral("GBA") });
    QCOMPARE(api.collections()->count(), 3);
    QVERIFY(user.remove(b, QStringLiteral("my games")));
    QCOMPARE(names(api.collections()), (QStringList { QStringLiteral("Android"), QStringLiteral("GBA") }));
    QCOMPARE(changed.count(), 4);

    QFile saved(path);
    QVERIFY(saved.open(QIODevice::ReadOnly));
    QVERIFY(QJsonDocument::fromJson(saved.readAll()).object().value(QStringLiteral("collections")).toArray().isEmpty());
}

void test_UserCollections::hide_and_rename()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    const QString path = dir.filePath(QStringLiteral("collections.json"));

    {
        auto [collections, games] = library(dir);
        model::ApiObject api(backend::CliArgs {});
        deckos::UserCollections user(&api, path);
        user.apply(collections, games); // nothing saved yet: the library's own names
        api.setGameData(std::move(collections), std::vector<model::Game*>(games));
        model::Game* a = by_title(games, QStringLiteral("A"));

        // a library collection renamed: its short name (the system) stays
        QCOMPARE(user.rename(QStringLiteral("gba"), QStringLiteral("Handhelds")), QString());
        QCOMPARE(names(api.collections()), (QStringList { QStringLiteral("Android"), QStringLiteral("Handhelds") }));
        QCOMPARE(a->collectionsModel()->entries().front()->shortName(), QStringLiteral("gba"));
        QVERIFY(!user.rename(QStringLiteral("Handhelds"), QStringLiteral("android")).isEmpty()); // taken

        // hidden: out of the list, the games keep it
        QVERIFY(user.setHidden(QStringLiteral("Android"), true));
        QCOMPARE(names(api.collections()), QStringList { QStringLiteral("Handhelds") });
        QCOMPARE(user.allCollections().size(), 2);
        QVERIFY(user.allCollections().at(0).toMap().value(QStringLiteral("hidden")).toBool());
        QCOMPARE(user.existingName(QStringLiteral("ANDROID")), QStringLiteral("Android"));
    }

    // the next start: renamed and hidden again
    auto [collections, games] = library(dir);
    model::ApiObject api(backend::CliArgs {});
    deckos::UserCollections user(&api, path);
    user.apply(collections, games);
    QStringList all;
    for (const model::Collection* coll : collections)
        all << coll->name();
    QCOMPARE(all, QStringList { QStringLiteral("Handhelds") });
    api.setGameData(std::move(collections), std::vector<model::Game*>(games));

    QVERIFY(user.setHidden(QStringLiteral("android"), false));
    QCOMPARE(names(api.collections()), (QStringList { QStringLiteral("Android"), QStringLiteral("Handhelds") }));
    // renamed back to its own name: nothing left to remember
    QCOMPARE(user.rename(QStringLiteral("Handhelds"), QStringLiteral("GBA")), QString());
    QFile saved(path);
    QVERIFY(saved.open(QIODevice::ReadOnly));
    const QJsonObject root = QJsonDocument::fromJson(saved.readAll()).object();
    QVERIFY(root.value(QStringLiteral("renames")).toObject().isEmpty());
    QVERIFY(root.value(QStringLiteral("hidden")).toArray().isEmpty());
}


QTEST_MAIN(test_UserCollections)
#include "test_UserCollections.moc"
