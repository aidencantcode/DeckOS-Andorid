// DeckOS - in-game layer
// AYN / Retroid device controls for the Quick Access "Performance" tab and the HUD:
//  - vendor performance mode and fan mode: Settings.System `performance_mode` / `fan_mode`, read
//    directly, written through PServer (`settings put system ...`). Values from ClusterTune's HUD code
//    (performance 0/1/2 = Standard/Performance/High, fan 0 Off, 1 Quiet, 4 Smart, 5 Sport, 6 Custom);
//    *verify* on each handheld with the device info dump.
//  - the CPU cluster list for the device info dump (underclocking itself: Underclock.java and C++
//    deckos/Underclock, ClusterTune built in).
//  - frame rate: SurfaceFlinger's page-flip counter (`service call SurfaceFlinger 1013`), sampled once a
//    second by a small loop started through PServer, only while the HUD shows it.
//  - a device info dump (Settings > System) to confirm all of the above on real hardware.

package com.deckos.ingame;

import android.content.Context;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import org.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


final class DeviceControl {
    private DeviceControl() {}

    static final String KEY_PERF = "performance_mode";
    static final String KEY_FAN = "fan_mode";

    static final int[] PERF_VALUES = { 0, 1, 2 };
    static final String[] PERF_LABELS = { "Standard", "Perf.", "High" };
    static final String[] PERF_NAMES = { "Standard", "Performance", "High Performance" };

    static final int FAN_CUSTOM = 6;
    static final int[] FAN_VALUES = { 1, 4, 5, FAN_CUSTOM };
    static final String[] FAN_LABELS = { "Quiet", "Smart", "Sport", "Max" };

    private static final String CPUFREQ = "/sys/devices/system/cpu/cpufreq";
    private static final String KGSL = "/sys/class/kgsl/kgsl-3d0";


    // --- which device ------------------------------------------------------------------------------

    static boolean isAynOrRetroid() {
        String s = (Build.MANUFACTURER + " " + Build.BRAND + " " + Build.MODEL).toLowerCase(Locale.US);
        return s.contains("ayn") || s.contains("odin") || s.contains("thor") || s.contains("retroid") || s.contains("moorechip");
    }

    static String socModel() {
        String v = "";
        if (Build.VERSION.SDK_INT >= 31) { // Build.SOC_MODEL, not in the SDK DeckOS compiles against
            try { Object f = Build.class.getField("SOC_MODEL").get(null); v = f == null ? "" : f.toString(); }
            catch (Exception ignored) {}
        }
        if (v == null || v.isEmpty() || "unknown".equalsIgnoreCase(v))
            v = sysProp("ro.soc.model");
        if (v.isEmpty())
            v = sysProp("ro.vendor.qti.soc_model");
        if (v.isEmpty())
            v = Build.HARDWARE;
        return v == null ? "" : v.trim();
    }

    static String sysProp(String name) {
        try {
            Object v = Class.forName("android.os.SystemProperties").getMethod("get", String.class).invoke(null, name);
            return v == null ? "" : v.toString().trim();
        }
        catch (Throwable e) {
            return "";
        }
    }


    // --- vendor modes ------------------------------------------------------------------------------

    static int readSystemInt(Context ctx, String key, int def) {
        try {
            String s = Settings.System.getString(ctx.getContentResolver(), key);
            return s == null ? def : Integer.parseInt(s.trim());
        }
        catch (Exception e) {
            return def;
        }
    }

    static boolean hasPerformanceModes(Context ctx) {
        return readSystemInt(ctx, KEY_PERF, -1) >= 0;
    }

    static boolean hasFanModes(Context ctx) {
        return readSystemInt(ctx, KEY_FAN, -1) >= 0;
    }

    static boolean canWrite() {
        return Privileged.available();
    }

    static int perfIndex(Context ctx) {
        return indexOf(PERF_VALUES, readSystemInt(ctx, KEY_PERF, -1));
    }

    static boolean setPerf(int index) {
        if (index < 0 || index >= PERF_VALUES.length) return false;
        return Privileged.run("settings put system " + KEY_PERF + " " + PERF_VALUES[index]);
    }

    static int fanIndex(Context ctx) {
        return indexOf(FAN_VALUES, readSystemInt(ctx, KEY_FAN, -1));
    }

    /// Max = the vendor's Custom mode. Setting its speed to full needs the custom-speed key, which the
    /// device info dump will tell us; until then Custom keeps the speed set in the vendor's settings.
    static boolean setFan(int index) {
        if (index < 0 || index >= FAN_VALUES.length) return false;
        return Privileged.run("settings put system " + KEY_FAN + " " + FAN_VALUES[index]);
    }

    static String perfName(Context ctx) {
        int i = perfIndex(ctx);
        return i >= 0 ? PERF_NAMES[i] : "";
    }

    static String fanName(Context ctx) {
        int i = fanIndex(ctx);
        return i >= 0 ? FAN_LABELS[i] : "";
    }

    private static int indexOf(int[] values, int v) {
        for (int i = 0; i < values.length; i++)
            if (values[i] == v) return i;
        return -1;
    }


    // --- CPU clusters (device info) ----------------------------------------------------------------

    static final class Policy {
        int id;
        String path;
        int hwMax;
        int[] freqs = new int[0];
        int current;
    }

    static List<Policy> policies() {
        List<Policy> out = new ArrayList<>();
        File[] dirs = new File(CPUFREQ).listFiles();
        if (dirs == null) return out;
        for (File d : dirs) {
            String n = d.getName();
            if (!n.startsWith("policy")) continue;
            try {
                Policy p = new Policy();
                p.id = Integer.parseInt(n.substring(6));
                p.path = d.getAbsolutePath();
                p.hwMax = parseInt(Stats.firstLine(p.path + "/cpuinfo_max_freq"), 0);
                p.current = parseInt(Stats.firstLine(p.path + "/scaling_max_freq"), 0);
                String avail = Stats.firstLine(p.path + "/scaling_available_frequencies");
                if (avail != null && !avail.trim().isEmpty()) {
                    String[] parts = avail.trim().split("\\s+");
                    int[] f = new int[parts.length];
                    for (int i = 0; i < parts.length; i++) f[i] = parseInt(parts[i], 0);
                    Arrays.sort(f);
                    p.freqs = f;
                }
                if (p.hwMax > 0) out.add(p);
            }
            catch (Exception ignored) {}
        }
        java.util.Collections.sort(out, (a, b) -> a.id - b.id);
        return out;
    }

    // --- frame rate --------------------------------------------------------------------------------

    private static final Pattern PARCEL = Pattern.compile("Parcel\\(\\s*([0-9a-fA-F]{1,8})");
    private static long sLastFrames = -1, sLastAt = 0;
    private static float sFps = Float.NaN;
    private static boolean sFpsRunning = false;

    /// starts / keeps alive / stops the frame counter loop; call once a second
    static void fpsTick(Context ctx, boolean wanted) {
        File dir = Privileged.dir(ctx);
        File flag = new File(dir, "fps.on");
        if (!wanted || !Privileged.available()) {
            if (flag.exists()) flag.delete();
            sFpsRunning = false;
            sFps = Float.NaN;
            sLastFrames = -1;
            return;
        }
        Privileged.writeText(flag, "1"); // fresh mtime: the loop stops by itself 15 s after DeckOS stops renewing it
        if (!sFpsRunning) {
            Privileged.outputFile(ctx, "fps.txt");
            Privileged.writeText(new File(dir, "fps.sh"),
                "cd \"$(dirname \"$0\")\"\n"
                + "while [ -f fps.on ]; do\n"
                + "  age=$(( $(date +%s) - $(stat -c %Y fps.on) ))\n"
                + "  [ \"$age\" -gt 15 ] && break\n"
                + "  service call SurfaceFlinger 1013 > fps.txt 2>/dev/null\n"
                + "  sleep 1\n"
                + "done\n");
            sFpsRunning = Privileged.runScript(ctx, "fps-start.sh",
                "nohup setsid sh fps.sh >/dev/null 2>&1 </dev/null &");
            return;
        }
        Matcher m = PARCEL.matcher(Privileged.readText(new File(dir, "fps.txt")));
        if (!m.find()) return;
        long frames = Long.parseLong(m.group(1), 16);
        long now = System.currentTimeMillis();
        if (sLastFrames >= 0 && frames >= sLastFrames && now > sLastAt) {
            float fps = (frames - sLastFrames) * 1000f / (now - sLastAt);
            if (fps >= 0 && fps < 500) sFps = fps;
        }
        sLastFrames = frames;
        sLastAt = now;
    }

    static float fps() { return sFps; }


    // --- device info -------------------------------------------------------------------------------

    static String deviceInfo(Context ctx) {
        StringBuilder s = new StringBuilder();
        s.append("DeckOS device info\n");
        s.append("Device: ").append(Build.MANUFACTURER).append(" / ").append(Build.BRAND).append(" / ")
         .append(Build.MODEL).append(" (").append(Build.DEVICE).append(")\n");
        s.append("Android ").append(Build.VERSION.RELEASE).append(" (SDK ").append(Build.VERSION.SDK_INT).append(")\n");
        s.append("SoC: ").append(socModel()).append("  hardware: ").append(Build.HARDWARE).append("\n");
        s.append("PServer: ").append(Privileged.pserver() ? "yes" : "no")
         .append("  root (su): ").append(Privileged.root() ? "yes" : "no")
         .append("  usage access: ").append(Foreground.usageAllowed(ctx) ? "yes" : "no").append("\n");
        s.append("Vendor modes: performance_mode=").append(readSystemInt(ctx, KEY_PERF, -1))
         .append(" fan_mode=").append(readSystemInt(ctx, KEY_FAN, -1)).append("\n");

        s.append("\nSettings.System (fan / performance / mode keys):\n");
        try (Cursor c = ctx.getContentResolver().query(Settings.System.CONTENT_URI, new String[] { "name", "value" }, null, null, null)) {
            if (c != null) {
                while (c.moveToNext()) {
                    String name = c.getString(0);
                    if (name == null) continue;
                    String low = name.toLowerCase(Locale.US);
                    if (low.contains("fan") || low.contains("perf") || low.contains("cpu") || low.contains("gpu")
                        || low.contains("thermal") || low.contains("boost") || low.contains("fps") || low.contains("game"))
                        s.append("  ").append(name).append(" = ").append(c.getString(1)).append("\n");
                }
            }
        }
        catch (Exception e) {
            s.append("  (can't read: ").append(e.getClass().getSimpleName()).append(")\n");
        }

        s.append("\nCPU clusters:\n");
        for (Policy p : policies())
            s.append("  policy").append(p.id).append(": max ").append(p.current).append(" / hw ").append(p.hwMax)
             .append(" kHz, ").append(p.freqs.length).append(" steps\n");
        s.append("GPU: max_gpuclk=").append(orDash(Stats.firstLine(KGSL + "/max_gpuclk")))
         .append(" busy=").append(orDash(Stats.firstLine(KGSL + "/gpu_busy_percentage"))).append("\n");

        s.append("\nFan nodes:\n");
        for (String path : new String[] { "/sys/class/gpio5_pwm2/speed", "/sys/class/gpio5_pwm2/duty",
                                          "/sys/devices/virtual/fan_info/fan_info_data/duty",
                                          "/sys/devices/platform/odm/odm:mid_custom/fan" })
            s.append("  ").append(path).append(": ").append(orDash(Stats.firstLine(path))).append("\n");

        Stats.Snapshot snap = SessionService.lastStats();
        if (snap == null) snap = new Stats(ctx).sample();
        s.append("\nSensors: cpu ").append(HudView.num(snap.cpuPct)).append("% ").append(HudView.num(snap.cpuTempC))
         .append("C, gpu ").append(HudView.num(snap.gpuPct)).append("% ").append(HudView.num(snap.gpuTempC))
         .append("C, batt ").append(HudView.num(snap.battPct)).append("% ")
         .append(Float.isNaN(snap.battWatts) ? "-" : String.format(Locale.US, "%.1f", snap.battWatts)).append("W, fan ")
         .append(snap.fanRpm).append(" rpm\n");
        return s.toString();
    }

    private static String orDash(String s) {
        return s == null || s.trim().isEmpty() ? "-" : s.trim();
    }

    private static int parseInt(String s, int def) {
        try { return s == null ? def : Integer.parseInt(s.trim()); } catch (Exception e) { return def; }
    }

    static void log(String msg) { Log.i(Session.TAG, msg); }
}
