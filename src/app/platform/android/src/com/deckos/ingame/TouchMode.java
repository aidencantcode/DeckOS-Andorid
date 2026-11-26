// DeckOS - in-game layer
// Android apps open in touch mode, as they do from the home screen.
//
// Android keeps a "touch mode": a touch turns it on, a D-pad or arrow key turns it off, and an app that
// opens starts in the current mode. Moving through DeckOS with the controller turns it off, so an app
// opened from DeckOS starts in keyboard mode. There Android draws its default focus highlight over the
// focused view of any app that has no focus look of its own - for a game made of one big view (Unity),
// a tint over the whole screen. The same app opened with a tap on the home screen starts in touch mode
// and shows nothing. (Pegasus does the same as DeckOS did.)
//
// So before an app opens, DeckOS turns touch mode back on the only way an app can: with a touch on one
// of its own windows. A transparent 8 x 8 px panel is added in the middle of DeckOS's window, one tap
// is injected on it (Instrumentation: an app may inject input into its own windows without any
// permission; the launch cover, also DeckOS's, can be the one on top), and the panel is removed. Nothing
// in DeckOS reacts to the tap. Emulators opened with a game are left alone: their touch controls can
// depend on the mode, and none showed the problem.

package com.deckos.ingame;

import android.app.Activity;
import android.app.Instrumentation;
import android.graphics.PixelFormat;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;


public final class TouchMode {
    private TouchMode() {}

    private static final int SIZE_PX = 8;
    private static final long PANEL_WAIT_MS = 400;
    private static final long TAP_WAIT_MS = 700;

    private static volatile String sNote = "";

    /// what the last app launch did, for DeckOS's log (ProcessLauncher); read once
    public static String lastNote() {
        final String n = sNote;
        sNote = "";
        return n;
    }

    /// Right before an app opens, on Qt's thread (not Android's UI thread). Takes ~0.1 s, 1.1 s at most.
    public static void enterBeforeLaunch(final Activity activity) {
        sNote = "";
        if (activity == null || activity.getWindow() == null)
            return;
        if (Looper.myLooper() == Looper.getMainLooper()) {
            note("touch mode: not switched (called on the UI thread)");
            return;
        }
        final View decor = activity.getWindow().getDecorView();
        if (decor == null || decor.isInTouchMode()) {
            note("touch mode: already on");
            return;
        }

        final Handler main = new Handler(Looper.getMainLooper());
        final View[] panel = new View[1];
        final int[] at = new int[2];
        final CountDownLatch shown = new CountDownLatch(1);
        main.post(() -> {
            try {
                final View v = new View(activity) {
                    @Override
                    public boolean onTouchEvent(MotionEvent e) {
                        return true; // the tap ends here
                    }
                };
                final WindowManager.LayoutParams lp = new WindowManager.LayoutParams(SIZE_PX, SIZE_PX,
                    WindowManager.LayoutParams.TYPE_APPLICATION_PANEL,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT);
                lp.gravity = Gravity.CENTER;
                lp.setTitle("DeckOS touch mode");
                activity.getWindowManager().addView(v, lp);
                panel[0] = v;
                v.post(() -> { // after its first layout
                    v.getLocationOnScreen(at);
                    shown.countDown();
                });
            }
            catch (Throwable e) {
                note("touch mode: no panel (" + e + ")");
                shown.countDown();
            }
        });

        try {
            if (!shown.await(PANEL_WAIT_MS, TimeUnit.MILLISECONDS) || panel[0] == null) {
                if (sNote.isEmpty())
                    note("touch mode: the panel didn't appear in time");
                removeLater(main, activity, panel);
                return;
            }
            Thread.sleep(50); // the panel's window reaches the input system (Android 13+ also syncs itself)

            final float x = at[0] + SIZE_PX / 2f, y = at[1] + SIZE_PX / 2f;
            final String[] result = { null };
            final CountDownLatch tapped = new CountDownLatch(1);
            final Thread worker = new Thread(() -> {
                try {
                    final Instrumentation ins = new Instrumentation();
                    final long t0 = SystemClock.uptimeMillis();
                    final MotionEvent down = MotionEvent.obtain(t0, t0, MotionEvent.ACTION_DOWN, x, y, 0);
                    down.setSource(InputDevice.SOURCE_TOUCHSCREEN);
                    ins.sendPointerSync(down);
                    down.recycle();
                    final MotionEvent up = MotionEvent.obtain(t0, SystemClock.uptimeMillis(), MotionEvent.ACTION_UP, x, y, 0);
                    up.setSource(InputDevice.SOURCE_TOUCHSCREEN);
                    ins.sendPointerSync(up);
                    up.recycle();
                    result[0] = "tap sent";
                }
                catch (Throwable e) { // SecurityException: another app's window was on top there
                    result[0] = "tap refused (" + e.getClass().getSimpleName() + ": " + e.getMessage() + ")";
                }
                tapped.countDown();
            }, "DeckOS touch mode");
            worker.setDaemon(true);
            worker.start();
            final boolean done = tapped.await(TAP_WAIT_MS, TimeUnit.MILLISECONDS);
            note("touch mode: " + (done ? result[0] : "tap still pending, app opens anyway")
                 + "; panel in touch mode " + panel[0].isInTouchMode() + ", DeckOS " + decor.isInTouchMode());
        }
        catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        finally {
            removeLater(main, activity, panel);
        }
    }

    /// posted after the panel's own add, so it always runs after it (the UI thread runs them in order)
    private static void removeLater(Handler main, final Activity activity, final View[] panel) {
        main.postDelayed(() -> {
            final View v = panel[0];
            panel[0] = null;
            if (v == null)
                return;
            try {
                activity.getWindowManager().removeViewImmediate(v);
            }
            catch (Throwable ignored) {}
        }, 300);
    }

    private static void note(String s) {
        sNote = s;
        Log.i(Session.TAG, s);
    }
}
