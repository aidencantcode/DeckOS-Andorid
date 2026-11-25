// DeckOS - in-game layer
// Whether the game DeckOS started still runs: its app's process, looked up through PServer / root
// (`pidof <package>`) every 2 s while a session is open - also while DeckOS itself is in front. Android
// hides other apps' processes from normal apps, so without PServer or root this stays unknown and a
// session ends when DeckOS is back in front, as before. With it, the session goes on until the game's
// process ends (the game page shows it running, with Resume and Stop, like Steam), and play time can
// count while the game runs instead of only while it's in front (Session.countWhileRunning).
// The output comes back through a file, like every PServer command (see Privileged).

package com.deckos.ingame;

import android.content.Context;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import java.io.File;
import java.util.regex.Pattern;


final class GameProcess {
    private GameProcess() {}

    private static final long PERIOD_MS = 2000;
    private static final long FIND_MS = 60000;     // never seen by then: not tracked this session
    private static final int MAX_WAIT_TICKS = 3;   // a script whose output never came: send it again
    private static final Pattern PID = Pattern.compile("pid=\\d");

    private static final Handler sMain = new Handler(Looper.getMainLooper());
    private static Handler sHandler;               // its own thread: file reads and PServer calls
    private static int sGeneration = 0;            // bumped per session, so an old tick stops
    private static volatile boolean sSeen = false, sAlive = false;
    private static File sPending;                  // the last script's output file, not read yet
    private static int sWaited = 0;
    private static long sStartedAt = 0;

    private static synchronized Handler handler() {
        if (sHandler == null) {
            HandlerThread t = new HandlerThread("deckos-game-process");
            t.start();
            sHandler = new Handler(t.getLooper());
        }
        return sHandler;
    }

    /// a game was launched (Session.setNowPlaying): watch its process, if PServer / root is there
    static synchronized void start() {
        final int gen = ++sGeneration;
        sSeen = false;
        sAlive = false;
        sPending = null;
        sWaited = 0;
        sStartedAt = SystemClock.elapsedRealtime();
        if (Session.app() == null || !Privileged.available())
            return;
        Handler h = handler();
        h.removeCallbacksAndMessages(null);
        h.postDelayed(() -> tick(gen), PERIOD_MS);
    }

    /// the session ended
    static synchronized void stop() {
        ++sGeneration;
        if (sHandler != null)
            sHandler.removeCallbacksAndMessages(null);
        sPending = null;
    }

    /// the game's process was seen running: whether it ends can be told
    static boolean tracked() { return sSeen; }

    /// ...and it still runs
    static boolean alive() { return sSeen && sAlive; }

    private static void tick(int gen) {
        synchronized (GameProcess.class) {
            if (gen != sGeneration)
                return;
        }
        Context ctx = Session.app();
        if (ctx == null || !Session.sessionOpen())
            return;
        String pkg = Session.gamePackage;
        if (!pkg.isEmpty()) {
            if (sPending != null) {
                String out = Privileged.readText(sPending);
                if (out.contains("end")) { // the script ran
                    sPending = null;
                    if (PID.matcher(out).find()) {
                        if (!sSeen) Log.i(Session.TAG, "game process found: " + pkg);
                        sSeen = true;
                        sAlive = true;
                    }
                    else if (sSeen && sAlive) {
                        sAlive = false;
                        Log.i(Session.TAG, "game process ended: " + pkg);
                        sMain.post(Session::onGameProcessGone);
                    }
                }
                else if (++sWaited >= MAX_WAIT_TICKS) {
                    sPending = null; // PServer dropped it: ask again
                }
            }
            if (sPending == null && sAlive == sSeen) { // nothing on the way (and not just ended)
                File f = Privileged.outputFile(ctx, "process.txt");
                String path = Privileged.quote(f.getAbsolutePath());
                String body = "echo \"pid=$(pidof " + Privileged.quote(pkg) + ")\" > " + path + "; echo end >> " + path;
                if (Privileged.runScript(ctx, "process.sh", body)) {
                    sPending = f;
                    sWaited = 0;
                }
            }
        }
        Session.onProcessTick();
        if (!sSeen && SystemClock.elapsedRealtime() - sStartedAt > FIND_MS) {
            Log.i(Session.TAG, "game process not found: no process tracking this session");
            return;
        }
        if (sSeen && !sAlive)
            return; // ended: nothing more to watch
        synchronized (GameProcess.class) {
            if (gen == sGeneration)
                handler().postDelayed(() -> tick(gen), PERIOD_MS);
        }
    }
}
