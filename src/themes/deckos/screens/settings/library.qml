// DECKOS: Settings > Library - Pegasus's game folder, data source and scanning settings, Steam-style.
import QtQuick 2.15
import QtQml 2.15
import "parts"

DeckSettingsPage {
    id: libraryPage
    title: "Library"

    readonly property bool isAndroid: Qt.platform.os === "android"
    // set after folders or data sources change: the library is only re-read on "Reload games"
    property bool needsReload: false
    // a folder row asks for a second A press before it is removed
    property string pendingRemove: ""

    // Providers is a model without get(); mirror it into objects the rows can call
    Instantiator {
        id: providerList
        model: Internal.settings.providers
        delegate: QtObject {
            readonly property string name: model.name
            readonly property bool enabled: model.enabled
            function setEnabled(v) { model.enabled = v }
        }
    }

    function reloadGames() {
        needsReload = false
        Internal.settings.reloadProviders() // rescans; the interface reloads when it finishes
    }

    readonly property var lib: (typeof deckos !== "undefined" && deckos) ? deckos.library : null

    function romFolderRows(r) {
        var roms = lib.romFolders
        r.push({ type: "section", label: "ROM folders" })
        if (roms.length === 0)
            r.push({ type: "info", label: "No ROM folders yet",
                     desc: "Pick the folder with your system folders (snes, gba, psx…). Nothing is written into it." })
        for (var i = 0; i < roms.length; i++) {
            (function (dir) {
                r.push({
                    type: "button", label: dir,
                    desc: function () { return libraryPage.pendingRemove === "rom:" + dir ? "Press A again to remove this folder" : "" },
                    value: function () { return libraryPage.pendingRemove === "rom:" + dir ? "Remove" : "" },
                    activate: function () {
                        if (libraryPage.pendingRemove !== "rom:" + dir) { libraryPage.pendingRemove = "rom:" + dir; return }
                        libraryPage.pendingRemove = ""
                        lib.removeRomFolder(dir)
                    }
                })
            })(roms[i])
        }
        r.push({ type: "button", label: "Add a ROM folder…", accent: true,
                 desc: "DeckOS finds the systems by folder name and picks an emulator for each",
                 activate: function () { libraryPage.pendingRemove = ""; folderPicker.target = "rom"; folderPicker.open() } })
        r.push({ type: "button", label: "Scan ROM folders",
                 desc: function () { return lib.status !== "" ? lib.status : "Find new and removed games" },
                 value: function () { return lib.scanning ? "Scanning…" : "" },
                 enabled: function () { return lib.romFolders.length > 0 && !lib.scanning },
                 activate: function () { lib.scan([]) } })
        r.push({ type: "button", label: "Rescan one system…",
                 desc: "Only that system's folder is read again",
                 enabled: function () { return lib.systems.length > 0 && !lib.scanning },
                 activate: function () { libraryPage.returnRow = libraryPage.activeItemIndex; libraryPage.pickingSystem = true; libraryPage.activeItemIndex = 0 } })
        r.push({ type: "toggle", label: "Look for new ROMs on start",
                 desc: "A quick check in the background after DeckOS starts",
                 value: function () { return lib.scanOnStart },
                 toggle: function () { lib.scanOnStart = !lib.scanOnStart } })
        r.push({ type: "button", label: "Emulators…",
                 desc: "Which emulator runs each system, and its launch command",
                 activate: function () { if (theme) theme.openSettingsPage("settings/emulators.qml") } })
    }

    // "Rescan one system": the page shows the systems instead of the settings until one is picked or B
    property bool pickingSystem: false
    backHandler: function () {
        if (pickingSystem) { pickingSystem = false; restoreRow(); return true }
        return false
    }

    // the row a picker was opened from, focused again when it closes (after the rows are rebuilt)
    property int returnRow: 0
    function restoreRow() {
        var row = returnRow
        Qt.callLater(function () { libraryPage.activeItemIndex = row })
    }

    function systemPickRows() {
        var r = [{ type: "section", label: "Rescan which system?" }]
        var list = lib.systems
        for (var i = 0; i < list.length; i++) {
            (function (sys) {
                r.push({ type: "button", label: sys.name, desc: sys.games + (sys.games === 1 ? " game" : " games"),
                         activate: function () { libraryPage.pickingSystem = false; libraryPage.restoreRow(); lib.scan([sys.id]) } })
            })(list[i])
        }
        return r
    }

    function buildRows() {
        var r = []
        if (lib && pickingSystem)
            return systemPickRows()
        if (lib)
            romFolderRows(r)
        var dirs = Internal.settings.gameDirs
        r.push({ type: "section", label: lib ? "Metadata folders" : "Game folders" })
        if (dirs.length === 0)
            r.push({ type: "info", label: "No metadata folders",
                     desc: "Only needed for folders that already have a metadata.pegasus.txt (from Pegasus or other tools)." })
        for (var i = 0; i < dirs.length; i++) {
            (function (dir) {
                r.push({
                    type: "button", label: dir,
                    desc: function () { return libraryPage.pendingRemove === dir ? "Press A again to remove this folder" : "" },
                    value: function () { return libraryPage.pendingRemove === dir ? "Remove" : "" },
                    activate: function () {
                        if (libraryPage.pendingRemove !== dir) { libraryPage.pendingRemove = dir; return }
                        libraryPage.pendingRemove = ""
                        Internal.settings.removeGameDirs([dirs.indexOf(dir)])
                        libraryPage.needsReload = true
                    }
                })
            })(dirs[i])
        }
        r.push({ type: "button", label: "Add a game folder…", accent: true,
                 activate: function () { libraryPage.pendingRemove = ""; folderPicker.target = "game"; folderPicker.open() } })

        if (isAndroid) {
            r.push({ type: "button", label: "Allow access to a folder…",
                     desc: "Android storage permission for folders on SD cards or USB drives",
                     value: function () { var n = Internal.settings.androidGrantedDirs.length; return n === 1 ? "1 folder" : n + " folders" },
                     activate: function () { Internal.settings.requestAndroidDir() } })
        }

        r.push({ type: "button", label: needsReload ? "Reload games now" : "Refresh library", accent: needsReload,
                 desc: needsReload ? "Your changes take effect after the library is reloaded"
                                   : "Quick: finds new and removed games, re-reads only what changed",
                 activate: function () {
                     if (libraryPage.needsReload || typeof deckos === "undefined" || !deckos) libraryPage.reloadGames()
                     else deckos.refreshLibrary()
                 } })
        r.push({ type: "button", label: "Full rescan",
                 desc: "Read every game folder and data source again (slow on big libraries)",
                 activate: function () { libraryPage.reloadGames() } })

        r.push({ type: "section", label: "Scanning" })
        r.push({ type: "toggle", label: "Full scan on every start",
                 desc: "Off (faster): start from the saved game list - new or deleted ROMs are still noticed",
                 value: function () { return Internal.settings.scanOnLaunch },
                 toggle: function () { Internal.settings.scanOnLaunch = !Internal.settings.scanOnLaunch } })
        r.push({ type: "toggle", label: "Check that game files exist",
                 desc: "Hide games whose files were moved or deleted",
                 value: function () { return Internal.settings.verifyFiles },
                 toggle: function () { Internal.settings.verifyFiles = !Internal.settings.verifyFiles } })
        r.push({ type: "toggle", label: "Show missing games",
                 desc: "List games whose files are missing anyway (greyed out)",
                 enabled: function () { return Internal.settings.verifyFiles },
                 value: function () { return Internal.settings.showMissingGames },
                 toggle: function () { Internal.settings.showMissingGames = !Internal.settings.showMissingGames } })

        r.push({ type: "section", label: "Data sources" })
        for (var p = 0; p < providerList.count; p++) {
            (function (prov) {
                if (!prov) return
                r.push({ type: "toggle", label: prov.name,
                         value: function () { return prov.enabled },
                         toggle: function () { prov.setEnabled(!prov.enabled); libraryPage.needsReload = true } })
            })(providerList.objectAt(p))
        }

        if (media) {
            // DECKOS: the DeckOS folder (MediaLibrary) - media, keys.txt and the log in one place
            r.push({ type: "section", label: "DeckOS folder" })
            r.push({ type: "button", label: media.folderSet ? "DeckOS folder" : "Choose a DeckOS folder",
                     desc: function () {
                         if (libraryPage.folderMessage !== "") return libraryPage.folderMessage
                         return media.folderSet ? "Artwork, trailers, your own pictures, keys.txt and the log. Choosing another moves the media along."
                                                : "Where artwork, trailers, your own pictures, keys.txt and the log go"
                     },
                     value: function () { return media.folderSet ? media.folder : "Not set" },
                     activate: function () { libraryPage.folderMessage = ""; mediaPicker.open() } })
        }

        // DECKOS: scraping has its own tab now (settings/scraping.qml)
        r.push({ type: "section", label: "Artwork and game info" })
        r.push({ type: "button", label: "Scraping…",
                 desc: "Scrape and re-scrape artwork, the sources and the API keys",
                 activate: function () { if (theme) theme.openSettingsPage("settings/scraping.qml") } })
        return r
    }

    readonly property var media: (typeof deckos !== "undefined" && deckos) ? deckos.media : null
    property string folderMessage: ""

    function useFolder(path) {
        var err = media.setFolder(path)
        folderMessage = err !== "" ? err : "Using " + path
        if (err === "" && typeof theme !== "undefined" && theme) theme.importKeysIfChanged()
        goToZone(1)
    }


    // re-built whenever the folder list, Android grants or the reload hint change
    rows: (Internal.settings.gameDirs, Internal.settings.androidGrantedDirs, needsReload, providerList.count,
           media ? media.folder : "", buildRows())

    // DECKOS: the DeckOS folder: pick one, or make a new one in the folder shown
    FolderPicker {
        id: mediaPicker
        title: "Choose your DeckOS folder"
        hint: "Open folders with A, go back with B. \"Use this folder\" keeps everything in the folder shown; \"New folder here\" makes one in it. Media saved so far moves along."
        allowNewFolder: true
        startFolder: libraryPage.media ? libraryPage.media.defaultParent : ""
        onPicked: libraryPage.useFolder(path)
        onNewFolderRequested: { folderName.parentPath = parentPath; folderName.open("DeckOS") }
        onClosed: goToZone(1)
    }
    TextEntry {
        id: folderName
        property string parentPath: ""
        title: "Name your DeckOS folder"
        hint: "It's made in " + parentPath + ". Done, B or Start creates it."
        maxLength: 60
        onAccepted: {
            if (text.trim() === "") { mediaPicker.forceActiveFocus(); return }
            var path = libraryPage.media.makeFolder(parentPath, text)
            mediaPicker.visible = false
            if (path === "") { libraryPage.folderMessage = "Couldn't create \"" + text + "\""; goToZone(1); return }
            libraryPage.useFolder(path)
        }
    }

    FolderPicker {
        id: folderPicker
        property string target: "game" // "game": metadata folder, "rom": ROM folder to scan
        title: target === "rom" ? "Add a ROM folder" : "Add a metadata folder"
        hint: target === "rom"
              ? "Open folders with A, go back with B. Choose \"Use this folder\" in the folder that contains your system folders (snes, gba, psx…) - or in one system folder."
              : "Open folders with A and go back with B. Choose \"Use this folder\" in the folder that has a metadata.pegasus.txt."
        onPicked: {
            if (target === "rom" && libraryPage.lib) {
                libraryPage.lib.addRomFolder(path) // scans right away
            } else {
                Internal.settings.addGameDir(path)
                libraryPage.needsReload = true
            }
            goToZone(1) // focus back to the settings screen
        }
        onClosed: goToZone(1)
    }
}
