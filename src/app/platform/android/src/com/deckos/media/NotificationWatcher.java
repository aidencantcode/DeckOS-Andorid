// DeckOS - media
// The Downloads page's "On this device" list: other apps' notifications that show a progress bar (Play
// Store installs, the browser's downloads, an emulator fetching its files...), read with Android's
// notification listener. Needs "Notification access" for DeckOS - given through PServer / root
// (`cmd notification allow_listener`), or by the user in Android's settings. Only the notifications'
// title, text, app and progress are kept, in memory, while DeckOS runs; nothing leaves the device.

package com.deckos.media;

import android.app.Notification;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.provider.Settings;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import androidx.core.app.NotificationManagerCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;


public class NotificationWatcher extends NotificationListenerService {
    private static final String TAG = "DeckOS/downloads";
    private static final int MAX_RECENT = 20;

    private static volatile NotificationWatcher sInstance;
    private static final Map<String, JSONObject> sActive = new LinkedHashMap<>();   // key -> item
    private static final List<JSONObject> sRecent = new ArrayList<>();               // newest first

    @Override
    public void onListenerConnected() {
        sInstance = this;
        try {
            StatusBarNotification[] all = getActiveNotifications();
            if (all != null)
                for (StatusBarNotification n : all) track(n);
        }
        catch (Exception e) {
            Log.w(TAG, "listing notifications: " + e);
        }
    }

    @Override
    public void onListenerDisconnected() {
        if (sInstance == this)
            sInstance = null;
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        track(sbn);
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        synchronized (sActive) {
            JSONObject was = sActive.remove(sbn.getKey());
            if (was != null)
                finish(was, "Finished");
        }
    }

    private void track(StatusBarNotification sbn) {
        if (sbn == null || getPackageName().equals(sbn.getPackageName()))
            return; // DeckOS's own downloads are listed from Updates
        Notification n = sbn.getNotification();
        Bundle x = n == null ? null : n.extras;
        if (x == null)
            return;
        int max = x.getInt(Notification.EXTRA_PROGRESS_MAX, 0);
        int value = x.getInt(Notification.EXTRA_PROGRESS, 0);
        boolean indeterminate = x.getBoolean(Notification.EXTRA_PROGRESS_INDETERMINATE, false);
        boolean progress = max > 0 || indeterminate;
        synchronized (sActive) {
            JSONObject known = sActive.get(sbn.getKey());
            if (!progress) {
                if (known != null) { // the bar went away: done ("Download complete")
                    sActive.remove(sbn.getKey());
                    try { known.put("text", text(x, Notification.EXTRA_TEXT)); } catch (Exception ignored) {}
                    finish(known, "Finished");
                }
                return;
            }
            try {
                JSONObject o = known != null ? known : new JSONObject();
                o.put("key", sbn.getKey());
                o.put("package", sbn.getPackageName());
                o.put("app", label(sbn.getPackageName()));
                o.put("title", text(x, Notification.EXTRA_TITLE));
                o.put("text", text(x, Notification.EXTRA_TEXT));
                o.put("sub", text(x, Notification.EXTRA_SUB_TEXT));
                o.put("progress", indeterminate || max <= 0 ? -1.0 : Math.max(0.0, Math.min(1.0, value / (double) max)));
                o.put("time", sbn.getPostTime());
                sActive.put(sbn.getKey(), o);
            }
            catch (Exception e) {
                Log.w(TAG, "notification: " + e);
            }
        }
    }

    private static void finish(JSONObject o, String state) {
        try {
            o.put("state", state);
            o.put("progress", 1.0);
            o.put("time", System.currentTimeMillis());
        }
        catch (Exception ignored) {}
        synchronized (sRecent) {
            sRecent.add(0, o);
            while (sRecent.size() > MAX_RECENT)
                sRecent.remove(sRecent.size() - 1);
        }
    }

    private static String text(Bundle x, String key) {
        CharSequence c = x.getCharSequence(key);
        return c == null ? "" : c.toString();
    }

    private String label(String pkg) {
        try {
            PackageManager pm = getPackageManager();
            ApplicationInfo ai = pm.getApplicationInfo(pkg, 0);
            return pm.getApplicationLabel(ai).toString();
        }
        catch (Exception e) {
            return pkg;
        }
    }

    // --- from C++ (deckos/DeviceDownloads) ------------------------------------------------------------

    /// { allowed, connected, active: [...], recent: [...] }
    public static String snapshot(Context ctx) {
        JSONObject out = new JSONObject();
        try {
            out.put("allowed", allowed(ctx));
            out.put("connected", sInstance != null);
            JSONArray active = new JSONArray();
            synchronized (sActive) {
                for (JSONObject o : sActive.values()) active.put(o);
            }
            JSONArray recent = new JSONArray();
            synchronized (sRecent) {
                for (JSONObject o : sRecent) recent.put(o);
            }
            out.put("active", active);
            out.put("recent", recent);
        }
        catch (Exception ignored) {}
        return out.toString();
    }

    public static boolean allowed(Context ctx) {
        return ctx != null && NotificationManagerCompat.getEnabledListenerPackages(ctx).contains(ctx.getPackageName());
    }

    /// through PServer / root; false if neither is there (then openSettings)
    public static boolean grant(Context ctx) {
        if (ctx == null)
            return false;
        String component = new ComponentName(ctx, NotificationWatcher.class).flattenToString();
        return com.deckos.ingame.Session.allowNotificationListener(component);
    }

    public static void openSettings(Context ctx) {
        if (ctx == null)
            return;
        try {
            Intent i = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            ctx.startActivity(i);
        }
        catch (Exception e) {
            Log.w(TAG, "notification access settings: " + e);
        }
    }

    public static void clearRecent() {
        synchronized (sRecent) {
            sRecent.clear();
        }
    }
}
