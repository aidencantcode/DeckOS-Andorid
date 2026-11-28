// DECKOS: the Store - emulators DeckOS knows how to get and keep up to date (deckos.updates and its
// catalog, catalog/emulator-sources.json), plus DeckOS itself. ALL / INSTALLED / UPDATES with LB / RB.
// A installs or updates (download with progress, then Android's installer), X opens its page, Y looks for
// new versions. Play Store apps are updated in the Play Store; emulators without a download DeckOS can
// install (Dolphin, DuckStation...) open their website.
import QtQuick 2.15
import "../settings/parts"

FocusScope {
    id: store
    focus: true
    property var theme

    readonly property var u: (typeof deckos !== "undefined" && deckos) ? deckos.updates : null
    property int tab: 0 // 0 all, 1 installed, 2 updates
    property int current: 0

    readonly property var all: u ? u.emulators : []
    readonly property var appRow: u ? u.app : ({})
    readonly property var rows: {
        var out = []
        var a = appRow
        if (tab === 0 || (tab === 1) || (tab === 2 && (a.update || a.state === "ready" || a.state === "downloading")))
            out.push({ isApp: true, data: a })
        for (var i = 0; i < all.length; i++) {
            var e = all[i]
            if (tab === 1 && !e.installed) continue
            if (tab === 2 && !(e.update || e.state === "ready" || e.state === "downloading")) continue
            out.push({ isApp: false, data: e })
        }
        return out
    }
    readonly property int installedCount: { var n = 0; for (var i = 0; i < all.length; i++) if (all[i].installed) n++; return n }
    readonly property int updateCount: (u && u.app.update ? 1 : 0) + (u ? u.emulatorUpdates.length : 0)

    onRowsChanged: if (current >= rows.length) current = Math.max(0, rows.length - 1)
    Component.onCompleted: if (u && Date.now() - u.lastCheck > 60 * 60 * 1000) u.check(false)

    function ago(ms) {
        if (!ms) return ""
        var s = Math.max(0, (Date.now() - ms) / 1000)
        if (s < 3600) return "just now"
        if (s < 86400) return Math.round(s / 3600) + " h ago"
        var d = Math.round(s / 86400)
        return d === 1 ? "yesterday" : d + " days ago"
    }

    function lineFor(r) {
        var e = r.data
        if (e.state === "downloading") return "Downloading  " + Math.round(e.progress * 100) + " %" + (e.size ? "  of " + e.size : "")
        if (e.state === "installing") return "Android's installer is open"
        if (e.state === "ready") return e.error || "Downloaded - A installs it"
        if (e.state === "error") return e.error
        if (r.isApp) return "This build " + e.installedVersion + (e.update ? "  ·  " + e.latest + " is out" : e.latest ? "  ·  up to date" : "")
        if (e.installed) {
            var v = "Installed " + (e.installedVersion || "?")
            if (e.update) return v + "  ·  " + e.latest + " is out" + (e.fromStore ? " (Play Store)" : "")
            return v + (e.latest ? "  ·  up to date" : "")
        }
        if (e.canInstall) return "Newest " + (e.latest || "…") + (e.size ? "  ·  " + e.size : "")
        return e.latest ? "Newest " + e.latest + "  ·  from its website" : "From its website"
    }

    function actionFor(r) {
        var e = r.data
        if (e.state === "downloading") return Math.round(e.progress * 100) + " %"
        if (e.state === "ready") return "Install"
        if (e.state === "installing") return "…"
        if (r.isApp) return e.update ? "Update" : "Up to date"
        if (e.installed) return e.update ? (e.fromStore ? "Play Store" : "Update") : "Up to date"
        return e.canInstall ? "Install" : "Website"
    }

    function act(r) {
        if (!u || !r) return
        var e = r.data
        if (e.state === "downloading") { u.cancel(r.isApp ? "app" : e.package); return }
        if (r.isApp) { if (e.update || e.state === "ready") u.updateApp(); else u.check(true); return }
        if (e.installed && !e.update && e.state !== "ready") { u.openPage(e.package); return }
        u.updateEmulator(e.package)
    }

    function sound(s) { try { s.stop(); s.play() } catch (e) {} }

    Keys.onPressed: {
        if (event.key === Qt.Key_Up) {
            if (current > 0) { current--; sound(sNav) }
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            if (current < rows.length - 1) { current++; sound(sNav) }
            event.accepted = true
        } else if (api.keys.isPrevPage(event) || api.keys.isNextPage(event)) {
            var t = Math.max(0, Math.min(2, tab + (api.keys.isPrevPage(event) ? -1 : 1)))
            if (t !== tab) { tab = t; current = 0; sound(sTab) }
            event.accepted = true
        } else if (api.keys.isAccept(event) && !event.isAutoRepeat) {
            sound(sAccept)
            act(rows[current])
            event.accepted = true
        } else if (api.keys.isDetails(event) && !event.isAutoRepeat) {
            var r = rows[current]
            if (r && !r.isApp && u) u.openPage(r.data.package)
            event.accepted = true
        } else if (api.keys.isFilters(event) && !event.isAutoRepeat) {
            if (u) u.check(true)
            event.accepted = true
        }
    }

    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 70; rightMargin: 70; topMargin: 125 }
        spacing: 8
        Text {
            text: "Store"
            color: "white"
            font.family: bold.name
            font.pixelSize: 46
        }
        Text {
            width: parent.width
            text: "Emulators DeckOS installs and keeps up to date" + (u && u.lastCheck ? "  ·  checked " + store.ago(u.lastCheck) : "")
                  + (u && u.checking ? "  ·  looking…" : "") + (u && u.error ? "  ·  " + u.error : "")
            color: "#8F98A3"
            elide: Text.ElideRight
            font.pixelSize: 20
        }
    }

    Row {
        id: tabs
        anchors { left: parent.left; leftMargin: 64; top: head.bottom; topMargin: 22 }
        spacing: 14
        Repeater {
            model: [ "ALL  " + (store.all.length + 1), "INSTALLED  " + (store.installedCount + 1), "UPDATES  " + store.updateCount ]
            Rectangle {
                width: tabText.implicitWidth + 44
                height: 54
                radius: 27
                color: store.tab === index ? "white" : "#252930"
                Text {
                    id: tabText
                    anchors.centerIn: parent
                    text: modelData
                    color: store.tab === index ? "black" : "white"
                    font.family: bold.name
                    font.pixelSize: 20
                }
                MouseArea { anchors.fill: parent; onClicked: { store.tab = index; store.current = 0 } }
            }
        }
    }
    Text {
        anchors { right: parent.right; rightMargin: 70; verticalCenter: tabs.verticalCenter }
        text: "LB / RB  tabs     Y  check     X  website"
        color: "#7C8692"
        font.pixelSize: 18
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: tabs.bottom; bottom: parent.bottom
                  leftMargin: 64; rightMargin: 64; topMargin: 24; bottomMargin: 110 }
        clip: true
        spacing: 12
        model: store.rows
        currentIndex: store.current
        interactive: false
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height - 130
        highlightMoveDuration: 180
        highlightMoveVelocity: -1
        delegate: DeckListRow {
            width: list.width
            readonly property var e: modelData.data
            title: modelData.isApp ? "DeckOS" : (e.name || "")
            letter: modelData.isApp ? "D" : ""
            icon: !modelData.isApp && e.installed ? "image://androidicons/" + e.package : ""
            line: store.lineFor(modelData)
            lineColor: e.state === "error" ? "#F2A73B" : (e.update ? "#8BD86F" : "#AEB6C0")
            subline: e.date ? "Released " + store.ago(e.date) : (modelData.isApp ? "" : (e.package || ""))
            action: store.actionFor(modelData)
            actionAccent: e.update || e.state === "ready" || (!e.installed && e.canInstall && !modelData.isApp)
            progress: e.state === "downloading" ? (e.progress > 0 ? e.progress : -1) : -2
            focused: store.activeFocus && index === store.current
            dim: !modelData.isApp && !e.installed && !e.canInstall
            onClicked: { if (store.current === index) store.act(modelData); else store.current = index }
        }
    }

    Text {
        visible: store.rows.length === 0
        anchors.centerIn: list
        text: store.tab === 2 ? "Everything is up to date" : "Nothing here"
        color: "#8F98A3"
        font.family: bold.name
        font.pixelSize: 28
    }
}
