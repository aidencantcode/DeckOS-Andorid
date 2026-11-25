// DeckOS - in-game layer
// A continuous Steam-style slider (0-100): the brightness slider in Quick Settings.
// D-pad left/right move it in steps (held: repeats), a tap or drag sets it directly.

package com.deckos.ingame;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;


final class ValueSlider extends View {
    interface Listener { void onValue(int value, boolean done); }

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float u;
    private final int step;
    private int value;
    private final Listener listener;

    ValueSlider(Context ctx, float u, int value, int step, Listener listener) {
        super(ctx);
        this.u = u;
        this.value = Math.max(0, Math.min(100, value));
        this.step = Math.max(1, step);
        this.listener = listener;
        setFocusable(true);
        setClickable(true);
    }

    void setValue(int v) {
        v = Math.max(0, Math.min(100, v));
        if (v == value) return;
        value = v;
        invalidate();
    }

    private void change(int v, boolean done) {
        v = Math.max(0, Math.min(100, v));
        boolean changed = v != value;
        value = v;
        invalidate();
        if (listener != null && (changed || done))
            listener.onValue(value, done);
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT) { change(value - step, false); return true; }
        if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT) { change(value + step, false); return true; }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT || keyCode == KeyEvent.KEYCODE_DPAD_RIGHT) {
            change(value, true);
            return true;
        }
        return super.onKeyUp(keyCode, event);
    }

    @Override
    public boolean onTouchEvent(MotionEvent e) {
        int a = e.getAction();
        if (a == MotionEvent.ACTION_DOWN || a == MotionEvent.ACTION_MOVE || a == MotionEvent.ACTION_UP) {
            float r = knob(), left = r, right = getWidth() - r;
            float t = (e.getX() - left) / Math.max(1, right - left);
            change(Math.round(t * 100), a == MotionEvent.ACTION_UP);
            return true;
        }
        return super.onTouchEvent(e);
    }

    @Override
    protected void onFocusChanged(boolean gainFocus, int direction, android.graphics.Rect previous) {
        super.onFocusChanged(gainFocus, direction, previous);
        invalidate();
    }

    private float knob() { return 11 * u; }

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        setMeasuredDimension(MeasureSpec.getSize(widthSpec), Math.round(32 * u));
    }

    @Override
    protected void onDraw(Canvas c) {
        float r = knob(), left = r, right = getWidth() - r, cy = getHeight() / 2f;
        float x = left + (right - left) * value / 100f;
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(0x0b, 0x0e, 0x12));
        c.drawRoundRect(new RectF(left, cy - 3 * u, right, cy + 3 * u), 3 * u, 3 * u, paint);
        paint.setColor(Ui.BLUE);
        c.drawRoundRect(new RectF(left, cy - 3 * u, x, cy + 3 * u), 3 * u, 3 * u, paint);
        if (isFocused()) {
            paint.setColor(Color.argb(90, 255, 255, 255));
            c.drawCircle(x, cy, r + 5 * u, paint);
        }
        paint.setColor(Color.WHITE);
        c.drawCircle(x, cy, r, paint);
    }
}
