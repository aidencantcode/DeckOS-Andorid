// DECKOS: Settings > Updates - DeckOS's own updates from its GitHub releases, and the installed emulators'
// (deckos.updates, Updates.h). A downloads and installs with Android's installer (or without a screen
// through PServer / root when that's on); progress shows here, on the Downloads page and in a notification.
// Emulators from the Play Store are updated there (a GitHub build can't replace them).
import QtQuick 2.15
import "parts"

DeckSettingsPage {
    id: updatesPage
    title: "Updates"

    readonly property var u: (typeof deckos !== "undefined" && deckos) ? deckos.updates : null

    function ago(ms) {
        if (!ms) return "never"
        var s = Math.max(0, (Date.now() - ms) / 1000)
        if (s < 90) return "just now"
        if (s < 3600) return Math.round(s / 60) + " min ago"
        if (s < 86400) return Math.round(s / 3600) + " h ago"
        return Math.round(s / 86400) + " days ago"
    }

    function appStatus() {
        if (!u) return ""
        var a = u.app
        if (a.state === "downloading") return "Downloading " + Math.round(a.progress * 100) + " %" + (a.size ? " of " + a.size : "")
        if (a.state === "installing") return "Android's installer is open - DeckOS restarts when it's done"
        if (a.state === "ready") return a.error || "Downloaded - A installs it"
        if (a.state === "error") return a.error
        if (a.update) return "DeckOS " + a.latest + " is out (" + new Date(a.date).toLocaleDateString(Qt.locale(), "d MMM") + (a.size ? ", " + a.size : "") + ")"
        if (a.latest) return "You have the newest version"
        return u.error || "Not checked yet"
    }

    function emuStatus(e) {
        if (e.state === "downloading") return "Downloading " + Math.round(e.progress * 100) + " %" + (e.size ? " of " + e.size : "")
        if (e.state === "installing") return "Android's installer is open"
        if (e.state === "installed") return "Updated to " + e.installedVersion
        if (e.state === "ready") return e.error || "Downloaded - A installs it"
        if (e.state === "error") return e.error
        var v = "Installed " + (e.installedVersion || "?")
        if (e.update && e.fromStore) return v + "  ·  " + e.latest + " is out - from the Play Store, update it there"
        if (e.update) return v + "  ·  " + e.latest + " is out" + (e.size ? " (" + e.size + ")" : "")
        if (e.latest) return v + "  ·  up to date"
        return v
    }

    function emuValue(e) {
        if (e.state === "downloading") return Math.round(e.progress * 100) + " %"
        if (e.state === "ready") return "Install"
        if (e.update) return e.fromStore ? "Play Store" : "Update"
        return e.latest ? "✓" : ""
    }

    function buildRows() {
        var r = []
        r.push({ type: "section", label: "DeckOS" })
        r.push({ type: "info", label: "This version", value: function () { return u ? u.appVersion : "" } })
        r.push({ type: "button", label: "Update DeckOS", accent: true,
                 desc: function () { return updatesPage.appStatus() },
                 value: function () {
                     if (!u) return ""
                     var a = u.app
                     if (a.state === "downloading") return Math.round(a.progress * 100) + " %"
                     if (a.state === "ready") return "Install"
                     return a.update ? a.latest : (a.latest ? "✓" : "")
                 },
                 enabled: function () { return !!u && (u.app.update || u.app.state === "ready") && u.app.state !== "downloading" },
                 activate: function () { u.updateApp() } })
        r.push({ type: "button", label: "Check for updates",
                 desc: function () {
                     if (!u) return ""
                     if (u.checking) return "Looking at GitHub…"
                     return "Last checked " + updatesPage.ago(u.lastCheck) + (u.error ? "  ·  " + u.error : "")
                 },
                 value: function () { return u && u.checking ? "…" : "" },
                 enabled: function () { return !!u && !u.checking },
                 activate: function () { u.check(true) } })
        r.push({ type: "toggle", label: "Check by myself",
                 desc: "When DeckOS starts and every 12 hours (GitHub allows a device 60 looks an hour)",
                 value: function () { return u ? u.autoCheck : false },
                 toggle: function () { u.autoCheck = !u.autoCheck } })
        r.push({ type: "toggle", label: "Install without Android's installer",
                 desc: function () {
                     return u && u.privileged ? "Through PServer / root: no confirmation screen; DeckOS opens again after its own update"
                                              : "Needs PServer or root, which weren't found"
                 },
                 value: function () { return u ? u.silentInstall : false },
                 enabled: function () { return !!u && u.privileged },
                 toggle: function () { u.silentInstall = !u.silentInstall } })
        r.push({ type: "button", label: "Allow DeckOS to install apps",
                 desc: function () { return u && u.canInstall ? "Allowed (Android's \"Install unknown apps\")" : "Android asks once: \"Install unknown apps\" for DeckOS" },
                 value: function () { return u && u.canInstall ? "✓" : "" },
                 enabled: function () { return !!u && !u.canInstall },
                 activate: function () { u.openInstallSettings() } })

        r.push({ type: "section", label: "Your emulators" })
        var list = u ? u.emulators : []
        var any = false
        for (var i = 0; i < list.length; i++) {
            if (!list[i].installed) continue
            any = true
            r.push((function (pkg, name) {
                function cur() {
                    var all = u.emulators
                    for (var k = 0; k < all.length; k++) if (all[k].package === pkg) return all[k]
                    return {}
                }
                return { type: "button", label: name,
                         desc: function () { return updatesPage.emuStatus(cur()) },
                         value: function () { return updatesPage.emuValue(cur()) },
                         activate: function () { var e = cur(); if (e.update || e.state === "ready") u.updateEmulator(pkg); else u.openPage(pkg) } }
            })(list[i].package, list[i].name))
        }
        if (!any)
            r.push({ type: "info", label: "No emulator from the update list is installed",
                     desc: "The Store lists the ones DeckOS can install and keep up to date" })
        r.push({ type: "button", label: "Open the Store", desc: "Every emulator DeckOS knows, to install or update",
                 activate: function () { theme.openPage(2) } })
        return r
    }

    rows: ((u ? u.emulators.length : 0), buildRows())
}
