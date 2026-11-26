// DECKOS: Settings > Emulators - which emulator runs each system DeckOS found in your ROM folders,
// and its launch command (visible and editable, with a way back to the default).
import QtQuick 2.15
import "parts"

DeckSettingsPage {
    id: emuPage

    readonly property var lib: (typeof deckos !== "undefined" && deckos) ? deckos.library : null
    // "" = the list of systems, otherwise the system being edited
    property string systemId: ""
    readonly property var current: {
        if (!lib || systemId === "") return null
        var list = lib.systems
        for (var i = 0; i < list.length; i++)
            if (list[i].id === systemId) return list[i]
        return null
    }

    title: current ? current.name : "Emulators"
    backHandler: function () {
        if (systemId === "") return false
        var back = systemId
        systemId = ""
        // put the cursor back on the system we came from
        Qt.callLater(function () {
            for (var i = 0; i < emuPage.rows.length; i++)
                if (emuPage.rows[i].systemId === back) { emuPage.activeItemIndex = i; break }
        })
        return true
    }

    function shortText(text, n) {
        var t = String(text || "")
        return t.length > n ? t.substring(0, n) + "…" : t
    }

    // DECKOS: "Scan installed emulators" - what's on the device, with or without ROM folders
    property var installed: null // null = not scanned yet
    function installedRows(r) {
        r.push({ type: "section", label: "Installed emulators" })
        r.push({ type: "button", label: "Scan installed emulators",
                 desc: "Find the emulators on this device that DeckOS knows, even before any ROM folder is added",
                 value: function () { return emuPage.installed === null ? "" : emuPage.installed.length + " found" },
                 activate: function () { emuPage.installed = lib ? lib.installedEmulators() : [] } })
        if (installed === null)
            return
        if (installed.length === 0)
            r.push({ type: "info", label: "None found",
                     desc: Qt.platform.os === "android" ? "No emulator from DeckOS's list is installed" : "Emulator apps are only found on Android" })
        for (var i = 0; i < installed.length; i++)
            r.push({ type: "info", label: installed[i].name, desc: "Runs " + installed[i].systems.join(", "),
                     value: installed[i].package })
    }

    function systemRows() {
        var r = []
        var list = lib ? lib.systems : []
        if (list.length === 0) {
            r.push({ type: "info", label: "No systems found yet",
                     desc: "Add your ROM folder in Settings > Library, then come back here" })
            r.push({ type: "button", label: "Open Library settings",
                     activate: function () { if (theme) theme.openSettingsPage("settings/library.qml") } })
            if (lib) installedRows(r)
            return r
        }
        r.push({ type: "section", label: "Your systems" })
        for (var i = 0; i < list.length; i++) {
            (function (sys) {
                r.push({ type: "button", label: sys.name, systemId: sys.id,
                         desc: sys.games + (sys.games === 1 ? " game" : " games") + "  ·  " + (sys.customCommand !== "" ? "custom command" : sys.emulatorName),
                         value: function () { return sys.customCommand !== "" || sys.installed ? "" : "Not installed" },
                         activate: function () { emuPage.systemId = sys.id; emuPage.activeItemIndex = 0 } })
            })(list[i])
        }
        installedRows(r)
        return r
    }

    function emulatorRows() {
        var r = []
        var sys = current
        if (!sys) return r
        r.push({ type: "section", label: "Emulator" })
        r.push({ type: "button", label: "Automatic",
                 desc: "An installed emulator, RetroArch's recommended core first",
                 value: function () { return current && current.automatic ? "✓" : "" },
                 activate: function () { lib.setEmulator(sys.id, "") } })
        var emus = lib.emulatorsFor(sys.id)
        for (var i = 0; i < emus.length; i++) {
            (function (emu) {
                r.push({ type: "button", label: emu.name,
                         desc: (emu.installed ? "Installed" : "Not installed") + (emu.achievements ? "  ·  RetroAchievements" : ""),
                         value: function () { return current && !current.automatic && current.emulatorId === emu.id ? "✓" : "" },
                         activate: function () { lib.setEmulator(sys.id, emu.id) } })
            })(emus[i])
        }
        r.push({ type: "section", label: "Launch command" })
        r.push({ type: "button", label: "Edit launch command…",
                 desc: function () { return current ? emuPage.shortText(current.command, 110) : "" },
                 activate: function () { commandEntry.open(current ? current.command : "") } })
        r.push({ type: "button", label: "Use the emulator's own command",
                 enabled: function () { return !!current && current.customCommand !== "" },
                 activate: function () { lib.setCustomCommand(sys.id, "") } })
        return r
    }

    rows: (systemId, installed, lib ? lib.systems : null, systemId === "" ? systemRows() : emulatorRows())

    TextEntry {
        id: commandEntry
        title: "Launch command"
        hint: "{file.path} = the game's file, {file.uri} = a content:// link to it. Clear (X) and save to undo."
        multiline: true
        maxLength: 1200
        onAccepted: {
            if (emuPage.lib && emuPage.current && text.trim() !== emuPage.current.command.trim())
                emuPage.lib.setCustomCommand(emuPage.systemId, text)
            goToZone(1)
        }
    }
}
