// DeckOS - media
// Updates and the Store (C++ deckos/Updates): which version of an app is installed and where it came from,
// installing a downloaded APK, and the "Downloads" notifications with their progress bars.
//
// Installing: Android's own installer screen (needs "Install unknown apps" for DeckOS - opened for the user
// the first time), or, with PServer / root and the setting on, `pm install -r` without a screen
// (Session.installPrivileged). An app from the Play Store can't be updated with a GitHub build (they're
// signed by different keys): installerOf() tells, and the Store sends those to the Play Store.

package com.deckos.media;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.content.FileProvider;

import org.json.JSONObject;
import org.pegasus_frontend.android.R;

import java.io.File;


public final class Packages {
    private static final String TAG = "DeckOS/packages";
    private static final String CHANNEL = "deckos_downloads";

    private Packages() {}

    /// { installed, version, code, updated (ms), installer } as JSON
    public static String info(Context ctx, String pkg) {
        JSONObject o = new JSONObject();
        try {
            o.put("installed", false);
            if (ctx == null || pkg == null || pkg.isEmpty())
                return o.toString();
            PackageManager pm = ctx.getPackageManager();
            PackageInfo pi = pm.getPackageInfo(pkg, 0);
            o.put("installed", true);
            o.put("version", pi.versionName == null ? "" : pi.versionName);
            o.put("code", Build.VERSION.SDK_INT >= 28 ? pi.getLongVersionCode() : pi.versionCode);
            o.put("updated", pi.lastUpdateTime);
            o.put("installer", installerOf(ctx, pkg));
        }
        catch (PackageManager.NameNotFoundException e) {
            // not installed
        }
        catch (Exception e) {
            Log.w(TAG, "info " + pkg + ": " + e);
        }
        return o.toString();
    }

    /// the store that installed it ("com.android.vending" = Play Store), "" if sideloaded / unknown
    static String installerOf(Context ctx, String pkg) {
        try {
            PackageManager pm = ctx.getPackageManager();
            String who;
            if (Build.VERSION.SDK_INT >= 30)
                who = pm.getInstallSourceInfo(pkg).getInstallingPackageName();
            else
                who = pm.getInstallerPackageName(pkg);
            return who == null ? "" : who;
        }
        catch (Exception e) {
            return "";
        }
    }

    /// Android lets DeckOS open the installer ("Install unknown apps")
    public static boolean canInstall(Context ctx) {
        return ctx != null && (Build.VERSION.SDK_INT < 26 || ctx.getPackageManager().canRequestPackageInstalls());
    }

    /// Android's "Install unknown apps" switch for DeckOS
    public static void openInstallSettings(Context ctx) {
        if (ctx == null || Build.VERSION.SDK_INT < 26)
            return;
        try {
            Intent i = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + ctx.getPackageName()));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            ctx.startActivity(i);
        }
        catch (Exception e) {
            Log.w(TAG, "install settings: " + e);
        }
    }

    /// installs a downloaded APK: privileged (no screen) when asked and possible, else Android's installer.
    /// 0: started, 1: needs "Install unknown apps" (its settings were opened), 2: failed
    public static int install(Context ctx, String path, boolean privileged, String thenStart) {
        if (ctx == null || path == null || !new File(path).isFile())
            return 2;
        if (privileged && com.deckos.ingame.Session.installPrivileged(path, thenStart))
            return 0;
        if (!canInstall(ctx)) {
            openInstallSettings(ctx);
            return 1;
        }
        try {
            Uri uri = FileProvider.getUriForFile(ctx, ctx.getPackageName() + ".files", new File(path));
            Intent i = new Intent(Intent.ACTION_VIEW);
            i.setDataAndType(uri, "application/vnd.android.package-archive");
            i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
            ctx.startActivity(i);
            return 0;
        }
        catch (Exception e) {
            Log.w(TAG, "can't open the installer: " + e);
            return 2;
        }
    }

    /// the app's page in the Play Store (an app installed from there updates there)
    public static void openStorePage(Context ctx, String pkg) {
        if (ctx == null || pkg == null)
            return;
        for (String u : new String[] { "market://details?id=" + pkg, "https://play.google.com/store/apps/details?id=" + pkg }) {
            try {
                Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(u));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                ctx.startActivity(i);
                return;
            }
            catch (Exception ignored) {}
        }
    }

    /// a download's notification: progress 0-100, -1 unknown, 101 finished, -2 failed (then it can be swiped)
    public static void notifyDownload(Context ctx, int id, String title, String text, int progress) {
        if (ctx == null)
            return;
        try {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null)
                return;
            if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
                NotificationChannel ch = new NotificationChannel(CHANNEL, "Downloads", NotificationManager.IMPORTANCE_LOW);
                ch.setDescription("DeckOS and emulator updates being downloaded");
                ch.setShowBadge(false);
                nm.createNotificationChannel(ch);
            }
            boolean running = progress >= -1 && progress <= 100;
            NotificationCompat.Builder b = new NotificationCompat.Builder(ctx, CHANNEL)
                .setSmallIcon(running ? android.R.drawable.stat_sys_download : android.R.drawable.stat_sys_download_done)
                .setContentTitle(title)
                .setContentText(text)
                .setOnlyAlertOnce(true)
                .setOngoing(running)
                .setAutoCancel(!running)
                .setPriority(NotificationCompat.PRIORITY_LOW);
            if (running)
                b.setProgress(100, Math.max(0, progress), progress < 0);
            Intent open = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
            if (open != null) {
                int flags = android.app.PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? android.app.PendingIntent.FLAG_IMMUTABLE : 0);
                b.setContentIntent(android.app.PendingIntent.getActivity(ctx, 7000 + id, open, flags));
            }
            nm.notify(7000 + id, b.build());
        }
        catch (Exception e) {
            Log.w(TAG, "download notification: " + e);
        }
    }

    public static void cancelNotification(Context ctx, int id) {
        try {
            NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null) nm.cancel(7000 + id);
        }
        catch (Exception ignored) {}
    }
}
