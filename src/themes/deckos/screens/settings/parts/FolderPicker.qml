// DECKOS: controller-friendly folder browser (Settings > Library > Add a game folder, Profile picture,
// the DeckOS folder, a game's own artwork). A opens a folder (or picks a file when filesMode), B goes up
// one level and closes at the top, the first entry picks the folder being shown. With allowNewFolder,
// the second entry asks for a new folder in the one shown (newFolderRequested).
import QtQuick 2.15
import Pegasus.FolderListModel 1.0

FocusScope {
    id: picker
    anchors.fill: parent
    visible: false

    property string title: "Choose a folder"
    property string hint: "Open a folder with A, go back with B. Pick the folder that holds your games."
    // filesMode: list files with these extensions and pick one of them instead of a folder
    property bool filesMode: false
    property var fileExtensions: []
    property bool allowNewFolder: false
    /// opened here (an absolute path) instead of where it was last
    property string startFolder: ""

    signal picked(string path)
    signal closed()
    signal newFolderRequested(string parentPath)

    function open() {
        if (startFolder !== "") folders.cd(startFolder)
        visible = true
        list.currentIndex = 0
        forceActiveFocus()
    }
    function close() {
        visible = false
        closed()
    }

    FolderListModel {
        id: folders
        // folders are always listed; files only when they match (the extensions need the dot)
        files: []
        extensions: picker.filesMode ? picker.fileExtensions : []
    }

    // row 0 picks the folder being shown (folder mode only); the model itself lists ".." first, then
    // folders, then matching files. "/" is the virtual list of drives and cannot be picked.
    readonly property int extraRows: picker.filesMode ? 0 : (picker.allowNewFolder ? 2 : 1)
    readonly property int rowCount: extraRows + folders.count
    readonly property bool canUseFolder: folders.folder !== "/" && folders.folder !== ""

    function activate(i) {
        if (!picker.filesMode && i === 0) {
            if (canUseFolder) { visible = false; picked(folders.folder) }
            return
        }
        if (!picker.filesMode && picker.allowNewFolder && i === 1) {
            if (canUseFolder) newFolderRequested(folders.folder)
            return
        }
        var e = folders.get(i - extraRows)
        if (!e || e.name === undefined) return
        if (e.isDir) { folders.cd(e.name); list.currentIndex = 0 }
        else if (picker.filesMode) {
            var base = folders.folder
            visible = false
            picked(base.charAt(base.length - 1) === "/" ? base + e.name : base + "/" + e.name)
        }
    }

    Keys.onPressed: {
        if (event.isAutoRepeat && (api.keys.isAccept(event) || api.keys.isCancel(event))) { event.accepted = true; return }
        if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
            event.accepted = true
            close()
        } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
            event.accepted = true
            activate(list.currentIndex)
            try { sAccept.stop(); sAccept.play() } catch (e) {}
        } else if (event.key === Qt.Key_Up) {
            event.accepted = true
            if (list.currentIndex > 0) { list.currentIndex--; try { sNav.stop(); sNav.play() } catch (e) {} }
        } else if (event.key === Qt.Key_Down) {
            event.accepted = true
            if (list.currentIndex < rowCount - 1) { list.currentIndex++; try { sNav.stop(); sNav.play() } catch (e) {} }
        } else if (api.keys.isPageUp(event) || api.keys.isPrevPage(event)) {
            event.accepted = true
            list.currentIndex = Math.max(0, list.currentIndex - 8)
        } else if (api.keys.isPageDown(event) || api.keys.isNextPage(event)) {
            event.accepted = true
            list.currentIndex = Math.min(rowCount - 1, list.currentIndex + 8)
        } else {
            event.accepted = true // modal: nothing reaches the page underneath
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#0F1318"
        MouseArea { anchors.fill: parent }
    }

    Text {
        id: titleText
        text: picker.title
        color: "white"
        font.pixelSize: 50
        font.family: bold.name
        font.bold: true
        anchors.top: parent.top
        anchors.topMargin: 70
        anchors.left: parent.left
        anchors.leftMargin: 50
    }
    Text {
        id: hintText
        text: picker.hint
        color: "lightgray"
        font.pixelSize: 24
        font.family: bold.name
        wrapMode: Text.WordWrap
        anchors.top: titleText.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.right: parent.right
        anchors.rightMargin: 50
    }
    Rectangle {
        id: pathBox
        anchors.top: hintText.bottom
        anchors.topMargin: 24
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.right: parent.right
        anchors.rightMargin: 50
        height: 64
        radius: 5
        color: "#23262B"
        Text {
            text: folders.folder
            color: "white"
            font.pixelSize: 26
            font.family: bold.name
            elide: Text.ElideLeft
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    ListView {
        id: list
        anchors.top: pathBox.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 90
        clip: true
        model: picker.rowCount
        highlightMoveDuration: 120
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height * 0.2
        preferredHighlightEnd: height * 0.8

        delegate: Rectangle {
            readonly property bool active: ListView.isCurrentItem
            readonly property bool isUse: !picker.filesMode && index === 0
            readonly property bool isNew: !picker.filesMode && picker.allowNewFolder && index === 1
            // reading folders.folder makes this re-evaluate after every cd() (same row count, new names)
            readonly property var entry: folders.folder !== null && index >= picker.extraRows ? folders.get(index - picker.extraRows) : null
            readonly property bool isUp: !!entry && entry.name === ".."
            width: list.width
            height: 80
            color: active ? (isUse ? "#1a9fff" : "#30343A") : "transparent"
            opacity: (isUse || isNew) && !picker.canUseFolder ? 0.4 : 1.0

            Text {
                text: isUse ? "✓  Use this folder"
                    : isNew ? "+  New folder here"
                    : isUp ? "‹  Up one level"
                    : entry ? ((entry.isDir ? "▸  " : "    ") + entry.name) : ""
                color: isUse && !active ? "#1a9fff" : "white"
                font.pixelSize: 28
                font.family: bold.name
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.leftMargin: 50
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
}
