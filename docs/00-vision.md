# 00 — Vision

## One line
SteamOS Game Mode's interface, for every game on an Android handheld — retro ROMs, PS2/PS3/Switch/Vita/PS4/Xbox 360 emulators, PC games via Winlator-family launchers, and your Steam library — with Steam-style achievements, art and playtime everywhere.

## Who it's for
- **Casual player:** installs DeckOS, points it at a ROM folder, it finds the systems, finds the installed emulators, picks good defaults, downloads art, and games launch. They never see a config file.
- **Tinkerer (the owner):** every launch command is visible and editable, custom emulators can be added, Pegasus metadata files and custom themes still work, and logs are accessible.

## What "faithful to Steam" means here
- Layout, navigation model and motion of Steam Deck Game Mode / Big Picture: left **main menu** (Steam-button menu), **Home** with a recent-games shelf over a hero background, **Library** with tabs, **game page** with hero art + logo + big Play button + stats row + tabs, **Properties** dialog, **Quick Access** menu, toasts for achievements, bottom button-hint bar.
- Same *feel*: snappy focus movement, subtle scale/glow on focused capsules, blurred hero backgrounds, consistent button hints, sounds on navigation.
- Not a copy of Valve's assets: no Valve logos, fonts (Motiva Sans) or sound files. We make our own look-alike-in-spirit assets and use open fonts.

## DeckOS flair (our own touches — ideas, not limits)
- Achievements are first-class for *everything*: RetroAchievements for ROMs, Steam achievements for Steam games, one unified UI.
- "Downloads" page = scrape/media download queue with progress, like Steam's download manager.
- Per-system accent colors and animated system icons in the library.
- Hardcore-mode indicator and RA "mastery" badges on capsules.
- "Compatibility" section in Properties (Steam's Proton selector, reimagined) to pick which emulator / core / PC launcher runs a game.
- Session summary toast when returning from a game: time played, achievements unlocked this session.
- Device-aware layouts: 16:9 (Odin 3) and near-square ≈10:9 (Retroid Pocket Classic, 1240×1080) are both first-class, not stretched.

## Non-goals
- Not an emulator, not a translation layer, not an OS/launcher replacement for Android system UI (though it may be set as the default Home app).
- No on-screen touch controls.
- No piracy features: never download ROMs/BIOS, never link to ROM sites.
- No store purchasing.

## End state
A signed APK named **DeckOS** with its own package ID, its own icon/splash, no Pegasus branding in the UI (credits + GPL notice in About), built by CI, installable alongside stock Pegasus.
