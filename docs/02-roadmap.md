# 02 — Roadmap

Work top to bottom. Each phase ends with an APK the owner tests. Tick boxes as you go (`[x]`). The owner's **current top priority** is Phase 2 (RetroAchievements tab) and Phase 3 (scraping) — get to them quickly, but Phases 0–1 must be solid first because everything sits on them.

---

## Phase 0 — Foundation (no visible features yet)
- [ ] Run `tools/bootstrap.sh` (or `.ps1`): clone upstream with submodules into `./deckos`, rename `origin` → `upstream`, create the owner's repo as `origin` (ask for its URL; until then work locally).
  - 2026-11-25: cloned at upstream `3702598c`, `upstream` remote set, DeckOS branch `main` created. **Pending:** owner's repo URL → `origin`.
- [ ] Build **unmodified** Pegasus on PC; run it; confirm a theme loads. Record exact toolchain in `DECISIONS.md`.
- [ ] Get the upstream Android workflow green in the owner's GitHub repo (it downloads the prebuilt Qt 5.15.10 Android toolchain). Produce an installable debug APK artifact. Add a stable debug keystore via repo secrets so new builds install over old ones.
  - [ ] Then switch to the DeckOS release flow (`13-release-flow.md`): `tools/check.ps1` gate, `tools/ship.ps1`, tag-triggered `android.yml` → GitHub pre-release with APK, Linux `ci.yml` for ordinary pushes; drop upstream's deploy/coverage jobs.
  - [x] GitHub presentation: DeckOS README, docs index, Test report / Idea issue forms, upstream funding links removed (2026-11-25).
- [ ] Rebrand identity: app name/label "DeckOS", applicationId `com.deckos.frontend`, new launcher icon + splash placeholders, window title, user-visible "Pegasus" strings → DeckOS. Keep copyright headers, LICENSE, and add About → Open-source licenses (Pegasus credit, Qt, SDL, every lib we add). Data dir names → `deckos`.
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
- [ ] Integrate **rcheevos** `rc_hash` in C++; console mapping; hash cache keyed by path+size+mtime.
- [ ] Per-console hash list download + cache; local hash → GameID; fuzzy title fallback flagged "unverified"; manual "Link RA game…" search.
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
- [ ] Performance overlay levels 0–4.
- [ ] In-game Quick Menu overlay (controller combo via AccessibilityService, plus notification/QS tile fallback).
- **Exit:** overlay works over at least RetroArch, an AetherSX2-family PS2 emulator and a Winlator-family launcher on Odin 3.

## Phase 7 — Polish & release
- [ ] Settings completeness pass (every Pegasus setting reachable; legacy menu removed).
- [ ] Backup/restore (settings, overrides, playtime, DB) to a zip.
- [ ] Performance pass (startup time, scrolling 1000+ games, image memory).
- [ ] Localization plumbing (English first).
- [ ] Original assets: icon, splash, sounds, system icons pass.
- [ ] Release signing, versioning, in-app "What's new".
- Ongoing: items from `12-qol-backlog.md`.
