// DeckOS
// The DeckOS folder: one folder the user picks at the first start (or in Settings > Library). It holds
// everything of theirs that DeckOS keeps, readable and changeable from any file manager:
//   media/<system>/<rom name>/   artwork, trailers and screenshots - what the scraper saved (hero.png,
//                                logo.png, capsule.png, wide-capsule.png, boxart.jpg, screenshot-01.png...)
//                                and the user's own (custom-hero.png...), which win over scraped ones
//   keys.txt                     API keys and accounts, KEY=VALUE; read again whenever it changed
//   logs/lastrun.log             a copy of DeckOS's log, for bug reports
// Until one is picked, scraped media stays in <config>/deckos/media as before; picking one moves it.
//
// Own artwork (Properties > Customization): a file picked with Android's file manager (pickFile) or
// DeckOS's own browser (assignFile) is copied into the game's media folder as custom-<name> and shown
// at once; clearCustom goes back to the scraped one.

#pragma once

#include <QObject>
#include <QPointer>
#include <QList>
#include <QString>
#include <QVariantList>

class QNetworkAccessManager;
class QTimer;
namespace model { class ApiObject; class Game; }


namespace deckos {

class MediaLibrary : public QObject {
    Q_OBJECT
    /// the DeckOS folder, "" until one is picked
    Q_PROPERTY(QString folder READ folder NOTIFY folderChanged)
    Q_PROPERTY(bool folderSet READ folderSet NOTIFY folderChanged)
    /// <folder>/keys.txt ("" without a folder)
    Q_PROPERTY(QString keysFile READ keysFile NOTIFY folderChanged)
    /// where a new DeckOS folder goes by default: the shared storage on Android, Documents on PC
    Q_PROPERTY(QString defaultParent READ defaultParent CONSTANT)
    /// Android's file manager can pick files (PC: only DeckOS's own browser)
    Q_PROPERTY(bool systemPicker READ systemPicker CONSTANT)
    /// a picked file is being copied
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit MediaLibrary(model::ApiObject* api, QObject* parent = nullptr);
    ~MediaLibrary() override;

    QString folder() const;
    bool folderSet() const { return !folder().isEmpty(); }
    QString keysFile() const { return keysFilePath(); }
    QString defaultParent() const;
    bool systemPicker() const;
    bool busy() const { return m_busy; }

    /// <folder>/keys.txt, "" without a DeckOS folder (Scraper::keysFilePath falls back to the old file)
    static QString keysFilePath();

    /// creates <parent>/<name>; its full path, or "" if it can't
    Q_INVOKABLE QString makeFolder(const QString& parent, const QString& name);
    /// makes `path` the DeckOS folder: creates media/ and logs/, a keys.txt to fill in if there is none,
    /// and moves the media saved so far into it. "" when done, else why not.
    Q_INVOKABLE QString setFolder(const QString& path);

    /// Customization's rows: one per asset (Hero, Logo, Capsule, Wide capsule, Box art, Icon, Trailer,
    /// Screenshots): { asset, label, hint, url (shown now), source ("custom", "scraped", "game", ""),
    /// file (local path of what's shown), count (screenshots), video }
    Q_INVOKABLE QVariantList artwork(QObject* game) const;
    /// copies `path` into the game's media folder as its own `asset` and shows it. "" when done, else why
    /// not. Screenshots are added; the others replace the user's earlier file.
    Q_INVOKABLE QString assignFile(QObject* game, const QString& asset, const QString& path);
    /// the same with a file picked in Android's file manager; the result comes as picked()
    Q_INVOKABLE void pickFile(QObject* game, const QString& asset);
    /// forgets the user's own `asset` (and deletes its files): the scraped one shows again
    Q_INVOKABLE void clearCustom(QObject* game, const QString& asset);
    /// DECKOS: pictures picked on the SteamGridDB page were kept as web addresses in the theme's memory
    /// (custom_assets_<title>) and loaded from the internet every time they showed - slow, gone offline,
    /// lost on a rename. Each is downloaded once and becomes the game's own picture (as if picked from
    /// storage); its address then leaves the memory, so every page shows the file. One game, or every
    /// game (after each library load).
    Q_INVOKABLE void localizeWebPicks(QObject* game = nullptr);

    /// keys.txt changed since it was last read (or was never read)
    Q_INVOKABLE bool keysChanged() const;
    Q_INVOKABLE void keysRead();
    /// copies the log into <folder>/logs (also when DeckOS goes to the background, and every few minutes)
    Q_INVOKABLE void saveLog() const;

signals:
    void folderChanged();
    void busyChanged();
    /// pickFile's result: error "" = done, "cancelled" = nothing picked
    void picked(QObject* game, const QString& asset, const QString& error);
    /// a game's own artwork changed (Customization reloads its rows)
    void artworkChanged(QObject* game);

private:
    model::ApiObject* const m_api;
    bool m_busy = false;
    QTimer* const m_log_timer;

    QString assign(model::Game& game, const QString& asset, const QString& path, bool move);
    void onPicked(QPointer<QObject> game, const QString& asset, const QString& uri);

    struct WebPick {
        QPointer<model::Game> game;
        QString memoryKey; // custom_assets_<title>
        QString slot;      // capsule, wideCapsule, logo, hero
        QString asset;     // poster, steam, logo, background
        QString url;
    };
    QList<WebPick> m_web_picks;
    bool m_web_busy = false;
    QNetworkAccessManager* m_net = nullptr;
    void queueWebPicks(model::Game&);
    void nextWebPick();
    void moveMedia(const QString& from, const QString& to);
};

} // namespace deckos
