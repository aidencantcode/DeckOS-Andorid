# 02 — Roadmap

Work top to bottom. Each phase ends with an APK the owner tests. Tick boxes as you go (`[x]`). The owner's **current top priority** is Phase 2 (RetroAchievements tab) and Phase 3 (scraping) — get to them quickly, but Phases 0–1 must be solid first because everything sits on them.

> **2026-11-25 — personal-build track (owner decision, `DECISIONS.md`).** The app is now built on StMini + BigScreenFE's RA panel in a private repo, so Phase 1 ("build the shell from scratch") and the RA-tab part of Phase 2 are replaced by:
> - [x] StMini as the built-in default theme, scaled for 1080p (Odin 3) with a floor for near-square screens; QML warnings fixed.
> - [x] RetroAchievements tab on the game page (BigScreenFE panel), controller login, verified with the owner's account on PC.
> - [ ] Device check on the Odin 3 (0.0.2 checklist in `CHANGELOG.md`).
> - [ ] Artwork: SteamGridDB (owner's key available) for grids/heroes/logos, so StMini's tiles and hero areas fill in.
> - [ ] Retroid Pocket Classic layout pass; RA badge on tiles; credentials into an encrypted store.
>
> **2026-11-25 — "full merge" request** (owner: StMini v0.4, boot video, Pegasus settings inside the theme, profile, scraping, QoL; `NEXT_WORK_BRIEF.md` outside the repo has the request verbatim):
> - [x] StMini 0.4.22 as the base, our RA tab/fixes re-applied; responsive layout verified at 1920×1080 and 1240×1080; interface scale slider works. (0.0.3)
> - [x] Steam Deck boot animation replaces Pegasus's splash, black Android splash. (0.0.3)
> - [x] Pegasus menu gone for the built-in theme; every Pegasus setting in Settings (General / Library / Controller / System); Profile page; profile in the side menu + top bar. (0.0.3)
> - [x] Scraping: auto-scrape (Settings + game Properties) incl. **descriptions**; TheGamesDB + SteamGridDB + libretro thumbnails (ScreenScraper/IGDB need credentials we lack); edit a game's name and description in Properties. (0.0.4)
> - [x] Big libraries: cache-first starts that notice new/removed ROMs, quick **Refresh** + **Full rescan**. (0.0.5) Per-platform rescan comes with the ROM scanner.
> - [x] "Show Boot Animation" toggle wired to the boot video. (0.0.5)
> - [ ] Native (Steam-styled) key/gamepad editors.
> - [x] ROM folders without metadata: system detection by folder name, per-system generated metadata, per-system rescan, emulator catalog (NeoStation, GPL-3.0) with installed-emulator auto-pick and editable commands. (0.0.6)
> - [x] Per-game "Launch with…" and editable per-game command (0.0.8); first-start welcome card (0.0.7).
> - [ ] The remaining original QoL items below (Steam profile, overlays, RA hash matching, native key editors) — study `misobadev/neostation-frontend` for launch args, scraping and RA.
> The remaining phases (scraping, setup wizard, emulators, Steam, playtime, overlays) still apply on top of this theme.

---

## Stable Alpha — 0.1.0 (current phase)

The first build that is not a pre-release (`ship.ps1 -Phase 1` → `0.1.0`; `android.yml` publishes 0.1+ as a normal release). The goal is "daily-drivable": nothing stutters, nothing is half-wired, the in-game layer works on both handhelds. Work the milestones in order.

**2026-11-26 (owner's call):** 0.1.0 shipped as the first stable build, ahead of the full device checklist in F. The open items below continue as 0.1.1, 0.1.2…

**Research behind this plan (2026-11-25, details in `DECISIONS.md`):**
- **ClusterTune has no outside API.** No exported receiver, activity extras or service. Its Quick Settings tile is bound by the system only. "Talk to the app" isn't possible without changes on its side.
  - So DeckOS switches CPU/GPU limits itself, the way ClusterTune does: writing each CPU cluster's maximum frequency and the GPU's.
  - It uses ClusterTune's bundled presets (MIT, credited) for the Odin 3's Snapdragon 8 Elite (`CQ8725S`) and the 8 Gen 2 (`QCS8550`). Other chips get steps derived from their frequency tables.
  - **Custom** is the first profile of a ClusterTune export file (its Share/Export button), imported once.
- **PServer.** AYN and Retroid firmware ship a system service, `PServerBinder`, that runs a shell command with system rights. It needs no root, Shizuku or permission, and ClusterTune uses it. DeckOS uses it for everything that needs privileges:
  - writing frequencies and vendor modes;
  - toggling Wi-Fi and Bluetooth;
  - reading frame stats.
  - It's fire-and-forget. Output comes back through a file in DeckOS's private folder.
  - On devices without it, these controls are hidden or open Android settings.
- **Vendor modes are `Settings.System` values.** Any app can read them (DeckOS targets SDK 30); writing them goes through PServer.
  - `performance_mode`: 0 Standard, 1 Performance, 2 High Performance.
  - `fan_mode`: 0 Off, 1 Quiet, 4 Smart, 5 Sport, 6 Custom.
  - This is ClusterTune's mapping, observed on AYN devices. *Verify* on the Odin 3 and on the Retroid Pocket Classic with the new device-info dump.
  - For the "Maximum" fan, the custom-speed key is unknown until that dump.
- **FPS without Shizuku:** sample SurfaceFlinger's frame counter through PServer, once a second, only while the HUD shows FPS. This is a small, contained change, so Shizuku is dropped.
- **Pausing:** the Quick Access menu is an Activity, so the game gets `onPause`, and emulators pause on that. A "Keep game running" mode shows the same menu as an overlay window instead. The game stays resumed; only window focus moves.
- **Lag:** `theme.qml` has a single page `Loader` that destroys and rebuilds each screen on every navigation. Library is 3.3k lines of QML, the game page 3k. Rebuilding them is the "UI break" when going back from a game to the library, and part of the library-open hiccup.

### A — Fluid library (optimization first)
- [x] Keep Home and Library alive: hide and show them instead of rebuilding them, so going back restores focus and scroll position instantly (0.0.11; dropped when Settings opens). Android: DeckOS stays loaded while a game runs instead of tearing down and rebuilding the whole UI at every launch, which also gives real play time.
- [ ] Library open: show cached data at once. A first start, or a start with no cache, gets a Steam-style loading screen instead of a frozen UI.
- [ ] Find what blocks the UI thread on open: image decode, model sorting, bindings. Log timings with a `--deckos-timing` flag, and fix the biggest costs:
  - `sourceSize` and `asynchronous` on every grid image;
  - fewer delegates built off-screen;
  - no full-model `count` loops in bindings.
- [ ] Budget on PC: game page ↔ library under 100 ms (done: 1 ms, logged as "DeckOS: page N shown again"). On the Odin 3: no visible stall, checked by the owner.

### B — Game page
- [x] **Last played:** "Never" for games never launched. The StMini leftover showed "Just now" when there was no date. (0.0.11)
  - Next to it, PLAYTIME with "3 h 12 min" (or "Never") underneath, from Pegasus's playtime stats.
- [x] **RetroAchievements tab:** (0.0.11)
  - A Steam-style spinner instead of the Pegasus loading icon.
  - When logged out: no BigScreenFE login or keyboard. One "Log in to RetroAchievements" button opens Settings › Profile › RetroAchievements.
- [x] **Profile RA login:** "Checking…" with a spinner, then ✓ "Logged in as *name*" or ✕ "Login failed: *reason*" (wrong key / offline). The tab refreshes on success. (0.0.11)
- [x] **Activity tab:** (0.0.11; RetroArch screenshots only - other emulators keep theirs in private folders)
  - Recent screenshots: scraped ones, plus emulator screenshot folders (RetroArch, PPSSPP, DuckStation, AetherSX2-family; paths *verify*).
  - Recently earned achievements.
  - A list/grid toggle. The list looks like the overlay's achievement rows; the grid shows badges with dates.
- [x] **Launch cover:** the launch screen stays over the game while the emulator starts, then fades to the game, so its loading screens and pop-ups are never seen (Winlator's boot screen, splash screens). Settings › Overlay › Game launch: on/off and 2–20 s (default 5). Needs "Display over other apps" or the controller shortcut service. Any button ends it early when that service is on. (0.0.12, device check pending)
- [ ] **Trailer:** player done (0.0.11); scraping waits for ScreenScraper credentials.
  - After ~3 s on the game page, the hero background cross-fades into the game's video. The logo and buttons stay.
  - It stops on leaving or launching. Settings has *Play trailers* (off / muted / with sound) and the delay.
  - Plays any video the game already has (`assets.video`, `media/<game>/video.*`).
  - **Scraping videos needs ScreenScraper** (the only free source of game video snaps). That needs a ScreenScraper account from the owner and DeckOS developer credentials, so it's **blocked on the owner**. TheGamesDB only links YouTube, which Qt can't play, and fetching YouTube streams isn't allowed by its terms.
  - 2026-11-25: the owner's account arrived, but ScreenScraper refused its login, and every lookup also needs DeckOS developer credentials, which only ScreenScraper issues. Both are with the owner (DECISIONS 2026-11-25).

### C — Scraping
- [x] **Rescrape everything →** a picker: every collection with a checkbox and a count, plus *Everything*. Only the chosen collections are rescraped; the rest are left as they are. (0.0.11)

### D — In-game layer (Quick Access + HUD)
- [x] **Controller shortcut:** an accessibility service watches for a button combo and opens Quick Access over any app. (0.0.11, device check pending)
  - Choices: Select+Start, Select+R1, L3+R3. Default Select+R1.
  - Only the second button of the combo is swallowed.
  - The permission is asked for in Settings › In-Game.
- [x] **Keep game running:** an option under *Resume game*, also in settings. When on, Quick Access opens as an overlay window and the game isn't paused. (0.0.11, device check pending)
- [x] **Exit game** (Quick Access button + Y): confirmation, fade to black, `am force-stop` through PServer, then DeckOS on Home. (0.0.13, device check pending)
- [x] **Play time = time in the game:** the emulator package comes from the launch command; which app is in front comes from the accessibility service or a PServer poll. Away time is paused, and only in-game time is saved. (0.0.13, device check pending)
- [x] **Notification comes back** when swiped away (Android 14+); a blocked notification is shown in Settings › Overlay. Quick Access tabs scroll with the focus, without half-page jumps. (0.0.13)
- [x] **0.0.13 report fixes:** (0.0.14, device check pending)
  - DeckOS presets for chips without ClusterTune ones.
  - Quick Access: blank Wi-Fi / Bluetooth rows (toggle measuring), focus on open (touch mode) plus a visible outline.
  - The shortcut service is turned on through PServer.
  - Home highlight restored after returning.
  - Screenshots from TheGamesDB plus libretro, with a one-time pass for games scraped earlier.
- [x] **Overlay settings tab:** (0.0.11)
  - A new rail tab in Quick Access and the same page in DeckOS Settings › In-Game (renamed "Overlay"). Both read and write the same settings, so changing one shows in the other.
  - Contents: overlay scale, HUD level, HUD position, keep running, notification, shortcut, FPS.
- [x] **Overlay scale:** a slider (75–200%) that rescales the open panel live and smoothly. It also scales the HUD. The default is bigger than 0.0.10's, which the owner found too small. (0.0.11)
- [x] **Quick Settings:** (0.0.11, device check pending)
  - A brightness slider. It needs the "Modify system settings" permission, asked for once; DeckOS's own window adjusts meanwhile.
  - Wi-Fi and Bluetooth toggles that switch directly through PServer; elsewhere they open Android's panel.
  - **Wi-Fi drawer:**
    - Shows the connected network and nearby networks with signal, and rescans.
    - Picking a network: open networks and saved networks connect when the firmware allows (*verify*). A new network needing a password opens Android's Wi-Fi panel.
  - **Bluetooth drawer:** paired devices with their connected state. Connecting or pairing new devices opens Android's Bluetooth settings.
- [x] **Font:** the performance overlay uses Unispace Regular/Bold (CC0), supplied by the owner. Quick Access keeps the system font. (0.0.12)
- [x] **Play time from usage stats:** the exact app a launch opens, and which app is in front from Android's usage stats (access granted through PServer / root). (0.0.15)
- [x] **Running game, like Steam** (owner request; 0.1.0, device check pending):
  - PServer / root watches the game's process. Back in DeckOS while it runs, the session goes on; its page shows **Resume** and a blue **Stop** (with a confirmation), and Home says RUNNING. When the process ends, Play is green again.
  - Play time counts while the game runs, except with the screen off (Settings › Overlay; off = only while it's in front, the fallback without PServer / root).
  - Launching another game ends the running game's session first; library reloads wait for the session to end.
- [x] **0.0.15 report fixes:** Home's game row no longer scrolls onto empty space after Settings or a game page; a tap opens a tile directly; Select+Start works in either order; Quick Access's background can't take the focus (Android's grey focus tint). (0.1.0)
- [x] **DeckOS folder + own artwork** (owner request; 0.1.1, device check pending):
  - One folder picked or named at the first start, holding `media/<system>/<game>/` (readable names, `custom-*` for the user's own), `keys.txt` (read again whenever it changed) and `logs/`. Earlier media moves in.
  - Properties › Customization: Hero, Logo, Capsule, Wide capsule, Box art, Icon, Trailer and Screenshots, each with what's shown now and its source. Android's file manager, DeckOS's own browser, or remove.
  - Steam menu: always starts on a real button (pages past Settings left it on none).
- [x] **Your own collections + Android apps opened like the home screen** (owner request; 0.1.2, device check pending):
  - *Add to collection...* (game page ⚙ options, Library Ⓧ): tick or untick any collection, or name a new one. Kept in `<config>/deckos/collections.json`, added after the game's own collections (the first one stays its system), changed live without a library reload.
  - Apps open with the home screen's exact intent (MAIN + LAUNCHER, `NEW_TASK | RESET_TASK_IF_NEEDED`), so a running app comes back instead of getting a second copy on top; Resume uses it too.
- [ ] SteamGridDB picks (Change artwork…) are still web addresses in memory: download them into the DeckOS folder as the user's own files.
- [ ] Collections: rename or delete a whole collection (today: take every game out), and add several games at once from the Library.

### E — Performance tab: device profiles (AYN / Retroid)
Under the overlay level slider, each one is a 3–5 step slider like the overlay one, and the HUD shows what's active:
- [x] **Performance mode:** Standard / Performance / High Performance (vendor `performance_mode`). (0.0.11, values to confirm)
- [ ] **Fan:** Quiet / Smart / Sport / **Maximum**. Maximum switches the vendor fan to Custom and sets the highest speed. The key is confirmed from the device dump first.
- [x] **Underclock:** Stock / Small / Medium / Large / Custom. (0.0.11, device check pending)
  - ClusterTune presets for the chip; Custom is the first profile of an imported ClusterTune export.
  - Applied through PServer and restored to Stock when the game session ends, if *Reset after game* is on.
  - If ClusterTune is installed, a note says its own app profiles may override DeckOS's.
- [x] **ClusterTune built in → Settings › Underclocking** (owner request; 0.0.13, device check pending). Its core ported to C++ and Java (MIT, `docs/clustertune-port.md`):
  - The applied profile, live limits per cluster and GPU, ClusterTune's presets for the chip.
  - Your own profiles: new (from the live limits), duplicate, rename, reorder, delete. Each CPU cluster's and the GPU's maximum is stepped through the chip's own frequency table.
  - Import and export in ClusterTune's file format; *Restore ClusterTune presets*.
  - Re-applied after a restart (boot receiver), optional.
  - Quick Access's slider is Stock, the presets and the profile chosen as "Custom"; the HUD names the applied one.
  - Unit tests on a fake `/sys` tree; PC simulates a Snapdragon 8 Elite.
- [x] **FPS** on HUD levels 1–4 via PServer, plus the active profiles ("PERF High · FAN Smart · CPU Medium"). (0.0.11, device check pending)
- [x] **Device info dump** (Settings › Overlay › Device info): model, SoC, PServer yes/no, vendor `Settings.System` keys with fan/perf in their name, readable sensors. The owner copies it for us, which settles the *verify* items above. (0.0.11)

### F — Stable Alpha release
- [x] `android.yml`: 0.1+ tags publish as a normal release; 0.0.x stays pre-release.
- [ ] Full checklist on both handhelds (layout at 1080p and 1240×1080; controller-only; offline; first start).
- [x] CHANGELOG 0.1.0 with the test checklist (2026-11-26).

## Beyond 0.1.0 — guided roadmap
Proposed order. Each line becomes a milestone when its release starts. The owner can reorder.
- **0.2 — Your games, your stats:**
  - Per-game performance profiles: mode, fan and underclock remembered per game, applied at launch, restored after.
  - ClusterTune's remaining parts (`docs/clustertune-port.md`): Auto Tune (per-game frame rate target that lowers the ceilings it doesn't need), a sleep profile, switch history.
  - Session summary toast on return ("Played 42 min · 3 achievements").
  - A Quick Access **Screenshot** button (PServer `screencap`, saved per game; it feeds the Activity tab).
  - ~~Accurate play time from Android usage stats.~~ Done in 0.0.15 / 0.1.0.
  - A Home "Continue playing" card while a session is running.
- **0.3 — Achievements everywhere:**
  - Manual "Link RA game…".
  - RA badges on tiles (has set / mastered).
  - A Home "Recent achievements" shelf and an achievements hub (totals, rarest, "3 away from mastering").
  - CHD hashing (libchdr).
  - An unlock toast in Quick Access.
- **0.4 — Steam:** public Steam profile (Phase 5): library, play time, achievements in the same UI.
- **0.5 — Setup for anyone:**
  - First-run wizard (Phase 4): storage permission, ROM folders, emulator check.
  - A BIOS-missing warning per system.
  - *Test launch* with a launch log.
  - Native key/gamepad editors.
- **0.6 — Media:**
  - ScreenScraper (art, video snaps, manuals) once there's an account.
  - Video download queue with a Wi-Fi-only option.
  - Manual viewer.
  - Home attract mode.
- **0.7 — Polish:**
  - Backup/restore to a zip.
  - Low-battery toast in the overlay.
  - Auto battery-saver profile under 15%.
  - Localization plumbing.
  - Original icon and sounds.
  - In-app "What's new".

---

## Phase 0 — Foundation (no visible features yet)
- [x] Run `tools/bootstrap.sh` (or `.ps1`): clone upstream with submodules into `./deckos`, rename `origin` → `upstream`, create the owner's repo as `origin` (ask for its URL; until then work locally).
  - 2026-11-25: cloned at upstream `3702598c`, `upstream` remote set, DeckOS branch `main` created; `origin` = github.com/aidencantcode/DeckOS-Andorid (gh CLI auth, repo-local credential helper).
- [x] Build **unmodified** Pegasus on PC; run it; confirm a theme loads. Record exact toolchain in `DECISIONS.md`. (2026-11-25: Qt 5.15.2 MinGW 8.1, 191/191 tests, Pegasus Grid loads; `tools/check.ps1` gate = build + unit tests.)
- [x] Get the upstream Android workflow green in the owner's GitHub repo (it downloads the prebuilt Qt 5.15.10 Android toolchain). Produce an installable debug APK artifact. Add a stable debug keystore via repo secrets so new builds install over old ones.
  - 2026-11-25: first push green — upstream `android.yml` built both ABIs (debug APK artifacts), `ci.yml` qmake + CMake green. Stable test key generated, in repo secrets.
  - [x] Then switch to the DeckOS release flow (`13-release-flow.md`): `tools/check.ps1` gate, `tools/ship.ps1`, tag-triggered `android.yml` → GitHub pre-release with APK, Linux `ci.yml` for ordinary pushes; drop upstream's deploy/coverage jobs. (2026-11-25: **DeckOS 0.0.1** published as a pre-release, signed arm64 APK.)
  - [x] GitHub presentation: DeckOS README, docs index, Test report / Idea issue forms, upstream funding links removed (2026-11-25).
- [x] Rebrand identity: app name/label "DeckOS", applicationId `com.deckos.frontend`, new launcher icon + splash placeholders, window title, user-visible "Pegasus" strings → DeckOS. Keep copyright headers, LICENSE, and add About → Open-source licenses (Pegasus credit, Qt, SDL, every lib we add). Data dir names → `deckos`. (2026-11-25, verified on PC; device check with 0.0.1. Details in DECISIONS.)
- [x] Move `docs/` (incl. `DECISIONS.md`), `catalog/` and `CHANGELOG.md` into the repo; add `reference/` and `third_party_refs/` to `.gitignore`.
- [ ] Add `src/backend/deckos/` module skeleton + `deckos` QML context object (empty services) + `deckos.db` with migrations.
- [ ] Dev tooling: `--deckos-dev` flags (mock data, screenshot tour, fixture ROM dir), offscreen smoke test, qmllint step (see `03-dev-loop.md`). CI runs smoke test on Linux.
- **Exit:** APK named DeckOS installs next to Pegasus on Odin 3 and shows upstream UI working with a test ROM folder.

## Phase 1 — DeckOS shell (Steam-faithful UI skeleton)
Study `reference/stmini` (see `reference/REFERENCE_NOTES.md`) then build `src/themes/deckos` from scratch:
- [ ] `style/Theme.qml` singleton: palette, spacing, radii, `vpx()` resolution-independent units, screen class (wide 16:9 vs near-square ≈10:9), open fonts, button-glyph sets (Xbox / Nintendo / PlayStation, auto + override).
- [ ] Shared components: TopBar (clock, battery, Wi-Fi, avatar), MainMenu (slide-in left), FooterHints, Capsule (cover tile w/ focus scale+glow, badges), Shelf, TabBar (L1/R1), Dialog/ContextMenu, Toast system, OnScreenKeyboard (controller), Spinner/Skeletons.
- [ ] Focus/navigation system: one consistent approach (FocusScope tree + small NavigationController), memory of last focused item per screen, no "focusZone integer" spaghetti.
- [ ] Screens: Home (recent shelf over hero), Library (tabs: All, Favorites, Collections/Systems, Recent, Steam later), GamePage (hero, logo, Play, stats row: last played / playtime / achievements, tabs: Activity, Achievements (placeholder), Your Stuff (media), Game Info), Properties dialog shell, Media (screenshots), Search, Settings shell, Power menu.
- [ ] Sounds: original or CC0 navigation/accept/back/toast sounds (no Valve files). Volume + mute setting.
- [ ] Video previews on game page/home after focus delay; respect "Reduce motion / no video" setting.
- [ ] Screenshot tour covers every screen at 1920×1080 and 1240×1080.
- **Exit:** owner can browse and launch games from a Pegasus metadata setup entirely in the DeckOS UI on both handhelds.

## Phase 2 — RetroAchievements (spec: `06-retroachievements.md`)
- [ ] Account setup (username + Web API key) with test/verify, stored in secret store.
- [x] Integrate **rcheevos** `rc_hash` in C++; console mapping; hash cache keyed by path+size+mtime. (0.0.9; CHD and 7z not yet)
- [x] Per-console hash list download + cache; local hash → GameID; fuzzy title fallback flagged "Matched by title" (0.0.9).
- [ ] Manual "Link RA game…" search.
- [ ] Game page **Achievements** tab: summary card + full Steam-style list (unlocked/locked, hardcore/softcore, points, unlock dates, rarity %, sorting, filters).
- [ ] Capsule badges (has set / mastered), Home "Recent achievements" shelf, profile summary in Settings → Accounts.
- [ ] Return-from-game refresh + "unlocked N achievements" session toast.
- **Exit:** owner's real RA account shows correct progress for at least NES/SNES/GBA/PS1/PSP/PS2 games on device.

## Phase 3 — Scraping (spec: `07-scraping.md`)
- [ ] Provider plugin interface + SteamGridDB, libretro-thumbnails, RetroAchievements media, IGDB, ScreenScraper, TheGamesDB (order of implementation is fine to change).
- [ ] Two queues: **Fast** (art + metadata) and **Heavy** (videos, manuals, fanart), persistent/resumable, shown on the Downloads page.
- [ ] Library Settings → Scraper tab: full scrape, scope, only-missing/overwrite, per-slot source priority (SteamGridDB first by default), credentials, concurrency, Wi-Fi-only, storage usage/cleanup.
- [ ] Game Properties → Artwork: per-slot candidate picker (grid/poster, hero/background, logo, icon, box front, screenshot, video), source switch, custom search term, local file, reset.
- **Exit:** a 500-game library gets full art on device in a reasonable time, without UI stutter.

## Phase 4 — Library setup & emulators (specs: `04-library-and-scanning.md`, `05-emulators-and-launching.md`)
- [ ] First-run Setup Wizard (controller-only) + re-runnable from Settings.
- [ ] Storage permission flow (All files access preferred, SAF fallback).
- [ ] Scanner: system detection by folder aliases + extensions, multi-disc/m3u, cue/bin hiding, folder-games, BIOS exclusion, incremental rescans; writes Pegasus metadata.
- [ ] Emulator catalog loader + Android package detection + RetroArch core detection.
- [ ] Launch resolver: per-system default, per-game override, "Launch with…", custom command editor with placeholder palette, live preview, **Test launch**, launch log.
- [ ] Generic fallback for unknown emulators.
- [ ] Owner's emulator list entries added and verified on device.
- **Exit:** fresh install → wizard → games launch on Odin 3 without touching a config file.

## Phase 5 — Steam & playtime (spec: `08-steam-and-playtime.md`)
- [ ] Steam account link (SteamID64 / vanity / profile URL + user's Web API key), privacy check.
- [ ] Steam library collection with art, playtime, last played, achievements (same Achievements UI as RA).
- [ ] "Play via…" mapping to installed PC-on-Android launchers (GameHub/GameNative/Winlator-family) or "not installable here".
- [ ] Accurate local playtime via UsageStats; Steam-like stats on the game page.
- **Exit:** owner's public Steam profile shows correctly; ROM playtime accurate within a minute.

## Phase 6 — Overlays (spec: `09-overlays.md`)
- [ ] Capability detection (normal / Shizuku / root).
- [x] Performance overlay levels 0–4 (0.0.10; no FPS without Shizuku; needs a device check of which sensors are readable).
- [x] In-game Quick Menu overlay, opened from the in-game notification (0.0.10): Performance, RA achievements, music, quick settings; play time + battery time left.
- [ ] Open the Quick Menu with a controller combo (AccessibilityService) and a Quick Settings tile; real per-game profiles and AYN / Retroid performance modes.
- **Exit:** overlay works over at least RetroArch, an AetherSX2-family PS2 emulator and a Winlator-family launcher on Odin 3.

## Phase 7 — Polish & release
- [ ] Settings completeness pass (every Pegasus setting reachable; legacy menu removed).
- [ ] Backup/restore (settings, overrides, playtime, DB) to a zip.
- [ ] Performance pass (startup time, scrolling 1000+ games, image memory).
- [ ] Localization plumbing (English first).
- [ ] Original assets: icon, splash, sounds, system icons pass.
- [ ] Release signing, versioning, in-app "What's new".
- Ongoing: items from `12-qol-backlog.md`.
