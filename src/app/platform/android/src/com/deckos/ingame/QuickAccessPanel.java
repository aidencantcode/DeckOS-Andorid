// DeckOS - in-game layer
// The Steam Deck "Quick Access" menu itself. Shown by QuickAccessActivity (the game pauses, as it does
// for any app switch) or as an overlay window by QuickAccessOverlay ("Keep game running": the game keeps
// running behind it). Both host the same view, so everything here works in either.
//
// Top bar (bell, Wi-Fi, battery, clock, avatar), a "now playing" strip with the play time and battery
// time left, the icon rail on the left and the tab content:
//   Notifications, Achievements (RetroAchievements), Friends, Quick Settings (brightness, Wi-Fi,
//   Bluetooth), Performance (overlay level, AYN / Retroid performance mode, fan, underclock), Music,
//   Overlay settings (scale, keep running, controller shortcut, frame rate, position), Help, Keyboard.
// Controller: D-pad moves, A selects, B closes, L1/R1 switch tabs. Sizes are Steam Deck pixels
// (screen height / 800) times the overlay scale, which can be changed live from the Overlay tab.

package com.deckos.ingame;

import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.media.AudioManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.Uri;
import android.os.Build;
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
import java.util.List;
import java.util.Locale;


final class QuickAccessPanel extends FrameLayout {
    interface Host {
        /// remove the panel (its close animation has finished)
        void dismiss();
        /// open another screen (Android settings...) over the game; the panel goes away
        void launch(Intent intent);
        /// true while the game is paused behind this panel (shown by an activity)
        boolean pausesGame();
    }

    private static final int[] TAB_ICONS = {
        R.drawable.deckos_ic_bell, R.drawable.deckos_ic_star, R.drawable.deckos_ic_friends, R.drawable.deckos_ic_gear,
        R.drawable.deckos_ic_battery, R.drawable.deckos_ic_music, R.drawable.deckos_ic_tune, R.drawable.deckos_ic_help,
        R.drawable.deckos_ic_keyboard,
    };
    private static final int TAB_NOTIFICATIONS = 0, TAB_ACHIEVEMENTS = 1, TAB_FRIENDS = 2, TAB_SETTINGS = 3,
                             TAB_PERFORMANCE = 4, TAB_MUSIC = 5, TAB_OVERLAY = 6, TAB_HELP = 7, TAB_KEYBOARD = 8;

    static final int[] SCALES = { 75, 90, 100, 110, 125, 150, 175, 200 };
    private static final String[] SCALE_LABELS = { "75%", "90%", "100%", "110%", "125%", "150%", "175%", "200%" };
    static final String[] SHORTCUT_LABELS = { "Off", "Select+Start", "Select+R1", "L3+R3" };
    static final String[] POSITION_LABELS = { "Top left", "Top right", "Bottom left", "Bottom right" };

    private final Host host;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final SimpleDateFormat clockFormat = new SimpleDateFormat("h:mm a", Locale.US);
    private Ui ui;
    private float u;
    private int panelWidth;
    private LinearLayout panel;
    private LinearLayout content;
    private FocusScrollView scroll;
    private TextView exitButton, exitCancel, exitConfirm;
    private FrameLayout exitDialog;     // the "Exit game?" confirmation, over the panel
    private final FrameLayout[] railItems = new FrameLayout[TAB_ICONS.length];
    private int tab = -1;
    private boolean closing = false;
    private boolean running = false;

    // live values, refreshed every second
    private TextView clockText, topBattText, playText, battBigText, battTimeText, battTimeLabel;
    private ImageView topBattIcon, bigBattIcon, wifiIcon;
    private TextView liveCpu, liveGpu, liveRam, livePower, liveFps;
    private Ui.Toggle wifiToggle, btToggle;
    private ValueSlider brightness;
    private Stats localStats;
    private Stats.Snapshot snap = new Stats.Snapshot();

    // Achievements tab
    private RaClient.Game raGame;
    private long raFetchedAt = 0;
    private boolean raLoading = false;

    // Quick Settings drawers
    private boolean wifiOpen = false, btOpen = false, wifiScanning = false;
    private List<QuickControls.Network> wifiNetworks = null;
    private String wifiConnected = "";


    QuickAccessPanel(Context ctx, Host host) {
        super(ctx);
        this.host = host;
        if (Session.app() == null)
            Session.init(ctx);
        localStats = new Stats(ctx);
        setOnClickListener(v -> close()); // a tap beside the panel closes it, like on the Deck
        build(Session.prefs().getInt(Session.KEY_TAB, Session.raGameId > 0 ? TAB_ACHIEVEMENTS : TAB_PERFORMANCE));
    }

    /// (re)creates the whole panel at the current scale, on the given tab
    private void build(int startTab) {
        removeAllViews();
        exitDialog = null; // removed with the rest
        DisplayMetrics dm = getResources().getDisplayMetrics();
        u = Math.min(dm.heightPixels, dm.widthPixels) / 800f * Session.overlayScale() / 100f;
        ui = new Ui(getContext(), u);
        panelWidth = Math.min(ui.px(430), Math.round(dm.widthPixels * 0.62f));

        panel = ui.column();
        panel.setBackgroundColor(Ui.PANEL);
        panel.setClickable(true);
        panel.addView(topBar(), new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ui.px(40)));
        panel.addView(nowPlaying(), Ui.fill());

        LinearLayout body = ui.row();
        body.setGravity(Gravity.TOP);
        body.addView(rail(), new LinearLayout.LayoutParams(ui.px(58), LinearLayout.LayoutParams.MATCH_PARENT));
        scroll = new FocusScrollView(getContext());
        scroll.setFillViewport(true);
        scroll.setVerticalScrollBarEnabled(false);
        content = ui.column();
        content.setPadding(ui.px(16), ui.px(14), ui.px(16), ui.px(16));
        scroll.addView(content, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT));
        body.addView(scroll, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));
        panel.addView(body, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));
        panel.addView(footer(), new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ui.px(40)));

        LayoutParams plp = new LayoutParams(panelWidth, LayoutParams.MATCH_PARENT);
        plp.gravity = Gravity.END;
        addView(panel, plp);

        tab = -1;
        selectTab(startTab, true);
    }

    void open() {
        panel.setTranslationX(panelWidth);
        panel.animate().translationX(0).setDuration(170).start();
        resume();
        // in an overlay window the focus can only be taken once the panel is attached
        // FromTouch: opened by a tap (the notification), Android is in touch mode, where a plain
        // requestFocus() does nothing and the controller had no highlight to start from
        post(() -> { if (findFocus() == null && tab >= 0) railItems[tab].requestFocusFromTouch(); });
    }

    void resume() {
        running = true;
        handler.removeCallbacks(ticker);
        handler.post(ticker);
    }

    void pause() {
        running = false;
        handler.removeCallbacks(ticker);
    }

    void close() {
        if (closing)
            return;
        closing = true;
        pause();
        panel.animate().translationX(panelWidth).setDuration(140).withEndAction(host::dismiss).start();
    }

    private void launch(Intent i) {
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        pause();
        host.launch(i);
    }

    private void returnToDeckOS() {
        Intent i = getContext().getPackageManager().getLaunchIntentForPackage(getContext().getPackageName());
        if (i != null) {
            i.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
            launch(i);
        }
    }


    // --- controller -------------------------------------------------------------------------------

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        int k = e.getKeyCode();
        boolean down = e.getAction() == KeyEvent.ACTION_DOWN;
        if (exitDialog != null) {
            // the confirmation holds the controller: B cancels, A presses, left / right pick
            switch (k) {
                case KeyEvent.KEYCODE_BUTTON_B:
                case KeyEvent.KEYCODE_BACK:
                case KeyEvent.KEYCODE_ESCAPE:
                    if (down && e.getRepeatCount() == 0) closeExitDialog();
                    return true;
                case KeyEvent.KEYCODE_BUTTON_A:
                case KeyEvent.KEYCODE_ENTER:
                case KeyEvent.KEYCODE_DPAD_CENTER:
                    if (down && e.getRepeatCount() == 0) {
                        View f = findFocus();
                        if (f == exitConfirm) confirmExit(); else closeExitDialog();
                    }
                    return true;
                case KeyEvent.KEYCODE_DPAD_LEFT:
                    if (down) exitCancel.requestFocus();
                    return true;
                case KeyEvent.KEYCODE_DPAD_RIGHT:
                    if (down) exitConfirm.requestFocus();
                    return true;
                default:
                    return true;
            }
        }
        // a controller press with nothing focused (after a touch): it lands on the current tab first
        if (down && tab >= 0 && findFocus() == null && (isDpad(k) || k == KeyEvent.KEYCODE_BUTTON_A)) {
            railItems[tab].requestFocusFromTouch();
            return true;
        }
        switch (k) {
            case KeyEvent.KEYCODE_BUTTON_Y:
                if (down && e.getRepeatCount() == 0 && GameExit.possible()) askExit();
                return true;
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
                    View f = findFocus();
                    if (f != null) f.performClick();
                }
                return true;
            case KeyEvent.KEYCODE_DPAD_LEFT:
                // from the tab content, LEFT goes back to the selected tab's icon (not the nearest one)
                if (down) {
                    View f = findFocus();
                    if (f != null && inside(f, content) && !(f instanceof LevelSlider) && !(f instanceof ValueSlider)) {
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

    private static boolean isDpad(int k) {
        return k == KeyEvent.KEYCODE_DPAD_UP || k == KeyEvent.KEYCODE_DPAD_DOWN
            || k == KeyEvent.KEYCODE_DPAD_LEFT || k == KeyEvent.KEYCODE_DPAD_RIGHT;
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

        ImageView avatar = new ImageView(getContext());
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
        // Exit game, like the Deck's (also Y): asks first, then closes the emulator (GameExit)
        if (GameExit.possible()) {
            exitButton = ui.button("Exit game", v -> askExit());
            exitButton.setPadding(ui.px(12), ui.px(6), ui.px(12), ui.px(6));
            strip.addView(exitButton, ui.margins(Ui.wrap(), 10, 0, 0, 0));
        }
        return strip;
    }

    // --- exit game --------------------------------------------------------------------------------

    private void askExit() {
        if (exitDialog != null || !GameExit.possible())
            return;
        FrameLayout dim = new FrameLayout(getContext());
        dim.setBackgroundColor(Color.argb(180, 0, 0, 0));
        dim.setClickable(true); // taps don't reach the panel underneath
        LinearLayout card = ui.column();
        card.setBackground(Ui.rect(Ui.CARD, ui.px(6)));
        card.setPadding(ui.px(18), ui.px(16), ui.px(18), ui.px(16));
        TextView head = ui.text("Exit game?", 19, Ui.TEXT, true);
        card.addView(head, ui.margins(Ui.fill(), 0, 0, 0, 8));
        TextView msg = ui.text("\"" + Session.title + "\" will be closed. Any progress you haven't saved will be lost.", 14, Ui.TEXT2, false);
        msg.setLineSpacing(0, 1.2f);
        card.addView(msg, ui.margins(Ui.fill(), 0, 0, 0, 16));
        LinearLayout buttons = ui.row();
        exitCancel = ui.button("Cancel", v -> closeExitDialog());
        exitConfirm = ui.button("Exit game", v -> confirmExit());
        buttons.addView(exitCancel, ui.margins(Ui.weight(), 0, 0, 6, 0));
        buttons.addView(exitConfirm, ui.margins(Ui.weight(), 6, 0, 0, 0));
        card.addView(buttons, Ui.fill());
        FrameLayout.LayoutParams clp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER);
        clp.leftMargin = clp.rightMargin = ui.px(16);
        dim.addView(card, clp);
        LayoutParams dlp = new LayoutParams(panelWidth, LayoutParams.MATCH_PARENT);
        dlp.gravity = Gravity.END;
        addView(dim, dlp);
        exitDialog = dim;
        exitCancel.requestFocus(); // the safe choice first
    }

    private void closeExitDialog() {
        if (exitDialog == null)
            return;
        removeView(exitDialog);
        exitDialog = null;
        if (exitButton != null) exitButton.requestFocus();
    }

    private void confirmExit() {
        if (exitDialog != null) {
            removeView(exitDialog);
            exitDialog = null;
        }
        pause();
        GameExit.exit(getContext(), host::dismiss);
    }

    private View rail() {
        LinearLayout rail = ui.column();
        rail.setBackgroundColor(Ui.RAIL);
        rail.setPadding(0, ui.px(6), 0, 0);
        for (int i = 0; i < TAB_ICONS.length; i++) {
            final int index = i;
            FrameLayout item = new FrameLayout(getContext());
            item.setFocusable(true);
            item.setClickable(true);
            ImageView icon = new ImageView(getContext());
            icon.setImageResource(TAB_ICONS[i]);
            FrameLayout.LayoutParams ilp = new FrameLayout.LayoutParams(ui.px(26), ui.px(26));
            ilp.gravity = Gravity.CENTER;
            item.addView(icon, ilp);
            View accent = new View(getContext());
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
            rail.addView(item, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ui.px(46)));
        }
        return rail;
    }

    private View footer() {
        LinearLayout bar = ui.row();
        bar.setBackgroundColor(Ui.TOP_BAR);
        bar.setGravity(Gravity.CENTER_VERTICAL | Gravity.END);
        bar.setPadding(0, 0, ui.px(14), 0);
        if (GameExit.possible())
            bar.addView(hint("Y", "EXIT GAME"));
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
        liveCpu = liveGpu = liveRam = livePower = liveFps = null;
        battBigText = battTimeText = battTimeLabel = null;
        bigBattIcon = null;
        wifiToggle = btToggle = null;
        brightness = null;
        content.removeAllViews();
        switch (tab) {
            case TAB_NOTIFICATIONS: buildNotifications(); break;
            case TAB_ACHIEVEMENTS: buildAchievements(); break;
            case TAB_FRIENDS: buildFriends(); break;
            case TAB_SETTINGS: buildQuickSettings(); break;
            case TAB_PERFORMANCE: buildPerformance(); break;
            case TAB_MUSIC: buildMusic(); break;
            case TAB_OVERLAY: buildOverlaySettings(); break;
            case TAB_HELP: buildHelp(); break;
            default: buildKeyboard(); break;
        }
        scroll.scrollTo(0, 0);
        tick();
    }

    /// rebuilds the tab and puts the focus back on the row with this label (or the first slider)
    private void rebuildKeeping(String label) {
        int y = scroll.getScrollY();
        buildContent();
        scroll.post(() -> scroll.scrollTo(0, y));
        View again = label != null ? findRow(content, label) : null;
        if (again == null) again = findButton(content, label == null ? "" : label);
        if (again != null) again.requestFocus();
    }

    private void title(String s) {
        content.addView(ui.text(s, 22, Ui.TEXT, true), ui.margins(Ui.fill(), 0, 0, 0, 14));
    }

    private void paragraph(String s) {
        TextView t = ui.text(s, 14, Ui.TEXT2, false);
        t.setLineSpacing(0, 1.2f);
        content.addView(t, ui.margins(Ui.fill(), 0, 0, 0, 12));
    }

    private void note(String s, int color) {
        TextView t = ui.text(s, 12, color, false);
        t.setLineSpacing(0, 1.15f);
        content.addView(t, ui.margins(Ui.fill(), 0, 0, 0, 8));
    }

    private void addButton(String label, View.OnClickListener click) {
        content.addView(ui.button(label, click), ui.margins(Ui.fill(), 0, 0, 0, 8));
    }

    private void section(String s) {
        content.addView(ui.caps(s), ui.margins(Ui.fill(), 0, 14, 0, 8));
    }

    /// a card with a title, an optional value on the right and a slider (Steam's style)
    private LinearLayout sliderCard(String label, String value, View slider) {
        LinearLayout card = ui.column();
        card.setBackground(Ui.rect(Ui.CARD, ui.px(4)));
        card.setPadding(ui.px(12), ui.px(12), ui.px(12), ui.px(6));
        LinearLayout head = ui.row();
        TextView t = ui.text(label, 15, Ui.TEXT, false);
        head.addView(t, Ui.weight());
        if (value != null) head.addView(ui.text(value, 13, Ui.TEXT2, true));
        card.addView(head, ui.margins(Ui.fill(), 0, 0, 0, 8));
        card.addView(slider, Ui.fill());
        content.addView(card, ui.margins(Ui.fill(), 0, 0, 0, 10));
        return card;
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
            AudioManager am = (AudioManager) getContext().getSystemService(Context.AUDIO_SERVICE);
            if (am != null) {
                am.dispatchMediaKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, key));
                am.dispatchMediaKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, key));
            }
        });
    }

    private void buildHelp() {
        title("Help");
        paragraph("Open this menu from DeckOS's notification, or with the controller shortcut (Overlay tab).");
        paragraph("L1 / R1 switch tabs, B closes the menu and goes back to the game.");
        paragraph(host.pausesGame()
                  ? "The game is paused while this menu is open. Overlay › Keep game running keeps it going."
                  : "The game keeps running behind this menu.");
        addButton("Return to DeckOS", v -> returnToDeckOS());
        addButton("Close", v -> close());
    }

    private void buildKeyboard() {
        title("Keyboard");
        paragraph("An on-screen keyboard for games is coming soon.");
    }


    // --- Quick Settings ---------------------------------------------------------------------------

    private void buildQuickSettings() {
        title("Quick Settings");
        final Context ctx = getContext();

        // brightness
        if (QuickControls.canSetBrightness(ctx)) {
            brightness = new ValueSlider(ctx, u, QuickControls.brightnessPercent(ctx), 5,
                                         (value, done) -> QuickControls.setBrightnessPercent(ctx, value, done));
            sliderCard("Brightness", null, brightness);
        } else {
            section("Brightness");
            note("DeckOS needs the \"Modify system settings\" permission to change the brightness.", Ui.ORANGE);
            addButton("Allow brightness control", v -> {
                Intent i = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:" + ctx.getPackageName()));
                launch(i);
            });
        }

        // Wi-Fi: switch + drawer with the networks
        section("Network");
        wifiToggle = new Ui.Toggle(ctx, u, QuickControls.wifiOn(ctx));
        LinearLayout wifi = ui.settingRow("Wi-Fi", wifiDescription(), wifiToggle);
        wifi.setOnClickListener(v -> {
            if (!QuickControls.canSwitchWifi()) { openWifiPanel(); return; }
            boolean on = !wifiToggle.on;
            wifiToggle.set(on);
            QuickControls.setWifi(on);
            if (!on) { wifiOpen = false; wifiNetworks = null; }
            handler.postDelayed(() -> { if (tab == TAB_SETTINGS) rebuildKeeping("Wi-Fi"); }, 1500);
        });
        content.addView(wifi);
        LinearLayout wifiMore = ui.settingRow(wifiOpen ? "Hide networks" : "Networks", null, ui.value(wifiOpen ? "‹" : "›"));
        wifiMore.setOnClickListener(v -> {
            wifiOpen = !wifiOpen;
            if (wifiOpen) scanWifi();
            rebuildKeeping(wifiOpen ? "Hide networks" : "Networks");
        });
        content.addView(wifiMore);
        if (wifiOpen) buildWifiDrawer();

        // Bluetooth: switch + paired devices
        if (QuickControls.hasBluetooth()) {
            btToggle = new Ui.Toggle(ctx, u, QuickControls.bluetoothOn());
            LinearLayout bt = ui.settingRow("Bluetooth", null, btToggle);
            bt.setOnClickListener(v -> {
                boolean on = !btToggle.on;
                if (QuickControls.setBluetooth(on)) btToggle.set(on);
                else launch(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS));
            });
            content.addView(bt);
            LinearLayout btMore = ui.settingRow(btOpen ? "Hide devices" : "Devices", null, ui.value(btOpen ? "‹" : "›"));
            btMore.setOnClickListener(v -> { btOpen = !btOpen; rebuildKeeping(btOpen ? "Hide devices" : "Devices"); });
            content.addView(btMore);
            if (btOpen) buildBluetoothDrawer();
        }

        section("More");
        content.addView(settingsLink("Volume", Build.VERSION.SDK_INT >= 29 ? Settings.Panel.ACTION_VOLUME : Settings.ACTION_SOUND_SETTINGS));
        content.addView(settingsLink("All Android settings", Settings.ACTION_SETTINGS));
    }

    private String wifiDescription() {
        if (!QuickControls.wifiOn(getContext())) return "Off";
        if (!wifiConnected.isEmpty()) return "Connected to " + wifiConnected;
        return online() ? "Connected" : "Not connected";
    }

    private void scanWifi() {
        if (!QuickControls.canSwitchWifi()) return;
        wifiScanning = true;
        QuickControls.scanWifi(getContext(), (connected, networks) -> {
            wifiScanning = false;
            wifiConnected = connected;
            wifiNetworks = networks;
            if (tab == TAB_SETTINGS && wifiOpen && running) rebuildKeeping(null);
        });
    }

    private void buildWifiDrawer() {
        if (!QuickControls.canSwitchWifi()) {
            note("This device doesn't let DeckOS list networks; Android's Wi-Fi panel can.", Ui.DIM);
            addButton("Open Wi-Fi settings", v -> openWifiPanel());
            return;
        }
        if (wifiScanning && wifiNetworks == null) { note("Scanning…", Ui.DIM); return; }
        if (wifiNetworks == null || wifiNetworks.isEmpty()) {
            note(QuickControls.wifiOn(getContext()) ? "No networks found." : "Wi-Fi is off.", Ui.DIM);
        } else {
            for (final QuickControls.Network n : wifiNetworks) {
                String bars = n.rssi >= -55 ? "▂▄▆█" : n.rssi >= -67 ? "▂▄▆" : n.rssi >= -78 ? "▂▄" : "▂";
                String right = (n.secure ? "🔒 " : "") + bars;
                LinearLayout row = ui.settingRow(n.ssid, n.connected ? "Connected" : null, ui.value(right));
                row.setOnClickListener(v -> {
                    if (n.connected) return;
                    if (n.secure) openWifiPanel(); // a password (or a saved network) is Android's job
                    else QuickControls.connectOpen(n.ssid);
                });
                content.addView(row);
            }
        }
        addButton("Scan again", v -> { scanWifi(); rebuildKeeping("Scan again"); });
        addButton("Other network… (Android)", v -> openWifiPanel());
    }

    private void buildBluetoothDrawer() {
        List<QuickControls.Device> devices = QuickControls.pairedDevices();
        if (!QuickControls.bluetoothOn()) note("Bluetooth is off.", Ui.DIM);
        else if (devices.isEmpty()) note("No paired devices.", Ui.DIM);
        for (QuickControls.Device d : devices) {
            LinearLayout row = ui.settingRow(d.name, d.connected ? "Connected" : "Paired", ui.value("›"));
            row.setOnClickListener(v -> launch(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)));
            content.addView(row);
        }
        addButton("Pair a new device… (Android)", v -> launch(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)));
    }

    private void openWifiPanel() {
        launch(new Intent(Build.VERSION.SDK_INT >= 29 ? Settings.Panel.ACTION_WIFI : Settings.ACTION_WIFI_SETTINGS));
    }

    private View settingsLink(String label, final String action) {
        LinearLayout r = ui.settingRow(label, null, ui.value("›"));
        r.setOnClickListener(v -> {
            try { launch(new Intent(action)); } catch (Exception ignored) {}
        });
        return r;
    }


    // --- Performance ------------------------------------------------------------------------------

    private void buildPerformance() {
        title("Performance");
        final Context ctx = getContext();

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

        LevelSlider level = new LevelSlider(ctx, u, Session.hudLevel(), l -> {
            Session.setHudLevel(l);
            if (l > 0 && !Session.overlayAllowed()) rebuildKeeping(null);
        });
        sliderCard("Performance Overlay Level", null, level);
        if (Session.hudLevel() > 0 && !Session.overlayAllowed()) {
            note("DeckOS needs \"Display over other apps\" to draw the overlay on top of games.", Ui.ORANGE);
            addButton("Allow display over other apps", v -> {
                Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + ctx.getPackageName()));
                launch(i);
            });
        }

        // AYN / Retroid: vendor performance mode, fan, underclock
        boolean vendor = DeviceControl.hasPerformanceModes(ctx) || DeviceControl.hasFanModes(ctx);
        if (vendor || DeviceControl.isAynOrRetroid()) {
            boolean write = DeviceControl.canWrite();
            if (DeviceControl.hasPerformanceModes(ctx)) {
                LevelSlider perf = new LevelSlider(ctx, u, DeviceControl.PERF_LABELS, DeviceControl.perfIndex(ctx), i -> {
                    if (DeviceControl.setPerf(i)) handler.postDelayed(() -> { if (tab == TAB_PERFORMANCE) rebuildKeeping(null); }, 700);
                });
                perf.setEnabled(write);
                sliderCard("Performance Mode", DeviceControl.perfName(ctx), perf);
            }
            if (DeviceControl.hasFanModes(ctx)) {
                LevelSlider fan = new LevelSlider(ctx, u, DeviceControl.FAN_LABELS, DeviceControl.fanIndex(ctx), i -> DeviceControl.setFan(i));
                fan.setEnabled(write);
                sliderCard("Fan", null, fan);
            }
            if (!write)
                note("Switching needs the AYN / Retroid system service (PServer), which wasn't found. The quick settings of the device still work.", Ui.DIM);
        }
        // underclock profiles from DeckOS › Settings › Underclocking (ClusterTune built in)
        if (Underclock.available()) {
            final java.util.List<Underclock.Step> steps = Underclock.steps();
            String[] labels = new String[steps.size()];
            boolean custom = false;
            for (int i = 0; i < labels.length; i++) {
                labels[i] = steps.get(i).label;
                custom = custom || "Custom".equals(labels[i]);
            }
            LevelSlider uc = new LevelSlider(ctx, u, labels, Underclock.index(steps), i -> Underclock.apply(ctx, steps.get(i)));
            sliderCard("Underclock (CPU / GPU limit)", null, uc);
            if (!custom)
                note("Custom: make your own profile in DeckOS › Settings › Underclocking.", Ui.DIM);
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
        content.addView(toggleRow("Use per-game profile", "Remembering these settings per game is coming in 0.2", Session.KEY_PER_GAME, false, true));

        if (advanced) {
            content.addView(ui.settingRow("Framerate Limit", "Coming later", ui.value("Off")));
            float hz = ((android.view.WindowManager) ctx.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay().getRefreshRate();
            content.addView(ui.settingRow("Refresh Rate", null, ui.value(Math.round(hz) + " Hz")));
            liveFps = ui.value("");
            content.addView(ui.settingRow("Frame rate", null, liveFps));
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


    // --- Overlay settings (mirrored in DeckOS › Settings › Overlay) -------------------------------

    static int scaleIndex(int percent) {
        int best = 0;
        for (int i = 0; i < SCALES.length; i++)
            if (Math.abs(SCALES[i] - percent) < Math.abs(SCALES[best] - percent)) best = i;
        return best;
    }

    private void buildOverlaySettings() {
        title("Overlay");
        final Context ctx = getContext();

        LevelSlider scale = new LevelSlider(ctx, u, SCALE_LABELS, scaleIndex(Session.overlayScale()), i -> {
            Session.setOverlayScale(SCALES[i]);
            // live: rebuild everything at the new size and stay on this slider
            handler.removeCallbacks(rescale);
            handler.postDelayed(rescale, 60);
        });
        sliderCard("Menu and overlay size", null, scale);

        content.addView(toggleRow("Keep game running", "The game keeps running behind this menu instead of pausing",
                                  Session.KEY_KEEP_RUNNING, false, false));
        if (Session.keepRunning() && !Session.overlayAllowed())
            note("Needs \"Display over other apps\" (Performance tab); until then the game pauses.", Ui.ORANGE);

        LevelSlider shortcut = new LevelSlider(ctx, u, SHORTCUT_LABELS, Session.shortcut(), i -> {
            Session.setShortcut(i);
        });
        sliderCard("Controller shortcut", null, shortcut);
        if (ShortcutService.instance() == null) {
            note(ShortcutService.enabled(ctx)
                     ? "Turned on in Android, but Android hasn't started it. Turn it off and on again in Accessibility (for a sideloaded app: App info › ⋮ › Allow restricted settings first)."
                     : "Opens this menu over any game. Needs DeckOS's accessibility service (it only watches buttons and which app is in front).", Ui.DIM);
            addButton("Turn on the controller shortcut", v -> {
                if (Session.enableShortcutService())
                    handler.postDelayed(() -> { if (tab == TAB_OVERLAY) rebuildKeeping("Controller shortcut"); }, 1500);
                else
                    launch(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
            });
        }

        content.addView(toggleRow("Show frame rate", Privileged.available()
                                      ? "In the performance overlay"
                                      : "Not available on this device (needs the AYN / Retroid system service)",
                                  Session.KEY_FPS, true, false));
        LevelSlider pos = new LevelSlider(ctx, u, POSITION_LABELS, Session.hudPosition(), Session::setHudPosition);
        sliderCard("Performance overlay position", null, pos);
        content.addView(toggleRow("In-game notification", "Play time while you play; tap it for this menu",
                                  Session.KEY_NOTIFY, true, false));
    }

    private final Runnable rescale = () -> {
        build(TAB_OVERLAY);
        View s = findSlider(content);
        if (s != null) s.requestFocus();
        tick();
    };

    private static View findSlider(ViewGroup g) {
        for (int i = 0; i < g.getChildCount(); i++) {
            View c = g.getChildAt(i);
            if (c instanceof LevelSlider || c instanceof ValueSlider) return c;
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

    private View toggleRow(String label, String desc, final String key, boolean def, boolean rebuild) {
        final Ui.Toggle t = new Ui.Toggle(getContext(), u, Session.prefs().getBoolean(key, def));
        LinearLayout r = ui.settingRow(label, desc, t);
        r.setOnClickListener(v -> {
            boolean on = !t.on;
            t.set(on);
            Session.prefs().edit().putBoolean(key, on).apply();
            SessionService.refresh();
            if (rebuild) rebuildKeeping(label);
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
                if (tab == TAB_ACHIEVEMENTS && running) {
                    View focused = findFocus();
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
        ImageView icon = new ImageView(getContext());
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
        FrameLayout bar = new FrameLayout(getContext());
        bar.setBackground(Ui.rect(Color.rgb(0x3d, 0x44, 0x50), ui.px(3)));
        View fill = new View(getContext());
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

        FrameLayout check = new FrameLayout(getContext());
        check.setBackgroundColor(Color.rgb(0x1b, 0x1f, 0x25));
        if (a.earned) {
            ImageView mark = new ImageView(getContext());
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
        ImageView badge = new ImageView(getContext());
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
            if (running) handler.postDelayed(this, 1000);
        }
    };

    private void tick() {
        if (clockText == null) return;
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
        if (liveFps != null)
            liveFps.setText(Float.isNaN(DeviceControl.fps()) ? "-" : Math.round(DeviceControl.fps()) + " FPS");
        if (wifiToggle != null && !wifiToggle.isFocused())
            wifiToggle.set(QuickControls.wifiOn(getContext()));
        if (btToggle != null)
            btToggle.set(QuickControls.bluetoothOn());
    }

    private String playTime() {
        // in a game: the time it was actually in front (Session); otherwise how long DeckOS has been away
        long ms = Session.hasGame() ? Session.playedMs() : System.currentTimeMillis() - Session.startedAt;
        long s = Math.max(0, ms / 1000);
        long h = s / 3600, m = (s / 60) % 60;
        return h > 0 ? h + "h " + m + "m" : m + "m " + (s % 60) + "s";
    }

    private boolean online() {
        ConnectivityManager cm = (ConnectivityManager) getContext().getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) return false;
        if (Build.VERSION.SDK_INT >= 23) {
            Network n = cm.getActiveNetwork();
            return n != null;
        }
        android.net.NetworkInfo info = cm.getActiveNetworkInfo();
        return info != null && info.isConnected();
    }
}
