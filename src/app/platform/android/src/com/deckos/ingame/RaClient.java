// DeckOS - in-game layer
// RetroAchievements for the overlay's Achievements tab: the running game's achievements with the
// user's progress (API_GetGameInfoAndUserProgress), and badge images. Network off the UI thread;
// the API key is never logged. RetroArch posts unlocks to RA right away, so refreshing when the tab
// opens shows what was just earned.

package com.deckos.ingame;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.util.LruCache;
import android.widget.ImageView;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;


final class RaClient {
    static final String MEDIA = "https://media.retroachievements.org";

    static final class Achievement {
        String title = "", description = "", badge = "";
        int points, order;
        float rate = Float.NaN;  // % of the game's players who have it
        boolean earned, hardcore;
        long earnedAt;           // ms, 0 if locked
    }

    static final class Game {
        int id;
        String title = "", console = "", icon = "";
        int earnedPoints, totalPoints;
        final List<Achievement> achievements = new ArrayList<>();
        String error = null;
        int earned() {
            int n = 0;
            for (Achievement a : achievements) if (a.earned) n++;
            return n;
        }
    }

    interface Callback { void done(Game game); }

    private static final ExecutorService POOL = Executors.newFixedThreadPool(3);
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final LruCache<String, Bitmap> IMAGES = new LruCache<String, Bitmap>(16 * 1024 * 1024) {
        @Override protected int sizeOf(String key, Bitmap b) { return b.getByteCount(); }
    };

    private RaClient() {}

    static void loadGame(final int gameId, final String user, final String key, final Callback callback) {
        POOL.execute(() -> {
            final Game g = new Game();
            g.id = gameId;
            try {
                String url = "https://retroachievements.org/API/API_GetGameInfoAndUserProgress.php?g=" + gameId
                    + "&u=" + URLEncoder.encode(user, "UTF-8") + "&y=" + URLEncoder.encode(key, "UTF-8");
                JSONObject o = new JSONObject(new String(download(url), "UTF-8"));
                g.title = str(o, "Title");
                g.console = str(o, "ConsoleName");
                g.icon = str(o, "ImageIcon");
                int players = o.optInt("NumDistinctPlayers", 0);
                JSONObject list = o.optJSONObject("Achievements");
                if (list != null) {
                    Iterator<String> it = list.keys();
                    while (it.hasNext()) {
                        JSONObject a = list.optJSONObject(it.next());
                        if (a == null) continue;
                        Achievement x = new Achievement();
                        x.title = str(a, "Title");
                        x.description = str(a, "Description");
                        x.badge = str(a, "BadgeName");
                        x.points = a.optInt("Points", 0);
                        x.order = a.optInt("DisplayOrder", 0);
                        if (players > 0)
                            x.rate = 100f * a.optInt("NumAwarded", 0) / players;
                        String hc = str(a, "DateEarnedHardcore");
                        String sc = str(a, "DateEarned");
                        x.earned = !hc.isEmpty() || !sc.isEmpty();
                        x.hardcore = !hc.isEmpty();
                        x.earnedAt = parseDate(!hc.isEmpty() ? hc : sc);
                        g.totalPoints += x.points;
                        if (x.earned) g.earnedPoints += x.points;
                        g.achievements.add(x);
                    }
                }
                // newest unlocks first, then the locked ones in the game's own order
                Collections.sort(g.achievements, (a, b) -> {
                    if (a.earned != b.earned) return a.earned ? -1 : 1;
                    if (a.earned) return Long.compare(b.earnedAt, a.earnedAt);
                    return Integer.compare(a.order, b.order);
                });
            }
            catch (Exception e) {
                Log.w(Session.TAG, "RetroAchievements: " + e.getClass().getSimpleName()); // no URL: it has the key
                g.error = "Couldn't reach RetroAchievements";
            }
            MAIN.post(() -> callback.done(g));
        });
    }

    static String badgeUrl(Achievement a) {
        return MEDIA + "/Badge/" + a.badge + (a.earned ? ".png" : "_lock.png");
    }

    static void image(final ImageView view, final String url) {
        view.setTag(url);
        Bitmap cached = IMAGES.get(url);
        if (cached != null) {
            view.setImageBitmap(cached);
            return;
        }
        POOL.execute(() -> {
            Bitmap bmp = null;
            try {
                byte[] data = download(url);
                bmp = BitmapFactory.decodeByteArray(data, 0, data.length);
            }
            catch (Exception ignored) {}
            if (bmp != null)
                IMAGES.put(url, bmp);
            final Bitmap result = bmp;
            MAIN.post(() -> {
                if (result != null && url.equals(view.getTag()))
                    view.setImageBitmap(result);
            });
        });
    }

    /// a local picture (the profile picture), scaled down to about `maxPx`
    static Bitmap localImage(String uriOrPath, int maxPx) {
        String path = uriOrPath;
        if (path.startsWith("file://")) path = path.substring(7);
        else if (path.startsWith("file:")) path = path.substring(5);
        if (path.isEmpty()) return null;
        BitmapFactory.Options o = new BitmapFactory.Options();
        o.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(path, o);
        int sample = 1;
        while (o.outWidth / (sample * 2) >= maxPx && o.outHeight / (sample * 2) >= maxPx) sample *= 2;
        BitmapFactory.Options d = new BitmapFactory.Options();
        d.inSampleSize = sample;
        return BitmapFactory.decodeFile(path, d);
    }

    private static String str(JSONObject o, String key) {
        return o.isNull(key) ? "" : o.optString(key, "");
    }

    private static long parseDate(String s) {
        if (s.isEmpty()) return 0;
        try {
            SimpleDateFormat f = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);
            f.setTimeZone(TimeZone.getTimeZone("UTC"));
            return f.parse(s).getTime();
        }
        catch (Exception e) {
            return 0;
        }
    }

    private static byte[] download(String url) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(15000);
        c.setReadTimeout(20000);
        c.setRequestProperty("User-Agent", "DeckOS (Pegasus Frontend fork)");
        try (InputStream in = c.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buf = new byte[16384];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            return out.toByteArray();
        }
        finally {
            c.disconnect();
        }
    }
}
