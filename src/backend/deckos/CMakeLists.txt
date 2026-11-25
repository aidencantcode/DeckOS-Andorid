# DeckOS services (keep in step with deckos.pri)
target_sources(pegasus-backend PRIVATE
    Catalog.cpp
    Catalog.h
    ClusterTunePresets.h
    DeckosApi.cpp
    DeckosApi.h
    GameOverrides.cpp
    GameOverrides.h
    InGame.cpp
    InGame.h
    RaMatcher.cpp
    RaMatcher.h
    RomLibrary.cpp
    RomLibrary.h
    Scraper.cpp
    Scraper.h
    Underclock.cpp
    Underclock.h
    UnderclockCore.cpp
    UnderclockCore.h
)
