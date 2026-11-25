// DeckOS - in-game layer
// "Exit game" in Quick Access, like the Deck's: after the confirmation the screen fades to black, the
// emulator is closed, DeckOS comes back on its Home page (Session.takeExitToHome, read by C++), and the
// black fades away once DeckOS is in front.
// Closing: `am force-stop <package>` through PServer (AYN / Retroid) ends the emulator at once, so any
// unsaved progress is lost (the dialog says so). Without PServer, Android only lets an app end another
// app's background processes: DeckOS comes to the front first, then asks Android to stop the emulator.
// The black window needs "Display over other apps" or DeckOS's accessibility service; without them the
// exit happens without the fade.

package com.deckos.ingame;

import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;


final class GameExit {
    private GameExit() {}

    private static final long FADE_IN_MS = 350;
    private static final long FADE_OUT_MS = 450;
    private static final long SAFETY_MS = 6000;     // DeckOS never came back: the black goes anyway

    private static final Handler sMain = new Handler(Looper.getMainLooper());
    private static View sBlack;                    // UI thread only
    private static final Runnable FADE_OUT = GameExit::fadeOut;
    private static WindowManager sWm;

    /// there is a game to close (its package is known)
    static boolean possible() {
        return Session.hasGame() && !Session.gamePackage.isEmpty();
    }

    /// ctx: the Quick Access panel's (the activity, the accessibility service or the app); dismiss
    /// removes the panel - under the black when there is one
    static void exit(Context ctx, Runnable dismiss) {
        final String pkg = Session.gamePackage;
        if (pkg.isEmpty())
            return;
        final Context app = ctx.getApplicationContext();
        Log.i(Session.TAG, "exit game: " + pkg);
        Runnable close = () -> {
            Session.requestHomeAfterExit();
            Session.setGameFocused(false); // play time ends now
            boolean stopped = Privileged.available() && Privileged.run("am force-stop " + Privileged.quote(pkg));
            bringDeckOS(ctx);
            if (dismiss != null) dismiss.run();
            if (!stopped)
                sMain.postDelayed(() -> killInBackground(app, pkg), 800);
        };
        if (!showBlack(close))
            close.run();
    }

    /// DeckOS is in front again: show it
    static void onFrontendResumed() {
        if (sBlack != null)
            sMain.postDelayed(FADE_OUT, 350); // a moment for DeckOS to draw its Home page
    }

    private static void bringDeckOS(Context ctx) {
        Intent i = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        if (i == null)
            return;
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
        try {
            ctx.startActivity(i);
        }
        catch (Exception e) {
            Log.w(Session.TAG, "can't bring DeckOS back: " + e);
        }
    }

    private static void killInBackground(Context app, String pkg) {
        try {
            ActivityManager am = (ActivityManager) app.getSystemService(Context.ACTIVITY_SERVICE);
            if (am != null) am.killBackgroundProcesses(pkg);
        }
        catch (Exception e) {
            Log.w(Session.TAG, "can't stop " + pkg + ": " + e);
        }
    }

    /// fades a black window in over everything, then runs `then`; false if it can't be shown
    private static boolean showBlack(Runnable then) {
        ShortcutService acc = ShortcutService.instance();
        Context ctx = acc != null ? acc : Session.app();
        if (ctx == null || (acc == null && !Session.overlayAllowed()))
            return false;
        removeBlack();
        int type = acc != null ? WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                 : Build.VERSION.SDK_INT >= 26 ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                 : WindowManager.LayoutParams.TYPE_PHONE;
        // touchable, so Android shows it fully opaque (see LaunchCover)
        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS | WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.START;
        if (Build.VERSION.SDK_INT >= 28)
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        if (Build.VERSION.SDK_INT >= 30)
            lp.setFitInsetsTypes(0);
        lp.setTitle("DeckOS exit game");
        View v = new View(ctx);
        v.setBackgroundColor(Color.BLACK);
        v.setAlpha(0f);
        WindowManager wm = (WindowManager) ctx.getSystemService(Context.WINDOW_SERVICE);
        try {
            wm.addView(v, lp);
        }
        catch (Exception e) {
            Log.w(Session.TAG, "can't show the exit fade: " + e);
            return false;
        }
        sBlack = v;
        sWm = wm;
        v.animate().alpha(1f).setDuration(FADE_IN_MS).withEndAction(then).start();
        sMain.postDelayed(FADE_OUT, FADE_IN_MS + SAFETY_MS);
        return true;
    }

    private static void fadeOut() {
        final View v = sBlack;
        if (v == null)
            return;
        sBlack = null;
        sMain.removeCallbacks(FADE_OUT);
        v.animate().cancel();
        v.animate().alpha(0f).setDuration(FADE_OUT_MS).withEndAction(() -> {
            try {
                sWm.removeView(v);
            }
            catch (Exception ignored) {}
        }).start();
    }

    private static void removeBlack() {
        if (sBlack == null)
            return;
        try {
            sWm.removeView(sBlack);
        }
        catch (Exception ignored) {}
        sBlack = null;
    }
}
