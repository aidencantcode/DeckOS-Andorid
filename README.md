# DeckOS

**A Steam Deck–style game frontend for Android gaming handhelds.**
One controller-first home for your retro ROMs, standalone emulators, PC-on-Android launchers and your Steam library — with Steam-style game pages, achievements, artwork and playtime for everything.

[![License: GPLv3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE.md)
![Status: pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange.svg)
![Platform: Android](https://img.shields.io/badge/platform-Android%20handhelds-3ddc84.svg)

> **Personal build — not for general use.** This repository is public for now only so the owner can install test builds on several handhelds; it will go private again when development ends. The APKs are for the owner's own devices: the interface is built on the StMini theme and BigScreenFE's RetroAchievements panel, which may not be redistributed (see [`src/themes/deckos/CREDITS.md`](src/themes/deckos/CREDITS.md)). Please don't fork it, mirror it or share the builds. Test builds appear on the [Releases](../../releases) page once they pass testing.

---

## What it will be

| | |
|---|---|
| 🎮 **Feels like Game Mode** | Home with a recent-games shelf over hero art, a tabbed Library, big game pages with Play button, stats and tabs, a Quick Access menu, button hints, toasts. Fully usable with a gamepad — no touch needed. |
| 🏆 **RetroAchievements** | Per-game Achievements tab, Steam-style, matched by real ROM hashes (rcheevos), not by guessing titles. |
| 🖼️ **One-click artwork** | SteamGridDB first, plus ScreenScraper, IGDB, libretro-thumbnails and more. Pick per game, or scrape the whole library with separate fast (art) and heavy (video) queues. |
| 📂 **Easy setup** | First-run wizard: point it at your ROM folder, it detects systems and installed emulators and writes the metadata for you. |
| 🔧 **Open for tinkerers** | Every launch command is visible and editable, with "Launch with…", custom emulators, Pegasus metadata files and custom themes still supported. |
| 🟦 **Steam profile** | Link a public Steam profile: library, playtime and achievements alongside your other games. |
| ⏱️ **Playtime & overlays** | Playtime tracking for everything you launch, a performance overlay and an in-game quick menu (where Android allows it). |

The full plan lives in [`docs/`](docs/README.md) — start with the [vision](docs/00-vision.md) and the [roadmap](docs/02-roadmap.md).

## Devices

Built and tested for the **AYN Odin 3 Max** (1080p, 16:9) and the **Retroid Pocket Classic** (1240×1080, near-square). Both layouts are first-class. Other Android devices with a gamepad should work but are not tested yet.

## Installing a test build

1. On the handheld, open this repo's [**Releases**](../../releases) page and download the newest `DeckOS_<version>_<commit>_arm64.apk`.
2. Open the file and allow installing from your browser/file manager if Android asks.
3. Later builds install **over** the previous one — settings and data are kept.

DeckOS has its own app ID (`com.deckos.frontend`), so it installs next to Pegasus without touching it.

Found a bug? Open a [**Test report**](../../issues/new/choose) — it asks for exactly what's needed to fix it.

## Versions

Builds are numbered `0.<phase>.<build>` — e.g. `0.1.4` is the 4th test build of Phase 1. See [docs/13-release-flow.md](docs/13-release-flow.md) for how builds are tested on PC, shipped and signed, and [CHANGELOG.md](CHANGELOG.md) for what changed in each one.

## Building from source

DeckOS is C++/Qt 5.15/QML. Android APKs are built by GitHub Actions; the Windows build exists for fast development and testing.

```sh
git clone --recursive <this repo>
cd DeckOS && mkdir build && cd build
qmake .. USE_SDL_GAMEPAD=1 USE_SDL_POWER=1   # plus SDL_LIBS / SDL_INCLUDES for your SDL2
make            # mingw32-make on Windows
make check      # unit tests
```

On Windows, with the toolchain from [DECISIONS.md](docs/DECISIONS.md) in `../toolchain/`, the scripts do all of this — `tools\check.ps1` builds and runs every test (it is the gate a build must pass before it ships).

Exact toolchain versions and every non-obvious choice are recorded in [docs/DECISIONS.md](docs/DECISIONS.md); the PC/Android dev loop is in [docs/03-dev-loop.md](docs/03-dev-loop.md).

## Credits

DeckOS is a heavily modified fork of **[Pegasus Frontend](https://github.com/mmatyas/pegasus-frontend)** by Mátyás Mustoha and contributors — a fantastic, customizable frontend. Its core (game library, metadata format, theme API, launching) is the foundation everything here is built on. If you like DeckOS, consider [supporting Pegasus](https://pegasus-frontend.org) too.

The interface is **StMini** 0.3.1 by ScriptUT, and the RetroAchievements panel comes from **[BigScreenFE](https://github.com/ZagonAb/BigScreenFE)** by Gonzalo Abbate (CC BY-NC-SA 4.0), both modified for DeckOS.

Third-party libraries are listed in the app under *Settings → About → Open-source licenses*.

DeckOS is an independent project. It is not affiliated with or endorsed by Valve Corporation; "Steam" and "Steam Deck" are trademarks of Valve, used here only to describe compatibility and inspiration. All other trademarks belong to their respective owners. DeckOS never downloads games or BIOS files.

## License

DeckOS is free software under the **GNU General Public License v3** — see [LICENSE.md](LICENSE.md). As in upstream Pegasus, some included assets such as product logos and symbols may have additional usage restrictions, and trademark usage may be limited as per §7 of the GPLv3.
