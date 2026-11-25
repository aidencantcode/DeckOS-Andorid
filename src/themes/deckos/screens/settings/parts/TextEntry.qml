// DECKOS: full-page text entry with the controller keyboard (names, descriptions, API keys).
// B or the keyboard's close key saves, Y pastes the clipboard, X clears. On a touch screen the
// text box can also be tapped to type with Android's keyboard.
import QtQuick 2.15
import "../../../ra"

FocusScope {
    id: entry
    anchors.fill: parent
    visible: false

    property string title: ""
    property string hint: ""
    property string text: ""
    property int maxLength: 64
    property bool multiline: false
    /// API keys: show only the start and the end of what was typed
    property bool secret: false

    signal accepted(string text)

    function open(current) {
        text = current || ""
        visible = true
        keyboard.show()
    }
    function finish() {
        keyboard.hide()
        visible = false
        accepted(text)
    }

    function shown() {
        if (!secret || text.length <= 10) return text
        return text.substring(0, 4) + "…" + text.substring(text.length - 4) + "  (" + text.length + " characters)"
    }

    TextEdit {
        id: clipboard
        visible: false
        function read() { text = ""; paste(); return text }
    }

    Keys.onPressed: {
        if (api.keys.isFilters(event)) { // Y: paste
            event.accepted = true
            var pasted = clipboard.read().replace(/\r/g, "")
            if (!entry.multiline) pasted = pasted.replace(/\n/g, " ").trim()
            entry.text = (entry.text + pasted).substring(0, entry.maxLength)
        } else if (api.keys.isDetails(event)) { // X: clear
            event.accepted = true
            entry.text = ""
        } else if (api.keys.isMenu(event)) {
            event.accepted = true
            entry.finish()
        }
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
        anchors.topMargin: 70
        anchors.left: parent.left
        anchors.leftMargin: 50
    }

    Rectangle {
        id: box
        anchors.top: titleText.bottom
        anchors.topMargin: 30
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.right: parent.right
        anchors.rightMargin: 50
        height: entry.multiline ? Math.max(80, Math.min(parent.height * 0.3, boxText.implicitHeight + 30)) : 80
        radius: 5
        color: "white"
        clip: true

        Text {
            id: boxText
            visible: !nativeInput.activeFocus
            text: entry.shown() + "|"
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
            onTextEdited: entry.text = text
            onAccepted: entry.finish()
        }
        MouseArea {
            anchors.fill: parent
            enabled: !nativeInput.activeFocus
            onClicked: { nativeInput.text = entry.text; nativeInput.forceActiveFocus(); Qt.inputMethod.show() }
        }
    }

    Text {
        id: hintText
        text: entry.hint + (entry.hint !== "" ? "\n" : "") + "B saves  ·  Y pastes  ·  X clears"
        color: "lightgray"
        font.pixelSize: 24
        font.family: bold.name
        wrapMode: Text.WordWrap
        anchors.top: box.bottom
        anchors.topMargin: 16
        anchors.left: box.left
        anchors.right: box.right
    }

    VirtualKeyboard {
        id: keyboard
        bottomBarHeight: 90
        onKeyTapped: {
            if (entry.text.length < entry.maxLength) entry.text += ch
        }
        onBackspacePressed: entry.text = entry.text.slice(0, -1)
        onCloseRequested: entry.finish()
    }
}
