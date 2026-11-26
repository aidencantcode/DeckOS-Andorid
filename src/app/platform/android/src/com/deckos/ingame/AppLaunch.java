// DeckOS - in-game layer
// Opening an Android app the way the home screen opens it.
//
// Pegasus opened apps with "am start -a android.intent.action.MAIN -n <app>/<activity>": an intent
// without the launcher category. Before reusing a running app, Android compares the new intent with
// the one that started the app's task (Intent.filterEquals: action, categories, package, component,
// data). The home screen's intent has the launcher category, Pegasus's didn't, so they never matched:
// an app already open from the home screen (or opened there after DeckOS) got a second copy of its
// first screen on top of the running one. Games started over, showed their start-up pop-ups again
// (Among Us's Announcements, over a dimmed screen), or ran twice.
//
// The home screen (Launcher3 and the launchers built on it) sends Intent.makeMainActivity(component):
// ACTION_MAIN + CATEGORY_LAUNCHER + the component, no package, with FLAG_ACTIVITY_NEW_TASK |
// FLAG_ACTIVITY_RESET_TASK_IF_NEEDED. With the same intent a running app comes back as it was, and
// one opened from DeckOS comes back from the home screen too. (PackageManager.getLaunchIntentForPackage,
// which NeoStation and the old Resume used, also sets the package, so it doesn't match the home screen's
// either.) RESET_TASK_IF_NEEDED also brings back an app whose task was started on another screen
// (an emulator opened with a game) instead of opening its main menu on top.

package com.deckos.ingame;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import java.util.List;
import java.util.Set;


public final class AppLaunch {
    private AppLaunch() {}

    static final int HOME_FLAGS = Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED;

    /// the home screen's intent for an app; null if it has no launcher entry
    public static Intent forPackage(Context ctx, String pkg) {
        if (ctx == null || pkg == null || pkg.isEmpty())
            return null;
        final ComponentName cn = launcherActivity(ctx.getPackageManager(), pkg);
        if (cn == null)
            return null;
        final Intent i = Intent.makeMainActivity(cn);
        i.setFlags(HOME_FLAGS);
        return i;
    }

    /// An "am start" that only opens an app (action MAIN or none, a component or a package, nothing
    /// else: what DeckOS and Pegasus write for Android apps) becomes the home screen's intent, in place.
    /// Anything with data, a type, extras or another category (emulators with a game, shortcuts) is
    /// left alone. True if it was an app launch.
    public static boolean asHomeScreen(Context ctx, Intent intent) {
        if (ctx == null || intent == null)
            return false;
        final String action = intent.getAction();
        if (action != null && !Intent.ACTION_MAIN.equals(action))
            return false;
        if (intent.getData() != null || intent.getType() != null || intent.getSelector() != null)
            return false;
        if (Build.VERSION.SDK_INT >= 29 && intent.getIdentifier() != null)
            return false;
        final Bundle extras = intent.getExtras();
        if (extras != null && !extras.isEmpty())
            return false;
        final Set<String> categories = intent.getCategories();
        if (categories != null) {
            for (String c : categories) {
                if (!Intent.CATEGORY_LAUNCHER.equals(c))
                    return false;
            }
        }

        ComponentName cn = intent.getComponent();
        final String pkg = cn != null ? cn.getPackageName() : intent.getPackage();
        if (pkg == null || pkg.isEmpty())
            return false;
        final PackageManager pm = ctx.getPackageManager();
        if (cn == null || !exists(pm, cn)) {
            // a package only, or an activity the app doesn't have any more (renamed in an update)
            final ComponentName found = launcherActivity(pm, pkg);
            if (found != null)
                cn = found;
            else if (cn == null)
                return false;
        }

        // flags written in the command stay (--activity-clear-task...); granting file access means nothing here
        final int kept = intent.getFlags()
            & ~(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        intent.setAction(Intent.ACTION_MAIN);
        intent.addCategory(Intent.CATEGORY_LAUNCHER);
        intent.setPackage(null);
        intent.setComponent(cn);
        intent.setFlags(kept | HOME_FLAGS);
        Log.i(Session.TAG, "opening " + cn.flattenToShortString() + " as the home screen does");
        return true;
    }

    /// the activity the home screen shows for the app (its first MAIN + LAUNCHER one; TV apps: leanback)
    static ComponentName launcherActivity(PackageManager pm, String pkg) {
        try {
            final Intent query = new Intent(Intent.ACTION_MAIN);
            query.addCategory(Intent.CATEGORY_LAUNCHER);
            query.setPackage(pkg);
            final List<ResolveInfo> found = pm.queryIntentActivities(query, 0);
            if (found != null && !found.isEmpty() && found.get(0).activityInfo != null)
                return new ComponentName(found.get(0).activityInfo.packageName, found.get(0).activityInfo.name);
            if (Build.VERSION.SDK_INT >= 21) {
                final Intent tv = pm.getLeanbackLaunchIntentForPackage(pkg);
                if (tv != null && tv.getComponent() != null)
                    return tv.getComponent();
            }
        }
        catch (Exception e) {
            Log.w(Session.TAG, "launcher entry of " + pkg + ": " + e);
        }
        return null;
    }

    private static boolean exists(PackageManager pm, ComponentName cn) {
        try {
            pm.getActivityInfo(cn, 0);
            return true;
        }
        catch (PackageManager.NameNotFoundException e) {
            return false;
        }
        catch (Exception e) {
            return true; // can't tell: try it as written
        }
    }
}
