// DeckOS - in-game layer
// The launch cover: the game page's launch screen stays over the game while it loads, then fades
// away - so the emulator's own loading screens and pop-ups (Winlator's boot screen, splash screens)
// are never seen. Right before the launch, C++ (InGame::showLaunchCover) takes a snapshot of the
// launch screen with the Steam logo and the spinner hidden and hands it here. This window draws the
// snapshot 1:1 where DeckOS's window was and plays the logo and the spinner over it, from where
// they were, so the hand-over can't be seen. Then the game starts underneath.
//
// The window takes touches (so Android shows it fully opaque) but not the controller, which goes to the
// game underneath. With DeckOS's accessibility service on (the controller shortcut), any button skips
// the rest of the wait. Needs "Display over other apps" or that accessibility service.

package com.deckos.ingame;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Movie;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.PorterDuff;
import android.graphics.RectF;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;


@SuppressWarnings("deprecation") // Movie: the only GIF player that can start mid-animation
final class LaunchCover extends View {
    private static final long FADE_MS = 600;
    private static final long QUICK_FADE_MS = 200;
    private static final long FRAME_MS = 33;
    private static final long SPINNER_STEP_MS = 70;   // the game page's spinner
    private static final long NO_SHOW_MS = 8000;      // DeckOS still in front by then: the game didn't start

    private static final Handler sMain = new Handler(Looper.getMainLooper());
    private static LaunchCover sCurrent;              // UI thread only

    private final WindowManager wm;
    private final Bitmap frame;
    private final int frameX, frameY;                 // where DeckOS's window was on screen, px
    private final RectF spinner, gifRect;             // in snapshot pixels; empty = not drawn
    private final int spinnerStep;
    private final Movie movie;
    private final Bitmap movieFrame;
    private final Canvas movieCanvas;
    private final long shownAt, movieStart;
    private final Paint bitmapPaint = new Paint(Paint.FILTER_BITMAP_FLAG | Paint.ANTI_ALIAS_FLAG);
    private final Paint dotPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final int[] origin = new int[2];
    private final RectF scratch = new RectF();
    private boolean closing = false;

    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            invalidate();
            sMain.postDelayed(this, FRAME_MS);
        }
    };

    private LaunchCover(Context ctx, Bitmap frame, int x, int y, RectF spinner, int spinnerStep,
                        RectF gifRect, Movie movie, float gifProgress) {
        super(ctx);
        this.wm = (WindowManager) ctx.getSystemService(Context.WINDOW_SERVICE);
        this.frame = frame;
        this.frameX = x;
        this.frameY = y;
        this.spinner = spinner;
        this.spinnerStep = spinnerStep;
        this.gifRect = gifRect;
        this.movie = movie;
        shownAt = SystemClock.uptimeMillis();
        if (movie != null && movie.width() > 0 && movie.height() > 0) {
            movieFrame = Bitmap.createBitmap(movie.width(), movie.height(), Bitmap.Config.ARGB_8888);
            movieCanvas = new Canvas(movieFrame);
            movieStart = shownAt - (long) (Math.max(0f, Math.min(1f, gifProgress)) * Math.max(1, movie.duration()));
        }
        else {
            movieFrame = null;
            movieCanvas = null;
            movieStart = shownAt;
        }
        dotPaint.setColor(Color.WHITE);
    }

    /// "Display over other apps", or the accessibility service (its overlay windows need no permission)
    static boolean possible() {
        return Session.overlayAllowed() || ShortcutService.instance() != null;
    }

    /// From C++ (Qt's thread). pixels: the snapshot (ARGB, w x h); x, y: DeckOS's window on screen;
    /// rects: {left, top, right, bottom} in snapshot pixels (empty: none); gifProgress: 0-1 into the
    /// logo's loop. The window appears a moment later on the UI thread.
    static boolean show(int[] pixels, int w, int h, int x, int y, float[] spinnerRect, int spinnerStep,
                        float[] logoRect, String gifPath, float gifProgress, int holdMs) {
        if (!possible() || pixels == null || w <= 0 || h <= 0 || pixels.length < w * h)
            return false;
        final Bitmap bmp;
        Movie m = null;
        try {
            bmp = Bitmap.createBitmap(pixels, w, h, Bitmap.Config.ARGB_8888);
            if (gifPath != null && !gifPath.isEmpty())
                m = Movie.decodeFile(gifPath);
        }
        catch (Throwable e) { // OutOfMemoryError included: then no cover, the launch goes on
            Log.w(Session.TAG, "launch cover: " + e);
            return false;
        }
        final Movie movie = m;
        final RectF sp = rect(spinnerRect), lg = rect(logoRect);
        final long hold = Math.max(500, holdMs);
        sMain.post(() -> {
            hideNow();
            ShortcutService acc = ShortcutService.instance();
            Context ctx = acc != null ? acc : Session.app();
            if (ctx == null || (acc == null && !Session.overlayAllowed()))
                return;
            LaunchCover v = new LaunchCover(ctx, bmp, x, y, sp, spinnerStep, lg, movie, gifProgress);
            int type = acc != null ? WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                     : Build.VERSION.SDK_INT >= 26 ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                     : WindowManager.LayoutParams.TYPE_PHONE;
            WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT, type,
                // touchable on purpose: Android 12+ caps a pass-through (FLAG_NOT_TOUCHABLE) app overlay at 80%
                // opacity, which let the loading emulator show through from the start. Not focusable: the
                // controller still goes to the game.
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                    | WindowManager.LayoutParams.FLAG_FULLSCREEN | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT);
            lp.gravity = Gravity.TOP | Gravity.START;
            if (Build.VERSION.SDK_INT >= 28)
                lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            if (Build.VERSION.SDK_INT >= 30)
                lp.setFitInsetsTypes(0); // over the status and navigation bar areas too
            lp.setTitle("DeckOS launch cover");
            try {
                v.wm.addView(v, lp);
            }
            catch (Exception e) {
                Log.w(Session.TAG, "can't show the launch cover: " + e);
                return;
            }
            sCurrent = v;
            sMain.post(v.tick);
            sMain.postDelayed(() -> v.fadeOut(FADE_MS), hold);
            sMain.postDelayed(() -> { if (Session.frontendInFront) v.fadeOut(QUICK_FADE_MS); }, Math.min(hold, NO_SHOW_MS));
        });
        return true;
    }

    /// DeckOS is back in front, or the launch was cancelled
    static void hide() {
        sMain.post(() -> { if (sCurrent != null) sCurrent.fadeOut(QUICK_FADE_MS); });
    }

    /// a controller button while the game loads underneath (accessibility service): stop waiting
    static void skip() {
        sMain.post(() -> {
            if (sCurrent != null && !Session.frontendInFront && SystemClock.uptimeMillis() - sCurrent.shownAt > 300)
                sCurrent.fadeOut(QUICK_FADE_MS);
        });
    }

    static boolean showing() { return sCurrent != null; }

    private static void hideNow() {
        if (sCurrent != null)
            sCurrent.remove();
    }

    private static RectF rect(float[] r) {
        return r != null && r.length == 4 && r[2] > r[0] && r[3] > r[1] ? new RectF(r[0], r[1], r[2], r[3]) : new RectF();
    }

    private void fadeOut(long ms) {
        if (closing)
            return;
        closing = true;
        animate().alpha(0f).setDuration(ms).withEndAction(this::remove).start();
    }

    private void remove() {
        sMain.removeCallbacks(tick);
        if (sCurrent == this)
            sCurrent = null;
        closing = true;
        try {
            wm.removeView(this);
        }
        catch (Exception ignored) {}
    }

    @Override
    protected void onDraw(Canvas canvas) {
        canvas.drawColor(Color.BLACK);
        getLocationOnScreen(origin);
        float dx = frameX - origin[0], dy = frameY - origin[1];
        canvas.drawBitmap(frame, dx, dy, null);
        long now = SystemClock.uptimeMillis();

        // the Steam logo, from where the game page's was in its loop
        if (movieFrame != null && !gifRect.isEmpty()) {
            movie.setTime((int) ((now - movieStart) % Math.max(1, movie.duration())));
            movieCanvas.drawColor(0, PorterDuff.Mode.CLEAR);
            movie.draw(movieCanvas, 0, 0);
            scratch.set(gifRect);
            scratch.offset(dx, dy);
            canvas.drawBitmap(movieFrame, null, scratch, bitmapPaint);
        }

        // the game page's spinner: 8 dots (6 x 10 of 50), the bright one stepping round every 70 ms
        if (!spinner.isEmpty()) {
            float k = spinner.width() / 50f;
            float cx = spinner.centerX() + dx, cy = spinner.centerY() + dy, top = spinner.top + dy;
            int step = (int) ((spinnerStep + (now - shownAt) / SPINNER_STEP_MS) % 8);
            for (int i = 0; i < 8; i++) {
                canvas.save();
                canvas.rotate(((i - step + 8) % 8) * 45f, cx, cy);
                dotPaint.setAlpha(Math.round(255 * (1f - i * 0.125f)));
                scratch.set(cx - 3 * k, top + 5 * k, cx + 3 * k, top + 15 * k);
                canvas.drawRoundRect(scratch, 3 * k, 3 * k, dotPaint);
                canvas.restore();
            }
        }
    }
}
