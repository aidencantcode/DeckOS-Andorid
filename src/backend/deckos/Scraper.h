// DeckOS
// Fetches artwork and game info for games in the library and stores it as DeckOS game changes
// (GameOverrides), so it shows up immediately and on every later start.
//
// Sources, per game, in this order (each needs nothing but what is listed):
//   1. TheGamesDB (user's API key): description, release date, players, front box art
//   2. SteamGridDB (user's API key): 600x900 capsule (poster), wide capsule (steam), hero (background), logo
//   3. libretro-thumbnails on GitHub (no key; needs a No-Intro style file name): box art, screenshot, title screen
// One game at a time, requests one after another, with a short pause between games. TheGamesDB keys
// have a monthly allowance (~1000 lookups), so each game is looked up once; "Scrape this game" forces it.

#pragma once

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QQueue>
#include <QSet>
#include <QStringList>
#include <QVariantMap>
#include <functional>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;
namespace model { class ApiObject; }
namespace model { class Game; }


namespace deckos {

class Scraper : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool running READ running NOTIFY progressChanged)
    Q_PROPERTY(int done READ done NOTIFY progressChanged)
    Q_PROPERTY(int total READ total NOTIFY progressChanged)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY progressChanged)
    Q_PROPERTY(QString status READ status NOTIFY progressChanged)
    /// TheGamesDB lookups left this month (-1 = unknown until the first lookup)
    Q_PROPERTY(int theGamesDbAllowance READ theGamesDbAllowance NOTIFY progressChanged)

    Q_PROPERTY(QString steamGridDbKey READ steamGridDbKey WRITE setSteamGridDbKey NOTIFY settingsChanged)
    Q_PROPERTY(QString theGamesDbKey READ theGamesDbKey WRITE setTheGamesDbKey NOTIFY settingsChanged)
    Q_PROPERTY(bool autoScrape READ autoScrape WRITE setAutoScrape NOTIFY settingsChanged)
    Q_PROPERTY(bool fetchDescriptions READ fetchDescriptions WRITE setFetchDescriptions NOTIFY settingsChanged)
    Q_PROPERTY(bool useLibretroThumbnails READ useLibretroThumbnails WRITE setUseLibretroThumbnails NOTIFY settingsChanged)

public:
    explicit Scraper(model::ApiObject* api, QObject* parent = nullptr);

    /// Scrapes one game now (front of the queue), replacing what DeckOS scraped for it before.
    Q_INVOKABLE void scrapeGame(QObject* game);
    /// Queues every game; with onlyMissing, only games that lack something and were never tried.
    /// Returns how many games were queued.
    /// collections: only games in these collections (by name); empty = every game.
    /// skipWithMedia: games that already have artwork (a cover, hero, logo or wide capsule - an Android
    /// app's own icon doesn't count) are left out, so a re-scrape only fills the gaps.
    Q_INVOKABLE int scrapeAll(bool onlyMissing, const QStringList& collections = {}, bool skipWithMedia = false);
    Q_INVOKABLE void cancel();

    /// <DeckOS folder>/keys.txt, else <config>/api-keys.env - KEY=VALUE lines (STEAMGRIDDB_API_KEY, THEGAMESDB_API_KEY, RA_USERNAME,
    /// RA_WEB_API_KEY). importKeys() stores the scraper keys and returns
    /// { found: <count>, path, error, raUser, raKey } so the interface can save the RA account.
    Q_INVOKABLE QString keysFilePath() const;
    Q_INVOKABLE QVariantMap importKeys();

    /// called when a library load finishes: starts the auto-scrape if it is on
    void onLibraryReady();

    bool running() const { return m_current != nullptr; }
    int done() const { return m_done; }
    int total() const { return m_total; }
    QString currentTitle() const;
    const QString& status() const { return m_status; }
    int theGamesDbAllowance() const { return m_tgdb_allowance; }

    const QString& steamGridDbKey() const { return m_sgdb_key; }
    const QString& theGamesDbKey() const { return m_tgdb_key; }
    bool autoScrape() const { return m_auto; }
    bool fetchDescriptions() const { return m_descriptions; }
    bool useLibretroThumbnails() const { return m_libretro; }
    void setSteamGridDbKey(const QString&);
    void setTheGamesDbKey(const QString&);
    void setAutoScrape(bool);
    void setFetchDescriptions(bool);
    void setUseLibretroThumbnails(bool);

signals:
    void progressChanged();
    void settingsChanged();
    void gameFinished(QObject* game, bool ok, const QString& message);

private:
    struct Job;

    model::ApiObject* const m_api;
    QNetworkAccessManager* const m_net;
    QTimer* const m_next_timer;

    QQueue<Job*> m_queue;
    Job* m_current = nullptr;
    QSet<QString> m_queued_keys;
    int m_done = 0;
    int m_total = 0;
    QString m_status;
    int m_tgdb_allowance = -1;
    QHash<QString, QHash<int, QString>> m_tgdb_names; // "developers"/"publishers"/"genres" -> id -> name
    QSet<QString> m_tgdb_names_tried;

    QString m_sgdb_key;
    QString m_tgdb_key;
    bool m_auto = false;
    bool m_descriptions = true;
    bool m_libretro = true;

    Job* makeJob(model::Game&, bool force);
    void enqueue(Job*, bool front);
    void startNext();
    void finishJob(bool ok, const QString& message);

    void stepTheGamesDb();
    void stepTheGamesDbNames(int index);
    void stepTheGamesDbScreenshots();
    void stepSteamGridDbSearch();
    void stepSteamGridDbAssets(int game_id, int step);
    void stepLibretro();
    void stepDownload();

    QNetworkReply* get(const QString& url, bool sgdb_auth = false);
    void whenDone(QNetworkReply*, std::function<void(QNetworkReply*)>);

    void loadTheGamesDbNames();
    void saveTheGamesDbNames() const;
    void loadSettings();
    void saveSettings() const;
    void setStatus(const QString&);
};

} // namespace deckos
