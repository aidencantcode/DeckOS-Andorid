# DeckOS documentation

Design docs and specs. They describe the plan; the roadmap tracks what is actually done.

## Start here
| Doc | What's in it |
|---|---|
| [00 — Vision](00-vision.md) | What DeckOS is, who it's for, what "faithful to Steam" means, non-goals |
| [01 — Architecture](01-architecture.md) | Pegasus core at a glance, DeckOS layering (QML shell, `deckos` API, C++ services, Android side) |
| [02 — Roadmap](02-roadmap.md) | Phases 0–7 with checkboxes — the current state of the project |
| [DECISIONS](DECISIONS.md) | Every non-obvious choice: what, why, alternatives |

## Working on DeckOS
| Doc | What's in it |
|---|---|
| [03 — Dev loop](03-dev-loop.md) | PC builds, automated checks, smoke test, screenshot tour, fixtures |
| [13 — Release flow](13-release-flow.md) | Windows test gate → GitHub → Android test build; version numbers; signing |
| [11 — Repos & licensing](11-repos-and-licensing.md) | Upstream sync, what may be reused from where, branding vs. credit |

## Feature specs
| Doc | Area |
|---|---|
| [04 — Library & scanning](04-library-and-scanning.md) | Setup wizard, ROM folder scanning, metadata |
| [05 — Emulators & launching](05-emulators-and-launching.md) | Emulator catalog, auto-detection, launch commands |
| [06 — RetroAchievements](06-retroachievements.md) | Account, hashing, Achievements tab |
| [07 — Scraping](07-scraping.md) | Art/metadata providers, queues, artwork picker |
| [08 — Steam & playtime](08-steam-and-playtime.md) | Steam profile link, playtime tracking |
| [09 — Overlays](09-overlays.md) | Performance overlay, in-game quick menu |
| [10 — UI design](10-ui-design.md) | Look, layout, navigation, screens |
| [12 — QoL backlog](12-qol-backlog.md) | Ideas waiting for a slot |
