// DeckOS - in-game layer
// Quick Settings controls: brightness, Wi-Fi and Bluetooth, switched in place instead of opening
// Android's settings. Android 10+ doesn't let apps switch Wi-Fi, so that (and the network list) goes
// through PServer (`svc wifi`, `cmd wifi ...`) on AYN / Retroid; without it the rows open Android's
// panels. Joining a network that needs a password always opens Android's Wi-Fi panel.

package com.deckos.ingame;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.res.Resources;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;

import java.io.File;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


final class QuickControls {
    private QuickControls() {}

    // --- brightness --------------------------------------------------------------------------------

    private static int maxBrightness() {
        try {
            Resources sys = Resources.getSystem();
            int id = sys.getIdentifier("config_screenBrightnessSettingMaximum", "integer", "android");
            if (id != 0) {
                int v = sys.getInteger(id);
                if (v > 0) return v;
            }
        }
        catch (Exception ignored) {}
        return 255;
    }

    static boolean canWriteSettings(Context ctx) {
        return Build.VERSION.SDK_INT < 23 || Settings.System.canWrite(ctx);
    }

    static boolean canSetBrightness(Context ctx) {
        return canWriteSettings(ctx) || Privileged.available();
    }

    static int brightnessPercent(Context ctx) {
        try {
            int v = Settings.System.getInt(ctx.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS);
            return Math.round(100f * v / maxBrightness());
        }
        catch (Exception e) {
            return 50;
        }
    }

    private static long sLastPrivileged = 0;

    /// done: the last value of a drag (always applied; in-between values through PServer are throttled)
    static void setBrightnessPercent(Context ctx, int pct, boolean done) {
        int v = Math.max(1, Math.round(maxBrightness() * Math.max(0, Math.min(100, pct)) / 100f));
        if (canWriteSettings(ctx)) {
            try {
                Settings.System.putInt(ctx.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS_MODE,
                                       Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                Settings.System.putInt(ctx.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, v);
                return;
            }
            catch (Exception e) {
                Log.w(Session.TAG, "brightness: " + e);
            }
        }
        long now = System.currentTimeMillis();
        if (!done && now - sLastPrivileged < 250) return; // each `settings` call starts a process
        sLastPrivileged = now;
        Privileged.run("settings put system screen_brightness_mode 0; settings put system screen_brightness " + v);
    }


    // --- Wi-Fi -------------------------------------------------------------------------------------

    static boolean wifiOn(Context ctx) {
        WifiManager wm = (WifiManager) ctx.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        return wm != null && wm.isWifiEnabled();
    }

    static boolean canSwitchWifi() { return Privileged.available(); }

    static boolean setWifi(boolean on) {
        return Privileged.run("svc wifi " + (on ? "enable" : "disable"));
    }

    static final class Network {
        String ssid;
        int rssi;
        boolean secure;
        boolean connected;
    }

    interface NetworksCallback { void done(String connected, List<Network> networks); }

    private static final Pattern SCAN_LINE = Pattern.compile(
        "^\\s*([0-9a-fA-F:]{17})\\s+(\\d+)\\s+(-?\\d+)\\s+(\\S+)\\s+(.*?)\\s*(\\[.*)?$");
    private static final Pattern STATUS_SSID = Pattern.compile("SSID: \"([^\"]*)\"");

    /// scans through PServer and reads the results a few seconds later (callback on the main thread)
    static void scanWifi(Context ctx, NetworksCallback cb) {
        final File scan = Privileged.outputFile(ctx, "wifi-scan.txt");
        final File status = Privileged.outputFile(ctx, "wifi-status.txt");
        boolean sent = Privileged.runScript(ctx, "wifi-scan.sh",
            "cmd wifi status > wifi-status.txt 2>&1\n"
            + "cmd wifi start-scan >/dev/null 2>&1\n"
            + "sleep 3\n"
            + "cmd wifi list-scan-results > wifi-scan.txt 2>&1\n");
        final Handler main = new Handler(Looper.getMainLooper());
        if (!sent) {
            main.post(() -> cb.done("", new ArrayList<>()));
            return;
        }
        new Thread(() -> {
            String text = "";
            for (int i = 0; i < 16 && text.isEmpty(); i++) {
                try { Thread.sleep(500); } catch (InterruptedException e) { break; }
                text = Privileged.readText(scan);
            }
            Matcher sm = STATUS_SSID.matcher(Privileged.readText(status));
            final String connected = sm.find() ? sm.group(1) : "";
            Map<String, Network> best = new LinkedHashMap<>();
            for (String line : text.split("\n")) {
                Matcher m = SCAN_LINE.matcher(line);
                if (!m.find()) continue;
                Network n = new Network();
                n.ssid = m.group(5).trim();
                if (n.ssid.isEmpty()) continue;
                try { n.rssi = Integer.parseInt(m.group(3)); } catch (NumberFormatException e) { n.rssi = -100; }
                String flags = m.group(6) == null ? "" : m.group(6);
                n.secure = flags.contains("PSK") || flags.contains("EAP") || flags.contains("SAE") || flags.contains("WEP");
                n.connected = n.ssid.equals(connected);
                Network old = best.get(n.ssid);
                if (old == null || old.rssi < n.rssi) best.put(n.ssid, n);
            }
            final List<Network> list = new ArrayList<>(best.values());
            java.util.Collections.sort(list, (a, b) -> a.connected != b.connected ? (a.connected ? -1 : 1) : b.rssi - a.rssi);
            main.post(() -> cb.done(connected, list));
        }, "deckos-wifi").start();
    }

    static boolean connectOpen(String ssid) {
        return Privileged.run("cmd wifi connect-network " + Privileged.quote(ssid) + " open");
    }


    // --- Bluetooth ---------------------------------------------------------------------------------

    @SuppressWarnings("deprecation")
    static BluetoothAdapter adapter() {
        try { return BluetoothAdapter.getDefaultAdapter(); } catch (Exception e) { return null; }
    }

    static boolean hasBluetooth() { return adapter() != null; }

    static boolean bluetoothOn() {
        BluetoothAdapter a = adapter();
        try { return a != null && a.isEnabled(); } catch (Exception e) { return false; }
    }

    @SuppressWarnings({"deprecation", "MissingPermission"})
    static boolean setBluetooth(boolean on) {
        BluetoothAdapter a = adapter();
        try {
            if (a != null && (on ? a.enable() : a.disable())) return true;
        }
        catch (Exception e) {
            Log.w(Session.TAG, "bluetooth: " + e);
        }
        return Privileged.run("svc bluetooth " + (on ? "enable" : "disable"));
    }

    static final class Device {
        String name;
        boolean connected;
    }

    @SuppressWarnings("MissingPermission")
    static List<Device> pairedDevices() {
        List<Device> out = new ArrayList<>();
        BluetoothAdapter a = adapter();
        if (a == null) return out;
        try {
            Set<BluetoothDevice> set = a.getBondedDevices();
            if (set == null) return out;
            for (BluetoothDevice d : set) {
                Device dev = new Device();
                dev.name = d.getName() != null ? d.getName() : d.getAddress();
                try {
                    Object c = d.getClass().getMethod("isConnected").invoke(d); // hidden API, read-only
                    dev.connected = c instanceof Boolean && (Boolean) c;
                }
                catch (Throwable ignored) {}
                out.add(dev);
            }
            java.util.Collections.sort(out, (x, y) -> x.connected != y.connected ? (x.connected ? -1 : 1) : x.name.compareToIgnoreCase(y.name));
        }
        catch (Exception e) {
            Log.w(Session.TAG, "paired devices: " + e);
        }
        return out;
    }
}
