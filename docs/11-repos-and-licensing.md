# 11 — Repos, upstream sync & licensing

## Repos
- `./deckos` = git clone of `https://github.com/mmatyas/pegasus-frontend` **with full history** and submodules (`lang`, `src/themes/pegasus-theme-grid`, `thirdparty/SortFilterProxyModel`). Remotes: `upstream` = mmatyas, `origin` = owner's DeckOS repo (ask for URL).
- Work on `main`; feature branches `feat/<area>-<thing>`; merge when the smoke test + screenshot tour pass.
- **Upstream sync**: monthly or when upstream lands something relevant: `git fetch upstream && git merge upstream/master` on a branch, resolve, run full checks. Keep DeckOS changes isolated (new dirs, `// DECKOS:` markers on edited upstream lines) to keep merges small.
- New dependencies as submodules under `thirdparty/` (e.g. `rcheevos`), pinned to tags.
- `third_party_refs/` (gitignored): throwaway clones of projects you study (ES-DE, Daijishō, Lemuroid, rcheevos examples, MangoHud, Decky, Steam-ROM-Manager, BigScreenFE/StMini upstreams). Never import code from here without a license check + `DECISIONS.md` entry.

## Licenses — the rules
| Thing | License | What we may do |
|---|---|---|
| Pegasus core | **GPLv3** | Fork, modify, rename, redistribute. DeckOS as a whole must stay GPLv3, ship source (public repo), keep copyright notices and LICENSE, credit Pegasus in About. Product logos/trademarks in Pegasus assets may have extra limits (§7) — replace branding assets anyway. |
| BigScreenFE (reference) | **CC BY-NC-SA 4.0** | Not GPL-compatible (NonCommercial). **Study only.** Reimplement behavior; do not copy code or assets into DeckOS. (Its system icons come from libretro retroarch-assets under CC-BY 4.0 — if we want those icons, fetch them from the libretro source with attribution, not from BigScreenFE.) |
| StMini (reference) | none stated | All rights reserved by default. **Study only.** Contains Valve sound effects and commercial fonts (Arial, Gilroy) — never ship those. |
| rcheevos | MIT | Vendor and link; credit. |
| Qt 5.15 (LGPLv3 modules) / SDL2 (zlib) | — | Fine; list in About → licenses. |
| Emulator intent data from ES-DE / Daijishō etc. | check each | Package/activity names are facts; write our own catalog entries; don't copy their files wholesale unless the license allows and we attribute. |

## Branding removal (UI) vs. credit (legal)
- Remove "Pegasus" from: app name, launcher icon, splash, window titles, menus, default theme, user-facing logs/messages, data dir names, Android package/applicationId.
- Keep: source copyright headers, LICENSE files, About → "Based on Pegasus Frontend by Mátyás Mustoha and contributors (GPLv3)" + links.

## Trademarks / look-alike safety
- "Steam-like" layout and behavior is fine; Valve's logos, the Steam wordmark as app branding, Motiva Sans font and Steam Deck sound files are not. Use our own icons/sounds.
- Using the Steam Web API and showing "Steam" as the source of a collection is fine (it's descriptive).
- Name check before public release: make sure "DeckOS" doesn't conflict with an existing product the owner cares about (owner's call).
