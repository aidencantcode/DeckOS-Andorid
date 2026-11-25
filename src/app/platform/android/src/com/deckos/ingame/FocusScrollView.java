// DeckOS - in-game layer
// The Quick Access tabs' scroller, for the controller. Android's ScrollView jumps half a page when the
// next option is further than that (a big empty gap on screen) and snaps to the focused one without
// animation. Here the focus always moves to the next option and the list glides just enough to keep it
// in view with some of its neighbours, like the Deck's menus.

package com.deckos.ingame;

import android.content.Context;
import android.graphics.Rect;
import android.view.KeyEvent;
import android.view.View;
import android.widget.ScrollView;


final class FocusScrollView extends ScrollView {
    private final Rect rect = new Rect();

    FocusScrollView(Context ctx) {
        super(ctx);
    }

    /// no half-page jumps: D-pad keys move the focus (the window's normal focus search)
    @Override
    public boolean executeKeyEvent(KeyEvent event) {
        return false;
    }

    /// ScrollView's own "bring the focused view on screen" snap - done by reveal() instead
    @Override
    protected int computeScrollDeltaToGetChildRectOnScreen(Rect r) {
        return 0;
    }

    @Override
    public void requestChildFocus(View child, View focused) {
        super.requestChildFocus(child, focused);
        if (focused != null)
            post(() -> reveal(focused));
    }

    /// scroll so the focused view sits inside the middle part of the view (a margin of about a fifth of
    /// the height above and below); the first and last options take the list to its ends
    void reveal(View v) {
        if (getChildCount() == 0 || !v.isAttachedToWindow() || !isAncestor(v))
            return;
        v.getDrawingRect(rect);
        offsetDescendantRectToMyCoords(v, rect);
        int h = getHeight();
        int top = getScrollY();
        int max = Math.max(0, getChildAt(0).getHeight() - h);
        int margin = Math.round(h * 0.2f);
        int target = top;
        if (rect.height() >= h - 2 * margin)
            target = rect.top - margin / 2;              // taller than the middle part: its top in view
        else if (rect.top - margin < top)
            target = rect.top - margin;
        else if (rect.bottom + margin > top + h)
            target = rect.bottom + margin - h;
        target = Math.max(0, Math.min(max, target));
        if (target != top)
            smoothScrollTo(0, target);
    }

    private boolean isAncestor(View v) {
        for (Object p = v.getParent(); p != null; p = ((View) p).getParent()) {
            if (p == this) return true;
            if (!(p instanceof View)) return false;
        }
        return false;
    }
}
