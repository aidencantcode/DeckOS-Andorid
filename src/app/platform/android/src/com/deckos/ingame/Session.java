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

    /// JSON: title, system, cover, raUser, raKey, profileName, profilePicture
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
            raGameId = 0;
            startedAt = System.currentTimeMillis();
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

    /// a ClusterTune export file's text: keeps its first profile as "Custom". Its name, or "!error".
    public static String importClusterTune(String json) {
        return sApp == null ? "!" : DeviceControl.importClusterTune(json);
    }

    public static String customUnderclockName() {
        if (sApp == null) return "";
        org.json.JSONObject p = DeviceControl.customProfile(sApp);
        return p == null ? "" : p.optString("name", "Custom");
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

    public static void onFrontendResumed(Activity activity) {
        frontendInFront = true;
        QuickAccessOverlay.hide();
        sGameLaunched = false;
        SessionService.stop(activity);
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
