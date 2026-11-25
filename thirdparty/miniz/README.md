# miniz

From https://github.com/richgel999/miniz, release `3.0.2` (amalgamated `miniz.c` / `miniz.h`, unmodified),
MIT license (`LICENSE`).

DeckOS reads zipped ROMs with it to compute their RetroAchievements hash (`src/backend/deckos/RaMatcher.cpp`).
Qt's own `QZipReader` can't be used: it is compiled out of the Android and Linux Qt builds DeckOS uses.

Built with `MINIZ_NO_STDIO` (files are read through `QFile`, so Unicode paths work everywhere),
`MINIZ_NO_TIME` and `MINIZ_NO_ZLIB_COMPATIBLE_NAMES` (no clash with a system zlib).
