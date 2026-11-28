// DECKOS: Downloads - DeckOS's own (updates and Store installs: deckos.updates.downloads) and, with
// Android's "Notification access", every other app's download that shows a progress bar
// (deckos.deviceDownloads: Play Store installs, the browser, an emulator fetching its files).
// A: install / cancel / try again on DeckOS's rows; Y clears the finished ones.
import QtQuick 2.15
import "../settings/parts"

FocusScope {
    id: page
    focus: true
    property var theme

    readonly property var u: (typeof deckos !== "undefined" && deckos) ? deckos.updates : null
    readonly property var dev: (typeof deckos !== "undefined" && deckos) ? deckos.deviceDownloads : null
    property int current: 0

    Component.onCompleted: if (dev) dev.watch(true)
    Component.onDestruction: if (dev) dev.watch(false)

    function fmtSize(b) { return b > 0 ? (b / 1048576).toFixed(1) + " MB" : "" }
    function ago(ms) {
        if (!ms) return ""
        var s = Math.max(0, (Date.now() - ms) / 1000)
        if (s < 90) return "just now"
        if (s < 3600) return Math.round(s / 60) + " min ago"
        if (s < 86400) return Math.round(s / 3600) + " h ago"
        return Math.round(s / 86400) + " days ago"
    }

    // headings and notes are skipped by the controller
    readonly property var rows: {
        var r = []
        var own = u ? u.downloads : []
        r.push({ type: "head", text: "DeckOS" })
        for (var i = 0; i < own.length; i++) r.push({ type: "own", data: own[i] })
        if (!own.length) r.push({ type: "note", text: "Nothing downloaded yet: DeckOS and emulator updates (Settings › Updates, the Store) show here." })
        r.push({ type: "head", text: "On this device" })
        if (!dev || !dev.available) {
            r.push({ type: "note", text: "Other apps' downloads are listed on the handheld." })
        } else if (!dev.allowed) {
            r.push({ type: "allow", text: "" })
        } else {
            var act = dev.active, done = dev.recent
            for (var j = 0; j < act.length; j++) r.push({ type: "device", data: act[j] })
            for (var k = 0; k < done.length; k++) r.push({ type: "device", data: done[k] })
            if (!act.length && !done.length) r.push({ type: "note", text: "Nothing downloading right now. Play Store installs, browser downloads and other apps' progress bars show here." })
        }
        return r
    }
    function selectable(i) { var t = rows[i] ? rows[i].type : ""; return t === "own" || t === "device" || t === "allow" }
    function firstSelectable() { for (var i = 0; i < rows.length; i++) if (selectable(i)) return i; return 0 }
    onRowsChanged: if (!selectable(current)) current = firstSelectable()

    function act(r) {
        if (!r) return
        if (r.type === "allow") { if (dev) dev.allow(); return }
        if (r.type !== "own" || !u) return
        var d = r.data
        if (d.state === "downloading") u.cancel(d.id)
        else if (d.id === "app") u.updateApp()
        else u.updateEmulator(d.id)
    }

    function sound(s) { try { s.stop(); s.play() } catch (e) {} }

    Keys.onPressed: {
        if (event.key === Qt.Key_Up) {
            for (var i = current - 1; i >= 0; i--) if (selectable(i)) { current = i; sound(sNav); break }
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            for (var j = current + 1; j < rows.length; j++) if (selectable(j)) { current = j; sound(sNav); break }
            event.accepted = true
        } else if (api.keys.isAccept(event) && !event.isAutoRepeat) {
            sound(sAccept)
            act(rows[current])
            event.accepted = true
        } else if (api.keys.isFilters(event) && !event.isAutoRepeat) {
            if (u) u.clearDownloads()
            if (dev) dev.clearRecent()
            event.accepted = true
        }
    }

    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 70; rightMargin: 70; topMargin: 125 }
        spacing: 8
        Text { text: "Downloads"; color: "white"; font.family: bold.name; font.pixelSize: 46 }
        Text {
            text: "Y  clears the finished ones"
            color: "#8F98A3"
            font.pixelSize: 20
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom
                  leftMargin: 64; rightMargin: 64; topMargin: 24; bottomMargin: 110 }
        clip: true
        spacing: 12
        model: page.rows
        currentIndex: page.current
        interactive: false
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height - 130
        highlightMoveDuration: 180
        highlightMoveVelocity: -1
        delegate: Loader {
            width: list.width
            readonly property var r: modelData
            readonly property bool sel: page.activeFocus && index === page.current
            sourceComponent: r.type === "head" ? headRow : r.type === "note" ? noteRow : r.type === "allow" ? allowRow
                           : r.type === "own" ? ownRow : deviceRow
        }
    }

    Component {
        id: headRow
        Text {
            topPadding: 14
            text: parent ? parent.r.text : ""
            color: "#B8C0C9"
            font.family: bold.name
            font.pixelSize: 26
        }
    }
    Component {
        id: noteRow
        Text {
            width: parent ? parent.width : 0
            text: parent ? parent.r.text : ""
            wrapMode: Text.WordWrap
            color: "#7C8692"
            font.pixelSize: 19
            bottomPadding: 6
        }
    }
    Component {
        id: allowRow
        DeckListRow {
            letter: "↓"
            title: "Show other apps' downloads"
            line: "DeckOS reads the progress bars of other apps' notifications - needs Android's \"Notification access\""
            subline: "With PServer or root it's turned on by itself; otherwise Android's setting opens"
            action: "Allow"
            actionAccent: true
            focused: parent ? parent.sel : false
        }
    }
    Component {
        id: ownRow
        DeckListRow {
            readonly property var d: parent ? parent.r.data : ({})
            letter: d.id === "app" ? "D" : ""
            icon: d.id && d.id !== "app" ? "image://androidicons/" + d.id : ""
            title: d.name || ""
            line: d.state === "downloading" ? "Downloading  " + Math.round((d.progress || 0) * 100) + " %"
                                              + (d.total ? "  ·  " + page.fmtSize(d.bytes) + " of " + page.fmtSize(d.total) : "")
                : d.state === "ready" ? "Downloaded  ·  " + page.fmtSize(d.total)
                : d.state === "installed" ? "Installed"
                : d.state === "error" ? (d.error || "Failed") : ""
            lineColor: d.state === "error" ? "#F2A73B" : d.state === "installed" ? "#8BD86F" : "#AEB6C0"
            subline: page.ago(d.time)
            action: d.state === "downloading" ? "Cancel" : d.state === "ready" ? "Install" : d.state === "error" ? "Try again" : ""
            actionAccent: d.state === "ready"
            progress: d.state === "downloading" ? (d.progress > 0 ? d.progress : -1) : -2
            focused: parent ? parent.sel : false
        }
    }
    Component {
        id: deviceRow
        DeckListRow {
            readonly property var d: parent ? parent.r.data : ({})
            icon: d.package ? "image://androidicons/" + d.package : ""
            title: d.title || d.app || ""
            line: (d.app || "") + (d.text ? "  ·  " + d.text : "")
            subline: d.state ? d.state + "  ·  " + page.ago(d.time) : (d.sub || "")
            lineColor: d.state ? "#8BD86F" : "#AEB6C0"
            progress: d.state ? -2 : (d.progress >= 0 ? d.progress : -1)
            focused: parent ? parent.sel : false
        }
    }
}
