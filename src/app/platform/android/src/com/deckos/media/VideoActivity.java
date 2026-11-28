// DeckOS - media
// A YouTube video played inside DeckOS (What's New's video shelves): a full-screen WebView with YouTube's
// own embedded player, driven by the controller - A play / pause, LEFT / RIGHT 10 s back / ahead, UP / DOWN
// volume, X opens it in the YouTube app, B goes back to DeckOS.
//
// The player is YouTube's official embed (the IFrame player API), so its terms are kept: no downloading,
// no ad-skipping, the video's own owner settings. The iframe is written here with
// referrerpolicy="strict-origin" and the page is loaded from an https base address, so YouTube receives a
// referrer: a WebView page without one gets "Error 153" (video player configuration error) since 2025.
// A video whose owner doesn't allow embedding (errors 101 / 150 / 152 / 153) opens in the YouTube app
// instead, and so does any video if the embed fails to load at all.

package com.deckos.media;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.TextView;


public class VideoActivity extends Activity {
    private static final String TAG = "DeckOS/video";
    private static final String EXTRA_ID = "videoId";
    private static final String EXTRA_TITLE = "title";
    private static final String BASE = "https://deckos.app/";
    private static final long HINT_MS = 3500;
    private static final long LOAD_TIMEOUT_MS = 15000;

    private WebView web;
    private TextView hint;
    private String videoId = "";
    private boolean ready = false;
    private boolean leaving = false;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable hideHint = () -> { if (hint != null) hint.animate().alpha(0f).setDuration(400).start(); };

    /// From C++ (deckos.web.playVideo). False if it couldn't be opened (the caller opens the link instead).
    public static boolean start(Context ctx, String videoId, String title) {
        if (ctx == null || videoId == null || !videoId.matches("[A-Za-z0-9_-]{6,20}"))
            return false;
        try {
            Intent i = new Intent(ctx, VideoActivity.class);
            i.putExtra(EXTRA_ID, videoId);
            i.putExtra(EXTRA_TITLE, title == null ? "" : title);
            if (!(ctx instanceof Activity))
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            ctx.startActivity(i);
            return true;
        }
        catch (Exception e) {
            Log.w(TAG, "can't open the player: " + e);
            return false;
        }
    }

    /// the video in the YouTube app (or the browser without it)
    public static boolean openInYouTube(Context ctx, String videoId) {
        if (ctx == null || videoId == null || videoId.isEmpty())
            return false;
        Intent app = new Intent(Intent.ACTION_VIEW, Uri.parse("vnd.youtube:" + videoId));
        Intent web = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/watch?v=" + videoId));
        for (Intent i : new Intent[] { app, web }) {
            if (!(ctx instanceof Activity))
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            try {
                ctx.startActivity(i);
                return true;
            }
            catch (ActivityNotFoundException ignored) {}
        }
        return false;
    }

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        videoId = getIntent().getStringExtra(EXTRA_ID);
        if (videoId == null || videoId.isEmpty()) {
            finish();
            return;
        }
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON | WindowManager.LayoutParams.FLAG_FULLSCREEN);
        immersive();

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        web = new WebView(this);
        web.setBackgroundColor(Color.BLACK);
        web.setFocusable(false); // the controller belongs to this activity, not to the page
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new WebViewClient());
        web.addJavascriptInterface(new Bridge(), "DeckOS");
        root.addView(web, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

        float dp = getResources().getDisplayMetrics().density;
        hint = new TextView(this);
        hint.setText("A  Play / Pause     ◀ ▶  10 s     ▲ ▼  Volume     X  Open in YouTube     B  Back");
        hint.setTextColor(Color.WHITE);
        hint.setTextSize(14);
        hint.setBackgroundColor(Color.argb(170, 14, 20, 27));
        hint.setPadding(Math.round(18 * dp), Math.round(10 * dp), Math.round(18 * dp), Math.round(10 * dp));
        FrameLayout.LayoutParams hp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT);
        hp.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
        hp.bottomMargin = Math.round(24 * dp);
        root.addView(hint, hp);

        setContentView(root);
        web.loadDataWithBaseURL(BASE, page(videoId), "text/html", "utf-8", null);
        showHint();
        // nothing playable in time (no network, YouTube changed something): the YouTube app instead
        handler.postDelayed(() -> { if (!ready && !leaving) handOver("the player didn't load"); }, LOAD_TIMEOUT_MS);
    }

    private static String page(String id) {
        return "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
            + "<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}"
            + "iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}</style></head><body>"
            + "<iframe id='p' referrerpolicy='strict-origin' allow='autoplay; encrypted-media; picture-in-picture'"
            + " src='https://www.youtube.com/embed/" + id + "?enablejsapi=1&autoplay=1&playsinline=1&rel=0&fs=0"
            + "&origin=" + Uri.encode(BASE.substring(0, BASE.length() - 1)) + "'></iframe>"
            + "<script>var player=null;"
            + "function onYouTubeIframeAPIReady(){player=new YT.Player('p',{events:{"
            + "onReady:function(e){DeckOS.ready();e.target.playVideo();},"
            + "onError:function(e){DeckOS.error(e.data);}}});}"
            + "function dToggle(){if(!player||!player.getPlayerState)return;var s=player.getPlayerState();"
            + "if(s==1||s==3)player.pauseVideo();else player.playVideo();}"
            + "function dSeek(d){if(!player||!player.getCurrentTime)return;player.seekTo(Math.max(0,player.getCurrentTime()+d),true);}"
            + "</script><script src='https://www.youtube.com/iframe_api'></script></body></html>";
    }

    private final class Bridge {
        @JavascriptInterface
        public void ready() {
            handler.post(() -> ready = true);
        }

        @JavascriptInterface
        public void error(int code) {
            // 2: bad id, 5: HTML5 error, 100: removed / private, 101 / 150: embedding off, 152 / 153: player config
            handler.post(() -> handOver("YouTube error " + code));
        }
    }

    /// the YouTube app takes over (embedding refused or broken)
    private void handOver(String why) {
        if (leaving)
            return;
        leaving = true;
        Log.i(TAG, "opening in YouTube instead: " + why);
        openInYouTube(this, videoId);
        finish();
    }

    private void js(String code) {
        if (web != null)
            web.evaluateJavascript(code, null);
    }

    private void showHint() {
        if (hint == null)
            return;
        hint.animate().cancel();
        hint.setAlpha(1f);
        handler.removeCallbacks(hideHint);
        handler.postDelayed(hideHint, HINT_MS);
    }

    private void volume(int direction) {
        AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        if (am != null)
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, AudioManager.FLAG_SHOW_UI);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        int k = e.getKeyCode();
        if (e.getAction() != KeyEvent.ACTION_DOWN)
            return k != KeyEvent.KEYCODE_VOLUME_UP && k != KeyEvent.KEYCODE_VOLUME_DOWN || super.dispatchKeyEvent(e);
        switch (k) {
            case KeyEvent.KEYCODE_BUTTON_A:
            case KeyEvent.KEYCODE_ENTER:
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_SPACE:
            case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                if (e.getRepeatCount() == 0) js("dToggle()");
                showHint();
                return true;
            case KeyEvent.KEYCODE_DPAD_LEFT:
            case KeyEvent.KEYCODE_MEDIA_REWIND:
                js("dSeek(-10)");
                showHint();
                return true;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
            case KeyEvent.KEYCODE_MEDIA_FAST_FORWARD:
                js("dSeek(10)");
                showHint();
                return true;
            case KeyEvent.KEYCODE_DPAD_UP:
                volume(AudioManager.ADJUST_RAISE);
                return true;
            case KeyEvent.KEYCODE_DPAD_DOWN:
                volume(AudioManager.ADJUST_LOWER);
                return true;
            case KeyEvent.KEYCODE_BUTTON_X:
                if (e.getRepeatCount() == 0) {
                    leaving = true;
                    openInYouTube(this, videoId);
                    finish();
                }
                return true;
            case KeyEvent.KEYCODE_BUTTON_B:
            case KeyEvent.KEYCODE_BACK:
            case KeyEvent.KEYCODE_ESCAPE:
                if (e.getRepeatCount() == 0) {
                    leaving = true;
                    finish();
                }
                return true;
            default:
                return super.dispatchKeyEvent(e);
        }
    }

    private void immersive() {
        View decor = getWindow().getDecorView();
        decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        if (Build.VERSION.SDK_INT >= 28)
            getWindow().getAttributes().layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus)
            immersive();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (web != null)
            web.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (web != null)
            web.onResume();
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        if (web != null) {
            web.loadUrl("about:blank");
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}
