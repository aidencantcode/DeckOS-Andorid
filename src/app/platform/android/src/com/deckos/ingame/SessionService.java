// DeckOS - in-game layer
// Runs while DeckOS is in the background: the ongoing "Playing ..." notification with a live play
// time (tap -> Quick Access overlay), the once-a-second device stats, and the performance overlay
// window over the game. See Session.java for the flow.

package com.deckos.ingame;

import android.app.Notification;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.WindowManager;

import androidx.core.app.NotificationCompat;

import org.pegasus_frontend.android.R;


public class SessionService extends Service {
    private static final int NOTIFICATION_ID = 4242;
    private static volatile SessionService sInstance;

    private Handler main;
    private HandlerThread statsThread;
    private Handler statsHandler;
    private Stats stats;
    private volatile Stats.Snapshot last = new Stats.Snapshot();
    private HudView hud;
    private WindowManager wm;
    private int shownTitleHash = 0;
    private int hudScale = 0, hudPos = -1;      // what the HUD window was made with
    static final String ACTION_OPEN = "com.deckos.ingame.OPEN_QUICK_ACCESS";

    static void start(Context ctx) {
        Intent intent = new Intent(ctx, SessionService.class);
        try {
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(intent);
            else ctx.startService(intent);
        }
        catch (Exception e) {
            Log.w(Session.TAG, "can't start the in-game service: " + e);
        }
    }

    static void stop(Context ctx) {
        ctx.stopService(new Intent(ctx, SessionService.class));
    }

    /// settings or the game changed: update the notification and the overlay
    static void refresh() {
        SessionService s = sInstance;
        if (s != null)
            s.main.post(s::apply);
    }

    static Stats.Snapshot lastStats() {
        SessionService s = sInstance;
        return s != null ? s.last : null;
    }

    static boolean running() { return sInstance != null; }


    @Override
    public void onCreate() {
        super.onCreate();
        sInstance = this;
        main = new Handler(Looper.getMainLooper());
        wm = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
        stats = new Stats(this);
        statsThread = new HandlerThread("deckos-stats");
        statsThread.start();
        statsHandler = new Handler(statsThread.getLooper());
        Session.createChannel(this);
        startForeground(NOTIFICATION_ID, buildNotification());
        statsHandler.post(sampler);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        startForeground(NOTIFICATION_ID, buildNotification());
        apply();
        if (intent != null && ACTION_OPEN.equals(intent.getAction()))
            Session.openQuickAccess(this); // the notification was tapped
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        sInstance = null;
        statsHandler.removeCallbacksAndMessages(null);
        statsHandler.post(() -> DeviceControl.fpsTick(this, false)); // stops the frame counter loop
        statsThread.quitSafely();
        removeHud();
        stopForeground(true);
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) { return null; }


    private final Runnable sampler = new Runnable() {
        @Override
        public void run() {
            String profile = "";
            float fps = Float.NaN;
            try {
                last = stats.sample();
                // the frame counter loop runs only while the HUD shows it
                boolean wantFps = hud != null && Session.showFps();
                DeviceControl.fpsTick(SessionService.this, wantFps);
                if (wantFps) fps = DeviceControl.fps();
                if (hud != null && Session.hudLevel() >= 3) profile = profileLine();
            }
            catch (Exception e) {
                Log.w(Session.TAG, "stats: " + e);
            }
            final String p = profile;
            final float f = fps;
            main.post(() -> {
                if (hud != null)
                    hud.update(last, Session.startedAt, f, p);
            });
            statsHandler.postDelayed(this, 1000);
        }
    };

    private void apply() {
        int hash = (Session.title + Session.startedAt).hashCode();
        if (hash != shownTitleHash) {
            shownTitleHash = hash;
            startForeground(NOTIFICATION_ID, buildNotification());
        }
        int level = Session.hudLevel();
        if (hud != null && (hudScale != Session.overlayScale() || hudPos != Session.hudPosition()))
            removeHud(); // size or corner changed: made again below
        if (level > 0 && Session.overlayAllowed())
            showHud(level);
        else
            removeHud();
    }

    /// "High Performance · Fan Smart · CPU Medium" for the HUD (AYN / Retroid only; empty elsewhere)
    private String profileLine() {
        StringBuilder b = new StringBuilder();
        String perf = DeviceControl.perfName(this), fan = DeviceControl.fanName(this), uc = DeviceControl.underclockName();
        if (!perf.isEmpty()) b.append(perf);
        if (!fan.isEmpty()) b.append(b.length() > 0 ? " · " : "").append("Fan ").append(fan);
        if (!uc.isEmpty()) b.append(b.length() > 0 ? " · " : "").append("CPU ").append(uc);
        return b.toString();
    }

    private Notification buildNotification() {
        // through this service, which opens Quick Access as an activity or, with "Keep game running", as
        // an overlay window (no activity, so the game isn't paused)
        Intent open = new Intent(this, SessionService.class).setAction(ACTION_OPEN);
        int piFlags = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
        PendingIntent pi = PendingIntent.getService(this, 0, open, piFlags);

        boolean game = Session.hasGame();
        return new NotificationCompat.Builder(this, Session.CHANNEL)
            .setSmallIcon(R.drawable.deckos_ic_gamepad)
            .setContentTitle(game ? Session.title : "DeckOS")
            .setContentText(game ? "Playing - tap for the quick access menu" : "Tap for the quick access menu")
            .setSubText(game && !Session.system.isEmpty() ? Session.system : null)
            .setWhen(Session.startedAt)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setContentIntent(pi)
            .build();
    }


    // --- performance overlay window ---------------------------------------------------------------

    private void showHud(int level) {
        if (hud == null) {
            hudScale = Session.overlayScale();
            hudPos = Session.hudPosition();
            // Steam Deck pixels, times the overlay size setting
            float u = Math.min(getResources().getDisplayMetrics().heightPixels, getResources().getDisplayMetrics().widthPixels) / 800f
                      * hudScale / 100f;
            hud = new HudView(this, u);
            int type = Build.VERSION.SDK_INT >= 26
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;
            WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT, type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                    | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT);
            lp.gravity = (hudPos >= 2 ? Gravity.BOTTOM : Gravity.TOP) | (hudPos % 2 == 1 ? Gravity.END : Gravity.START);
            lp.x = Math.round(8 * u);
            lp.y = Math.round(8 * u);
            lp.alpha = 0.8f; // Android 12+ passes touches through overlays only up to 80% opacity
            lp.setTitle("DeckOS performance overlay");
            try {
                wm.addView(hud, lp);
            }
            catch (Exception e) {
                Log.w(Session.TAG, "can't show the performance overlay: " + e);
                hud = null;
                return;
            }
        }
        hud.setLevel(level);
        hud.update(last, Session.startedAt, Float.NaN, ""); // the sampler fills in FPS and the profile next second
    }

    private void removeHud() {
        if (hud == null)
            return;
        try {
            wm.removeView(hud);
        }
        catch (Exception ignored) {}
        hud = null;
    }
}
