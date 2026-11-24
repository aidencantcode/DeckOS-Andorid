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
  - `windeployqt --release` misreads Qt 5.15.2's MinGW plugins as debug builds and refuses to deploy → no deploy step for dev runs; the exe runs from `build/run/` with the toolchain on PATH (aqt hard-wires the Qt prefix, so plugins/QML are found).
  - Pegasus only reads `metadata.pegasus.txt` directly inside each `game_dirs.txt` entry (not recursively) — fixtures must list each system folder.
  - The `offscreen` platform has no system fonts (`QFontDatabase: Cannot find font directory`) → the DeckOS theme must bundle its fonts (planned anyway); the smoke test must not count this line as a theme warning.
  - No OpenSSL 1.1.1 DLLs yet → "SSL support not available" on PC. Add them (aqt `tools_openssl_x64`) before Phase 2 networking.
  - Pegasus's PC-only providers (Steam/GOG/…) scan this machine → smoke tests must disable them for deterministic results.
- **Alternatives:** MSVC 2019-ABI Qt build with VS 2026 (works, upstream AppVeyor uses it, but further from Android); official Qt online installer (needs a Qt account); building Qt 5.15.10 from source (hours, little gain).
- **Revisit if:** a Qt 5.15.2-vs-5.15.10 difference bites, or a later Qt 5.15.x MinGW binary becomes available.

## 2026-11-25 — GitHub workflows: one lean Linux CI, Android unchanged for its first run
- **Decision:** Replace upstream `x11.yml` (3 jobs incl. Coveralls coverage upload, .deb/zip packaging, deploy to mmatyas's staging repo) and `macos.yml` with one `ci.yml`: Linux build + unit tests with qmake and CMake, on pushes to `main` and PRs. `android.yml` is left exactly as upstream for the first push, to prove the upstream Android build is green in the DeckOS repo before it is changed to the tag-driven release flow (`13-release-flow.md`).
- **Why:** Coveralls would fail on the DeckOS repo (red ✗ on every push); packaging/deploy steps target upstream infrastructure; DeckOS doesn't target macOS or desktop Linux distribution. Both build systems stay compiled so new DeckOS code can't silently break one.
- **Alternatives:** Keep upstream workflows and ignore failures (noisy, hides real failures).
- **Revisit if:** we ever ship desktop builds.
