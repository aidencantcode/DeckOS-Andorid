// DeckOS - in-game layer
// The performance overlay, MangoHud / Steam Deck style, drawn in a window over the game.
//   1  frame rate (AYN / Retroid, through PServer), battery and play time
//   2  one horizontal bar: BATT | GPU | CPU | RAM | play time
//   3  the vertical block: clock, GPU, CPU, RAM, BATT, time left, fan, session
//   4  level 3 + every CPU core and a 60 s CPU load graph
// Colours are MangoHud's defaults.

package com.deckos.ingame;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.util.Log;
import android.view.View;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;


final class HudView extends View {
    static final int GPU = Color.rgb(0x2e, 0x97, 0x62);
    static final int CPU = Color.rgb(0x2e, 0x97, 0xcb);
    static final int RAM = Color.rgb(0xc2, 0x66, 0x93);
    static final int BATT = Color.rgb(0xff, 0x90, 0x78);
    static final int FAN = Color.rgb(0xe5, 0x5b, 0x5b);
    static final int SESSION = Color.rgb(0xff, 0xff, 0xff);
    static final int GRAPH = Color.rgb(0x00, 0xff, 0x00);
    static final int ENGINE = Color.rgb(0xeb, 0x5b, 0x5b); // MangoHud's frame rate line

    private final float u;
    private final Paint labelPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint valuePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint unitPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint graphPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final SimpleDateFormat clock = new SimpleDateFormat("HH:mm:ss", Locale.US);

    private int level = 0;
    private Stats.Snapshot snap = new Stats.Snapshot();
    private long sessionStart = System.currentTimeMillis();
    private float fps = Float.NaN;   // NaN: not shown
    private String profile = "";     // AYN / Retroid mode, fan and underclock
    private final float[] history = new float[60];
    private int historyCount = 0;

    // one line = cells; vertical levels align cells in columns
    private static final class Cell {
        final String value; final String unit; final int color; final boolean label;
        Cell(String value, String unit, int color, boolean label) {
            this.value = value; this.unit = unit; this.color = color; this.label = label;
        }
    }
    private final List<List<Cell>> lines = new ArrayList<>();
    private float[] colWidth = new float[0];
    private float lineHeight, pad, graphHeight;

    HudView(Context ctx, float unit) {
        super(ctx);
        u = unit;
        labelPaint.setTypeface(font(ctx, true));
        labelPaint.setTextSize(15 * u);
        valuePaint.setTypeface(font(ctx, true));
        valuePaint.setTextSize(15 * u);
        valuePaint.setColor(Color.WHITE);
        unitPaint.setTypeface(font(ctx, false));
        unitPaint.setTextSize(10 * u);
        unitPaint.setColor(Color.WHITE);
        bgPaint.setColor(Color.argb(140, 0, 0, 0));
        graphPaint.setColor(GRAPH);
        graphPaint.setStyle(Paint.Style.STROKE);
        graphPaint.setStrokeWidth(Math.max(1, 1.5f * u));
        lineHeight = 19 * u;
        pad = 6 * u;
        graphHeight = 34 * u;
    }

    // Unispace (Ray Larabie, CC0 - assets/fonts), the Steam Deck overlay look; Android's own font if it fails
    private static Typeface sRegular, sBold;

    static Typeface font(Context ctx, boolean bold) {
        if (sRegular == null) {
            try {
                sRegular = Typeface.createFromAsset(ctx.getAssets(), "fonts/unispace_regular.otf");
                sBold = Typeface.createFromAsset(ctx.getAssets(), "fonts/unispace_bold.otf");
            }
            catch (Exception e) {
                Log.w(Session.TAG, "overlay font: " + e);
                sRegular = Typeface.DEFAULT;
                sBold = Typeface.DEFAULT_BOLD;
            }
        }
        return bold ? sBold : sRegular;
    }

    void setLevel(int newLevel) {
        level = newLevel;
        rebuild();
    }

    void update(Stats.Snapshot s, long start, float framesPerSecond, String profileLine) {
        snap = s;
        sessionStart = start;
        fps = framesPerSecond;
        profile = profileLine == null ? "" : profileLine;
        if (!Float.isNaN(s.cpuPct)) {
            System.arraycopy(history, 1, history, 0, history.length - 1);
            history[history.length - 1] = s.cpuPct;
            historyCount = Math.min(history.length, historyCount + 1);
        }
        rebuild();
    }


    // --- content ----------------------------------------------------------------------------------

    static String num(float v) {
        return Float.isNaN(v) ? "-" : String.valueOf(Math.round(v));
    }

    static String playTime(long start) {
        long s = Math.max(0, (System.currentTimeMillis() - start) / 1000);
        return String.format(Locale.US, "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60);
    }

    static String hoursMinutes(long minutes) {
        if (minutes < 0) return "-";
        return minutes >= 60 ? (minutes / 60) + "h " + (minutes % 60) + "m" : minutes + "m";
    }

    static String gib(long mb) {
        return mb < 0 ? "-" : String.format(Locale.US, "%.1f", mb / 1024f);
    }

    private void rebuild() {
        lines.clear();
        Stats.Snapshot s = snap;
        if (level == 1) {
            List<Cell> l = new ArrayList<>();
            if (!Float.isNaN(fps)) { l.add(new Cell("FPS", "", ENGINE, true)); l.add(new Cell(num(fps), "", 0, false)); }
            l.add(new Cell("BATT", "", BATT, true));
            l.add(new Cell(num(s.battPct), "%", 0, false));
            if (sessionStart > 0) l.add(new Cell(playTime(sessionStart), "", SESSION, false));
            lines.add(l);
        }
        else if (level == 2) {
            List<Cell> l = new ArrayList<>();
            if (!Float.isNaN(fps)) { l.add(new Cell("FPS", "", ENGINE, true)); l.add(new Cell(num(fps), "", 0, false)); }
            l.add(new Cell("BATT", "", BATT, true));
            l.add(new Cell(num(s.battPct), "%", 0, false));
            l.add(new Cell(Float.isNaN(s.battWatts) ? "-" : String.format(Locale.US, "%.1f", s.battWatts), "W", 0, false));
            l.add(new Cell("GPU", "", GPU, true));
            l.add(new Cell(num(s.gpuPct), "%", 0, false));
            l.add(new Cell(num(s.gpuTempC), "\u00b0C", 0, false));
            l.add(new Cell("CPU", "", CPU, true));
            l.add(new Cell(num(s.cpuPct), "%", 0, false));
            l.add(new Cell(num(s.cpuTempC), "\u00b0C", 0, false));
            l.add(new Cell("RAM", "", RAM, true));
            l.add(new Cell(gib(s.ramUsedMb), "GiB", 0, false));
            if (sessionStart > 0) l.add(new Cell(playTime(sessionStart), "", SESSION, true));
            lines.add(l);
        }
        else if (level >= 3) {
            lines.add(row(new Cell(clock.format(new Date()), "", Color.WHITE, true)));
            if (!Float.isNaN(fps))
                lines.add(row(new Cell("FPS", "", ENGINE, true), new Cell(num(fps), "", 0, false), new Cell("", "", 0, false),
                              new Cell(fps > 0 ? String.format(Locale.US, "%.1f", 1000f / fps) : "-", "ms", 0, false)));
            if (!profile.isEmpty())
                lines.add(row(new Cell(profile, "", Color.WHITE, false)));
            lines.add(row(new Cell("GPU", "", GPU, true), new Cell(num(s.gpuPct), "%", 0, false),
                          new Cell(num(s.gpuTempC), "\u00b0C", 0, false), new Cell(s.gpuMhz < 0 ? "-" : String.valueOf(s.gpuMhz), "MHz", 0, false)));
            lines.add(row(new Cell("CPU", "", CPU, true), new Cell(num(s.cpuPct), "%", 0, false),
                          new Cell(num(s.cpuTempC), "\u00b0C", 0, false), new Cell(s.cpuMaxMhz < 0 ? "-" : String.valueOf(maxCore(s)), "MHz", 0, false)));
            if (level >= 4) {
                for (int i = 0; i < s.coreMhz.length; i++) {
                    lines.add(row(new Cell("CPU" + i, "", CPU, true), new Cell(num(s.coreLoad[i]), "%", 0, false),
                                  new Cell("", "", 0, false), new Cell(s.coreMhz[i] < 0 ? "-" : String.valueOf(s.coreMhz[i]), "MHz", 0, false)));
                }
            }
            lines.add(row(new Cell("RAM", "", RAM, true), new Cell(gib(s.ramUsedMb), "GiB", 0, false),
                          new Cell("", "", 0, false), new Cell(gib(s.ramTotalMb), "GiB", 0, false)));
            lines.add(row(new Cell("BATT", "", BATT, true), new Cell(num(s.battPct), "%", 0, false),
                          new Cell(num(s.battTempC), "\u00b0C", 0, false),
                          new Cell(Float.isNaN(s.battWatts) ? "-" : String.format(Locale.US, "%.1f", s.battWatts), "W", 0, false)));
            lines.add(row(new Cell(s.charging ? "Full in" : "Remaining", "", BATT, true),
                          new Cell("", "", 0, false), new Cell("", "", 0, false), new Cell(hoursMinutes(s.battMinutesLeft), "", 0, false)));
            if (s.fanRpm >= 0)
                lines.add(row(new Cell("FAN", "", FAN, true), new Cell("", "", 0, false), new Cell("", "", 0, false),
                              new Cell(String.valueOf(s.fanRpm), "RPM", 0, false)));
            if (sessionStart > 0) // 0: no game (DeckOS was only left)
                lines.add(row(new Cell("SESSION", "", SESSION, true), new Cell("", "", 0, false), new Cell("", "", 0, false),
                              new Cell(playTime(sessionStart), "", 0, false)));
        }
        measureColumns();
        requestLayout();
        invalidate();
    }

    private static int maxCore(Stats.Snapshot s) {
        int best = -1;
        for (int mhz : s.coreMhz) best = Math.max(best, mhz);
        return best;
    }

    private static List<Cell> row(Cell... cells) {
        List<Cell> l = new ArrayList<>();
        for (Cell c : cells) l.add(c);
        return l;
    }

    private float cellWidth(Cell c) {
        Paint p = c.label ? labelPaint : valuePaint;
        float w = p.measureText(c.value);
        if (!c.unit.isEmpty())
            w += 2 * u + unitPaint.measureText(c.unit);
        return w;
    }

    private void measureColumns() {
        int cols = 0;
        for (List<Cell> l : lines) cols = Math.max(cols, l.size());
        colWidth = new float[cols];
        if (level >= 3) {
            for (List<Cell> l : lines) {
                if (l.size() == 1) continue; // the clock spans the block
                for (int i = 0; i < l.size(); i++)
                    colWidth[i] = Math.max(colWidth[i], cellWidth(l.get(i)));
            }
        }
    }

    private float contentWidth() {
        if (lines.isEmpty()) return 0;
        if (level <= 2) {
            float w = 0;
            for (Cell c : lines.get(0)) w += cellWidth(c) + (c.label ? 5 * u : 9 * u);
            return w;
        }
        float w = 0;
        for (float c : colWidth) w += c + 12 * u;
        for (List<Cell> l : lines) // lines of one cell (clock, profile) span the block
            if (l.size() == 1) w = Math.max(w, cellWidth(l.get(0)));
        return w;
    }


    // --- drawing ----------------------------------------------------------------------------------

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        if (level <= 0 || lines.isEmpty()) {
            setMeasuredDimension(0, 0);
            return;
        }
        float h = lines.size() * lineHeight + 2 * pad;
        if (level >= 4 && historyCount > 1)
            h += graphHeight + pad;
        setMeasuredDimension((int) Math.ceil(contentWidth() + 2 * pad), (int) Math.ceil(h));
    }

    @Override
    protected void onDraw(Canvas canvas) {
        if (level <= 0 || lines.isEmpty())
            return;
        canvas.drawRoundRect(new RectF(0, 0, getWidth(), getHeight()), 4 * u, 4 * u, bgPaint);
        float y = pad + lineHeight * 0.78f;
        for (List<Cell> l : lines) {
            float x = pad;
            for (int i = 0; i < l.size(); i++) {
                Cell c = l.get(i);
                if (level <= 2 || l.size() == 1) {
                    drawCell(canvas, c, x, y);
                    x += cellWidth(c) + (c.label ? 5 * u : 9 * u);
                } else {
                    float colW = colWidth[i];
                    // labels left-aligned, numbers right-aligned in their column
                    float cx = c.label ? x : x + colW - cellWidth(c);
                    drawCell(canvas, c, cx, y);
                    x += colW + 12 * u;
                }
            }
            y += lineHeight;
        }
        if (level >= 4 && historyCount > 1) {
            float top = y - lineHeight * 0.78f + pad * 0.5f;
            float left = pad, width = getWidth() - 2 * pad;
            labelPaint.setColor(GRAPH);
            Path path = new Path();
            int start = history.length - historyCount;
            for (int i = start; i < history.length; i++) {
                float px = left + width * (i - start) / (float) (history.length - 1 - start);
                float py = top + graphHeight - graphHeight * Math.min(100, history[i]) / 100f;
                if (i == start) path.moveTo(px, py); else path.lineTo(px, py);
            }
            canvas.drawPath(path, graphPaint);
            unitPaint.setColor(Color.argb(160, 255, 255, 255));
            canvas.drawText("CPU load, 60 s", left, top + graphHeight, unitPaint);
            unitPaint.setColor(Color.WHITE);
        }
    }

    private void drawCell(Canvas canvas, Cell c, float x, float y) {
        Paint p = c.label ? labelPaint : valuePaint;
        if (c.label)
            labelPaint.setColor(c.color);
        canvas.drawText(c.value, x, y, p);
        if (!c.unit.isEmpty())
            canvas.drawText(c.unit, x + p.measureText(c.value) + 2 * u, y, unitPaint);
    }
}
