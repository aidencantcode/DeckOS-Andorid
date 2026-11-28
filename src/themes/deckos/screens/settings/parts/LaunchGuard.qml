// DECKOS: one game at a time. Every Play in the theme goes through theme.playGame(game, launch):
// - nothing runs behind DeckOS: launch() at once;
// - the same game still runs: it's looked at first (it may have been closed in the emulator a moment ago
//   and DeckOS not have noticed yet) - still there: Resume brings it back as it was; gone: launch();
// - another game still runs: this card asks first. "Close game and play" closes it, shows a loading bar
//   until Android confirms it has ended (InGame::closeRunning), then launches the new game. Starting a
//   game on top of a running one threw people back into the old emulator in a broken state.
// Also shown while the game page's Stop closes a game, and for launches that skip the theme
// (InGame::launchBlocked, e.g. a game with several files).
import QtQuick 2.15
import QtQuick.Window 2.15

FocusScope {
    id: guard
    anchors.fill: parent
    z: 5003
    visible: mode !== ""

    /// "", "ask", "checking", "closing", "failed"
    property string mode: ""
    property var game: null
    property var launchFn: null
    property int current: 0
    property var restoreFocus: null
    property bool shown: false // "checking" stays invisible for its first moments (usually all of it)

    readonly property var ingame: (typeof deckos !== "undefined" && deckos) ? deckos.ingame : null
    readonly property string runningTitle: ingame && ingame.runningTitle !== "" ? ingame.runningTitle : "The game"
    readonly property string gameTitle: game && game.title ? game.title : "this game"

    readonly property var buttons: mode === "ask"
        ? [ { id: "close", label: "Close game and play" }, { id: "resume", label: "Resume " + shortTitle(runningTitle) }, { id: "cancel", label: "Cancel" } ]
        : mode === "failed" ? [ { id: "retry", label: "Try again" }, { id: "cancel", label: "OK" } ]
        : []

    function shortTitle(t) { return t.length > 22 ? t.substring(0, 21) + "…" : t }

    function sameGame(g) {
        if (!g || !ingame) return false
        var r = ingame.runningGame
        return (!!r && r === g) || (ingame.runningTitle !== "" && g.title === ingame.runningTitle)
    }

    /// the entry point (theme.playGame)
    function play(g, fn) {
        if (mode !== "" && mode !== "closing") return // already asking
        if (!ingame || (!ingame.running && !ingame.busy)) { fn(); return }
        game = g
        launchFn = fn
        if (mode === "closing") return // the game is closing: this one starts once it's gone
        if (sameGame(g)) {
            open("checking")
            ingame.checkRunning()
            return
        }
        open("ask")
    }

    function open(m) {
        if (mode === "") restoreFocus = Window.activeFocusItem
        mode = m
        current = 0
        shown = m !== "checking"
        if (m === "checking") showTimer.restart()
        forceActiveFocus()
        if (shown) { try { sShowui.play() } catch (e) {} }
    }

    function finish() {
        mode = ""
        game = null
        launchFn = null
        shown = false
        var f = restoreFocus
        restoreFocus = null
        Qt.callLater(function () {
            if (guard.mode !== "") return
            if (f && f.visible) { f.forceActiveFocus(); return }
            var page = pageLoader.item
            if (!page) return
            if (typeof page.resumeFocus === "function") page.resumeFocus()
            else page.forceActiveFocus()
        })
    }

    function press(i) {
        var b = buttons[i]
        if (!b) return
        if (b.id === "close" || b.id === "retry") {
            try { sAccept.play() } catch (e) {}
            mode = "closing"
            ingame.closeRunning(game)
        } else if (b.id === "resume") {
            try { sAccept.play() } catch (e) {}
            finish()
            ingame.resumeGame()
        } else {
            try { sBack.play() } catch (e) {}
            finish()
        }
    }

    Timer { id: showTimer; interval: 350; onTriggered: guard.shown = true }

    Connections {
        target: guard.ingame
        function onRunningChecked(alive) {
            if (guard.mode !== "checking") return
            var fn = guard.launchFn
            guard.finish()
            if (alive) {
                if (!guard.ingame.resumeGame() && fn) fn() // no launcher entry to bring back: launched again
            } else if (fn) {
                fn()
            }
        }
        function onRunningClosed(next) {
            if (guard.mode !== "closing") return
            var fn = guard.launchFn
            guard.finish()
            if (fn) fn()
        }
        function onCloseFailed() {
            if (guard.mode === "closing") { guard.mode = "failed"; guard.current = 0 }
        }
        function onBusyChanged() {
            // the game page's Stop: the same loading bar while the game closes
            if (guard.ingame.closing && guard.mode === "") guard.open("closing")
        }
        function onLaunchBlocked(g) {
            if (!g) return
            guard.play(g, function () { g.launch() })
        }
    }

    // the page under it moves the focus while it opens: take it back while the card is up
    onActiveFocusChanged: if (visible && !activeFocus) Qt.callLater(function () { if (guard.visible) guard.forceActiveFocus() })

    Keys.onPressed: {
        event.accepted = true
        if (event.isAutoRepeat && (api.keys.isAccept(event) || api.keys.isCancel(event))) return
        if (buttons.length === 0) return // checking / closing: wait
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            if (current > 0) { current--; try { sNav.stop(); sNav.play() } catch (e) {} }
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            if (current < buttons.length - 1) { current++; try { sNav.stop(); sNav.play() } catch (e) {} }
        } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
            press(current)
        } else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
            try { sBack.play() } catch (e) {}
            finish()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#B3000000"
        opacity: guard.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        MouseArea { anchors.fill: parent } // nothing under it is pressed meanwhile
    }

    Rectangle {
        id: card
        width: Math.min(parent.width * 0.56, parent.height * 1.05)
        height: column.height + guard.height * 0.07
        anchors.centerIn: parent
        radius: 6
        opacity: guard.shown ? 1 : 0
        scale: guard.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        gradient: Gradient {
            GradientStop { position: 0; color: "#2B2F36" }
            GradientStop { position: 1; color: "#1D2025" }
        }

        Column {
            id: column
            width: parent.width * 0.88
            anchors.centerIn: parent
            spacing: guard.height * 0.024

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "white"
                font.family: bold.name
                font.pixelSize: guard.height * 0.036
                text: guard.mode === "ask" ? "A game is still running"
                    : guard.mode === "checking" ? "Checking " + guard.runningTitle + "…"
                    : guard.mode === "closing" ? "Closing " + guard.runningTitle + "…"
                    : guard.mode === "failed" ? "Couldn't close " + guard.runningTitle : ""
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#B8BCC2"
                font.pixelSize: guard.height * 0.025
                textFormat: Text.StyledText
                text: guard.mode === "ask"
                    ? "<b>" + guard.runningTitle + "</b> is still open. Only one game runs at a time: close it to play <b>"
                      + guard.gameTitle + "</b>.<br>Anything unsaved in " + guard.runningTitle + " will be lost."
                    : guard.mode === "checking" ? "Making sure it's still open."
                    : guard.mode === "closing" ? (guard.launchFn ? "Waiting for Android to close it, then " + guard.gameTitle + " starts."
                                                                 : "Waiting for Android to close it.")
                    : guard.mode === "failed" ? "It still runs after 10 seconds. Close it from Android's recent apps, then try again."
                    : ""
            }

            // Steam's thin blue loading bar
            Rectangle {
                visible: guard.mode === "checking" || guard.mode === "closing"
                width: parent.width
                height: Math.max(6, guard.height * 0.008)
                radius: height / 2
                color: "#14171C"
                clip: true
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: parent.width * Math.max(0.04, guard.ingame ? guard.ingame.busyProgress : 0)
                    color: "#1A9FFF"
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
                Rectangle { // a glint running along it: something is happening
                    width: parent.width * 0.18
                    height: parent.height
                    radius: height / 2
                    opacity: 0.35
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#001A9FFF" }
                        GradientStop { position: 0.5; color: "#FFFFFF" }
                        GradientStop { position: 1; color: "#001A9FFF" }
                    }
                    NumberAnimation on x {
                        from: -guard.width * 0.1; to: guard.width * 0.6
                        duration: 1100; loops: Animation.Infinite
                        running: guard.visible && (guard.mode === "checking" || guard.mode === "closing")
                    }
                }
            }

            Row {
                visible: guard.buttons.length > 0
                anchors.right: parent.right
                spacing: guard.height * 0.016
                Repeater {
                    model: guard.buttons
                    Rectangle {
                        readonly property bool active: guard.current === index
                        width: label.implicitWidth + guard.height * 0.05
                        height: guard.height * 0.062
                        radius: 4
                        color: active ? "white" : "#3D4450"
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.active ? "black" : "white"
                            font.family: bold.name
                            font.pixelSize: guard.height * 0.024
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { if (guard.current === index) guard.press(index); else guard.current = index }
                        }
                    }
                }
            }
        }
    }
}
