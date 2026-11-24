# Changelog

One entry per build the owner tests. Newest first.

## Unreleased
- **Rebrand to DeckOS:** app name and window title, app ID `com.deckos.frontend` (installs next to Pegasus), placeholder icon / TV banner / splash, version numbers from DeckOS tags, data folder `deckos`. Help → About credits Pegasus Frontend; Help → Licenses lists every bundled library. The Windows test build is now `DeckOS.exe`.
- `tools/build.ps1`: a fresh (`-Clean`) build no longer fails at the qmake step.
- First push to GitHub: upstream Android build (armeabi-v7a + arm64-v8a) and the new Linux CI are green.
- Release flow: `tools/ship.ps1` + the DeckOS Android workflow — each test build is an arm64 APK on the Releases page, signed with one stable key so it installs over the previous build.
- `windows-build\` folder (next to the repo): a double-clickable Windows build, refreshed by `tools\check.ps1` every time a build passes the gate (`tools/deploy-windows.ps1`). Portable settings and a small fake library; settings survive rebuilds.
- Windows dev toolchain (Qt 5.15.2 MinGW, SDL2 2.32.10) and scripts: `tools/build.ps1`, `tools/test.ps1`, and the release gate `tools/check.ps1` (build + all unit tests). Unmodified Pegasus builds clean and passes 191/191 tests.
- New README, docs index, release-flow spec (`docs/13-release-flow.md`), GitHub issue forms.
- Phase 0: upstream Pegasus cloned into `deckos/` (DeckOS work on branch `main`, `master` mirrors upstream); docs, catalog and changelog now versioned in the repo; reference/toolchain dirs gitignored.
- `tools/bootstrap.ps1` fixed to run under Windows PowerShell 5.1 (non-ASCII dashes in a UTF-8 file without BOM broke parsing).
- Starter kit: brief, specs, references, bootstrap scripts.
