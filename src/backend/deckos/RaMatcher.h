// DeckOS
// Finds a game's RetroAchievements entry by ROM hash, the way RetroArch does: rcheevos
// (thirdparty/rcheevos) hashes the ROM, and RA's hash list for that console (API_GetGameList with
// h=1, verified 2026-11-25) says which RA game that exact dump belongs to. Lists are cached for a
// week in <config>/deckos/ra/, ROM hashes by path + size + date, so a game is hashed only once.
// The RA tab falls back to matching by title when this finds nothing.

#pragma once

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QPair>
#include <QPointer>
#include <QSet>
#include <QThreadPool>
#include <QVector>

#include <memory>

class QNetworkAccessManager;
class QTimer;


namespace deckos {

/// The RA console id of a game system ("snes", "Super Nintendo", "megadrive"...); 0 = not on RA.
int ra_console_for(const QString& short_name, const QString& name = {});

/// The RA hash of a ROM, or empty if it can't be hashed (`error` says why).
/// Zipped cartridge ROMs are hashed by the game inside the zip, as RetroArch does.
QString ra_hash_file(const QString& path, int console_id, QString* error = nullptr);


class RaMatcher : public QObject {
    Q_OBJECT

public:
    explicit RaMatcher(QObject* parent = nullptr);
    /// with another cache folder (tests)
    RaMatcher(const QString& cache_dir, QObject* parent);
    ~RaMatcher() override;

    /// Looks up the RA game of a game's ROM by its hash; answers with identified().
    Q_INVOKABLE void identify(QObject* game, const QString& apiKey);
    /// The RA console id of a game's system, 0 if RetroAchievements doesn't cover it.
    Q_INVOKABLE int consoleOf(QObject* game) const;

signals:
    /// method: "hash"        RA knows this exact dump (gameId > 0, title is RA's)
    ///         "unknown"     hashed, but no RA game has this hash (another dump, a hack, no set yet)
    ///         "unsupported" can't be hashed: no local file, system not on RA, unreadable, .7z...
    ///         "offline"     RA's list for the console couldn't be loaded and isn't cached
    /// detail: the hash, or why it couldn't be found.
    void identified(QObject* game, int gameId, const QString& title, const QString& method, const QString& detail);

private:
    struct Request {
        QPointer<QObject> game;
        int console = 0;
        QString hash;
        QString key;
    };
    struct ConsoleList {
        bool loaded = false;
        QDateTime fetched;
        QHash<QString, QPair<int, QString>> games; // hash -> (RA game id, title)
    };
    struct RomHash {
        qint64 size = 0;
        qint64 mtime = 0;
        int console = 0;
        QString hash;
    };

    const QString m_dir;
    QNetworkAccessManager* const m_net;
    QTimer* const m_save_timer;

    bool m_rom_hashes_loaded = false;
    QHash<QString, RomHash> m_rom_hashes;  // ROM path -> its hash
    QHash<int, ConsoleList> m_lists;       // console -> RA's hash list
    QHash<int, QVector<Request>> m_waiting; // console -> lookups waiting for its list download
    QSet<int> m_downloaded;                // consoles whose list was (tried to be) downloaded this run
    QHash<QString, QVector<Request>> m_hash_waiting; // ROM path being hashed -> lookups waiting for it
    QThreadPool m_pool;                    // hashing runs here, off the UI thread

    void onHashed(const QString& path, const RomHash& entry, const QString& error);
    void lookup(const Request& req);
    void finish(const Request& req);
    void download(int console, const QString& key);
    void downloadPage(int console, const QString& key, int offset,
                      std::shared_ptr<QHash<QString, QPair<int, QString>>> games);
    void listDownloaded(int console, const QHash<QString, QPair<int, QString>>* games); // null = failed

    ConsoleList& list(int console);
    void saveList(int console) const;
    void loadRomHashes();
    void saveRomHashes() const;
};

} // namespace deckos
