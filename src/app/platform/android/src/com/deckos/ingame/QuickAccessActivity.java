// DeckOS - in-game layer
// The Steam Deck "Quick Access" menu, over the running game: opened from DeckOS's in-game
// notification. A translucent activity in its own task, so the game stays visible behind it.
//
// Top bar (bell, Wi-Fi, battery, clock, avatar), a "now playing" strip with the play time and the
// battery time left, the icon rail on the left and the tab content:
//   Notifications, Achievements (RetroAchievements, star icon), Friends, Quick Settings,
//   Performance (overlay level 0-4, per-game profile, performance mode), Music, Help, Keyboard.
// Controller: D-pad moves, A selects, B closes, L1/R1 switch tabs.

package com.deckos.ingame;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.media.AudioManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.DisplayMetrics;
import android.view.FocusFinder;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.core.graphics.drawable.RoundedBitmapDrawable;
import androidx.core.graphics.drawable.RoundedBitmapDrawableFactory;

import org.pegasus_frontend.android.R;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;


public class QuickAccessActivity extends Activity {
    private static final int[] TAB_ICONS = {
        R.drawable.deckos_ic_bell, R.drawable.deckos_ic_star, R.drawable.deckos_ic_friends, R.drawable.deckos_ic_gear,
        R.drawable.deckos_ic_battery, R.drawable.deckos_ic_music, R.drawable.deckos_ic_help, R.drawable.deckos_ic_keyboard,
    };
    private static final int TAB_NOTIFICATIONS = 0, TAB_ACHIEVEMENTS = 1, TAB_FRIENDS = 2, TAB_SETTINGS = 3,
                             TAB_PERFORMANCE = 4, TAB_MUSIC = 5, TAB_HELP = 6, TAB_KEYBOARD = 7;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final SimpleDateFormat clockFormat = new SimpleDateFormat("h:mm a", Locale.US);
    private Ui ui;
    private float u;
    private int panelWidth;
    private LinearLayout panel;
    private LinearLayout content;
    private ScrollView scroll;
    private final FrameLayout[] railItems = new FrameLayout[TAB_ICONS.length];
    private int tab = -1;
    private boolean closing = false;

    // live values, refreshed every second
    private TextView clockText, topBattText, playText, battBigText, battTimeText, battTimeLabel;
    private ImageView topBattIcon, bigBattIcon, wifiIcon;
    private TextView liveCpu, liveGpu, liveRam, livePower;
    private Stats localStats;
    private Stats.Snapshot snap = new Stats.Snapshot();

    // Achievements tab
    private RaClient.Game raGame;
    private long raFetchedAt = 0;
    private boolean raLoading = false;


    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        if (Session.app() == null)
            Session.init(this);
        DisplayMetrics dm = getResources().getDisplayMetrics();
        u = Math.min(dm.heightPixels, dm.widthPixels) / 800f;
        ui = new Ui(this, u);
        panelWidth = Math.min(ui.px(430), Math.round(dm.widthPixels * 0.62f));
        hideSystemBars();

        FrameLayout root = new FrameLayout(this);
        root.setOnClickListener(v -> close()); // a tap beside the panel closes it, like on the Deck

        panel = ui.column();
        panel.setBackgroundColor(Ui.PANEL);
        panel.setClickable(true);
        panel.addView(topBar(), new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ui.px(40)));
        panel.addView(nowPlaying(), Ui.fill());

        LinearLayout body = ui.row();
        body.setGravity(Gravity.TOP);
        body.addView(rail(), new LinearLayout.LayoutParams(ui.px(58), LinearLayout.LayoutParams.MATCH_PARENT));
        scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setVerticalScrollBarEnabled(false);
        content = ui.column();
        content.setPadding(ui.px(16), ui.px(14), ui.px(16), ui.px(16));
        scroll.addView(content, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT));
        body.addView(scroll, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));
        panel.addView(body, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));
        panel.addView(footer(), new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ui.px(40)));

        FrameLayout.LayoutParams plp = new FrameLayout.LayoutParams(panelWidth, FrameLayout.LayoutParams.MATCH_PARENT);
        plp.gravity = Gravity.END;
        root.addView(panel, plp);
        setContentView(root);

        localStats = new Stats(this);
        int first = Session.prefs().getInt(Session.KEY_TAB, Session.raGameId > 0 ? TAB_ACHIEVEMENTS : TAB_PERFORMANCE);
        selectTab(first, true);

        panel.setTranslationX(panelWidth);
        panel.animate().translationX(0).setDuration(170).start();
    }

    @Override
    protected void onResume() {
        super.onResume();
        hideSystemBars();
        handler.removeCallbacks(ticker);
        handler.post(ticker);
    }

    @Override
    protected void onPause() {
        super.onPause();
        handler.removeCallbacks(ticker);
    }

    private void hideSystemBars() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
    }

    private void close() {
        if (closing)
            return;
        closing = true;
        panel.animate().translationX(panelWidth).setDuration(140).withEndAction(() -> {
            finish();
            overridePendingTransition(0, 0);
        }).start();
    }

    private void returnToDeckOS() {
        Intent i = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (i != null) {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
            startActivity(i);
        }
        finish();
        overridePendingTransition(0, 0);
    }


    // --- controller -------------------------------------------------------------------------------

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        int k = e.getKeyCode();
        boolean down = e.getAction() == KeyEvent.ACTION_DOWN;
        switch (k) {
            case KeyEvent.KEYCODE_BUTTON_B:
            case KeyEvent.KEYCODE_BACK:
            case KeyEvent.KEYCODE_ESCAPE:
            case KeyEvent.KEYCODE_BUTTON_MODE:
                if (down && e.getRepeatCount() == 0) close();
                return true;
            case KeyEvent.KEYCODE_BUTTON_L1:
                if (down) selectTab((tab + TAB_ICONS.length - 1) % TAB_ICONS.length, true);
                return true;
            case KeyEvent.KEYCODE_BUTTON_R1:
                if (down) selectTab((tab + 1) % TAB_ICONS.length, true);
                return true;
            case KeyEvent.KEYCODE_BUTTON_A:
                if (down && e.getRepeatCount() == 0) {
                    View f = getCurrentFocus();
                    if (f != null) f.performClick();
                }
                return true;
            case KeyEvent.KEYCODE_DPAD_LEFT:
                // from the tab content, LEFT goes back to the selected tab's icon (not the nearest one)
                if (down) {
                    View f = getCurrentFocus();
                    if (f != null && inside(f, content) && !(f instanceof LevelSlider)) {
                        View next = FocusFinder.getInstance().findNextFocus(panel, f, View.FOCUS_LEFT);
                        if (next == null || !inside(next, content)) {
                            railItems[tab].requestFocus();
                            return true;
                        }
                    }
                }
                break;
            default:
                break;
        }
        return super.dispatchKeyEvent(e);
    }

    private static boolean inside(View v, ViewGroup parent) {
        ViewParent p = v.getParent();
        while (p != null) {
            if (p == parent) return true;
            p = p.getParent();
        }
        return false;
    }


    // --- frame ------------------------------------------------------------------------------------

    private View topBar() {
        LinearLayout bar = ui.row();
        bar.setBackgroundColor(Ui.TOP_BAR);
        bar.setGravity(Gravity.CENTER_VERTICAL | Gravity.END);
        bar.setPadding(ui.px(12), 0, ui.px(10), 0);

        ImageView bell = ui.icon(R.drawable.deckos_ic_bell, 20, Ui.TEXT);
        bar.addView(bell, ui.margins((LinearLayout.LayoutParams) bell.getLayoutParams(), 0, 0, 14, 0));
        wifiIcon = ui.icon(R.drawable.deckos_ic_wifi, 20, Ui.TEXT);
        bar.addView(wifiIcon, ui.margins((LinearLayout.LayoutParams) wifiIcon.getLayoutParams(), 0, 0, 14, 0));
        topBattIcon = ui.icon(R.drawable.deckos_ic_battery, 24, Ui.GREEN);
        bar.addView(topBattIcon);
        topBattText = ui.text("", 14, Ui.TEXT, true);
        bar.addView(topBattText, ui.margins(Ui.wrap(), 4, 0, 14, 0));
        clockText = ui.text("", 15, Ui.TEXT, true);
        bar.addView(clockText, ui.margins(Ui.wrap(), 0, 0, 12, 0));

        ImageView avatar = new ImageView(this);
        avatar.setScaleType(ImageView.ScaleType.CENTER_CROP);
        Bitmap pic = Session.profilePicture.isEmpty() ? null : RaClient.localImage(Session.profilePicture, ui.px(64));
        if (pic != null) {
            RoundedBitmapDrawable round = RoundedBitmapDrawableFactory.create(getResources(), pic);
            round.setCornerRadius(ui.px(4));
            avatar.setImageDrawable(round);
        } else {
            avatar.setImageResource(R.drawable.deckos_ic_gamepad);
            avatar.setColorFilter(Color.WHITE);
            avatar.setBackground(Ui.rect(Ui.BLUE, ui.px(4)));
            avatar.setPadding(ui.px(4), ui.px(4), ui.px(4), ui.px(4));
        }
        bar.addView(avatar, new LinearLayout.LayoutParams(ui.px(30), ui.px(30)));
        return bar;
    }

    private View nowPlaying() {
        LinearLayout strip = ui.row();
        strip.setBackgroundColor(Color.rgb(0x14, 0x18, 0x1e));
        strip.setPadding(ui.px(14), ui.px(9), ui.px(14), ui.px(9));
        ImageView pad = ui.icon(R.drawable.deckos_ic_gamepad, 22, Ui.BLUE);
        strip.addView(pad, ui.margins((LinearLayout.LayoutParams) pad.getLayoutParams(), 0, 0, 10, 0));
        LinearLayout texts = ui.column();
        TextView title = ui.text(Session.hasGame() ? Session.title : "DeckOS", 15, Ui.TEXT, true);
        title.setSingleLine(true);
        title.setEllipsize(TextUtils.TruncateAt.END);
        texts.addView(title);
        playText = ui.text("", 12, Ui.TEXT2, false);
        playText.setPadding(0, ui.px(3), 0, 0);
        texts.addView(playText);
        strip.addView(texts, Ui.weight());
        return strip;
    }

    private View rail() {
        LinearLayout rail = ui.column();
        rail.setBackgroundColor(Ui.RAIL);
        rail.setPadding(0, ui.px(6), 0, 0);
        for (int i = 0; i < TAB_ICONS.length; i++) {
            final int index = i;
            FrameLayout item = new FrameLayout(this);
            item.setFocusable(true);
            item.setClickable(true);
            ImageView icon = new ImageView(this);
            icon.setImageResource(TAB_ICONS[i]);
            FrameLayout.LayoutParams ilp = new FrameLayout.LayoutParams(ui.px(26), ui.px(26));
            ilp.gravity = Gravity.CENTER;
            item.addView(icon, ilp);
            View accent = new View(this);
            accent.setBackgroundColor(Ui.BLUE);
            FrameLayout.LayoutParams alp = new FrameLayout.LayoutParams(ui.px(3), FrameLayout.LayoutParams.MATCH_PARENT);
            alp.gravity = Gravity.START;
            item.addView(accent, alp);
            item.setOnFocusChangeListener((v, has) -> { if (has && index != tab) selectTab(index, false); });
            item.setOnClickListener(v -> {
                selectTab(index, false);
                View first = firstFocusable(content);
                if (first != null) first.requestFocus();
            });
            railItems[i] = item;
            rail.addView(item, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ui.px(52)));
        }
        return rail;
    }

    private View footer() {
        LinearLayout bar = ui.row();
        bar.setBackgroundColor(Ui.TOP_BAR);
        bar.setGravity(Gravity.CENTER_VERTICAL | Gravity.END);
        bar.setPadding(0, 0, ui.px(14), 0);
        bar.addView(hint("A", "SELECT"));
        bar.addView(hint("B", "CLOSE"));
        return bar;
    }

    private View hint(String button, String label) {
        LinearLayout h = ui.row();
        TextView glyph = ui.text(button, 12, Color.rgb(0x0e, 0x14, 0x1b), true);
        glyph.setGravity(Gravity.CENTER);
        glyph.setBackground(Ui.rect(Color.WHITE, ui.px(10)));
        h.addView(glyph, new LinearLayout.LayoutParams(ui.px(20), ui.px(20)));
        h.addView(ui.text(label, 12, Ui.TEXT, true), ui.margins(Ui.wrap(), 6, 0, 0, 0));
        h.setPadding(ui.px(14), 0, 0, 0);
        return h;
    }

    private void selectTab(int index, boolean focusRail) {
        index = Math.max(0, Math.min(TAB_ICONS.length - 1, index));
        boolean changed = index != tab;
        tab = index;
        Session.prefs().edit().putInt(Session.KEY_TAB, tab).apply();
        for (int i = 0; i < railItems.length; i++) {
            boolean sel = i == tab;
            railItems[i].setBackground(ui.focusable(sel ? Ui.SELECTED : Color.TRANSPARENT, Ui.FOCUS));
            ((ImageView) railItems[i].getChildAt(0)).setColorFilter(sel ? Ui.TEXT : Ui.DIM);
            railItems[i].getChildAt(1).setVisibility(sel ? View.VISIBLE : View.INVISIBLE);
        }
        if (changed)
            buildContent();
        if (focusRail)
            railItems[tab].requestFocus();
    }

    private static View firstFocusable(ViewGroup group) {
        for (int i = 0; i < group.getChildCount(); i++) {
            View c = group.getChildAt(i);
            if (c.isFocusable() && c.getVisibility() == View.VISIBLE) return c;
            if (c instanceof ViewGroup) {
                View inner = firstFocusable((ViewGroup) c);
                if (inner != null) return inner;
            }
        }
        return null;
    }


    // --- tabs -------------------------------------------------------------------------------------

    private void buildContent() {
        liveCpu = liveGpu = liveRam = livePower = null;
        battBigText = battTimeText = battTimeLabel = null;
        bigBattIcon = null;
        content.removeAllViews();
        switch (tab) {
            case TAB_NOTIFICATIONS: buildNotifications(); break;
            case TAB_ACHIEVEMENTS: buildAchievements(); break;
            case TAB_FRIENDS: buildFriends(); break;
            case TAB_SETTINGS: buildQuickSettings(); break;
            case TAB_PERFORMANCE: buildPerformance(); break;
            case TAB_MUSIC: buildMusic(); break;
            case TAB_HELP: buildHelp(); break;
            default: buildKeyboard(); break;
        }
        scroll.scrollTo(0, 0);
        tick();
    }

    private void title(String s) {
        content.addView(ui.text(s, 22, Ui.TEXT, true), ui.margins(Ui.fill(), 0, 0, 0, 14));
    }

    private void paragraph(String s) {
        TextView t = ui.text(s, 14, Ui.TEXT2, false);
        t.setLineSpacing(0, 1.2f);
        content.addView(t, ui.margins(Ui.fill(), 0, 0, 0, 12));
    }

    private void addButton(String label, View.OnClickListener click) {
        content.addView(ui.button(label, click), ui.margins(Ui.fill(), 0, 0, 0, 8));
    }

    private void section(String s) {
        content.addView(ui.caps(s), ui.margins(Ui.fill(), 0, 14, 0, 8));
    }

    private void buildNotifications() {
        title("Notifications");
        if (Session.hasGame()) {
            section("Now playing");
            paragraph(Session.title + (Session.system.isEmpty() ? "" : "  ·  " + Session.system));
            addButton("Resume game", v -> close());
        } else {
            paragraph("No new notifications.");
        }
        addButton("Return to DeckOS", v -> returnToDeckOS());
    }

    private void buildFriends() {
        title("Friends");
        paragraph("Friends and chat will show here once a Steam profile is linked in DeckOS (coming soon).");
    }

    private void buildQuickSettings() {
        title("Quick Settings");
        content.addView(settingsLink("Wi-Fi", Build.VERSION.SDK_INT >= 29 ? Settings.Panel.ACTION_WIFI : Settings.ACTION_WIFI_SETTINGS));
        content.addView(settingsLink("Bluetooth", Settings.ACTION_BLUETOOTH_SETTINGS));
        content.addView(settingsLink("Volume", Build.VERSION.SDK_INT >= 29 ? Settings.Panel.ACTION_VOLUME : Settings.ACTION_SOUND_SETTINGS));
        content.addView(settingsLink("Display and brightness", Settings.ACTION_DISPLAY_SETTINGS));
    }

    private View settingsLink(String label, final String action) {
        LinearLayout r = ui.settingRow(label, null, ui.value("›"));
        r.setOnClickListener(v -> {
            try {
                Intent i = new Intent(action);
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(i);
            }
            catch (Exception ignored) {}
        });
        return r;
    }

    private void buildMusic() {
        title("Music");
        paragraph("Controls whatever is playing on this device.");
        LinearLayout row = ui.row();
        row.addView(mediaButton("Previous", KeyEvent.KEYCODE_MEDIA_PREVIOUS), ui.margins(Ui.weight(), 0, 0, 6, 0));
        row.addView(mediaButton("Play / Pause", KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE), ui.margins(Ui.weight(), 0, 0, 6, 0));
        row.addView(mediaButton("Next", KeyEvent.KEYCODE_MEDIA_NEXT), Ui.weight());
        content.addView(row, Ui.fill());
    }

    private View mediaButton(String label, final int key) {
        return ui.button(label, v -> {
            AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
            if (am != null) {
                am.dispatchMediaKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, key));
                am.dispatchMediaKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, key));
            }
        });
    }

    private void buildHelp() {
        title("Help");
        paragraph("Tap DeckOS's notification at any time to open this menu.");
        paragraph("L1 / R1 switch tabs, B closes the menu and goes back to the game.");
        paragraph("Play time keeps counting in the notification while you play.");
        addButton("Return to DeckOS", v -> returnToDeckOS());
        addButton("Close", v -> close());
    }

    private void buildKeyboard() {
        title("Keyboard");
        paragraph("An on-screen keyboard for games is coming soon.");
    }


    // --- Performance ------------------------------------------------------------------------------

    private void buildPerformance() {
        title("Performance");

        // battery: big icon + %, projected time on the right (as on the Deck)
        LinearLayout batt = ui.row();
        bigBattIcon = ui.icon(R.drawable.deckos_ic_battery, 44, Ui.GREEN);
        batt.addView(bigBattIcon);
        battBigText = ui.text("", 28, Ui.TEXT, true);
        batt.addView(battBigText, ui.margins(Ui.wrap(), 8, 0, 0, 0));
        LinearLayout right = ui.column();
        right.setGravity(Gravity.END);
        battTimeText = ui.text("", 17, Ui.TEXT, true);
        right.addView(battTimeText);
        battTimeLabel = ui.text("", 10, Ui.DIM, true);
        battTimeLabel.setPadding(0, ui.px(3), 0, 0);
        right.addView(battTimeLabel);
        batt.addView(right, Ui.weight());
        content.addView(batt, ui.margins(Ui.fill(), 0, 0, 0, 14));

        // overlay level card
        LinearLayout card = ui.column();
        card.setBackground(Ui.rect(Ui.CARD, ui.px(4)));
        card.setPadding(ui.px(12), ui.px(12), ui.px(12), ui.px(6));
        card.addView(ui.text("Performance Overlay Level", 15, Ui.TEXT, false), ui.margins(Ui.fill(), 0, 0, 0, 8));
        LevelSlider slider = new LevelSlider(this, u, Session.hudLevel(), level -> {
            Session.setHudLevel(level);
            if (level > 0 && !Session.overlayAllowed())
                buildContentKeepingFocusOnSlider();
        });
        card.addView(slider, Ui.fill());
        content.addView(card, ui.margins(Ui.fill(), 0, 0, 0, 10));

        if (Session.hudLevel() > 0 && !Session.overlayAllowed()) {
            TextView warn = ui.text("DeckOS needs \"Display over other apps\" to draw the overlay on top of games.", 13, Ui.ORANGE, false);
            content.addView(warn, ui.margins(Ui.fill(), 0, 0, 0, 6));
            addButton("Allow display over other apps", v -> Session.requestOverlayPermission());
        }

        final boolean advanced = Session.prefs().getBoolean(Session.KEY_ADVANCED, false);
        addButton(advanced ? "Basic View" : "Advanced View", v -> {
            Session.prefs().edit().putBoolean(Session.KEY_ADVANCED, !advanced).apply();
            buildContent();
            View again = findButton(content, advanced ? "Advanced View" : "Basic View");
            if (again != null) again.requestFocus();
        });

        LinearLayout head = ui.row();
        head.addView(ui.caps("Performance settings"), Ui.weight());
        head.addView(ui.icon(R.drawable.deckos_ic_info, 16, Ui.DIM));
        content.addView(head, ui.margins(Ui.fill(), 0, 16, 0, 4));
        boolean perGame = Session.prefs().getBoolean(Session.KEY_PER_GAME, false);
        content.addView(ui.text(perGame && Session.hasGame() ? "Using " + Session.title + " profile" : "Using default profile", 12, Ui.DIM, false),
                        ui.margins(Ui.fill(), 0, 0, 0, 6));
        content.addView(toggleRow("Use per-game profile", null, Session.KEY_PER_GAME, true));
        content.addView(toggleRow("Performance mode", "Switches the AYN / Retroid performance mode - coming soon", Session.KEY_PERF_MODE, false));

        if (advanced) {
            content.addView(ui.settingRow("Framerate Limit", "Needs Shizuku - coming soon", ui.value("Off")));
            float hz = getWindowManager().getDefaultDisplay().getRefreshRate();
            content.addView(ui.settingRow("Refresh Rate", null, ui.value(Math.round(hz) + " Hz")));
            liveCpu = ui.value("");
            content.addView(ui.settingRow("CPU", null, liveCpu));
            liveGpu = ui.value("");
            content.addView(ui.settingRow("GPU", null, liveGpu));
            liveRam = ui.value("");
            content.addView(ui.settingRow("Memory", null, liveRam));
            livePower = ui.value("");
            content.addView(ui.settingRow("Battery", null, livePower));
        }
    }

    private void buildContentKeepingFocusOnSlider() {
        buildContent();
        View s = findSlider(content);
        if (s != null) s.requestFocus();
    }

    private static View findSlider(ViewGroup g) {
        for (int i = 0; i < g.getChildCount(); i++) {
            View c = g.getChildAt(i);
            if (c instanceof LevelSlider) return c;
            if (c instanceof ViewGroup) {
                View inner = findSlider((ViewGroup) c);
                if (inner != null) return inner;
            }
        }
        return null;
    }

    private static View findButton(ViewGroup g, String label) {
        for (int i = 0; i < g.getChildCount(); i++) {
            View c = g.getChildAt(i);
            if (c instanceof TextView && c.isFocusable() && label.contentEquals(((TextView) c).getText())) return c;
            if (c instanceof ViewGroup) {
                View inner = findButton((ViewGroup) c, label);
                if (inner != null) return inner;
            }
        }
        return null;
    }

    private View toggleRow(String label, String desc, final String key, boolean rebuild) {
        final Ui.Toggle t = new Ui.Toggle(this, u, Session.prefs().getBoolean(key, false));
        LinearLayout r = ui.settingRow(label, desc, t);
        r.setOnClickListener(v -> {
            boolean on = !t.on;
            t.set(on);
            Session.prefs().edit().putBoolean(key, on).apply();
            if (rebuild) {
                int y = scroll.getScrollY();
                buildContent();
                scroll.post(() -> scroll.scrollTo(0, y));
                View again = findRow(content, label);
                if (again != null) again.requestFocus();
            }
        });
        return r;
    }

    private static View findRow(ViewGroup g, String label) {
        for (int i = 0; i < g.getChildCount(); i++) {
            View c = g.getChildAt(i);
            if (c.isFocusable() && c instanceof ViewGroup && containsText((ViewGroup) c, label)) return c;
            if (c instanceof ViewGroup) {
                View inner = findRow((ViewGroup) c, label);
                if (inner != null) return inner;
            }
        }
        return null;
    }

    private static boolean containsText(ViewGroup g, String s) {
        for (int i = 0; i < g.getChildCount(); i++) {
            View c = g.getChildAt(i);
            if (c instanceof TextView && s.contentEquals(((TextView) c).getText())) return true;
            if (c instanceof ViewGroup && containsText((ViewGroup) c, s)) return true;
        }
        return false;
    }


    // --- Achievements -----------------------------------------------------------------------------

    private void buildAchievements() {
        title("Achievements");
        if (Session.raUser.isEmpty() || Session.raKey.isEmpty()) {
            paragraph("Sign in to RetroAchievements in DeckOS (Settings › Profile) to follow your achievements here while you play.");
            return;
        }
        if (!Session.hasGame()) {
            paragraph("Start a game from DeckOS to see its achievements here.");
            return;
        }
        if (Session.raGameId <= 0) {
            paragraph("This game isn't linked to RetroAchievements: its ROM isn't a dump RetroAchievements knows, or the lookup hasn't finished yet.");
            return;
        }
        long now = System.currentTimeMillis();
        if (!raLoading && (raGame == null || raGame.id != Session.raGameId || now - raFetchedAt > 15000)) {
            raLoading = true;
            RaClient.loadGame(Session.raGameId, Session.raUser, Session.raKey, game -> {
                raLoading = false;
                raFetchedAt = System.currentTimeMillis();
                raGame = game;
                if (tab == TAB_ACHIEVEMENTS && !isFinishing()) {
                    View focused = getCurrentFocus();
                    boolean onRail = focused != null && !inside(focused, content);
                    buildContent();
                    if (onRail) railItems[tab].requestFocus();
                }
            });
        }
        if (raGame == null || raGame.id != Session.raGameId) {
            paragraph("Loading…");
            return;
        }
        if (raGame.error != null) {
            paragraph(raGame.error + ".");
            addButton("Try again", v -> { raFetchedAt = 0; buildContent(); });
            return;
        }

        // game header + progress
        LinearLayout head = ui.row();
        ImageView icon = new ImageView(this);
        if (!raGame.icon.isEmpty()) RaClient.image(icon, RaClient.MEDIA + raGame.icon);
        head.addView(icon, new LinearLayout.LayoutParams(ui.px(48), ui.px(48)));
        LinearLayout names = ui.column();
        TextView gt = ui.text(raGame.title, 16, Ui.TEXT, true);
        gt.setSingleLine(true);
        gt.setEllipsize(TextUtils.TruncateAt.END);
        names.addView(gt);
        names.addView(ui.text(raGame.console, 12, Ui.DIM, false), ui.margins(Ui.wrap(), 0, 4, 0, 0));
        head.addView(names, ui.margins(Ui.weight(), 10, 0, 0, 0));
        content.addView(head, ui.margins(Ui.fill(), 0, 0, 0, 10));

        int total = raGame.achievements.size(), earned = raGame.earned();
        int pct = total > 0 ? Math.round(100f * earned / total) : 0;
        content.addView(ui.text("You've unlocked " + earned + "/" + total + " (" + pct + "%)  ·  "
                                + raGame.earnedPoints + "/" + raGame.totalPoints + " points", 13, Ui.TEXT2, false),
                        ui.margins(Ui.fill(), 0, 0, 0, 6));
        content.addView(progressBar(total > 0 ? (float) earned / total : 0, earned == total && total > 0),
                        ui.margins(new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ui.px(6)), 0, 0, 0, 8));

        long sessionStart = Session.startedAt - 60000;
        boolean anyNew = false, anyEarned = false, anyLocked = false;
        for (RaClient.Achievement a : raGame.achievements) {
            if (a.earned && a.earnedAt >= sessionStart) anyNew = true;
            else if (a.earned) anyEarned = true;
            else anyLocked = true;
        }
        if (anyNew) {
            section("Unlocked this session");
            for (RaClient.Achievement a : raGame.achievements)
                if (a.earned && a.earnedAt >= sessionStart) content.addView(achievementRow(a, true));
        }
        if (anyEarned) {
            section("Unlocked");
            for (RaClient.Achievement a : raGame.achievements)
                if (a.earned && a.earnedAt < sessionStart) content.addView(achievementRow(a, false));
        }
        if (anyLocked) {
            section("Locked");
            for (RaClient.Achievement a : raGame.achievements)
                if (!a.earned) content.addView(achievementRow(a, false));
        }
        addButton("Refresh", v -> { raFetchedAt = 0; buildContent(); });
    }

    private View progressBar(final float fraction, final boolean complete) {
        FrameLayout bar = new FrameLayout(this);
        bar.setBackground(Ui.rect(Color.rgb(0x3d, 0x44, 0x50), ui.px(3)));
        View fill = new View(this);
        fill.setBackground(Ui.rect(complete ? Ui.GOLD : Ui.BLUE, ui.px(3)));
        bar.addView(fill, new FrameLayout.LayoutParams(0, FrameLayout.LayoutParams.MATCH_PARENT));
        bar.addOnLayoutChangeListener((v, l, t, r, b, ol, ot, or, ob) -> {
            int w = Math.round((r - l) * fraction);
            if (fill.getLayoutParams().width != w) {
                fill.getLayoutParams().width = w;
                fill.post(fill::requestLayout);
            }
        });
        return bar;
    }

    /// one row of the list, like Steam's achievements page: check, badge, name + description, global rate
    private View achievementRow(RaClient.Achievement a, boolean isNew) {
        LinearLayout row = ui.row();
        row.setFocusable(true);
        row.setClickable(true);

        FrameLayout check = new FrameLayout(this);
        check.setBackgroundColor(Color.rgb(0x1b, 0x1f, 0x25));
        if (a.earned) {
            ImageView mark = new ImageView(this);
            mark.setImageResource(R.drawable.deckos_ic_check);
            mark.setColorFilter(isNew ? Ui.GOLD : Ui.DIM);
            FrameLayout.LayoutParams mlp = new FrameLayout.LayoutParams(ui.px(18), ui.px(18));
            mlp.gravity = Gravity.CENTER;
            check.addView(mark, mlp);
        }
        row.addView(check, new LinearLayout.LayoutParams(ui.px(32), LinearLayout.LayoutParams.MATCH_PARENT));

        final Ui.PercentBar bg = new Ui.PercentBar(Float.isNaN(a.rate) ? 0 : a.rate);
        LinearLayout card = ui.row();
        card.setBackground(bg);
        card.setPadding(ui.px(8), ui.px(8), ui.px(10), ui.px(8));
        ImageView badge = new ImageView(this);
        RaClient.image(badge, RaClient.badgeUrl(a));
        card.addView(badge, new LinearLayout.LayoutParams(ui.px(48), ui.px(48)));
        LinearLayout texts = ui.column();
        TextView name = ui.text(isNew ? "NEW  " + a.title : a.title, 14, isNew ? Ui.GOLD : Ui.TEXT, true);
        name.setSingleLine(true);
        name.setEllipsize(TextUtils.TruncateAt.END);
        texts.addView(name);
        TextView desc = ui.text(a.description + "  ·  " + a.points + " pts" + (a.hardcore ? "  ·  hardcore" : ""), 12, Ui.TEXT2, false);
        desc.setMaxLines(2);
        desc.setEllipsize(TextUtils.TruncateAt.END);
        texts.addView(desc, ui.margins(Ui.wrap(), 0, 3, 0, 0));
        card.addView(texts, ui.margins(Ui.weight(), 10, 0, 8, 0));
        card.addView(ui.text(Float.isNaN(a.rate) ? "" : String.format(Locale.US, "%.1f%%", a.rate), 14, Ui.TEXT, true));
        row.addView(card, Ui.weight());

        row.setOnFocusChangeListener((v, has) -> { bg.focused = has; bg.invalidateSelf(); });
        LinearLayout.LayoutParams lp = Ui.fill();
        lp.bottomMargin = ui.px(5);
        row.setLayoutParams(lp);
        return row;
    }


    // --- live values ------------------------------------------------------------------------------

    private final Runnable ticker = new Runnable() {
        @Override
        public void run() {
            tick();
            handler.postDelayed(this, 1000);
        }
    };

    private void tick() {
        Stats.Snapshot fromService = SessionService.lastStats();
        snap = fromService != null ? fromService : localStats.sample();

        clockText.setText(clockFormat.format(new Date()));
        int battColor = (!Float.isNaN(snap.battPct) && snap.battPct <= 20 && !snap.charging) ? Ui.ORANGE : Ui.GREEN;
        topBattIcon.setColorFilter(battColor);
        topBattText.setText(HudView.num(snap.battPct) + "%");
        wifiIcon.setColorFilter(online() ? Ui.TEXT : Ui.DIM);

        String left = snap.battMinutesLeft >= 0
            ? (snap.charging ? "  ·  full in " : "  ·  ") + HudView.hoursMinutes(snap.battMinutesLeft) + (snap.charging ? "" : " of battery left")
            : "";
        playText.setText((Session.hasGame() ? "Playing for " : "Running for ") + playTime() + left);

        if (battBigText != null) {
            battBigText.setText(HudView.num(snap.battPct) + "%");
            bigBattIcon.setColorFilter(battColor);
            battTimeText.setText(snap.battMinutesLeft >= 0 ? HudView.hoursMinutes(snap.battMinutesLeft) : "-");
            battTimeLabel.setText(snap.charging ? "PROJECTED CHARGING TIME" : "PROJECTED BATTERY LIFE");
        }
        if (liveCpu != null) {
            liveCpu.setText(HudView.num(snap.cpuPct) + "%" + (snap.cpuFromClocks ? " (clock)" : "")
                            + "  ·  " + HudView.num(snap.cpuTempC) + "°C");
            liveGpu.setText(HudView.num(snap.gpuPct) + "%  ·  " + HudView.num(snap.gpuTempC) + "°C"
                            + (snap.gpuMhz > 0 ? "  ·  " + snap.gpuMhz + " MHz" : ""));
            liveRam.setText(HudView.gib(snap.ramUsedMb) + " / " + HudView.gib(snap.ramTotalMb) + " GiB");
            livePower.setText((Float.isNaN(snap.battWatts) ? "-" : String.format(Locale.US, "%.1f W", snap.battWatts))
                              + "  ·  " + HudView.num(snap.battTempC) + "°C");
        }
    }

    private String playTime() {
        long s = Math.max(0, (System.currentTimeMillis() - Session.startedAt) / 1000);
        long h = s / 3600, m = (s / 60) % 60;
        return h > 0 ? h + "h " + m + "m" : m + "m " + (s % 60) + "s";
    }

    private boolean online() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) return false;
        if (Build.VERSION.SDK_INT >= 23) {
            Network n = cm.getActiveNetwork();
            return n != null;
        }
        android.net.NetworkInfo info = cm.getActiveNetworkInfo();
        return info != null && info.isConnected();
    }
}
