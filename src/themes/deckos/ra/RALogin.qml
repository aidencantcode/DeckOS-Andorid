// DECKOS: RetroAchievements login overlay for the game page.
// BigScreenFE's RACredentialsPopup with DeckOS's Steam keyboard (screens/settings/parts/SteamKeyboard.qml),
// packaged as one full-screen overlay. Credentials end up in api.memory
// ("ra_api_user" / "ra_api_key"), where RAGameInfoSection reads them.
import QtQuick 2.15
import "../screens/settings/parts"

FocusScope {
    id: root
    anchors.fill: parent
    visible: popup.isOpen
    z: 1000

    signal saved()
    signal closed()

    property string _activeField: "user"
    property bool _suppressReopen: false

    function open() {
        root.forceActiveFocus()
        popup.open()
    }

    // dim the page and swallow clicks behind the popup
    Rectangle {
        anchors.fill: parent
        color: "#C0000000"
        MouseArea { anchors.fill: parent }
    }

    RACredentialsPopup {
        id: popup
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.1
        width: Math.min(parent.width * 0.6, vpx(640))
        height: vpx(260)
        focus: true

        onUserInputActivated: {
            root._activeField = "user"
            if (!root._suppressReopen) vkb.show(popup.fieldText("user"))
        }
        onKeyInputActivated: {
            root._activeField = "key"
            if (!root._suppressReopen) vkb.show(popup.fieldText("key"))
        }
        onCredentialsSaved: {
            suppressTimer.stop(); root._suppressReopen = false
            vkb.hide()
            root.saved()
        }
        onPopupClosed: {
            suppressTimer.stop(); root._suppressReopen = false
            vkb.hide()
            root.closed()
        }
    }

    // DECKOS: the same full-size Steam keyboard as everywhere else (Paste key for the API key)
    SteamKeyboard {
        id: vkb
        maxLength: root._activeField === "key" ? 64 : 40
        onEdited: popup.setFieldText(root._activeField, text)
        onAccepted: {
            root._suppressReopen = true
            suppressTimer.restart()
            hide()
            popup.focusFieldSafe(root._activeField)
        }
    }

    Timer {
        id: suppressTimer
        interval: 300
        onTriggered: root._suppressReopen = false
    }
}
