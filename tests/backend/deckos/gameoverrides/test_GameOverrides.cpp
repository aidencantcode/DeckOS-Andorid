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
    void custom_beats_scraped();
    void custom_screenshots_first();
    void media_dir_and_names();
    void record_round_trip();
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


// DECKOS 0.1.1: the user's own files ("custom") are shown before scraped ones, whatever the order in the file
void test_GameOverrides::custom_beats_scraped()
{
    model::Game game(QStringLiteral("Game"));
    const QString media = deckos::GameOverrides::mediaDir() + QStringLiteral("/snes/x/");
    const QString scraped = QUrl::fromLocalFile(media + QStringLiteral("hero.png")).toString() + QStringLiteral("?v=1");
    const QString mine = QUrl::fromLocalFile(media + QStringLiteral("custom-hero.png")).toString() + QStringLiteral("?v=2");
    deckos::GameOverrides::apply(game, {
        { QStringLiteral("custom"), QJsonObject { { QStringLiteral("background"), mine } } },
        { QStringLiteral("assets"), QJsonObject { { QStringLiteral("background"), scraped } } },
    }, false);
    QCOMPARE(game.assets().background(), mine);
    QCOMPARE(game.assets().backgroundList().size(), 2);

    deckos::GameOverrides::restore(game); // both are DeckOS's own files: neither stays
    QVERIFY(game.assets().background().isEmpty());
}

void test_GameOverrides::custom_screenshots_first()
{
    model::Game game(QStringLiteral("Game"));
    game.assetsMut().add_uri(AssetType::SCREENSHOT, QStringLiteral("file:///roms/snes/shot.png"));
    const QString media = deckos::GameOverrides::mediaDir() + QStringLiteral("/snes/x/");
    const QString scraped = QUrl::fromLocalFile(media + QStringLiteral("screenshot-01.png")).toString();
    const QString mine = QUrl::fromLocalFile(media + QStringLiteral("custom-screenshot-01.png")).toString();
    const QJsonObject entry {
        { QStringLiteral("assets"), QJsonObject { { QStringLiteral("screenshot"), QJsonArray { scraped } } } },
        { QStringLiteral("custom"), QJsonObject { { QStringLiteral("screenshot"), QJsonArray { mine } } } },
    };
    deckos::GameOverrides::apply(game, entry, false);
    deckos::GameOverrides::apply(game, entry, false); // a second load doesn't add them twice
    const QStringList shots = game.assets().screenshotList();
    QCOMPARE(shots, (QStringList { QStringLiteral("file:///roms/snes/shot.png"), mine, scraped }));
}

void test_GameOverrides::media_dir_and_names()
{
    QCOMPARE(deckos::GameOverrides::fileStem(QStringLiteral("background")), QStringLiteral("hero"));
    QCOMPARE(deckos::GameOverrides::fileStem(QStringLiteral("poster")), QStringLiteral("capsule"));
    QCOMPARE(deckos::GameOverrides::fileStem(QStringLiteral("steam")), QStringLiteral("wide-capsule"));
    QCOMPARE(deckos::GameOverrides::fileStem(QStringLiteral("video")), QStringLiteral("trailer"));
    QCOMPARE(deckos::GameOverrides::fileStem(QStringLiteral("logo")), QStringLiteral("logo"));
    QCOMPARE(deckos::GameOverrides::safeName(QStringLiteral("Zelda: Link's \"Awakening\"")), QStringLiteral("Zelda_ Link_s _Awakening_"));

    QTemporaryDir dir;
    const QString legacy_uri = QUrl::fromLocalFile(deckos::GameOverrides::legacyMediaDir() + QStringLiteral("/a/b.png")).toString();
    deckos::GameOverrides::setMediaDir(dir.path() + QStringLiteral("/media"));
    QCOMPARE(deckos::GameOverrides::gameMediaDir(QString(), QStringLiteral("Game")), dir.path() + QStringLiteral("/media/other/Game"));
    QVERIFY(deckos::GameOverrides::isOwnMedia(QUrl::fromLocalFile(dir.path() + QStringLiteral("/media/snes/x/hero.png")).toString() + QStringLiteral("?v=3")));
    QVERIFY(deckos::GameOverrides::isOwnMedia(legacy_uri)); // still known: what was saved before moves in
    QVERIFY(!deckos::GameOverrides::isOwnMedia(QStringLiteral("file:///roms/snes/hero.png")));
    QVERIFY(!deckos::GameOverrides::isOwnMedia(QUrl::fromLocalFile(dir.path() + QStringLiteral("/media-other/x.png")).toString()));
    deckos::GameOverrides::setMediaDir(QString());
    QCOMPARE(deckos::GameOverrides::mediaDir(), deckos::GameOverrides::legacyMediaDir());
}

void test_GameOverrides::record_round_trip()
{
    QTemporaryDir dir;
    deckos::GameOverrides::setMediaDir(dir.path() + QStringLiteral("/media"));
    const QString game_dir = dir.path() + QStringLiteral("/media/snes/Chrono Trigger (USA)");
    QDir().mkpath(game_dir);
    for (const char* name : { "capsule.png", "custom-hero.png", "screenshot-01.png", "screenshot-02.png" }) {
        QFile f(game_dir + QLatin1Char('/') + QLatin1String(name));
        QVERIFY(f.open(QIODevice::WriteOnly));
    }
    auto uri = [&game_dir](const char* name) {
        return QUrl::fromLocalFile(game_dir + QLatin1Char('/') + QLatin1String(name)).toString() + QStringLiteral("?v=1");
    };
    const QString key = QStringLiteral("file:/roms/snes/Chrono Trigger (USA).sfc");
    {
        deckos::GameOverrides store(dir.filePath(QStringLiteral("o.json")));
        store.update(key, QJsonObject {
            { QStringLiteral("description"), QStringLiteral("Line one\n\nLine three") },
            { QStringLiteral("developer"), QJsonArray { QStringLiteral("Square"), QStringLiteral("Akira") } },
            { QStringLiteral("publisher"), QStringLiteral("Square") },
            { QStringLiteral("players"), 1 },
            { QStringLiteral("shots"), true },
            { QStringLiteral("assets"), QJsonObject {
                { QStringLiteral("poster"), uri("capsule.png") },
                { QStringLiteral("screenshot"), QJsonArray { uri("screenshot-01.png"), uri("screenshot-02.png") } } } },
            { QStringLiteral("custom"), QJsonObject { { QStringLiteral("background"), uri("custom-hero.png") } } },
        });
        QCOMPARE(store.takeChangedSinceReload(), QStringList { key });
        QVERIFY(store.takeChangedSinceReload().isEmpty());
    }

    const QString record = game_dir + QStringLiteral("/game.txt");
    QVERIFY(QFileInfo::exists(record));
    QString file;
    const QJsonObject back = deckos::GameOverrides::readRecord(record, &file);
    QCOMPARE(file, QStringLiteral("/roms/snes/Chrono Trigger (USA).sfc"));
    QCOMPARE(back.value(QStringLiteral("description")).toString(), QStringLiteral("Line one\n\nLine three"));
    QCOMPARE(back.value(QStringLiteral("developer")).toArray().size(), 2);
    QCOMPARE(back.value(QStringLiteral("publisher")).toString(), QStringLiteral("Square"));
    QCOMPARE(back.value(QStringLiteral("players")).toInt(), 1);
    QCOMPARE(back.value(QStringLiteral("shots")).toBool(), true);
    const QJsonObject assets = back.value(QStringLiteral("assets")).toObject();
    QCOMPARE(QUrl(assets.value(QStringLiteral("poster")).toString()).toLocalFile(), game_dir + QStringLiteral("/capsule.png"));
    QCOMPARE(assets.value(QStringLiteral("screenshot")).toArray().size(), 2);
    QCOMPARE(QUrl(back.value(QStringLiteral("custom")).toObject().value(QStringLiteral("background")).toString()).toLocalFile(),
             game_dir + QStringLiteral("/custom-hero.png"));

    // forgetting the game takes its record too
    {
        deckos::GameOverrides store(dir.filePath(QStringLiteral("o.json")));
        store.remove(key);
    }
    QVERIFY(!QFileInfo::exists(record));
    deckos::GameOverrides::setMediaDir(QString());
}

QTEST_MAIN(test_GameOverrides)
#include "test_GameOverrides.moc"
