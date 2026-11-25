// DeckOS - in-game layer
// After a restart the kernel is back at its stock limits: this applies the underclock profile again,
// if Settings > Underclocking says so (Underclock.java). PServer can come up a little after the boot
// broadcast, so it's tried a few times, as ClusterTune's boot restore does.

package com.deckos.ingame;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;


public class UnderclockBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction()))
            return;
        if (Session.app() == null)
            Session.init(context);
        final String script = Underclock.activeScript();
        if (!Underclock.onBoot() || Underclock.STOCK.equals(Underclock.activeId()) || script.isEmpty())
            return;
        final Context app = context.getApplicationContext();
        final PendingResult pending = goAsync();
        new Thread(() -> {
            try {
                for (int attempt = 0; attempt < 4; attempt++) {
                    if (Privileged.available() && Privileged.runScript(app, "underclock.sh", script)) {
                        Log.i(Session.TAG, "underclock profile applied again after the restart");
                        break;
                    }
                    Thread.sleep(2000);
                }
            }
            catch (InterruptedException ignored) {}
            finally {
                pending.finish();
            }
        }, "deckos-underclock-boot").start();
    }
}
