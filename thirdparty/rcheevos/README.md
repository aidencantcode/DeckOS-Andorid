# rcheevos (hashing only)

From https://github.com/RetroAchievements/rcheevos, tag `v12.5.0` (commit `1433173`), MIT license (`LICENSE`).

Only the ROM hashing code is here, unmodified: `include/rc_hash.h`, `rc_consoles.h`, `rc_export.h`,
`src/rc_compat.*` and `src/rhash/`. DeckOS uses it to compute the same hash RetroArch sends to
RetroAchievements, so a game's achievements are found by its exact dump (`src/backend/deckos/RaMatcher.cpp`).

To update: copy the same files from a newer tag and update the version above, in `rcheevos.pri`
and in `CMakeLists.txt`.
