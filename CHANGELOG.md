# Changelog

One entry per build the owner tests. Newest first.

## Unreleased
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
