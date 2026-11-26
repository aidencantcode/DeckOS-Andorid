// DeckOS
// The Android in-game layer (Java: src/app/platform/android/src/com/deckos/ingame): its settings for
// QML (`deckos.ingame`), and the game it shows. At every launch the game's title and system, the
// RetroAchievements account and the DeckOS profile go to Java (Session.setNowPlaying); the RA game id
// follows as soon as RaMatcher has found the ROM by its hash. On PC nothing runs; the settings
// page still works (values are only kept until DeckOS closes).

#pragma once

#include <QObject>
#include <QPointer>

namespace model { class ApiObject; class GameFile; }
class QTimer;


namespace deckos {

class RaMatcher;

class InGame : public QObject {
    Q_OBJECT
    /// false on PC: there's no in-game layer to drive
    Q_PROPERTY(bool available READ available CONSTANT)
    /// performance overlay over games: 0 = off, 1-4 = Steam Deck's levels
    Q_PROPERTY(int hudLevel READ hudLevel WRITE setHudLevel NOTIFY changed)
    /// the "Playing ..." notification while DeckOS is in the background (opens the overlay)
    Q_PROPERTY(bool notification READ notification WRITE setNotification NOTIFY changed)
    /// Android blocks DeckOS's notifications (or the in-game channel): the notification can't show
    Q_PROPERTY(bool notificationBlocked READ notificationBlocked NOTIFY changed)
    /// Android's "Display over other apps" permission, needed for the performance overlay
    Q_PROPERTY(bool overlayAllowed READ overlayAllowed NOTIFY changed)
    /// Android: keep the interface loaded while a game runs (instant return, real play time); off frees
    /// its memory for the game, as Pegasus did
    Q_PROPERTY(bool keepLoaded READ keepLoaded WRITE setKeepLoaded NOTIFY changed)
    /// a game started from DeckOS is running (Android, with keepLoaded): DeckOS is waiting for it
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    /// ...and DeckOS is back in front while it still runs (PServer / root sees its process): its page
    /// shows Resume and Stop, like Steam, until the game ends
    Q_PROPERTY(bool running READ running NOTIFY playingChanged)
    /// the game of the session (a Game), null without one
    Q_PROPERTY(QObject* runningGame READ runningGame NOTIFY playingChanged)
    /// its title (for when the library was reloaded meanwhile and the Game object changed)
    Q_PROPERTY(QString runningTitle READ runningTitle NOTIFY playingChanged)
    /// PServer / root: DeckOS can tell when a game ends, and stop it
    Q_PROPERTY(bool processTracking READ processTracking NOTIFY changed)
    /// play time counts while the game runs, like Steam (needs processTracking); off: only while it's in front
    Q_PROPERTY(bool countWhileRunning READ countWhileRunning WRITE setCountWhileRunning NOTIFY changed)

    // the overlay's own settings (its Overlay tab shows the same values: Java Session prefs)
    /// Quick Access and performance overlay size, percent of Steam Deck size (75-200)
    Q_PROPERTY(int overlayScale READ overlayScale WRITE setOverlayScale NOTIFY changed)
    /// Quick Access as an overlay window, so the game isn't paused
    Q_PROPERTY(bool keepRunning READ keepRunning WRITE setKeepRunning NOTIFY changed)
    /// controller shortcut: 0 off, 1 Select+Start, 2 Select+R1, 3 L3+R3
    Q_PROPERTY(int shortcut READ shortcut WRITE setShortcut NOTIFY changed)
    /// DeckOS's accessibility service (needed for the shortcut) is turned on
    Q_PROPERTY(bool shortcutEnabled READ shortcutEnabled NOTIFY changed)
    /// ...and Android actually started it (it can be on in the settings but blocked)
    Q_PROPERTY(bool shortcutRunning READ shortcutRunning NOTIFY changed)
    /// performance overlay corner: 0 top left, 1 top right, 2 bottom left, 3 bottom right
    Q_PROPERTY(int hudPosition READ hudPosition WRITE setHudPosition NOTIFY changed)
    Q_PROPERTY(bool showFps READ showFps WRITE setShowFps NOTIFY changed)
    /// AYN / Retroid's PServer, or root, is there (modes, underclocking, frame rate)
    Q_PROPERTY(bool privileged READ privileged NOTIFY changed)
    /// play time can tell which app is in front exactly: Android's usage access is given
    Q_PROPERTY(bool usageAccess READ usageAccess NOTIFY changed)
    /// the launch cover: the launch screen stays over the game while it loads, hiding the emulator's own
    /// loading screens (Android; Java LaunchCover)
    Q_PROPERTY(bool launchCover READ launchCover WRITE setLaunchCover NOTIFY changed)
    /// how long it stays, seconds (1-30)
    Q_PROPERTY(int launchCoverSeconds READ launchCoverSeconds WRITE setLaunchCoverSeconds NOTIFY changed)
    /// it can be shown: "Display over other apps" or DeckOS's accessibility service (PC: only with
    /// DECKOS_COVER_DUMP=<file.png> set, which saves the snapshot instead - for testing)
    Q_PROPERTY(bool launchCoverPossible READ launchCoverPossible NOTIFY changed)

public:
    InGame(model::ApiObject* api, RaMatcher* ra, QObject* parent = nullptr);

    bool available() const;
    int hudLevel() const;
    void setHudLevel(int level);
    bool notification() const;
    void setNotification(bool on);
    bool notificationBlocked() const;
    bool overlayAllowed() const;
    bool keepLoaded() const;
    void setKeepLoaded(bool on);
    bool playing() const { return m_playing; }
    bool running() const { return m_playing && m_background; }
    QObject* runningGame() const { return m_playing ? m_session_game.data() : nullptr; }
    QString runningTitle() const { return m_playing ? m_session_title : QString(); }
    bool processTracking() const;
    bool countWhileRunning() const;
    void setCountWhileRunning(bool on);
    int overlayScale() const;
    void setOverlayScale(int percent);
    bool keepRunning() const;
    void setKeepRunning(bool on);
    int shortcut() const;
    void setShortcut(int combo);
    bool shortcutEnabled() const;
    bool shortcutRunning() const;
    int hudPosition() const;
    void setHudPosition(int pos);
    bool showFps() const;
    void setShowFps(bool on);
    bool privileged() const;
    bool usageAccess() const;
    bool launchCover() const;
    void setLaunchCover(bool on);
    int launchCoverSeconds() const;
    void setLaunchCoverSeconds(int seconds);
    bool launchCoverPossible() const;

    /// Android's notification settings for DeckOS
    Q_INVOKABLE void openNotificationSettings();
    /// Android's accessibility settings, to turn on the shortcut service
    Q_INVOKABLE void openAccessibilitySettings();
    /// turns the shortcut service on directly (AYN / Retroid PServer, root), else opens those settings
    Q_INVOKABLE void enableShortcut();
    /// gives DeckOS usage access directly (PServer, root), else opens Android's usage access screen
    Q_INVOKABLE void allowUsageAccess();
    /// model, chip, PServer, vendor settings and sensors - for checking a new handheld
    Q_INVOKABLE QString deviceInfo() const;

    /// Right before a launch: snapshots the window with `spinner` and `logo` (an AnimatedImage) hidden
    /// and shows it over everything for `holdMs`, the two drawn again natively on top, so the game can
    /// load underneath. false if it can't be shown (PC, no permission): launch without it.
    Q_INVOKABLE bool showLaunchCover(QObject* spinner, int spinnerStep, QObject* logo, int holdMs);
    /// the launch was cancelled
    Q_INVOKABLE void hideLaunchCover();

    /// the emulator a launch command starts ("am start -n <package>/<activity> ...", -p / --component
    /// too), "" if it doesn't say
    static QString packageFromCommand(const QString& command);
    /// Android: the seconds the game was actually in front this session (Java tracks which app is in
    /// front), or -1 if that isn't known (PC) - then Pegasus keeps its launch-to-return time
    qint64 playedSeconds() const;

    /// opens Android's "Display over other apps" screen for DeckOS
    Q_INVOKABLE void requestOverlayPermission();
    /// re-reads the values (the permission is granted outside DeckOS)
    Q_INVOKABLE void recheck() { emit changed(); }

    /// the running game's page: Steam's STOP - closes the game's app at once (PServer / root) and ends
    /// the session. false if it can't.
    Q_INVOKABLE bool stopGame();
    /// ...and Resume: the game's app back in front as it was left (not launched again)
    Q_INVOKABLE bool resumeGame();

    /// Close menu (Android): the device restarts / shuts down through PServer or root (`svc power`).
    /// False if neither is there; on PC the theme uses Pegasus's own power commands instead.
    Q_INVOKABLE bool rebootDevice();
    Q_INVOKABLE bool shutdownDevice();
    /// Close > Restart DeckOS: call, then quit as usual - DeckOS opens again once it has quit
    Q_INVOKABLE void restartAfterQuit();

    void onGameLaunching(const model::GameFile* file);
    /// the game started and DeckOS stays loaded: sessionEnded() follows once DeckOS is back in front,
    /// or - while PServer / root sees the game still running - once it ends or is stopped
    void beginSession();
    /// ends the session now if there is one (another game is launched, DeckOS closes)
    void finishSession();

signals:
    void changed();
    void playingChanged();
    /// DeckOS came back to the front after the game (or the game never covered it), or the game that
    /// ran behind DeckOS ended
    void sessionEnded();
    /// DeckOS is in front again while the game still runs behind it (the session goes on)
    void returnedToFront();
    /// after sessionEnded: the game was closed with Quick Access's "Exit game", so Home is shown
    void exitedToHome();

private:
    model::ApiObject* const m_api;
    RaMatcher* const m_ra;
    QPointer<QObject> m_launched; // the game whose RA id is being looked up
    QTimer* const m_no_show_timer; // ends a session whose game never covered DeckOS
    QTimer* const m_running_timer; // while the game runs behind DeckOS: has it ended?
    QPointer<QObject> m_session_game;
    QString m_session_title;
    bool m_playing = false;
    bool m_left_front = false;
    bool m_background = false;     // DeckOS in front, the game still running behind it
    bool m_pc_count_running = true;
    int m_pc_hud = 0;
    bool m_pc_notification = true;
    bool m_pc_keep_loaded = true;
    int m_pc_scale = 125;
    bool m_pc_keep_running = false;
    int m_pc_shortcut = 2;
    int m_pc_hud_pos = 0;
    bool m_pc_fps = true;
    bool m_pc_cover = true;
    int m_pc_cover_seconds = 5;

    void onAppState(Qt::ApplicationState state);
    void endSession();
};

} // namespace deckos
