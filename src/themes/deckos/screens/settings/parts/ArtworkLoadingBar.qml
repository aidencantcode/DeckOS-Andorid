// DECKOS: a thin Steam-blue bar along the bottom of a page while artwork loads (ImageCache.h): the tiles
// on screen being read, or the whole library's thumbnails being made ahead ("Preparing artwork 120 / 4000",
// which only happens once, after new artwork). Shows after a quarter second, so a fast load doesn't flicker.
import QtQuick 2.15

Item {
    id: bar
    height: 46

    readonly property var cache: (typeof deckos !== "undefined" && deckos) ? deckos.images : null
    readonly property int pending: cache ? cache.pending : 0
    readonly property int warming: cache ? cache.warming : 0
    readonly property int total: cache ? cache.warmTotal : 0
    readonly property bool busy: pending > 0 || warming > 0
    readonly property bool determinate: warming > 0 && total > 0
    property bool shown: false

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 250 } }

    Timer { running: bar.busy && !bar.shown; interval: 250; onTriggered: bar.shown = true }
    Timer { running: !bar.busy && bar.shown; interval: 700; onTriggered: bar.shown = false }

    Rectangle { // the label, in a pill so it reads over any artwork
        anchors { right: parent.right; rightMargin: 24; bottom: track.top; bottomMargin: 8 }
        width: label.implicitWidth + 28
        height: label.implicitHeight + 10
        radius: height / 2
        color: "#CC0E1116"
        Text {
            id: label
            anchors.centerIn: parent
            text: bar.determinate ? "Preparing artwork  " + Math.max(0, bar.total - bar.warming) + " / " + bar.total
                                  : "Loading artwork…"
            color: "#C7CBD1"
            font.pixelSize: 17
            font.family: bold.name
        }
    }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 4
        color: "#40000000"
        clip: true

        Rectangle { // how far the library's thumbnails have got
            visible: bar.determinate
            height: parent.height
            color: "#1A9FFF"
            width: parent.width * Math.max(0.02, 1 - bar.warming / Math.max(1, bar.total))
            Behavior on width { NumberAnimation { duration: 250 } }
        }
        Rectangle { // tiles loading: a segment running along
            id: runner
            visible: !bar.determinate
            height: parent.height
            width: parent.width * 0.22
            color: "#1A9FFF"
            NumberAnimation on x {
                from: -track.width * 0.22; to: track.width
                duration: 1100; loops: Animation.Infinite
                running: bar.visible && !bar.determinate
            }
        }
    }
}
