# 01 — Architecture

## Upstream Pegasus at a glance (verify against the live tree)
Snapshot studied: `mmatyas/pegasus-frontend` master, Nov 2026 (latest commit then: "Executes .sh for Android, like other platforms (#1195)").

```
src/app/                    main.cpp, Android platform files (AndroidManifest.xml, build.gradle, Java in src/org/pegasus_frontend/android/)
src/backend/
  Backend.cpp, FrontendLayer.cpp      app wiring, theme loading
  ProcessLauncher.cpp                 builds & runs launch commands; on Android only "am start ..." is supported,
                                      parsed by IntentHelper.java; placeholders {file.path} {file.uri} {file.documenturi}
                                      {file.name} {file.basename} {file.dir} {env.X}
  AppSettings.*, Paths.*              settings & config/data dirs (portable mode exists)
  model/Api.*                         the `api` object themes see: collections, allGames, memory, keys, device, launch signals
  model/gaming/                       Game, GameFile, Collection, Assets
  model/memory/                       per-theme key/value store (api.memory get/set/has/unset)
  model/device/                       battery info
  providers/                          game sources: pegasus_metadata (metadata.pegasus.txt), pegasus_media (media/ dirs),
                                      pegasus_playtime, pegasus_favorites, es2, steam, gog, lutris, launchbox, playnite,
                                      skraper, logiqx, android_apps
  platform/                           AndroidHelpers, PowerCommands
src/frontend/               built-in menus (main menu, settings incl. GameDirEditor, AndroidSafEditor, GamepadEditor, KeyEditor)
src/themes/pegasus-theme-grid  (submodule) default theme
lang/                       (submodule) translations
thirdparty/SortFilterProxyModel (submodule)
tests/                      Qt Test unit tests
.github/workflows/          android.yml, x11.yml, macos.yml; build scripts in .circleci/
```

Build facts from the snapshot: Qt **5.15** (Android CI uses a prebuilt **Qt 5.15.10** downloaded from Pegasus's `alpha1` release assets + OpenSSL 1.1.1t), **NDK r21e**, `androiddeployqt --gradle`, `android-30` platform, ABIs `armeabi-v7a` and `arm64-v8a`. qmake (`pegasus.pro`) and CMake both exist.

## DeckOS layering

```
┌───────────────────────────── QML ─────────────────────────────┐
│ src/themes/deckos/          DeckOS shell = built-in default theme │
│   components/  (TopBar, MainMenu, FooterHints, Capsule, Toast,    │
│                 Dialog, OnScreenKeyboard, FocusRing, ...)          │
│   screens/     (Home, Library, GamePage, Achievements, Properties, │
│                 Media, Downloads, Settings/*, SetupWizard/*, ...)  │
│   style/       (Theme.qml singleton: colors, metrics, vpx(), fonts)│
├──────────────────────── QML-facing API ───────────────────────┤
│ `api`     — unchanged Pegasus API (compat for 3rd-party themes)   │
│ `deckos`  — NEW context object with sub-services:                 │
│    deckos.library   scan, wizard, systems, rescan, metadata write │
│    deckos.emulators catalog, detected apps, per-system/game choice│
│    deckos.launch    resolve/preview/test/launch with overrides    │
│    deckos.ra        account, game match, progress models, toasts  │
│    deckos.scraper   jobs, queues, candidates per art slot         │
│    deckos.steam     profile, owned games, achievements            │
│    deckos.playtime  sessions, totals                              │
│    deckos.overlay   perf overlay level, quick menu (Android)      │
│    deckos.settings  typed settings + secret store                 │
│    deckos.device    capabilities (shizuku/root), screen class     │
├──────────────────────────── C++ ──────────────────────────────┤
│ src/backend/deckos/   services, SQLite cache (deckos.db),         │
│                       NetworkClient (rate limit/retry/cache),     │
│                       rcheevos (rc_hash) for RA hashing           │
├──────────────────────── Android (Java) ───────────────────────┤
│ src/app/platform/android/src/com/deckos/…                         │
│   PackageScanner, UsageStatsTracker, OverlayService,              │
│   QuickMenuAccessibilityService, StoragePermission, SecretStore   │
└────────────────────────────────────────────────────────────────┘
```

Rules:
- New C++ lives in `src/backend/deckos/` with its own `.pri`/CMake target linked into backend. Touch upstream files minimally (registration hooks, launcher override points) and comment those spots with `// DECKOS:`.
- Expose services as QObjects with `Q_PROPERTY`s and list models; long work on worker threads (`QThreadPool`/`QtConcurrent`), results marshalled to the GUI thread.
- One SQLite DB `deckos.db` in the app data dir (schema versioned, migrations in code). Tables roughly: `games_identity` (path, size, mtime, crc32/md5/sha1, ra_hash, serial), `ra_hashlists`, `ra_game_cache`, `ra_user_progress`, `scrape_results`, `scrape_jobs`, `steam_cache`, `playtime_sessions`, `launch_overrides`.
- Pegasus's built-in `src/frontend` menus are replaced by the DeckOS shell's own Steam-style Settings. Keep the old menu reachable behind an "Advanced → Legacy Pegasus settings" entry until the new settings cover everything, then remove.
- Replace the `pegasus-theme-grid` submodule as default with `src/themes/deckos` compiled into a qrc. The theme picker remains under Advanced for custom themes.

## Data locations
- App data (Android: app-specific internal storage; PC: portable `./config` in dev): settings, `deckos.db`, generated metadata, logs, catalog overrides.
- Media: written in Pegasus layout so `pegasus_media` picks them up — `<metadata dir>/media/<game basename>/<asset>.<ext>`. Default media root on Android: `/storage/emulated/0/DeckOS/media/…` (user-changeable; SD card supported). Large but user-visible and easy to back up.
- Logs: `DeckOS/logs/` exportable from Settings → System → Export logs (zip with lastrun log, deckos log, device info, redacted settings).

## Qt version decision
Start on **Qt 5.15** exactly like upstream (prebuilt Android toolchain already exists, all reference themes use Qt 5 imports like `QtGraphicalEffects`). Revisit Qt 6 only if a blocker appears; log in `DECISIONS.md`.

## Identity
- App name: **DeckOS**. Android applicationId suggestion: `com.deckos.frontend` (change before first public release if the owner prefers another). Must differ from `org.pegasus_frontend.android` so both can be installed.
- Can be set as Android default Home app (keep upstream's HOME intent-filter, make it optional in docs/settings).
