// DeckOS - in-game layer
// Reads what a normal app may read about the device, once a second: battery (level, power draw,
// time left), CPU (load, per-core clocks, temperature), GPU (Adreno load/clock/temperature), RAM and
// fan speed. Anything a device doesn't expose stays NaN / -1 and is shown as "-" instead of guessed.
// Frame rate is not readable without Shizuku/root (planned).

package com.deckos.ingame;

import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.BatteryManager;
import android.os.Build;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.List;


final class Stats {

    static final class Snapshot {
        float battPct = Float.NaN;
        boolean charging = false;
        float battWatts = Float.NaN;
        long battMinutesLeft = -1;   // discharging: time left; charging: time to full
        float battTempC = Float.NaN;
        float cpuPct = Float.NaN;
        boolean cpuFromClocks = false; // load estimated from clock speeds (Android hides /proc/stat)
        int[] coreMhz = new int[0];
        float[] coreLoad = new float[0];
        int cpuMaxMhz = -1;
        float cpuTempC = Float.NaN;
        float gpuPct = Float.NaN;
        int gpuMhz = -1;
        float gpuTempC = Float.NaN;
        long ramUsedMb = -1;
        long ramTotalMb = -1;
        int fanRpm = -1;
    }

    private final Context ctx;
    private long[] lastCpu = null;
    private int cores = -1;
    private List<File> cpuZones = null;
    private List<File> gpuZones = null;
    private File fanFile = null;
    private boolean fanSearched = false;

    Stats(Context ctx) { this.ctx = ctx.getApplicationContext(); }

    Snapshot sample() {
        Snapshot s = new Snapshot();
        readBattery(s);
        readCpu(s);
        readGpu(s);
        readRam(s);
        readTemps(s);
        readFan(s);
        return s;
    }


    // --- battery ----------------------------------------------------------------------------------

    private void readBattery(Snapshot s) {
        Intent bat = ctx.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if (bat != null) {
            int level = bat.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int scale = bat.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
            if (level >= 0 && scale > 0)
                s.battPct = 100f * level / scale;
            int status = bat.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
            s.charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL;
            int tenths = bat.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Integer.MIN_VALUE);
            if (tenths != Integer.MIN_VALUE)
                s.battTempC = tenths / 10f;

            BatteryManager bm = (BatteryManager) ctx.getSystemService(Context.BATTERY_SERVICE);
            int mv = bat.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1);
            if (bm != null) {
                long ua = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW);
                if (ua != Integer.MIN_VALUE && ua != 0) {
                    // most devices report microamps; a few report milliamps
                    if (Math.abs(ua) < 10000) ua *= 1000;
                    if (mv > 0)
                        s.battWatts = Math.abs(ua) / 1e6f * (mv / 1000f);
                    long uah = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER);
                    if (!s.charging && uah > 0 && uah != Integer.MIN_VALUE)
                        s.battMinutesLeft = Math.round(60.0 * uah / Math.abs(ua));
                }
                if (s.charging && Build.VERSION.SDK_INT >= 28) {
                    long ms = bm.computeChargeTimeRemaining();
                    if (ms > 0)
                        s.battMinutesLeft = ms / 60000;
                }
            }
        }
    }


    // --- CPU --------------------------------------------------------------------------------------

    private void readCpu(Snapshot s) {
        if (cores < 0)
            cores = Math.max(1, Runtime.getRuntime().availableProcessors());

        // real load from /proc/stat where it's readable (Android 8+ usually hides it from apps)
        String line = firstLine("/proc/stat");
        if (line != null && line.startsWith("cpu ")) {
            String[] parts = line.trim().split("\\s+");
            long[] now = new long[parts.length - 1];
            for (int i = 1; i < parts.length; i++)
                now[i - 1] = parseLong(parts[i], 0);
            if (lastCpu != null && lastCpu.length == now.length && now.length >= 4) {
                long total = 0, idle = 0;
                for (int i = 0; i < now.length; i++) total += now[i] - lastCpu[i];
                idle = (now[3] - lastCpu[3]) + (now.length > 4 ? now[4] - lastCpu[4] : 0);
                if (total > 0)
                    s.cpuPct = 100f * (total - idle) / total;
            }
            lastCpu = now;
        }

        s.coreMhz = new int[cores];
        s.coreLoad = new float[cores];
        float loadSum = 0;
        int loadCount = 0;
        for (int i = 0; i < cores; i++) {
            String base = "/sys/devices/system/cpu/cpu" + i + "/cpufreq/";
            long cur = parseLong(firstLine(base + "scaling_cur_freq"), -1);
            long max = parseLong(firstLine(base + "cpuinfo_max_freq"), -1);
            s.coreMhz[i] = cur > 0 ? (int) (cur / 1000) : -1;
            s.coreLoad[i] = (cur > 0 && max > 0) ? 100f * cur / max : Float.NaN;
            if (max > 0)
                s.cpuMaxMhz = Math.max(s.cpuMaxMhz, (int) (max / 1000));
            if (!Float.isNaN(s.coreLoad[i])) {
                loadSum += s.coreLoad[i];
                loadCount++;
            }
        }
        if (Float.isNaN(s.cpuPct) && loadCount > 0) {
            s.cpuPct = loadSum / loadCount;
            s.cpuFromClocks = true;
        }
    }


    // --- GPU (Qualcomm Adreno: Odin 3, Retroid Pocket) ----------------------------------------------

    private void readGpu(Snapshot s) {
        String kgsl = "/sys/class/kgsl/kgsl-3d0/";
        String busy = firstLine(kgsl + "gpu_busy_percentage");
        if (busy != null) {
            s.gpuPct = parseFloat(busy.replace("%", "").trim(), Float.NaN);
        } else {
            String pair = firstLine(kgsl + "gpubusy");
            if (pair != null) {
                String[] p = pair.trim().split("\\s+");
                if (p.length >= 2) {
                    long b = parseLong(p[0], 0), t = parseLong(p[1], 0);
                    if (t > 0) s.gpuPct = 100f * b / t;
                }
            }
        }
        long hz = parseLong(firstLine(kgsl + "gpuclk"), -1);
        if (hz <= 0)
            hz = parseLong(firstLine(kgsl + "devfreq/cur_freq"), -1);
        if (hz > 0)
            s.gpuMhz = (int) (hz >= 1000000 ? hz / 1000000 : hz);
    }


    // --- RAM --------------------------------------------------------------------------------------

    private void readRam(Snapshot s) {
        ActivityManager am = (ActivityManager) ctx.getSystemService(Context.ACTIVITY_SERVICE);
        if (am == null)
            return;
        ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
        am.getMemoryInfo(mi);
        s.ramTotalMb = mi.totalMem / (1024 * 1024);
        s.ramUsedMb = (mi.totalMem - mi.availMem) / (1024 * 1024);
    }


    // --- temperatures and fan ---------------------------------------------------------------------

    private void readTemps(Snapshot s) {
        if (cpuZones == null) {
            cpuZones = new ArrayList<>();
            gpuZones = new ArrayList<>();
            File[] zones = new File("/sys/class/thermal").listFiles();
            if (zones != null) {
                for (File zone : zones) {
                    if (!zone.getName().startsWith("thermal_zone"))
                        continue;
                    String type = firstLine(zone.getPath() + "/type");
                    if (type == null)
                        continue;
                    type = type.toLowerCase();
                    if (type.contains("gpu"))
                        gpuZones.add(new File(zone, "temp"));
                    else if (type.contains("cpu") || type.contains("tsens_tz_sensor") || type.startsWith("soc"))
                        cpuZones.add(new File(zone, "temp"));
                }
            }
        }
        s.cpuTempC = maxTemp(cpuZones);
        s.gpuTempC = maxTemp(gpuZones);
    }

    private static float maxTemp(List<File> files) {
        float best = Float.NaN;
        for (File f : files) {
            long raw = parseLong(firstLine(f.getPath()), Long.MIN_VALUE);
            if (raw == Long.MIN_VALUE)
                continue;
            float c = raw > 1000 ? raw / 1000f : raw; // millidegrees on most kernels
            if (c > 0 && c < 150 && (Float.isNaN(best) || c > best))
                best = c;
        }
        return best;
    }

    private void readFan(Snapshot s) {
        if (!fanSearched) {
            fanSearched = true;
            File[] mons = new File("/sys/class/hwmon").listFiles();
            if (mons != null) {
                for (File mon : mons) {
                    File f = new File(mon, "fan1_input");
                    if (f.canRead()) { fanFile = f; break; }
                }
            }
        }
        if (fanFile != null)
            s.fanRpm = (int) parseLong(firstLine(fanFile.getPath()), -1);
    }


    // --- helpers ----------------------------------------------------------------------------------

    static String firstLine(String path) {
        try (BufferedReader r = new BufferedReader(new FileReader(path))) {
            return r.readLine();
        }
        catch (Exception e) {
            return null;
        }
    }

    static long parseLong(String s, long fallback) {
        if (s == null) return fallback;
        try { return Long.parseLong(s.trim()); }
        catch (NumberFormatException e) { return fallback; }
    }

    static float parseFloat(String s, float fallback) {
        if (s == null) return fallback;
        try { return Float.parseFloat(s.trim()); }
        catch (NumberFormatException e) { return fallback; }
    }
}
