// DeckOS - in-game layer
// What is playing right now, the in-game settings, and the hooks DeckOS's main activity calls.
//
// Flow: C++ calls setNowPlaying() right before a game starts (deckos/InGame.cpp). When DeckOS goes
// to the background (onFrontendStopped), SessionService starts: an ongoing notification with the
// play time; tapping it opens the Steam-style Quick Access overlay (QuickAccessActivity); the
// performance overlay (HUD) is drawn over the game if its level is above 0. When DeckOS comes
// back to the front (onFrontendResumed), the session ends.

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
            gamePackage = o.optString("package", "");
            raGameId = 0;
            startedAt = System.currentTimeMillis();
            resetPlayTime();
            sGameLaunched = true;
        }
        catch (Exception e) {
            Log.w(TAG, "setNowPlaying: " + e);
        }
        SessionService.refresh();
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
        setGameFocused(false);
        QuickAccessOverlay.hide();
        LaunchCover.hide();
        GameExit.onFrontendResumed();
        sGameLaunched = false;
        SessionService.stop(activity);
    }


    // --- play time: only while the game is in front -------------------------------------------------
    // Which app is in front comes from DeckOS's accessibility service (window changes, at once) or,
    // without it, from PServer every few seconds (SessionService). With neither, the game counts as in
    // front until DeckOS comes back, as before.

    /// the emulator's package (from the launch command, or the first app in front after the launch)
    static volatile String gamePackage = "";
    /// the emulator's process is gone (PServer can tell)
    static volatile boolean gameClosed = false;
    private static boolean sFocused = true;
    private static long sPlayedMs = 0, sFocusedSince = 0;
    private static java.util.Set<String> sIgnored;

    private static synchronized void resetPlayTime() {
        sPlayedMs = 0;
        sFocused = true;
        sFocusedSince = System.currentTimeMillis();
        gameClosed = false;
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
        synchronized (Session.class) {
            if (focused == sFocused)
                return;
            long now = System.currentTimeMillis();
            if (sFocused)
                sPlayedMs += Math.max(0, now - sFocusedSince);
            else
                sFocusedSince = now;
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

    /// an app came to the front while a game is running (accessibility event or PServer poll)
    static void onForegroundPackage(String pkg) {
        if (sApp == null || !sGameLaunched || frontendInFront || pkg == null || pkg.isEmpty())
            return;
        if (ignoredPackages().contains(pkg))
            return; // DeckOS's own windows, the status bar and shade, keyboards
        if (gamePackage.isEmpty() && !pkg.equals(homePackage())) {
            gamePackage = pkg; // the launch command didn't name it: the first app in front after the launch
            Log.i(TAG, "game package: " + pkg);
        }
        setGameFocused(pkg.equals(gamePackage));
    }

    /// PServer saw the emulator's process end
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
