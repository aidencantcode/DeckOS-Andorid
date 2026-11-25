# rcheevos v12.5.0 (commit 1433173), hashing part only - see README.md in this folder.
# Compiled straight into the backend library.

INCLUDEPATH += $$PWD/include
DEFINES *= RC_NO_THREADS

HEADERS += \
    $$PWD/include/rc_consoles.h \
    $$PWD/include/rc_export.h \
    $$PWD/include/rc_hash.h \

SOURCES += \
    $$PWD/src/rc_compat.c \
    $$PWD/src/rhash/aes.c \
    $$PWD/src/rhash/cdreader.c \
    $$PWD/src/rhash/hash.c \
    $$PWD/src/rhash/hash_disc.c \
    $$PWD/src/rhash/hash_encrypted.c \
    $$PWD/src/rhash/hash_rom.c \
    $$PWD/src/rhash/hash_zip.c \
    $$PWD/src/rhash/md5.c \
