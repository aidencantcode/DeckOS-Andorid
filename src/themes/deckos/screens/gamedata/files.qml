// DECKOS: "Local Files" page of the game properties screen. StMini 0.4 links to gamedata/files.qml but
// does not ship it; this lists the game's files and the folder they are in.
import QtQuick 2.0

Item {
    id: filesPage
    anchors.fill: parent

    property int activeItemIndex: 0
    readonly property var game: (typeof theme !== "undefined" && theme) ? theme.currentGame : null
    readonly property int fileCount: game ? game.files.count : 0
    property int maxItemIndex: Math.max(0, fileCount - 1)

    function folderOf(path) {
        var i = path.lastIndexOf("/")
        return i > 0 ? path.substring(0, i) : ""
    }

    Column {
        anchors.fill: parent
        anchors.margins: 50
        spacing: 15

        Text {
            text: "Local Files"
            color: "white"
            font.pixelSize: 40
            font.family: bold.name
        }

        Text {
            width: parent.width
            text: filesPage.fileCount === 0 ? "This game has no files (it is an app or a launcher entry)."
                  : filesPage.fileCount === 1 ? "1 file" : filesPage.fileCount + " files"
            color: "lightgray"
            font.pixelSize: 25
            font.family: bold.name
            wrapMode: Text.Wrap
        }

        Item { width: 1; height: 10 }

        Repeater {
            model: filesPage.game ? filesPage.game.files : null
            delegate: Rectangle {
                readonly property bool active: activeZone === 1 && filesPage.activeItemIndex === index
                width: parent.width
                height: 110
                color: active ? "white" : "#31343B"
                Behavior on color { ColorAnimation { duration: 150 } }
                clip: true

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        width: parent.width
                        text: modelData.name
                        color: active ? "black" : "white"
                        font.pixelSize: 28
                        font.family: bold.name
                        elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width
                        text: filesPage.folderOf(modelData.path) || modelData.path
                        color: active ? "#333" : "lightgray"
                        font.pixelSize: 22
                        font.family: bold.name
                        elide: Text.ElideLeft
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: { activeZone = 1; filesPage.activeItemIndex = index }
                }
            }
        }
    }
}
