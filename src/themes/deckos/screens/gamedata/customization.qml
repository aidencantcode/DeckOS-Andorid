import QtQuick 2.0
import "../settings/parts" // DECKOS: FolderPicker (the artwork rows' own browser)

Item {
    id: customizationPage
    anchors.fill: parent

    // DECKOS: `theme` is the Properties page's (gamedata.qml), as in details.qml. StMini declared its own
    // here, which nothing ever set - the game was unknown (no artwork rows) and the key hints failed.


    property bool showBootAnimation: api.memory.has("showBootAnimation") ? api.memory.get("showBootAnimation") : true
    property int activeItemIndex: 0
    property int maxItemIndex: 2 + artRows.length // DECKOS: the three titles, then the artwork rows

    // DECKOS: the game's artwork (MediaLibrary): what each kind shows now, and the user's own files - A picks
    // one (Android's file manager; PC: DeckOS's browser), X browses in DeckOS, Y removes the user's own
    readonly property var media: (typeof deckos !== "undefined" && deckos) ? deckos.media : null
    readonly property var game: theme ? theme.currentGame : null
    property var artRows: []
    property string artMessage: ""
    readonly property int firstArtRow: 3
    readonly property var imageExts: [".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".PNG", ".JPG", ".JPEG", ".WEBP", ".GIF", ".BMP"]
    readonly property var videoExts: [".mp4", ".webm", ".mkv", ".mov", ".m4v", ".3gp", ".avi", ".MP4", ".WEBM", ".MKV", ".MOV", ".M4V", ".3GP", ".AVI"]
    // SteamGridDB picks made on the artwork page are web addresses in memory (theme.getAssetSource)
    readonly property var onlineKeys: ({ poster: "capsule", steam: "wideCapsule", logo: "logo", background: "hero" })

    function refreshArt() {
        artRows = media && game ? media.artwork(game) : []
    }
    // what Home, the Library and the game page show for this row (an online pick beats the game's files)
    function shownUrl(row) {
        if (!row) return ""
        if (onlineKeys[row.asset] !== undefined && theme && game) {
            var url = theme.getAssetSource(row.asset, game)
            if (url) return url
        }
        return row.url
    }
    function isOnline(row) {
        var url = shownUrl(row)
        return url.indexOf("http") === 0 && url !== row.url
    }
    function clearOnlinePick(asset) {
        var key = onlineKeys[asset]
        if (!key || !game) return false
        var name = "custom_assets_" + game.title
        var data = api.memory.has(name) ? api.memory.get(name) : null
        if (!data || !data.assets || !data.assets[key]) return false
        data.assets[key] = ""
        api.memory.set(name, data)
        return true
    }
    function artRow() {
        return activeItemIndex >= firstArtRow ? artRows[activeItemIndex - firstArtRow] : null
    }
    function chooseFile(row) {
        if (!row || !media || !game) return
        if (media.systemPicker) {
            artMessage = "Pick a " + (row.video ? "video" : "picture") + " in Android's file manager…"
            media.pickFile(game, row.asset)
        } else {
            browseFile(row)
        }
    }
    function browseFile(row) {
        if (!row) return
        artPicker.asset = row.asset
        artPicker.fileExtensions = row.video ? videoExts : imageExts
        artPicker.title = row.asset === "screenshot" ? "Add a screenshot" : "Choose the " + row.label.toLowerCase()
        artPicker.open()
        artPicker.startFolder = "" // next time it opens where it was left
    }
    function assigned(asset, error) {
        if (error === "cancelled") { artMessage = ""; return }
        if (error !== "") { artMessage = error; return }
        clearOnlinePick(asset) // the file shows, not an older online pick
        artMessage = "Saved in " + (media.folderSet ? "your DeckOS folder" : "DeckOS's media folder")
        refreshArt()
    }
    function handleX() {
        var row = artRow()
        if (row) browseFile(row)
    }
    function handleY() {
        var row = artRow()
        if (!row || !media || !game) return
        if (row.customCount > 0) {
            media.clearCustom(game, row.asset)
            artMessage = row.label + ": back to the scraped one"
        } else if (clearOnlinePick(row.asset)) {
            artMessage = row.label + ": the online pick is gone"
            refreshArt()
        }
    }
    function restoreFocus() {
        if (typeof settingsZoneFocusProxy !== "undefined") settingsZoneFocusProxy.forceActiveFocus()
    }
    // keep the selected row on screen (rows: 3 x 160 for the titles, the artwork header 100, then 170 each)
    function rowY(i) { return i < firstArtRow ? i * 160 : firstArtRow * 160 + 100 + (i - firstArtRow) * 170 }
    function rowH(i) { return i < firstArtRow ? 160 : 170 }
    onActiveItemIndexChanged: {
        var y = rowY(activeItemIndex), h = rowH(activeItemIndex)
        if (activeItemIndex === 0) rowsFlick.contentY = 0
        else if (y < rowsFlick.contentY) rowsFlick.contentY = Math.max(0, y - 20)
        else if (y + h > rowsFlick.contentY + rowsFlick.height)
            rowsFlick.contentY = Math.max(0, Math.min(rowsFlick.contentHeight - rowsFlick.height, y + h - rowsFlick.height + 20))
    }
    // (refreshArt also runs in Component.onCompleted below)
    onGameChanged: refreshArt()
    Connections {
        target: customizationPage.media
        function onArtworkChanged(g) { if (g === customizationPage.game) customizationPage.refreshArt() }
        function onPicked(g, asset, error) { if (g === customizationPage.game) customizationPage.assigned(asset, error) }
        function onBusyChanged() { if (customizationPage.media.busy) customizationPage.artMessage = "Copying…" }
    }
    Connections { // a scrape or another page changed the game's artwork
        target: customizationPage.game ? customizationPage.game.assets : null
        function onChanged() { customizationPage.refreshArt() }
    }

    // Оригинальное название игры - ключ хранения.
    // Берём из theme.currentGame (если есть), иначе из targetGameName в памяти.
        // 1. Делаем свойство пустой строкой
    property string originalGameTitle: ""

    // Рабочие переменные
    property string customSearchTitle: ""
    property string customSteamTitle: ""
    property string retroAchievementsTitle: ""

    property string activeField: "customSearch"
    property bool keyboardOpen: false

    // 2. Принудительно читаем название игры и данные КАЖДЫЙ РАЗ при вызове функции
    function refreshFromMemory() {
        var tempTitle = "";
        if (theme && theme.currentGame && theme.currentGame.title !== "") {
            tempTitle = theme.currentGame.title;
        } else {
            var mem = api.memory.get("targetGameName");
            tempTitle = (mem !== null && mem !== undefined && mem !== "") ? mem : "";
        }
        
        originalGameTitle = tempTitle;

        if (originalGameTitle === "") return;

        var data = api.memory.get("custom_assets_" + originalGameTitle);
        var ct = (data && data.customTitles) ? data.customTitles : {};
        
        customSearchTitle       = (ct.searchTitle           && ct.searchTitle           !== "") ? ct.searchTitle           : originalGameTitle;
        customSteamTitle        = (ct.steamTitle            && ct.steamTitle            !== "") ? ct.steamTitle            : originalGameTitle;
        retroAchievementsTitle  = (ct.retroAchievementsTitle && ct.retroAchievementsTitle !== "") ? ct.retroAchievementsTitle : originalGameTitle;
    }

    // 3. Триггеры: обновляем при загрузке И при каждом открытии страницы
    Component.onCompleted: { refreshFromMemory(); refreshArt() } // DECKOS: and the artwork rows
    
    onVisibleChanged: {
        if (visible) {
            refreshFromMemory();
        }
    }
    
    // (Опционально) Если тема переключает игру, пока страница открыта
    Connections {
        target: theme ? theme : null
        function onCurrentGameChanged() { refreshFromMemory() } // DECKOS: Qt 5.15 Connections syntax
    }


    // -------------------------------------------------------
    // Сохраняем все три поля в одну структуру custom_assets_<title>
    // -------------------------------------------------------
    function saveCustomTitles() {
        if (originalGameTitle === "") return
        // Читаем существующий объект, чтобы не затереть assets/gameId/timestamp
        var data = api.memory.get("custom_assets_" + originalGameTitle)
        if (!data) data = {
            currentGame: originalGameTitle,
            gameId: null,
            assets: { capsule: "", wideCapsule: "", logo: "", hero: "", icon: "" }
        }
        data.customTitles = {
            searchTitle:            (customSearchTitle      === "" || customSearchTitle      === originalGameTitle) ? "" : customSearchTitle,
            steamTitle:             (customSteamTitle       === "" || customSteamTitle       === originalGameTitle) ? "" : customSteamTitle,
            retroAchievementsTitle: (retroAchievementsTitle === "" || retroAchievementsTitle === originalGameTitle) ? "" : retroAchievementsTitle
        }
        api.memory.set("custom_assets_" + originalGameTitle, data)
    }

    onShowBootAnimationChanged: api.memory.set("showBootAnimation", showBootAnimation)

    function getCurrentFieldValue() {
        if (activeField === "customSearch") return customSearchTitle
        if (activeField === "customSteam")  return customSteamTitle
        if (activeField === "retroAch")     return retroAchievementsTitle
        return ""
    }

    function setCurrentFieldValue(v) {
        if      (activeField === "customSearch") customSearchTitle      = v
        else if (activeField === "customSteam")  customSteamTitle       = v
        else if (activeField === "retroAch")     retroAchievementsTitle = v
    }

    function handleAccept() {
        if (keyboardOpen) return
        if      (activeItemIndex === 0) openKeyboard("customSearch")
        else if (activeItemIndex === 1) openKeyboard("customSteam")
        else if (activeItemIndex === 2) openKeyboard("retroAch")
        else chooseFile(artRow()) // DECKOS: an artwork row
    }
    function handleLeft() {}
    function handleRight() {}
    function handleCancel() {}

    TextEdit {
        id: clipboardHelper
        visible: false
        function getClipboard() {
            text = "";
            paste();
            return text;
        }
    }

    function openKeyboard(field) {
        activeField = field
        keyboardOpen = true
        kbScope.cursorPosition = getCurrentFieldValue().length
        kbScope.forceActiveFocus()
    }


    Text {
        id: pageTitle
        text: "Customization"
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
        id: titleDivider
        height: 1
        width: parent.width - 100
        color: "#333"
        anchors.top: pageTitle.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
    }
    

    // DECKOS: scrolls (the artwork rows don't fit), following the selected row (onActiveItemIndexChanged)
    Flickable {
        id: rowsFlick
        anchors.top: titleDivider.bottom
        anchors.topMargin: 30
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60 // the button bar covers the page's last ~48 px
        contentHeight: rowsColumn.height + 40
        clip: true
        interactive: !customizationPage.keyboardOpen
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentY { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

    Column {
        id: rowsColumn
        width: rowsFlick.width
        spacing: 0

        
        
        // 0. Custom Search Title (для поиска на странице Search)
        Rectangle {
            width: parent.width
            height: 160
            color: (activeZone === 1 && activeItemIndex === 0) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text { text: "Custom Search Title"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                Text { text: "How this game is found on the Search page."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
            }

            Rectangle {
                id: ctInput
                width: parent.width * 0.38
                height: 75
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                color: (activeZone === 1 && activeItemIndex === 0) ? "white" : "#31343B"
                Behavior on color { ColorAnimation { duration: 150 } }
                clip: true

                Item {
                    id: ctScrollContent
                    height: parent.height
                    width: parent.width

                    property real cursorLocalX: ctCursorProvider.width
                    property real idealX: (parent.width / 2) - cursorLocalX
                    x: Math.min(20, idealX)
                    Behavior on x { NumberAnimation { duration: 100 } }

                    Text {
                        id: ctTextInner
                        anchors.verticalCenter: parent.verticalCenter
                        color: (activeZone === 1 && activeItemIndex === 0) ? "black" : "white"
                        font.pixelSize: 28
                        font.family: bold.name
                        text: customizationPage.customSearchTitle === "" ? "Enter title..." : customizationPage.customSearchTitle
                        opacity: customizationPage.customSearchTitle === "" ? 0.4 : 1
                    }

                    Rectangle {
                        width: 3; height: 38
                        color: ctTextInner.color
                        visible: customizationPage.keyboardOpen && customizationPage.activeField === "customSearch"
                        x: ctScrollContent.cursorLocalX
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: visible; loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0; duration: 500 }
                            NumberAnimation { from: 0; to: 1; duration: 500 }
                        }
                    }

                    Text {
                        id: ctCursorProvider
                        visible: false
                        font: ctTextInner.font
                        text: customizationPage.customSearchTitle.substring(0, kbScope.cursorPosition)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 0) {
                        customizationPage.openKeyboard("customSearch")
                    } else {
                        activeZone = 1
                        activeItemIndex = 0
                    }
                }
            }

            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // 1. Custom SteamGridDB Title (для поиска артов на SteamGridDB)
        Rectangle {
            width: parent.width
            height: 160
            color: (activeZone === 1 && activeItemIndex === 1) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text { text: "Custom SteamGridDB Title"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                Text { text: "How this game is searched on SteamGridDB."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
            }

            Rectangle {
                id: sgdbInput
                width: parent.width * 0.38
                height: 75
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                color: (activeZone === 1 && activeItemIndex === 1) ? "white" : "#31343B"
                Behavior on color { ColorAnimation { duration: 150 } }
                clip: true

                Item {
                    id: sgdbScrollContent
                    height: parent.height
                    width: parent.width

                    property real cursorLocalX: sgdbCursorProvider.width
                    property real idealX: (parent.width / 2) - cursorLocalX
                    x: Math.min(20, idealX)
                    Behavior on x { NumberAnimation { duration: 100 } }

                    Text {
                        id: sgdbTextInner
                        anchors.verticalCenter: parent.verticalCenter
                        color: (activeZone === 1 && activeItemIndex === 1) ? "black" : "white"
                        font.pixelSize: 28
                        font.family: bold.name
                        text: customizationPage.customSteamTitle === "" ? "Enter title..." : customizationPage.customSteamTitle
                        opacity: customizationPage.customSteamTitle === "" ? 0.4 : 1
                    }

                    Rectangle {
                        width: 3; height: 38
                        color: sgdbTextInner.color
                        visible: customizationPage.keyboardOpen && customizationPage.activeField === "customSteam"
                        x: sgdbScrollContent.cursorLocalX
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: visible; loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0; duration: 500 }
                            NumberAnimation { from: 0; to: 1; duration: 500 }
                        }
                    }

                    Text {
                        id: sgdbCursorProvider
                        visible: false
                        font: sgdbTextInner.font
                        text: customizationPage.customSteamTitle.substring(0, kbScope.cursorPosition)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 1) {
                        customizationPage.openKeyboard("customSteam")
                    } else {
                        activeZone = 1
                        activeItemIndex = 1
                    }
                }
            }

            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // 2. RetroAchievements Title (заготовка)
        Rectangle {
            width: parent.width
            height: 160
            color: (activeZone === 1 && activeItemIndex === 2) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text { text: "RetroAchievements Title"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                Text { text: "How this game will be matched on RetroAchievements (reserved)."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
            }

            Rectangle {
                id: raInput
                width: parent.width * 0.38
                height: 75
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                color: (activeZone === 1 && activeItemIndex === 2) ? "white" : "#31343B"
                Behavior on color { ColorAnimation { duration: 150 } }
                clip: true

                Item {
                    id: raScrollContent
                    height: parent.height
                    width: parent.width

                    property real cursorLocalX: raCursorProvider.width
                    property real idealX: (parent.width / 2) - cursorLocalX
                    x: Math.min(20, idealX)
                    Behavior on x { NumberAnimation { duration: 100 } }

                    Text {
                        id: raTextInner
                        anchors.verticalCenter: parent.verticalCenter
                        color: (activeZone === 1 && activeItemIndex === 2) ? "black" : "white"
                        font.pixelSize: 28
                        font.family: bold.name
                        text: customizationPage.retroAchievementsTitle === "" ? "Enter title..." : customizationPage.retroAchievementsTitle
                        opacity: customizationPage.retroAchievementsTitle === "" ? 0.4 : 1
                    }

                    Rectangle {
                        width: 3; height: 38
                        color: raTextInner.color
                        visible: customizationPage.keyboardOpen && customizationPage.activeField === "retroAch"
                        x: raScrollContent.cursorLocalX
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: visible; loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0; duration: 500 }
                            NumberAnimation { from: 0; to: 1; duration: 500 }
                        }
                    }

                    Text {
                        id: raCursorProvider
                        visible: false
                        font: raTextInner.font
                        text: customizationPage.retroAchievementsTitle.substring(0, kbScope.cursorPosition)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 2) {
                        customizationPage.openKeyboard("retroAch")
                    } else {
                        activeZone = 1
                        activeItemIndex = 2
                    }
                }
            }

            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // DECKOS: 3+. The artwork: what each kind shows now, where it comes from, and the user's own files
        Item {
            width: parent.width
            height: 100
            Text {
                id: artHeader
                text: "Artwork"
                color: "white"
                font.pixelSize: 34
                font.family: bold.name
                font.bold: true
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.top: parent.top
                anchors.topMargin: 18
            }
            Text {
                text: customizationPage.artMessage !== "" ? customizationPage.artMessage
                    : (customizationPage.media && customizationPage.media.systemPicker
                       ? "Ⓐ Choose a file   Ⓧ Browse in DeckOS   Ⓨ Remove yours"
                       : "Ⓐ / Ⓧ Choose a file   Ⓨ Remove yours")
                color: customizationPage.artMessage !== "" ? "#66c0f4" : "lightgray"
                font.pixelSize: 22
                font.family: bold.name
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.top: artHeader.bottom
                anchors.topMargin: 6
            }
        }

        Repeater {
            model: customizationPage.artRows

            Rectangle {
                readonly property int rowIndex: customizationPage.firstArtRow + index
                readonly property bool active: activeZone === 1 && activeItemIndex === rowIndex
                readonly property string shown: customizationPage.shownUrl(modelData)
                readonly property bool online: customizationPage.isOnline(modelData)
                width: parent.width
                height: 170
                color: active ? "#30343A" : "transparent"

                Rectangle {
                    id: thumb
                    x: 50
                    anchors.verticalCenter: parent.verticalCenter
                    width: 240
                    height: 135
                    radius: 4
                    color: "#1B1E23"
                    clip: true
                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        anchors.margins: 4
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: 480
                        source: modelData.video ? "" : shown
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: modelData.video || shown === "" || thumbImage.status === Image.Error
                        text: modelData.video ? (shown !== "" ? "▶  Video" : "No trailer")
                            : thumbImage.status === Image.Error ? "Can't show it" : "None"
                        color: "#8b929a"
                        font.pixelSize: 24
                        font.family: bold.name
                    }
                }

                Column {
                    anchors.left: thumb.right
                    anchors.leftMargin: 30
                    anchors.right: parent.right
                    anchors.rightMargin: 50
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Row {
                        spacing: 14
                        Text { text: modelData.label; color: "white"; font.pixelSize: 30; font.family: bold.name }
                        Rectangle {
                            readonly property string what: modelData.source === "custom" ? "Yours"
                                : online ? "Online pick"
                                : modelData.source === "scraped" ? "Scraped"
                                : modelData.source === "game" ? "Game files" : ""
                            visible: what !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: badgeText.implicitWidth + 20
                            height: 32
                            radius: 4
                            color: modelData.source === "custom" ? "#1a9fff" : "#3d4450"
                            Text { id: badgeText; anchors.centerIn: parent; text: parent.what; color: "white"; font.pixelSize: 20; font.family: bold.name }
                        }
                    }
                    Text { text: modelData.hint; color: "lightgray"; font.pixelSize: 24; font.family: bold.name }
                    Text {
                        width: parent.width
                        text: modelData.asset === "screenshot"
                              ? (modelData.count === 0 ? "None yet - A adds one" : modelData.count + (modelData.count === 1 ? " screenshot" : " screenshots")
                                 + (modelData.customCount > 0 ? " (" + modelData.customCount + " yours)" : "") + " - A adds one")
                              : (online ? shown : modelData.file)
                        color: "#8b929a"
                        font.pixelSize: 20
                        font.family: bold.name
                        elide: Text.ElideMiddle
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        activeZone = 1
                        activeItemIndex = rowIndex
                        customizationPage.chooseFile(modelData) // a tap picks a file at once
                    }
                }

                Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
    } // Flickable

    // DECKOS: DeckOS's own file browser for the artwork rows (X; A on PC) - works with the controller
    FolderPicker {
        id: artPicker
        property string asset: ""
        filesMode: true
        hint: "Open folders with A, go back with B, pick a file with A."
        startFolder: customizationPage.media ? customizationPage.media.defaultParent : ""
        onPicked: {
            if (customizationPage.media && customizationPage.game)
                customizationPage.assigned(asset, customizationPage.media.assignFile(customizationPage.game, asset, path))
            customizationPage.restoreFocus()
        }
        onClosed: customizationPage.restoreFocus()
    }

    FocusScope {
    id: kbScope
    anchors.fill: parent
    visible: customizationPage.keyboardOpen
    focus: customizationPage.keyboardOpen

    property int r: 2
    property int c: 5
    property bool isCaps: false
    property int cursorPosition: 0

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    onVisibleChanged: {
        if (visible) {
            opacity = 1;
            kbPanel.anchors.bottomMargin = -48;
            root.goToZone(0);
        } else {
            opacity = 0;
            kbPanel.anchors.bottomMargin = -kbPanel.height;
        }
    }

    function processInput(v) {
        if (!v || v === "") return;
        if (v === "Done") {
            // Сохраняем все три поля разом в custom_assets_<title>.customTitles
            customizationPage.saveCustomTitles()
            customizationPage.keyboardOpen = false
            return
        }

        var cur = customizationPage.getCurrentFieldValue()
        var maxLength = 40

        if (v === "paste") {
            var clip = clipboardHelper.getClipboard()
            if (clip) {
                clip = clip.replace(/[\r\n\t]+/g, "")
                var available = Math.max(0, maxLength - cur.length)
                var toInsert = clip.substring(0, available)
                cur = cur.substring(0, cursorPosition) + toInsert + cur.substring(cursorPosition)
                cursorPosition += toInsert.length
                customizationPage.setCurrentFieldValue(cur)
            }
            return
        }

        if (v === "caps") {
            isCaps = !isCaps
        } else if (v === "backspace") {
            if (cursorPosition > 0) {
                cur = cur.substring(0, cursorPosition - 1) + cur.substring(cursorPosition)
                cursorPosition--
            }
        } else if (v === "left") {
            if (cursorPosition > 0) cursorPosition--
        } else if (v === "right") {
            if (cursorPosition < cur.length) cursorPosition++
        } else {
            if (cur.length < maxLength) {
                var letter = (v.length === 1 && isCaps) ? v.toUpperCase() : v
                cur = cur.substring(0, cursorPosition) + letter + cur.substring(cursorPosition)
                cursorPosition += letter.length
            }
        }

        customizationPage.setCurrentFieldValue(cur)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            customizationPage.saveCustomTitles()
            customizationPage.keyboardOpen = false
        }
    }

    Rectangle {
        id: kbPanel
        width: animatedContent.width
        height: 405
        color: "#22262F"

        anchors.bottom: parent.bottom
        anchors.right: parent.right

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent; anchors.margins: 5; spacing: 4
            Repeater {
                    model: [
                        {row:0, wSum:15, keys:[{l:"`",v:"`"},{l:"1",v:"1"},{l:"2",v:"2"},{l:"3",v:"3"},{l:"4",v:"4"},{l:"5",v:"5"},{l:"6",v:"6"},{l:"7",v:"7"},{l:"8",v:"8"},{l:"9",v:"9"},{l:"0",v:"0"},{l:"-",v:"-"},{l:"=",v:"="},{l:"X",v:"backspace",w:2,isBS:true,isSpec:true}]},
                        {row:1, wSum:15, keys:[{l:"Tab",v:"   ",w:1.5,isSpec:true},{l:"Q",v:"q"},{l:"W",v:"w"},{l:"E",v:"e"},{l:"R",v:"r"},{l:"T",v:"t"},{l:"Y",v:"y"},{l:"U",v:"u"},{l:"I",v:"i"},{l:"O",v:"o"},{l:"P",v:"p"},{l:"[",v:"["},{l:"]",v:"]"},{l:"\\",v:"\\",w:1.5}]},
                        {row:2, wSum:15, keys:[{l:"Caps",v:"caps",w:1.8,isSpec:true},{l:"A",v:"a"},{l:"S",v:"s"},{l:"D",v:"d"},{l:"F",v:"f"},{l:"G",v:"g"},{l:"H",v:"h"},{l:"J",v:"j"},{l:"K",v:"k"},{l:"L",v:"l"},{l:";",v:";"},{l:"'",v:"'"},{l:"Enter",v:"Done",w:2.2,c:"#1A9EFF",isSpec:true}]},
                        {row:3, wSum:15, keys:[{l:"Shift",v:"caps",w:2.5,isSpec:true},{l:"Z",v:"z"},{l:"X",v:"x"},{l:"C",v:"c"},{l:"V",v:"v"},{l:"B",v:"b"},{l:"N",v:"n"},{l:"M",v:"m"},{l:",",v:","},{l:".",v:"."},{l:"/",v:"/"},{l:"Shift",v:"caps",w:2.5,isSpec:true}]},
                        {row:4, wSum:13.1, keys:[{l:"☺",v:"",w:1.2,isSpec:true},{l:" ",v:" ",w:6.5},{l:"🌐",v:"paste",w:1.2,isSpec:true},{l:"<",v:"left",w:1.2,isSpec:true},{l:">",v:"right",w:1.2,isSpec:true},{l:"Hide",v:"Done",w:1.8,isSpec:true}]}
                    ]
                delegate: Row {
                    width: kbPanel.width - 10; height: 75; spacing: 4
                    property int rowIndex: modelData.row
                    property real tWeight: modelData.wSum
                    Repeater {
                        model: modelData.keys
                        delegate: Rectangle {
    width: (parent.width / parent.tWeight) * (modelData.w || 1.0) - parent.spacing
    height: parent.height
    color: (kbScope.r === parent.rowIndex && kbScope.c === index) ? "white" : (modelData.isSpec ? "black" : "#0F1318")

    MouseArea {
        anchors.fill: parent
        onPressed: {
            kbScope.r = parent.parent.rowIndex
            kbScope.c = index
            if (typeof sType !== "undefined") sType.play()
            if (modelData.v !== "Done" && modelData.v !== "caps" && modelData.v !== "paste") {
                kbAutoRepeat.start()
            } else {
                kbScope.processInput(modelData.v)
            }
        }
        onReleased: kbAutoRepeat.stop()
        onExited: kbAutoRepeat.stop()
        onCanceled: kbAutoRepeat.stop()

        SequentialAnimation {
            id: kbAutoRepeat
            ScriptAction { script: kbScope.processInput(modelData.v) }
            PauseAnimation { duration: 500 }
            SequentialAnimation {
                loops: Animation.Infinite
                ScriptAction { script: { kbScope.processInput(modelData.v); if (typeof sType !== "undefined") sType.play() } }
                PauseAnimation { duration: 60 }
            }
        }
    }

    Item {
        anchors.fill: parent

        Text {
            id: spaceIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === " "
            font.pixelSize: 40
            text: "Y"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 20
        }

        Text {
            id: backspaceIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === "backspace"
            font.pixelSize: 40
            text: theme && theme.nintendoLayout ? (theme.universalIcons ? "У" : "Y") : (theme && theme.universalIcons ? "Х" : "X")
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }

        Text {
            id: backspaceText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === "backspace"
            font.pixelSize: 22
            text: "Backspace"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
            width: Math.min(implicitWidth, parent.width - 40); elide: Text.ElideRight
        }

        Text {
            id: enterIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Enter"
            font.pixelSize: 45
            text: ">"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }

        Text {
            id: enterText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Enter"
            font.pixelSize: 26
            text: "Enter"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
            width: Math.min(implicitWidth, parent.width - 40); elide: Text.ElideRight
        }

        Text {
            id: hideIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Hide" && modelData.v === "Done"
            font.pixelSize: 40
            text: theme && theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme && theme.universalIcons ? "В" : "B")
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }

        Text {
            id: hideText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Hide" && modelData.v === "Done"
            font.pixelSize: 24
            text: "Hide"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
            width: Math.min(implicitWidth, parent.width - 40); elide: Text.ElideRight
        }

        Text {
            id: leftShiftText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Shift" && index === 0
            font.pixelSize: 26
            text: "Shift"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
            width: Math.min(implicitWidth, parent.width * 0.5 - 15); elide: Text.ElideRight
        }

        Text {
            id: leftShiftIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Shift" && index === 0
            font.pixelSize: 45
            text: "<"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
        }

        Text {
            id: capsText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === "caps" && modelData.l !== "Shift"
            font.pixelSize: 26
            text: "Caps"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
            width: Math.min(implicitWidth, parent.width * 0.5 - 15); elide: Text.ElideRight
        }

        Text {
            id: capsIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === "caps" && modelData.l !== "Shift"
            font.pixelSize: 45
            text: "<"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
        }

        Text {
            id: rightShiftIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Shift" && index === 11
            font.pixelSize: 45
            text: "<"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }

        Text {
            id: rightShiftText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Shift" && index === 11
            font.pixelSize: 26
            text: "Shift"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
            width: Math.min(implicitWidth, parent.width - 40); elide: Text.ElideRight
        }

        Text {
            id: arrowText
            font.family: bold.name
            font.pixelSize: 30
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            text: modelData.v === "left" ? "<" : (modelData.v === "right" ? ">" : "")
            visible: modelData.v === "left" || modelData.v === "right"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            id: emojiGlobeText
            font.family: (modelData.l === "☺") ? icons.name : bold.name
            font.pixelSize: (modelData.l === "☺") ? 45 : 26
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            text: modelData.l === "☺" ? "😀" : (modelData.l === "🌐" ? "Paste" : "")
            visible: modelData.l === "☺" || modelData.l === "🌐"
            anchors.bottom: parent.bottom; anchors.bottomMargin: (modelData.l === "☺") ? 13 : 20
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            id: specTextOnly
            font.family: bold.name
            font.pixelSize: 26
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            text: modelData.l === "Tab" ? "Tab" : (modelData.l === "   " ? "   " : "")
            visible: !!modelData.isSpec && !spaceIcon.visible && !backspaceIcon.visible && !enterIcon.visible && !hideIcon.visible && !leftShiftText.visible && !capsText.visible && !rightShiftIcon.visible && !arrowText.visible && !emojiGlobeText.visible
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }

        Text {
            id: normalKeyText
            font.family: bold.name
            font.pixelSize: 26
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            text: {
                if (modelData.isSpec) return ""
                if (modelData.v.length === 1) return kbScope.isCaps ? modelData.l.toUpperCase() : modelData.l.toLowerCase()
                return modelData.l
            }
            visible: !modelData.isSpec
            anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.3; anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
}
                }
            }
        }
    }

    Keys.onPressed: {
        var rowCounts = [14, 14, 13, 12, 6]
        if (api.keys.isLeft(event)) { if (c > 0) { c--; if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } } event.accepted = true }
        else if (api.keys.isRight(event)) { if (c < rowCounts[r] - 1) { c++; if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } } event.accepted = true }
        else if (api.keys.isUp(event)) { if (r > 0) { r--; c = Math.min(c, rowCounts[r] - 1); if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } } event.accepted = true }
        else if (api.keys.isDown(event)) { if (r < 4) { r++; c = Math.min(c, rowCounts[r] - 1); if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } } event.accepted = true }
        else if (api.keys.isDetails(event)) { processInput("backspace"); event.accepted = true }
        else if (api.keys.isFilters(event)) { processInput(" "); event.accepted = true }
        else if (api.keys.isNextPage(event)) { processInput("Done"); event.accepted = true }
        else if (api.keys.isPrevPage(event)) { isCaps = !isCaps; event.accepted = true }
        else if (api.keys.isCancel(event)) { processInput("Done"); event.accepted = true }
        else if (api.keys.isAccept(event)) {
            var values = [
                ["`","1","2","3","4","5","6","7","8","9","0","-","=","backspace"],
                ["   ","q","w","e","r","t","y","u","i","o","p","[","]","\\"],
                ["caps","a","s","d","f","g","h","j","k","l",";","'","Done"],
                ["caps","z","x","c","v","b","n","m",",",".","/","caps"],
                ["",""," ","left","right","Done"]
            ]
            if (typeof sType !== "undefined") sType.play()
            processInput(values[r][c])
            event.accepted = true
        }
    }
}
}
