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

    function buildRows() {
        var r = []
        var dirs = Internal.settings.gameDirs
        r.push({ type: "section", label: "Game folders" })
        if (dirs.length === 0)
            r.push({ type: "info", label: "No game folders yet", desc: "Add the folder that holds your games or their metadata.pegasus.txt." })
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
                 activate: function () { libraryPage.pendingRemove = ""; folderPicker.open() } })

        if (isAndroid) {
            r.push({ type: "button", label: "Allow access to a folder…",
                     desc: "Android storage permission for folders on SD cards or USB drives",
                     value: function () { var n = Internal.settings.androidGrantedDirs.length; return n === 1 ? "1 folder" : n + " folders" },
                     activate: function () { Internal.settings.requestAndroidDir() } })
        }

        r.push({ type: "button", label: needsReload ? "Reload games now" : "Reload all games", accent: needsReload,
                 desc: needsReload ? "Your changes take effect after the library is reloaded" : "Scan every game folder and data source again",
                 activate: function () { libraryPage.reloadGames() } })

        r.push({ type: "section", label: "Scanning" })
        r.push({ type: "toggle", label: "Scan for games on launch",
                 desc: "Off: start faster with the games found last time",
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
        return r
    }

    // re-built whenever the folder list, Android grants or the reload hint change
    rows: (Internal.settings.gameDirs, Internal.settings.androidGrantedDirs, needsReload, providerList.count, buildRows())

    FolderPicker {
        id: folderPicker
        title: "Add a game folder"
        hint: "Open folders with A and go back with B. Choose \"Use this folder\" inside the folder that holds your games."
        onPicked: {
            Internal.settings.addGameDir(path)
            libraryPage.needsReload = true
            goToZone(1) // focus back to the settings screen
        }
        onClosed: goToZone(1)
    }
}
