# 03 — Dev loop: PC testing, Android builds, owner reports

## A. Fastest loop for pure QML (use from day 1)
Until our fork builds, iterate on the theme with an **official Pegasus PC build** (download the latest continuous build for the dev machine's OS from pegasus-frontend.org / the `pegasus-deploy-staging` releases — *verify current location*):
1. Unpack it; create `portable.txt` next to the executable (portable mode → config lives next to the exe — *verify in `src/backend/Paths.cpp`*).
2. Point it at `src/themes/deckos` (symlink/junction into the `themes/` folder of the portable config) and a fixture game dir.
3. Edit QML → restart Pegasus (or use a reload shortcut we add in Phase 0).
Once the fork builds, switch to our own binary permanently.

## B. Building our fork on PC
Pick what matches the machine Claude Code runs on; record the exact versions in `DECISIONS.md`.

**Windows** (likely the owner's machine):
- Qt 5.15.2 MinGW 64-bit via the official online installer or `pip install aqtinstall` → `aqt install-qt windows desktop 5.15.2 win64_mingw81 -m qtcharts` (modules as needed; QtMultimedia, QtSvg, QtGraphicalEffects ship with the base desktop package — verify). Matching MinGW toolchain: `aqt install-tool windows desktop tools_mingw qt.tools.win64_mingw810`.
- SDL2 development libs (MinGW) — upstream supports SDL2 or Qt Gamepad; prefer SDL2 for controller parity with Android.
- `git submodule update --init --recursive`, then `qmake .. && mingw32-make -j` in `build/` (or CMake).

**Linux** (Ubuntu 24.04-ish): `qtbase5-dev qtdeclarative5-dev qtmultimedia5-dev libqt5svg5-dev qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtquick-layouts qml-module-qtgraphicaleffects qml-module-qtmultimedia qml-module-qtquick-controls2 libsdl2-dev libqt5sql5-sqlite` (verify list against upstream `x11.yml`).

## C. Automated checks (add in Phase 0, run after every change)
1. **Build** with warnings visible; treat new warnings in DeckOS code as errors.
2. **qmllint** over `src/themes/deckos/**/*.qml`.
3. **Unit tests**: Qt Test for C++ services (hashing, scanner rules, launch resolver, catalog parsing, scraper ranking). Upstream already has `tests/`.
4. **Smoke test**: `QT_QPA_PLATFORM=offscreen ./deckos --deckos-dev=mock,fixtures,quit-after=20s` — loads the theme with mock services and fixture library, navigates programmatically, exits non-zero on any QML warning/error in the log.
5. **Screenshot tour**: `--deckos-dev=tour,resolution=1920x1080` and `resolution=1240x1080` — walks every screen (Home, Library tabs, GamePage tabs, Achievements, Properties, Artwork picker, Settings pages, Wizard steps, Downloads) and saves PNGs to `build/tour/<res>/NN-screen.png` via `QQuickWindow::grabWindow()`. **Open and look at these PNGs yourself** after UI changes; compare against StMini screenshots/Steam Deck reference behavior; fix layout clipping and overlap.
6. **Mock services**: `deckos.ra`, `deckos.steam`, `deckos.scraper` have a mock backend that serves recorded JSON fixtures from `tests/fixtures/` (record real responses once with the owner's keys **redacted**). UI work must never depend on live network.

## D. Fixture library (never real ROMs)
`tools/make_fixtures.py` generates a fake ROM tree: right extensions and folder names for ~25 systems, multi-disc sets with `.m3u`, `.cue/.bin`, a PS3 folder game, BIOS files to be excluded, junk files, odd unicode names, 1000-game stress collection. Tiny dummy files only. Optionally a few homebrew/public-domain ROMs for real hash tests (e.g. freely licensed homebrew), with sources noted.

## E. Android builds
> The agreed end-to-end flow (Windows gate → `tools/ship.ps1` → tag → GitHub pre-release with APK), version numbers and signing are specified in [13-release-flow.md](13-release-flow.md); it supersedes the versioning bullets below where they differ.

- CI: adapt upstream `.github/workflows/android.yml` (Qt 5.15.10 prebuilt + NDK r21e + androiddeployqt). Build `arm64-v8a` only by default (both targets are 64-bit); keep 32-bit job optional.
- Sign debug builds with a stable keystore from repo secrets so builds update in place. Artifact name: `DeckOS_<version>_<shortsha>_arm64.apk`.
- Version: `versionName` = `0.<phase>.<build>`; `versionCode` monotonic from CI run number.
- Local Android build is optional; CI is the source of truth.
- Install/debug from the PC if the owner connects a device: `adb install -r`, `adb logcat -s DeckOS:* Qt:* libpegasus:*` (*verify log tags*), `adb shell am start` to replicate launch intents.

## F. Handing a build to the owner
For each APK, give the owner a short checklist:
```
Build: DeckOS 0.2.7 (abc1234)
New: Achievements tab on game page
Please test on: Odin 3 Max + Retroid Pocket Classic
1. Settings → Accounts → RetroAchievements → enter user + Web API key → "Verify" shows your avatar
2. Open a SNES game you have achievements in → Achievements tab → numbers match retroachievements.org
3. Play 2 min, unlock nothing, come back → no toast; unlock one → toast appears
Known issues: PS2 hashing slow on first run (~5 s per game)
If something breaks: Settings → System → Export logs, send the zip
```

## G. When the owner reports back
They'll use the template in `PROMPTS.md`. Steps: read logs → reproduce on PC with fixtures/mocks → write a failing test if feasible → fix → note in `CHANGELOG.md` → new build + checklist.
