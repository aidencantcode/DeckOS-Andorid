// DeckOS - in-game layer
// What is playing right now, the in-game settings, and the hooks DeckOS's main activity calls.
//
// Flow: C++ calls setNowPlaying() right before a game starts (deckos/InGame.cpp). When DeckOS goes
// to the background (onFrontendStopped), SessionService starts: an ongoing notification with the
// play time; tapping it opens the Steam-style Quick Access overlay (QuickAccessActivity); the
// performance overlay (HUD) is drawn over the game if its level is above 0. When DeckOS comes
// back to the front (onFrontendResumed), the session ends - unless PServer / root can see that the
// game's process still runs (GameProcess): then it goes on behind DeckOS (the game page offers Resume
// and Stop) until that process ends or the game is stopped, and C++ ends it (sessionFinished).

package com.deckos.ingame;

import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import org.json.JSONObject;


public final class Session {
    static final String TAG = "DeckOS/ingame";
    static final String CHANNEL = "deckos_ingame";

    private static final String PREFS = "deckos_ingame";
    private static final String KEY_HUD = "hud_level";
    static final String KEY_NOTIFY = "notification";
    private static final String KEY_KEEP_LOADED = "keep_loaded";
    static final String KEY_SCALE = "overlay_scale";
    static final String KEY_KEEP_RUNNING = "keep_running";
    static final String KEY_SHORTCUT = "shortcut";
    static final String KEY_HUD_POS = "hud_position";
    static final String KEY_FPS = "show_fps";
    static final String KEY_PER_GAME = "per_game_profile";
    static final String KEY_PERF_MODE = "performance_mode";
    static final String KEY_TAB = "last_tab";
    static final String KEY_ADVANCED = "advanced_view";
    static final String KEY_COVER = "launch_cover";
    static final String KEY_COVER_SECONDS = "launch_cover_seconds";
    static final String KEY_COUNT_RUNNING = "count_while_running";

    private static Context sApp;

    // the game being played; written from the Qt thread, read on the UI thread
    static volatile String title = "";
    static volatile String system = "";
    static volatile String cover = "";
    static volatile String raUser = "";
    static volatile String raKey = "";
    static volatile int raGameId = 0;
    static volatile String profileName = "";
    static volatile String profilePicture = "";
    static volatile long startedAt = 0;
    private static volatile boolean sGameLaunched = false;
    /// DeckOS itself is on screen (the controller shortcut does nothing then)
    static volatile boolean frontendInFront = true;

    private Session() {}

    public static void init(Context ctx) {
        sApp = ctx.getApplicationContext();
        createChannel(sApp); // early, so Android 13+ asks for the notification permission while DeckOS is open
    }

    static Context app() { return sApp; }

    static SharedPreferences prefs() {
        return sApp.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    static boolean hasGame() { return !title.isEmpty(); }

    /// a game launched from DeckOS has a session (GameProcess watches it meanwhile)
    static boolean sessionOpen() { return sGameLaunched; }


    // --- called from C++ (Qt's thread) ------------------------------------------------------------

    /// JSON: title, system, cover, raUser, raKey, profileName, profilePicture, package (the emulator's,
    /// from the launch command; "" if it couldn't be told)
    public static void setNowPlaying(String json) {
        try {
            JSONObject o = new JSONObject(json);
            title = o.optString("title", "");
            system = o.optString("system", "");
            cover = o.optString("cover", "");
            raUser = o.optString("raUser", "");
            raKey = o.optString("raKey", "");
            profileName = o.optString("profileName", "");
            profilePicture = o.optString("profilePicture", "");
            startedAt = System.currentTimeMillis();
            // the app the launch's intent opens (MainActivity, onGameIntent) beats the command's text
            gamePackage = startedAt - sIntentAt < 5000 && !sIntentPackage.isEmpty() ? sIntentPackage : o.optString("package", "");
            raGameId = 0;
            sRunningMode = countWhileRunning(); // for the whole session
            sBackground = false;
            resetPlayTime();
            sGameLaunched = true;
            GameProcess.start();
            Foreground.startSession(startedAt);
            if (sApp != null && !Foreground.usageAllowed(sApp) && Foreground.grantUsage(sApp))
                Log.i(TAG, "usage access requested through PServer / root (play time)");
        }
        catch (Exception e) {
            Log.w(TAG, "setNowPlaying: " + e);
        }
        SessionService.refresh();
    }

    private static volatile String sIntentPackage = "";
    private static volatile long sIntentAt = 0;

    /// MainActivity, as it starts a game ("am start ..."): the app Android opens for that intent is the
    /// game's - exact, where the launch command's text can only be guessed from
    public static void onGameIntent(Context ctx, Intent intent) {
        String pkg = Foreground.packageOf(ctx, intent);
        sIntentPackage = pkg;
        sIntentAt = System.currentTimeMillis();
        if (pkg.isEmpty())
            return;
        if (sGameLaunched && sIntentAt - startedAt < 5000)
            gamePackage = pkg; // setNowPlaying came first (the usual order)
        Log.i(TAG, "game app: " + pkg);
    }

    /// the RetroAchievements game of what's playing (found by ROM hash, a moment after the launch)
    public static void setRaGame(int gameId) {
        raGameId = gameId;
        SessionService.refresh();
    }

    public static boolean overlayAllowed() {
        return sApp != null && (Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(sApp));
    }

    public static void requestOverlayPermission() {
        if (sApp == null || Build.VERSION.SDK_INT < 23)
            return;
        try {
            Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + sApp.getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            sApp.startActivity(intent);
        }
        catch (Exception e) {
            Log.w(TAG, "overlay permission screen: " + e);
        }
    }

    public static int hudLevel() {
        return sApp == null ? 0 : prefs().getInt(KEY_HUD, 0);
    }

    public static void setHudLevel(int level) {
        if (sApp == null)
            return;
        prefs().edit().putInt(KEY_HUD, Math.max(0, Math.min(4, level))).apply();
        SessionService.refresh();
    }

    public static boolean notificationEnabled() {
        return sApp != null && prefs().getBoolean(KEY_NOTIFY, true);
    }

    public static void setNotificationEnabled(boolean on) {
        if (sApp != null)
            prefs().edit().putBoolean(KEY_NOTIFY, on).apply();
    }

    /** Keep DeckOS's interface loaded while a game runs (see Backend::onProcessLaunched). */
    public static boolean keepLoaded() {
        return sApp == null || prefs().getBoolean(KEY_KEEP_LOADED, true);
    }

    public static void setKeepLoaded(boolean on) {
        if (sApp != null)
            prefs().edit().putBoolean(KEY_KEEP_LOADED, on).apply();
    }


    // --- overlay settings (the overlay's own Overlay tab and DeckOS's Settings > Overlay) ----------

    /// Quick Access and HUD size, percent of Steam Deck size
    public static int overlayScale() {
        return sApp == null ? 125 : Math.max(50, Math.min(250, prefs().getInt(KEY_SCALE, 125)));
    }

    public static void setOverlayScale(int percent) {
        if (sApp == null) return;
        prefs().edit().putInt(KEY_SCALE, Math.max(50, Math.min(250, percent))).apply();
        SessionService.refresh();
    }

    /// Quick Access as an overlay window: the game isn't paused
    public static boolean keepRunning() {
        return sApp != null && prefs().getBoolean(KEY_KEEP_RUNNING, false);
    }

    public static void setKeepRunning(boolean on) {
        if (sApp != null) prefs().edit().putBoolean(KEY_KEEP_RUNNING, on).apply();
    }

    /// the launch screen stays over the game while it loads (LaunchCover), for this many seconds
    public static boolean launchCover() {
        return sApp != null && prefs().getBoolean(KEY_COVER, true);
    }

    public static void setLaunchCover(boolean on) {
        if (sApp != null) prefs().edit().putBoolean(KEY_COVER, on).apply();
    }

    public static int launchCoverSeconds() {
        return sApp == null ? 5 : prefs().getInt(KEY_COVER_SECONDS, 5);
    }

    public static void setLaunchCoverSeconds(int seconds) {
        if (sApp != null) prefs().edit().putInt(KEY_COVER_SECONDS, Math.max(1, Math.min(30, seconds))).apply();
    }

    public static boolean launchCoverPossible() {
        return sApp != null && LaunchCover.possible();
    }

    /// from C++ right before a launch; see LaunchCover.show
    public static boolean showLaunchCover(int[] pixels, int w, int h, int x, int y, float[] spinnerRect, int spinnerStep,
                                          float[] logoRect, String gifPath, float gifProgress, int holdMs) {
        return sApp != null && LaunchCover.show(pixels, w, h, x, y, spinnerRect, spinnerStep, logoRect, gifPath, gifProgress, holdMs);
    }

    public static void hideLaunchCover() {
        LaunchCover.hide();
    }

    /// controller shortcut: 0 off, 1 Select+Start, 2 Select+R1, 3 L3+R3
    public static int shortcut() {
        return sApp == null ? 0 : prefs().getInt(KEY_SHORTCUT, 2);
    }

    public static void setShortcut(int combo) {
        if (sApp != null) prefs().edit().putInt(KEY_SHORTCUT, Math.max(0, Math.min(3, combo))).apply();
    }

    public static boolean shortcutServiceEnabled() {
        return sApp != null && ShortcutService.enabled(sApp);
    }

    public static void openAccessibilitySettings() {
        openSettings(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
    }

    /// Android started it (enabled in the settings is not always running: a sideloaded app's service
    /// can be blocked by Android 13+'s "restricted settings")
    public static boolean shortcutServiceRunning() {
        return ShortcutService.instance() != null;
    }

    /// "Turn on the controller shortcut": through PServer (AYN / Retroid) DeckOS adds its service to
    /// the enabled accessibility services itself - which also gets past "restricted settings". False
    /// if it can't (no PServer): the caller opens Android's accessibility settings instead.
    public static boolean enableShortcutService() {
        if (sApp == null || !Privileged.available())
            return false;
        String me = new android.content.ComponentName(sApp, ShortcutService.class).flattenToString();
        String body = "svc=" + Privileged.quote(me) + "\n"
                    + "cur=$(settings get secure enabled_accessibility_services)\n"
                    + "case \"$cur\" in\n"
                    + "  *\"$svc\"*) ;;\n"
                    + "  null|'') settings put secure enabled_accessibility_services \"$svc\" ;;\n"
                    + "  *) settings put secure enabled_accessibility_services \"$cur:$svc\" ;;\n"
                    + "esac\n"
                    + "settings put secure accessibility_enabled 1\n";
        return Privileged.runScript(sApp, "shortcut.sh", body);
    }

    /// performance overlay corner: 0 top left, 1 top right, 2 bottom left, 3 bottom right
    public static int hudPosition() {
        return sApp == null ? 0 : prefs().getInt(KEY_HUD_POS, 0);
    }

    public static void setHudPosition(int pos) {
        if (sApp == null) return;
        prefs().edit().putInt(KEY_HUD_POS, Math.max(0, Math.min(3, pos))).apply();
        SessionService.refresh();
    }

    public static boolean showFps() {
        return sApp != null && prefs().getBoolean(KEY_FPS, true);
    }

    public static void setShowFps(boolean on) {
        if (sApp == null) return;
        prefs().edit().putBoolean(KEY_FPS, on).apply();
        SessionService.refresh();
    }

    /// the AYN / Retroid system service DeckOS uses for modes, underclocking and the frame rate
    public static boolean privilegedAvailable() {
        return Privileged.available();
    }

    public static String deviceInfo() {
        return sApp == null ? "" : DeviceControl.deviceInfo(sApp);
    }

    // --- underclocking (C++ deckos/Underclock owns the profiles; see Underclock.java) ---

    /// Quick Access's steps and the restart setting, as JSON with ready-made scripts
    public static void setUnderclockSteps(String json) {
        if (sApp != null) prefs().edit().putString(Underclock.PREF_STEPS, json == null ? "{}" : json).apply();
    }

    /// the applied profile's current script, run again after a restart
    public static void setUnderclockBootScript(String id, String script) {
        if (sApp != null && id != null && id.equals(Underclock.activeId()))
            prefs().edit().putString(Underclock.PREF_ACTIVE_SCRIPT, script == null ? "" : script).apply();
    }

    /// applies a profile (DeckOS's settings page); false if PServer couldn't be reached
    public static boolean runUnderclock(String id, String name, String label, String script) {
        return sApp != null && Underclock.run(sApp, id, label, script);
    }

    public static String underclockActiveId() {
        return sApp == null ? Underclock.STOCK : Underclock.activeId();
    }

    static void openSettings(Intent intent) {
        if (sApp == null) return;
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            sApp.startActivity(intent);
        }
        catch (Exception e) {
            Log.w(TAG, "can't open settings: " + e);
        }
    }

    /// the notification and the controller shortcut: Quick Access as an overlay (keep running) or activity
    static void openQuickAccess(Context ctx) {
        if (keepRunning() && QuickAccessOverlay.show(ctx))
            return;
        Intent i = new Intent(ctx, QuickAccessActivity.class);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            ctx.startActivity(i);
        }
        catch (Exception e) {
            Log.w(TAG, "can't open quick access: " + e);
        }
    }


    // --- DeckOS's main activity -------------------------------------------------------------------

    public static void onFrontendStopped(Activity activity) {
        frontendInFront = false;
        if (sBackground) {
            // back into the game that ran behind DeckOS (Resume, or Android's recent apps)
            sBackground = false;
            if (sGameLaunched && !sRunningMode && sApp != null && !Foreground.usageActive(sApp) && ShortcutService.instance() == null)
                setGameFocused(true); // nothing can tell which app is in front: the game, as at a launch
        }
        if (sApp == null || !notificationEnabled())
            return;
        if (!sGameLaunched) {
            // DeckOS just went to the background (no game): the overlay is still there to open
            title = "";
            system = "";
            cover = "";
            raGameId = 0;
            startedAt = System.currentTimeMillis();
        }
        SessionService.start(activity);
    }

    /// called before Qt hears that DeckOS is active again, so the session's play time is final when
    /// C++ reads it (playedSeconds)
    public static void onFrontendResumed(Activity activity) {
        frontendInFront = true;
        QuickAccessOverlay.hide();
        LaunchCover.hide();
        GameExit.onFrontendResumed();
        SessionService.stop(activity);
        if (sGameLaunched && !gameClosed && GameProcess.alive()) {
            // the game still runs behind DeckOS: its session goes on until its process ends or it's
            // stopped (C++ asks gameRunning(), then calls sessionFinished)
            sBackground = true;
            if (!sRunningMode)
                setGameFocused(false);
            Log.i(TAG, "back in DeckOS, the game still runs: " + gamePackage);
            return;
        }
        setGameFocused(false);
        sGameLaunched = false;
        sBackground = false;
        GameProcess.stop();
    }


    // --- a game running behind DeckOS (PServer / root) ----------------------------------------------

    /// the game is "running" while DeckOS is in front (Steam's blue STOP / Resume on its page)
    private static volatile boolean sBackground = false;
    /// this session counts play time while the game runs, not only while it's in front
    private static volatile boolean sRunningMode = false;

    /// From C++ as DeckOS comes back to the front: the session goes on behind DeckOS
    public static boolean backgroundSession() {
        return sGameLaunched && sBackground;
    }

    /// From C++ (every second while the game runs behind DeckOS): false once its process has ended
    public static boolean gameRunning() {
        return sGameLaunched && !gameClosed;
    }

    /// From C++ once it has read the play time: the session is over
    public static void sessionFinished() {
        sGameLaunched = false;
        sBackground = false;
        GameProcess.stop();
    }

    /// PServer or root: DeckOS can tell when the game's process ends (and stop it)
    public static boolean processTracking() {
        return sApp != null && Privileged.available();
    }

    /// Settings > Overlay > Play time: count while the game runs, like Steam (on by default), instead of
    /// only while it's in front. Needs PServer / root - only they can tell when the game ends.
    public static boolean countWhileRunning() {
        return processTracking() && prefs().getBoolean(KEY_COUNT_RUNNING, true);
    }

    public static void setCountWhileRunning(boolean on) {
        if (sApp != null) prefs().edit().putBoolean(KEY_COUNT_RUNNING, on).apply();
    }

    /// the game page's Stop: closes the game's app at once (`am force-stop`, PServer / root; unsaved
    /// progress is lost - the page asks first). False if it can't.
    public static boolean stopGame() {
        final String pkg = gamePackage;
        if (sApp == null || !sGameLaunched || pkg.isEmpty() || !Privileged.available())
            return false;
        Log.i(TAG, "stop game: " + pkg);
        onGameProcessGone(); // play time ends now
        return Privileged.run("am force-stop " + Privileged.quote(pkg));
    }

    /// the game page's Resume: the game's app back in front as it was left - with the exact intent of its
    /// icon in Android's launcher, which brings a running app back instead of starting it again (launching
    /// the game again would restart it in most emulators; AppLaunch.java). False if it has no launcher entry.
    public static boolean resumeGame() {
        final String pkg = gamePackage;
        if (sApp == null || pkg.isEmpty())
            return false;
        final Intent i = AppLaunch.forPackage(sApp, pkg);
        if (i == null)
            return false;
        try {
            sApp.startActivity(i);
            Log.i(TAG, "resume game: " + pkg);
            return true;
        }
        catch (Exception e) {
            Log.w(TAG, "can't resume " + pkg + ": " + e);
            return false;
        }
    }

    /// GameProcess, every 2 s: counting while the game runs, except while the screen is off (Android
    /// pauses the game then; a handheld left asleep with a game open didn't play it)
    static void onProcessTick() {
        if (!sGameLaunched || !sRunningMode || gameClosed || sApp == null)
            return;
        boolean screenOn = true;
        try {
            android.os.PowerManager pm = (android.os.PowerManager) sApp.getSystemService(Context.POWER_SERVICE);
            if (pm != null) screenOn = pm.isInteractive();
        }
        catch (Exception ignored) {}
        setGameFocused(screenOn);
    }


    // --- play time: while the game runs (PServer / root), else only while it's in front ---------------
    // The game is the app DeckOS opened (onGameIntent). Counting while it runs (countWhileRunning): from
    // the launch until its process ends (GameProcess), except while the screen is off. Otherwise only
    // while it's in front - which app is: see Foreground (usage stats, else the accessibility service,
    // else PServer / root every few seconds). With none of them, the game counts as in front until DeckOS
    // comes back, as before.

    /// the emulator's package (the app the launch opened, else the first app in front after it)
    static volatile String gamePackage = "";
    /// the emulator's process is gone (GameProcess), or the game was stopped / exited from DeckOS
    static volatile boolean gameClosed = false;
    private static boolean sFocused = true;
    private static long sPlayedMs = 0, sFocusedSince = 0;
    private static java.util.Set<String> sIgnored;

    private static synchronized void resetPlayTime() {
        sPlayedMs = 0;
        sFocused = true;
        sFocusedSince = System.currentTimeMillis();
        gameClosed = false;
        sResumedPkg = "";
        sResumedClass = "";
    }

    /// Settings > Overlay > Play time: DeckOS may read which app is in front (usage access)
    public static boolean usageAccessAllowed() {
        return sApp != null && Foreground.usageAllowed(sApp);
    }

    /// gives usage access through PServer / root; false if it can't (the caller opens the settings)
    public static boolean allowUsageAccess() {
        return sApp != null && Foreground.grantUsage(sApp);
    }

    public static void openUsageAccessSettings() {
        Foreground.openUsageSettings();
    }

    static synchronized long playedMs() {
        return sPlayedMs + (sFocused ? Math.max(0, System.currentTimeMillis() - sFocusedSince) : 0);
    }

    static synchronized boolean gameFocused() {
        return sFocused;
    }

    /// for the HUD and the notification's timer: now minus the time played
    static long playStart() {
        return System.currentTimeMillis() - playedMs();
    }

    static void setGameFocused(boolean focused) {
        setGameFocused(focused, System.currentTimeMillis());
    }

    /// `at`: when it happened (the usage stats are read a moment later)
    static void setGameFocused(boolean focused, long at) {
        synchronized (Session.class) {
            if (focused == sFocused)
                return;
            long now = System.currentTimeMillis();
            if (sFocused) {
                at = Math.max(sFocusedSince, Math.min(at, now));
                sPlayedMs += at - sFocusedSince;
            }
            else
                sFocusedSince = Math.min(Math.max(at, startedAt), now);
            sFocused = focused;
        }
        Log.i(TAG, focused ? "game in front: play time counting" : "game not in front: play time paused");
        SessionService.refresh();
    }

    /// From C++ when the session ends: the seconds the game was actually in front, or -1 if nothing
    /// was ever launched (then Pegasus's own launch-to-return time is kept)
    public static long playedSeconds() {
        return startedAt > 0 ? playedMs() / 1000 : -1;
    }

    /// an app came to the front while a game is running (accessibility event or PServer poll; the usage
    /// stats go through onActivityChange)
    static void onForegroundPackage(String pkg) {
        if (sApp != null && Foreground.usageActive(sApp))
            return; // the usage stats know better (exact times)
        onForegroundPackage(pkg, System.currentTimeMillis());
    }

    private static void onForegroundPackage(String pkg, long at) {
        if (sApp == null || !sGameLaunched || frontendInFront || pkg == null || pkg.isEmpty())
            return;
        if (ignoredPackages().contains(pkg))
            return; // DeckOS's own windows, the status bar and shade, keyboards
        if (gamePackage.isEmpty() && !pkg.equals(homePackage()) && !SYSTEM_SCREENS.contains(pkg)) {
            gamePackage = pkg; // the launch didn't name it ("Open with"): the first app in front after it
            Log.i(TAG, "game package: " + pkg);
        }
        if (pkg.equals(gamePackage))
            gameClosed = false; // started again (from Android's recent apps)
        if (!sRunningMode) // counting while the game runs: which app is in front doesn't matter
            setGameFocused(pkg.equals(gamePackage), at);
    }

    private static volatile String sResumedPkg = "", sResumedClass = "";

    /// Foreground's usage stats: an activity resumed / paused / stopped, or the screen went off
    static void onActivityChange(int type, String pkg, String cls, long at) {
        if (sApp == null || !sGameLaunched || frontendInFront || (pkg != null && ignoredPackages().contains(pkg)))
            return;
        String c = cls == null ? "" : cls;
        if (type == Foreground.RESUMED) {
            sResumedPkg = pkg == null ? "" : pkg;
            sResumedClass = c;
            onForegroundPackage(pkg, at);
        }
        else if (type == Foreground.SCREEN_OFF) {
            if (!sRunningMode) setGameFocused(false, at); // (onProcessTick knows the screen too)
        }
        else if (pkg != null && pkg.equals(sResumedPkg) && (c.isEmpty() || sResumedClass.isEmpty() || c.equals(sResumedClass))) {
            // the activity in front paused or stopped (not an older one of the same app stopping late)
            sResumedPkg = "";
            sResumedClass = "";
            if (!sRunningMode) setGameFocused(false, at);
        }
    }

    /// apps an emulator may open for a moment (permissions, folder picker, settings): never taken for
    /// the game, and the game doesn't count while they're in front
    private static final java.util.Set<String> SYSTEM_SCREENS = new java.util.HashSet<>(java.util.Arrays.asList(
        "com.android.settings", "com.android.documentsui", "com.google.android.documentsui",
        "com.android.permissioncontroller", "com.google.android.permissioncontroller",
        "com.android.packageinstaller", "com.google.android.packageinstaller", "com.android.intentresolver"));

    /// the emulator's process ended (GameProcess), or DeckOS closed it (Stop, Exit game)
    static void onGameProcessGone() {
        if (!sGameLaunched || gameClosed)
            return;
        gameClosed = true;
        setGameFocused(false);
        SessionService.refresh();
    }

    private static synchronized java.util.Set<String> ignoredPackages() {
        if (sIgnored == null) {
            sIgnored = new java.util.HashSet<>();
            sIgnored.add(sApp.getPackageName());
            sIgnored.add("com.android.systemui");
            sIgnored.add("android");
            try {
                android.view.inputmethod.InputMethodManager imm =
                    (android.view.inputmethod.InputMethodManager) sApp.getSystemService(Context.INPUT_METHOD_SERVICE);
                if (imm != null)
                    for (android.view.inputmethod.InputMethodInfo i : imm.getInputMethodList())
                        sIgnored.add(i.getPackageName());
            }
            catch (Exception ignored) {}
        }
        return sIgnored;
    }

    private static String sHome;

    /// the home screen app (never taken for the game)
    static String homePackage() {
        if (sHome == null) {
            sHome = "";
            try {
                Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
                android.content.pm.ResolveInfo r = sApp.getPackageManager().resolveActivity(home, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY);
                if (r != null && r.activityInfo != null) sHome = r.activityInfo.packageName;
            }
            catch (Exception ignored) {}
        }
        return sHome;
    }


    // --- exit game (Quick Access) -------------------------------------------------------------------

    private static volatile boolean sExitToHome = false;

    static void requestHomeAfterExit() { sExitToHome = true; }

    /// From C++ when the session ends: the game was quit from Quick Access, so DeckOS opens on Home
    public static boolean takeExitToHome() {
        boolean v = sExitToHome;
        sExitToHome = false;
        return v;
    }


    // --- notification state (Settings > Overlay) ----------------------------------------------------

    /// Android blocks DeckOS's notifications, or the in-game channel
    public static boolean notificationsBlocked() {
        if (sApp == null)
            return false;
        try {
            if (!androidx.core.app.NotificationManagerCompat.from(sApp).areNotificationsEnabled())
                return true;
            if (Build.VERSION.SDK_INT >= 26) {
                NotificationManager nm = (NotificationManager) sApp.getSystemService(Context.NOTIFICATION_SERVICE);
                NotificationChannel ch = nm != null ? nm.getNotificationChannel(CHANNEL) : null;
                return ch != null && ch.getImportance() == NotificationManager.IMPORTANCE_NONE;
            }
        }
        catch (Exception ignored) {}
        return false;
    }

    /// Android's notification settings for DeckOS
    public static void openNotificationSettings() {
        if (sApp == null)
            return;
        Intent i;
        if (Build.VERSION.SDK_INT >= 26) {
            i = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
            i.putExtra(Settings.EXTRA_APP_PACKAGE, sApp.getPackageName());
        }
        else {
            i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + sApp.getPackageName()));
        }
        openSettings(i);
    }


    static void createChannel(Context ctx) {
        if (Build.VERSION.SDK_INT < 26)
            return;
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null || nm.getNotificationChannel(CHANNEL) != null)
            return;
        NotificationChannel channel = new NotificationChannel(CHANNEL, "In-game", NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("Play time of the running game; tap it for the DeckOS overlay");
        channel.setShowBadge(false);
        nm.createNotificationChannel(channel);
    }
}
