// DECKOS: the user's picture and name at the top of the STEAM side menu (set in Settings > Profile).
// Falls back to the RetroAchievements account, then to "Player".
import QtQuick 2.15
import QtGraphicalEffects 1.15

Item {
    id: badge
    property var theme

    readonly property string pictureSource: theme ? theme.profilePictureSource : ""
    readonly property string nameText: theme ? theme.profileDisplayName : "Player"

    Rectangle {
        id: avatarFrame
        width: badge.height
        height: badge.height
        radius: height / 2
        color: "#2a3f5a"
        anchors.verticalCenter: parent.verticalCenter

        Text {
            visible: avatarImage.status !== Image.Ready
            anchors.centerIn: parent
            text: badge.nameText.length > 0 ? badge.nameText.charAt(0).toUpperCase() : "?"
            color: "white"
            font.pixelSize: parent.height * 0.5
            font.family: bold.name
        }

        Image {
            id: avatarImage
            anchors.fill: parent
            source: badge.pictureSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            sourceSize.width: 256
            sourceSize.height: 256
            visible: false
        }
        Rectangle {
            id: avatarMask
            anchors.fill: parent
            radius: height / 2
            visible: false
        }
        OpacityMask {
            anchors.fill: parent
            source: avatarImage
            maskSource: avatarMask
            visible: avatarImage.status === Image.Ready
        }
    }

    Column {
        anchors.left: avatarFrame.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            width: parent.width
            text: badge.nameText
            color: "white"
            font.pixelSize: 32
            font.family: bold.name
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: badge.theme && badge.theme.isOnline ? "Online" : "Offline"
            color: badge.theme && badge.theme.isOnline ? "#57cbde" : "#8b929a"
            font.pixelSize: 22
            font.family: bold.name
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (badge.theme) badge.theme.openSettingsPage("settings/profile.qml")
    }
}
