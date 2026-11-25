// DeckOS - in-game layer
// Shows the Quick Access panel (QuickAccessPanel) as a translucent activity in its own task, over the
// running game. Android pauses the game while it's open; with "Keep game running" the panel opens as an
// overlay window instead (QuickAccessOverlay) and this activity hands over and closes at once.

package com.deckos.ingame;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;


public class QuickAccessActivity extends Activity implements QuickAccessPanel.Host {
    private QuickAccessPanel panel;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        if (Session.app() == null)
            Session.init(this);
        if (Session.keepRunning() && Session.overlayAllowed() && QuickAccessOverlay.show(this)) {
            finish();
            overridePendingTransition(0, 0);
            return;
        }
        hideSystemBars();
        panel = new QuickAccessPanel(this, this);
        setContentView(panel);
        panel.open();
    }

    @Override
    protected void onResume() {
        super.onResume();
        hideSystemBars();
        if (panel != null) panel.resume();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (panel != null) panel.pause();
    }

    private void hideSystemBars() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
    }

    // --- QuickAccessPanel.Host --------------------------------------------------------------------

    @Override
    public void dismiss() {
        finish();
        overridePendingTransition(0, 0);
    }

    @Override
    public void launch(Intent intent) {
        try {
            startActivity(intent);
        }
        catch (Exception ignored) {}
        finish();
        overridePendingTransition(0, 0);
    }

    @Override
    public boolean pausesGame() { return true; }
}
