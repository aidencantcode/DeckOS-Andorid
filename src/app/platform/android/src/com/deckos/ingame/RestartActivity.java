// DeckOS - in-game layer
// Close > Restart DeckOS. Qt can't start a second time in the same process, so DeckOS asks this activity
// (its own ":restart" process, see the manifest) to bring it back: DeckOS quits as usual, this waits a
// moment, ends DeckOS's process if it's still there, opens DeckOS again and goes away.

package com.deckos.ingame;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import android.util.Log;


public final class RestartActivity extends Activity {
    private static final String EXTRA_PID = "deckos.pid";
    private static final long WAIT_MS = 1200; // DeckOS's own quit: saving play time, settings

    /// from DeckOS's process, right before it quits
    static boolean start(Context ctx) {
        if (ctx == null)
            return false;
        try {
            Intent i = new Intent(ctx, RestartActivity.class);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_ANIMATION);
            i.putExtra(EXTRA_PID, Process.myPid());
            ctx.startActivity(i);
            return true;
        }
        catch (Exception e) {
            Log.w(Session.TAG, "restart: " + e);
            return false;
        }
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        final int pid = getIntent().getIntExtra(EXTRA_PID, -1);
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            if (pid > 0 && pid != Process.myPid())
                Process.killProcess(pid); // same app: allowed; nothing happens if it already quit
            Intent main = getPackageManager().getLaunchIntentForPackage(getPackageName());
            if (main != null) {
                main.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                try {
                    startActivity(main);
                }
                catch (Exception e) {
                    Log.w(Session.TAG, "restart: " + e);
                }
            }
            finish();
            new Handler(Looper.getMainLooper()).postDelayed(() -> Process.killProcess(Process.myPid()), 300);
        }, WAIT_MS);
    }
}
