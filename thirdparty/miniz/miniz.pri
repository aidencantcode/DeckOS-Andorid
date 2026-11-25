# miniz 3.0.2 (zip reading, for hashing zipped ROMs) - see README.md in this folder.
# Compiled straight into the backend library. The defines must match wherever miniz.h is included.

DEFINES *= MINIZ_NO_STDIO MINIZ_NO_TIME MINIZ_NO_ZLIB_COMPATIBLE_NAMES

HEADERS += $$PWD/miniz.h
SOURCES += $$PWD/miniz.c
