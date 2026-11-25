// DeckOS - in-game layer
// Small view helpers for the Quick Access overlay: Steam Deck colours, text, focusable rows/buttons.
// Sizes are in Steam Deck pixels (`u` = screen height / 800), so the overlay keeps the Deck's
// proportions on any screen.

package com.deckos.ingame;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;


final class Ui {
    static final int TOP_BAR = Color.rgb(0x0b, 0x0e, 0x12);
    static final int RAIL = Color.rgb(0x16, 0x1a, 0x20);
    static final int PANEL = Color.rgb(0x1f, 0x23, 0x29);
    static final int CARD = Color.rgb(0x2a, 0x2f, 0x37);
    static final int CARD_FILL = Color.rgb(0x3a, 0x40, 0x4a);
    static final int SELECTED = Color.rgb(0x3d, 0x44, 0x50);
    static final int FOCUS = Color.rgb(0x52, 0x5c, 0x6b);
    static final int BUTTON = Color.rgb(0x3d, 0x44, 0x50);
    static final int BUTTON_FOCUS = Color.rgb(0xdc, 0xde, 0xdf);
    static final int FOCUS_RING = Color.rgb(0xe8, 0xf2, 0xff);
    static final int TEXT = Color.WHITE;
    static final int TEXT2 = Color.rgb(0xb8, 0xbc, 0xbf);
    static final int DIM = Color.rgb(0x8b, 0x92, 0x9a);
    static final int BLUE = Color.rgb(0x1a, 0x9f, 0xff);
    static final int GREEN = Color.rgb(0x59, 0xbf, 0x40);
    static final int GOLD = Color.rgb(0xf5, 0xa6, 0x23);
    static final int ORANGE = Color.rgb(0xe0, 0xa0, 0x40);

    final Context ctx;
    final float u;

    Ui(Context ctx, float u) {
        this.ctx = ctx;
        this.u = u;
    }

    int px(float deckPx) { return Math.round(deckPx * u); }

    TextView text(String s, float size, int color, boolean bold) {
        TextView t = new TextView(ctx);
        t.setText(s);
        t.setTextSize(TypedValue.COMPLEX_UNIT_PX, size * u);
        t.setTextColor(color);
        t.setTypeface(bold ? Typeface.DEFAULT_BOLD : Typeface.DEFAULT);
        t.setIncludeFontPadding(false);
        return t;
    }

    TextView caps(String s) {
        TextView t = text(s.toUpperCase(), 12, DIM, true);
        t.setLetterSpacing(0.06f);
        return t;
    }

    ImageView icon(int res, float size, int tint) {
        ImageView v = new ImageView(ctx);
        v.setImageResource(res);
        v.setColorFilter(tint);
        v.setLayoutParams(new LinearLayout.LayoutParams(px(size), px(size)));
        return v;
    }

    static GradientDrawable rect(int color, float radius) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(radius);
        return d;
    }

    /// background that lights up while the view has controller focus
    Drawable focusable(int normal, int focused) {
        StateListDrawable s = new StateListDrawable();
        // the controller's focus: the lighter fill plus a light outline, so it's never missed
        GradientDrawable ring = rect(focused, 3 * u);
        ring.setStroke(Math.max(2, Math.round(2 * u)), FOCUS_RING);
        s.addState(new int[] { android.R.attr.state_focused }, ring);
        s.addState(new int[] { android.R.attr.state_pressed }, rect(focused, 3 * u));
        s.addState(new int[] {}, rect(normal, 3 * u));
        return s;
    }

    LinearLayout column() {
        LinearLayout l = new LinearLayout(ctx);
        l.setOrientation(LinearLayout.VERTICAL);
        return l;
    }

    LinearLayout row() {
        LinearLayout l = new LinearLayout(ctx);
        l.setOrientation(LinearLayout.HORIZONTAL);
        l.setGravity(Gravity.CENTER_VERTICAL);
        return l;
    }

    static LinearLayout.LayoutParams wrap() {
        return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
    }

    static LinearLayout.LayoutParams fill() {
        return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
    }

    static LinearLayout.LayoutParams weight() {
        return new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
    }

    LinearLayout.LayoutParams margins(LinearLayout.LayoutParams lp, float l, float t, float r, float b) {
        lp.setMargins(px(l), px(t), px(r), px(b));
        return lp;
    }

    /// a Steam-style full-width button: grey, white with dark text while focused
    TextView button(String label, View.OnClickListener click) {
        final TextView b = text(label, 15, TEXT, true);
        b.setGravity(Gravity.CENTER);
        b.setPadding(px(12), px(11), px(12), px(11));
        b.setBackground(focusable(BUTTON, BUTTON_FOCUS));
        b.setFocusable(true);
        b.setClickable(true);
        b.setOnClickListener(click);
        b.setOnFocusChangeListener((v, has) -> b.setTextColor(has ? Color.rgb(0x0e, 0x14, 0x1b) : TEXT));
        return b;
    }

    /// a settings row: label + optional description on the left, a value or a switch on the right
    LinearLayout settingRow(String label, String desc, View right) {
        LinearLayout r = row();
        r.setPadding(px(10), px(10), px(10), px(10));
        r.setBackground(focusable(Color.TRANSPARENT, SELECTED));
        r.setFocusable(true);
        r.setClickable(true);
        LinearLayout texts = column();
        texts.addView(text(label, 15, TEXT, false));
        if (desc != null && !desc.isEmpty()) {
            TextView d = text(desc, 12, DIM, false);
            d.setPadding(0, px(4), 0, 0);
            texts.addView(d);
        }
        r.addView(texts, weight());
        if (right != null) {
            // keep the view's own size if it has one (the toggle), else wrap it
            LinearLayout.LayoutParams lp = right.getLayoutParams() instanceof LinearLayout.LayoutParams
                ? new LinearLayout.LayoutParams((LinearLayout.LayoutParams) right.getLayoutParams()) : wrap();
            lp.leftMargin = px(10);
            lp.gravity = Gravity.CENTER_VERTICAL;
            r.addView(right, lp);
        }
        return r;
    }

    TextView value(String s) {
        TextView t = text(s, 14, TEXT2, false);
        t.setMaxLines(1);
        t.setEllipsize(TextUtils.TruncateAt.END);
        return t;
    }


    /// Steam's on/off pill
    static final class Toggle extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final float u;
        boolean on;

        Toggle(Context ctx, float u, boolean on) {
            super(ctx);
            this.u = u;
            this.on = on;
            setLayoutParams(new LinearLayout.LayoutParams(Math.round(44 * u), Math.round(24 * u)));
        }

        void set(boolean value) { on = value; invalidate(); }

        /// always its own size: as "wrap content" a plain View takes all the room it's offered, which
        /// squeezed the Wi-Fi / Bluetooth rows' labels away (blank rows in Quick Settings)
        @Override
        protected void onMeasure(int widthSpec, int heightSpec) {
            setMeasuredDimension(Math.round(44 * u), Math.round(24 * u));
        }

        @Override
        protected void onDraw(Canvas c) {
            float h = getHeight(), w = getWidth();
            paint.setColor(on ? BLUE : Color.rgb(0x5d, 0x66, 0x72));
            c.drawRoundRect(new RectF(0, 0, w, h), h / 2, h / 2, paint);
            paint.setColor(Color.WHITE);
            float r = h / 2 - 3 * u;
            c.drawCircle(on ? w - h / 2 : h / 2, h / 2, r, paint);
        }
    }


    /// achievement row background: the global unlock rate as a lighter bar (like Steam's list)
    static final class PercentBar extends Drawable {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final float pct;
        boolean focused = false;

        PercentBar(float pct) { this.pct = Math.max(0, Math.min(100, pct)); }

        @Override
        public void draw(Canvas c) {
            android.graphics.Rect b = getBounds();
            paint.setColor(focused ? FOCUS : CARD);
            c.drawRect(b, paint);
            paint.setColor(focused ? Color.rgb(0x62, 0x6d, 0x7d) : CARD_FILL);
            c.drawRect(b.left, b.top, b.left + b.width() * pct / 100f, b.bottom, paint);
        }

        @Override public void setAlpha(int alpha) {}
        @Override public void setColorFilter(ColorFilter cf) {}
        @Override public int getOpacity() { return PixelFormat.OPAQUE; }
    }
}
