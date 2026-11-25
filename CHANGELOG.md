# Changelog

One entry per build the owner tests. Newest first.

## Unreleased
**Launch cover and overlay font.** Two owner requests on top of 0.0.11:
- **Launch cover:** the launch screen now stays over the game while the emulator starts, then fades away to the running game. Emulator loading screens and pop-ups (Winlator's boot screen, splash screens) aren't seen any more. The Steam logo and spinner keep moving the whole time.
  - Settings › Overlay › Game launch: *Hide emulator loading screens* (on by default) and *Keep the launch screen for* 2, 3, 5, 8, 12 or 20 seconds (default 5).
  - It needs "Display over other apps" (the same permission as the performance overlay) or the controller shortcut's accessibility service. Without them, launching works as before.
  - With the controller shortcut service on, any button shows the game sooner.
  - If the launch fails, the cover goes away at once and DeckOS shows the error.
- **Performance overlay font:** Unispace, the font you sent, for every level of the performance overlay.

**Notes**
- Trailer scraping is still blocked: ScreenScraper refused the account login, and DeckOS also needs its own ScreenScraper developer credentials (see the release message).
- Nothing here has run on a handheld yet: the cover was checked on PC by saving its snapshot.

**Test checklist**
1. Settings › Overlay: "Allow drawing over games" shows ✓ (grant it if not). *Game launch* shows the two new rows.
2. Start a game from its page. The launch screen plays as before, then stays up while the emulator starts: the Steam logo keeps animating and the spinner keeps turning, with no jump when the game starts underneath.
3. After about 5 seconds it fades out to the running game, with no emulator loading screen seen. Try a Winlator game with 12 or 20 seconds.
4. With the controller shortcut turned on (Android accessibility), press any button while the cover is up: it fades out at once.
5. Start a game whose emulator isn't installed: the cover goes away straight away and the error shows.
6. Turn the cover off: launching is as in 0.0.11 (3 s on the launch screen, then the emulator's own loading).
7. Performance overlay levels 1–4 use the new font and nothing is cut off. Try the Retroid's near-square screen too.

## 0.0.11 — 2026-11-25
**Stable Alpha work.** This build makes the library fast, makes coming back from a game instant, and makes the in-game layer usable. Highlights:
- **Library:** Home and Library stay loaded behind the game page, so going back is instant and lands on the same game.
- **Leaving a game:** DeckOS stays loaded while you play, so you return to exactly where you were, and play time is real.
- **Game page:** Activity feed, trailers, and PLAY TIME next to LAST PLAYED.
- **RetroAchievements:** the sign-in page tells you whether it worked.
- **Quick Access:** can keep the game running, opens with a controller shortcut, can be resized, and has real quick settings.
- **AYN / Retroid:** performance mode, fan and underclock controls, plus a frame rate on the overlay.

### What changed
- **Faster navigation:** going back from a game page to the Library or Home no longer rebuilds them (1 ms instead of a full reload). Focus and scroll position are kept.
- **Back from a game:** on Android, DeckOS no longer unloads and reloads its whole interface at every launch.
  - You come back to the game page you left, at once, and the launch animation rewinds.
  - Play time is now counted until you're back in DeckOS. Before, every session was saved as ~0 seconds.
  - To turn this off: Settings → Overlay → *Keep DeckOS loaded while playing* (frees memory for the game).
- **Game page:**
  - Games you never played show "Never" instead of "Just now", on Home too.
  - PLAY TIME (hours and minutes) sits next to LAST PLAYED.
  - The Play button is narrower on the near-square screen so both fit.
- **Activity tab:**
  - Your recently unlocked achievements, newest first. **Y** switches between a list (like the in-game overlay's) and a grid of badges.
  - The game's screenshots, newest first: RetroArch's (named after the ROM, next to it or in its screenshots folder), then scraped ones.
- **Trailers:** after 3 seconds on a game page, its video fades in behind the logo.
  - Settings → General → *Trailers*: off / muted / with sound, plus the delay.
  - It plays videos the game already has (`media/<game>/video.mp4`). Scraping videos needs a ScreenScraper account (see notes).
- **RetroAchievements:**
  - The loading icon is a Steam-style spinner.
  - When you're logged out, the Achievements tab shows one **Log in to RetroAchievements** button. It opens DeckOS's sign-in page; the old BigScreenFE popup and keyboard are gone.
  - **Sign in** checks your account with RetroAchievements. You see a spinner, then "✓ Logged in as …" or why it failed (wrong key, unknown user, offline), and it returns where you came from.
- **Re-scrape…** (Settings → Library) lets you pick collections, or everything.
- **Quick Access menu (over games):**
  - **Keep game running:** the menu opens over the game without pausing it. It's in the menu's new **Overlay** tab and in Settings → **Overlay** (the renamed In-Game page); both show the same settings.
  - **Controller shortcut:** Select+R1 by default (or Select+Start, L3+R3) opens the menu over any game. Turn on *DeckOS controller shortcut* in Android's Accessibility settings first (Settings → Overlay has a button). It only watches controller buttons.
  - **Size:** the menu and the performance overlay can be 75–200%. The default is now 125%. The slider in the menu resizes it as you move it.
  - **Quick Settings:**
    - A brightness slider.
    - Wi-Fi and Bluetooth switches that work in place.
    - A Wi-Fi drawer listing nearby networks; open networks connect directly, and ones that need a password open Android's Wi-Fi panel.
    - A Bluetooth drawer listing paired devices.
  - **Performance tab, under the overlay slider:**
    - *Performance Mode* (Standard / Performance / High).
    - *Fan* (Quiet / Smart / Sport / Max).
    - *Underclock* (Stock / Small / Medium / Large / Custom), using ClusterTune's presets.
    - Custom is the first profile of a ClusterTune export you import in Settings → Overlay.
  - **Performance overlay:**
    - Shows the **frame rate** (FPS and frame time) on all levels.
    - Levels 3–4 also show the active mode, fan and underclock.
    - You can choose which corner it sits in.
- **Settings → Overlay → Device info:** lists model, chip, the AYN/Retroid system service, vendor settings and sensors, with a Copy button.

### Notes
- **AYN / Retroid controls** use the firmware's built-in command service (PServer), the same way ClusterTune does. ClusterTune itself can't be controlled by other apps, so DeckOS applies the same CPU limits directly.
  - The mode/fan values come from AYN devices and need confirming on yours (see checklist).
  - **Max** fan currently means the vendor's *Custom* fan mode. Making it full speed needs one more setting name from your Device info.
- **Trailer scraping:** the only free source of game videos is ScreenScraper, which needs an account (and developer credentials for DeckOS). Until then, trailers play only for games that already have a video file.
- **Untested on hardware:** this whole build is checked on PC and compiled by CI. The Android parts (overlay window, shortcut, PServer, Wi-Fi/Bluetooth) haven't run on a device yet.

### Test checklist (Odin 3 Max first, then the Retroid Pocket Classic)
1. **Library speed:**
   - Open the Library, open a game and press B: you're back on the same tile with no reload.
   - Do the same from Home.
2. **Play time:**
   - Launch a game, play for 2 minutes, then return to DeckOS (Home button, or Quick Access → Return to DeckOS).
   - You should land on the same game page. LAST PLAYED says "2 minutes ago" (it counts from the launch) and PLAY TIME says "2 min".
   - A game you never played says "Never".
3. **Sign-in:**
   - Settings → Profile → RetroAchievements → Sign in: a spinner, then "✓ Logged in as <you>", then back on Profile.
   - With a wrong key you get a clear error.
4. **Activity tab:** on a game with unlocked achievements, they show with dates. Press Y for grid view and again for the list.
5. **Device info first:** Settings → Overlay → **Device info** → *Copy to clipboard*, and send me the text from both handhelds. It tells me:
   - whether PServer is there;
   - the mode and fan setting names;
   - which sensors work.
6. **Controller shortcut:**
   - Settings → Overlay → *Turn on the controller shortcut*. In Android's Accessibility list, turn on **DeckOS controller shortcut**.
   - In a game, hold **Select** and press **R1**: the menu opens. Press the shortcut again (or B) to close it.
7. **Keep game running:** turn it on in the menu's Overlay tab, then open the menu during a game. The game keeps running behind it (watch the music or an animation); B returns.
8. **Size:** Overlay tab → *Menu and overlay size*. Moving the slider resizes the menu immediately. The performance overlay follows next time it's drawn.
9. **Quick Settings:**
   - The brightness slider changes the screen (the first time it may ask for "Modify system settings").
   - Wi-Fi and Bluetooth switches turn them off and on.
   - *Networks* lists nearby Wi-Fi; picking a password network opens Android's panel.
10. **Performance tab:**
    - Move *Performance Mode* and check the device's own quick setting changed too.
    - Do the same with *Fan*.
    - Set *Underclock* to Large: the overlay's CPU MHz should drop under load. Set it back to Stock.
11. **Frame rate:** overlay level 1 shows FPS in a game. If it shows "-", tell me (and include Device info).

## 0.0.10 — 2026-11-25
**The in-game layer: play time, a Steam-style overlay and a performance HUD.** While you play, DeckOS shows a notification with the game and a live play timer. Tap it for a Steam Deck-style Quick Access menu over the game, with performance info, your RetroAchievements and an overlay level slider. 0.0.9 never got an APK, so this build also carries all of 0.0.9 (ROM-hash achievements, the new keyboard, the boot and menu fixes); its checklist is below.

### Test checklist (Odin 3 Max first, then the Retroid Pocket Classic)
1. **Permissions:** start DeckOS. On Android 13+ it asks to allow notifications: say yes. Settings → **In-Game** → *Allow drawing over games* opens Android's "Display over other apps" screen: turn DeckOS on, go back, and the row shows ✓.
2. **Notification:** launch a game. Pull down the notification shade: "**<game name>** · Playing" with a timer counting up. Going to the home screen without a game shows "DeckOS · Tap for the quick access menu". Back in DeckOS, the notification disappears.
3. **Quick Access:** tap the notification during a game. A panel slides in from the right over the game:
   - It has a top bar (Wi-Fi, battery, clock, your picture) and a strip with the game, "Playing for…" and the battery time left.
   - The tabs are Notifications, ★ Achievements, Friends, Quick Settings, Performance, Music, Help and Keyboard. D-pad moves, L1/R1 switch tabs, B closes back into the game, and tapping beside the panel closes it too.
4. **Performance tab:** shows the battery % and projected time. Set **Performance Overlay Level** with the D-pad to 1, 2, 3 and 4; each draws a different overlay in the game's top-left corner:
   - 1: battery and play time.
   - 2: one bar.
   - 3: the detailed block.
   - 4: every CPU core and a load graph.

   Tell me which numbers show "-" on each device: CPU %, CPU/GPU temperature, GPU %, fan. Android hides some of them from apps, and I'll look for other places to read them. *Advanced View* shows the same values as rows. *Use per-game profile* and *Performance mode* are switches only for now.
5. **Achievements tab:** with a game RA knows (signed in to RA in DeckOS), it shows the game, "You've unlocked X/Y", and rows like Steam's list: a check, the badge, the name and description, and the % of players who have it. Unlock something in RetroArch, open the overlay again (or press *Refresh*), and it appears under **Unlocked this session**.
6. **Music tab:** Play/Pause, Previous and Next control whatever is playing. **Quick Settings** opens Android's Wi-Fi, Bluetooth, volume and display panels. **Return to DeckOS** (Notifications or Help tab) brings DeckOS back.
7. Everything from 0.0.9 below.

### Under the hood
- Java `com.deckos.ingame`:
  - `Session`: what's playing, the settings and lifecycle hooks.
  - `SessionService`: a foreground service with a chronometer notification, stats once a second and the HUD window.
  - `QuickAccessActivity`: translucent, in its own task.
  - `HudView`, `Stats`, `RaClient`, `LevelSlider`, `Ui`.
- C++ `deckos.ingame` (`InGame`): it hands the game, RA account and profile to Java at every launch (connected before the launcher), then the RA game id once `RaMatcher` finds the ROM's hash.
- Fixed 0.0.9's failed builds: zipped ROMs are read with miniz (MIT, vendored), because Qt's `QZipReader` is compiled out of the Android and Linux Qt; `PAGE_SIZE` is a macro on Android.
- New permissions: notifications, foreground service, display over other apps. The overlay's icons are based on Material Design icons (Apache 2.0) and are credited in the licenses screen.

## 0.0.9 — 2026-11-25
> **Not published:** the Android build failed (Qt's zip reader is missing from the Android Qt). Everything below ships in the next build.

**Achievements found by ROM, a real keyboard, and fixes.** The Achievements tab now identifies a game by its ROM's hash, the same check RetroArch does, instead of guessing from the title. Every text box uses the big Steam-style keyboard with a Paste key. The boot animation plays to the end, and pressing MENU quickly no longer breaks the side menu.

### Test checklist
1. **Boot:** start DeckOS. The whole Steam Deck animation plays (about 4.5 s) and the logo fades into Home. It shouldn't vanish after a second. Any button still skips it.
2. **Side menu:** press MENU twice quickly, a few times in a row. The menu ends up open or closed, never half-open or invisible, and the D-pad always moves inside it when it's open.
3. **Achievements:** open a game you have RA progress for → Achievements tab. Next to the console name you'll see one of two labels:
   - **✓ ROM verified** (green): RA knows this exact dump.
   - **Matched by title**, with an orange note: your file isn't a dump RA knows, so the emulator may not unlock achievements for it.

   Try a zipped ROM, a `.cue`/`.iso` disc game and a `.chd`. CHD and `.7z` can't be hashed yet and fall back to the title match. The first game of each console downloads RA's list for it, so it takes a moment; later games are instant.
4. **Keyboard:** Settings → Library → SteamGridDB/TheGamesDB key, Settings → Profile → Name, a game's Properties → Details → Name/Description/Launch command, and the game page's RetroAchievements login all open the same full-width keyboard.
   - The **Paste** key pastes the clipboard (copy your API key in a browser first).
   - Controller: X deletes, Y types a space, L1 toggles caps, B/R1/Start finish.
   - **Clear** empties the field; **< >** move the cursor; **Shift** gives symbols (!@#…).
   - On the Retroid (1240×1080) every key label should be readable.

### Under the hood
- `src/backend/deckos/RaMatcher.*` exposed as `deckos.ra`:
  - Hashes the ROM with rcheevos (v12.5.0, MIT, vendored in `thirdparty/rcheevos`, hashing part only) on a worker thread.
  - Zipped cartridge ROMs are hashed by the game inside the zip.
  - Hashes are cached by path + size + date.
  - Lookups use RA's per-console hash list (`API_GetGameList` with `f=1&h=1`, paged), cached for 7 days and fetched again after a day when a hash isn't in it, at most once per console per run.
  - 7 new unit tests.
- Boot layer: hidden by its own `shown` flag instead of keyboard focus. The theme grabbing focus while loading used to fade it out early. The video now stays during the fade.
- Side menu: the close animation's hide timer no longer hides a menu that was reopened meanwhile; the menu also takes focus back from the page's focus timer after a quick reopen.
- Text entry: `SteamKeyboard.qml` replaces the small BigScreenFE keyboard everywhere. StMini's own controller table typed a space on Paste; every key's action now comes from the key itself.

## 0.0.8 — 2026-11-25
**Launch with… for single games.** A game's Properties → Details now has a *Launch* section: pick another emulator for just that game, or view and edit its full launch command.

### Test checklist
1. A game → gear → Properties → Details → **Launch with…**: the emulators for its system (installed first). Pick one → that game starts with it; the rest of the system keeps its emulator.
2. **Launch command** shows the exact `am start …` command; edit it (keyboard, Y pastes) → saved for this game. Clear it (X) and save → back to the system's command. *The system's emulator* in Launch with… does the same.
3. *Undo all DeckOS changes* also resets the launch command.

### Under the hood
- Per-game `launch` in the DeckOS game changes (applied over the system's command on every load, original kept for undo); `deckos.gameLaunchCommand/setGameLaunchCommand/gameEmulators/setGameEmulator`.
- Fixed: the Details page read its game before the theme handed it over (flags like "Edited" could show stale values).

## 0.0.7 — 2026-11-25
**A first-start welcome.** On a fresh install (no ROM folder, no metadata folder) Home shows a "Welcome to DeckOS" card: A goes straight to Settings → Library to add your ROM folder, B hides it for good.

### Test checklist
1. Only on a fresh install (or after clearing DeckOS's data): the card appears over Home; A opens Settings → Library; B closes it and Home works normally. Your existing setup won't show it.

### Under the hood
- Empty-library start verified (no warnings); the page under the card is disabled so its buttons can't be pressed by accident.

## 0.0.6 — 2026-11-25
**Just pick your ROM folder.** DeckOS finds your systems by folder name (snes, gba, psx, "PlayStation 2"…), lists the games, and picks an installed emulator for each system — no metadata files needed. Every launch command is visible and editable.

### Test checklist (Odin 3 Max first)
1. Settings → Library → **Add a ROM folder…** → browse to the folder that *contains* your system folders (e.g. `/storage/emulated/0/ROMs`) → **Use this folder**. A scan starts; the row under it shows "N games in M systems", and the library reloads with them.
2. Home / Library: the new games appear with clean names ("Chrono Trigger", not "Chrono Trigger (USA)"); multi-disc games with an `.m3u` show once.
3. **Play** a game from each system you have. Tell me which ones don't start (and which emulator it tried — Settings → Emulators shows it).
4. Settings → **Emulators**: each system shows its emulator. Open one: installed emulators are listed first; pick another → launches use it at once. *Edit launch command…* shows the full `am start` command; *Use the emulator's own command* undoes edits.
5. Copy a new ROM into a system folder → restart DeckOS (or Library → *Scan ROM folders*) → it appears. Library → **Rescan one system…** re-reads just that system.
6. If you also still have old Pegasus metadata folders, they now sit under "Metadata folders"; games listed in both appear once.
7. Settings → System → Open-source licenses: NeoStation is credited.

### Under the hood
- Catalog: 117 systems / ~1500 Android emulator entries converted from NeoStation's GPL-3.0 catalog (`tools/import-neostation-catalog.ps1` → `src/backend/deckos/catalog/systems.json`); RetroArch core names expanded to `/data/data/<package>/cores/<core>_libretro_android.so`.
- `deckos.library` (RomLibrary): background scan, `.m3u`/`.cue`/`.gdi` parts hidden, artwork/BIOS/save folders skipped; one generated `deckos/library/<system>.metadata.pegasus.txt` per system, rewritten only when it changed (so the game index cache stays valid); installed emulators read from Android's app list.
- Settings: ROM folders + scan + rescan one system on the Library page; new Emulators page.
- Fixed: RA profile name/picture never loaded in StMini's profile code (unqualified writes in a callback); the theme logged a network check every 15 s.
- 8 new unit tests (catalog aliases, core paths, scanning, playlists, titles).

## 0.0.5 — 2026-11-25
**Faster starts and a quick Refresh.** DeckOS now starts from the saved game list and only does a full scan when a game folder actually changed.

### Test checklist
1. Settings → Library → turn **Full scan on every start** off (new installs have it off already). Restart: the boot animation ends and Home appears without the long scan on a big library.
2. Copy a new ROM into one of your game folders (on the PC or with a file manager), then Settings → Library → **Refresh library**: the new game shows up. Delete it again → Refresh → it's gone.
3. **Full rescan** still reads everything (for when something looks wrong).
4. Settings → Customization → **Show Boot Animation** off → restart: no animation, straight to Home after loading.
5. The SteamGridDB key is shared: set it once (Library page or Customization page) and both the scraper and "Change artwork…" use it.

### Under the hood
- Game index cache fingerprint now includes the game folders and their direct subfolders (folder modification times change when files are added or removed); "Scan for games on launch" defaults to off.
- `deckos.refreshLibrary()`: cache-aware reload (Pegasus's reload always forced a full scan).

## 0.0.4 — 2026-11-25
**Scraping: artwork, descriptions and game info for your whole library — plus rename a game and edit its description.**

### Before you test: your keys
Copy the `api-keys.env` file from the PC (`DECKOS\secrets\`) into the **`deckos` folder in the handheld's internal storage** (the folder with `lastrun.log`). Then Settings → Library → **Load keys from a file**. It loads the SteamGridDB and TheGamesDB keys and your RetroAchievements account in one go. (Or type/paste them under Settings → Library.)

### Test checklist (Odin 3 Max first)
1. **Load keys** as above → it should say "4 keys loaded (RetroAchievements account too)".
2. Settings → Library → **Scrape games with missing artwork or info**. The row shows "3 / 40" style progress and what it is doing; you can keep using DeckOS meanwhile. Home tiles, game pages (hero + logo) and Game Info fill in as each game finishes.
3. **Game Info** tab: description, release date, developer, publisher, genre.
4. A game → gear button → **Properties** (works with A now) → **Details**:
   - *Name*: rename it with the keyboard → the new name shows everywhere at once.
   - *Description*: edit or clear (X) → shows on the game page.
   - *Scrape this game*: re-fetches everything for just this game.
   - *Undo all DeckOS changes* (press A twice): back to the original name/description/art.
5. Turn on **Auto-scrape new games**: after adding a ROM folder and reloading, new games get artwork by themselves.
6. Restart DeckOS: names, descriptions and artwork are still there; nothing is scraped twice.
7. TheGamesDB allows ~1000 lookups a month per key — the TheGamesDB key row shows how many are left.

### Under the hood
- New DeckOS backend (`src/backend/deckos/`): the `deckos` QML object, a per-game changes store (`<deckos folder>/deckos/game_overrides.json`) applied on every library load by a new provider, and the scraper (TheGamesDB → SteamGridDB → libretro thumbnails; one game at a time; downloads to `deckos/media/`).
- Game titles, descriptions, dates and artwork can now change while DeckOS runs (they were fixed after loading in Pegasus).
- Fixed in StMini: Properties did nothing when chosen with a controller; a broken battery icon path in the artwork picker.
- 7 new unit tests (199 total).

## 0.0.3 — 2026-11-25
**StMini 0.4, the Steam Deck boot animation, and no more Pegasus screens.** The whole interface is now StMini 0.4 (much bigger: new Settings, game properties, SteamGridDB artwork picker), every Pegasus setting lives in its Settings screen, and the app starts with the Deck boot animation.

### Test checklist (Odin 3 Max first, then Retroid)
1. **Update in place** over 0.0.2. Settings, RA login and play time should survive.
2. **Boot.** Black screen, then the Steam Deck boot animation with its sound, then a fade into Home. No Pegasus logo or grey screen anywhere. Any button skips the animation. If the animation never shows (just black, then Home), say so.
3. **Home / Library / game page** look like 0.0.2 but StMini 0.4: check the top bar, the Recent games row, the Library tabs and the game page.
4. **Achievements** tab on a game page works as in 0.0.2 (Down from the tab into the badges). Already connected? It should still be connected.
5. **Side menu** (Start opens the STEAM menu): your profile is at the top ("Player" until you set a name). Settings is in this menu.
6. **Settings**: General, *Library* (new), *Profile* (new), Accessibility, Sound, Power, High Contrast, Customization, Controller, System.
   - *Library*: your game folders are listed. "Add a game folder…" opens a folder browser (A opens, B goes back, "Use this folder" adds it), then "Reload games now". Data sources and scan options are here too. On Android, "Allow access to a folder…" asks Android for SD-card access.
   - *Profile*: set a name (controller keyboard) and a picture (pick an image file). Both show up in the side menu and the top-right avatar.
   - *General*: language, clock format, mouse/touch, when DeckOS hides after launching a game.
   - *Accessibility* → interface scale slider now really makes everything bigger/smaller.
   - *Controller*: shows your controller's name; "Test and remap buttons" and "Button shortcuts" open the (still Pegasus-styled) editors.
   - *System*: version 0.0.3, log file path, theme switcher, open-source licenses.
7. **Start/B never open the old grey Pegasus menu** any more.
8. **Exit**: side menu → Close → Exit really closes DeckOS now.
9. **Retroid Pocket Classic**: StMini 0.4 adapts to the near-square screen; check Home, a game page and Settings for cut-off text.

### Under the hood
- Theme rebased on StMini 0.4.22 (only the assets it uses: 5.6 MB instead of 25 MB); our RetroAchievements tab, scaling and fixes re-applied; dozens of StMini warnings fixed (wrong scopes, enum/anchor mix-ups, old Connections syntax, a missing "Local Files" page).
- Pegasus splash → `BootLayer.qml` (1080p re-encode of the boot clip, 178 KB); Android splash/window background black.
- Settings: new shared row component and controller folder browser; Pegasus settings wired directly to the app's settings API.
- Backend: theme settings storage no longer re-notifies on unchanged values and notifies asynchronously (fixes StMini's binding loops); folder model usable from QML pickers. New unit test for the storage change.
- `tools/drive-window.ps1`: the screenshot/key driver used for PC tours, now in the repo.

## 0.0.2 — 2026-11-25
**The Steam Deck look arrives.** DeckOS now starts in the StMini Steam Deck interface (Home, Library, side menu, game pages with the green Play button, Deck sounds), sized for the Odin's 1080p screen, with **RetroAchievements on every game page**.

### Test checklist (Odin 3 Max first)
1. **Update in place.** Install over 0.0.1 - Android should offer "Update", not a fresh install.
2. **Home.** Opens in the Steam Deck look: top bar (search, clock, battery), "Recent games" row, button hints at the bottom. Navigating plays the Deck sounds.
3. **Menus.** **L2** opens the STEAM side menu (Home and Library work; the others are StMini placeholders). **Start** still opens the system menu (settings, game folders, quit).
4. **Library.** All Games grid; L1/R1 switch tabs.
5. **Game page.** A on a game: hero area, green Play, tabs. Play launches the game as before.
6. **Achievements.** On a game page: Down to the tabs, Right twice to **ACHIEVEMENTS**. First time: Down → *Connect account* → A → enter your RA username and Web API key (controller keyboard, or tap the field for Android's keyboard) → it should say "Connected as …".
7. Then a game you've played with RetroAchievements shows "You've unlocked N/M", your earned badges and the locked ones. Down from the tabs moves into the badges, Left/Right moves through them, B goes back.
8. **Artwork.** Tiles are grey unless your ROM folders already have Pegasus/Steam-style media - artwork downloading is the next big item.
9. **Retroid Pocket Classic** (optional): usable, but a few top-bar icons may sit in odd places on the near-square screen.

### Under the hood
- Built-in DeckOS theme = StMini 0.3.1 (ScriptUT) + BigScreenFE 1.1's RetroAchievements panel (Gonzalo Abbate), scaled for 1080p; private personal build (see `src/themes/deckos/CREDITS.md`).
- Fixed in the imported code: achievements never finishing loading, missing battery icon on Android, double page loads, several broken layout bindings.
- Fixed a rare crash when DeckOS closes right after saving a game session's play time (upstream Pegasus bug; also made a unit test crash on Linux CI).
- Windows test build: HTTPS works (OpenSSL 1.1.1), test library uses real game titles; `tools/build.ps1` regenerates Makefiles when `.qrc`/`.pro` files change.

## 0.0.1 — 2026-11-25
**First installable DeckOS build.** Underneath it is still the stock Pegasus interface: this build proves that the DeckOS app, its install/update path and the build pipeline work on real hardware. The Steam-style DeckOS interface starts in Phase 1.

### Test checklist (Odin 3 Max and Retroid Pocket Classic)
1. **Install.** The app appears as **DeckOS** with a dark placeholder "D" icon. If Pegasus is installed, both stay installed side by side.
2. **First launch.** You may see a dark screen with the "D" for a moment, then the interface. Allow storage access ("All files access") if Android asks.
3. **Library.** Your installed Android apps show up as a collection. Optional: Start → Settings → *Set game directories…* → add a ROM folder that already has a `metadata.pegasus.txt` (from a Pegasus setup); those games should appear and launch.
4. **About.** Start → Help: "DeckOS, version 0.0.1"; scrolling down, Licenses credits Pegasus Frontend and the other libraries.
5. **Controller only.** Everything above works with the D-pad and buttons; Start opens the menu, B goes back.
6. **Quit.** Start → Quit → Exit DeckOS closes the app.
7. **Files.** A `deckos` folder now exists in internal storage; `deckos/lastrun.log` inside it is the log to attach to bug reports.
8. Android may offer DeckOS as a **Home app** - keep your usual launcher for now.

Report anything odd (layout on the near-square Retroid screen included) with a **Test report** issue.

### Under the hood
- Rebrand: app ID `com.deckos.frontend`, app name, window title, placeholder icon / TV banner / splash, data folder `deckos`, version numbers from DeckOS tags; Help → About credits Pegasus Frontend, Help → Licenses lists every bundled library.
- Release flow: `tools/ship.ps1` + the DeckOS Android workflow - every test build is an arm64 APK on the Releases page, signed with one stable key so it installs over the previous build.
- Windows test build in `windows-build\` (`DeckOS.exe`), refreshed every time a build passes the test gate (`tools/check.ps1`: build + 191 unit tests).
- Windows dev toolchain (Qt 5.15.2 MinGW, SDL2 2.32.10) and scripts; Linux CI on GitHub; README, docs and issue forms.
- Phase 0 setup: Pegasus cloned (DeckOS on branch `main`, `master` mirrors upstream), docs/catalog/changelog in the repo, bootstrap script fixed for Windows PowerShell 5.1.
