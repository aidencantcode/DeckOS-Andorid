// DECKOS: one row of the Store and Downloads pages: an icon (an app's own, or a letter tile), a title, a
// status line, an optional progress bar and an action on the right ("Update", "Install", "45 %").
import QtQuick 2.15

Item {
    id: row
    property string icon: ""          // image source; "" -> the letter tile
    property string letter: ""
    property string title: ""
    property string line: ""
    property color lineColor: "#AEB6C0"
    property string subline: ""
    property string action: ""
    property bool actionAccent: false
    property real progress: -2        // -2 none, -1 unknown, 0-1
    property bool focused: false
    property bool dim: false
    signal clicked()

    height: 118

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: row.focused ? "#3A3F48" : "#1C1F25"
        border.width: row.focused ? 3 : 0
        border.color: "#C8D0DA"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Item {
        id: iconBox
        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
        width: 76
        height: 76
        Rectangle {
            anchors.fill: parent
            radius: 14
            visible: img.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: "#3F6E9A" }
                GradientStop { position: 1; color: "#23384F" }
            }
            Text {
                anchors.centerIn: parent
                text: row.letter !== "" ? row.letter : (row.title.length ? row.title.charAt(0).toUpperCase() : "?")
                color: "white"
                font.family: bold.name
                font.pixelSize: 38
            }
        }
        Image {
            id: img
            anchors.fill: parent
            source: row.icon
            sourceSize: Qt.size(152, 152)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    Column {
        anchors {
            left: iconBox.right; leftMargin: 22
            right: actionBox.left; rightMargin: 20
            verticalCenter: parent.verticalCenter
        }
        spacing: 4
        Text {
            width: parent.width
            text: row.title
            elide: Text.ElideRight
            color: row.dim ? "#8F98A3" : "white"
            font.family: bold.name
            font.pixelSize: 26
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.line
            elide: Text.ElideRight
            color: row.lineColor
            font.pixelSize: 19
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.subline
            elide: Text.ElideRight
            color: "#7C8692"
            font.pixelSize: 16
        }
        Rectangle {
            visible: row.progress > -2
            width: parent.width
            height: 6
            radius: 3
            color: "#14171C"
            clip: true
            Rectangle {
                visible: row.progress >= 0
                height: parent.height
                radius: 3
                width: parent.width * Math.max(0, Math.min(1, row.progress))
                color: "#1A9FFF"
                Behavior on width { NumberAnimation { duration: 200 } }
            }
            Rectangle { // unknown length: a segment running along
                visible: row.progress === -1
                height: parent.height
                width: parent.width * 0.2
                radius: 3
                color: "#1A9FFF"
                NumberAnimation on x {
                    from: -row.width * 0.2; to: row.width
                    duration: 1100; loops: Animation.Infinite
                    running: row.visible && row.progress === -1
                }
            }
        }
    }

    Rectangle {
        id: actionBox
        visible: row.action !== ""
        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
        width: visible ? Math.max(130, actionText.implicitWidth + 36) : 0
        height: 54
        radius: 4
        color: row.focused ? (row.actionAccent ? "#1A9FFF" : "white") : (row.actionAccent ? "#1A5E93" : "#30353E")
        Text {
            id: actionText
            anchors.centerIn: parent
            text: row.action
            color: row.focused && !row.actionAccent ? "black" : "white"
            font.family: bold.name
            font.pixelSize: 20
        }
    }

    MouseArea { anchors.fill: parent; onClicked: row.clicked() }
}
