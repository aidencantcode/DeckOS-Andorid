// DECKOS: Settings > Collections. Every collection, hidden ones too. A opens one: show or hide it in the
// Library, rename it, and - for a ROM-folder system - pick the folder its games come from. Android apps
// are found by DeckOS itself, so that collection has no folder. Backed by deckos.collections
// (UserCollections.h) and deckos.library.linkFolder (RomLibrary.h).
import QtQuick 2.15
import QtQml 2.15
import "parts"

DeckSettingsPage {
    id: collectionsPage
    title: "Collections"

    readonly property var store: (typeof deckos !== "undefined" && deckos) ? deckos.collections : null
    readonly property var lib: (typeof deckos !== "undefined" && deckos) ? deckos.library : null

    property var list: store ? store.allCollections() : []
    function reload() { list = store ? store.allCollections() : [] }
    Connections {
        target: collectionsPage.store
        function onListChanged() { collectionsPage.reload() }
        function onChanged() { collectionsPage.reload() }
    }
    Connections {
        target: api.collections
        function onCountChanged() { collectionsPage.reload() }
    }

    // the collection opened (its name), "" = the list
    property string opened: ""
    property string message: ""
    property int returnRow: 0
    backHandler: function () {
        if (opened === "") return false
        opened = ""
        message = ""
        var row = returnRow
        Qt.callLater(function () { collectionsPage.activeItemIndex = row })
        return true
    }

    function find(name) {
        for (var i = 0; i < list.length; i++)
            if (list[i].name === name) return list[i]
        return null
    }
    function systemOf(coll) {
        if (!lib || !coll) return null
        var systems = lib.systems
        for (var i = 0; i < systems.length; i++)
            if (systems[i].id === coll.shortName) return systems[i]
        return null
    }

    function listRows() {
        var r = [{ type: "section", label: "Your library's collections" }]
        if (list.length === 0)
            r.push({ type: "info", label: "No collections yet", desc: "Add game folders in Settings › Library" })
        for (var i = 0; i < list.length; i++) {
            (function (coll) {
                r.push({ type: "button", label: coll.name,
                         desc: coll.count + (coll.count === 1 ? " game" : " games") + (coll.user ? " · made in DeckOS" : ""),
                         value: coll.hidden ? "Hidden" : "",
                         activate: function () {
                             collectionsPage.returnRow = collectionsPage.activeItemIndex
                             collectionsPage.message = ""
                             collectionsPage.opened = coll.name
                             collectionsPage.activeItemIndex = 0
                         } })
            })(list[i])
        }
        return r
    }

    function collectionRows(coll) {
        var r = [{ type: "section", label: coll.name }]
        if (message !== "")
            r.push({ type: "info", label: message })
        r.push({ type: "toggle", label: "Show in the Library",
                 desc: "Hidden: not in the Library's Collections tab or Add to collection. Its games stay in your library.",
                 value: function () { var c = collectionsPage.find(collectionsPage.opened); return !!c && !c.hidden },
                 toggle: function () {
                     var c = collectionsPage.find(collectionsPage.opened)
                     if (c) collectionsPage.store.setHidden(c.name, !c.hidden)
                 } })
        r.push({ type: "button", label: "Rename…",
                 desc: "Kept across rescans. A system keeps being recognised by DeckOS under any name.",
                 activate: function () { renameEntry.open(collectionsPage.opened) } })

        var sys = systemOf(coll)
        if (coll.shortName === "android") {
            r.push({ type: "info", label: "Games folder", desc: "Android apps are found by DeckOS itself, not in a folder",
                     value: "Installed apps" })
        } else if (sys) {
            r.push({ type: "button", label: "Games folder…",
                     desc: sys.link !== "" ? "Only this folder is read for " + sys.name
                                           : "Found by name in your ROM folders: " + (sys.folders.length ? sys.folders.join(", ") : "none"),
                     value: sys.link !== "" ? sys.link : "Automatic",
                     activate: function () { folderPicker.systemId = sys.id; folderPicker.open() } })
            if (sys.link !== "")
                r.push({ type: "button", label: "Use the folders found by name",
                         desc: "Forget the folder picked above",
                         activate: function () { collectionsPage.lib.linkFolder(sys.id, ""); collectionsPage.message = "Rescanning " + sys.name + "…" } })
        } else {
            r.push({ type: "info", label: "Games folder",
                     desc: coll.user ? "A collection you made: its games stay where they are"
                                     : "From a metadata file or another source: change it there" })
        }
        return r
    }

    rows: (lib ? lib.systems : null, list, message,
           opened !== "" && find(opened) ? collectionRows(find(opened)) : listRows())

    TextEntry {
        id: renameEntry
        title: "Rename collection"
        hint: "The new name shows everywhere. Leave it as it is to cancel."
        maxLength: 60
        onAccepted: {
            var old = collectionsPage.opened
            var clean = text.replace(/\s+/g, " ").trim()
            if (clean !== "" && clean !== old) {
                var err = collectionsPage.store.rename(old, clean)
                if (err === "") { collectionsPage.opened = clean; collectionsPage.message = "Renamed to " + clean }
                else collectionsPage.message = err
            }
            goToZone(1)
        }
    }

    FolderPicker {
        id: folderPicker
        property string systemId: ""
        title: "Games folder"
        hint: "Open folders with A, go back with B. Choose \"Use this folder\" in the folder that holds this system's games."
        onPicked: {
            collectionsPage.lib.linkFolder(systemId, path)
            collectionsPage.message = "Rescanning with " + path + "…"
            goToZone(1)
        }
        onClosed: goToZone(1)
    }
}
