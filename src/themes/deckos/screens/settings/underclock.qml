// DECKOS: Settings > Underclocking - ClusterTune built into DeckOS (deckos.underclock, C++ Underclock).
// The applied profile, every profile (ClusterTune's presets for the chip and your own) with an editor
// for each CPU cluster's and the GPU's maximum clock, and ClusterTune files in and out. Quick Access's
// underclock slider uses the same profiles (Stock, the presets, and the one chosen as "Custom").
// Ported from ClusterTune 1.3.0 by Aurelio Bernal (MIT) - docs/clustertune-port.md.
import QtQuick 2.15
import "parts"

DeckSettingsPage {
    id: ucPage
    title: "Underclocking"

    readonly property var uc: (typeof deckos !== "undefined" && deckos) ? deckos.underclock : null
    readonly property bool ready: !!uc && uc.available
    property string editingId: ""       // the profile being edited ("" = the list)
    property string message: ""          // import / export / delete feedback
    property bool confirmDelete: false
    property int revision: 0             // the list's structure changed (add, delete, move)

    Component.onCompleted: { if (uc) uc.refresh(); rebuild() }
    Connections {
        target: Qt.application
        function onStateChanged() { if (Qt.application.state === Qt.ApplicationActive && ucPage.uc) ucPage.uc.refresh() }
    }

    backHandler: function () {
        if (editingId === "") return false
        closeEditor()
        return true
    }

    // --- data (read through the uc.profiles property, so values follow every change) ---------------

    function prof(id) {
        var l = uc ? uc.profiles : []
        for (var i = 0; i < l.length; i++) if (l[i].id === id) return l[i]
        return null
    }
    function activeName() { var p = uc ? prof(uc.activeId) : null; return p ? p.name : "Stock" }
    function cpuLimit(p, policy, stock) {
        var v = p && p.cpu ? p.cpu[String(policy)] : undefined
        return v !== undefined && v > 0 ? v : stock
    }
    // the next / previous selectable value; the top of the table is Stock
    function stepValue(table, value, dir) {
        var i = table.indexOf(value)
        if (i < 0) { i = 0; while (i < table.length - 1 && table[i] < value) i++ }
        return table[Math.max(0, Math.min(table.length - 1, i + dir))]
    }
    function cycleActive(dir) {
        var l = uc.profiles, i = 0
        for (var k = 0; k < l.length; k++) if (l[k].id === uc.activeId) i = k
        uc.apply(l[(i + dir + l.length) % l.length].id)
    }
    function cycleCustom(dir) {
        var ids = [""]
        var l = uc.profiles
        for (var k = 1; k < l.length; k++) ids.push(l[k].id)
        var i = Math.max(0, ids.indexOf(uc.overlayCustomId))
        uc.overlayCustomId = ids[(i + dir + ids.length) % ids.length]
    }

    function openEditor(id) {
        message = ""
        confirmDelete = false
        editingId = id
        activeItemIndex = 1
    }
    function closeEditor() {
        var back = editingId
        editingId = ""
        confirmDelete = false
        // land on the profile that was open
        Qt.callLater(function () {
            for (var i = 0; i < rows.length; i++)
                if (rows[i].profileId === back) { activeItemIndex = i; return }
        })
    }

    // --- the list ------------------------------------------------------------------------------------

    function listRows() {
        var r = []
        if (!uc) return [{ type: "info", label: "Not available in this build" }]
        r.push({ type: "section", label: "Now" })
        r.push({ type: "choice", label: "Applied profile",
                 desc: function () {
                     if (!uc.canApply) return "Needs the AYN / Retroid system service (PServer), which wasn't found"
                     return uc.status !== "" ? uc.status : "Switches right away. Quick Access has the same choice."
                 },
                 value: function () { return ucPage.activeName() },
                 enabled: function () { return uc.canApply },
                 next: function () { ucPage.cycleActive(1) }, prev: function () { ucPage.cycleActive(-1) } })
        r.push({ type: "info", label: "Chip", value: function () { return uc.chip } })
        var cl = uc.clusters
        for (var i = 0; i < cl.length; i++) {
            (function (c) {
                r.push({ type: "info", label: "CPU · " + c.label,
                         value: function () {
                             var now = ucPage.clusterNow(c.policy)
                             return uc.formatCpu(now) + " of " + uc.formatCpu(c.stock)
                         } })
            })(cl[i])
        }
        if (uc.gpu.present)
            r.push({ type: "info", label: "GPU", value: function () { return uc.formatGpu(uc.gpu.current) + " of " + uc.formatGpu(uc.gpu.stock) } })

        r.push({ type: "section", label: "Profiles" })
        var l = uc.profiles
        for (var k = 0; k < l.length; k++) {
            (function (p) {
                r.push({ type: "button", label: p.name, profileId: p.id,
                         desc: function () {
                             var q = ucPage.prof(p.id) || p
                             var tags = []
                             if (q.bundled) tags.push("ClusterTune preset")
                             if (!q.fits) tags.push("some values aren't on this chip")
                             if (q.id !== "stock" && q.id === uc.overlayCustomId) tags.push("Quick Access \"Custom\"")
                             return q.summary + (tags.length ? " · " + tags.join(" · ") : "")
                         },
                         value: function () { return uc.activeId === p.id ? "Applied" : "" },
                         activate: function () {
                             if (p.stock) { uc.apply("stock"); return }
                             ucPage.openEditor(p.id)
                         } })
            })(l[k])
        }
        r.push({ type: "button", label: "New profile", accent: true,
                 desc: "Starts from the limits in effect now",
                 activate: function () { var id = uc.createProfile(); ucPage.revision++; ucPage.openEditor(id) } })

        r.push({ type: "section", label: "Options" })
        r.push({ type: "toggle", label: "Apply again after a restart",
                 desc: "Limits reset at every restart; this puts the profile back",
                 value: function () { return uc.applyOnBoot },
                 toggle: function () { uc.applyOnBoot = !uc.applyOnBoot } })
        r.push({ type: "choice", label: "Quick Access \"Custom\"",
                 desc: "Its underclock slider's last step",
                 value: function () { var p = ucPage.prof(uc.overlayCustomId); return p ? p.name : "None" },
                 next: function () { ucPage.cycleCustom(1) }, prev: function () { ucPage.cycleCustom(-1) } })
        r.push({ type: "button", label: "Import from ClusterTune…",
                 desc: function () { return ucPage.message !== "" ? ucPage.message : "Every profile in a ClusterTune file that fits this chip" },
                 activate: function () { ucPage.message = ""; importPicker.open() } })
        r.push({ type: "button", label: "Export profiles",
                 desc: "To Downloads as a ClusterTune file - ClusterTune can import it too",
                 activate: function () {
                     var res = uc.exportFile()
                     ucPage.message = res.charAt(0) === "!" ? res.slice(1) : "Saved to " + res
                 } })
        r.push({ type: "button", label: "Restore ClusterTune presets",
                 desc: "Puts back the chip's presets that were deleted or changed",
                 activate: function () {
                     var n = uc.restorePresets()
                     ucPage.revision++
                     ucPage.message = n > 0 ? "Restored " + n + (n === 1 ? " preset" : " presets") : "The presets are all there"
                 } })
        r.push({ type: "info", label: "Based on ClusterTune 1.3.0",
                 desc: "By Aurelio Bernal, MIT License. Lower limits mean less heat, fan noise and battery use; Stock puts the chip's own back." })
        return r
    }

    function clusterNow(policy) {
        var cl = uc.clusters
        for (var i = 0; i < cl.length; i++) if (cl[i].policy === policy) return cl[i].current
        return 0
    }

    // --- one profile ---------------------------------------------------------------------------------

    function editorRows() {
        var r = []
        var p = prof(editingId)
        if (!p) return [{ type: "info", label: "That profile is gone" }]
        r.push({ type: "section", label: p.bundled ? "ClusterTune preset" : "Your profile" })
        r.push({ type: "button", label: "Apply", accent: true,
                 desc: function () {
                     if (!uc.canApply) return "Needs the AYN / Retroid system service (PServer)"
                     return uc.activeId === ucPage.editingId && uc.status !== "" ? uc.status : "Changes to an applied profile apply as you make them"
                 },
                 value: function () { return uc.activeId === ucPage.editingId ? "Applied" : "" },
                 enabled: function () { return uc.canApply },
                 activate: function () { uc.apply(ucPage.editingId) } })
        r.push({ type: "button", label: "Name",
                 value: function () { var q = ucPage.prof(ucPage.editingId); return q ? q.name : "" },
                 activate: function () { var q = ucPage.prof(ucPage.editingId); nameEntry.open(q ? q.name : "") } })

        r.push({ type: "section", label: "Maximum clocks" })
        var cl = uc.clusters
        for (var i = 0; i < cl.length; i++) {
            (function (c) {
                r.push({ type: "choice", label: "CPU · " + c.label,
                         desc: c.freqs.length + " steps, " + uc.formatCpu(c.freqs[0]) + " to " + uc.formatCpu(c.stock),
                         value: function () {
                             var v = ucPage.cpuLimit(ucPage.prof(ucPage.editingId), c.policy, c.stock)
                             return v >= c.stock ? "Stock (" + uc.formatCpu(c.stock) + ")" : uc.formatCpu(v)
                         },
                         next: function () { ucPage.stepCpu(c, 1) }, prev: function () { ucPage.stepCpu(c, -1) } })
            })(cl[i])
        }
        if (uc.gpu.present) {
            r.push({ type: "choice", label: "GPU",
                     desc: uc.gpu.freqs.length > 0 ? uc.gpu.freqs.length + " steps, " + uc.formatGpu(uc.gpu.freqs[0]) + " to " + uc.formatGpu(uc.gpu.stock)
                                                   : "This GPU lists no steps: only Stock",
                     value: function () {
                         var q = ucPage.prof(ucPage.editingId)
                         var v = q && q.gpu > 0 ? q.gpu : uc.gpu.stock
                         return v >= uc.gpu.stock ? "Stock (" + uc.formatGpu(uc.gpu.stock) + ")" : uc.formatGpu(v)
                     },
                     enabled: function () { return uc.gpu.freqs.length > 0 },
                     next: function () { ucPage.stepGpu(1) }, prev: function () { ucPage.stepGpu(-1) } })
        }

        r.push({ type: "section", label: "Profile" })
        r.push({ type: "button", label: "Move up", desc: "Its place in the list (and in Quick Access, for presets)",
                 activate: function () { uc.moveProfile(ucPage.editingId, -1); ucPage.revision++ } })
        r.push({ type: "button", label: "Move down",
                 activate: function () { uc.moveProfile(ucPage.editingId, 1); ucPage.revision++ } })
        r.push({ type: "button", label: "Duplicate",
                 activate: function () { var id = uc.duplicateProfile(ucPage.editingId); ucPage.revision++; if (id !== "") ucPage.openEditor(id) } })
        r.push({ type: "button", label: "Delete",
                 desc: function () {
                     if (ucPage.confirmDelete) return "Press A again to delete it" + (uc.activeId === ucPage.editingId ? " (the chip goes back to Stock)" : "")
                     return p.bundled ? "\"Restore ClusterTune presets\" brings it back" : "Can't be undone"
                 },
                 value: function () { return ucPage.confirmDelete ? "Sure?" : "" },
                 activate: function () {
                     if (!ucPage.confirmDelete) { ucPage.confirmDelete = true; return }
                     var gone = ucPage.editingId
                     ucPage.editingId = ""
                     ucPage.confirmDelete = false
                     uc.deleteProfile(gone)
                     ucPage.revision++
                     ucPage.activeItemIndex = 1
                 } })
        return r
    }

    function stepCpu(c, dir) {
        var cur = cpuLimit(prof(editingId), c.policy, c.stock)
        var v = stepValue(c.freqs, cur, dir)
        uc.setCpuLimit(editingId, c.policy, v >= c.stock ? 0 : v)
    }
    function stepGpu(dir) {
        var table = uc.gpu.freqs
        if (table.length === 0) return
        var q = prof(editingId)
        var cur = q && q.gpu > 0 ? q.gpu : uc.gpu.stock
        var v = stepValue(table, cur, dir)
        uc.setGpuLimit(editingId, v >= uc.gpu.stock ? 0 : v)
    }

    // rebuilt only when the list itself changes; the rows' values follow uc live
    function rebuild() { rows = editingId !== "" ? editorRows() : listRows() }
    onEditingIdChanged: rebuild()
    onRevisionChanged: rebuild()
    onReadyChanged: rebuild()

    TextEntry {
        id: nameEntry
        title: "Profile name"
        hint: "Shown here, in Quick Access and on the performance overlay."
        maxLength: 40
        onAccepted: {
            if (ucPage.uc && ucPage.editingId !== "" && text.trim() !== "") ucPage.uc.renameProfile(ucPage.editingId, text.trim())
            goToZone(1)
        }
    }

    FolderPicker {
        id: importPicker
        title: "Import ClusterTune profiles"
        hint: "In ClusterTune, export your profiles to a file first. Open folders with A, go back with B, and pick the .json file."
        filesMode: true
        fileExtensions: [".json", ".JSON", ".txt"]
        onPicked: {
            var res = ucPage.uc ? ucPage.uc.importFile(path) : "!Not available"
            ucPage.message = res.charAt(0) === "!" ? res.slice(1) : res
            ucPage.revision++
            goToZone(1)
        }
        onClosed: goToZone(1)
    }
}
