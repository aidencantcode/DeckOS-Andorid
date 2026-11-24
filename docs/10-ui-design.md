# 10 — UI design (Steam-faithful shell)

Reference look: Steam Deck Game Mode + Big Picture, as approximated by StMini (`reference/stmini`). Study its screens for layout and feel; rebuild cleanly. Use real Steam Deck footage/screenshots from the web as the ground truth for layout and motion (don't ship them).

## Screens
- **Main menu** (Guide/Start or a dedicated button): left slide-in panel — Home, Library, Achievements (DeckOS), Media, Downloads, Settings, Power. Avatar + name at top (RA/Steam profile).
- **Home**: large blurred hero/background of the focused game, horizontal **Recent games** shelf (last item = "Library" shortcut tile), below: "Recent achievements", "Continue playing", "Recently added", per-system shelves (configurable). Top bar: search, notifications, Wi-Fi, battery, clock, avatar.
- **Library**: L1/R1 tabs — All games · Favorites · Systems (collection grid with system art/icons) · Recent · Installed emulators? (no) · **Steam** (Phase 5) · Non-ROM apps (Android apps provider). Sort & filter menu (X): name, last played, playtime, release, rating, achievements state; filters by system, genre, has-achievements, mastered, favorites, players.
- **Game page**: hero (with parallax on scroll), logo over hero, **Play** (green) + secondary buttons (favorite, … options), stats row (LAST PLAYED · PLAY TIME · ACHIEVEMENTS), tabs: **Activity** (sessions, recent unlocks), **Achievements**, **Your Stuff** (screenshots, videos, manuals), **Game Info** (description, developer, publisher, genre, release, players, system, file info). "… → Properties" dialog: General (title, launch options), **Compatibility** (emulator/core/command), **Artwork**, **RetroAchievements** (link/unlink), **Details**, **Files** (path, size, hashes).
- **Quick Access** (… button): notifications (scrape done, achievements), quick settings (volume, brightness where allowed, perf overlay level), Downloads summary.
- **Settings**: System · Library (folders, rescan, setup wizard, generated metadata, advanced Pegasus dirs) · Scraper · Emulators · Accounts (RA, Steam, SteamGridDB, ScreenScraper, IGDB) · Controller (layout, glyphs, combos) · Display (theme accent, reduce motion, video previews, aspect handling) · Sounds · Performance/Overlays · Storage · About (version, credits, open-source licenses, export logs).
- **Downloads**: scrape queues (Fast/Heavy), needs-review, failures.
- **Media**: screenshots grid across games.
- **Power**: Exit DeckOS, restart DeckOS, (Android system power menu if allowed).

## Visual system
- `Theme.qml` singleton: palette close to Steam's dark navy/blue-grey (e.g. background ≈ `#0F1318` as StMini uses), accent blue for focus, green for Play; corner radii; elevation via subtle gradients/shadows; blur for backgrounds (use `QtGraphicalEffects` sparingly — expensive on mobile; prefer pre-blurred cached images for hero backgrounds).
- **Fonts**: open fonts only (e.g. Inter / Noto Sans / Roboto Flex for UI; Noto Sans CJK for coverage). StMini's Arial/Gilroy files must not ship.
- **Units**: `vpx(n)` scales from a 1280×800 design (Steam Deck's resolution) to the actual window. Layout breakpoints: **wide** (≥ 16:10) and **square-ish** (≤ 4:3, incl. the Retroid Pocket Classic’s ≈10:9) — square-ish shows fewer capsules per row, stacks the game page stats, keeps text sizes readable on the Retroid Pocket Classic's small screen.
- **Capsules**: vertical 2:3 posters by default (fallbacks: boxFront → generated title card with system color + title text); focus = scale ~1.08, bright outline/glow, slight lift; badges (RA, favorite, mastered, "new").
- **Motion**: 120–200 ms ease-out for focus, 250–300 ms for page transitions; everything 60 fps on Retroid Pocket Classic. "Reduce motion" setting.
- **Button hints**: bottom bar always shows contextual actions with the correct glyph set (Xbox / Nintendo / PlayStation, auto-detected from the controller with manual override; handhelds with Nintendo-layout toggles must show the right letters).
- **Sounds**: subtle original/CC0 set (navigate, accept, back, tab, toast, launch, achievement). Never Valve's files.

## Input & focus
- Gamepad only must reach everything. Keyboard on PC for dev.
- One navigation model: nested `FocusScope`s per zone (top bar, content, footer), `KeyNavigation` inside lists/grids, a tiny `Nav` helper for zone switching + focus memory per screen; no global integer "focusZone" state machines (StMini's main pain point).
- Hold-to-repeat with acceleration in long grids; L1/R1 tabs; L2/R2 jump by letter/page in Library; Select = main menu? (decide & log); Start = Quick Access.
- On-screen keyboard: Steam-like controller keyboard (A type, B backspace, X space, Y shift, L/R cursor) for search and credentials; also accept a hardware keyboard.

## Performance
- Images: always set `sourceSize`, use cached thumbnails for capsules, `asynchronous: true`, recycle delegates; no full-res posters in grids.
- Video previews: start after ~1 s of focus, one player instance reused, muted by default with setting.
- Profile startup (<2 s to Home on Odin 3 with 1000 games) and scrolling (no dropped frames) — measure with the screenshot tour + a frame timer in dev mode.
