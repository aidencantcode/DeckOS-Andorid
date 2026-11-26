// DeckOS
// The `deckos` object themes see: editing a game's name/description and the scraper.

#pragma once

#include <QObject>
#include <QVariantMap>

namespace model { class ApiObject; class GameFile; }


namespace deckos {

class Scraper;
class RomLibrary;
class RaMatcher;
class InGame;
class Underclock;
class MediaLibrary;
class UserCollections;

class DeckosApi : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* scraper READ scraperObj CONSTANT)
    Q_PROPERTY(QObject* library READ libraryObj CONSTANT)
    /// RetroAchievements game matching by ROM hash (RaMatcher.h)
    Q_PROPERTY(QObject* ra READ raObj CONSTANT)
    /// Android in-game layer settings: performance overlay level, notification, overlay permission
    Q_PROPERTY(QObject* ingame READ ingameObj CONSTANT)
    /// underclocking: ClusterTune built in (Settings > Underclocking; Underclock.h)
    Q_PROPERTY(QObject* underclock READ underclockObj CONSTANT)
    /// the DeckOS folder (media, keys.txt, logs) and the user's own artwork (MediaLibrary.h)
    Q_PROPERTY(QObject* media READ mediaObj CONSTANT)
    /// the user's collections: Add to collection... on the game page (UserCollections.h)
    Q_PROPERTY(QObject* collections READ collectionsObj CONSTANT)

public:
    explicit DeckosApi(model::ApiObject* api, QObject* parent = nullptr);

    /// New name / description for a game (empty = back to what the game's metadata says).
    /// Saved at once and shown everywhere; kept across library reloads and restarts.
    Q_INVOKABLE void setGameTitle(QObject* game, const QString& title);
    Q_INVOKABLE void setGameDescription(QObject* game, const QString& text);
    /// Forgets every DeckOS change to this game (edits and scraped info/artwork).
    Q_INVOKABLE void resetGame(QObject* game);
    /// { edited: bool, titleEdited, descriptionEdited, scraped: ISO date or "", sources: "TheGamesDB, ..." }
    Q_INVOKABLE QVariantMap gameChanges(QObject* game) const;

    /// The command a game launches with, a hand-written one for it (empty = back to its system's),
    /// and "Launch with...": the emulators known for its system, or one of them for this game only.
    Q_INVOKABLE QString gameLaunchCommand(QObject* game) const;
    Q_INVOKABLE void setGameLaunchCommand(QObject* game, const QString& command);
    Q_INVOKABLE QVariantList gameEmulators(QObject* game) const;
    Q_INVOKABLE void setGameEmulator(QObject* game, const QString& emulatorId);

    /// Reloads the library: from the game index cache if no game folder or metadata file changed
    /// (seconds), otherwise a full scan. Settings > Library > "Reload all games" forces a full scan.
    Q_INVOKABLE void refreshLibrary();

    /// The game's own screenshots, newest first: RetroArch's (named after the ROM, next to it or in
    /// RetroArch's screenshots folder) and DeckOS's (<config>/deckos/screenshots/<rom name>/).
    /// Each entry: { url, time (ms since epoch) }. At most `limit`.
    Q_INVOKABLE QVariantList gameScreenshots(QObject* game, int limit = 12) const;

    Scraper* scraper() const { return m_scraper; }
    QObject* scraperObj() const;
    QObject* libraryObj() const;
    QObject* raObj() const;
    QObject* ingameObj() const;
    QObject* underclockObj() const;
    QObject* mediaObj() const;
    QObject* collectionsObj() const;
    InGame* ingame() const { return m_ingame; }
    UserCollections* collections() const { return m_collections; }

    void onLibraryReady();
    /// a game is about to start (before the launcher): hands it to the in-game layer
    void onGameLaunching(const model::GameFile* file);

signals:
    void libraryRefreshRequested();

private:
    Scraper* const m_scraper;
    RomLibrary* const m_library;
    RaMatcher* const m_ra;
    InGame* const m_ingame;
    Underclock* const m_underclock;
    MediaLibrary* const m_media;
    UserCollections* const m_collections;
    bool m_started = false;
};

} // namespace deckos
