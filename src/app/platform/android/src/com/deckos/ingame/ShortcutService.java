// DeckOS - in-game layer
// The controller shortcut that opens Quick Access over any game (Settings > Overlay, or the menu's
// Overlay tab: Select+Start, Select+R1 or L3+R3, in either order). An accessibility service is the only
// way for an app to see controller buttons while another app is in front. It only filters key events: it
// reads no screen content and keeps nothing. The first button of the combo still reaches the game; only
// the second one (which completes the combo) is swallowed. Nothing happens while DeckOS itself is in front. It also hears
// which app comes to the front (its package name, from window changes) so play time counts only while
// the game is in front. Any button
// also skips the launch cover (LaunchCover) once the game is starting underneath.

package com.deckos.ingame;

import android.accessibilityservice.AccessibilityService;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

import java.util.HashSet;
import java.util.Set;


public class ShortcutService extends AccessibilityService {
    private static volatile boolean sConnected = false;
    private static volatile ShortcutService sInstance; // its overlay windows need no permission (LaunchCover)

    // [combo][0] = held button, [combo][1] = the button that completes it (index = Session.shortcut())
    private static final int[][] COMBOS = {
        {},
        { KeyEvent.KEYCODE_BUTTON_SELECT, KeyEvent.KEYCODE_BUTTON_START },
        { KeyEvent.KEYCODE_BUTTON_SELECT, KeyEvent.KEYCODE_BUTTON_R1 },
        { KeyEvent.KEYCODE_BUTTON_THUMBL, KeyEvent.KEYCODE_BUTTON_THUMBR },
    };

    private final Set<Integer> held = new HashSet<>();
    private int swallowUp = 0;

    static ShortcutService instance() { return sInstance; }

    /// the user turned the service on in Android's accessibility settings
    static boolean enabled(Context ctx) {
        if (sConnected)
            return true;
        String list = Settings.Secure.getString(ctx.getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if (TextUtils.isEmpty(list))
            return false;
        String me = new ComponentName(ctx, ShortcutService.class).flattenToString();
        for (String s : list.split(":"))
            if (s.equalsIgnoreCase(me)) return true;
        return false;
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        sConnected = true;
        sInstance = this;
        if (Session.app() == null)
            Session.init(this);
    }

    @Override
    public boolean onUnbind(Intent intent) {
        sConnected = false;
        sInstance = null;
        return super.onUnbind(intent);
    }

    @Override
    protected boolean onKeyEvent(KeyEvent e) {
        int k = e.getKeyCode();
        if (e.getAction() == KeyEvent.ACTION_UP) {
            held.remove(k);
            if (swallowUp == k) { swallowUp = 0; return true; }
            return false;
        }
        if (e.getAction() != KeyEvent.ACTION_DOWN)
            return false;
        if (LaunchCover.showing())
            LaunchCover.skip(); // a button while the game loads under the launch cover: show the game
        int combo = Session.app() != null ? Session.shortcut() : 0;
        // either order: pressed together, Start often lands a few ms before Select, and the combo was
        // missed (it took two or three tries). The first of the two still reaches the game.
        if (e.getRepeatCount() == 0 && combo > 0 && combo < COMBOS.length && !Session.frontendInFront
            && ((k == COMBOS[combo][1] && held.contains(COMBOS[combo][0]))
                || (k == COMBOS[combo][0] && held.contains(COMBOS[combo][1])))) {
            swallowUp = k;
            held.clear();
            open();
            return true;
        }
        held.add(k);
        return false;
    }

    private void open() {
        if (QuickAccessOverlay.showing()) {
            QuickAccessOverlay.hide();
            return;
        }
        // "Keep game running": an accessibility overlay (no permission needed); otherwise the activity
        if (Session.keepRunning() && QuickAccessOverlay.show(this))
            return;
        Intent i = new Intent(this, QuickAccessActivity.class);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(i);
        }
        catch (Exception ignored) {}
    }

    /// which app is in front (window changes only; nothing on screen is read): play time counts only
    /// while the game is (Session.onForegroundPackage)
    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event != null && event.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && event.getPackageName() != null)
            Session.onForegroundPackage(event.getPackageName().toString());
    }

    @Override
    public void onInterrupt() {}
}
