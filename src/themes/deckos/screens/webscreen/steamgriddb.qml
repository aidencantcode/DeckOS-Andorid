import QtQuick 2.15
import ".." // DECKOS: ProfileBadge
import QtMultimedia 5.9
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15
import SortFilterProxyModel 0.2

FocusScope {
    id: root
    anchors.fill: parent
    focus: true
    
    ShaderEffectSource {
    id: globalBlurSource
    anchors.fill: parent
    sourceItem: animatedContent
    live: true
    visible: false
    // ClampToEdge гарантирует отсутствие щелей при размытии
    wrapMode: ShaderEffectSource.ClampToEdge
}


    MouseArea {
        id: blockerArea
        anchors.fill: parent
        enabled: root.saving
        z: 9999 
        hoverEnabled: true 
        preventStealing: true 
        onClicked: {}
        onPressed: {}
        onReleased: {}
        onWheel: {} 
    }
    

    property int currentPage: 0
    property real topH: 95
    property var theme
    
    
    property bool optionsMenuVisible: false
    property var currentFocusedGame: null

    property int focusZone: 1
    property real animX: 0
    property real animOpacity: 1.0
    property bool isScrolled: false
    property bool closeMenuVisible: false

    // ==========================================
    // === ДАННЫЕ STEAMGRIDDB ===
    // ==========================================
    property bool saving: false
    property string pendingDelete: ""
    property string apiKey: (api.memory.has("steamGridApiKey") && api.memory.get("steamGridApiKey") !== "") ? api.memory.get("steamGridApiKey") : ((typeof deckos !== "undefined" && deckos) ? deckos.scraper.steamGridDbKey : "") // DECKOS: falls back to the scraper's key
     // Сделай так:
    property string gameName: {
    // 1. Получаем оригинальное название игры из темы
    var baseTitle = (theme && theme.currentGame) ? theme.currentGame.title : "";
    
    // Если игра не выбрана (пустая строка), дальше не идем
    if (!baseTitle) return "";

    // 2. Ищем кастомные данные в памяти по оригинальному названию
    var data = api.memory.get("custom_assets_" + baseTitle);
    
    // 3. Если в памяти есть сохраненный steamTitle, отдаем его
    if (data && data.customTitles && data.customTitles.steamTitle) {
        return data.customTitles.steamTitle;
    }
    
    // 4. Если кастомного названия нет, отдаем обычное оригинальное
    return baseTitle;
}


        onGameNameChanged: {
        if (gameName !== "") {
            loadSavedAssets(); // Сначала подтягиваем то, что уже сохранено в памяти
            searchGame();      // Затем парсим веб
        }
    }    

    
    property bool searching: true
    property var gameId: null
    property var verticalAssets: []
    property var horizontalAssets: []
    property var logoAssets: []
    property var headerAssets: []

    property var currentGameAssets: ({
        capsule: "",
        wideCapsule: "",
        logo: "",
        hero: ""
    })

    Timer {
        id: saveTimer
        interval: 2000
        onTriggered: {
            if (root.pendingDelete !== "") {
                var newAssets = {
                    capsule: root.currentGameAssets.capsule,
                    wideCapsule: root.currentGameAssets.wideCapsule,
                    logo: root.currentGameAssets.logo,
                    hero: root.currentGameAssets.hero
                };
                newAssets[root.pendingDelete] = "";
                root.currentGameAssets = newAssets;
                root.saveToMemoryFile();
                root.pendingDelete = "";
            }
            root.saving = false;
        }
    }

    function selectAsset(type, url) {
        if (currentGameAssets.hasOwnProperty(type)) {
            var newAssets = {
                capsule: currentGameAssets.capsule,
                wideCapsule: currentGameAssets.wideCapsule,
                logo: currentGameAssets.logo,
                hero: currentGameAssets.hero
            };
            newAssets[type] = url;
            currentGameAssets = newAssets;
        }
    }

    function httpGet(url, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url, true)
        xhr.setRequestHeader("Authorization", "Bearer " + root.apiKey)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    if (response.success) {
                        callback(response.data)
                    }
                }
            }
        }
        xhr.send()
    }

    function searchGame() {
        searching = true
        var url = "https://www.steamgriddb.com/api/v2/search/autocomplete/" + encodeURIComponent(gameName)
        httpGet(url, function(data) {
            if (data && data.length > 0) {
                gameId = data[0].id
                loadAssets()
            } else {
                searching = false
            }
        })
    }

    function sortAndFilterAssets(assets) {
        if (!assets) return []
        var filtered = assets.filter(function(asset) {
            return asset.nsfw !== true
        })
        filtered.sort(function(a, b) {
            var scoreA = (a.likes || 0) + (a.downloads || 0)
            var scoreB = (b.likes || 0) + (b.downloads || 0)
            if (a.author && a.author.name === "Steam") scoreA += 10000
            if (b.author && b.author.name === "Steam") scoreB += 10000
            return scoreB - scoreA
        })
        return filtered
    }

    function loadAssets() {
        if (!gameId) return

        httpGet("https://www.steamgriddb.com/api/v2/grids/game/" + gameId + "?dimensions=600x900,342x482,660x930&limit=100", function(data) {
            root.verticalAssets = sortAndFilterAssets(data || [])
        })

        httpGet("https://www.steamgriddb.com/api/v2/grids/game/" + gameId + "?dimensions=460x215,920x430&limit=100", function(data) {
            root.horizontalAssets = sortAndFilterAssets(data || [])
        })

        httpGet("https://www.steamgriddb.com/api/v2/logos/game/" + gameId + "?styles=official&limit=100", function(data) {
            root.logoAssets = sortAndFilterAssets(data || [])
        })

        httpGet("https://www.steamgriddb.com/api/v2/heroes/game/" + gameId + "?limit=100", function(data) {
            root.headerAssets = sortAndFilterAssets(data || [])
            searching = false
        })
    }

    function saveToMemoryFile() {
        var data = {
            currentGame: root.gameName,
            gameId: root.gameId,
            assets: root.currentGameAssets,
            timestamp: new Date().toISOString()
        }

        if (typeof api !== "undefined" && api.memory) {
            api.memory.set("custom_assets_" + root.gameName, data);
        }
    }
    
        function loadSavedAssets() {
        if (typeof api !== "undefined" && api.memory) {
            var savedData = api.memory.get("custom_assets_" + root.gameName);
            if (savedData && savedData.assets) {
                root.currentGameAssets = savedData.assets;
                return true; 
            } else {
                // Важно! Если для игры нет сохранений, обнуляем объект, 
                // иначе QML может оставить картинки от предыдущей игры
                root.currentGameAssets = {
                    capsule: "",
                    wideCapsule: "",
                    logo: "",
                    hero: ""
                };
            }
        }
        return false;
    }


    // ========== УНИВЕРСАЛЬНЫЙ КОМПОНЕНТ ДЛЯ СЕТКИ АССЕТОВ ==========
    Component {
        id: assetGridComponent

        FocusScope {
            property alias model: gridView.model
            property alias gridView: gridView
            property real verticalSpacing: 0
            property real ratio: 1.5
            property int cols: 5
            property int imgFillMode: Image.PreserveAspectCrop
            property string assetType: ""
            
            Rectangle {
                anchors.fill: parent
                color: "#0F1318"

                GridView {
                    id: gridView
                    anchors {
                        fill: parent
                        topMargin: 20
                        leftMargin: parent.width * 0.015
                        rightMargin: parent.width * 0.015
                        bottomMargin: 20
                    }

                    clip: false
                    cellWidth: width / item.cols
                    cellHeight: cellWidth * item.ratio + item.verticalSpacing
                    currentIndex: 0
                    focus: false
                    
                    snapMode: GridView.NoSnap
                    highlightRangeMode: GridView.ApplyRange
                    highlightMoveDuration: 250
                    cacheBuffer: cellHeight * 3

                    onContentYChanged: root.isScrolled = (contentY > 30)

                    Keys.onPressed: {
                        if (root.focusZone === 2) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (event.key === Qt.Key_Left) {
                                if (currentIndex > 0) {
                                    sNav.stop(); sNav.play();
                                    currentIndex--;
                                    event.accepted = true;
                                }
                            }
                            else if (event.key === Qt.Key_Right) {
                                if (currentIndex < count - 1) {
                                    sNav.stop(); sNav.play();
                                    currentIndex++;
                                    event.accepted = true;
                                }
                            }
                            else if (event.key === Qt.Key_Up) {
                                if (currentIndex < columnsCount) {
                                    sNav.stop(); sNav.play();
                                    root.goToZone(1);
                                    event.accepted = true;
                                } else {
                                    sNav.stop(); sNav.play();
                                    currentIndex -= columnsCount;
                                    event.accepted = true;
                                }
                            }
                            else if (event.key === Qt.Key_Down) {
                                if (currentIndex < count - columnsCount) {
                                    sNav.stop(); sNav.play();
                                    currentIndex += columnsCount;
                                    event.accepted = true;
                                }
                            }
                            // Внутри assetGridComponent -> GridView -> Keys.onPressed
else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
    var selected = model[currentIndex];
    if (selected && selected.url && assetType) {
        // Дублируем логику из MouseArea: выбор + сохранение
        root.selectAsset(assetType, selected.url);
        root.saving = true;
        root.saveToMemoryFile();
        saveTimer.start();
        sNav.stop(); sNav.play();
    }
    event.accepted = true;
}
                        }
                    }

                    delegate: Item {
                        id: itemRoot
                        width: gridView.cellWidth
                        height: gridView.cellHeight
                        property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                        Rectangle {
    id: gameContainer
    anchors.fill: parent 
    color: "transparent"
    scale: isFocused ? 0.96425 : 0.95
    Behavior on scale { NumberAnimation { duration: 150 } }
    
    Item {
        anchors {
            top: gameImage.bottom
            topMargin: 10
            left: gameImage.left
        }
        width: gameImage.width
        height: 18
        visible: modelData && modelData.author

        Row {
            spacing: 10
            AnimatedImage {
                width: 25
                height: 25
                source: modelData.author.avatar || ""
                visible: status === Image.Ready
                cache: true
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                playing: isFocused
            }
            Text {
                text: modelData.author.name || "Unknown"
                color: "#CCCCCC"
                font.pixelSize: 25
                elide: Text.ElideRight
                width: Math.min(implicitWidth, gameImage.width - 20)
            }
        }
    }

    AnimatedImage {
        id: loading
        width: Math.floor(gridView.cellWidth * 0.5)
        height: width * item.ratio 
        z: 1001
        anchors.centerIn: parent
        source: "../../assets/video/bouncing.gif"                             
        fillMode: Image.PreserveAspectFit
        playing: root.saving && isFocused 
        visible: root.saving && isFocused
        opacity: visible ? 1.0 : 0.0
    }

    Rectangle {
        width: Math.floor(gridView.cellWidth * 0.9)
        height: width * item.ratio 
        anchors.centerIn: parent
        color: "#000000"
        opacity: root.saving ? 0.8 : 0.0
        visible: opacity > 0 && isFocused
        z: 1000
        radius: theme.roundedCovers ? 24 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {
        width: Math.floor(gridView.cellWidth * 0.9)
        height: width * item.ratio 
        anchors.centerIn: parent
        z: 80
        color: "#555"
        radius: theme.roundedCovers ? 24 : 0
    }

    Rectangle {
        id: thumbMask
        width: Math.floor(gridView.cellWidth * 0.9)
        height: width * item.ratio 
        anchors.centerIn: parent
        radius: theme.roundedCovers ? 24 : 0
        visible: false
    }
    
    AnimatedImage {
        id: gameImage
        width: Math.floor(gridView.cellWidth * 0.9)
        height: width * item.ratio 
        z: 90
        anchors.centerIn: parent
        source: modelData ? modelData.thumb : ""
        fillMode: imgFillMode
        visible: status === Image.Ready
        cache: true
        asynchronous: true
        playing: isFocused

        layer.enabled: theme.roundedCovers
        layer.effect: OpacityMask {
            maskSource: thumbMask
        }
    }
    
    Item {
        width: gridView.cellWidth * 1.1
        height: width * item.ratio 
        anchors.centerIn: parent
        clip: false
        opacity: isFocused ? 0.2 : 0.0
        z: parent.z - 1
        
        Image {
            id: blurSource
            anchors.fill: parent
            source: modelData ? modelData.thumb : ""
            fillMode: Image.PreserveAspectCrop
            visible: false
            z: parent.z - 1
        }
        
        FastBlur {
            anchors.fill: parent
            anchors.margins: -20
            source: blurSource
            radius: 144
            transparentBorder: true
            z: parent.z - 1
        }
    }

    Rectangle {
        id: highlightBorder
        property real offset: 7
        width: gameImage.width + (offset * 2)
        height: gameImage.height + (offset * 2)
        anchors.centerIn: gameImage
        color: "transparent"
        border.width: 4
        border.color: "white"
        radius: theme.roundedCovers ? 32 : 2
        opacity: isFocused ? 0.5 : 0.0
        visible: isFocused
        z: 1000

        SequentialAnimation {
            id: appearAnim
            running: isFocused
            loops: 1
            ParallelAnimation {
                NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                NumberAnimation { target: highlightBorder; property: "radius"; to: theme.roundedCovers ? 32 : 0; duration: 200; easing.type: Easing.OutBack }
                NumberAnimation { target: highlightBorder; property: "offset"; to: 15; duration: 200; easing.type: Easing.OutBack }
                ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 200 }
                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 200 }
            }
            ParallelAnimation {
                NumberAnimation { target: highlightBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.InOutQuad }
                NumberAnimation { target: highlightBorder; property: "offset"; to: 10; duration: 200; easing.type: Easing.InOutQuad }
                NumberAnimation { target: highlightBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
            }
            SequentialAnimation {
                loops: Animation.Infinite
                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.2; duration: 500 }
                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 500 }
            }
        }
    }
}


                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!isFocused) {
                                    gridView.currentIndex = index
                                    gridView.forceActiveFocus()
                                    root.goToZone(2)
                                    sNav.stop(); sNav.play();
                                } else {
                                    if (modelData && modelData.url && assetType) {
                                        root.selectAsset(assetType, modelData.url)
                                        root.saving = true
                                        root.saveToMemoryFile()
                                        saveTimer.start()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: pageSwapAnim
        property int targetIdx: 0
        property int direction: 1
     
        onStarted: {}

        ParallelAnimation {
            NumberAnimation { target: root; property: "animOpacity"; to: 0.2; duration: 100 }
            NumberAnimation { target: root; property: "animX"; to: -root.width * 0.2 * pageSwapAnim.direction; duration: 150; easing.type: Easing.OutQuad }        
        }
        
        ScriptAction {
            script: {
                root.currentPage = pageSwapAnim.targetIdx
                topNavRow.currentIndex = pageSwapAnim.targetIdx
                root.animX = root.width * 0.2 * pageSwapAnim.direction
            }
        }
        
        ParallelAnimation {
            NumberAnimation { target: root; property: "animOpacity"; to: 1.0; duration: 250 }
            NumberAnimation { target: root; property: "animX"; to: 0; duration: 500; easing.type: Easing.OutExpo }
        }
    }

    function safeNav(newIdx) {
        if (newIdx === currentPage) return;
        if (pageSwapAnim.running) { pageSwapAnim.stop(); }
        pageSwapAnim.direction = (newIdx > currentPage) ? 1 : -1;
        pageSwapAnim.targetIdx = newIdx;
        pageSwapAnim.start();
    }

    readonly property real currentScrollY: {
        var gv = getCurrentGridView();
        return gv ? gv.contentY : 0;
    }

    function getCurrentGridView() {
        for (var i in contentContainer.loadedPages) {
            var page = contentContainer.loadedPages[i];
            if (page && page.visible) {
                return page.gridView ? page.gridView : page.gridCollections;
            }
        }
        return null;
    }

    Keys.onPressed: {
        if (leftBar.isOpen) return;

                if (event.key === Qt.Key_Down) {
            if (focusZone === 0) {
                sNav.stop(); sNav.play(); 
                goToZone(1)
                event.accepted = true
            }
            else if (focusZone === 1) {
                sNav.stop(); sNav.play(); 
                
                // Если мы на странице Manage, убеждаемся, что фокус уйдет на первый ассет
                if (root.currentPage === 4) {
                    var managePage = contentContainer.loadedPages[4];
                    if (managePage) {
                        goToZone(2);
                        // Опционально: явно фокусим первый элемент (например, capsuleFocus)
                        // если внутри PageManage не прописан default focus
                        if (managePage.startFocus) managePage.startFocus(); 
                    }
                } else {
                    goToZone(2);
                }
                
                event.accepted = true
            }
        }

        else if (api.keys.isPrevPage(event)) {
            if (focusZone === 2 || focusZone === 1) {
                if (currentPage > 0) {
                    sTab.stop(); sTab.play();
                    safeNav(currentPage - 1);
                    goToZone(1);
                }
                event.accepted = true
            }
        }
        else if (api.keys.isNextPage(event)) {
            if (focusZone === 2 || focusZone === 1) {
                if (currentPage < 4) {
                    sTab.stop(); sTab.play();
                    safeNav(currentPage + 1);
                    goToZone(1);
                }
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Up) {
            if (focusZone === 2) {
                event.accepted = false;
            }
            else if (focusZone === 1) {
                goToZone(0)
                sNav.stop(); sNav.play(); 
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Left) {
            if (focusZone === 0 && topButtonsNames.currentIndex > 0) {
                topButtonsNames.currentIndex--
                event.accepted = true
            }
            else if (focusZone === 1) {
                if (currentPage > 0) {
                    sTab.stop(); sTab.play();
                    safeNav(currentPage - 1);
                }
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Right) {
            if (focusZone === 0 && topButtonsNames.currentIndex < 3) {
                 topButtonsNames.currentIndex++
                event.accepted = true
            }
            else if (focusZone === 1) {
                if (currentPage < 4) {
                    sTab.stop(); sTab.play();
                    safeNav(currentPage + 1);
                }
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
            if (focusZone === 1) {
                currentPage = topNavRow.currentIndex
                event.accepted = true
            }
            else if (focusZone === 0) {
                event.accepted = true
            }
        }
        else if (api.keys.isMenu(event) && !root.optionsMenuVisible && !root.closeMenuVisible) {
            leftBar.toggle()
            event.accepted = true
        }
        else if (api.keys.isCancel(event) && !root.optionsMenuVisible && !root.closeMenuVisible) {      
            if (focusZone === 2) {
                goToZone(1)
                event.accepted = true
            }
            else if (focusZone === 0) {
                goToZone(1)
                event.accepted = true
            }
            else if (focusZone === 1) {
    var src = api.memory.has("steamGridSource") ? api.memory.get("steamGridSource") : 8
    api.memory.set("steamGridSource", null)
    root.startExitAnimation(src)
    event.accepted = true
}
        }
    }
    
    function goToZone(zoneIndex) {
    if (zoneIndex < 0) zoneIndex = 0
    if (zoneIndex > 2) zoneIndex = 2
    
    topNavRow.focus = false
    topButtonsNames.focus = false
    
    var currentGridView = getCurrentGridView();
    if (currentGridView) { currentGridView.focus = false }
    
    focusZone = zoneIndex
    
    if (zoneIndex === 1) {
        topNavRow.focus = true
        topNavRow.forceActiveFocus()
    }
    else if (zoneIndex === 0) {
        topButtonsNames.focus = true
        topButtonsNames.forceActiveFocus()
    }
    else if (zoneIndex === 2) {
        // Проверяем, не находимся ли мы на странице управления (индекс 4)
        if (root.currentPage === 4) {
            var managePage = contentContainer.loadedPages[4];
            if (managePage) {
                // Убираем лишнее свойство gridView, фокусим напрямую саму страницу
                managePage.focus = true;
                managePage.forceActiveFocus();
                // В функции goToZone(zoneIndex
            if (managePage.startFocus) managePage.startFocus(); 
        }
    }  else {
            // Стандартная логика для страниц с GridView
            currentGridView = getCurrentGridView();
            if (currentGridView) {
                currentGridView.focus = true
                currentGridView.forceActiveFocus()
            }
        }
    }
}

    
    Item {
        id: animatedContent
        anchors.fill: parent
        
        // Самый нижний слой (фоновая подложка)
    Rectangle {
        id: globalBackground
        anchors.fill: parent
        color: "#0F1318" // Тот самый цвет темы
        z: -100 // Всегда сзади всех
    }


        // ===============================
        // === ВЕРХНЯЯ ЗОНА (КНОПКИ) ===
        // ===============================
        Rectangle {
            id: topZone
            y: 95
            width: parent.width
            height: topH
            z: 2
            
            property real bgOpacity: Math.min(1.0, Math.max(0.0, (root.currentScrollY + 0) / 100))
            color: "transparent"

            Rectangle {
                id: topBarBg
                anchors.fill: parent
                color: "#0F1318"
                opacity: root.isScrolled ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 50 } }
            }
            
            Text {
                id: leftSideText
                anchors {
                    left: parent.left
                    leftMargin: 40
                    verticalCenter: parent.verticalCenter
                }
                text: "<"
                color: "white"
                font.pixelSize: 70
                font.family: icons.name
                opacity: (root.focusZone === 2||root.focusZone === 1) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            }

            Text {
                id: rightSideText
                anchors {
                    right: parent.right
                    rightMargin: 40
                    verticalCenter: parent.verticalCenter
                }
                text: ">"
                color: "white"
                font.pixelSize: 70
                font.family: icons.name
                opacity: (root.focusZone === 2||root.focusZone === 1) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                horizontalAlignment: Text.AlignRight
            }

            Row {
                id: topNavRow
                anchors.centerIn: parent
                spacing: 40
                focus: true
                property int currentIndex: 0
                
                Keys.enabled: true
                Keys.forwardTo: []
                
                Keys.onLeftPressed: {
                    if (currentIndex > 0) {
                        currentIndex--;
                        sTab.stop(); sTab.play();
                    safeNav(currentPage - 1);
                        currentPage = currentIndex;
                    }
                    event.accepted = true;
                }
                
                Keys.onRightPressed: {
                    if (currentIndex < 4) {
                        currentIndex++;
                        sTab.stop(); sTab.play();
                    safeNav(currentPage + 1);
                        currentPage = currentIndex;
                    }
                    event.accepted = true;
                }
                
                Keys.onReturnPressed: {
                    currentPage = currentIndex
                    event.accepted = true
                }

                Repeater {
                    model: [
                        { name: "CAPSULE" },
                        { name: "WIDE CAPSULE" },
                        { name: "LOGO" },
                        { name: "HERO" },
                        { name: "MANAGE" }
                    ]

                    delegate: Rectangle {
                        width: (index === 1) ? 280 : 220
                        height: 74
                        radius: 40
                        color: {
                            if (root.focusZone === 1 && index === currentPage) return "white"
                            else if (index === currentPage) return "#31343B"
                            else return "transparent"
                        }
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            font.pixelSize: 25
                            font.family: typeof bold !== "undefined" ? bold.name : ""
                            color: (root.focusZone === 1 && index === currentPage) ? "black" : "white"

                            text: {
                                var count = 0;
                                if (index === 0) count = root.verticalAssets.length;
                                else if (index === 1) count = root.horizontalAssets.length;
                                else if (index === 2) count = root.logoAssets.length;
                                else if (index === 3) count = root.headerAssets.length;
                                
                                if (index === 4) return modelData.name;
                                return modelData.name + "      <font color='#808080'>" + count + "</font>";
                            }
                            textFormat: Text.StyledText
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                sTab.stop(); sTab.play();
                                safeNav(index);
                                root.goToZone(1);
                            }
                        }
                    }
                }
            }
        }

        // ===============================
        // === НИЖНЯЯ ЗОНА (КОНТЕНТ) ===
        // ===============================
        Item {
            id: contentContainer
            x: root.animX
            opacity: root.animOpacity
            y: topZone.y + topZone.height
            width: parent.width
            height: parent.height - (topZone.y + topZone.height + bottomBar.height)
            
            property var loadedPages: ({})
            
            function showPage(index) {
                for (var i in loadedPages) {
                    if (loadedPages[i] && loadedPages[i].visible) {
                        loadedPages[i].visible = false;
                    }
                }
                
                if (loadedPages[index]) {
                    loadedPages[index].visible = true;
                } else {
                    createPage(index);
                }
            }
            
            function createPage(index) {
                var pages = [pageCapsule, pageWideCapsule, pageLogos, pageHeroes, pageManage];
                
                if (index >= 0 && index < pages.length) {
                    var component = pages[index];
                    var page = component.createObject(contentContainer, {
                        "width": contentContainer.width,
                        "height": contentContainer.height,
                        "visible": true
                    });
                    if (page) {
                        loadedPages[index] = page;
                        preloadAdjacentPages(index);
                    }
                }
            }
            
            function preloadAdjacentPages(currentIdx) {
                var pages = [pageCapsule, pageWideCapsule, pageLogos, pageHeroes, pageManage];
                var indices = [];
                
                if (currentIdx < pages.length - 1) indices.push(currentIdx + 1);
                if (currentIdx > 0) indices.push(currentIdx - 1);
                for (var i = 0; i < indices.length; i++) {
                    var idx = indices[i];
                    if (!loadedPages[idx]) {
                        var page = pages[idx].createObject(contentContainer, {
                            "width": contentContainer.width,
                            "height": contentContainer.height,
                            "visible": false
                        });
                        if (page) {
                            loadedPages[idx] = page;
                        }
                    }
                }
            }
            
            Component.onCompleted: {
                createPage(root.currentPage);
            }
            
            Connections {
                target: root
                function onCurrentPageChanged() {
                    contentContainer.showPage(root.currentPage);
                }
            }
        }

        // ===============================
        // === 5 СТРАНИЦ ===
        // ===============================
        Component {
            id: pageCapsule
            FocusScope {
                width: parent.width
                height: parent.height
                property var gridView: gridLoader.item ? gridLoader.item.gridView : null

                Loader {
                    id: gridLoader
                    anchors.fill: parent
                    sourceComponent: assetGridComponent
                    onLoaded: {
                        item.model = Qt.binding(function() { return root.verticalAssets })
                        item.ratio = 1.5
                        item.cols = 5
                        item.imgFillMode = Image.PreserveAspectCrop
                        item.assetType = "capsule"
                    }
                }
            }
        }

        Component {
            id: pageWideCapsule
            FocusScope {
                width: parent.width
                height: parent.height
                property var gridView: gridLoader.item ? gridLoader.item.gridView : null

                Loader {
                    id: gridLoader
                    anchors.fill: parent
                    sourceComponent: assetGridComponent
                    onLoaded: {
                        item.model = Qt.binding(function() { return root.horizontalAssets })
                        item.ratio = 0.467
                        item.cols = 4
                        item.verticalSpacing = 45 
                        item.imgFillMode = Image.PreserveAspectCrop
                        item.assetType = "wideCapsule"
                    }
                }
            }
        }

        Component {
            id: pageLogos
            FocusScope {
                width: parent.width
                height: parent.height
                property var gridView: gridLoader.item ? gridLoader.item.gridView : null

                Loader {
                    id: gridLoader
                    anchors.fill: parent
                    sourceComponent: assetGridComponent
                    onLoaded: {
                        item.model = Qt.binding(function() { return root.logoAssets })
                        item.ratio = 1
                        item.cols = 4
                        item.imgFillMode = Image.PreserveAspectFit
                        item.assetType = "logo"
                    }
                }
            }
        }

        Component {
            id: pageHeroes
            FocusScope {
                width: parent.width
                height: parent.height
                property var gridView: gridLoader.item ? gridLoader.item.gridView : null

                Loader {
                    id: gridLoader
                    anchors.fill: parent
                    sourceComponent: assetGridComponent
                    onLoaded: {
                        item.model = Qt.binding(function() { return root.headerAssets })
                        item.ratio = 0.32
                        item.cols = 3
                        item.verticalSpacing = 45 
                        item.imgFillMode = Image.PreserveAspectCrop
                        item.assetType = "hero"
                    }
                }
            }
        }

        Component {
    id: pageManage
    FocusScope {
        id: manageRoot
        width: parent.width
        height: parent.height

        // ЭТА ФУНКЦИЯ РЕШИТ ПРОБЛЕМУ:
        function startFocus() {
            wideFocus.forceActiveFocus();
        }

                Keys.onPressed: {
            if (root.focusZone === 2) {
                // 1. Переход ВВЕРХ: из WideCapsule или Capsule в TopZone
                if (event.key === Qt.Key_Up) {
                    if (wideFocus.activeFocus || capsuleFocus.activeFocus) {
                        root.goToZone(1); // Переход в навигацию вкладок
                    } else if (logoFocus.activeFocus || logoDeleteFocus.activeFocus) {
                        wideFocus.forceActiveFocus();
                        manageFlickable.ensureVisible(wideRect);
                    } else if (heroFocus.activeFocus || heroDeleteFocus.activeFocus) {
                        logoFocus.forceActiveFocus();
                        manageFlickable.ensureVisible(logoRect);
                    }
                    sNav.stop(); sNav.play();
                    event.accepted = true;
                }
                
                // 2. Навигация ВНИЗ
                else if (event.key === Qt.Key_Down) {
                    if (wideFocus.activeFocus || wideDeleteFocus.activeFocus || capsuleFocus.activeFocus || capsuleDeleteFocus.activeFocus) {
                        logoFocus.forceActiveFocus();
                        manageFlickable.ensureVisible(logoRect);
                    } else if (logoFocus.activeFocus || logoDeleteFocus.activeFocus) {
                        heroFocus.forceActiveFocus();
                        manageFlickable.ensureVisible(heroRect);
                    }
                    sNav.stop(); sNav.play();
                    event.accepted = true;
                }

                // 3. Навигация ВЛЕВО/ВПРАВО (между Capsule и WideCapsule)
                else if (event.key === Qt.Key_Left) {
                    if (wideFocus.activeFocus || wideDeleteFocus.activeFocus) {
                        capsuleFocus.forceActiveFocus();
                    } else if (capsuleDeleteFocus.activeFocus) {
                        capsuleFocus.forceActiveFocus();
                    } else if (wideDeleteFocus.activeFocus) {
                        wideFocus.forceActiveFocus();
                    } else if (logoDeleteFocus.activeFocus) {
                        logoFocus.forceActiveFocus();
                    } else if (heroDeleteFocus.activeFocus) {
                        heroFocus.forceActiveFocus();
                    }
                    sNav.stop(); sNav.play();
                    event.accepted = true;
                }
                
                else if (event.key === Qt.Key_Right) {
                    if (capsuleFocus.activeFocus || capsuleDeleteFocus.activeFocus) {
                        wideFocus.forceActiveFocus();
                    }
                    sNav.stop(); sNav.play();
                    event.accepted = true;
                }

                // 4. Нажатие isAccept: Переход на кнопку удаления (DeleteFocus)
                else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                    // Переход С картинки НА корзину
                    if (wideFocus.activeFocus && root.currentGameAssets.wideCapsule !== "") {
                        wideDeleteFocus.forceActiveFocus();
                    } else if (capsuleFocus.activeFocus && root.currentGameAssets.capsule !== "") {
                        capsuleDeleteFocus.forceActiveFocus();
                    } else if (logoFocus.activeFocus && root.currentGameAssets.logo !== "") {
                        logoDeleteFocus.forceActiveFocus();
                    } else if (heroFocus.activeFocus && root.currentGameAssets.hero !== "") {
                        heroDeleteFocus.forceActiveFocus();
                    } 
                    // Если фокус уже на корзине — выполняем удаление
                    else if (wideDeleteFocus.activeFocus) {
                        root.pendingDelete = "wideCapsule"; root.saving = true; saveTimer.start();
                    } else if (capsuleDeleteFocus.activeFocus) {
                        root.pendingDelete = "capsule"; root.saving = true; saveTimer.start();
                    } else if (logoDeleteFocus.activeFocus) {
                        root.pendingDelete = "logo"; root.saving = true; saveTimer.start();
                    } else if (heroDeleteFocus.activeFocus) {
                        root.pendingDelete = "hero"; root.saving = true; saveTimer.start();
                    }
                    sNav.stop(); sNav.play();
                    event.accepted = true;
                }
            }
        }

        
                Flickable {
                    id: manageFlickable
                    anchors.fill: parent
                    contentWidth: parent.width
                    contentHeight: mainColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Behavior on contentY { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    function ensureVisible(item) {
                        if (!item) return;
                        var itemY = item.mapToItem(mainColumn, 0, 0).y;
                        var itemHeight = item.height;
                        var flickableHeight = manageFlickable.height;
                        var currentY = manageFlickable.contentY;
                        if (itemY < currentY) {
                            manageFlickable.contentY = itemY;
                        } else if (itemY + itemHeight > currentY + flickableHeight) {
                            manageFlickable.contentY = itemY + itemHeight - flickableHeight;
                        }
                    }

                    Column {
                        id: mainColumn
                        width: parent.width
                        spacing: 0

                        Row {
                            width: parent.width
                            spacing: 0

                            // 1. CAPSULE
                            Rectangle {
                                id: capsuleRect
                                width: parent.width / 3.33
                                height: width * 1.5
                                color: "transparent"
                                FocusScope {
                                    id: capsuleFocus
                                    anchors.fill: parent
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            capsuleFocus.forceActiveFocus();
                                            manageFlickable.ensureVisible(capsuleRect);
                                            sNav.stop(); sNav.play();
                                        }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 40
                                    anchors.top: parent.top
                                    anchors.topMargin: 20
                                    text: "CAPSULE"
                                    font.pixelSize: 30
                                    font.family: bold.name
                                    color: "white"
                                }

                                Item {
                                    id: capsuleImageContainer
                                    anchors.fill: parent
                                    anchors.leftMargin: 40
                                    anchors.rightMargin: 15
                                    anchors.topMargin: 60
                                    anchors.bottomMargin: 15

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#2A2E35"
                                        radius: theme.roundedCovers ? 24 : 0
                                        visible: root.currentGameAssets.capsule === ""
                                    }

                                    Rectangle {
                                        id: capsuleMask
                                        anchors.fill: parent
                                        radius: theme.roundedCovers ? 24 : 0
                                        visible: false
                                    }

                                    AnimatedImage {
                                        id: capsuleImage
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: root.currentGameAssets.capsule !== "" 
                                                ? root.currentGameAssets.capsule 
                                                : (currentGame.assets.boxart || currentGame.assets.poster || "")
                                        visible: source != ""
                                        cache: true
                                        asynchronous: true
                                        playing: capsuleFocus.activeFocus || capsuleDeleteFocus.activeFocus

                                        layer.enabled: theme.roundedCovers
                                        layer.effect: OpacityMask {
                                            maskSource: capsuleMask
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#000000"
                                        opacity: (root.saving && (capsuleFocus.activeFocus || capsuleDeleteFocus.activeFocus)) ? 0.8 : 0.0
                                        visible: opacity > 0
                                        z: 1000
                                        radius: theme.roundedCovers ? 24 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }

                                    AnimatedImage {
                                        id: capsuleLoading
                                        width: Math.min(parent.width, parent.height) * 0.5
                                        height: width
                                        anchors.centerIn: parent
                                        source: "../../assets/video/bouncing.gif"                             
                                        fillMode: Image.PreserveAspectFit
                                        playing: root.saving && (capsuleFocus.activeFocus || capsuleDeleteFocus.activeFocus)
                                        visible: playing
                                        z: 1001
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 5
                                        width: 100
                                        height: 100
                                        radius: theme.roundedCovers ? 35 : 5
                                        color: capsuleDeleteFocus.activeFocus ? "white" : "#80000000"
                                        visible: root.currentGameAssets.capsule !== "" && capsuleFocus.activeFocus
                                        FocusScope {
                                            id: capsuleDeleteFocus
                                            anchors.fill: parent
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    capsuleDeleteFocus.forceActiveFocus()
                                                    if (capsuleDeleteFocus.activeFocus) {
                                                        root.pendingDelete = "capsule"
                                                        root.saving = true
                                                        saveTimer.start()
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Ь"
                                            font.pixelSize: 35
                                            font.family: icons.name
                                            color: capsuleDeleteFocus.activeFocus ? "black" : "white"
                                        }
                                    }

                                    Rectangle {
                                        id: capsuleBorder
                                        anchors.fill: parent
                                        anchors.margins: -7
                                        color: "transparent"
                                        border.width: 5
                                        border.color: "grey"
                                        radius: theme.roundedCovers ? 32 : 2
                                        opacity: capsuleFocus.activeFocus ? 1.0 : 0.0
                                        visible: capsuleFocus.activeFocus

                                        SequentialAnimation {
                                            id: capsuleAnim
                                            running: capsuleFocus.activeFocus
                                            loops: 1
                                            ParallelAnimation {
                                                NumberAnimation { target: capsuleBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                                NumberAnimation { target: capsuleBorder; property: "radius"; to: theme.roundedCovers ? 32 : 0; duration: 200; easing.type: Easing.OutBack }
                                                NumberAnimation { target: capsuleBorder; property: "scale"; to: 1.02; duration: 200; easing.type: Easing.OutBack }
                                                ColorAnimation { target: capsuleBorder; property: "border.color"; to: "white"; duration: 200 }
                                                NumberAnimation { target: capsuleBorder; property: "opacity"; to: 0.5; duration: 200 }
                                            }
                                            ParallelAnimation {
                                                NumberAnimation { target: capsuleBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.InOutQuad }
                                                NumberAnimation { target: capsuleBorder; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
                                                NumberAnimation { target: capsuleBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                                            }
                                            SequentialAnimation {
                                                loops: Animation.Infinite
                                                NumberAnimation { target: capsuleBorder; property: "opacity"; to: 0.2; duration: 500 }
                                                NumberAnimation { target: capsuleBorder; property: "opacity"; to: 0.5; duration: 500 }
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. ПРАВАЯ КОЛОНКА
                            Column {
                                width: parent.width - parent.width / 3.33
                                spacing: 0

                                // 2.1 WIDE CAPSULE
                                Rectangle {
                                    id: wideRect
                                    width: parent.width
                                    height: (width - 55) * 215/460 + 75
                                    color: "transparent"
                                    FocusScope {
                                        id: wideFocus
                                        anchors.fill: parent
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                wideFocus.forceActiveFocus();
                                                manageFlickable.ensureVisible(wideRect);
                                                sNav.stop(); sNav.play();
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 15
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        text: "WIDE CAPSULE"
                                        font.pixelSize: 30
                                        font.family: bold.name
                                        color: "white"
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 15
                                        anchors.rightMargin: 40
                                        anchors.topMargin: 60
                                        anchors.bottomMargin: 15

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#2A2E35"
                                            radius: theme.roundedCovers ? 24 : 0
                                            visible: root.currentGameAssets.wideCapsule === ""
                                        }

                                        Rectangle {
                                            id: wideMask
                                            anchors.fill: parent
                                            radius: theme.roundedCovers ? 24 : 0
                                            visible: false
                                        }

                                        AnimatedImage {
                                            id: wideImage
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: root.currentGameAssets.wideCapsule !== "" 
                                                    ? root.currentGameAssets.wideCapsule 
                                                    : (currentGame.assets.steam || "")
                                            visible: source != ""
                                            cache: true
                                            asynchronous: false
                                            playing: wideFocus.activeFocus || wideDeleteFocus.activeFocus

                                            layer.enabled: theme.roundedCovers
                                            layer.effect: OpacityMask {
                                                maskSource: wideMask
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#000000"
                                            opacity: (root.saving && (wideFocus.activeFocus || wideDeleteFocus.activeFocus)) ? 0.8 : 0.0
                                            visible: opacity > 0
                                            z: 1000
                                            radius: theme.roundedCovers ? 24 : 0
                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                        }

                                        AnimatedImage {
                                            id: wideLoading
                                            width: Math.min(parent.width, parent.height) * 0.5
                                            height: width
                                            anchors.centerIn: parent
                                            source: "../../assets/video/bouncing.gif"                             
                                            fillMode: Image.PreserveAspectFit
                                            playing: root.saving && (wideFocus.activeFocus || wideDeleteFocus.activeFocus)
                                            visible: playing
                                            z: 1001
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            anchors.margins: 5
                                            width: 100
                                            height: 100
                                            radius: theme.roundedCovers ? 35 : 5
                                            color: wideDeleteFocus.activeFocus ? "white" : "#80000000"
                                            visible: root.currentGameAssets.wideCapsule !== "" && wideFocus.activeFocus
                                            FocusScope {
                                                id: wideDeleteFocus
                                                anchors.fill: parent
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        wideDeleteFocus.forceActiveFocus()
                                                        if (wideDeleteFocus.activeFocus) {
                                                            root.pendingDelete = "wideCapsule"
                                                            root.saving = true
                                                            saveTimer.start()
                                                        }
                                                    }
                                                }
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Ь"
                                                font.pixelSize: 35
                                                font.family: icons.name
                                                color: wideDeleteFocus.activeFocus ? "black" : "white"
                                            }
                                        }

                                        Rectangle {
                                            id: wideBorder
                                            anchors.fill: parent
                                            anchors.margins: -7
                                            color: "transparent"
                                            border.width: 5
                                            border.color: "grey"
                                            radius: theme.roundedCovers ? 32 : 2
                                            opacity: wideFocus.activeFocus ? 1.0 : 0.0
                                            visible: wideFocus.activeFocus

                                            SequentialAnimation {
                                                running: wideFocus.activeFocus
                                                loops: 1
                                                ParallelAnimation {
                                                    NumberAnimation { target: wideBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                                    NumberAnimation { target: wideBorder; property: "radius"; to: theme.roundedCovers ? 32 : 0; duration: 200; easing.type: Easing.OutBack }
                                                    NumberAnimation { target: wideBorder; property: "scale"; to: 1.02; duration: 200; easing.type: Easing.OutBack }
                                                    ColorAnimation { target: wideBorder; property: "border.color"; to: "white"; duration: 200 }
                                                    NumberAnimation { target: wideBorder; property: "opacity"; to: 0.5; duration: 200 }
                                                }
                                                ParallelAnimation {
                                                    NumberAnimation { target: wideBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.InOutQuad }
                                                    NumberAnimation { target: wideBorder; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
                                                    NumberAnimation { target: wideBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                                                }
                                                SequentialAnimation {
                                                    loops: Animation.Infinite
                                                    NumberAnimation { target: wideBorder; property: "opacity"; to: 0.2; duration: 500 }
                                                    NumberAnimation { target: wideBorder; property: "opacity"; to: 0.5; duration: 500 }
                                                }
                                            }
                                        }
                                    }
                                }


                                // 2.2 LOGO
                                Rectangle {
                                    id: logoRect
                                    width: parent.width
                                    height: width * 0.33
                                    color: "transparent"
                                    FocusScope {
                                        id: logoFocus
                                        anchors.fill: parent
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                logoFocus.forceActiveFocus();
                                                manageFlickable.ensureVisible(logoRect);
                                                sNav.stop(); sNav.play();
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 15
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        text: "LOGO"
                                        font.pixelSize: 30
                                        font.family: bold.name
                                        color: "white"
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 15
                                        anchors.rightMargin: 40
                                        anchors.topMargin: 60
                                        anchors.bottomMargin: 15

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "black"
                                            opacity: 0.5
                                            visible: true
                                        }

                                        AnimatedImage {
                                            id: logoImage
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            source: root.currentGameAssets.logo !== "" 
        ? root.currentGameAssets.logo 
        : (currentGame.assets.logo || "")
                                            visible: source != ""
                                            cache: true
                                            asynchronous: false
                                            playing: logoFocus.activeFocus || logoDeleteFocus.activeFocus
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#000000"
                                            opacity: (root.saving && (logoFocus.activeFocus || logoDeleteFocus.activeFocus)) ? 0.8 : 0.0
                                            visible: opacity > 0
                                            z: 1000
                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                        }

                                        AnimatedImage {
                                            id: logoLoading
                                            width: Math.min(parent.width, parent.height) * 0.5
                                            height: width
                                            anchors.centerIn: parent
                                            source: "../../assets/video/bouncing.gif"                             
                                            fillMode: Image.PreserveAspectFit
                                            playing: root.saving && (logoFocus.activeFocus || logoDeleteFocus.activeFocus)
                                            visible: playing
                                            z: 1001
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            anchors.margins: 5
                                            width: 100
                                            height: 100
                                            radius: theme.roundedCovers ? 35 : 5
                                            color: logoDeleteFocus.activeFocus ? "white" : "#80000000"
                                            visible: root.currentGameAssets.logo !== "" && logoFocus.activeFocus
                                            FocusScope {
                                                id: logoDeleteFocus
                                                anchors.fill: parent
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        logoDeleteFocus.forceActiveFocus()
                                                        if (logoDeleteFocus.activeFocus) {
                                                            root.pendingDelete = "logo"
                                                            root.saving = true
                                                            saveTimer.start()
                                                        }
                                                    }
                                                }
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Ь"
                                                font.pixelSize: 35
                                                font.family: icons.name
                                                color: logoDeleteFocus.activeFocus ? "black" : "white"
                                            }
                                        }

                                        Rectangle {
                                            id: logoBorder
                                            anchors.fill: parent
                                            anchors.margins: -7
                                            color: "transparent"
                                            border.width: 5
                                            border.color: "grey"
                                            radius: 2
                                            opacity: logoFocus.activeFocus ? 1.0 : 0.0
                                            visible: logoFocus.activeFocus

                                            SequentialAnimation {
                                                running: logoFocus.activeFocus
                                                loops: 1
                                                ParallelAnimation {
                                                    NumberAnimation { target: logoBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                                    NumberAnimation { target: logoBorder; property: "radius"; to: 0; duration: 200; easing.type: Easing.OutBack }
                                                    NumberAnimation { target: logoBorder; property: "scale"; to: 1.02; duration: 200; easing.type: Easing.OutBack }
                                                    ColorAnimation { target: logoBorder; property: "border.color"; to: "white"; duration: 200 }
                                                    NumberAnimation { target: logoBorder; property: "opacity"; to: 0.5; duration: 200 }
                                                }
                                                ParallelAnimation {
                                                    NumberAnimation { target: logoBorder; property: "radius"; to: 2; duration: 200; easing.type: Easing.InOutQuad }
                                                    NumberAnimation { target: logoBorder; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
                                                    NumberAnimation { target: logoBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                                                }
                                                SequentialAnimation {
                                                    loops: Animation.Infinite
                                                    NumberAnimation { target: logoBorder; property: "opacity"; to: 0.2; duration: 500 }
                                                    NumberAnimation { target: logoBorder; property: "opacity"; to: 0.5; duration: 500 }
                                                }
                                            }
                                        }
                                    }
                                }

                            }
                        }

                        // 3. HERO
                        Rectangle {
                            id: heroRect
                            width: parent.width
                            height: (width - 80) * 620/1920 + 75
                            color: "transparent"
                            FocusScope {
                                id: heroFocus
                                anchors.fill: parent
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        heroFocus.forceActiveFocus();
                                        manageFlickable.ensureVisible(heroRect);
                                        sNav.stop(); sNav.play();
                                    }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 40
                                anchors.top: parent.top
                                anchors.topMargin: 20
                                text: "HERO"
                                font.pixelSize: 30
                                font.family: bold.name
                                color: "white"
                            }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 40
                                anchors.rightMargin: 40
                                anchors.topMargin: 60
                                anchors.bottomMargin: 15

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#2A2E35"
                                    visible: root.currentGameAssets.hero === ""
                                }

                                AnimatedImage {
                                    id: heroImage
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: root.currentGameAssets.hero !== "" 
        ? root.currentGameAssets.hero 
        : (currentGame.assets.background || "")
                                    visible: source != ""
                                    cache: true
                                    asynchronous: false
                                    playing: heroFocus.activeFocus || heroDeleteFocus.activeFocus
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#000000"
                                    opacity: (root.saving && (heroFocus.activeFocus || heroDeleteFocus.activeFocus)) ? 0.8 : 0.0
                                    visible: opacity > 0
                                    z: 1000
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                AnimatedImage {
                                    id: heroLoading
                                    width: Math.min(parent.width, parent.height) * 0.5
                                    height: width
                                    anchors.centerIn: parent
                                    source: "../../assets/video/bouncing.gif"                             
                                    fillMode: Image.PreserveAspectFit
                                    playing: root.saving && (heroFocus.activeFocus || heroDeleteFocus.activeFocus)
                                    visible: playing
                                    z: 1001
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.margins: 5
                                    width: 100
                                    height: 100
                                    radius: theme.roundedCovers ? 35 : 5
                                    color: heroDeleteFocus.activeFocus ? "white" : "#80000000"
                                    visible: root.currentGameAssets.hero !== "" && heroFocus.activeFocus
                                    FocusScope {
                                        id: heroDeleteFocus
                                        anchors.fill: parent
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                heroDeleteFocus.forceActiveFocus()
                                                if (heroDeleteFocus.activeFocus) {
                                                    root.pendingDelete = "hero"
                                                    root.saving = true
                                                    saveTimer.start()
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Ь"
                                        font.pixelSize: 35
                                        font.family: icons.name
                                        color: heroDeleteFocus.activeFocus ? "black" : "white"
                                    }
                                }

                                Rectangle {
                                    id: heroBorder
                                    anchors.fill: parent
                                    anchors.margins: -10
                                    color: "transparent"
                                    border.width: 5
                                    border.color: "grey"
                                    radius: 2
                                    opacity: heroFocus.activeFocus ? 1.0 : 0.0
                                    visible: heroFocus.activeFocus

                                    SequentialAnimation {
                                        running: heroFocus.activeFocus
                                        loops: 1
                                        ParallelAnimation {
                                            NumberAnimation { target: heroBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                            NumberAnimation { target: heroBorder; property: "radius"; to: 0; duration: 200; easing.type: Easing.OutBack }
                                            NumberAnimation { target: heroBorder; property: "scale"; to: 1.02; duration: 200; easing.type: Easing.OutBack }
                                            ColorAnimation { target: heroBorder; property: "border.color"; to: "white"; duration: 200 }
                                            NumberAnimation { target: heroBorder; property: "opacity"; to: 0.5; duration: 200 }
                                        }
                                        ParallelAnimation {
                                            NumberAnimation { target: heroBorder; property: "radius"; to: 2; duration: 200; easing.type: Easing.InOutQuad }
                                            NumberAnimation { target: heroBorder; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
                                            NumberAnimation { target: heroBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                                        }
                                        SequentialAnimation {
                                            loops: Animation.Infinite
                                            NumberAnimation { target: heroBorder; property: "opacity"; to: 0.2; duration: 500 }
                                            NumberAnimation { target: heroBorder; property: "opacity"; to: 0.5; duration: 500 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /* ================= TOP BAR ================= */
    Rectangle {
        id: topBar
        anchors.left: root.left   
        anchors.right: root.right 
        height: root.topH
        color: "black"
        z: 10000

        Row {
            id: topButtonsNames
            anchors {
                left: parent.left 
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 15
                leftMargin: 0
            }
            property int currentIndex: 0
            spacing: 0
            focus: false

            Keys.onLeftPressed: if (currentIndex > 0) {currentIndex--; sNav.stop(); sNav.play(); }
            Keys.onRightPressed: if (currentIndex < 3) {currentIndex++; sNav.stop(); sNav.play(); }
            Keys.onPressed: 
                if (event.key === Qt.Key_Return || api.keys.isAccept(event)){
                    if (root.focusZone === 0 && currentIndex === 0) {
                        theme.openPage(9)
                    }
                }

            Rectangle {
                id: topBtnSearch
                width: topBar.width - (topBtnNet.width + topBarBattery.width + topBtnClock.width + topBtnUser.width + (topButtonsNames.spacing * 4) + (topButtonsNames.anchors.rightMargin * 2))
                height: root.topH
                color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: "¿"
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "black" : "white"
                    
                    readonly property real posRight: topBtnSearch.width - 50
                    readonly property real posLeft: 15
                    
                    x: posRight
                    
                    states: [
                        State {
                            name: "focused"
                            when: topButtonsNames.currentIndex === 0 && root.focusZone === 0
                            PropertyChanges { target: searchIcon; x: posLeft; opacity: 1 }
                        },
                        State {
                            name: "default"
                            when: !(topButtonsNames.currentIndex === 0 && root.focusZone === 0)
                            PropertyChanges { target: searchIcon; x: posRight; opacity: 1 }
                        }
                    ]

                    transitions: [
                        Transition {
                            from: "default"; to: "focused"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x"; to: searchIcon.posRight - 20; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                                }
                                PropertyAction { target: searchIcon; property: "x"; value: searchIcon.posLeft + 20 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x"; to: searchIcon.posLeft; duration: 200; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 1; duration: 200 }
                                }
                            }
                        },
                        Transition {
                            from: "focused"; to: "default"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x"; to: searchIcon.posLeft + 20; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                                }
                                PropertyAction { target: searchIcon; property: "x"; value: searchIcon.posRight - 20 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x"; to: searchIcon.posRight; duration: 200; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 1; duration: 200 }
                                }
                            }
                        }
                    ]
                }
              
                Text {
                    id: searchText
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property real targetX: 15 + 50
                    x: targetX + 20
                    text: "Search games in your Library..."
                    font.pixelSize: 30
                    font.family: typeof bold !== "undefined" ? bold.name : ""
                    color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "grey" : "transparent"
                    opacity: 0
                    visible: false

                    states: [
                        State {
                            name: "focused"
                            when: topButtonsNames.currentIndex === 0 && root.focusZone === 0
                            PropertyChanges { target: searchText; x: searchText.targetX; opacity: 1; visible: true }
                        }
                    ]

                    transitions: [
                        Transition {
                            from: "*"; to: "focused"
                            SequentialAnimation {
                                PropertyAction { target: searchText; property: "visible"; value: true }
                                PauseAnimation { duration: 150 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchText; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchText; property: "x"; to: searchText.targetX; duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        },
                        Transition {
                            from: "focused"; to: "*"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: searchText; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                                    NumberAnimation { target: searchText; property: "x"; to: searchText.targetX + 20; duration: 150; easing.type: Easing.InCubic }
                                }
                                PropertyAction { target: searchText; property: "visible"; value: false }
                            }
                        }
                    ]
                }

                MouseArea { 
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        if (root.focusZone === 0 && topButtonsNames.currentIndex === 0) {
                            theme.openPage(9)
                        } else {
                            sNav.stop(); sNav.play(); 
                            root.goToZone(0)
                            topButtonsNames.currentIndex = 0
                        }
                    }
                }
            }

            Rectangle {
                id: topBtnNet
                width: 72; height: root.topH
                color: (topButtonsNames.currentIndex === 1 && root.focusZone === 0) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 1 && root.focusZone === 0) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: theme.isOnline ? "°" : "o" 
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsNames.currentIndex === 1 && root.focusZone === 0) ? "black" : "white"
                }

                MouseArea { 
                    anchors.fill: parent;
                    onClicked: if (!root.closeMenuVisible) {
                        sNav.stop(); sNav.play(); 
                        root.goToZone(0)
                        topButtonsNames.currentIndex = 1
                    }
                }
            }
            
            Item {
                id: topBarBattery
                width: theme.showBatteryPercent ? 170 : 70 
                height: root.topH

                Rectangle {
                    id: batteryBg
                    anchors.fill: parent
                    color: (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "white" : "transparent"
                    border.width: (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? 2 : 0
                    border.color: "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    id: batteryRow
                    spacing: 5
                    anchors.centerIn: parent

                    function getBatteryIcon() {
                        if (isNaN(api.device.batteryPercent)) return "../../assets/theme-icons/battery" /* DECKOS: was ../assets */ + getSuffix() + ".png";
                        const batteryPercent = api.device.batteryPercent * 100;
                        if (batteryPercent <= 20) return "../../assets/theme-icons/20" + getSuffix() + ".png";
                        else if (batteryPercent <= 40) return "../../assets/theme-icons/40" + getSuffix() + ".png";
                        else if (batteryPercent <= 60) return "../../assets/theme-icons/60" + getSuffix() + ".png";
                        else if (batteryPercent <= 80) return "../../assets/theme-icons/80" + getSuffix() + ".png";
                        else return "../../assets/theme-icons/battery" + getSuffix() + ".png";
                    }

                    function getSuffix() {
                        return (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "B" : "";
                    }

                    Text {
                        text: isNaN(api.device.batteryPercent) ? "N/A" : (api.device.batteryPercent * 100).toFixed(0) + "%"
                        color: (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "black" : "white"
                        font.family: typeof bold !== "undefined" ? bold.name : ""
                        font.pixelSize: 36
                        visible: theme.showBatteryPercent 
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        width: 57; height: 33
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: batteryBase
                            anchors.fill: parent
                            source: batteryRow.getBatteryIcon()
                            mipmap: true
                        }
                        Image {
                            id: chargingOverlay
                            anchors.fill: parent
                            source: "../../assets/theme-icons/charging" + batteryRow.getSuffix() + ".png"
                            mipmap: true
                            visible: api.device.batteryCharging
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        sNav.stop(); sNav.play();
                        root.goToZone(0)
                        topButtonsNames.currentIndex = 2
                    }
                }
            }

            Rectangle {
                id: topBtnClock
                width: theme.use24HourFormat ? 130 : 200; height: root.topH
                color: "transparent"
                border.color: "transparent"               

                property string timeFormat: theme.use24HourFormat ? "HH:mm" : "hh:mm AP"

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), topBtnClock.timeFormat)
                    font.pixelSize: 35
                    font.family: typeof bold !== "undefined" ? bold.name : ""
                    color: "white"
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
                }                
                
                onTimeFormatChanged: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
            }

            Rectangle {
                id: topBtnUser
                width: root.topH * 1.1; height: root.topH
                color: (topButtonsNames.currentIndex === 3 && root.focusZone === 0) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 3 && root.focusZone === 0) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Image {
                    id: userImage
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    height: parent.height * 0.8
                    source: (root.theme && root.theme.profilePictureSource !== "") ? root.theme.profilePictureSource : "../../assets/logo/logo.jpg" /* DECKOS */
                    fillMode: Image.PreserveAspectFit
                }

                Rectangle {
                    anchors { top: userImage.top; bottom: userImage.bottom; right: userImage.right }
                    width: 10
                    color: "#00BFFF"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: if (!root.closeMenuVisible) {
                        sNav.stop(); sNav.play(); 
                        root.goToZone(0)
                        topButtonsNames.currentIndex = 3
                    }
                }
            }
        }
    }

    /* ================= BOTTOM BAR ================= */
    Item {
    id: bottomBar
    width: parent.width
    height: root.topH
    anchors.bottom: parent.bottom
    z: 100000000000
    clip: true

    // Захватываем фрагмент фона строго под bottomBar (не весь экран!)
    ShaderEffectSource {
        id: bottomAreaSource
        sourceItem: globalBlurSource
        // Координаты bottomBar в системе координат globalBlurSource (размер root)
        sourceRect: Qt.rect(0, root.height - root.topH, root.width, root.topH)
        live: true
        visible: false
    }

   GaussianBlur {
    anchors.fill: parent
    source: bottomAreaSource
    radius: 150          
    visible: !theme.highContrastBottomBar               // до любого нужного значения
    samples: 64        // количество сэмплов для качества
    transparentBorder: false
}

    // Полупрозрачный чёрный (50%)
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: theme.highContrastBottomBar ? 1.0 : (leftBar.isOpen || root.closeMenuVisible || root.optionsMenuVisible ? 0.9 : 0.6)
  
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

        Rectangle {
            id: btnMenu
            width: 180; height: parent.height
            anchors.left: parent.left
            anchors.leftMargin: 18
            color: "transparent"

            Row {
                anchors.verticalCenter: parent.verticalCenter 
                spacing: 6
                Text { text: ":"; font.family: icons.name; font.pixelSize: 54; color: "white" }
                Text { 
                    text: root.closeMenuVisible ? "PEGASUS MENU" : "MENU"
                    font.family: typeof bold !== "undefined" ? bold.name : "" 
                    font.pixelSize: 28 
                    color: "white"
                    y: parent.height * 0.21 
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: if (!root.closeMenuVisible) {
                    leftBar.toggle()
                    leftBar.currentIndex = 1
                    leftBar.updateFocus()
                }
            }
        }

        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.rightMargin: 35
            anchors.verticalCenter: parent.verticalCenter
            spacing: 38

            Row {
                spacing: 18
                anchors.verticalCenter: parent.verticalCenter
                Text { text: theme.nintendoLayout ? (theme.universalIcons ? "В" : "B") : (theme.universalIcons ? "А" : "A"); font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025}
                Text { text: "SELECT"; font.family: typeof bold !== "undefined" ? bold.name : ""; font.pixelSize: 25; color: "white"; y: parent.height * 0.23}
            }

            Rectangle {
                id: btnBack
                width: 140; height: parent.height
                color: "transparent"
                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Text { text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B"); font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025}
                    Text { text: "BACK"; font.family: typeof bold !== "undefined" ? bold.name : ""; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
                }
                MouseArea { 
                    anchors.fill: parent
                    onClicked: {
                        if (focusZone === 2) {
                            goToZone(1)
                            event.accepted = true
                        }
                        else if (focusZone === 0) {
                            goToZone(1)
                            event.accepted = true
                        }
                        else if (focusZone === 1) {
    var src = api.memory.has("steamGridSource") ? api.memory.get("steamGridSource") : 8
    api.memory.set("steamGridSource", null)
    root.startExitAnimation(src)
    event.accepted = true
}
                    }
                }
            }
        }
    }

    /* LEFT BAR ФОН */ 
Item {
    id: leftOverlay
    anchors.fill: parent
    z: 0 
    
    // Прямая привязка к движению панели для синхронной анимации
    opacity: (leftBar.x + leftBar.width) / leftBar.width
    visible: opacity > 0

    MouseArea {
        anchors.fill: parent
        enabled: leftBar.isOpen
        onClicked: {
            leftBar.toggle()
            focusTimer.start()
        }
    }

    FastBlur {
        anchors.fill: parent
        source: globalBlurSource
        radius: 50
        transparentBorder: false
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.7
    }
}


    /* ================= LEFT BAR ================= */
    FocusScope {
        id: leftBar
        width: parent.width
        height: parent.height
        visible: false
        focus: false
        z: 999
        x: leftBar.isOpen ? 0 : -width
        Behavior on x {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        property bool isOpen: false
        property int currentIndex: 0
        property var buttons: []
        
        Keys.onPressed: {
            if (leftBar.isOpen && leftBar.focus) {
                if (event.key === Qt.Key_Up) {
                    if (currentIndex > 0) {
                        currentIndex--
                        updateFocus()
                        event.accepted = true
                        sNav.stop(); sNav.play();
                    } else {
                        event.accepted = true
                    }
                }
                else if (event.key === Qt.Key_Down) {
                    if (currentIndex < buttons.length - 1) {
                        currentIndex++
                        updateFocus()
                        event.accepted = true
                        sNav.stop(); sNav.play();
                    } else {
                        event.accepted = true
                    }
                }
                else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                    if (currentIndex === 7) {
                        toggle()
                        root.closeMenuVisible = true
                        focusTimer.start()
                    } else {
                        theme.openPage(currentIndex)
                        toggle()
                        if (currentIndex === 6) {
                            sShowui.play()
                        }
                    }
                    event.accepted = true
                }
                else if (api.keys.isMenu(event)) {
                    toggle()
                    focusTimer.start()
                    event.accepted = true
                }
                else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                    toggle()
                    focusTimer.start()
                    event.accepted = true
                }
                else {
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: menuPanel
            width: parent.width * 0.25
            height: parent.height
            color: "#181B20"
            radius: 0
            anchors.left: parent.left
            z: 1000
            x: leftBar.isOpen ? width * 0.2: 0
            opacity: leftBar.isOpen ? 1 : 0
            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 0 } }

            ProfileBadge { // DECKOS: user picture + name (Settings > Profile)
                theme: root.theme
                anchors.left: parent.left; anchors.leftMargin: 40
                anchors.right: parent.right; anchors.rightMargin: 20
                y: parent.height * 0.105; height: parent.height * 0.075
            }
            Column {
                id: buttonColumn
                anchors { left: parent.left; top: parent.top; leftMargin: 0; topMargin: parent.height * 0.2 /* DECKOS: was 0.11, room for the profile */ }
                spacing: 0
            }
        }

        Component {
            id: menuButtonComponent

            FocusScope {
                id: buttonScope
                property string title: ""
                property int buttonIndex: 0
                width: menuPanel.width
                height: Math.min(106, menuPanel.height * 0.085) /* DECKOS: was 106 */
                
                property bool isFocused: leftBar.isOpen && leftBar.currentIndex === buttonIndex // DECKOS: the selected button, not Qt focus (which can drift)
                
                onIsFocusedChanged: {
                    if (isFocused) {
                        bgColor = "#27303A"
                        textColor = "white"
                    } else {
                        bgColor = "transparent"
                        textColor = "#AAA"
                    }
                }
              
                property color bgColor: "transparent"
                property color textColor: "#AAA"
                property string icon: ""

                Rectangle {
                    anchors.fill: parent
                    color: bgColor
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Item {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 20; bottomMargin: 20 }
                        width: 11
                        visible: theme.currentPage === buttonIndex   
                        
                        Rectangle {
                            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                            width: 27
                            color: "#1A9EFF"
                            radius: 40
                        }
                    }
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: menuPanel.width * 0.083
                        spacing: 38

                        Text {
                            text: icon
                            font.family: icons.name
                            font.pixelSize: menuPanel.width * 0.075
                            color: "white"
                            verticalAlignment: Text.AlignVCenter // DECKOS: was parent.verticalCenter (an anchor line)
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: title
                            font.family: typeof bold !== "undefined" ? bold.name : ""
                            font.pixelSize: menuPanel.width * 0.075
                            color: "white"
                            verticalAlignment: Text.AlignVCenter // DECKOS: was parent.verticalCenter (an anchor line)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }         

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (leftBar.currentIndex === buttonIndex) {
                            if (buttonIndex === 7) {
                                leftBar.toggle()
                                closeMenu.forceActiveFocus()
                                closeMenuVisible = true
                            } else {
                                theme.openPage(buttonIndex)
                                leftBar.toggle()
                                if (buttonIndex === 6) {
                                    sShowui.play()
                                }
                            }
                        } else {
                            leftBar.currentIndex = buttonIndex
                            leftBar.updateFocus()
                            sNav.play()
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            var btn1 = menuButtonComponent.createObject(buttonColumn, { "title": "Home", "buttonIndex": 0, "icon": "^" })
            var btn2 = menuButtonComponent.createObject(buttonColumn, { "title": "Library", "buttonIndex": 1, "icon": "L" })
            var btn3 = menuButtonComponent.createObject(buttonColumn, { "title": "Store", "buttonIndex": 2, "icon": "€" })
            var btn4 = menuButtonComponent.createObject(buttonColumn, { "title": "Friends and Chat", "buttonIndex": 3, "icon": "F" })
            var btn5 = menuButtonComponent.createObject(buttonColumn, { "title": "Media", "buttonIndex": 4, "icon": "M" })
            var btn6 = menuButtonComponent.createObject(buttonColumn, { "title": "Downloads", "buttonIndex": 5, "icon": "♠︎" })
            var btn7 = menuButtonComponent.createObject(buttonColumn, { "title": "Settings", "buttonIndex": 6, "icon": "w" })
            var btn8 = menuButtonComponent.createObject(buttonColumn, { "title": "Close", "buttonIndex": 7, "icon": "C" })
            leftBar.buttons = [btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8]
            
            currentIndex = 1
            updateFocus()
        }

        function updateFocus() {
            if (currentIndex >= 0 && currentIndex < buttons.length) {
                buttons[currentIndex].forceActiveFocus()
            }
        }

        function toggle() {
            theme.toggleLeftBar(leftBar);
        }
    }

    
    /* ================= CLOSE MENU ================= */
    FocusScope {
        id: closeMenu
        width: parent.width
        height: parent.height
        visible: closeMenuVisible
        focus: closeMenuVisible
        enabled: visible
        z: 9999
        
        opacity: closeMenuVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        property int currentButtonIndex: 0
        property var buttons: [exitButton, cancelButton1]

        /* CLOSE MENU ФОН */
Item {
    id: closeMenuOverlay
    anchors.fill: parent
    z: 0 
    visible: root.closeMenuVisible // Используем твой флаг видимости

    MouseArea {
        anchors.fill: parent
    }

    FastBlur {
        anchors.fill: parent
        source: globalBlurSource
        radius: 50
        transparentBorder: false
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.7
    }
}


        Rectangle {
            width: 550; height: 240
            anchors.centerIn: parent
            color: "#181B20"
            
            Text {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: -65 }
                text: "Close"
                color: "white"
                font.pixelSize: 38
                font.family: typeof bold !== "undefined" ? bold.name : ""
            }
            
            Column {
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                spacing: 0
                
                Rectangle {
                    id: exitButton
                    width: parent.width; height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 0 ? "#DE3619" : "transparent"
                    Text {
                        text: "   Exit"
                        color: "white"
                        font.pixelSize: 35
                        font.family: typeof bold !== "undefined" ? bold.name : ""
                        anchors.verticalCenter: parent.verticalCenter
                    }               
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 0) {
                                closeMenu.currentButtonIndex = 0
                                sNav.stop(); sNav.play();
                            } else {
                                Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                            }
                        }
                    }
                }
                
                Rectangle {
                    id: cancelButton1
                    width: parent.width; height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 1 ? "white" : "transparent"
                    Text {
                        text: "   Cancel"
                        color: closeMenu.currentButtonIndex === 1 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: typeof bold !== "undefined" ? bold.name : ""
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 1) {
                                closeMenu.currentButtonIndex = 1
                                sNav.stop(); sNav.play();
                            } else {
                                closeMenuVisible = false
                                sLeftClose.play()
                                focusTimer.start()
                            }
                        }
                    }
                }
            }
        }
        
        Keys.onPressed: {
            if (closeMenuVisible) {
                if (event.key === Qt.Key_Up) {
                    if (currentButtonIndex > 0) {
                        currentButtonIndex--
                        sNav.stop(); sNav.play();
                    }
                    event.accepted = true
                }
                else if (event.key === Qt.Key_Down) {
                    if (currentButtonIndex < 1) {
                        currentButtonIndex++
                        sNav.stop(); sNav.play(); 
                    }
                    event.accepted = true
                }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    event.accepted = true
                }
                else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape){}
                else if (api.keys.isMenu(event)) {}
                else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    if (currentButtonIndex === 0) {
                        event.accepted = true
                        Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                        return
                    } else if (currentButtonIndex === 1) {
                        closeMenuVisible = false
                        sLeftClose.play()
                        focusTimer.start()
                    }
                    event.accepted = true
                }            
            }
        }
      
        onVisibleChanged: {
            if (visible) {
                currentButtonIndex = 0
                sShowui.play()
                forceActiveFocus()
            }
        }
    }

    property int nextPageIndex: 0

    function startExitAnimation(index) {
        nextPageIndex = index
        exitAnim.start()
    }

    Component.onCompleted: {
    enterAnim.start()
    topNavRow.currentIndex = currentPage
    // Измените это: вместо goToZone(2) ставим 1, чтобы фокус был на кнопках
    root.goToZone(1)                                
    focusTimer.start()
    loadSavedAssets()
    searchGame()
}


    SequentialAnimation {
        id: enterAnim
        ScriptAction { 
            script: { 
                animatedContent.opacity = 0
                animatedContent.scale = 0.95
            } 
        }
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 1; duration: 225; easing.type: Easing.OutQuad }
            NumberAnimation { target: animatedContent; property: "scale"; to: 1.0; duration: 225; easing.type: Easing.OutQuad }
        }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 0; duration: 225; easing.type: Easing.InQuad }
            NumberAnimation { target: animatedContent; property: "scale"; to: 0.95; duration: 225; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: theme.finalizeNavigation(nextPageIndex)
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            var gridView = root.getCurrentGridView()
            if (gridView) {
                if (!root.closeMenuVisible && gridView.count > 0) {
                    gridView.currentIndex = gridView.currentIndex
                    gridView.forceActiveFocus()
                }
            }
        }
    }
}
 