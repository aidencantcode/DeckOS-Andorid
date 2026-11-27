// DECKOS: a collection's properties (Library > Collections > X > Properties): its icon. Dynamic is
// StMini's collage of the games' covers; Custom is a picture of your own - from SteamGridDB (console,
// launcher and game icons, square grids, logos) or from storage. Switching back to Dynamic keeps the
// picture for later. Saved by deckos.collections (UserCollections.h); SteamGridDB is searched and the
// picture downloaded by deckos.scraper (Scraper.h), nothing over the network from QML but thumbnails.
//
// Main view: D-pad rows, A picks, B closes. SteamGridDB view: the matching entries on the left, their
// artwork on the right; LB/RB change the kind, Y searches for something else, A picks, B goes back.
import QtQuick 2.15

FocusScope {
    id: page
    anchors.fill: parent
    visible: false

    property var collection: null
    property string name: ""
    property string message: ""

    signal closed()

    readonly property var store: (typeof deckos !== "undefined" && deckos) ? deckos.collections : null
    readonly property var scraper: (typeof deckos !== "undefined" && deckos) ? deckos.scraper : null
    readonly property var icon: (store && name !== "") ? store.icons[name.toLowerCase()] : undefined
    readonly property bool hasPicture: !!icon
    readonly property bool custom: hasPicture && icon.custom
    readonly property real u: Math.min(width / 1920, height / 1080)
    readonly property bool narrow: width < 1500

    function open(coll) {
        collection = coll
        name = coll && coll.name ? coll.name : ""
        message = ""
        view = "main"
        current = 0
        visible = true
        forceActiveFocus()
    }
    function close() {
        if (!visible) return
        visible = false
        closed()
    }

    // ---- main view -------------------------------------------------------------------------------
    property string view: "main" // "main" | "sgdb"
    property int current: 0
    readonly property var rows: [
        { id: "mode", label: "Icon", desc: "Dynamic shows the covers of its games; Custom shows your picture" },
        { id: "sgdb", label: "Find on SteamGridDB…", desc: "Console, launcher and game icons, square grids and logos" },
        { id: "file", label: "Choose a picture from storage…", desc: "A PNG, JPG or WebP picture on this device" },
        { id: "fit", label: "Show the whole picture", desc: "On for icons and logos; off fills the tile" },
        { id: "done", label: "Done", desc: "" }
    ]
    function rowEnabled(id) { return id !== "fit" || hasPicture }
    function rowValue(id) {
        if (id === "mode") return custom ? "Custom" : "Dynamic"
        if (id === "fit") return hasPicture ? (icon.fit ? "On" : "Off") : ""
        return ""
    }

    function activate(id) {
        message = ""
        if (id === "mode") {
            if (!hasPicture) { message = "Pick a picture first: from SteamGridDB or from storage"; current = 1; return }
            store.setCustomIcon(name, !custom)
        } else if (id === "sgdb") {
            openSteamGrid(name)
        } else if (id === "file") {
            filePicker.open()
        } else if (id === "fit") {
            if (!hasPicture) return
            var err = store.setIcon(name, icon.source, !icon.fit)
            if (err !== "") message = err
        } else {
            close()
        }
    }

    function moveMain(step) {
        var i = current + step
        while (i >= 0 && i < rows.length && !rowEnabled(rows[i].id)) i += step
        if (i >= 0 && i < rows.length && i !== current) { current = i; sNav.stop(); sNav.play() }
    }

    // ---- SteamGridDB view ------------------------------------------------------------------------
    property string term: ""
    property var entries: []
    property int entryIndex: 0
    property int shownGameId: 0
    readonly property var kinds: [ { id: "icons", label: "Icons" }, { id: "grids", label: "Square grids" }, { id: "logos", label: "Logos" } ]
    property int kindIndex: 0
    property var items: []
    property bool searching: false
    property bool loadingItems: false
    property string savingUrl: ""
    property string sgdbError: ""
    property int zone: 0 // 0: entries, 1: artwork

    function openSteamGrid(searchFor) {
        view = "sgdb"
        zone = 0
        term = searchFor
        entries = []
        items = []
        shownGameId = 0
        sgdbError = ""
        searching = true
        scraper.findArtworkGames(searchFor)
    }
    function showEntry(i) {
        if (i < 0 || i >= entries.length) return
        entryIndex = i
        shownGameId = entries[i].id
        loadKind()
    }
    function loadKind() {
        items = []
        sgdbError = ""
        if (shownGameId <= 0) return
        loadingItems = true
        artGrid.currentIndex = 0
        scraper.findArtwork(shownGameId, kinds[kindIndex].id)
    }
    function pick(item) {
        if (!item || savingUrl !== "") return
        savingUrl = item.url
        sgdbError = ""
        scraper.saveArtwork(item.url)
    }

    Connections {
        target: page.scraper
        function onArtworkGames(t, games, error) {
            if (!page.visible || page.view !== "sgdb" || t !== page.term) return
            page.searching = false
            page.entries = games
            page.sgdbError = error !== "" ? error : (games.length === 0 ? "Nothing found for \"" + t + "\" - press Y to search for something else" : "")
            entryList.currentIndex = 0
            if (games.length > 0) page.showEntry(0)
        }
        function onArtworkList(gameId, kind, list, error) {
            if (!page.visible || gameId !== page.shownGameId || kind !== page.kinds[page.kindIndex].id) return
            page.loadingItems = false
            page.items = list
            page.sgdbError = error !== "" ? error : (list.length === 0 ? "No " + page.kinds[page.kindIndex].label.toLowerCase() + " for this one - try LB/RB or another entry" : "")
        }
        function onArtworkSaved(url, path, error) {
            if (url !== page.savingUrl) return
            page.savingUrl = ""
            if (error !== "") { page.sgdbError = error; return }
            var err = page.store.setIcon(page.name, path, page.kinds[page.kindIndex].id !== "grids")
            if (err !== "") { page.sgdbError = err; return }
            page.view = "main"
            page.current = 0
            page.message = "Icon set - it's shown in the Library now"
            sAccept.stop(); sAccept.play()
        }
    }

    // ---- keys ------------------------------------------------------------------------------------
    Keys.onPressed: {
        event.accepted = true
        var nav = event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right
        if (event.isAutoRepeat && !nav) return
        if (view === "main") {
            if (event.key === Qt.Key_Up) moveMain(-1)
            else if (event.key === Qt.Key_Down) moveMain(1)
            else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) { sAccept.stop(); sAccept.play(); activate(rows[current].id) }
            else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) { sBack.stop(); sBack.play(); close() }
            return
        }
        // SteamGridDB
        if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
            sBack.stop(); sBack.play()
            view = "main"; current = 1
        } else if (api.keys.isFilters(event)) {
            searchEntry.open(term)
        } else if (api.keys.isPrevPage(event) || api.keys.isNextPage(event)) {
            var k = kindIndex + (api.keys.isNextPage(event) ? 1 : -1)
            if (k >= 0 && k < kinds.length) { kindIndex = k; sTab.stop(); sTab.play(); loadKind() }
        } else if (zone === 0) {
            if (event.key === Qt.Key_Up && entryList.currentIndex > 0) { entryList.currentIndex--; sNav.stop(); sNav.play() }
            else if (event.key === Qt.Key_Down && entryList.currentIndex < entries.length - 1) { entryList.currentIndex++; sNav.stop(); sNav.play() }
            else if ((event.key === Qt.Key_Right || api.keys.isAccept(event) || event.key === Qt.Key_Return) && entries.length > 0) {
                if (entryList.currentIndex !== entryIndex) showEntry(entryList.currentIndex)
                if (items.length > 0 || event.key !== Qt.Key_Right) { zone = 1; sNav.stop(); sNav.play() }
            }
        } else {
            var cols = Math.max(1, Math.floor(artGrid.width / artGrid.cellWidth))
            var i = artGrid.currentIndex
            if (event.key === Qt.Key_Left) {
                if (i % cols === 0) { zone = 0; sNav.stop(); sNav.play() }
                else { artGrid.currentIndex = i - 1; sNav.stop(); sNav.play() }
            } else if (event.key === Qt.Key_Right && i < items.length - 1) { artGrid.currentIndex = i + 1; sNav.stop(); sNav.play() }
            else if (event.key === Qt.Key_Up && i - cols >= 0) { artGrid.currentIndex = i - cols; sNav.stop(); sNav.play() }
            else if (event.key === Qt.Key_Down && i + cols < items.length) { artGrid.currentIndex = i + cols; sNav.stop(); sNav.play() }
            else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) pick(items[i])
        }
    }

    // ---- look ------------------------------------------------------------------------------------
    Rectangle { anchors.fill: parent; color: "#0F1318" }
    MouseArea { anchors.fill: parent } // nothing reaches the Library under it

    Column {
        id: header
        x: 90 * page.u
        y: 60 * page.u
        width: parent.width - 2 * x
        spacing: 6 * page.u
        Text {
            text: page.view === "main" ? "COLLECTION PROPERTIES" : "STEAMGRIDDB"
            color: "#8b929a"
            font.family: bold.name
            font.pixelSize: 24 * page.u
            font.letterSpacing: 2 * page.u
        }
        Text {
            width: parent.width
            text: page.view === "main" ? page.name : "Results for “" + page.term + "”"
            color: "white"
            font.family: bold.name
            font.pixelSize: 52 * page.u
            elide: Text.ElideRight
        }
    }

    // main view
    Item {
        id: mainView
        visible: page.view === "main"
        anchors { top: header.bottom; topMargin: 50 * page.u; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 120 * page.u }

        Item { // the tile as the Library shows it
            id: preview
            x: 90 * page.u
            width: Math.min(page.width * (page.narrow ? 0.34 : 0.27), parent.height * 0.8)
            height: width

            Rectangle { anchors.fill: parent; color: "#23262e" }
            Image {
                anchors.fill: parent
                anchors.margins: page.custom && page.icon.fit ? parent.width * 0.14 : 0
                visible: page.custom
                source: page.custom ? page.icon.source : ""
                fillMode: page.custom && page.icon.fit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
            }
            Column {
                anchors.centerIn: parent
                width: parent.width * 0.8
                visible: !page.custom
                spacing: 14 * page.u
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "DYNAMIC"
                    color: "white"
                    font.family: bold.name
                    font.pixelSize: 34 * page.u
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: page.hasPicture ? "The covers of its games. Your picture is kept - switch Icon to Custom to use it."
                                          : "The covers of its games, like the Library shows them now."
                    color: "#8b929a"
                    font.family: bold.name
                    font.pixelSize: 22 * page.u
                }
            }
        }

        Column {
            id: rowsColumn
            anchors { left: preview.right; leftMargin: 60 * page.u; right: parent.right; rightMargin: 90 * page.u }
            spacing: 6 * page.u
            Repeater {
                model: page.rows
                delegate: Rectangle {
                    readonly property bool selected: page.current === index && page.view === "main"
                    readonly property bool usable: page.rowEnabled(modelData.id)
                    width: rowsColumn.width
                    height: (modelData.desc !== "" ? 104 : 80) * page.u
                    radius: 4 * page.u
                    color: selected ? "#3d4450" : "#1b2129"
                    opacity: usable ? 1 : 0.45
                    Rectangle { visible: parent.selected; width: 6 * page.u; height: parent.height; color: "#1a9fff" }
                    Column {
                        anchors { left: parent.left; leftMargin: 34 * page.u; right: valueText.left; rightMargin: 20 * page.u; verticalCenter: parent.verticalCenter }
                        spacing: 4 * page.u
                        Text { width: parent.width; text: modelData.label; color: "white"; font.family: bold.name; font.pixelSize: 30 * page.u; elide: Text.ElideRight }
                        Text { width: parent.width; visible: modelData.desc !== ""; text: modelData.desc; color: "#8b929a"; font.family: bold.name; font.pixelSize: 20 * page.u; elide: Text.ElideRight }
                    }
                    Text {
                        id: valueText
                        anchors { right: parent.right; rightMargin: 34 * page.u; verticalCenter: parent.verticalCenter }
                        text: page.rowValue(modelData.id)
                        color: modelData.id === "mode" && page.custom ? "#1a9fff" : "#c7d5e0"
                        font.family: bold.name
                        font.pixelSize: 28 * page.u
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.usable
                        onClicked: { if (page.current !== index) page.current = index; else page.activate(modelData.id) }
                    }
                }
            }
            Text {
                width: parent.width
                topPadding: 14 * page.u
                visible: page.message !== ""
                text: page.message
                color: page.message.indexOf("Icon set") === 0 ? "#7ecb6a" : "#ff9a9a"
                font.family: bold.name
                font.pixelSize: 24 * page.u
                wrapMode: Text.WordWrap
            }
        }
    }

    // SteamGridDB view
    Item {
        id: sgdbView
        visible: page.view === "sgdb"
        anchors { top: header.bottom; topMargin: 40 * page.u; left: parent.left; leftMargin: 90 * page.u; right: parent.right; rightMargin: 90 * page.u; bottom: parent.bottom; bottomMargin: 120 * page.u }

        ListView {
            id: entryList
            width: parent.width * (page.narrow ? 0.34 : 0.27)
            height: parent.height
            clip: true
            model: page.entries
            spacing: 4 * page.u
            highlightMoveDuration: 120
            delegate: Rectangle {
                readonly property bool selected: ListView.isCurrentItem && page.zone === 0
                width: entryList.width
                height: 70 * page.u
                radius: 4 * page.u
                color: selected ? "#3d4450" : (index === page.entryIndex ? "#232a33" : "transparent")
                Rectangle { visible: index === page.entryIndex; width: 6 * page.u; height: parent.height; color: "#1a9fff" }
                Text {
                    anchors { left: parent.left; leftMargin: 26 * page.u; right: parent.right; rightMargin: 16 * page.u; verticalCenter: parent.verticalCenter }
                    text: modelData.name
                    color: "white"
                    font.family: bold.name
                    font.pixelSize: 25 * page.u
                    elide: Text.ElideRight
                }
                MouseArea { anchors.fill: parent; onClicked: { entryList.currentIndex = index; page.zone = 0; page.showEntry(index) } }
            }
            Text {
                anchors.centerIn: parent
                visible: page.searching
                text: "Searching…"
                color: "#8b929a"; font.family: bold.name; font.pixelSize: 26 * page.u
            }
        }

        Row { // kinds: LB / RB
            id: kindTabs
            anchors { left: entryList.right; leftMargin: 40 * page.u }
            spacing: 34 * page.u
            Text { text: "LB"; color: "#5c636c"; font.family: bold.name; font.pixelSize: 24 * page.u; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: page.kinds
                delegate: Column {
                    spacing: 6 * page.u
                    Text { text: modelData.label; color: index === page.kindIndex ? "white" : "#8b929a"; font.family: bold.name; font.pixelSize: 28 * page.u }
                    Rectangle { width: parent.width; height: 4 * page.u; color: index === page.kindIndex ? "#1a9fff" : "transparent" }
                    MouseArea { width: parent.width; height: 40 * page.u; onClicked: { page.kindIndex = index; page.loadKind() } }
                }
            }
            Text { text: "RB"; color: "#5c636c"; font.family: bold.name; font.pixelSize: 24 * page.u; anchors.verticalCenter: parent.verticalCenter }
        }

        GridView {
            id: artGrid
            anchors { left: entryList.right; leftMargin: 40 * page.u; right: parent.right; top: kindTabs.bottom; topMargin: 24 * page.u; bottom: parent.bottom }
            clip: true
            model: page.items
            cellWidth: width / Math.max(2, Math.floor(width / (230 * page.u)))
            cellHeight: cellWidth
            highlightMoveDuration: 120
            delegate: Item {
                width: artGrid.cellWidth
                height: artGrid.cellHeight
                readonly property bool selected: GridView.isCurrentItem && page.zone === 1
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8 * page.u
                    color: "#23262e"
                    border.width: parent.selected ? 4 * page.u : 0
                    border.color: "white"
                    Image {
                        anchors.fill: parent
                        anchors.margins: 12 * page.u
                        source: modelData.thumb
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }
                    Text {
                        anchors { right: parent.right; bottom: parent.bottom; margins: 8 * page.u }
                        visible: modelData.width > 0
                        text: modelData.width + "×" + modelData.height
                        color: "#8b929a"; font.family: bold.name; font.pixelSize: 16 * page.u
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: page.savingUrl === modelData.url
                        color: "#b0000000"
                        Text { anchors.centerIn: parent; text: "Saving…"; color: "white"; font.family: bold.name; font.pixelSize: 24 * page.u }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { page.zone = 1; if (artGrid.currentIndex !== index) artGrid.currentIndex = index; else page.pick(modelData) }
                }
            }
            Text {
                anchors.centerIn: parent
                width: parent.width * 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: page.loadingItems || page.sgdbError !== ""
                text: page.loadingItems ? "Loading…" : page.sgdbError
                color: page.loadingItems ? "#8b929a" : "#ff9a9a"
                font.family: bold.name
                font.pixelSize: 26 * page.u
            }
        }
    }

    // button hints, on a strip like the Library's bottom bar
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 82 * page.u
        color: "#0b0e12"
    }
    Row {
        anchors { right: parent.right; rightMargin: 60 * page.u; bottom: parent.bottom; bottomMargin: 16 * page.u }
        spacing: 44 * page.u
        // the theme's button font: Nintendo layout swaps A/B and X/Y, universal icons use its other glyphs
        function glyph(steam) {
            var nin = { "A": "B", "B": "A", "X": "Y", "Y": "X" }
            var uni = { "A": "А", "B": "В", "X": "Х", "Y": "У" }
            var l = theme.nintendoLayout ? nin[steam] : steam
            return theme.universalIcons ? uni[l] : l
        }
        Repeater {
            model: page.view === "main"
                   ? [ { b: parent.glyph("A"), t: "SELECT" }, { b: parent.glyph("B"), t: "BACK" } ]
                   : [ { b: parent.glyph("Y"), t: "SEARCH" }, { b: parent.glyph("A"), t: "PICK" }, { b: parent.glyph("B"), t: "BACK" } ]
            delegate: Row {
                spacing: 16 * page.u
                Text { text: modelData.b; font.family: icons.name; font.pixelSize: 48 * page.u; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: modelData.t; font.family: bold.name; font.pixelSize: 24 * page.u; color: "white"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    FolderPicker {
        id: filePicker
        title: "Choose a picture for " + page.name
        hint: "Open folders with A, go back with B. Pick a PNG, JPG or WebP picture."
        filesMode: true
        fileExtensions: [".png", ".jpg", ".jpeg", ".webp"]
        onPicked: {
            var err = page.store.setIcon(page.name, path, false)
            page.message = err !== "" ? err : "Icon set - it's shown in the Library now"
            page.forceActiveFocus()
        }
        onClosed: page.forceActiveFocus()
    }

    TextEntry {
        id: searchEntry
        title: "Search SteamGridDB"
        hint: "A console (\"Nintendo 64\"), a launcher or emulator (\"RetroArch\") or a game. Done, B or Start searches."
        maxLength: 80
        onAccepted: {
            page.forceActiveFocus()
            if (text.trim() !== "") page.openSteamGrid(text.trim())
        }
    }
}
