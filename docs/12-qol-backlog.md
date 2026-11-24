# 12 — Quality-of-life backlog

Ideas, not commitments. Add your own (mark `(claude)`), move to the roadmap when picked up.

## Library & launching
- "Recently added" shelf and a "New" badge for 7 days after a game appears.
- Hide/unhide games; per-system hide; duplicate-region collapse.
- Custom collections (Steam "dynamic collections": rules like system=PS2 AND has achievements AND not played).
- Random game button ("Surprise me") with filters.
- Per-game notes and personal rating.
- RetroArch: per-game core options/shader presets shortcut (open RetroArch with a specific core/config), save-state browser if readable.
- Detect BIOS presence per system and warn on the game page ("PS2 BIOS missing for ARMSX2").
- Import from ES-DE gamelists (`gamelist.xml`) and existing Pegasus metadata on first run.

## Achievements
- Unified "Achievements" hub page (RA + Steam): totals, recently unlocked, rarest, nearly-complete sets ("You're 3 away from mastering…").
- Hardcore-mode nudge: show which installed emulators support RA hardcore for this system.
- RA "set exists" indicator during browse (pre-computed hashes).
- Weekly RA "Achievement of the Week"/events shelf if the API exposes it (verify).

## Media
- Video "attract mode" on Home after idle.
- Manuals (PDF/CBZ) viewer from ScreenScraper media.
- Screenshot gallery per game from emulator screenshot folders (RetroArch, PPSSPP, etc.).

## System & device
- Odin 3 / Retroid-specific: detect device model and pick sensible defaults (layout class, glyphs, fan/perf mode hints).
- Set DeckOS as Android Home launcher (optional), with a "boot straight into DeckOS" guide.
- Battery-time estimate in the top bar; low-battery toast in overlay.
- Backup/restore to SD card or a file share; settings sync between two devices via export file.
- Cloud-free by design; optional self-hosted sync later.

## UI flair
- Per-system accent colors and animated system logos in the Systems tab.
- Dynamic accent color from the focused game's hero art.
- Steam-like "Great on Deck" equivalent → **"Verified on this device"** badge from the emulator catalog `verified` + owner's reports.
- Optional PS1/retro shader mode for the UI (owner is a PS1-style rendering dev — a dithered/low-poly UI skin would be a fun signature theme option).
- Startup animation (original), with skip.

## Advanced
- Plugin/extension hooks (QML panels on the game page).
- Theme SDK docs for the `deckos` API so community themes can use RA/scraper/playtime.
- Remote control from phone/PC via local web page (rename, edit commands, upload art).
