// DECKOS: the inside of a shelf card made of an icon and a few lines (ShelfCard.qml): RetroAchievements
// sets and awards, friends, emulator updates, actions. Optional: a chip above the lines, an online dot on
// the icon, a small icon on the right (the game a friend plays), a progress bar along the bottom.
import QtQuick 2.15
import QtGraphicalEffects 1.15

Item {
    id: ic
    property string iconSource: ""
    property bool round: false
    property string glyph: ""          // instead of a picture: a big character on a tile
    property string chip: ""
    property color chipColor: "#6CB2EB"
    property string line1: ""
    property color line1Color: "white"
    property string line2: ""
    property string line3: ""
    property bool wrapLine2: false
    property color dotColor: "transparent"
    property bool showDot: false
    property string sideIcon: ""
    property real progress: -1

    Rectangle { // a soft wash of the icon's colours behind everything
        anchors.fill: parent
        color: "#1E2128"
    }

    Item {
        id: iconBox
        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
        width: Math.min(parent.height - 32, 132)
        height: width

        Rectangle {
            id: iconBg
            anchors.fill: parent
            radius: ic.round ? width / 2 : 6
            color: "#2F343D"
            visible: ic.glyph !== "" || pic.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                visible: ic.glyph !== ""
                text: ic.glyph
                color: "white"
                font.family: bold.name
                font.pixelSize: parent.height * 0.5
            }
        }
        Image {
            id: pic
            anchors.fill: parent
            source: ic.iconSource
            sourceSize: Qt.size(Math.round(width), Math.round(height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            visible: false
        }
        Rectangle { id: mask; anchors.fill: parent; radius: ic.round ? width / 2 : 6; visible: false }
        OpacityMask {
            anchors.fill: parent
            source: pic
            maskSource: mask
            visible: ic.iconSource !== "" && pic.status === Image.Ready
        }
        Rectangle { // online / idle / offline (friends only)
            visible: ic.showDot
            width: parent.width * 0.26
            height: width
            radius: width / 2
            color: ic.dotColor
            border.width: 4
            border.color: "#1E2128"
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: ic.round ? 2 : -4; bottomMargin: ic.round ? 2 : -4 }
        }
    }

    Image {
        id: side
        visible: ic.sideIcon !== "" && status === Image.Ready
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        width: Math.min(parent.height * 0.42, 72)
        height: width
        source: ic.sideIcon
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    Column {
        anchors {
            left: iconBox.right; leftMargin: 18
            right: side.visible ? side.left : parent.right; rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        spacing: 4
        Rectangle {
            visible: ic.chip !== ""
            width: chipText.implicitWidth + 16
            height: chipText.implicitHeight + 6
            radius: 3
            color: Qt.rgba(ic.chipColor.r, ic.chipColor.g, ic.chipColor.b, 0.18)
            Text {
                id: chipText
                anchors.centerIn: parent
                text: ic.chip
                color: ic.chipColor
                font.family: bold.name
                font.pixelSize: 14
            }
        }
        Text {
            width: parent.width
            text: ic.line1
            elide: Text.ElideRight
            color: ic.line1Color
            font.family: bold.name
            font.pixelSize: 23
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: ic.line2
            elide: Text.ElideRight
            wrapMode: ic.wrapLine2 ? Text.WordWrap : Text.NoWrap
            maximumLineCount: ic.wrapLine2 ? 3 : 1
            color: "#C9D2DC"
            font.pixelSize: 18
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: ic.line3
            elide: Text.ElideRight
            color: "#8F98A3"
            font.pixelSize: 16
        }
    }

    Rectangle {
        visible: ic.progress >= 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 5
        color: "#14171C"
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, ic.progress))
            height: parent.height
            color: "#1A9FFF"
            Behavior on width { NumberAnimation { duration: 200 } }
        }
    }
}
