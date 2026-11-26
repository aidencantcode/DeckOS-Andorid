// DECKOS: Add to collection... (the game page's options). Every collection of the library, ticked where
// the game is; A puts the game in or takes it out (the ones you put it in - a system's or a metadata
// file's collection stays), the last row names a new collection with the Steam keyboard. B closes.
// Saved by deckos.collections (UserCollections.h) and shown in the Library's Collections tab at once.
import QtQuick 2.15

FocusScope {
    id: picker
    anchors.fill: parent
    visible: false

    property var game: null
    property var rows: []
    property string message: ""
    property bool messageIsError: false

    signal closed()

    readonly property var store: (typeof deckos !== "undefined" && deckos) ? deckos.collections : null
    readonly property int rowCount: rows.length + 1 // the last row: New collection

    function open(g) {
        // the Library hands over a sorted model's row (its fields, the game itself in modelData)
        game = g && g.modelData ? g.modelData : g
        message = ""
        refresh("")
        list.currentIndex = 0
        visible = true
        forceActiveFocus()
    }
    function close() {
        if (!visible) return
        visible = false
        game = null
        closed()
    }

    // reloads the rows, keeping the selection on `keepName` when it's still there
    function refresh(keepName) {
        rows = store && game ? store.forGame(game) : []
        if (keepName !== "") {
            for (var i = 0; i < rows.length; i++) {
                if (rows[i].name.toLowerCase() === keepName.toLowerCase()) { list.currentIndex = i; return }
            }
        }
        list.currentIndex = Math.min(list.currentIndex, rowCount - 1)
    }

    function say(text, isError) {
        message = text
        messageIsError = !!isError
    }

    function activate(i) {
        if (!store || !game) return
        if (i >= rows.length) {
            nameEntry.open("")
            return
        }
        var r = rows[i]
        if (!r.member) {
            var err = store.add(game, r.name)
            if (err !== "") say(err, true)
            else say("Added to " + r.name, false)
        } else if (r.mine) {
            store.remove(game, r.name)
            say("Taken out of " + r.name, false)
        } else {
            say(r.name + " comes from your library (the game's folder or metadata file), so it stays", true)
        }
        refresh(r.name)
    }

    function addNew(name) {
        var clean = name.replace(/\s+/g, " ").trim()
        if (clean === "") { say("No new collection: the name was empty", true); return }
        var existing = store.existingName(clean)
        var err = store.add(game, clean)
        if (err !== "") { say(err, true); return }
        say(existing !== "" ? "Added to " + existing + " (it was there already)" : "Made " + clean + " and added the game", false)
        refresh(existing !== "" ? existing : clean)
    }

    Keys.onPressed: {
        if (nameEntry.visible) return
        event.accepted = true // modal: nothing reaches the page underneath
        if (event.isAutoRepeat && (api.keys.isAccept(event) || api.keys.isCancel(event))) return
        if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
            try { sBack.stop(); sBack.play() } catch (e) {}
            close()
        } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
            try { sAccept.stop(); sAccept.play() } catch (e) {}
            activate(list.currentIndex)
        } else if (event.key === Qt.Key_Up) {
            if (list.currentIndex > 0) { list.currentIndex--; try { sNav.stop(); sNav.play() } catch (e) {} }
        } else if (event.key === Qt.Key_Down) {
            if (list.currentIndex < rowCount - 1) { list.currentIndex++; try { sNav.stop(); sNav.play() } catch (e) {} }
        } else if (api.keys.isPageUp(event) || api.keys.isPrevPage(event)) {
            list.currentIndex = Math.max(0, list.currentIndex - 6)
        } else if (api.keys.isPageDown(event) || api.keys.isNextPage(event)) {
            list.currentIndex = Math.min(rowCount - 1, list.currentIndex + 6)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#0F1318"
        MouseArea { anchors.fill: parent }
    }

    Text {
        id: titleText
        text: "Add to collection"
        color: "white"
        font.pixelSize: 50
        font.family: bold.name
        font.bold: true
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.left: parent.left
        anchors.leftMargin: 50
    }
    Text {
        id: gameText
        text: picker.game ? picker.game.title : ""
        color: "#1a9fff"
        font.pixelSize: 30
        font.family: bold.name
        elide: Text.ElideRight
        anchors.top: titleText.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.right: parent.right
        anchors.rightMargin: 50
    }
    Text {
        id: hintText
        text: picker.message !== "" ? picker.message
            : "A puts the game in a collection or takes it out. Your collections show in the Library's Collections tab."
        color: picker.message === "" ? "lightgray" : (picker.messageIsError ? "#F2A73B" : "#7FD36B")
        font.pixelSize: 24
        font.family: bold.name
        wrapMode: Text.WordWrap
        anchors.top: gameText.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.right: parent.right
        anchors.rightMargin: 50
    }

    ListView {
        id: list
        anchors.top: hintText.bottom
        anchors.topMargin: 22
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 100 // above the page's button bar (A select, B back), which stays on top
        clip: true
        model: picker.rowCount
        highlightMoveDuration: 120
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height * 0.2
        preferredHighlightEnd: height * 0.8

        delegate: Rectangle {
            readonly property bool active: ListView.isCurrentItem
            readonly property bool isNew: index >= picker.rows.length
            readonly property var row: isNew ? null : picker.rows[index]
            width: list.width
            height: 80
            color: active ? (isNew ? "#1a9fff" : "#30343A") : "transparent"

            // tick box
            Rectangle {
                id: box
                visible: !isNew
                width: 38; height: 38
                radius: 5
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                color: row && row.member ? (row.mine ? "#1a9fff" : "#5B6470") : "transparent"
                border.width: row && row.member ? 0 : 2
                border.color: "#8B929A"
                Text {
                    anchors.centerIn: parent
                    visible: !!row && row.member
                    text: "✓"
                    color: "white"
                    font.pixelSize: 28
                    font.family: bold.name
                }
            }
            Text {
                id: nameText
                text: isNew ? "+  New collection…" : (row ? row.name : "")
                color: isNew && !active ? "#1a9fff" : "white"
                font.pixelSize: 30
                font.family: bold.name
                elide: Text.ElideRight
                anchors.left: isNew ? parent.left : box.right
                anchors.leftMargin: isNew ? 50 : 24
                anchors.right: infoText.left
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: infoText
                text: !row ? ""
                    : (row.member && !row.mine ? "From your library  ·  " : "")
                      + row.count + (row.count === 1 ? " game" : " games")
                color: "#A0A7AF"
                font.pixelSize: 24
                font.family: bold.name
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
            MouseArea {
                anchors.fill: parent
                onClicked: { if (list.currentIndex === index) picker.activate(index); else list.currentIndex = index }
            }
        }
    }

    TextEntry {
        id: nameEntry
        z: 10
        title: "New collection"
        hint: "A name for it, like \"Games\" (an existing collection's name adds the game to that one). Leave it empty to cancel."
        maxLength: 60
        onAccepted: {
            picker.addNew(text)
            picker.forceActiveFocus()
        }
    }
}
