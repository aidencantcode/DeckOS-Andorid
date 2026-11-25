// DECKOS: Settings > Profile - the name and picture shown in the STEAM side menu and the top bar,
// plus the accounts DeckOS can show (RetroAchievements now, a public Steam profile later).
import QtQuick 2.15
import "parts"
import "../../ra"

DeckSettingsPage {
    id: profilePage
    title: "Profile"

    readonly property var th: (typeof theme !== "undefined" && theme) ? theme : null

    function fileName(path) {
        var s = String(path)
        var i = s.lastIndexOf("/")
        return i >= 0 ? s.substring(i + 1) : s
    }

    rows: [
        { type: "section", label: "You" },
        { type: "button", label: "Name",
          desc: "Shown in the side menu",
          value: function () { return th && th.profileName !== "" ? th.profileName : "Not set" },
          activate: function () { nameEntry.open(th ? th.profileName : "") } },
        { type: "button", label: "Picture",
          desc: "Any PNG or JPG image on this device",
          value: function () { return th && th.profilePicture !== "" ? profilePage.fileName(th.profilePicture) : "Not set" },
          activate: function () { picturePicker.open() } },
        { type: "button", label: "Remove picture",
          enabled: function () { return !!th && th.profilePicture !== "" },
          activate: function () { if (th) th.profilePicture = "" } },
        { type: "section", label: "Accounts" },
        { type: "button", label: "RetroAchievements",
          desc: "Achievements on every game page",
          value: function () { return th && th.savedUsername !== "" ? th.savedUsername : "Not connected" },
          activate: function () { if (th) th.openPage(13) } },
        { type: "info", label: "Steam profile",
          desc: "Show a public Steam profile's games, play time and achievements",
          value: function () { return "Coming soon" } }
    ]

    FolderPicker {
        id: picturePicker
        title: "Choose a picture"
        hint: "Open folders with A, go back with B, and pick an image."
        filesMode: true
        fileExtensions: [".png", ".jpg", ".jpeg", ".webp", ".PNG", ".JPG", ".JPEG", ".WEBP"]
        onPicked: {
            if (th) th.profilePicture = "file:" + (path.charAt(0) === "/" ? "//" + path : "///" + path)
            goToZone(1)
        }
        onClosed: goToZone(1)
    }

    // name entry: text box + the controller keyboard (Start or B on the keyboard closes it and saves)
    FocusScope {
        id: nameEntry
        anchors.fill: parent
        visible: false
        property string text: ""

        function open(current) {
            text = current
            visible = true
            keyboard.show()
        }
        function finish() {
            keyboard.hide()
            visible = false
            if (th) th.profileName = text.trim()
            goToZone(1)
        }

        Rectangle { anchors.fill: parent; color: "#0F1318"; MouseArea { anchors.fill: parent } }

        Text {
            id: entryTitle
            text: "Your name"
            color: "white"
            font.pixelSize: 50
            font.family: bold.name
            font.bold: true
            anchors.top: parent.top
            anchors.topMargin: 70
            anchors.left: parent.left
            anchors.leftMargin: 50
        }
        Rectangle {
            id: entryBox
            anchors.top: entryTitle.bottom
            anchors.topMargin: 30
            anchors.left: parent.left
            anchors.leftMargin: 50
            anchors.right: parent.right
            anchors.rightMargin: 50
            height: 80
            radius: 5
            color: "white"
            Text {
                text: nameEntry.text + "|"
                color: "black"
                font.pixelSize: 32
                font.family: bold.name
                elide: Text.ElideLeft
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: "Type with the keyboard below. B or the keyboard's close key saves the name."
            color: "lightgray"
            font.pixelSize: 24
            font.family: bold.name
            anchors.top: entryBox.bottom
            anchors.topMargin: 16
            anchors.left: entryBox.left
        }

        VirtualKeyboard {
            id: keyboard
            bottomBarHeight: 90
            onKeyTapped: if (nameEntry.text.length < 32) nameEntry.text += ch
            onBackspacePressed: nameEntry.text = nameEntry.text.slice(0, -1)
            onCloseRequested: nameEntry.finish()
        }
    }
}
