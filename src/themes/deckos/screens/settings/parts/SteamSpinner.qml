// DECKOS: Steam-style loading spinner - a faint ring with a bright arc going round.
// Used wherever something loads (RetroAchievements tab, login check, first library load).
import QtQuick 2.15
import QtGraphicalEffects 1.15

Item {
    id: spinner
    property real size: 64
    property color color: "#1a9fff"
    property bool running: visible
    width: size
    height: size

    readonly property real ringWidth: Math.max(3, size * 0.09)

    Rectangle { // the track
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: spinner.ringWidth
        border.color: "#2effffff"
    }

    Rectangle { // the arc's shape, used as a mask
        id: ring
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: spinner.ringWidth
        border.color: "white"
        visible: false
    }

    ConicalGradient {
        anchors.fill: parent
        source: ring
        gradient: Gradient {
            GradientStop { position: 0.0; color: spinner.color }
            GradientStop { position: 0.35; color: Qt.rgba(spinner.color.r, spinner.color.g, spinner.color.b, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(spinner.color.r, spinner.color.g, spinner.color.b, 0.0) }
        }
        RotationAnimation on rotation {
            from: 0; to: 360
            duration: 900
            loops: Animation.Infinite
            running: spinner.running
        }
    }
}
