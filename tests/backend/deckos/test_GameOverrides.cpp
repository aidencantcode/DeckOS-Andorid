// DeckOS
// Tests for deckos::GameOverrides: the store of per-game edits and scraped data.

#include <QtTest/QtTest>

#include "Log.h"
#include "deckos/GameOverrides.h"
#include "model/gaming/Assets.h"
#include "model/gaming/Game.h"

#include <QJsonArray>
#include <QSignalSpy>
#include <QTemporaryDir>


class test_GameOverrides : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { Log::init_qttest(); }

    void update_merges_and_saves();
    void null_removes_fields();
    void remove_forgets_game();
    void apply_and_restore();
    void apply_keeps_first_original();
};

void test_GameOverrides::update_merges_and_saves()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    const QString path = dir.filePath(QStringLiteral("deckos/game_overrides.json"));

    {
        deckos::GameOverrides store(path);
        store.update(QStringLiteral("file:/a.sfc"), { { QStringLiteral("title"), QStringLiteral("A") } });
        store.update(QStringLiteral("file:/a.sfc"), {
            { QStringLiteral("description"), QStringLiteral("Text") },
            { QStringLiteral("assets"), QJsonObject { { QStringLiteral("logo"), QStringLiteral("file:///l.png") } } },
        });
        store.update(QStringLiteral("file:/a.sfc"), {
            { QStringLiteral("assets"), QJsonObject { { QStringLiteral("poster"), QStringLiteral("file:///p.png") } } },
        });
    }

    // a new store on the same file sees everything, assets merged rather than replaced
    deckos::GameOverrides reloaded(path);
    const QJsonObject entry = reloaded.entry(QStringLiteral("file:/a.sfc"));
    QCOMPARE(entry.value(QStringLiteral("title")).toString(), QStringLiteral("A"));
    QCOMPARE(entry.value(QStringLiteral("description")).toString(), QStringLiteral("Text"));
    const QJsonObject assets = entry.value(QStringLiteral("assets")).toObject();
    QCOMPARE(assets.value(QStringLiteral("logo")).toString(), QStringLiteral("file:///l.png"));
    QCOMPARE(assets.value(QStringLiteral("poster")).toString(), QStringLiteral("file:///p.png"));
    QCOMPARE(reloaded.keys(), QStringList { QStringLiteral("file:/a.sfc") });
}

void test_GameOverrides::null_removes_fields()
{
    QTemporaryDir dir;
    deckos::GameOverrides store(dir.filePath(QStringLiteral("o.json")));
    store.update(QStringLiteral("k"), {
        { QStringLiteral("title"), QStringLiteral("A") },
        { QStringLiteral("assets"), QJsonObject { { QStringLiteral("logo"), QStringLiteral("x") } } },
    });
    store.update(QStringLiteral("k"), {
        { QStringLiteral("title"), QJsonValue::Null },
        { QStringLiteral("assets"), QJsonObject { { QStringLiteral("logo"), QJsonValue::Null } } },
    });
    // nothing left -> the game is not stored at all
    QVERIFY(store.entry(QStringLiteral("k")).isEmpty());
    QVERIFY(store.keys().isEmpty());
}

void test_GameOverrides::remove_forgets_game()
{
    QTemporaryDir dir;
    deckos::GameOverrides store(dir.filePath(QStringLiteral("o.json")));
    store.update(QStringLiteral("k1"), { { QStringLiteral("title"), QStringLiteral("A") } });
    store.update(QStringLiteral("k2"), { { QStringLiteral("title"), QStringLiteral("B") } });
    store.remove(QStringLiteral("k1"));
    QCOMPARE(store.keys(), QStringList { QStringLiteral("k2") });
}

void test_GameOverrides::apply_and_restore()
{
    model::Game game(QStringLiteral("Original"));
    game.setDescription(QStringLiteral("Old text"));
    game.assetsMut().add_uri(AssetType::LOGO, QStringLiteral("file:///other/logo.png"));
    QSignalSpy meta(&game, &model::Game::metadataChanged);
    QSignalSpy assets(game.assetsPtr(), &model::Assets::changed);

    const QString scraped_logo = QUrl::fromLocalFile(deckos::GameOverrides::mediaDir() + QStringLiteral("/snes/x/logo-1.png")).toString();
    deckos::GameOverrides::apply(game, {
        { QStringLiteral("title"), QStringLiteral("New") },
        { QStringLiteral("description"), QStringLiteral("New text") },
        { QStringLiteral("release"), QStringLiteral("1995-08-22") },
        { QStringLiteral("developer"), QJsonArray { QStringLiteral("Square") } },
        { QStringLiteral("players"), 2 },
        { QStringLiteral("assets"), QJsonObject { { QStringLiteral("logo"), scraped_logo } } },
    }, true);

    QCOMPARE(game.title(), QStringLiteral("New"));
    QCOMPARE(game.sortBy(), QStringLiteral("New"));
    QCOMPARE(game.description(), QStringLiteral("New text"));
    QCOMPARE(game.summary(), QStringLiteral("New text")); // themes show summary first
    QCOMPARE(game.releaseDate(), QDate(1995, 8, 22));
    QCOMPARE(game.developerStr(), QStringLiteral("Square"));
    QCOMPARE(game.playerCount(), 2);
    QCOMPARE(game.assets().logo(), scraped_logo); // the scraped one is shown first
    QCOMPARE(game.assets().logoList().size(), 2);
    QCOMPARE(meta.count(), 1);
    QVERIFY(assets.count() >= 1);

    deckos::GameOverrides::restore(game);
    QCOMPARE(game.title(), QStringLiteral("Original"));
    QCOMPARE(game.description(), QStringLiteral("Old text"));
    QCOMPARE(game.assets().logo(), QStringLiteral("file:///other/logo.png")); // other sources' files stay
    QCOMPARE(game.assets().logoList().size(), 1);
}

void test_GameOverrides::apply_keeps_first_original()
{
    model::Game game(QStringLiteral("Original"));
    deckos::GameOverrides::apply(game, { { QStringLiteral("title"), QStringLiteral("First") } }, false);
    deckos::GameOverrides::apply(game, { { QStringLiteral("title"), QStringLiteral("Second") } }, false);
    QCOMPARE(game.title(), QStringLiteral("Second"));
    deckos::GameOverrides::restore(game);
    QCOMPARE(game.title(), QStringLiteral("Original"));
}


QTEST_MAIN(test_GameOverrides)
#include "test_GameOverrides.moc"
