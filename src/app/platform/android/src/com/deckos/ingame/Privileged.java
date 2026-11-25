// DeckOS - in-game layer
// Privileged commands through "PServer", the command runner that AYN and Retroid firmware ship as the
// system service "PServerBinder" (no root, Shizuku or permission needed). It's how DeckOS switches the
// vendor performance / fan modes, writes CPU and GPU limits (underclocking) and reads the frame counter.
//
// Protocol (documented by ClusterTune, MIT, from the AYN Thor's /system/bin/pservice; checked
// 2026-11-25): transaction code 0, flags 0, no interface token; Parcel = int32 count (2), the shell
// command (UTF-16, at most 255 bytes) and "0" (no output capture). It's fire-and-forget: output comes
// back through files DeckOS creates in its code cache folder (the privileged shell writes into them, so
// they stay DeckOS's and readable), as ClusterTune does with its host launcher.
// Longer work goes into a script in that folder, run with `cd <dir> && sh <script>`.
// A transaction that may have run is never retried. Devices without PServer: available() is false and
// every caller falls back (features hidden, or Android's own settings opened).

package com.deckos.ingame;

import android.content.Context;
import android.os.IBinder;
import android.os.Parcel;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;


final class Privileged {
    private static final int MAX_COMMAND_BYTES = 255;
    private static Boolean sAvailable;

    private Privileged() {}

    private static IBinder service() {
        try {
            Object b = Class.forName("android.os.ServiceManager")
                .getMethod("checkService", String.class)
                .invoke(null, "PServerBinder");
            return b instanceof IBinder ? (IBinder) b : null;
        }
        catch (Throwable e) {
            return null;
        }
    }

    /// PServer is there and alive (cached once found)
    static boolean available() {
        if (sAvailable != null && sAvailable)
            return true;
        IBinder b = service();
        sAvailable = b != null && b.isBinderAlive();
        return sAvailable;
    }

    /// Runs one short shell command (fire-and-forget). False if it couldn't be sent.
    static boolean run(String command) {
        if (command == null || command.isEmpty() || command.indexOf('\0') >= 0)
            return false;
        if (command.getBytes(StandardCharsets.UTF_8).length > MAX_COMMAND_BYTES) {
            Log.w(Session.TAG, "privileged command too long");
            return false;
        }
        IBinder b = service();
        if (b == null || !b.isBinderAlive())
            return false;
        Parcel request = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            request.writeInt(2);
            request.writeString(command);
            request.writeString("0");
            return b.transact(0, request, reply, 0);
        }
        catch (Throwable e) {
            Log.w(Session.TAG, "PServer: " + e);
            return false;
        }
        finally {
            reply.recycle();
            request.recycle();
        }
    }

    /// The folder for scripts and their output files (DeckOS-owned).
    static File dir(Context ctx) {
        File d = new File(ctx.getCodeCacheDir(), "deckos-priv");
        if (!d.isDirectory())
            d.mkdirs();
        d.setExecutable(true, false);
        d.setReadable(true, false);
        return d;
    }

    /// Writes `body` as a shell script named `name` and runs it in its folder.
    static boolean runScript(Context ctx, String name, String body) {
        File d = dir(ctx);
        File script = new File(d, name);
        if (!writeText(script, "#!/system/bin/sh\n" + body + "\n"))
            return false;
        script.setReadable(true, false);
        script.setExecutable(true, false);
        return run("cd " + quote(d.getAbsolutePath()) + " && sh " + quote(name));
    }

    /// An empty, DeckOS-owned file the privileged shell can write output into.
    static File outputFile(Context ctx, String name) {
        File f = new File(dir(ctx), name);
        writeText(f, "");
        f.setReadable(true, false);
        f.setWritable(true, false);
        return f;
    }

    static String quote(String s) {
        return "'" + s.replace("'", "'\\''") + "'";
    }

    static boolean writeText(File f, String text) {
        try (FileOutputStream out = new FileOutputStream(f)) {
            out.write(text.getBytes(StandardCharsets.UTF_8));
            return true;
        }
        catch (Exception e) {
            Log.w(Session.TAG, "can't write " + f.getName() + ": " + e);
            return false;
        }
    }

    static String readText(File f) {
        if (f == null || !f.isFile())
            return "";
        try (FileInputStream in = new FileInputStream(f)) {
            byte[] buf = new byte[(int) Math.min(f.length(), 256 * 1024)];
            int n = 0, r;
            while (n < buf.length && (r = in.read(buf, n, buf.length - n)) > 0)
                n += r;
            return new String(buf, 0, n, StandardCharsets.UTF_8);
        }
        catch (Exception e) {
            return "";
        }
    }
}
