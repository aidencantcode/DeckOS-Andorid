// DeckOS - in-game layer
// "Keep game running": the Quick Access panel in an overlay window instead of an activity. The game's
// activity is never paused (no app switch); the overlay window only takes the controller while it's
// open. Needs "Display over other apps" - or, opened by the controller shortcut, DeckOS's
// accessibility service, whose own overlay windows need no permission.

package com.deckos.ingame;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.util.Log;
import android.view.Gravity;
import android.view.WindowManager;


final class QuickAccessOverlay implements QuickAccessPanel.Host {
    private static QuickAccessOverlay sCurrent;

    private final Context ctx;
    private final WindowManager wm;
    private QuickAccessPanel panel;

    private QuickAccessOverlay(Context ctx) {
        this.ctx = ctx;
        this.wm = (WindowManager) ctx.getSystemService(Context.WINDOW_SERVICE);
    }

    static boolean showing() { return sCurrent != null; }

    /// false if it can't be shown (no permission): the caller falls back to the activity
    static boolean show(Context ctx) {
        if (sCurrent != null)
            return true;
        boolean accessibility = ctx instanceof AccessibilityService;
        if (!accessibility && !Session.overlayAllowed())
            return false;
        QuickAccessOverlay o = new QuickAccessOverlay(accessibility ? ctx : ctx.getApplicationContext());
        int type = accessibility ? WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                 : Build.VERSION.SDK_INT >= 26 ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                 : WindowManager.LayoutParams.TYPE_PHONE;
        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT, type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN | WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.START;
        if (Build.VERSION.SDK_INT >= 28)
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        lp.setTitle("DeckOS Quick Access");
        o.panel = new QuickAccessPanel(o.ctx, o);
        try {
            o.wm.addView(o.panel, lp);
        }
        catch (Exception e) {
            Log.w(Session.TAG, "can't show the quick access overlay: " + e);
            return false;
        }
        sCurrent = o;
        o.panel.open();
        return true;
    }

    static void hide() {
        if (sCurrent != null)
            sCurrent.panel.close();
    }

    // --- QuickAccessPanel.Host --------------------------------------------------------------------

    @Override
    public void dismiss() {
        if (sCurrent == this)
            sCurrent = null;
        panel.pause();
        try {
            wm.removeView(panel);
        }
        catch (Exception ignored) {}
    }

    @Override
    public void launch(Intent intent) {
        dismiss();
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            ctx.startActivity(intent);
        }
        catch (Exception e) {
            Log.w(Session.TAG, "can't open " + intent.getAction() + ": " + e);
        }
    }

    @Override
    public boolean pausesGame() { return false; }
}
