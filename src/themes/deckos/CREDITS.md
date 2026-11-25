# DeckOS theme — credits and licensing (PRIVATE PERSONAL BUILD)

This theme is a modified combination of two third-party Pegasus themes, used by the repo owner for
**private, non-commercial, personal use only**. The APK is not for distribution. The repository is
temporarily public only so the owner's own handhelds can download test builds without signing in to GitHub;
the owner will make it private again when development ends (decisions 2026-11-25, `docs/DECISIONS.md`).

| Part | Source | Author | License |
|---|---|---|---|
| Everything outside `ra/` (screens, scripts, sounds, fonts, icons) except the files marked DeckOS below | StMini 0.4.22 (0.3.1 until build 0.0.3) | ScriptUT | None stated (all rights reserved by the author) |
| `ra/RAGameInfoSection.qml`, `ra/assets/icons/*` (its login popup and keyboard were removed in 0.1.0) | [BigScreenFE](https://github.com/ZagonAb/BigScreenFE) 1.1 | Gonzalo Abbate | CC BY-NC-SA 4.0 |

StMini additionally contains third-party assets: Steam Deck UI sounds (Valve), Arial Bold (Microsoft),
Gilroy ExtraBold (commercial font) and a Fontello icon font. None of these may be redistributed.

DeckOS changes are marked with `DECKOS:` comments. Before this project could ever be published, everything
in this folder must be replaced with original or properly licensed work.

Written for DeckOS (no third-party code): `screens/ProfileBadge.qml`, `screens/gamedata/files.qml`, `screens/gamedata/details.qml`,
`screens/settings/library.qml`, `screens/settings/profile.qml`, `screens/settings/parts/*`, and the rebuilt
`screens/settings/general.qml` / `screens/settings/system.qml`.

Outside this folder, `src/app/platform/android/assets/fonts/unispace_*.otf` is Unispace by Ray Larabie (Typodermic), released
under CC0 (public domain) and supplied by the owner for the performance overlay; it may be redistributed freely.

`screens/settings/underclock.qml` (written for DeckOS) is the page for the underclocking code ported from
[ClusterTune](https://github.com/AurelioB/ClusterTune) by Aurelio Bernal, MIT License
(`src/backend/deckos/ClusterTune-LICENSE.txt`, `docs/clustertune-port.md`).

Outside this folder, `src/frontend/assets/boot.mp4` is the Steam Deck startup animation (Valve), supplied by the
owner and re-encoded to 1080p; it falls under the same personal-use-only terms as the Deck sounds above.
