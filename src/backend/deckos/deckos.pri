# DeckOS services
QT *= network
include($$PWD/../../../thirdparty/rcheevos/rcheevos.pri)
include($$PWD/../../../thirdparty/miniz/miniz.pri)

HEADERS += \
    $$PWD/Catalog.h \
    $$PWD/DeckosApi.h \
    $$PWD/GameOverrides.h \
    $$PWD/InGame.h \
    $$PWD/RaMatcher.h \
    $$PWD/RomLibrary.h \
    $$PWD/Scraper.h \
    $$PWD/ClusterTunePresets.h \
    $$PWD/Underclock.h \
    $$PWD/UnderclockCore.h \

SOURCES += \
    $$PWD/Catalog.cpp \
    $$PWD/DeckosApi.cpp \
    $$PWD/GameOverrides.cpp \
    $$PWD/InGame.cpp \
    $$PWD/RaMatcher.cpp \
    $$PWD/RomLibrary.cpp \
    $$PWD/Scraper.cpp \
    $$PWD/Underclock.cpp \
    $$PWD/UnderclockCore.cpp \

