// DeckOS - in-game layer
// Whether the game DeckOS started still runs, looked up through PServer / root while a session is open -
// also while DeckOS itself is in front. Android hides other apps from normal apps, so without PServer or
// root this stays unknown and a session ends when DeckOS is back in front, as before. With it, the
// session goes on until the game ends (the game page shows it running, with Resume and Stop, like Steam),
// and play time can count while the game runs instead of only while it's in front
// (Session.countWhileRunning).
//
// "Runs" = its app's process is there AND it still has an activity in Android's task list
// (`dumpsys activity activities`, the "Hist #" rows). The process alone wasn't enough: an emulator closed
// from its own menu (or crashed) leaves a cached process behind for minutes, so DeckOS kept showing it
// running and Resume opened the emulator's own menu instead of the game. Firmware whose dump has no
// "Hist" rows falls back to the process alone.
//
// Checked every 2 s while the game is in front, every 0.7 s while DeckOS is (closing is noticed within
// about a second), and at once when asked (checkNow: DeckOS came back, Play / Resume was pressed, or a
// game was just closed). The output comes back through a file, like every PServer command (Privileged);
// it's read every 100 ms until it's there.

package com.deckos.ingame;

import android.content.Context;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import java.io.File;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


final class GameProcess {
    private GameProcess() {}

    private static final long PERIOD_GAME_MS = 2000;     // the game is in front
    private static final long PERIOD_FRONTEND_MS = 700;  // DeckOS is in front, the game behind it
    private static final long READ_MS = 100;             // the script's output: looked for this often
    private static final long GIVE_UP_MS = 3000;         // a script whose output never came: sent again
    private static final long FIND_MS = 60000;           // never seen by then: not tracked this session
    private static final Pattern RESULT = Pattern.compile("pid=(\\S*)\\s+hist=(\\d+)\\s+act=(\\d+)");

    private static final Handler sMain = new Handler(Looper.getMainLooper());
    private static Handler sHandler;                     // its own thread: file reads and PServer calls
    private static int sGeneration = 0;                  // bumped per session, so an old loop stops
    private static volatile boolean sSeen = false, sAlive = false;
    private static File sPending;                        // the running script's output file
    private static volatile long sPendingSince = 0;      // ...and when that script was sent
    private static volatile long sNextCheckAt = 0;
    private static long sStartedAt = 0;
    private static volatile long sRequestedAt = 0;       // checkNow
    private static volatile long sResultFrom = 0;        // when the script of the last result was sent

    private static synchronized Handler handler() {
        if (sHandler == null) {
            HandlerThread t = new HandlerThread("deckos-game-process");
            t.start();
            sHandler = new Handler(t.getLooper());
        }
        return sHandler;
    }

    /// a game was launched (Session.setNowPlaying): watch it, if PServer / root is there
    static synchronized void start() {
        final int gen = ++sGeneration;
        sSeen = false;
        sAlive = false;
        sPending = null;
        sNextCheckAt = 0;
        sRequestedAt = 0;
        sResultFrom = 0;
        sStartedAt = SystemClock.elapsedRealtime();
        if (Session.app() == null || !Privileged.available())
            return;
        Handler h = handler();
        h.removeCallbacksAndMessages(null);
        sNextCheckAt = sStartedAt + PERIOD_GAME_MS;
        h.postDelayed(() -> tick(gen), PERIOD_GAME_MS);
    }

    /// the session ended
    static synchronized void stop() {
        ++sGeneration;
        if (sHandler != null)
            sHandler.removeCallbacksAndMessages(null);
        sPending = null;
    }

    /// look again now (the result: fresh() turns true)
    static void checkNow() {
        final int gen;
        synchronized (GameProcess.class) {
            gen = sGeneration;
            sRequestedAt = SystemClock.elapsedRealtime();
            sNextCheckAt = 0;
        }
        if (Session.app() == null || !Privileged.available())
            return;
        Handler h = handler();
        h.removeCallbacksAndMessages(null);
        h.post(() -> tick(gen));
    }

    /// a check sent after the last checkNow() has come back
    static boolean fresh() { return sResultFrom >= sRequestedAt && sResultFrom > 0; }

    /// the game was seen running: whether it ends can be told
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
        final String pkg = Session.gamePackage;
        final long now = SystemClock.elapsedRealtime();
        if (pkg.isEmpty()) {
            sNextCheckAt = now + PERIOD_GAME_MS; // not known yet (the first app in front names it)
        }
        else {
            if (sPending != null) {
                String out = Privileged.readText(sPending);
                if (out.contains("end")) { // the script ran
                    long from = sPendingSince;
                    sPending = null;
                    onResult(pkg, out, from);
                    if (gen != sGeneration) return;
                }
                else if (now - sPendingSince > GIVE_UP_MS) {
                    sPending = null; // PServer dropped it: ask again
                    sNextCheckAt = 0;
                }
            }
            if (sPending == null && now >= sNextCheckAt) {
                File f = Privileged.outputFile(ctx, "process.txt");
                String path = Privileged.quote(f.getAbsolutePath());
                String q = Privileged.quote(pkg);
                String body = "p=$(pidof " + q + ")\n"
                            + "d=$(dumpsys activity activities 2>/dev/null | grep -E 'Hist +#')\n"
                            + "t=$(printf '%s\\n' \"$d\" | grep -c .)\n"
                            + "a=$(printf '%s\\n' \"$d\" | grep -cF \" \"" + q + "\"/\")\n"
                            + "echo \"pid=$p hist=$t act=$a\" > " + path + "\n"
                            + "echo end >> " + path;
                if (Privileged.runScript(ctx, "process.sh", body)) {
                    sPending = f;
                    sPendingSince = now;
                }
                sNextCheckAt = now + (Session.frontendInFront ? PERIOD_FRONTEND_MS : PERIOD_GAME_MS);
            }
        }
        Session.onProcessTick();
        if (!sSeen && now - sStartedAt > FIND_MS && sRequestedAt == 0) {
            Log.i(Session.TAG, "game process not found: no process tracking this session");
            return;
        }
        if (sSeen && !sAlive)
            return; // ended: nothing more to watch
        long delay = sPending != null ? READ_MS : Math.max(READ_MS, sNextCheckAt - now);
        synchronized (GameProcess.class) {
            if (gen == sGeneration)
                handler().postDelayed(() -> tick(gen), delay);
        }
    }

    private static void onResult(String pkg, String out, long from) {
        Matcher m = RESULT.matcher(out);
        boolean pid, running;
        if (m.find()) {
            pid = !m.group(1).isEmpty();
            int hist = Integer.parseInt(m.group(2)), act = Integer.parseInt(m.group(3));
            running = pid && (hist == 0 || act > 0); // no "Hist" rows on this firmware: the process alone
        }
        else {
            pid = out.contains("pid=") && !out.contains("pid= ");
            running = pid;
        }
        sResultFrom = from;
        if (running) {
            if (!sSeen) Log.i(Session.TAG, "game found running: " + pkg);
            sSeen = true;
            sAlive = true;
        }
        else if (sSeen && sAlive) {
            sAlive = false;
            Log.i(Session.TAG, (pid ? "game closed (its app has no screen left): " : "game process ended: ") + pkg);
            sMain.post(Session::onGameProcessGone);
        }
    }
}
