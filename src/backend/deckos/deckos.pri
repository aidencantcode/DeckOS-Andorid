# DeckOS services
QT *= network gui-private # gui-private: QZipReader, for hashing zipped ROMs (RaMatcher)
include($$PWD/../../../thirdparty/rcheevos/rcheevos.pri)

HEADERS += \
    $$PWD/Catalog.h \
    $$PWD/DeckosApi.h \
    $$PWD/GameOverrides.h \
    $$PWD/RaMatcher.h \
    $$PWD/RomLibrary.h \
    $$PWD/Scraper.h \

SOURCES += \
    $$PWD/Catalog.cpp \
    $$PWD/DeckosApi.cpp \
    $$PWD/GameOverrides.cpp \
    $$PWD/RaMatcher.cpp \
    $$PWD/RomLibrary.cpp \
    $$PWD/Scraper.cpp \

