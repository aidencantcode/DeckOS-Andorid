# Decisions log

Format: `## YYYY-MM-DD — Title` · **Decision** · **Why** · **Alternatives considered** · **Revisit if**

## 2026-11-25 — Starter kit baseline
- **Decision:** Fork Pegasus Frontend (GPLv3) on Qt 5.15 as upstream does; DeckOS shell is a new built-in QML theme; new features are C++ services exposed as a `deckos` QML object; reference themes are study-only.
- **Why:** Upstream Android toolchain (prebuilt Qt 5.15.10, NDK r21e) already works; all reference themes target Qt 5; license separation (BigScreenFE is CC BY-NC-SA, StMini unlicensed with Valve assets).
- **Alternatives:** Qt 6 port (more work, breaks QtGraphicalEffects-based themes); keep everything in QML like BigScreenFE (insecure keys, no caching, no hashing).
- **Revisit if:** a Qt 5 limitation blocks a headline feature on Android.

## 2026-11-25 — Branch model and where the docs live
- **Decision:** In `./deckos`, branch `master` stays a pristine mirror of `upstream/master`; all DeckOS work happens on `main` (feature branches `feat/<area>-<thing>` off `main`). `docs/`, `catalog/` and `CHANGELOG.md` moved into the repo; the top-level `CLAUDE.md` stays outside (unversioned) and notes the new paths.
- **Why:** A clean `master` makes upstream syncs a plain fast-forward followed by `git merge master` into `main`, and keeps the diff against upstream easy to read. Versioning the docs keeps the roadmap/decisions in step with the code.
- **Alternatives:** Commit straight on `master` (muddles upstream syncs); keep docs outside the repo (unversioned, drift).
- **Revisit if:** the owner wants a different default branch name on GitHub.

## 2026-11-25 — Release flow, version numbers, GitHub presentation
- **Decision:** Windows PC build is the test gate; only builds that pass it are shipped. Shipping = `tools/ship.ps1` tags `v0.<phase>.<build>` and pushes; the tag triggers the Android workflow, which publishes a GitHub pre-release with the signed APK. `versionCode = major*1000000 + phase*1000 + build`. Full spec: `docs/13-release-flow.md`.
- **Why:** Owner wants to test on device only builds that already work on PC, and to grab APKs straight from the Releases page on the handheld (artifacts need a GitHub login and come zipped). A version-derived `versionCode` is reproducible and identical locally and in CI, unlike the CI run number (which differs per workflow and resets if workflows are renamed) or upstream's commit count (meaningless across forks).
- **Alternatives:** Build an APK on every push (wastes CI time, floods the owner with untested builds); CI run number as `versionCode` (the original `03-dev-loop.md` plan).
- **Also:** Upstream `.github/FUNDING.yml` and Pegasus issue templates replaced by DeckOS issue forms (upstream support is credited in the README instead). Upstream tags are not pushed to the DeckOS repo so its tag list shows only DeckOS versions. These files may conflict on upstream syncs — keep ours.
- **Revisit if:** the owner wants nightly builds of every push, or a Play Store/F-Droid channel.

## 2026-11-25 — Windows PC toolchain (verified: unmodified Pegasus builds, tests pass, theme loads)
- **Decision:** Qt **5.15.2** `win64_mingw81` + MinGW-w64 **GCC 8.1.0** (`qt.tools.win64_mingw810`), both installed with **aqtinstall 3.3.0** (standalone `aqt_x64.exe`) from download.qt.io; **SDL2 2.32.10** MinGW dev libs (libsdl-org release, same SDL version as upstream CI); **qmake** build with `USE_SDL_GAMEPAD=1 USE_SDL_POWER=1` and upstream's `-Wall -Wextra -pedantic`. Git for Windows 2.56.1. All of it lives in `../toolchain/` next to the repo (never committed; override with `DECKOS_TOOLCHAIN`). Scripts: `tools/env.ps1`, `build.ps1`, `test.ps1`, `check.ps1`.
- **Baseline (2026-11-25, upstream `3702598c`):** clean build 1.6 min at `-j12`, 0 warnings in `src/`/`tests/` (only Qt-header `-Wpedantic` and SortFilterProxyModel deprecation noise), **23 suites / 191 tests pass**, Pegasus Grid theme loads with a fixture library (5 games, 2 systems) in a portable config.
- **Why MinGW, not the MSVC 2026 already on this PC:** GCC's warnings/behaviour are closer to the Android NDK's clang than MSVC's; upstream's Windows releases are MinGW builds; the docs prescribe it; fully self-contained (no VS dependency).
- **Known version skew:** Android CI uses Qt **5.15.10**; 5.15.2 is the newest open-source 5.15 with official Windows binaries. Fine for development; if a bug only reproduces on one side, suspect this first.
- **Windows quirks found (workarounds are in the scripts):**
  - `sh.exe` on PATH (Git-bash) breaks qmake's MinGW makefiles → `env.ps1` builds a minimal PATH with `Git\cmd` only.
  - QTest output doesn't reach a redirected stdout here, so `make check` logs look empty → `test.ps1` runs each suite with `-o <file>,txt` and parses the totals.
  - `windeployqt` (default or `--release`) fails with "Unable to find the platform plugin": aqt's MinGW plugin DLLs carry a PE debug directory, so windeployqt classes them as *debug* and skips them all. **Fix:** `windeployqt --debug` — plugins are then accepted, and the Qt libraries still come from the exe's import table (release DLLs). Verified: the deployed folder runs with only `System32` on PATH. Used by `tools/deploy-windows.ps1`.
  - PowerShell 5.1 mis-binds positional `Set-Content` arguments next to the dynamic `-Encoding` parameter (path and value get swapped, a file named after the value appears in the working directory) and `-Encoding utf8` writes a BOM → scripts write files with a BOM-less `[IO.File]::WriteAllLines` helper.
  - Pegasus only reads `metadata.pegasus.txt` directly inside each `game_dirs.txt` entry (not recursively) — fixtures must list each system folder.
  - The `offscreen` platform has no system fonts (`QFontDatabase: Cannot find font directory`) → the DeckOS theme must bundle its fonts (planned anyway); the smoke test must not count this line as a theme warning.
  - No OpenSSL 1.1.1 DLLs yet → "SSL support not available" on PC. Add them (aqt `tools_openssl_x64`) before Phase 2 networking.
  - Pegasus's PC-only providers (Steam/GOG/…) scan this machine → smoke tests must disable them for deterministic results.
- **Alternatives:** MSVC 2019-ABI Qt build with VS 2026 (works, upstream AppVeyor uses it, but further from Android); official Qt online installer (needs a Qt account); building Qt 5.15.10 from source (hours, little gain).
- **Revisit if:** a Qt 5.15.2-vs-5.15.10 difference bites, or a later Qt 5.15.x MinGW binary becomes available.

## 2026-11-25 — `windows-build/`: a double-clickable Windows build for the owner
- **Decision:** `tools/deploy-windows.ps1` copies the exe + `windeployqt` runtime + `SDL2.dll` into `<DECKOS root>/windows-build/` (outside the repo, next to `toolchain/`), in portable mode with a tiny fake library and windowed, PC-importers-off settings. `tools/check.ps1` runs it as its **last** step, so the folder only ever holds a build that passed the gate. App files are overwritten each time; `config/` and `test-roms/` are created once and kept. Never deletes anything.
- **Why:** the owner asked for an easy way to try each Windows build themselves; the old `build/run/` only worked with the toolchain on PATH. Living outside the repo keeps 100 MB of Qt DLLs out of git, and `-Clean` builds can't wipe the owner's settings.
- **Alternatives:** a zip artifact from CI (slower loop, Linux CI doesn't build Windows); a static Qt build (hours of Qt compilation for a dev convenience).

## 2026-11-25 — Rebrand: what changed, and what deliberately didn't
- **Decision:**
  - Installed app ID `com.deckos.frontend` is set as `applicationId` in `build.gradle`. The manifest `package` (= Java namespace `org.pegasus_frontend.android`) and all Java/JNI class paths stay, so upstream Java/JNI changes still merge cleanly.
  - FileProvider authority → `${applicationId}.files` (Java builds it from `getPackageName()`). With upstream's fixed authority Android refuses to install DeckOS while Pegasus is installed (`INSTALL_FAILED_CONFLICTING_PROVIDER`).
  - Data dirs: app + org name `deckos` → Android config in `<shared storage>/deckos/` (Pegasus uses `/pegasus-frontend/`), PC `%LOCALAPPDATA%\deckos` or portable `config\`. DeckOS does not pick up an existing Pegasus config — clean separation.
  - Version: `GIT_REVISION` (qmake and CMake) = `git describe --tags --match v[0-9]*` without the `v`, so the log header, Help → About and Android `versionName` all show the DeckOS version. `versionCode` is computed in `.qmake.conf` (qmake can't multiply → zero-padded concatenation, tested on sample tags).
  - The build target stays `pegasus-fe` (the native lib name inside the APK; referenced by CMake, CI and packaging files across ~12 upstream files). Nobody sees it: CI names the APK, the Windows folder gets `DeckOS.exe`.
  - Icons: placeholder "D" mark from `tools/make-placeholder-icons.ps1` (shapes only, no fonts), written over upstream's icon files in place — same names, so no manifest/build changes. Final art is a Phase 7 item. Splash: Qt's `android.app.splash_screen_drawable` with a background-colour + icon layer-list (first checked on device with 0.0.1).
  - Help → About/Licenses credits Pegasus and every bundled library (SortFilterProxyModel MIT, QtApng BSD-3-Clause, SDL2 zlib — verified via GitHub API 2026-11-25; OpenSSL acknowledgment for Android). Every library added later goes there too.
  - Changed English UI strings lose their community translations (fall back to English). Acceptable: English first.
  - **Left alone on purpose:** upstream's misspelt `android.theme` manifest attribute (fixing it would apply a parent-less style — revisit with Phase 1 theming); `setOrganizationDomain("pegasus-frontend.org")` (invisible on our platforms); copyright headers; the `PEGASUS_HOME` env var.
- **Alternatives:** renaming the manifest package and moving the Java sources (large diff on every upstream merge for no user-visible gain); renaming the build target (same).

## 2026-11-25 — Upstream bug fixed: PlaytimeStats use-after-free
- **Found:** Linux CI (qmake job) segfaulted after `test_Playtime` had passed all 7 cases; the same code had passed one push earlier and 300 local Windows runs → timing-dependent. Cause in upstream `PlaytimeStats`: the `QtConcurrent` writer captures `this` and emits `finishedWriting()` as its last step; whoever waits for that signal (the test; in the app, shutdown right after a game session is saved) can destroy the object while the worker is still inside the emit.
- **Fix:** writer futures are tracked in a `QFutureSynchronizer<void>`; `~PlaytimeStats()` waits for them. No deadlock risk: the writer never waits on the GUI thread. `// DECKOS:` marked; a candidate to offer upstream.

## 2026-11-25 — DeckOS `android.yml`, signing key, `ship.ps1`
- **Decision:** upstream's first run in the DeckOS repo was green (both ABIs, 4m40s), so `android.yml` is now DeckOS's: triggers on `v*` tags + manual runs only (ordinary pushes get the cheap Linux CI), **arm64-v8a only** (both target handhelds; halves build time), signed with the stable test key from repo secrets via `androiddeployqt --sign … --storetype pkcs12`, `apksigner verify` must show the DeckOS certificate digest, APK named `DeckOS_<version>_<sha>_arm64.apk`, tag builds become a GitHub **pre-release** whose notes are that version's CHANGELOG section. Upstream's master-only release/deploy steps (mmatyas's keystore and staging repo) are gone.
- **Key:** generated with OpenSSL 3.5 (no local JDK): RSA 4096, 30 years, PKCS#12 with `PBE-SHA1-3DES` + SHA-1 MAC — the PKCS#12 flavour every Java/apksigner version reads (OpenSSL 3's AES default needs a recent JDK). Uploaded with `gh secret set` from stdin; never printed.
- **`ship.ps1` runs the gate after tagging locally** (clean build of the exact release commit), not before: the Windows build then carries the release version, and the tested commit is exactly the shipped one. Failure undoes commit + tag.
- **Alternatives:** keytool-generated JKS (needs a JDK on the PC); signing in Gradle config (more upstream files touched); releases on every push to `main` (too noisy for the owner).

## 2026-11-25 — GitHub workflows: one lean Linux CI, Android unchanged for its first run
- **Decision:** Replace upstream `x11.yml` (3 jobs incl. Coveralls coverage upload, .deb/zip packaging, deploy to mmatyas's staging repo) and `macos.yml` with one `ci.yml`: Linux build + unit tests with qmake and CMake, on pushes to `main` and PRs. `android.yml` is left exactly as upstream for the first push, to prove the upstream Android build is green in the DeckOS repo before it is changed to the tag-driven release flow (`13-release-flow.md`).
- **Why:** Coveralls would fail on the DeckOS repo (red ✗ on every push); packaging/deploy steps target upstream infrastructure; DeckOS doesn't target macOS or desktop Linux distribution. Both build systems stay compiled so new DeckOS code can't silently break one.
- **Alternatives:** Keep upstream workflows and ignore failures (noisy, hides real failures).
- **Revisit if:** we ever ship desktop builds.
