# Changelog

One entry per build the owner tests. Newest first.

## Unreleased
**One game at a time, no more stuck performance overlay, a much faster Library, and navigation fixes.**
- **Stuck performance overlay fixed.** When a game crashed or was closed in the emulator, DeckOS could draw one last overlay just as its overlay service stopped. That copy froze on screen, and every new game drew another on top. Now only one overlay can exist, and it goes as soon as the game's app ends or DeckOS is back.
- **One game at a time.** Pressing Play while another game still runs behind DeckOS asks first: *Close game and play*, *Resume <game>* or *Cancel*. Closing shows a loading bar until Android confirms the game has really ended, then starts the new one. The game page's **Stop** uses the same bar. Every Play (Home, Library, Search, the game page, games with several files) goes through this.
- **Faster "stopped" detection.** A game now counts as running only while its app still has a screen open, not just a leftover process. Emulators closed from their own menu used to look "running" for minutes. While DeckOS is in front, the check runs every 0.7 s, and immediately when you come back or press Play / Resume. **Resume checks first:** if the game was closed meanwhile, Play just starts it again instead of opening the emulator's own menu.
- **Library scrolls smoothly.**
  - Covers are now small thumbnails, made once in the background and kept on disk and in memory. Every tile used to decode the full-size picture on the interface thread.
  - The whole library's thumbnails are made ahead the first time, with a thin progress bar at the bottom: *Preparing artwork 120 / 4000*. While tiles load, the bar shows *Loading artwork…*.
  - Same for Home's row and Search.
- **Lighter frosted bars.** The blurred top and bottom bars re-rendered the whole page at full resolution every frame. They now use a third of the resolution, which looks the same.
- **Home tabs:** LB / RB now switch What's New / Friends / Recommended from the tab row too (they only worked inside a tab before), and quick presses no longer get lost mid-animation.
- **Change artwork / Choose artwork by hand: B works.** B goes back where you came from (the game page, Properties, Home, Library, Search). After one use it used to lead nowhere, and you had to leave through the Steam menu.
- **Quick Access (in-game menu):**
  - It always opens on **Performance**.
  - RIGHT from the tab icons goes to the tab's first option, not whichever was level with the icon.
  - UP / DOWN stay in their column instead of slipping to the icons or the Exit button.
  - After changing the performance mode, the focus stays on that slider instead of jumping to the icons.

### Test checklist
1. **Overlay:** turn the performance overlay on (level 1 or more), start a game, then close it **from the emulator's own menu** (not Quick Access). The overlay must be gone on DeckOS. Start another game: exactly one overlay. Try again by swiping the emulator away in Android's recent apps.
2. **One game at a time:** start a game, press Home to go back to DeckOS, open **another** game and press Play. The *A game is still running* card appears. Pick *Close game and play*: a blue bar, then the new game starts. Try *Resume* and *Cancel* too.
3. **Closed in the emulator:** start a game, close it from the emulator's menu, then quickly press Play on its page in DeckOS. It should start fresh, not show the emulator's own menu. Its page should switch from Resume/Stop to Play within about a second.
4. **Library:** open the Library and scroll down fast with the D-pad. The first time, the bottom bar shows *Preparing artwork…*. After that, scrolling should stay smooth.
5. **Change artwork:** from Home (X › Change artwork…) and from Properties › *Choose artwork by hand…*, press B. You're back where you came from. Do it twice.
6. **Quick Access:** open it in a game. It's on Performance; RIGHT goes to the first slider; change the performance mode, and the focus stays on it.
7. **Home tabs:** go down to the WHAT'S NEW / FRIENDS / RECOMMENDED row and press LB / RB.

## 0.1.5 — 2026-11-27
**Artwork that always loads, scraped data that doesn't go missing, and a game page that opens at once.**
- **Game page opens instantly.** It used to be built from scratch every time (about half a second on PC, more on a handheld). Now it is built once in the background shortly after DeckOS starts and kept, like Home and Library. Opening another game starts at the top; coming back from Properties returns to where you were.
- **A record for every game (`game.txt`)** next to its artwork in `<DeckOS folder>/media/<system>/<game>/`: its scraped and edited info and its artwork file names, in Pegasus-style text. It is rewritten whenever the game's artwork or info changes. When a game has no saved changes, DeckOS reads its record back on the next load and brings everything back. That covers a ROM folder reached by another path (`/sdcard/…` vs `/storage/emulated/0/…`), a folder added again, a renamed SD card, or DeckOS's own list (`game_overrides.json`) being lost. Existing scraped games get their records written once, on the first start of this version.
- **Artwork from a scrape or edit that finished while the library was reloading** used to show only after a restart: it reached the old copies of the games. It is now applied to the reloaded library, and scrapes still in the queue continue on the new copies.
- **SteamGridDB picks are saved as files.** Pictures picked on the SteamGridDB page were kept as web addresses and downloaded again on every page, so they were slow, missing offline, and only updated after a restart. Each pick is now downloaded once and becomes the game's own picture (Properties › Customization shows it as yours). Picks made before this version are converted after the next library load.

### Test checklist
1. **Game page:** open a few games from Home and the Library. Each should open at once, at the top, on its own artwork. Open Properties (X) and press B: you're back on the game page where you were.
2. **SteamGridDB pick:** Properties › Customization › SteamGridDB, pick a new capsule or hero. It should show right away in Home and the Library, also with Wi-Fi off afterwards, and after restarting DeckOS.
3. **Records:** in your DeckOS folder, `media/<system>/<game>/game.txt` exists for scraped games.
4. **Scrape during a scan:** start "Scrape missing artwork", then *Scan ROM folders* while it runs. After the reload, the newly scraped games show their artwork without a restart.

## 0.1.4 — 2026-11-27
**RetroArch uses your own setup again, a proper loading screen for ROM scans, and collection options and icons.**
- **RetroArch starts with your own config:** shaders, hotkeys, controller binds, everything you set up in RetroArch. DeckOS's RetroArch commands didn't say which config to use, so RetroArch opened with a blank default one. Every RetroArch launch now passes RetroArch's own `retroarch.cfg`, including games whose command was saved earlier ("Launch with…", a system's own command, your metadata files).
- **Loading screen for ROM scans and library reloads:** adding a ROM folder (or *Scan ROM folders*, *Rescan one system*, *Refresh library*, *Full rescan*) darkens the screen and shows a progress bar, how many games were found so far, the system being read, and tips (with the StMini, BigScreenFE and Pegasus credits). The same screen stays up while the library reloads and the interface is rebuilt, instead of a black screen. **B cancels a scan**; nothing changes then. The quick check after start-up still runs quietly with its top-left card.
- **Collection options:** press **X on a collection** in the Library's Collections tab: *Scrape missing artwork*, *Re-scrape this collection* (follows the skip setting in Settings › Scraping), *Rename…*, *Properties…*, *Hide from Library*.
- **Collection icons** (*Properties…*): **Dynamic** is StMini's collage of the games' covers; **Custom** is a picture of your own:
  - **Find on SteamGridDB…** searches for the collection's name, or anything else with Y: console, launcher and game **icons**, **square grids** and **logos**. LB/RB switch the kind, and A picks.
  - **Choose a picture from storage…** takes a PNG, JPG or WebP.
  - *Show the whole picture* fits icons and logos with the name under them, or fills the tile.
  - Switching back to Dynamic keeps your picture for later. Renaming a collection keeps its icon.
- **Home:** the background crossfade is smooth both ways. The new picture used to pop in at full strength after the old one faded out; now it fades in. The old one also starts fading from exactly where it was.
- **Getting ready for the emulator overhaul:**
  - PS4 and PS5 are recognised systems: folders `ps4`, `PlayStation 4`, `ps5`…
  - Folder games are found: PS3 (`PS3_GAME/USRDIR/EBOOT.BIN`), PS4/PS5 (`eboot.bin`), Xbox (`default.xbe`), Xbox 360 (`default.xex`). Each counts as one game named after its folder.
  - Their emulators come next.

### Test checklist
1. **RetroArch:** start a game that runs in RetroArch. Your shaders, hotkeys (menu toggle, save states) and controller binds should all be there. `logs/lastrun.log` shows the command with `CONFIGFILE`.
2. **Loading screen:** Settings › Library › *Add a ROM folder…* and pick your ROMs folder. A dark screen with a bar, a game count and tips should stay up until the Library is back. There should be no black screen and no freeze. Try B during a scan: it says *Cancelling…* and your library stays as it was.
3. **Collection options:** Library › Collections, X on a collection. Try Rename… (the new name shows at once) and Scrape missing artwork (the progress card appears top-left).
4. **Collection icon:** X › Properties… › Find on SteamGridDB… and pick an icon. The tile in the Library changes. Switch *Icon* back to Dynamic: the collage returns. Then try *Choose a picture from storage…*.
5. **Home:** move left and right through the games. The background should fade from one picture to the next with no sudden cut.

## 0.1.3 — 2026-11-26
**Notifications, a cleaner Settings, collections you can manage, and controller fixes.**
- **Steam-style notifications** in the top-left corner, over every page: a card with an icon, a title, a line of text and a progress bar. Scraping shows its progress there (game name, *3 of 40*) and then *Scraping finished*; a ROM folder scan shows there too. Achievements and other notices can use the same cards later.
- **Re-scrape… → *Skip games that already have artwork*** (on by default): only games without a cover, hero, logo or wide capsule are scraped again, so re-scraping a collection doesn't redo the games that are fine. Turn it off to redo everything you pick.
- **Settings, rearranged:**
  - New **Scraping** tab: auto-scrape, scrape missing, Re-scrape…, sources, the SteamGridDB and TheGamesDB keys, load keys from a file. Settings › Library keeps a *Scraping…* shortcut.
  - New **Collections** tab: every collection, with *Show in the Library* (hide one; its games stay in your library), *Rename…* (kept through rescans; the system is still recognised) and, for a ROM folder system, *Games folder…* to point it at another folder (*Use the folders found by name* undoes it). Android apps aren't a folder, so they only get hide and rename.
  - **Power** tab removed; *Show battery percent* is in General now.
  - **Accessibility** moved into **Customization** (interface scale, rows, async loading, animated covers, launch animation), under the Look options.
  - System no longer has the Pegasus theme switcher.
  - The extra SteamGridDB key field left over from StMini is gone: the artwork browser uses the key from Settings › Scraping.
- **Emulators tab:** *Scan installed emulators* works even before any ROM folder or system is found, and lists what it found.
- **Achievements tab: list or grid.** The list is like Steam's achievements page (badge, name, description, unlock date or how many players have it, points). Ⓨ or the List/Grid pills switch; the choice is remembered for every game.
- **Close menu:** *Exit DeckOS*, *Restart DeckOS*, *Restart device* and *Shut down device* (the last two need PServer or root), *Cancel*. One menu for every page now.
- **Library: the controller highlight no longer goes missing.** Pressing Down right after LB/RB gave the keys to the tab you were leaving (hidden), so no game was highlighted and the D-pad moved the hidden one until you tapped a game. The Library now always focuses the tab on screen, also when a tab finishes loading late (async loading) and when you come back to DeckOS.
- **Properties:** Ⓑ on its left list goes back to where you opened it (Home, Library, Search or the game page) instead of opening the Steam menu.
- **Properties › Details: renaming a game and editing its description work.** From the Library, Home and Search, the page got a copy of the game's data instead of the game, so the change was dropped. A renamed game keeps its SteamGridDB picks and custom titles.
- **Custom SteamGridDB title** (Properties › Customization) is now used by *Scrape this game*, auto-scrape and re-scrape too, not only by the artwork browser.
- **Android apps open in touch mode.** Moving through DeckOS with the D-pad switches Android to "keyboard mode", and an app opened from DeckOS started in it. Apps without their own focus style then get Android's default focus highlight over their whole screen (a tint). DeckOS now gives one invisible tap to its own window before opening an app, so the app starts as if you'd tapped its icon. Emulators opened with a game are unchanged.
- **Fixes:** closing the power menu put Home's focus on the search bar; the scraping notification could show a stale *Downloading…* line; a page change that never finishes no longer blocks the controller-focus safety check, which now also recovers focus left on something hidden.

**Notes**
- The touch-mode fix is the leading explanation for the remaining tint, not a certainty. DeckOS's log (`logs/lastrun.log` in your DeckOS folder) now has a `touch mode:` line after each app launch, saying whether it switched.
- *Restart device* / *Shut down device* only appear on devices where Pegasus allows them, and need PServer or root on Android.
- Checked on PC at 1920×1080, then 1240×1080. The Android code and APK build locally; nothing has been checked on a handheld yet.

**Test checklist**
1. Settings › Scraping › *Re-scrape…*: leave *Skip games that already have artwork* on, turn *Everything* off, pick a collection, *Start re-scrape*. Top-left, a card shows the progress, then *Scraping finished*. Only games without artwork were scraped.
2. Settings › Collections: open a collection, turn *Show in the Library* off → it's gone from Library › Collections. Turn it on. *Rename…* it → the new name shows in the Library. For a ROM system, *Games folder…* → pick a folder → its games are rescanned from there.
3. Settings › General has *Show battery percent*; there's no Power or Accessibility tab; Customization has the accessibility options.
4. Settings › Emulators › *Scan installed emulators* lists the emulators on the device.
5. A game page with RetroAchievements: Achievements tab → Ⓨ switches list/grid. Open another game: same view.
6. Steam menu › Close: Exit, Restart DeckOS, Restart device, Shut down device, Cancel. Try *Restart DeckOS*: DeckOS closes and opens again.
7. Library: press RB then Down quickly, several times, across all tabs. A game is always highlighted and the D-pad moves it. Same after launching a game and coming back.
8. Library: Ⓧ on a game › Properties, then Ⓑ: back in the Library on the same game. Same from a game page, Home and Search.
9. Properties › Details › Name: change it, Ⓑ to save. The new name shows in the Library and on the game page. Same for the description.
10. Properties › Customization: set a *Custom SteamGridDB Title*, then Details › *Scrape this game*: the artwork found matches that title.
11. Navigate DeckOS with the D-pad, then open Among Us (or another Android app that showed the tint). No tint. If it's still there, send `logs/lastrun.log`: the `touch mode:` line says what happened.

## 0.1.2 — 2026-11-26
**Your own collections, and Android apps that come back instead of starting over.**
- **Add to collection:** pick *Add to collection...* in a game page's options (the ⚙ button), or with Ⓧ on a game in the Library.
  - Every collection of your library is listed, with a tick where the game already is. Ⓐ puts the game in or takes it out.
  - *New collection…* at the bottom names a new one with the keyboard and puts the game in it. Typing the name of one you have (any case) adds the game to that one.
  - A system's collection, or one from a metadata file, shows as *From your library* and stays.
  - Collections show in the Library's *Collections* tab straight away; one you empty goes away. They're kept in `deckos/collections.json` in DeckOS's config folder, through rescans and updates.
- **Android apps open the way the home screen opens them:**
  - Pegasus (and DeckOS until now) opened apps with a slightly different request than the home screen's. When the app was already open, Android took it for a different request and stacked a second copy of the app's first screen on top of the running one. Games started over and showed their start-up pop-ups again; that's the Among Us pop-up with the dimmed screen.
  - DeckOS now sends exactly the home screen's request, so a running app comes back as you left it, from DeckOS or from the home screen. Emulators started with a game are unchanged.
  - The same goes for *Resume* on the game page. For an emulator it used to open the emulator's main menu on top instead of the game.
  - The launch command shown for Android apps now includes the launcher category.
- **Fix:** after 0.1.1 moved the artwork into the DeckOS folder, a quick start from the game list cache could still look for old artwork files. Only the current ones are used now.

**Notes**
- An app still running from an older DeckOS launch may restart once more the first time. After that it comes back.
- Checked on PC at 1920×1080, then 1240×1080. The Android code and APK build locally; nothing has been checked on a handheld yet.

**Test checklist**
1. Open a game's page, select the ⚙ button, pick *Add to collection...* → *New collection…*, type "Games", press B. The row "Games" appears ticked; B again goes back to the game page.
2. Library › Collections: "Games" is there with that game. In the Library, press Ⓧ on an Android game (Among Us) → *Add to collection...* → Ⓐ on "Games".
3. In the picker, Ⓐ on "Games" again takes the game out (the tick goes). Take all of them out: "Games" leaves the Collections tab.
4. The game's system (e.g. GBA) shows *From your library*; Ⓐ on it says it stays.
5. Open Among Us from Android's home screen and leave it on its main menu. Switch to DeckOS (recent apps) and play Among Us from its page: the same game comes back where you left it, with no restart and no Announcements pop-up. Then the other way round: play it from DeckOS, press home, tap its icon. Same game, same place.
6. Start a game in an emulator from DeckOS, go back to DeckOS, press *Resume*: the game is back, not the emulator's menu.

## 0.1.1 — 2026-11-26
**Your own artwork, one DeckOS folder for everything, and the Steam menu with the controller.**
- **A DeckOS folder.** At the first start (and once after this update), DeckOS asks where to keep its things:
  - Ⓐ makes a folder in your storage and lets you name it (DeckOS by default).
  - Ⓧ lets you pick any folder, or make a new one inside it.
  - Ⓑ asks again next time. You can change it later in Settings › Library › *DeckOS folder*.
- **What goes in it:**
  - `media/<system>/<game>/`: the artwork, trailers and screenshots, with names that say what they are (`hero.png`, `logo.png`, `capsule.png`, `wide-capsule.png`, `boxart.png`, `screenshot-01.png`…). Your own files are `custom-hero.png` and so on, and a rescrape never replaces them.
  - `keys.txt`: your API keys and accounts, one `KEY=value` per line. DeckOS reads it at start and whenever you change it, so you never have to type keys on the handheld. It starts as a template to fill in.
  - `logs/lastrun.log`: a copy of DeckOS's log, for bug reports.
  - What was scraped so far moves into it, with the new names.
- **Your own artwork:** Properties › Customization lists the game's Hero, Logo, Capsule, Wide capsule, Box art, Icon, Trailer and Screenshots. Each row shows what's used now and where it comes from: *Yours*, *Scraped*, *Game files* or *Online pick*.
  - A tap, or Ⓐ, opens Android's file manager to pick a picture (or a video for the trailer). It's copied into the game's folder and shown everywhere at once.
  - Ⓧ browses with DeckOS's own controller-friendly browser instead.
  - Ⓨ removes your file, and the scraped one comes back.
  - Screenshots are added, not replaced.
- **Steam menu with the controller:** opening the menu on a game page, in Properties or on the search page left the selection on no button, so nothing was highlighted and the D-pad did nothing. It now always starts on a real button.
- **Fixes:** the Customization page never knew which game it showed (StMini bug), and the selected row no longer sits under the button bar.

**Notes**
- Keys: your keys file is in `DECKOS\secrets\keys.txt` on your PC. Copy it over the template `keys.txt` in your DeckOS folder. It's never on GitHub.
- The ScreenScraper forum request hasn't been posted yet; ScreenScraper keys aren't used until it's answered.
- Checked on PC at 1920×1080 first, then 1240×1080. The Android code and APK build locally; nothing has been checked on a handheld yet.

**Test checklist**
1. Start DeckOS: the *Your DeckOS folder* card appears. Press Ⓐ, keep "DeckOS", press Done. In a file manager, `/storage/emulated/0/DeckOS` has `media`, `keys.txt` and `logs`, and `media/<system>/<game>/` has `hero`, `logo`, `capsule`… files for scraped games. Home and the game pages still show their artwork.
2. Copy your `keys.txt` over the one in the DeckOS folder, then go back to DeckOS. Settings › Library shows the SteamGridDB and TheGamesDB keys as *Set*, and the RetroAchievements account is signed in.
3. On a game page: options › Properties › Customization › *Hero*. Tap it (or Ⓐ), pick a picture in Android's file manager. The row says *Yours*, and the game page's hero is your picture. `custom-hero.jpg` (or `.png`) is in the game's folder.
4. Do the same for the Logo and the Capsule, and add a screenshot. Then press Ⓨ on the Hero row: the scraped hero is back.
5. Open the Steam menu on a game page with a tap on *STEAM MENU*, and once with the menu button. Both times the D-pad moves the highlight, and Ⓐ opens the page.

## 0.1.0 — 2026-11-26
**The first stable build: a normal release, no longer a pre-release.**
- **A game keeps running behind DeckOS, like on Steam.** On your handhelds the system service (or root) can see whether the game's app is still running.
  - Back in DeckOS while the game is still open, the game page shows a green **Resume** and a blue **Stop**, and Home shows **RUNNING** under it. Once the game's app is closed, Play is green again.
  - **Resume** brings the game back exactly where you left it. It doesn't start it again.
  - **Stop** asks first, then closes the game at once. Anything not saved in the game is lost.
  - Starting a different game ends the running game's session first, and its play time is saved.
- **Play time counts while the game runs**, from the launch until the game's app is closed, but not while the screen is off. That includes time you spend back in DeckOS with the game open.
  - Settings › Overlay › *Count play time while the game runs* turns it off. Then it counts only while the game is in front, as in 0.0.15, which is also how devices without the system service or root work.
- **Home's game row no longer vanishes.** After Settings, or coming back from a game page, the row could be scrolled onto empty space: no icons, no highlight, and a tap on *View more in your Library* scrolled instead of opening the Library. It now always sits on the selected game.
- **A tap opens a tile** on Home and in the Library (games, collections, *View more*). It used to take a second tap.
- **The controller shortcut works in either order.** Select+Start pressed together often registered Start first and was missed, so it took two or three tries.
- **Quick Access:** its background can no longer take the controller focus. When it did, Android tinted the whole screen grey and the controller seemed to move nothing.

**Notes**
- **About the blue tint in your Among Us photos:** that's the game's own Announcements pop-up. The game dims everything behind it, and its controller ring sits on the pop-up's X. The performance overlay can't take the focus or draw a highlight. The main-menu photos are the same game without the pop-up.
- Nothing here has been checked on a handheld yet. The PC checks (235 tests) pass, and the Android code and APK build locally.

**Test checklist**
1. Launch a game from DeckOS, play a minute, then come back to DeckOS (Home button, Quick Access › Return to DeckOS, or recent apps). The game page shows **Resume** and a blue **Stop**, and Home says **RUNNING**.
2. Press **Resume**: the game is back where you left it, not restarted.
3. Come back to DeckOS, press **Stop**, choose *Stop game*. The game closes, Play is green again, and its play time includes the minutes spent in DeckOS while it was open.
4. Launch a game, close it from Android's recent apps, then open DeckOS: it shows Play, not Resume.
5. Settings › Overlay: *Count play time while the game runs* is on. Turn it off, play, go back to DeckOS for a minute, then play again. That minute doesn't count.
6. Open Settings, go back to Home: the game row shows its icons and highlight. Open a game page, go back, tap *View more in your Library*: the Library opens on the first tap.
7. In a game, press Select+Start together a few times. Quick Access opens every time, whichever button lands first.

## 0.0.15 — 2026-11-26
**Fixes from your report on the Steam menu's highlight and on play time.**
- **Play time counts only while the app DeckOS opened is in front.**
  - DeckOS now records the exact app Android opens for a launch. Before, it guessed it from the launch command, and when the guess failed it took whatever app came to the front next.
  - It sees which app is in front through Android's **usage access**: every app switch, with its exact time, including the screen turning off. On AYN / Retroid, DeckOS gives itself that access through the system service at the first launch. It's shown and can be given by hand under Settings › Overlay › *Play time*.
  - The home screen, other apps, Android's settings, file pickers and permission screens never count, and are never taken for the game.
  - Without a game (you only left DeckOS), the notification, Quick Access and the performance overlay no longer show a timer. Quick Access says "No game running".
  - Quick Access shows "Paused at …" while the game isn't in front and "Game closed" once its process has ended.
- **Steam menu: the highlight always shows the selected button.** It used to follow Qt's keyboard focus, which could drift elsewhere while the menu stayed on the selected button. Now it follows the selection itself.
- **The controller's focus is checked a few times a second.** With the Steam menu open, the keys always go to it. If nothing on the page has the focus (after the boot screen, or coming back to DeckOS), the page takes it back. Home's own focus timer no longer pulls the focus out of an open menu.
- **Root:** on devices without the AYN / Retroid system service, DeckOS can now use root (Magisk, KernelSU) for the same things: modes, underclocking, the frame rate, usage access and the controller shortcut. Your handhelds have the system service, so they won't show a Magisk prompt. Settings › Overlay › Device info now shows the system service, root and usage access.

**Notes**
- Nothing here has been checked on a handheld yet; the Android code compiles locally (`tools\check-android.ps1`, which can now also build an APK locally).

**Test checklist**
1. Settings › Overlay › *Play time* shows ✓. If it doesn't, launch a game once, or press it.
2. Launch a game and play 2 minutes. Press the Android Home button and wait 2 minutes, then open the game again from recent apps and play 1 minute. The notification said "Paused, the game isn't in front" while you were away. Back in DeckOS, the game's play time grew by about 3 minutes, not 5.
3. Leave DeckOS without starting a game (Home button). The notification shows no running timer, and Quick Access says "No game running".
4. Open the Steam menu on Home, Library and a game page; move up and down. The selected button is always highlighted. Press the menu button twice quickly, then once more: the menu opens with Home highlighted.
5. Leave DeckOS from Home and come back: the game row still has its highlight.

## 0.0.14 — 2026-11-25
**Fixes from your 0.0.13 report (Retroid Pocket Classic).**
- **Underclocking presets on every chip.** ClusterTune only has presets for the Odin 3's and the Odin 2 / Thor's chips, so your Retroid's list held only Stock, and left / right kept applying it. Chips without ClusterTune presets now get DeckOS's own *Small / Medium / Large Underclock*: about 85 / 70 / 55 % of each cluster's top clock, on the chip's own steps. They're marked "DeckOS preset" and appear in Quick Access's slider too.
- **Quick Access: the blank Wi-Fi and Bluetooth rows are fixed.** Their on/off switch took the whole row's width, so the labels were squeezed to nothing. This was also the "empty gaps".
- **Quick Access: the controller always has a visible selection.**
  - Opened with a tap (the notification), Android was in touch mode and nothing took the focus. Now the current tab is selected at once, and a press with nothing selected lands there.
  - The selection also has a light outline now, so it can't be missed.
- **Controller shortcut:**
  - *Turn on the controller shortcut* (Settings › Overlay, or Quick Access › Overlay) now turns DeckOS's accessibility service on by itself on AYN / Retroid. That also gets past Android's "restricted settings", which blocks sideloaded apps.
  - The settings now tell "on and running" apart from "on but blocked by Android".
- **Home: the selection highlight comes back** after leaving DeckOS and returning. Its animation is restarted and the row gets the focus again; the selected game stays the same.
- **Screenshots:**
  - Up to 5 per game: TheGamesDB's screenshots plus libretro's in-game snap, which was the only one fetched until now. They show in the game page's Activity tab, under the description, and in the media viewer.
  - Games scraped before get one screenshot-only pass. It starts by itself with *Scrape new games automatically*, otherwise with *Scrape missing games*.
  - That pass keeps a reserve of TheGamesDB's monthly lookups for new games.
- **Trailer:** the default delay is now 2 seconds.

**Notes**
- **Trailers still need ScreenScraper.** It's the only free source of game videos; TheGamesDB only has YouTube links, which DeckOS can't play. Its API refused your account login, and DeckOS also needs its own developer credentials, which only ScreenScraper gives out (a request on their forum). Until then, a trailer plays only for games that already have a video file.
- Nothing here has been checked on a handheld yet. The Android code is now compiled locally before every push (`tools\check-android.ps1`).

**Test checklist**
1. Retroid: Settings › Underclocking lists Stock, Small, Medium and Large Underclock ("DeckOS preset"). Applied profile → Medium: the status says it was applied, and the CPU rows show lower limits.
2. Quick Access › Quick Settings: the Wi-Fi and Bluetooth rows show their names and switches, with no blank spaces.
3. Open Quick Access by tapping the notification, then use the D-pad: a tab is selected straight away, with an outline. Move through tabs and options.
4. Settings › Overlay › *Turn on the controller shortcut*: within a second or two it shows ✓ "Running". In a game, Select + R1 opens Quick Access.
5. Home: highlight a game, press the Android Home button, come back. The game is still highlighted (the border blinks).
6. Settings › Library › *Scrape missing games* (or wait if automatic scraping is on): games get screenshots. Check a game's Activity tab and the screenshots under its description.

## 0.0.13 — 2026-11-25
**ClusterTune built in.** Underclocking is now its own settings tab, **Settings › Underclocking**, with ClusterTune's tuner ported into DeckOS (MIT, by Aurelio Bernal). The separate app isn't needed any more.
- **Applied profile:** switch profiles right on the page. The page shows the chip and every CPU cluster's and the GPU's current limit next to its stock limit.
- **ClusterTune's presets** for the chip (Small / Medium / Large on the Snapdragon 8 Elite and 8 Gen 2). Like in ClusterTune, they can be edited or deleted, and *Restore ClusterTune presets* puts them back.
- **Your own profiles:**
  - *New profile* starts from the limits in effect now.
  - Each CPU cluster's and the GPU's maximum steps through the chip's own frequencies, left and right.
  - Rename, duplicate, move up or down, and delete (press A twice).
  - Editing the applied profile applies the change as you make it.
- **ClusterTune files:** *Import from ClusterTune…* takes every profile in an export that fits the chip. *Export profiles* writes them to Downloads in ClusterTune's format, so ClusterTune can import them too.
- **Apply again after a restart** (on by default): the chip resets to its own limits at every restart, and DeckOS puts the profile back.
- **Quick Access:** the underclock slider is Stock, the presets, and the profile you choose as *Custom* on the page. The performance overlay names the applied profile.
- Settings › Overlay's old "Import ClusterTune profile" (one Custom profile) is replaced by a link to the new tab.

**Fixes and additions from your 0.0.12 report**
- **Launch cover:** it's now fully opaque until its time is up, then it fades. On Android 12+ it was capped at 80% opacity, because its window let touches through, so the loading emulator showed through from the start. The cover now takes touches; the controller still goes to the game.
- **Play time counts only while the game is in front.**
  - DeckOS now knows which emulator it started: it reads the package from the launch command, or takes the first app in front after the launch.
  - Switching to another app or the home screen pauses the time, and coming back resumes it. A closed emulator stops it.
  - Only this time is saved to the game's play time.
  - The notification, Quick Access and the performance overlay show it. The notification says "Paused, the game isn't in front" while you're away.
  - It sees which app is in front through the controller shortcut's accessibility service, which now also reports that (it still reads nothing on screen). Without that service, DeckOS asks the AYN / Retroid system service every 5 seconds.
- **Exit game** in Quick Access, like the Deck: a button next to the game's name, or Y.
  - A confirmation first: "Exit game?", with a warning that unsaved progress will be lost. Cancel is selected by default.
  - Then the screen fades to black, the emulator is closed, and DeckOS comes back on its Home page before the black fades away.
- **The in-game notification comes back.** Android 14 and 15 let you swipe away notifications like this one, and DeckOS only re-posted it when the game changed. It now comes back within a couple of seconds.
  - Settings › Overlay shows when Android is blocking DeckOS's notifications, with a button that opens the right Android page.
  - If you swipe DeckOS itself away from recent apps, Android closes it, and the notification goes with it until the next game.
- **Quick Access tabs scroll smoothly.** Moving down no longer jumps half a page (the big gaps); the list glides to keep the selected option in view.

**Notes**
- Limits are written through the AYN / Retroid system service (PServer), the way ClusterTune does it on these handhelds. Without it, the page shows the limits but can't change them.
- Not in yet: ClusterTune's Auto Tune, per-app profiles (DeckOS will do per-game ones), and the sleep profile. They're on the roadmap.
- Checked on PC against a simulated Snapdragon 8 Elite, with unit tests for the ported code. Not tried on a handheld yet.

**Test checklist**
1. Settings › Underclocking (new tab under Overlay). *Chip* names your chip, and each CPU cluster and the GPU show "X of Y".
2. Odin 3: Small, Medium and Large Underclock are listed as ClusterTune presets.
3. Applied profile → Medium. After about a second the text below says "Medium Underclock applied", and the cluster rows show the lower limits. CPU-Z or ClusterTune shows the same limits.
4. Switch the vendor performance mode in Quick Access: the underclock limits stay.
5. *New profile*, lower one cluster a few steps, then *Apply*. Back in the list it shows your values.
6. Set it as Quick Access "Custom", open Quick Access › Performance: the slider reads Stock / Small / Medium / Large / Custom, and moving it applies each one.
7. Restart the handheld with a profile applied: after the restart the limits come back by themselves within a few seconds.
8. *Export profiles*, then *Import from ClusterTune…* with the same file (Downloads): it says "Imported N profiles". The file also imports into ClusterTune.
9. Applied profile → Stock: every limit is back at the chip's own.
10. Launch a game: the launch screen stays fully solid (no emulator showing through) for its time, then fades to the game.
11. Turn on the controller shortcut, start a game, then press Home and wait a minute. The notification says "Paused…". Go back to the game, then return to DeckOS: the game's PLAY TIME went up only by the time you were in it.
12. In a game, open Quick Access. Press Y (or *Exit game* at the top): the confirmation shows with Cancel selected, and B or Cancel goes back. Confirm instead: the screen fades to black, the emulator closes, and DeckOS shows Home.
13. While playing, swipe the DeckOS notification away: it comes back a couple of seconds later.
14. Quick Access › Performance and Overlay tabs: hold down. The list glides one option at a time with no big empty jumps.

## 0.0.12 — 2026-11-25
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
