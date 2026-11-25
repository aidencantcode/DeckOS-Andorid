// DECKOS: Settings > Profile - the name and picture shown in the STEAM side menu and the top bar,
// plus the accounts DeckOS can show (RetroAchievements now, a public Steam profile later).
import QtQuick 2.15
import "parts"


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

    TextEntry {
        id: nameEntry
        title: "Your name"
        hint: "Shown in the side menu and the top bar."
        maxLength: 32
        onAccepted: {
            if (th) th.profileName = text.trim()
            goToZone(1)
        }
    }
}
