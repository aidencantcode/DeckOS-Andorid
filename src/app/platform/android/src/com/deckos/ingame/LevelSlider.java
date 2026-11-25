// DeckOS - in-game layer
// Steam's "Performance Overlay Level" slider: OFF 1 2 3 4. D-pad left/right (or a tap) changes it.

package com.deckos.ingame;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;


final class LevelSlider extends View {
    interface Listener { void onLevel(int level); }

    private static final String[] LABELS = { "OFF", "1", "2", "3", "4" };
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float u;
    private int level;
    private final Listener listener;

    LevelSlider(Context ctx, float u, int level, Listener listener) {
        super(ctx);
        this.u = u;
        this.level = level;
        this.listener = listener;
        setFocusable(true);
        setClickable(true);
        setMinimumHeight(Math.round(48 * u));
    }

    private void set(int value) {
        value = Math.max(0, Math.min(LABELS.length - 1, value));
        if (value == level)
            return;
        level = value;
        invalidate();
        if (listener != null)
            listener.onLevel(level);
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT) { set(level - 1); return true; }
        if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT) { set(level + 1); return true; }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean onTouchEvent(MotionEvent e) {
        if (e.getAction() == MotionEvent.ACTION_DOWN || e.getAction() == MotionEvent.ACTION_MOVE) {
            float left = knobRadius(), right = getWidth() - knobRadius();
            float t = (e.getX() - left) / Math.max(1, right - left);
            set(Math.round(t * (LABELS.length - 1)));
            return true;
        }
        return super.onTouchEvent(e);
    }

    @Override
    protected void onFocusChanged(boolean gainFocus, int direction, android.graphics.Rect previous) {
        super.onFocusChanged(gainFocus, direction, previous);
        invalidate();
    }

    private float knobRadius() { return 11 * u; }

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        setMeasuredDimension(MeasureSpec.getSize(widthSpec), Math.round(48 * u));
    }

    @Override
    protected void onDraw(Canvas c) {
        float r = knobRadius();
        float left = r, right = getWidth() - r;
        float cy = 14 * u;
        float step = (right - left) / (LABELS.length - 1);
        float knobX = left + step * level;

        // track: blue up to the knob, dark after it
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.rgb(0x0b, 0x0e, 0x12));
        c.drawRoundRect(new RectF(left, cy - 3 * u, right, cy + 3 * u), 3 * u, 3 * u, paint);
        paint.setColor(Ui.BLUE);
        c.drawRoundRect(new RectF(left, cy - 3 * u, knobX, cy + 3 * u), 3 * u, 3 * u, paint);

        // ticks + labels
        paint.setTextSize(11 * u);
        paint.setTypeface(Typeface.DEFAULT_BOLD);
        paint.setTextAlign(Paint.Align.CENTER);
        for (int i = 0; i < LABELS.length; i++) {
            float x = left + step * i;
            paint.setColor(i <= level ? Ui.BLUE : Color.rgb(0x5d, 0x66, 0x72));
            c.drawRect(x - 1.5f * u, cy + 6 * u, x + 1.5f * u, cy + 14 * u, paint);
            paint.setColor(i == level ? Color.WHITE : Ui.DIM);
            c.drawText(LABELS[i], x, cy + 28 * u, paint);
        }

        // knob (with a focus ring while the controller is on it)
        if (isFocused()) {
            paint.setColor(Color.argb(90, 255, 255, 255));
            c.drawCircle(knobX, cy, r + 5 * u, paint);
        }
        paint.setColor(Color.WHITE);
        c.drawCircle(knobX, cy, r, paint);
    }
}
