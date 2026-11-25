// DECKOS: full-page text entry with the Steam keyboard (names, descriptions, launch commands, API keys).
// Done / B / Start saves; the keyboard's Paste key pastes, Clear empties the box. On a touch screen
// the text box can also be tapped to type with Android's own keyboard.
import QtQuick 2.15

FocusScope {
    id: entry
    anchors.fill: parent
    visible: false

    property string title: ""
    property string hint: ""
    property alias text: keyboard.text
    property int maxLength: 64
    property bool multiline: false
    /// API keys: show only the start and the end of what was typed
    property bool secret: false

    signal accepted(string text)

    function open(current) {
        visible = true
        keyboard.show(current || "")
    }
    function finish() {
        if (!visible) return
        keyboard.hide()
        visible = false
        accepted(keyboard.text)
    }

    function shown() {
        var t = keyboard.text
        if (secret && t.length > 10)
            return t.substring(0, 4) + "…" + t.substring(t.length - 4) + "  (" + t.length + " characters)"
        return t.substring(0, keyboard.cursorPosition) + "|" + t.substring(keyboard.cursorPosition)
    }

    Rectangle { anchors.fill: parent; color: "#0F1318"; MouseArea { anchors.fill: parent } }

    Text {
        id: titleText
        text: entry.title
        color: "white"
        font.pixelSize: 50
        font.family: bold.name
        font.bold: true
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.left: parent.left
        anchors.leftMargin: 50
    }

    Rectangle {
        id: box
        anchors.top: titleText.bottom
        anchors.topMargin: 26
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.right: parent.right
        anchors.rightMargin: 50
        height: entry.multiline
                ? Math.max(80, Math.min(keyboard.y - box.y - 110, boxText.implicitHeight + 30))
                : 80
        radius: 5
        color: "white"
        clip: true

        Text {
            id: boxText
            visible: !nativeInput.activeFocus
            text: entry.shown()
            color: "black"
            font.pixelSize: 30
            font.family: bold.name
            wrapMode: entry.multiline ? Text.Wrap : Text.NoWrap
            elide: entry.multiline ? Text.ElideNone : Text.ElideLeft
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.bottom: entry.multiline ? parent.bottom : undefined
            anchors.bottomMargin: entry.multiline ? 15 : 0
            anchors.verticalCenter: entry.multiline ? undefined : parent.verticalCenter
        }
        // touch: Android's own keyboard
        TextInput {
            id: nativeInput
            visible: activeFocus
            anchors.fill: parent
            anchors.margins: 20
            font.pixelSize: 30
            font.family: bold.name
            color: "black"
            echoMode: entry.secret ? TextInput.PasswordEchoOnEdit : TextInput.Normal
            maximumLength: entry.maxLength
            onTextEdited: { keyboard.text = text; keyboard.cursorPosition = cursorPosition }
            onAccepted: entry.finish()
        }
        MouseArea {
            anchors.fill: parent
            enabled: !nativeInput.activeFocus
            onClicked: { nativeInput.text = keyboard.text; nativeInput.forceActiveFocus(); Qt.inputMethod.show() }
        }
    }

    Text {
        id: hintText
        text: entry.hint + (entry.hint !== "" ? "\n" : "") + "X deletes  ·  Y space  ·  L1 caps  ·  Paste key pastes  ·  B saves"
        color: "lightgray"
        font.pixelSize: 24
        font.family: bold.name
        wrapMode: Text.WordWrap
        anchors.top: box.bottom
        anchors.topMargin: 16
        anchors.left: box.left
        anchors.right: box.right
    }

    SteamKeyboard {
        id: keyboard
        bottomMargin: 90 // above the page's button hints bar
        maxLength: entry.maxLength
        multiline: entry.multiline
        onAccepted: entry.finish()
    }
}
