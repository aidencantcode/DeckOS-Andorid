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
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        sInstance = null;
        statsHandler.removeCallbacksAndMessages(null);
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
            try {
                last = stats.sample();
            }
            catch (Exception e) {
                Log.w(Session.TAG, "stats: " + e);
            }
            main.post(() -> {
                if (hud != null)
                    hud.update(last, Session.startedAt);
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
        if (level > 0 && Session.overlayAllowed())
            showHud(level);
        else
            removeHud();
    }

    private Notification buildNotification() {
        Intent open = new Intent(this, QuickAccessActivity.class);
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        int piFlags = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
        PendingIntent pi = PendingIntent.getActivity(this, 0, open, piFlags);

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
            float u = getResources().getDisplayMetrics().heightPixels / 800f; // Steam Deck pixels
            if (getResources().getDisplayMetrics().widthPixels < getResources().getDisplayMetrics().heightPixels)
                u = getResources().getDisplayMetrics().widthPixels / 800f;
            hud = new HudView(this, u);
            int type = Build.VERSION.SDK_INT >= 26
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;
            WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT, type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                    | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT);
            lp.gravity = Gravity.TOP | Gravity.START;
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
        hud.update(last, Session.startedAt);
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
