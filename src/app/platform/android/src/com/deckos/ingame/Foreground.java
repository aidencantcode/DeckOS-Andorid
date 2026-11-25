// DeckOS - in-game layer
// Which app is in front while a game runs, so play time counts only while the app DeckOS opened is the
// one in front (Session). Sources, best first:
//  1. Android's usage stats: every activity resume / pause with its exact time, read every 2 s by
//     SessionService. Exact even between reads, the screen going off included. Needs "Usage access",
//     which DeckOS gives itself through PServer / root (appops) at the first launch, or the user in
//     Android's settings (Settings > Overlay > Play time).
//  2. DeckOS's accessibility service (window changes, at once; ShortcutService)
//  3. PServer / root: dumpsys every 5 s (SessionService.checkForeground)
// With none of them, play time counts until DeckOS is back, as Pegasus did.

package com.deckos.ingame;

import android.app.AppOpsManager;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.os.Handler;
import android.os.Process;
import android.provider.Settings;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;


final class Foreground {
    // UsageEvents.Event types (numbers: the names changed between Android versions)
    static final int RESUMED = 1;         // MOVE_TO_FOREGROUND / ACTIVITY_RESUMED
    static final int PAUSED = 2;          // MOVE_TO_BACKGROUND / ACTIVITY_PAUSED
    static final int SCREEN_OFF = 16;     // SCREEN_NON_INTERACTIVE (Android 9+)
    static final int STOPPED = 23;        // ACTIVITY_STOPPED (Android 10+)

    private static volatile long sSince = 0;
    private static volatile boolean sUsageOk = false;
    private static volatile long sUsageCheckedAt = 0;

    private Foreground() {}

    // --- usage access ------------------------------------------------------------------------------

    /// DeckOS may read the usage stats (checked again at most every 5 s)
    static boolean usageAllowed(Context ctx) {
        long now = System.currentTimeMillis();
        if (now - sUsageCheckedAt < 5000)
            return sUsageOk;
        sUsageCheckedAt = now;
        sUsageOk = false;
        if (ctx == null || Build.VERSION.SDK_INT < 22)
            return false;
        try {
            AppOpsManager ops = (AppOpsManager) ctx.getSystemService(Context.APP_OPS_SERVICE);
            int mode = ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.getPackageName());
            sUsageOk = mode == AppOpsManager.MODE_DEFAULT
                ? ctx.checkCallingOrSelfPermission("android.permission.PACKAGE_USAGE_STATS") == PackageManager.PERMISSION_GRANTED
                : mode == AppOpsManager.MODE_ALLOWED;
        }
        catch (Exception e) {
            Log.w(Session.TAG, "usage access check: " + e);
        }
        return sUsageOk;
    }

    /// gives DeckOS usage access through PServer / root; false if neither is there
    static boolean grantUsage(Context ctx) {
        if (ctx == null || !Privileged.available())
            return false;
        sUsageCheckedAt = 0; // look again next time
        return Privileged.run("appops set " + ctx.getPackageName() + " GET_USAGE_STATS allow");
    }

    static void openUsageSettings() {
        Session.openSettings(new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS));
    }


    // --- the app a launch opens ----------------------------------------------------------------------

    /// the package Android opens for `intent`: its component or package, else what it resolves to.
    /// "" for Android's "Open with" chooser (the user picks the app; the first one in front is taken).
    static String packageOf(Context ctx, Intent intent) {
        if (ctx == null || intent == null)
            return "";
        if (intent.getComponent() != null)
            return intent.getComponent().getPackageName();
        if (intent.getPackage() != null)
            return intent.getPackage();
        try {
            ResolveInfo r = ctx.getPackageManager().resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY);
            if (r != null && r.activityInfo != null && !"android".equals(r.activityInfo.packageName))
                return r.activityInfo.packageName;
        }
        catch (Exception e) {
            Log.w(Session.TAG, "can't resolve the launch: " + e);
        }
        return "";
    }


    // --- reading the activity changes (SessionService's stats thread) ------------------------------

    /// a game was launched at `at`: changes from just before it on are read
    static void startSession(long at) {
        sSince = at - 1000;
    }

    static final class Change {
        final int type;
        final String pkg, cls;
        final long at;
        Change(int type, String pkg, String cls, long at) { this.type = type; this.pkg = pkg; this.cls = cls; this.at = at; }
    }

    /// Reads what changed since the last call and hands it to Session on `main`. False if the usage
    /// stats can't be read (no access, or no session): the other sources are used then.
    static boolean poll(Context ctx, Handler main) {
        if (sSince == 0 || !usageAllowed(ctx))
            return false;
        final List<Change> changes = new ArrayList<>();
        try {
            UsageStatsManager usm = (UsageStatsManager) ctx.getSystemService(Context.USAGE_STATS_SERVICE);
            if (usm == null)
                return false;
            long now = System.currentTimeMillis();
            UsageEvents events = usm.queryEvents(sSince, now + 1000);
            UsageEvents.Event e = new UsageEvents.Event();
            long last = sSince - 1;
            while (events != null && events.hasNextEvent()) {
                events.getNextEvent(e);
                long t = e.getTimeStamp();
                if (t < sSince)
                    continue;
                last = Math.max(last, t);
                int type = e.getEventType();
                if (type == RESUMED || type == PAUSED || type == STOPPED || type == SCREEN_OFF)
                    changes.add(new Change(type, e.getPackageName(), e.getClassName(), t));
            }
            sSince = last + 1;
        }
        catch (Exception ex) {
            Log.w(Session.TAG, "usage events: " + ex);
            return false;
        }
        if (!changes.isEmpty())
            main.post(() -> {
                for (Change c : changes)
                    Session.onActivityChange(c.type, c.pkg, c.cls, c.at);
            });
        return true;
    }

    /// the usage stats are the source right now (the others are ignored then)
    static boolean usageActive(Context ctx) {
        return sSince != 0 && usageAllowed(ctx);
    }
}
