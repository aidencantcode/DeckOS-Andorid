# Changelog

One entry per build the owner tests. Newest first.

## Unreleased

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
