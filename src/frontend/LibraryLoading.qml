// DeckOS: the "updating your library" screen. One screen for every step after the user asks for a scan:
//   1. the ROM folder scan (RomLibrary, in the background): the interface stays up, darkened, under a
//      progress bar with the games found so far; B cancels (nothing is changed then)
//   2. the library reload that follows when games were added or removed, and
//   3. the interface being built again: the boot screen is up (the theme is unloaded meanwhile), this
//      stays on top of it so the whole wait looks like one step instead of a black screen.
// Later library reloads (Refresh library, Full rescan) show it too; the very first load keeps the boot video.
import QtQuick 2.8


FocusScope {
    id: root
    anchors.fill: parent

    /// step 1: a scan the user is waiting for
    readonly property var lib: (typeof deckos !== "undefined" && deckos) ? deckos.library : null
    readonly property bool scanning: !!lib && lib.scanForeground
    /// steps 2-3: set by main.qml while the boot screen is up after the first start
    property bool reloading: false
    readonly property bool dataLoading: Internal.scanner.running
    readonly property bool active: scanning || reloading

    /// the count from the scan, still shown while the library loads
    property int lastFound: 0
    readonly property int found: scanning ? lib.scanFound : lastFound
    property bool cancelling: false

    signal released() // the scan ended without a reload: the interface gets the buttons back

    visible: opacity > 0
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }

    onScanningChanged: {
        if (scanning) {
            cancelling = false
            lastFound = 0
            forceActiveFocus()
        } else {
            lastFound = lib ? lib.scanFound : 0
            if (activeFocus) released()
        }
    }
    onActiveChanged: if (active) tips.pickFirst()

    readonly property real u: height / 1080 // sizes are designed at 1080p
    readonly property real progress: {
        if (scanning) return lib.scanProgress
        if (dataLoading) return Internal.scanner.progress
        return 1
    }
    readonly property bool indeterminate: scanning && (lib.scanProgress <= 0 || cancelling)

    // the buttons go nowhere else while scanning (B cancels); the boot screen has them during a reload
    Keys.onPressed: {
        event.accepted = true
        if (!scanning || cancelling) return
        if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            cancelling = true
            lib.cancelScan()
        }
    }
    MouseArea { anchors.fill: parent; enabled: root.active; onClicked: {} } // taps don't reach the interface

    Rectangle { // darkens the interface during the scan; plain black over the boot screen
        anchors.fill: parent
        color: "#000"
        opacity: root.reloading ? 1 : 0.86
        Behavior on opacity { NumberAnimation { duration: 280 } }
    }

    Column {
        id: panel
        width: Math.min(parent.width * 0.78, 980 * root.u)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.06
        spacing: 22 * root.u

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.scanning ? (root.cancelling ? "Cancelling…" : "Scanning your ROM folders")
                                : (root.dataLoading ? (root.lastFound > 0 ? "Updating your library" : "Loading your library") : "Getting everything ready")
            color: "white"
            font.family: global.fonts.sansBold
            font.pixelSize: 44 * root.u
            elide: Text.ElideRight
        }

        Item { // Steam-style bar: blue on dark grey, sliding while the amount of work isn't known yet
            id: track
            width: parent.width * 0.82
            height: Math.max(4, 8 * root.u)
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true

            Rectangle { anchors.fill: parent; radius: height / 2; color: "#2a2f37" }
            Rectangle {
                visible: !root.indeterminate
                height: parent.height
                radius: height / 2
                width: parent.width * Math.max(0.03, Math.min(1, root.progress))
                color: "#1a9fff"
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            }
            Rectangle {
                id: slider
                visible: root.indeterminate
                height: parent.height
                radius: height / 2
                width: parent.width * 0.25
                color: "#1a9fff"
                NumberAnimation on x {
                    running: slider.visible && root.visible
                    from: -track.width * 0.25; to: track.width
                    duration: 1300; loops: Animation.Infinite; easing.type: Easing.InOutQuad
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: "#c7d5e0"
            font.family: global.fonts.sans
            font.pixelSize: 27 * root.u
            elide: Text.ElideMiddle
            text: {
                var games = root.found === 1 ? "1 game found" : root.found.toLocaleString(Qt.locale(), "f", 0) + " games found"
                if (root.scanning)
                    return root.lib.scanSystem !== "" && !root.cancelling ? games + "  ·  " + root.lib.scanSystem : games
                var step = root.dataLoading ? (Internal.scanner.stage !== "" ? Internal.scanner.stage : "Reading your games")
                                            : "Building the interface"
                return root.lastFound > 0 ? games + "  ·  " + step : step
            }
        }

        Row { // B cancels, scan only
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14 * root.u
            visible: root.scanning && !root.cancelling
            Rectangle {
                width: 38 * root.u; height: width; radius: width / 2
                color: "#3d4450"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: (api.memory.has("nintendoLayout") && api.memory.get("nintendoLayout")) ? "A" : "B"
                    color: "white"; font.family: global.fonts.sansBold; font.pixelSize: 22 * root.u
                }
            }
            Text {
                text: "Cancel"
                color: "#8b929a"
                font.family: global.fonts.sansBold
                font.pixelSize: 24 * root.u
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // tips and credits, one at a time, at the bottom
    Item {
        id: tips
        width: Math.min(parent.width * 0.8, 1100 * root.u)
        height: tipColumn.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.08

        readonly property var list: [
            "DeckOS's Steam-style interface is built on StMini, made by ScriptUT.",
            "The Achievements panel is built on BigScreenFE by Gonzalo Abbate.",
            "DeckOS is built on Pegasus Frontend by Mátyás Mustoha.",
            "Press X on a game for its options: Properties, collections and scraping.",
            "Press X on a collection in the Library to scrape it, rename it or change its icon.",
            "Every launch command can be seen and edited in Settings > Emulators.",
            "Collections can be hidden, renamed or given another games folder in Settings > Collections.",
            "Press Y in a game's Achievements tab to switch between the list and the grid.",
            "A keys.txt file in your DeckOS folder adds your API keys without typing them.",
            "Re-scrape skips games that already have artwork unless you turn that off in Settings > Scraping.",
            "Play time is counted for everything you start from DeckOS.",
            "A game's Properties > Customization picks its artwork from SteamGridDB."
        ]
        property int index: 0
        function pickFirst() { index = Math.floor(Math.random() * list.length); tipText.opacity = 1 }

        Timer {
            interval: 6500
            repeat: true
            running: root.visible
            onTriggered: tipFade.restart()
        }
        SequentialAnimation {
            id: tipFade
            NumberAnimation { target: tipText; property: "opacity"; to: 0; duration: 300 }
            ScriptAction { script: tips.index = (tips.index + 1) % tips.list.length }
            NumberAnimation { target: tipText; property: "opacity"; to: 1; duration: 300 }
        }

        Column {
            id: tipColumn
            width: parent.width
            spacing: 10 * root.u
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "TIP"
                color: "#1a9fff"
                font.family: global.fonts.sansBold
                font.pixelSize: 21 * root.u
                font.letterSpacing: 3 * root.u
            }
            Text {
                id: tipText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: tips.list[tips.index]
                color: "#8b929a"
                font.family: global.fonts.sans
                font.pixelSize: 25 * root.u
            }
        }
    }
}
