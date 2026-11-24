# 09 — Overlays (performance overlay + in-game quick menu)

Honest constraints first: on stock Android, an app can draw over other apps (`SYSTEM_ALERT_WINDOW`) but **cannot** read another app's FPS, and many sysfs sensors are restricted. So everything is built in **capability tiers**, detected at runtime and shown in Settings → Performance:

| Tier | How | Unlocks |
|---|---|---|
| Normal | overlay permission | clock, battery %, charging, battery current/power (BatteryManager), RAM used, CPU per-core frequency (where `cpufreq` is readable), session time |
| Shizuku | user installs/starts Shizuku, grants DeckOS | shell-level reads: FPS via SurfaceFlinger stats (`dumpsys SurfaceFlinger` latency/timestats — research the most reliable method on Android 14/15), GPU busy/freq, thermal zones, CPU load |
| Root | su available (owner has had rooted devices) | everything above without Shizuku, plus vendor sensors |

Odin 3 / Retroid devices ship their own vendor performance overlays and fan/perf modes — don't fight them; ours is the Steam-styled one that also shows achievements/session info. Research whether vendor perf modes are controllable via intents/settings (log findings).

## Performance overlay (gamescope / MangoHud style)
- Levels like Steam Deck: **0** off · **1** FPS only · **2** horizontal bar (FPS, frametime, CPU %, GPU %, battery W) · **3** detailed vertical panel · **4** full (per-core freq, temps, RAM, frametime graph).
- Foreground service (`OverlayService`, notification required) with a `TYPE_APPLICATION_OVERLAY` view: non-focusable, non-touchable, position (4 corners), scale, opacity.
- Sample rate 2–4 Hz for text, 30 Hz for frametime graph only at level 4; must cost <1–2% CPU. Measure it.
- Per-game remembered level (optional), global default, toggle from Quick Menu.
- Native Android Views (Java) for the overlay — the Qt activity isn't foreground while a game runs. Style it to match DeckOS (same colors/fonts).

## In-game Quick Menu (Steam overlay style)
**Opening it** while an emulator is in front:
1. Primary: `QuickMenuAccessibilityService` with key-event filtering → configurable controller combo (default: hold **Select + Start** 0.5 s; alternative: a user-chosen button). Must pass every other key through untouched and add zero input latency. Note for users: on Android 13+ sideloaded apps need "Allow restricted settings" in App info before the accessibility toggle can be enabled — the wizard explains this.
2. Fallbacks: persistent notification action, Quick Settings tile, optional small edge handle.

**Panel** (slides in from the right like Steam's Quick Access; controller-navigable; takes focus only while open):
- Current game title, art, session time, today's playtime.
- RetroAchievements / Steam progress for this game + recently unlocked + next achievements.
- Performance overlay level slider, brightness/volume shortcuts (where allowed).
- **Return to DeckOS** (bring our activity to front), **Close game** (best effort: for RetroArch use its quit command/network command if enabled; otherwise explain; with Shizuku/root `am force-stop <pkg>` after a confirm).
- Screenshot (MediaProjection consent once per session; saved to `DeckOS/screenshots/<game>/` and shown in Media).
- Notes per game (quick text field), later.

## Safety
Never block or swallow input when the panel is closed. If the service crashes, the game must be unaffected. Provide a one-tap "Disable overlays" in DeckOS settings and in the notification.
