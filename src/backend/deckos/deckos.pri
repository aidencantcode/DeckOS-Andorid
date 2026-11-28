# DeckOS services
QT *= network
include($$PWD/../../../thirdparty/rcheevos/rcheevos.pri)
include($$PWD/../../../thirdparty/miniz/miniz.pri)

HEADERS += \
    $$PWD/Catalog.h \
    $$PWD/DeckosApi.h \
    $$PWD/DeviceDownloads.h \
    $$PWD/Feeds.h \
    $$PWD/GameOverrides.h \
    $$PWD/ImageCache.h \
    $$PWD/InGame.h \
    $$PWD/LibraryStats.h \
    $$PWD/MediaLibrary.h \
    $$PWD/RaMatcher.h \
    $$PWD/RomLibrary.h \
    $$PWD/Scraper.h \
    $$PWD/ClusterTunePresets.h \
    $$PWD/Underclock.h \
    $$PWD/UnderclockCore.h \
    $$PWD/Updates.h \
    $$PWD/UserCollections.h \
    $$PWD/Web.h \

SOURCES += \
    $$PWD/Catalog.cpp \
    $$PWD/DeckosApi.cpp \
    $$PWD/DeviceDownloads.cpp \
    $$PWD/Feeds.cpp \
    $$PWD/GameOverrides.cpp \
    $$PWD/ImageCache.cpp \
    $$PWD/InGame.cpp \
    $$PWD/LibraryStats.cpp \
    $$PWD/MediaLibrary.cpp \
    $$PWD/RaMatcher.cpp \
    $$PWD/RomLibrary.cpp \
    $$PWD/Scraper.cpp \
    $$PWD/Underclock.cpp \
    $$PWD/UnderclockCore.cpp \
    $$PWD/Updates.cpp \
    $$PWD/UserCollections.cpp \
    $$PWD/Web.cpp \

