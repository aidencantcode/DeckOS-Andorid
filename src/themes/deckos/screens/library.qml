import QtQuick 2.15
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
    
    property string sortMode: api.memory.has("librarySortMode") ? api.memory.get("librarySortMode") : "alphabetical"
property bool sortMenuVisible: false

    
    SortFilterProxyModel {
    id: favoritesModel
    sourceModel: api.allGames
    dynamicSortFilter: true   // <-- добавить эту строку
    filters: ValueFilter {
        roleName: "favorite"
        value: true
    }
}

SortFilterProxyModel {
    id: sortedAllGames
    sourceModel: api.allGames
    dynamicSortFilter: true
    sorters: RoleSorter {
        id: allGamesSorter
        roleName: "title"
        ascendingOrder: true
    }
}

SortFilterProxyModel {
    id: sortedFavoritesModel
    sourceModel: api.allGames
    dynamicSortFilter: true
    filters: ValueFilter {
        roleName: "favorite"
        value: true
    }
    sorters: RoleSorter {
        id: favoritesSorter
        roleName: "title"
        ascendingOrder: true
    }
}

    // ========== ОБЩИЙ КОМПОНЕНТ ДЛЯ СЕТКИ ИГР ==========
    Component {
        id: gameGridComponent

        FocusScope {
            property alias model: gridView.model
            property alias gridView: gridView
            signal gameSelected(var game)

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
                    cellWidth: width / theme.libraryRows

                    cellHeight: cellWidth * 1.5
                    currentIndex: 0
                    focus: false
                    
                    snapMode: GridView.NoSnap
                    highlightRangeMode: GridView.ApplyRange
                    highlightMoveDuration: 250
                    cacheBuffer: cellHeight * 3

                    onContentYChanged: root.isScrolled = (contentY > 30)

                    Keys.onPressed: {
                        if (root.focusZone === 2) {
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
                                var columnsCount = Math.floor(width / cellWidth);
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
                                var columnsCount = Math.floor(width / cellWidth);
                                if (currentIndex < count - columnsCount) {
                                    sNav.stop(); sNav.play();
                                    currentIndex += columnsCount;
                                    event.accepted = true;
                                }
                            }
                            else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
    if (currentItem && currentItem.gameRef) {
        gameSelected(currentItem.gameRef);
    }
    event.accepted = true;
}
                            else if (api.keys.isFilters(event) && !root.optionsMenuVisible && !root.closeMenuVisible && !root.sortMenuVisible) {
    root.toggleSortMenu();
    event.accepted = true;
}
                            else if (api.keys.isDetails(event) && !root.optionsMenuVisible) {
                                var game = model.get(currentIndex);
                                if (game) {
                                    root.currentFocusedGame = game;
                                    root.toggleOptionsMenu();
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    delegate: Item {
                        width: gridView.cellWidth
                        height: gridView.cellHeight
                        property var gameRef: modelData
                        property bool hasImage: {
    if (!modelData) return false;

    // 1. Проверка веб-ассетов (SteamGridDB) через api.memory
    if (typeof api !== "undefined" && api.memory) {
        var customData = api.memory.get("custom_assets_" + modelData.title);
        if (customData && customData.assets && customData.assets.capsule) {
            return true;
        }
    }

    // 2. Проверка локальных ассетов (Metadata)
    return !!(modelData.assets && (modelData.assets.poster || modelData.assets.boxFront));
}
                        property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                        Rectangle {
    id: gameContainer
    anchors.fill: parent 
    color: "transparent"
    scale: isFocused ? 0.96425 : 0.95
    Behavior on scale { NumberAnimation { duration: 150 } }

    Rectangle {
        width: gridView.cellWidth * 0.9
        height: gridView.cellHeight * 0.9
        anchors.centerIn: parent
        color: "#555"
        visible: !hasImage
        radius: theme.roundedCovers ? 24 : 0
    }
    
    Rectangle {
        id: favoritesIndicator
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 20
            bottomMargin: 27
        }
        width: 110
        height: 55
        radius: 45
        color: "#0F1318"
        visible: modelData && modelData.favorite === true && isFocused
        z: 20
        
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            spacing: 5
            
            Text {
                text: "★"
                color: "white"
                font.pixelSize: 50
                font.family: icons.name
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: "✓"
                color: "#6ccf58"
                font.pixelSize: 50
                font.family: icons.name
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Rectangle {
        id: posterMask
        width: gridView.cellWidth * 0.9
        height: gridView.cellHeight * 0.9
        anchors.centerIn: parent
        radius: theme.roundedCovers ? 24 : 0
        visible: false
    }

    AnimatedImage {
        id: gamePoster
        width: gridView.cellWidth * 0.9
        height: gridView.cellHeight * 0.9
        anchors.centerIn: parent
        
        readonly property var assetData: modelData.assets || {}
        source: theme.getAssetSource("poster", modelData)

        fillMode: AnimatedImage.PreserveAspectCrop
        visible: hasImage && status === AnimatedImage.Ready
        
        playing: visible && status === AnimatedImage.Ready && theme.animatedCovers && (!theme.animationInFocus || isFocused)
        
        cache: true
        asynchronous: true
        
        layer.enabled: theme.roundedCovers
        layer.effect: OpacityMask {
            maskSource: posterMask
        }
    }


                            
                            Item {
                                width: gridView.cellWidth * 1.1
                                height: gridView.cellHeight * 1.1
                                anchors.centerIn: parent
                                clip: false
                                opacity: isFocused ? 0.2 : 0.0
                                z: parent.z - 1
                                
                                Image {
                                    id: blurSource
                                    anchors.fill: parent
                                    source: theme.getAssetSource("poster", modelData)
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
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
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData.title 
                                color: "white"
                                font.family: bold.name
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                                width: parent.width * 0.9
                                visible: !hasImage
                            }
                        }

                        Rectangle {
                            id: highlightBorder
                            width: gridView.cellWidth * 0.947
                            height: gridView.cellHeight * 0.935
                            anchors.centerIn: parent
                            color: "transparent"
                            border.width: 5
                            border.color: "grey"
                            radius: theme.roundedCovers ? 32 : 2
                            opacity: isFocused ? 1.0 : 0.0
                            visible: isFocused
                            z: 1000
                            scale: isFocused ? 0.96425 : 0.95
                            Behavior on scale { NumberAnimation { duration: 150 } }

                            SequentialAnimation {
                                id: appearAnim
                                running: isFocused
                                loops: 1
                                ParallelAnimation {
                                    NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: highlightBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947 + 12; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935 + 12; duration: 200; easing.type: Easing.OutBack }
                                    ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 200 }
                                    NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 200 }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: highlightBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947; duration: 200; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935; duration: 200; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: highlightBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                                }
                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.2; duration: 500 }
                                    NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 500 }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // DECKOS: a tap opens the game at once, like touch on the Deck (selected
                                // first, so B comes back to it) - it took a second tap
                                if (!isFocused) {
                                    gridView.currentIndex = index
                                    gridView.forceActiveFocus()
                                    root.goToZone(2)
                                }
                                if (modelData && modelData.launch) {
                                    gameSelected(modelData);
                                }
                            }
                            onPressAndHold: {
                                if (root.focusZone === 2) {
                                    root.currentFocusedGame = modelData
                                    root.toggleOptionsMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Анимация пкреключения страниц (из Library.qml)
    SequentialAnimation {
        id: pageSwapAnim
        property int targetIdx: 0
        property int direction: 1 // 1 для Next, -1 для Prev
        
        onStarted: {
            // Просто останавливаем при новом вызове
        }

        // Кадр 1: Старый контент уходит
        ParallelAnimation {
            NumberAnimation { 
                target: root; 
                property: "animOpacity"; 
                to: 0.2; 
                duration: 100
            }
            NumberAnimation { 
                target: root; 
                property: "animX"; 
                to: -root.width * 0.2 * pageSwapAnim.direction; 
                duration: 150; 
                easing.type: Easing.OutQuad 
            }        
        }
        
        // Кадр 2: Мгновенная подмена и телепортация нового контента
        ScriptAction {
            script: {
                root.currentPage = pageSwapAnim.targetIdx
                topNavRow.currentIndex = pageSwapAnim.targetIdx
                collectionGamesLoader.active = false
                root.animX = root.width * 0.2 * pageSwapAnim.direction
            }
        }
        
        // Кадр 3: Новый контент встает на место
        ParallelAnimation {
            NumberAnimation { 
                target: root; 
                property: "animOpacity"; 
                to: 1.0; 
                duration: 250
            }
            NumberAnimation { 
                target: root; 
                property: "animX"; 
                to: 0; 
                duration: 500; 
                easing.type: Easing.OutExpo
            }
        }
    }

    // Функция-костыль для запуска
    function safeNav(newIdx) {
        if (newIdx === currentPage) return;
        
        // Просто останавливаем текущую анимацию если она идет
        if (pageSwapAnim.running) {
            pageSwapAnim.stop();
        }
        
        pageSwapAnim.direction = (newIdx > currentPage) ? 1 : -1;
        pageSwapAnim.targetIdx = newIdx;
        pageSwapAnim.start();
    }

    
    
    
    // Внутри FocusScope { id: root ... }
    readonly property real currentScrollY: {
        var gv = getCurrentGridView();
        return gv ? gv.contentY : 0;
    }

    
    function toggleOptionsMenu() {
        console.log("toggleOptionsMenu called. Visible:", optionsMenuVisible, "focusZone:", focusZone);
        
        if (optionsMenuVisible) {
            // Закрытие меню
            console.log("Closing options menu");
            optionsMenuVisible = false
            optionsMenu.focus = false
            
            // Возвращаем фокус в GridView
            var currentGridView = getCurrentGridView()
            if (currentGridView && focusZone === 2) {
                currentGridView.forceActiveFocus()
            }
        } else if (focusZone === 2) {
            // Открытие меню
            console.log("Opening options menu");
            var currentGridView = getCurrentGridView()
            
            if (currentGridView && currentGridView.count > 0) {
                // Получаем текущую игру из GridView
                console.log("GridView found. Current index:", currentGridView.currentIndex, "Total count:", currentGridView.count);
                
                var gameData = null;
                
                // Проверяем разные типы моделей
                if (currentGridView.model && currentGridView.model.get) {
                    gameData = currentGridView.model.get(currentGridView.currentIndex);
                } else if (currentGridView.model && Array.isArray(currentGridView.model)) {
                    gameData = currentGridView.model[currentGridView.currentIndex];
                }
                
                if (gameData) {
                    console.log("Game found:", gameData.title);
                    currentFocusedGame = gameData
                    
                    // Снимаем фокус со всех элементов
                    topNavRow.focus = false
                    topButtonsNames.focus = false
                    currentGridView.focus = false
                    
                    // Открываем меню
                    optionsMenuVisible = true
                    optionsMenu.forceActiveFocus()
                    console.log("Menu opened successfully");
                } else {
                    console.log("No game data at index:", currentGridView.currentIndex);
                }
            } else {
                console.log("No grid view or grid is empty");
            }
        }
    }
    
    function applySortMode(mode) {
    api.memory.set("librarySortMode", mode);
    sortMode = mode;
    var useTitle = (mode === "alphabetical");

    allGamesSorter.roleName = useTitle ? "title" : "lastPlayed";
    allGamesSorter.ascendingOrder = useTitle ? true : false;

    favoritesSorter.roleName = useTitle ? "title" : "lastPlayed";
    favoritesSorter.ascendingOrder = useTitle ? true : false;
}

function toggleSortMenu() {
    if (sortMenuVisible) {
        sortMenuVisible = false;
        sortMenu.focus = false;
        var gv = getCurrentGridView();
        if (gv && focusZone === 2) gv.forceActiveFocus();
    } else if (focusZone === 2 || focusZone === 1) {
        sortMenuVisible = true;
        sortMenu.currentButtonIndex = (sortMode === "alphabetical") ? 0 : 1;
        sortMenu.forceActiveFocus();
    }
}

    // Функция для получения текущего активного GridView - УПРОЩЕННАЯ
    function getCurrentGridView() {
        // Проверяем коллекции
        if (collectionGamesLoader.active && collectionGamesLoader.item) {
            return collectionGamesLoader.item.gridView;
        }
        
        // Просто берем видимую страницу из contentContainer
        for (var i in contentContainer.loadedPages) {
            var page = contentContainer.loadedPages[i];
            if (page && page.visible) {
                // Возвращаем gridView или gridCollections в зависимости от страницы
                return page.gridView ? page.gridView : page.gridCollections;
            }
        }
        
        return null;
    }

    // ============================================
    // ГЛАВНЫЙ ОБРАБОТЧИК КЛАВИШ ДЛЯ ВСЕХ ЗОН
    // ============================================
    Keys.onPressed: {
        if (leftBar.isOpen) return;

        // ========== ОБРАБОТКА DETAILS ДЛЯ КОЛЛЕКЦИЙ (ТОЛЬКО ПОГЛОЩЕНИЕ) ==========
        if (api.keys.isDetails(event) && !optionsMenuVisible) {
            var isOnCollectionGrid = (currentPage === 2 && !collectionGamesLoader.active);
            if (focusZone === 2 && isOnCollectionGrid) {
                event.accepted = true; // Поглощаем нажатие, чтобы ничего не происходило
                return;
            }
        }

        // ========== НАВИГАЦИЯ ВНИЗ ==========
        if (event.key === Qt.Key_Down) {
            if (focusZone === 0) {
                sNav.stop();
                sNav.play(); 
                // С верхнего навигатора в верхние кнопки
                goToZone(1)
                event.accepted = true
            }
            else if (focusZone === 1) {
                sNav.stop();
                sNav.play(); 
                // С верхних кнопок в основной контент               
                goToZone(2)
                event.accepted = true
            }
            // Для зоны 2 событие не обрабатываем – пусть идёт в GridView
        }
        
        // ========== PAGE UP/DOWN ПЕРЕКЛЮЧЕНИЕ СТРАНИЦ ==========
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
                if (currentPage < 3) {
                    sTab.stop(); sTab.play();
                    safeNav(currentPage + 1);
                    goToZone(1);
                }
                event.accepted = true
            }
        }

        // ========== НАВИГАЦИЯ ВВЕРХ ==========
        else if (event.key === Qt.Key_Up) {
            if (focusZone === 2) {
                // В основном контенте - проверяем, можно ли двигаться вверх
                // Это событие дойдёт до GridView, и если он на первой строке, он вызовет goToZone(1)
                // Поэтому здесь ничего не делаем, пусть обрабатывает GridView
                event.accepted = false;
            }
            else if (focusZone === 1) {
                // С верхних кнопок в верхний навигатор
                console.log("Zone 0 → Zone 1 (top nav)")
                goToZone(0)
                sNav.stop();
                sNav.play(); 
                event.accepted = true
            }
            else if (focusZone === 1) {
                // На верхнем навигаторе - ничего не делаем
                console.log("Already at top nav")
                sNav.stop();
                sNav.play(); 
                event.accepted = true
            }
        }
        
        // ========== ГОРИЗОНТАЛЬНАЯ НАВИГАЦИЯ ==========
        else if (event.key === Qt.Key_Left) {
            if (focusZone === 0 && topButtonsNames.currentIndex > 0) {
                topButtonsNames.currentIndex--
                event.accepted = true
            }
            else if (focusZone === 1) {
                // Переключение страницы влево
                if (currentPage > 0) {
                    sTab.stop(); sTab.play();
                    safeNav(currentPage - 1);
                }
                event.accepted = true
            }
            // В зоне 2 обрабатывается в GridView
        }

        else if (event.key === Qt.Key_Right) {
            if (focusZone === 0 && topButtonsNames.currentIndex < 3) {
                topButtonsNames.currentIndex++
                event.accepted = true
            }
            else if (focusZone === 1) {
                // Переключение страницы вправо
                if (currentPage < 3) {
                    sTab.stop(); sTab.play();
                    safeNav(currentPage + 1);
                }
                event.accepted = true
            }
            // В зоне 2 обрабатывается в GridView
        }
        
        // ========== КНОПКА ACCEPT (SELECT/A) ==========
        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
            if (focusZone === 1) {
                // Выбор таба в верхнем навигаторе
                console.log("Accept on top nav tab:", topNavRow.currentIndex)
                currentPage = topNavRow.currentIndex
                event.accepted = true
            }
            else if (focusZone === 0) {
                // Клик по выбранной верхней кнопке
                console.log("Accept on top button:", topButtonsNames.currentIndex)
                // Здесь можно добавить логику для каждой кнопки
                event.accepted = true
            }
            // Для зоны 2 обрабатывается в GridView
        }
        
        else if (api.keys.isMenu(event) && !root.optionsMenuVisible && !root.closeMenuVisible) {
            // Кнопка Menu (левый нижний угол) - открытие левого меню
            leftBar.toggle()
            event.accepted = true
        }
        
               
        // ========== КНОПКА CANCEL (BACK/B) ==========
        else if (api.keys.isCancel(event) && !root.optionsMenuVisible && !root.closeMenuVisible) {      
            if (collectionGamesLoader.active) {
                // Выход из вложенных игр коллекции
                console.log("Back from collection games")
                collectionGamesLoader.active = false
                // Возвращаем фокус в основную сетку коллекций
                goToZone(2)
                event.accepted = true
            }
            else if (focusZone === 2) {
                // Из основного контента возвращаемся к верхним кнопкам
                console.log("Back from grid to top buttons")
                goToZone(1)
                event.accepted = true
            }
            else if (focusZone === 0) {
                // Из верхних кнопок возвращаемся к навигатору
                console.log("Back from top buttons to nav")
                goToZone(1)
                event.accepted = true
            }
            else if (focusZone === 1) {
                // В верхнем навигаторе - открываем меню
                console.log("Open menu from top nav")
                theme.openPage(0)
                event.accepted = true
            }
        }
    }
    
    function goToZone(zoneIndex) {
        if (zoneIndex < 0) zoneIndex = 0
        if (zoneIndex > 2) zoneIndex = 2
        
        
        // СНАЧАЛА СНИМАЕМ ФОКУС СО ВСЕХ
        topNavRow.focus = false
        topButtonsNames.focus = false
        
        // Снимаем фокус с текущего GridView
        var currentGridView = getCurrentGridView();
        if (currentGridView) {
            currentGridView.focus = false
        }
        
        focusZone = zoneIndex
        
        // ЗАТЕМ УСТАНАВЛИВАЕМ ФОКУС ТОЛЬКО НА ОДНУ ЗОНУ
        if (zoneIndex === 1) {
            topNavRow.focus = true
            topNavRow.forceActiveFocus()
        }
        else if (zoneIndex === 0) {
            topButtonsNames.focus = true
            topButtonsNames.forceActiveFocus()
        }
        else if (zoneIndex === 2) {
            currentGridView = getCurrentGridView();
            if (currentGridView) {
                currentGridView.focus = true
                currentGridView.forceActiveFocus()
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
                color: "black"
                opacity: root.isScrolled ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }
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
                spacing: 80
                focus: true
                property int currentIndex: 0
                
                Keys.enabled: true
                Keys.forwardTo: []
                
                Keys.onLeftPressed: {
                    if (currentIndex > 0) {
                        currentIndex--;
                        sTab.stop(); sTab.play();
                    safeNav(currentPage - 1);
                        if (collectionGamesLoader.active) collectionGamesLoader.active = false
                        currentPage = currentIndex;          
                    }
                    event.accepted = true;
                }
                
                Keys.onRightPressed: {
                    if (currentIndex < 3) {
                        currentIndex++;
                        sTab.stop(); sTab.play();
                    safeNav(currentPage + 1);
                        if (collectionGamesLoader.active) collectionGamesLoader.active = false
                        currentPage = currentIndex;
                    }
                    event.accepted = true;
                }
                
                Keys.onReturnPressed: {
                    if (collectionGamesLoader.active) collectionGamesLoader.active = false
                    currentPage = currentIndex
                    event.accepted = true
                }

                Repeater {
                    model: [
                        { name: "ALL GAMES" },
                        { name: "FAVORITES" },
                        { name: "COLLECTIONS" },
                        { name: "OTHER" }
                    ]

                    delegate: Rectangle {
                        width: 240
                        height: 74
                        radius: 40
                        color: {
                            if (root.focusZone === 1 && index === currentPage) {
                                return "white"
                            } else if (index === currentPage) {
                                return "#26FFFFFF"
                            } else {
                                return "transparent"
                            }
                        }
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
    anchors.centerIn: parent
    font.pixelSize: 25
    font.family: bold.name
    // Устанавливаем черный цвет только для активного таба, иначе белый
    color: (root.focusZone === 1 && index === currentPage) ? "black" : "white"

    text: {
        var count = 0;
        if (index === 0) count = api.allGames.count;
        else if (index === 1) count = favoritesModel.count;
        else if (index === 2) count = api.collections.count;
        else if (index === 3) count = api.allGames.count;
        
        // Формируем строку: Название + пробел + число
        return modelData.name + "      " + "<font color='#808080'>" + count + "</font>";
    }
    
    // Включаем поддержку rich text для отображения серого цвета внутри строки
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
                var component;
                var pages = [pageAllGames, pageFavorites, pageCollections, pageOther];
                
                if (index >= 0 && index < pages.length) {
                    component = pages[index];
                    
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
                var pages = [pageAllGames, pageFavorites, pageCollections, pageOther];
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
        // === 4 СТРАНИЦЫ ===
        // ===============================
        Component {
            id: pageAllGames
            FocusScope {
                width: parent.width
                height: parent.height
                property var gridView: gridLoader.item ? gridLoader.item.gridView : null

                Loader {
                    id: gridLoader
                    anchors.fill: parent
                    asynchronous: api.memory.has("asyncLoading") ? api.memory.get("asyncLoading") : false
                    sourceComponent: gameGridComponent
                    onLoaded: {
                        item.model = sortedAllGames
                        item.gameSelected.connect(function(game) {
                            theme.currentGame = game;
                            theme.openPage(8);
                        })
                    }
                }
            }
        }

        Component {
            id: pageFavorites
            FocusScope {
                width: parent.width
                height: parent.height
                property var gridView: gridLoader.item ? gridLoader.item.gridView : null

                Loader {
                    id: gridLoader
                    anchors.fill: parent
                    sourceComponent: gameGridComponent
                    onLoaded: {
                        item.model = sortedFavoritesModel
                        item.gameSelected.connect(function(game) {
                            theme.currentGame = game;
                            theme.openPage(8);
                        })
                    }
                }
            }
        }

        Component {
            id: pageCollections
            FocusScope {
                width: parent.width
                height: parent.height
                property color flickableColor: "#0F1318"
                property alias gridCollections: gridCollections

                Rectangle {
                    anchors.fill: parent
                    color: flickableColor
                    
                    GridView {
                        id: gridCollections
                        anchors {
                            fill: parent
                            leftMargin: parent.width * 0.015
                            rightMargin: parent.width * 0.015
                            topMargin: 20
                            bottomMargin: 20
                        }
                        onContentYChanged: {
                            root.isScrolled = (contentY > 30)
                        }

                        clip: false
                        cellWidth: width / theme.libraryRows
                        cellHeight: cellWidth * 1
                        model: api.collections
                        currentIndex: 0
                        focus: false

                        snapMode: GridView.NoSnap
                        highlightRangeMode: GridView.ApplyRange
                        highlightMoveDuration: 250
                        cacheBuffer: cellHeight * 3

                        Keys.onPressed: {
                            if (root.focusZone === 2) {
                                if (event.key === Qt.Key_Left) {
                                    if (currentIndex > 0) { currentIndex--; event.accepted = true; sNav.stop(); sNav.play(); }
                                }
                                else if (event.key === Qt.Key_Right) {
                                    if (currentIndex < count - 1) { currentIndex++; event.accepted = true; sNav.stop(); sNav.play(); }
                                }
                                else if (event.key === Qt.Key_Up) {
                                    var columnsCount = Math.floor(width / cellWidth);
                                    if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; sNav.stop(); sNav.play(); }
                                    else { currentIndex -= columnsCount; event.accepted = true; sNav.stop(); sNav.play(); }
                                }
                                else if (event.key === Qt.Key_Down) {
                                    var columnsCount = Math.floor(width / cellWidth);
                                    if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; sNav.stop(); sNav.play(); }
                                }
                                else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                                    if (model.get(currentIndex)) {
                                        var selectedCollection = model.get(currentIndex);
                                        collectionGamesLoader.collection = selectedCollection;
                                        collectionGamesLoader.active = true;
                                        Qt.callLater(function() {
                                            if (collectionGamesLoader.item && collectionGamesLoader.item.gridView) {
                                                if (collectionGamesLoader.item.gridView.count > 0) {
                                                    collectionGamesLoader.item.gridView.currentIndex = 0;
                                                    collectionGamesLoader.item.gridView.forceActiveFocus();
                                                    root.focusZone = 2;
                                                }
                                            }
                                        });
                                    }
                                    event.accepted = true;
                                }
                            }
                        }

                        delegate: Item {
                            width: gridCollections.cellWidth
                            height: gridCollections.cellHeight 
                            property bool hasImage: {
    if (!modelData) return false;

    // 1. Проверка веб-ассетов (SteamGridDB) через api.memory
    if (typeof api !== "undefined" && api.memory) {
        var customData = api.memory.get("custom_assets_" + modelData.title);
        if (customData && customData.assets && customData.assets.capsule) {
            return true;
        }
    }

    // 2. Проверка локальных ассетов (Metadata)
    return !!(modelData.assets && (modelData.assets.poster || modelData.assets.boxFront));
}

                            property bool isFocused: GridView.isCurrentItem && gridCollections.focus && root.focusZone === 2

                            Rectangle {
                                id: collectionContainer
                                anchors.fill: parent
                                color: "transparent"
                                scale: isFocused ? 1.015 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }

                                Rectangle {
                                    width: gridCollections.cellWidth * 0.9
                                    height: gridCollections.cellHeight * 0.9
                                    anchors.centerIn: parent
                                    color: "#555"
                                    visible: !hasImage
                                }

                                Item {
                                    width: gridCollections.cellWidth * 0.9
                                    height: gridCollections.cellHeight * 0.9
                                    anchors.centerIn: parent
                                    visible: !hasImage
                                    clip: true

                                    Item {
                                        anchors.centerIn: parent
                                        width: parent.width * 1
                                        height: parent.height * 1
                                        transform: [
                                            Matrix4x4 {
                                                matrix: {
                                                    var skew = 6.5 * Math.PI / 180
                                                    var rot = -35 * Math.PI / 180
                                                    
                                                    var rotMatrix = Qt.matrix4x4(
                                                        Math.cos(rot), -Math.sin(rot), 0, 0,
                                                        Math.sin(rot), Math.cos(rot), 0, 0,
                                                        0, 0, 1, 0,
                                                        0, 0, 0, 1
                                                    )
                                                    
                                                    var skewMatrix = Qt.matrix4x4(
                                                        1, Math.tan(skew), 0, 0,
                                                        0, 1, 0, 0,
                                                        0, 0, 1, 0,
                                                        0, 0, 0, 1
                                                    )
                                                    
                                                    return Qt.matrix4x4(1, 0, 0, width/2, 0, 1, 0, height/2, 0, 0, 1, 0, 0, 0, 0, 1).times(rotMatrix.times(skewMatrix)).times(Qt.matrix4x4(1, 0, 0, -width/2, 0, 1, 0, -height/2, 0, 0, 1, 0, 0, 0, 0, 1))
                                                }
                                            }
                                        ]

                                        Grid {
                                            id: collectionGrid
                                            anchors.centerIn: parent 
                                            columns: gameCount === 1 ? 1 : (gameCount <= 4 ? 2 : 3)
                                            rows: gameCount <= 2 ? 1 : (gameCount <= 5 ? 2 : 3)
                                            spacing: 30 

                                            property var gameList: modelData.games
                                            property int gameCount: gameList ? gameList.count : 0

                                            Repeater {
                                                model: Math.min(parent.gameCount, 9)
                                                
                                                delegate: Item {
                                                    width: {
                                                        if (parent.gameCount === 1) return (gridCollections.cellHeight * 1.3) / 1.5
                                                        if (parent.gameCount <= 4) return (gridCollections.cellWidth * 1.3 - parent.spacing) / 2
                                                        return (gridCollections.cellWidth * 1.3 - parent.spacing * 2) / 3
                                                    }
                                                    height: width * 1.5

                                                    Image {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: parent.leftPadding
                                                        asynchronous: api.memory.has("asyncLoading") ? api.memory.get("asyncLoading") : false
                                                        source: {
                                                            var game = parent.parent.gameList.get(index)
                                                            return (game && game.assets) ? (theme.getAssetSource("poster", game)) : ""
                                                        }
                                                        fillMode: Image.PreserveAspectCrop
                                                        visible: source.toString() !== ""
                                                        cache: true // Обязательно для списков
                                                        
                                                        layer.enabled: true
                                                        layer.smooth: true // Отключаем сглаживание для экономии ресурсов
                                                        layer.textureSize: Qt.size(width / 1.2, height / 1.2) // Рендерим в 2 раза меньшем разрешении
                                                        layer.effect: DropShadow {
                                                            transparentBorder: true
                                                            radius: 15
                                                            samples: 16
                                                            color: "#80000000"
                                                            horizontalOffset: -30
                                                            verticalOffset: 20
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Image {
                                    width: gridCollections.cellWidth * 0.9
                                    height: gridCollections.cellHeight * 0.9
                                    anchors.centerIn: parent
                                    source: {
                                        if (modelData.assets) {
                                            if (modelData.assets.boxFront) return modelData.assets.boxFront                                    
                                            if (modelData.assets.poster) return modelData.assets.poster
                                        }
                                        return ""
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    visible: hasImage
                                }
                                
                                Rectangle {
                                    id: textSpot
                                    width: gridCollections.cellWidth * 0.9
                                    height: gridCollections.cellHeight * 0.9
                                    anchors.centerIn: parent
                                    color: "transparent"
                                    clip: true
                                    opacity: 0.7
                                    z: 9
                                    visible: !hasImage

                                    Image {
                                        id: blurImg
                                        width: 2
                                        height: 2
                                        anchors.centerIn: parent
                                        source: {
    if (modelData && modelData.games && modelData.games.count > 0) {
        var firstGame = modelData.games.get(0);
        return theme.getAssetSource("poster", firstGame);
    }
    return "";
}
                                        fillMode: Image.PreserveAspectCrop
                                        visible: false 
                                    }

                                    FastBlur {
                                        id: blurredImage
                                        anchors.fill: parent 
                                        source: blurImg
                                        radius: 144
                                        visible: false 
                                    }

                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        source: blurredImage 
                                        maskSource: Item {
                                            width: textSpot.width 
                                            height: textSpot.height 
                                            
                                            Canvas {
                                                anchors.fill: parent
                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.reset()
                                                    
                                                    var textY = countText.y + countText.height / 2

                                                    var globalGlow = ctx.createRadialGradient(width/2, height/2, 0, width/2, height/2, width * 0.9)
                                                    globalGlow.addColorStop(0.0, "#90FFFFFF") 
                                                    globalGlow.addColorStop(0.6, "#30FFFFFF") 
                                                    globalGlow.addColorStop(1.0, "transparent")
                                                    ctx.fillStyle = globalGlow
                                                    ctx.fillRect(0, 0, width, height)

                                                    var bottomGlow = ctx.createRadialGradient(width/2, textY, 0, width/2, textY, width * 0.8)
                                                    bottomGlow.addColorStop(0.0, "white")
                                                    bottomGlow.addColorStop(0.2, "#E0FFFFFF")
                                                    bottomGlow.addColorStop(0.5, "#60FFFFFF")
                                                    bottomGlow.addColorStop(0.9, "transparent")
                                                    
                                                    ctx.fillStyle = bottomGlow
                                                    ctx.fillRect(0, 0, width, height)
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    id: countText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom 
                                    anchors.bottomMargin: 60

                                    text: "( " + (modelData.games ? modelData.games.count : 0) + " )"
                                    color: "grey"
                                    font.pixelSize: 30    
                                    font.family: bold.name
                                    
                                    visible: !hasImage
                                    z: 10
                                    layer.enabled: true
                                    layer.effect: DropShadow { transparentBorder: true; radius: 0; samples: 16; color: "black"; verticalOffset: 2; horizontalOffset: -2}
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: countText.top
                                    anchors.bottomMargin: 20
                                    
                                    text: modelData.name || ("Collection " + (index + 1))
                                    color: "white"
                                    font.pixelSize: 30
                                    font.capitalization: Font.AllUppercase
                                    font.family: bold.name
                                    layer.enabled: true
                                    layer.effect: DropShadow { transparentBorder: true; radius: 0; samples: 16; color: "black"; verticalOffset: 2; horizontalOffset: -2}
                                    
                                    width: parent.width * 0.9
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3 
                                    elide: Text.ElideRight
                                    
                                    visible: !hasImage
                                    z: 10 
                                }
                            }

                            Rectangle {
                                id: highlightBorderCollection
                                width: gridCollections.cellWidth * 0.93
                                height: gridCollections.cellHeight * 0.93
                                anchors.centerIn: parent
                                color: "transparent"
                                border.width: 5
                                border.color: "grey"
                                radius: 2
                                opacity: isFocused ? 1.0 : 0.0
                                z: 1000
                                scale: isFocused ? 1.028 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150 } }

                                SequentialAnimation {
                                    id: appearAnimCollection
                                    running: isFocused
                                    loops: 1
                                    ParallelAnimation {
                                        NumberAnimation { target: highlightBorderCollection; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                        NumberAnimation { target: highlightBorderCollection; property: "radius"; to: 0; duration: 200; easing.type: Easing.OutBack }
                                        NumberAnimation { target: highlightBorderCollection; property: "width"; to: gridCollections.cellWidth * 0.93 + 12; duration: 200; easing.type: Easing.OutBack }
                                        NumberAnimation { target: highlightBorderCollection; property: "height"; to: gridCollections.cellHeight * 0.93 + 12; duration: 200; easing.type: Easing.OutBack }
                                        ColorAnimation { target: highlightBorderCollection; property: "border.color"; to: "white"; duration: 200 }
                                        NumberAnimation { target: highlightBorderCollection; property: "opacity"; to: 0.5; duration: 200 }
                                    }
                                    ParallelAnimation {
                                        NumberAnimation { target: highlightBorderCollection; property: "radius"; to: 2; duration: 200; easing.type: Easing.InOutQuad }
                                        NumberAnimation { target: highlightBorderCollection; property: "width"; to: gridCollections.cellWidth * 0.93; duration: 200; easing.type: Easing.InOutQuad }
                                        NumberAnimation { target: highlightBorderCollection; property: "height"; to: gridCollections.cellHeight * 0.93; duration: 200; easing.type: Easing.InOutQuad }
                                        NumberAnimation { target: highlightBorderCollection; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                                    }
                                    SequentialAnimation {
                                        loops: Animation.Infinite
                                        NumberAnimation { target: highlightBorderCollection; property: "opacity"; to: 0.2; duration: 500 }
                                        NumberAnimation { target: highlightBorderCollection; property: "opacity"; to: 0.5; duration: 500 }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (!isFocused) { // DECKOS: then opened at once (see the games grid)
                                        gridCollections.currentIndex = index
                                        gridCollections.forceActiveFocus()
                                        root.goToZone(2)
                                    }
                                    collectionGamesLoader.collection = modelData
                                    collectionGamesLoader.active = true
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            id: collectionGamesLoader
            y: topZone.y + topZone.height
            width: parent.width
            height: parent.height - (topZone.y + topZone.height + bottomBar.height)
            active: false
            asynchronous: api.memory.has("asyncLoading") ? api.memory.get("asyncLoading") : false
            property var collection
            
            sourceComponent: FocusScope {
                width: parent.width
                height: parent.height
                property color flickableColor: "#0F1318"
                property alias gridView: gridView

                Rectangle {
                    anchors.fill: parent
                    color: flickableColor

                    GridView {
                        id: gridView
                        anchors {
                            fill: parent
                            leftMargin: parent.width * 0.015
                            rightMargin: parent.width * 0.015
                            topMargin: 20
                            bottomMargin: 20
                        }
                        
                        clip: false
                        cellWidth: width / theme.libraryRows
                        cellHeight: cellWidth * 1.5
                        model: collectionGamesLoader.collection ? collectionGamesLoader.collection.games : null
                        currentIndex: 0
                        focus: false
                        
                        snapMode: GridView.NoSnap
                        highlightRangeMode: GridView.ApplyRange
                        highlightMoveDuration: 250
                        cacheBuffer: cellHeight * 3

                        onContentYChanged: {
                            root.isScrolled = (contentY > 30)
                        }

                        Keys.onPressed: {
                            if (root.focusZone === 2) {
                                if (event.key === Qt.Key_Left) {
                                    if (currentIndex > 0) { currentIndex--; event.accepted = true; sNav.stop(); sNav.play(); }
                                }
                                else if (event.key === Qt.Key_Right) {
                                    if (currentIndex < count - 1) { currentIndex++; event.accepted = true; sNav.stop(); sNav.play(); }
                                }
                                else if (event.key === Qt.Key_Up) {
                                    var columnsCount = Math.floor(width / cellWidth);
                                    if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; sNav.stop(); sNav.play(); }
                                    else { currentIndex -= columnsCount; event.accepted = true; sNav.stop(); sNav.play(); }
                                }
                                else if (event.key === Qt.Key_Down) {
                                    var columnsCount = Math.floor(width / cellWidth);
                                    if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; sNav.stop(); sNav.play(); }
                                }
                                else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                                    if (model.get(currentIndex) && model.get(currentIndex).launch) {
                                        var gameData = model.get ? model.get(currentIndex) : model[currentIndex];
                                        theme.currentGame = gameData;
                                        root.focus = false
                                        theme.openPage(8);
                                        event.accepted = true;
                                    }
                                    event.accepted = true;
                                }
                                else if (api.keys.isDetails(event) && !root.optionsMenuVisible) {
                                    if (model.get(currentIndex)) {
                                        root.currentFocusedGame = model.get(currentIndex);
                                        root.toggleOptionsMenu();
                                    }
                                    event.accepted = true;
                                }
                            }
                        }

                        delegate: Item {
                            width: gridView.cellWidth
                            height: gridView.cellHeight 
                            property bool hasImage: {
    if (!modelData) return false;

    // 1. Проверка веб-ассетов (SteamGridDB) через api.memory
    if (typeof api !== "undefined" && api.memory) {
        var customData = api.memory.get("custom_assets_" + modelData.title);
        if (customData && customData.assets && customData.assets.capsule) {
            return true;
        }
    }

    // 2. Проверка локальных ассетов (Metadata)
    return !!(modelData.assets && (modelData.assets.poster || modelData.assets.boxFront));
}

                            property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                            Rectangle {
    id: gameContainer
    anchors.fill: parent 
    color: "transparent"
    scale: isFocused ? 0.96425 : 0.95
    Behavior on scale { NumberAnimation { duration: 150 } }

    Rectangle {
        width: gridView.cellWidth * 0.9
        height: gridView.cellHeight * 0.9
        anchors.centerIn: parent
        color: "#555"
        visible: !hasImage
        radius: theme.roundedCovers ? 24 : 0
    }
    
    Rectangle {
        id: favoritesIndicator
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: 20
            bottomMargin: 27
        }
        width: 110
        height: 55
        radius: 45
        color: "#0F1318"
        visible: modelData && modelData.favorite === true && isFocused
        z: 20
        
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            spacing: 5
            
            Text {
                text: "★"
                color: "white"
                font.pixelSize: 50
                font.family: icons.name
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: "✓"
                color: "#6ccf58"
                font.pixelSize: 50
                font.family: icons.name
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Rectangle {
        id: posterMask
        width: gridView.cellWidth * 0.9
        height: gridView.cellHeight * 0.9
        anchors.centerIn: parent
        radius: theme.roundedCovers ? 24 : 0
        visible: false
    }

    AnimatedImage {
        id: gamePoster
        width: gridView.cellWidth * 0.9
        height: gridView.cellHeight * 0.9
        anchors.centerIn: parent
        
        readonly property var assetData: modelData.assets || {}
        source: theme.getAssetSource("poster", modelData)

        fillMode: AnimatedImage.PreserveAspectCrop
        visible: hasImage && status === AnimatedImage.Ready
        
        playing: visible && status === AnimatedImage.Ready && theme.animatedCovers && (!theme.animationInFocus || isFocused)
        
        cache: true
        asynchronous: true
        
        layer.enabled: theme.roundedCovers
        layer.effect: OpacityMask {
            maskSource: posterMask
        }
    }


                            
                            Item {
                                width: gridView.cellWidth * 1.1
                                height: gridView.cellHeight * 1.1
                                anchors.centerIn: parent
                                clip: false
                                opacity: isFocused ? 0.2 : 0.0
                                z: parent.z - 1
                                
                                Image {
                                    id: blurSource
                                    anchors.fill: parent
                                    source: theme.getAssetSource("poster", modelData)
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
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
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData.title 
                                color: "white"
                                font.family: bold.name
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                                width: parent.width * 0.9
                                visible: !hasImage
                            }
                        }

                        Rectangle {
                            id: highlightBorder
                            width: gridView.cellWidth * 0.947
                            height: gridView.cellHeight * 0.935
                            anchors.centerIn: parent
                            color: "transparent"
                            border.width: 5
                            border.color: "grey"
                            radius: theme.roundedCovers ? 32 : 2
                            opacity: isFocused ? 1.0 : 0.0
                            visible: isFocused
                            z: 1000
                            scale: isFocused ? 0.96425 : 0.95
                            Behavior on scale { NumberAnimation { duration: 150 } }

                            SequentialAnimation {
                                id: appearAnim
                                running: isFocused
                                loops: 1
                                ParallelAnimation {
                                    NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: highlightBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947 + 12; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935 + 12; duration: 200; easing.type: Easing.OutBack }
                                    ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 200 }
                                    NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 200 }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: highlightBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947; duration: 200; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935; duration: 200; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: highlightBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                                }
                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.2; duration: 500 }
                                    NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 500 }
                                }
                            }
                        }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (!isFocused) { // DECKOS: then opened at once (see the games grid)
                                        gridView.currentIndex = index
                                        gridView.forceActiveFocus()
                                        root.goToZone(2)
                                    }
                                    if (modelData && modelData.launch) {
                                        theme.currentGame = modelData;
                                        theme.openPage(8);
                                    }
                                }
                                onPressAndHold: {
                                    if (root.focusZone === 2) {
                                        root.currentFocusedGame = modelData
                                        root.toggleOptionsMenu()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: pageOther
            FocusScope {
                width: parent.width
                height: parent.height
                property var gridView: gridLoader.item ? gridLoader.item.gridView : null

                Loader {
                    id: gridLoader
                    anchors.fill: parent
                    asynchronous: api.memory.has("asyncLoading") ? api.memory.get("asyncLoading") : false
                    sourceComponent: gameGridComponent
                    onLoaded: {
                        item.model = sortedAllGames
                        item.gameSelected.connect(function(game) {
                            theme.currentGame = game;
                            theme.openPage(8);
                        })
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
        color: "transparent"
        z: 10000
        
        Rectangle {
            anchors.fill: parent
            color: "black"
            z: -1
        }

        // ======= ROW: TOP BUTTONS =======
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
                        theme.openPage(9) // Открываем Library
                    }
                }

            // ===== 0. SEARCH =====
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
                                    NumberAnimation { 
                                        target: searchIcon
                                        property: "x"
                                        to: searchIcon.posRight - 20
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                                }

                                PropertyAction { 
                                    target: searchIcon
                                    property: "x"
                                    value: searchIcon.posLeft + 20
                                }

                                ParallelAnimation {
                                    NumberAnimation { 
                                        target: searchIcon
                                        property: "x"
                                        to: searchIcon.posLeft
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 1; duration: 200 }
                                }
                            }
                        },
                        
                        Transition {
                            from: "focused"; to: "default"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { 
                                        target: searchIcon
                                        property: "x"
                                        to: searchIcon.posLeft + 20
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                                }

                                PropertyAction { 
                                    target: searchIcon
                                    property: "x"
                                    value: searchIcon.posRight - 20
                                }

                                ParallelAnimation {
                                    NumberAnimation { 
                                        target: searchIcon
                                        property: "x"
                                        to: searchIcon.posRight
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
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
                    font.family: bold.name
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

            // ===== 1. NETWORK =====
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
            
            // ===== 2. BATTERY =====
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
                        if (isNaN(api.device.batteryPercent)) return "../assets/theme-icons/battery" + getSuffix() + ".png";
                        const batteryPercent = api.device.batteryPercent * 100;
                        if (batteryPercent <= 20) return "../assets/theme-icons/20" + getSuffix() + ".png";
                        else if (batteryPercent <= 40) return "../assets/theme-icons/40" + getSuffix() + ".png";
                        else if (batteryPercent <= 60) return "../assets/theme-icons/60" + getSuffix() + ".png";
                        else if (batteryPercent <= 80) return "../assets/theme-icons/80" + getSuffix() + ".png";
                        else return "../assets/theme-icons/battery" + getSuffix() + ".png";
                    }

                    function getSuffix() {
                        return (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "B" : "";
                    }

                    Text {
                        text: isNaN(api.device.batteryPercent) ? "N/A" : (api.device.batteryPercent * 100).toFixed(0) + "%"
                        color: (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "black" : "white"
                        font.family: bold.name
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
                            source: "../assets/theme-icons/charging" + batteryRow.getSuffix() + ".png"
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

            // ===== CLOCK =====
            Rectangle {
                id: topBtnClock
                width: theme.use24HourFormat ? 130 : 200; height: root.topH
                color: "transparent"
                border.color: "transparent"               

                // Динамически определяем формат времени на основе настройки
                property string timeFormat: theme.use24HourFormat ? "HH:mm" : "hh:mm AP"

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    // Инициализация при загрузке
                    text: Qt.formatTime(new Date(), topBtnClock.timeFormat)
                    font.pixelSize: 35
                    font.family: bold.name
                    color: "white"
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
                }                
                
                // Мгновенно обновляем текст, если переключатель нажали
                onTimeFormatChanged: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
            }

            // ===== 3. USER =====
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
                    source: (root.theme && root.theme.profilePictureSource !== "") ? root.theme.profilePictureSource : "../assets/logo/logo.jpg" /* DECKOS */
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
                    font.family: bold.name 
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
            
            Item {
    id: sortBtn
    width: sortLayout.width
    height: 53 // Высота иконки для правильного центрирования
    anchors.verticalCenter: parent.verticalCenter
    visible: !root.closeMenuVisible && !root.optionsMenuVisible && !leftBar.isOpen

    Row {
        id: sortLayout
        spacing: 18
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: theme.nintendoLayout ? (theme.universalIcons ? "Х" : "X") : (theme.universalIcons ? "У" : "Y")
            font.family: icons.name
            font.pixelSize: 53
            color: "white"
            // Центрируем иконку и чуть приподнимаем, если шрифт "сидит" низко
            y: parent.height * -0.025
        }

        Text {
            text: "SORT BY"
            font.family: bold.name
            font.pixelSize: 25
            color: "white"
            y: parent.height * 0.23 
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.toggleSortMenu();
        }
    }
}


            Row {
                spacing: 18
                visible: root.closeMenuVisible ? 0 : 1 && !leftBar.isOpen
                anchors.verticalCenter: parent.verticalCenter
                Text { text: theme.nintendoLayout ? (theme.universalIcons ? "У" : "Y") : (theme.universalIcons ? "Х" : "X")
; font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025 }
                Text { text: "OPTIONS"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
            }

            Row {
                spacing: 18
                anchors.verticalCenter: parent.verticalCenter
                Text { text: theme.nintendoLayout ? (theme.universalIcons ? "В" : "B") : (theme.universalIcons ? "А" : "A")
; font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025}
                Text { text: "SELECT"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23}
            }

            Rectangle {
                id: btnBack
                width: 140; height: parent.height
                color: "transparent"
                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Text { text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B")
; font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025}
                    Text { text: "BACK"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
                }
                MouseArea { 
                    anchors.fill: parent
                    onClicked: 
                        if (collectionGamesLoader.active) {
                            console.log("Back from collection games")
                            collectionGamesLoader.active = false
                            goToZone(2)
                            event.accepted = true
                        }
                        else if (focusZone === 2) {
                            console.log("Back from grid to top buttons")
                            goToZone(1)
                            event.accepted = true
                        }
                        else if (focusZone === 0) {
                            console.log("Back from top buttons to nav")
                            goToZone(1)
                            event.accepted = true
                        }
                        else if (focusZone === 1) {
                            console.log("Open menu from top nav")
                            theme.openPage(0)
                            event.accepted = true
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

/* ================= SORT MENU ================= */
FocusScope {
    id: sortMenu
    width: parent.width
    height: parent.height
    visible: sortMenuVisible
    focus: sortMenuVisible
    enabled: visible
    z: 9999

    opacity: sortMenuVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    property int currentButtonIndex: 0

    Item {
        anchors.fill: parent
        z: 0
        visible: sortMenu.visible

        MouseArea { anchors.fill: parent }

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
        width: 550
        height: 220
        anchors.centerIn: parent
        color: "#181B20"

        Column {
            anchors.fill: parent
            spacing: 0

            // ===== 0. ALPHABETICAL =====
            Rectangle {
                width: parent.width
                height: parent.height / 2
                color: sortMenu.currentButtonIndex === 0 ? "white" : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 30

                    Text {
                        text: "Alphabetical"
                        color: sortMenu.currentButtonIndex === 0 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (sortMenu.currentButtonIndex !== 0) {
                            sortMenu.currentButtonIndex = 0;
                            sNav.stop(); sNav.play();
                        } else {
                            root.applySortMode("alphabetical");
                            root.toggleSortMenu();
                        }
                    }
                }
            }

            // ===== 1. LAST PLAYED =====
            Rectangle {
                width: parent.width
                height: parent.height / 2
                color: sortMenu.currentButtonIndex === 1 ? "white" : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 30

                    Text {
                        text: "Last Played"
                        color: sortMenu.currentButtonIndex === 1 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (sortMenu.currentButtonIndex !== 1) {
                            sortMenu.currentButtonIndex = 1;
                            sNav.stop(); sNav.play();
                        } else {
                            root.applySortMode("lastPlayed");
                            root.toggleSortMenu();
                        }
                    }
                }
            }
        }
    }

    Keys.onPressed: {
        if (sortMenuVisible && sortMenu.focus) {
            if (event.key === Qt.Key_Up) {
                if (currentButtonIndex > 0) { currentButtonIndex--; sNav.stop(); sNav.play(); }
                event.accepted = true;
            }
            else if (event.key === Qt.Key_Down) {
                if (currentButtonIndex < 1) { currentButtonIndex++; sNav.stop(); sNav.play(); }
                event.accepted = true;
            }
            else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                if (currentButtonIndex === 0) {
                    root.applySortMode("alphabetical");
                } else {
                    root.applySortMode("lastPlayed");
                }
                root.toggleSortMenu();
                event.accepted = true;
            }
            else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                root.toggleSortMenu();
                sLeftClose.play();
                event.accepted = true;
            }
            else if (event.key === Qt.Key_Y) {
                root.toggleSortMenu();
                event.accepted = true;
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            sShowui.play();
        }
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
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
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
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 0
                    topMargin: parent.height * 0.2 /* DECKOS: was 0.11, room for the profile */
                }
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
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            topMargin: 20
                            bottomMargin: 20
                        }
                        width: 11
                        visible: theme.currentPage === buttonIndex   
                        
                        Rectangle {
                            anchors {
                                right: parent.right
                                top: parent.top
                                bottom: parent.bottom
                            }
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
                            font.family: bold.name
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
            var btn1 = menuButtonComponent.createObject(buttonColumn, { 
                "title": "Home", 
                "buttonIndex": 0,
                "icon": "^"
            })
            var btn2 = menuButtonComponent.createObject(buttonColumn, { 
                "title": "Library", 
                "buttonIndex": 1,
                "icon": "L",
            })
            var btn3 = menuButtonComponent.createObject(buttonColumn, { 
                "title": "Store", 
                "buttonIndex": 2,
                "icon": "€"
            })
            var btn4 = menuButtonComponent.createObject(buttonColumn, { 
                "title": "Friends and Chat", 
                "buttonIndex": 3,
                "icon": "F"
            })
            var btn5 = menuButtonComponent.createObject(buttonColumn, { 
                "title": "Media", 
                "buttonIndex": 4,
                "icon": "M"
            })
            var btn6 = menuButtonComponent.createObject(buttonColumn, { 
                "title": "Downloads", 
                "buttonIndex": 5,
                "icon": "♠︎"
            })
            var btn7 = menuButtonComponent.createObject(buttonColumn, { 
                "title": "Settings", 
                "buttonIndex": 6,
                "icon": "w"
            })
            var btn8 = menuButtonComponent.createObject(buttonColumn, { 
                "title": "Close", 
                "buttonIndex": 7,
                "icon": "C"
            })
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

    /* ================= OPTIONS MENU ================= */
FocusScope {
    id: optionsMenu
    width: parent.width
    height: parent.height
    visible: optionsMenuVisible
    focus: optionsMenuVisible
    enabled: visible
    z: 9999
    
    opacity: optionsMenuVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    property int currentButtonIndex: 0
    property var buttons: [playButton, favoriteButton, propertiesButton, artworkButton, cancelButton]

    /* OPTIONS MENU ФОН */
    Item {
        id: optionsOverlay
        anchors.fill: parent
        z: 0 
        visible: optionsMenu.visible

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
        width: 550
        height: 550 
        anchors.centerIn: parent
        color: "#181B20"
        
        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: -65
            }
            text: currentFocusedGame ? currentFocusedGame.title : "No game selected"
            color: "white"
            font.pixelSize: 38
            font.family: bold.name
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        
        Column {
            anchors.fill: parent
            spacing: 0
            
            // ===== 0. PLAY =====
            Rectangle {
                id: playButton
                width: parent.width
                height: parent.height / 5
                color: optionsMenu.currentButtonIndex === 0 ? "#54B63D" : "transparent"
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 30                    
                    Text {
                        text: "♥︎"
                        color: "white"
                        font.pixelSize: 55
                        font.family: icons.name
                        anchors.verticalCenter: parent.verticalCenter
                    }                  
                    Text {
                        text: "Play"
                        color: "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (optionsMenu.currentButtonIndex !== 0) {
                            optionsMenu.currentButtonIndex = 0
                            sNav.stop(); sNav.play();
                        } else if (currentFocusedGame) {
                            if (typeof sGame !== "undefined") sGame.play();
                            currentFocusedGame.launch()
                            root.toggleOptionsMenu()
                        }
                    }
                }
            }
            
            // ===== 1. FAVORITE =====
            Rectangle {
                id: favoriteButton
                width: parent.width
                height: parent.height / 5
                color: optionsMenu.currentButtonIndex === 1 ? "white" : "transparent"
                
                Text {
                    text: currentFocusedGame ? (currentFocusedGame.favorite ? "   Delete from favorites" : "   Add to favorites") : "   Add to favorites"
                    color: optionsMenu.currentButtonIndex === 1 ? "black" : "white"
                    font.pixelSize: 35
                    font.family: bold.name
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (optionsMenu.currentButtonIndex !== 1) {
                            optionsMenu.currentButtonIndex = 1
                            sNav.stop(); sNav.play();
                        } else if (currentFocusedGame) {
                            currentFocusedGame.favorite = !currentFocusedGame.favorite
                            root.toggleOptionsMenu()
                        }
                    }
                }
            }
            
            // ===== 2. PROPERTIES =====
            Rectangle {
                id: propertiesButton
                width: parent.width
                height: parent.height / 5
                color: optionsMenu.currentButtonIndex === 2 ? "white" : "transparent"
                
                Text {
                    text: "   Properties"
                    color: optionsMenu.currentButtonIndex === 2 ? "black" : "white"
                    font.pixelSize: 35
                    font.family: bold.name
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (optionsMenu.currentButtonIndex !== 2) {
                            optionsMenu.currentButtonIndex = 2
                            sNav.stop(); sNav.play();
                        } else if (currentFocusedGame) {
                            theme.currentGame = currentFocusedGame;
                            api.memory.set("targetGameName", currentFocusedGame.title);
                            root.toggleOptionsMenu();
                            theme.openPage(14);
                        }
                    }
                }                
            }

            // ===== 3. CHANGE ARTWORK =====
            Rectangle {
                id: artworkButton
                width: parent.width
                height: parent.height / 5
                color: optionsMenu.currentButtonIndex === 3 ? "white" : "transparent"
                
                Text {
                    text: "   Change artwork..."
                    color: optionsMenu.currentButtonIndex === 3 ? "black" : "white"
                    font.pixelSize: 35
                    font.family: bold.name
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (optionsMenu.currentButtonIndex !== 3) {
                            optionsMenu.currentButtonIndex = 3
                            sNav.stop(); sNav.play();
                        } else if (currentFocusedGame) {
                            theme.currentGame = currentFocusedGame;
                            api.memory.set("targetGameName", currentFocusedGame.title);
                            root.toggleOptionsMenu();
                            theme.openPage(12);
                        }
                    }
                }                
            }
            
            // ===== 4. CANCEL =====
            Rectangle {
                id: cancelButton
                width: parent.width
                height: parent.height / 5
                color: optionsMenu.currentButtonIndex === 4 ? "white" : "transparent"
                
                Text {
                    text: "   Cancel"
                    color: optionsMenu.currentButtonIndex === 4 ? "black" : "white"
                    font.pixelSize: 35
                    font.family: bold.name
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (optionsMenu.currentButtonIndex !== 4) {
                            optionsMenu.currentButtonIndex = 4
                            sNav.stop(); sNav.play();
                        } else {
                            root.toggleOptionsMenu()
                            sLeftClose.play()
                        }
                    }
                }
            }
        }
    }

    Keys.onPressed: {
        if (optionsMenuVisible && optionsMenu.focus) {
            if (event.key === Qt.Key_Up) {
                if (currentButtonIndex > 0) {
                    currentButtonIndex--
                    sNav.stop(); sNav.play(); 
                }
                event.accepted = true
            }
            else if (event.key === Qt.Key_Down) {
                if (currentButtonIndex < 4) {
                    currentButtonIndex++
                    sNav.stop(); sNav.play(); 
                }
                event.accepted = true
            }
            else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (currentButtonIndex === 0) {
                    if (currentFocusedGame) {
                        if (typeof sGame !== "undefined") sGame.play();
                        currentFocusedGame.launch();
                        root.toggleOptionsMenu();
                    }
                } else if (currentButtonIndex === 1) {
                    if (currentFocusedGame) {
                        currentFocusedGame.favorite = !currentFocusedGame.favorite;
                        root.toggleOptionsMenu();
                    }
                } else if (currentButtonIndex === 2) {
                    if (currentFocusedGame) { theme.currentGame = currentFocusedGame; api.memory.set("targetGameName", currentFocusedGame.title) } root.toggleOptionsMenu(); theme.openPage(14) // DECKOS: Properties did nothing with a controller (mouse only)
                } else if (currentButtonIndex === 3) {
                    if (currentFocusedGame) {
                        theme.currentGame = currentFocusedGame;
                        api.memory.set("targetGameName", currentFocusedGame.title);
                    }
                    root.toggleOptionsMenu();
                    theme.openPage(12);
                } else if (currentButtonIndex === 4) {
                    root.toggleOptionsMenu();
                    sLeftClose.play();
                }
                event.accepted = true
            }
            else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
                root.toggleOptionsMenu();
                sLeftClose.play();
                event.accepted = true
            }
        }
    }
    
    onVisibleChanged: {
        if (visible) {
            currentButtonIndex = 0
            forceActiveFocus()
            sShowui.play()
        }
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
            width: 550
            height: 240
            anchors.centerIn: parent
            color: "#181B20"
            
            Text {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: -65
                }
                text: "Close"
                color: "white"
                font.pixelSize: 38
                font.family: bold.name
            }
            
            Column {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                spacing: 0
                
                Rectangle {
                    id: exitButton
                    width: parent.width
                    height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 0 ? "#DE3619" : "transparent"
                                  
                    Text {
                        text: "   Exit"
                        color: "white"
                        font.pixelSize: 35
                        font.family: bold.name
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
                    width: parent.width
                    height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 1 ? "white" : "transparent"
                    
                    Text {
                        text: "   Cancel"
                        color: closeMenu.currentButtonIndex === 1 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
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
                else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape){
                }
                else if (api.keys.isMenu(event)) {    
                }
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
    if (index === 8 || index === 12) {
        var gv = getCurrentGridView()
        var collPage = contentContainer.loadedPages[2]
        var cIdx = (collPage && collPage.gridCollections) ? collPage.gridCollections.currentIndex : 0
        
        api.memory.set("libraryReturnContext", {
            tab: root.currentPage,
            gridIndex: gv ? gv.currentIndex : 0,
            contentY: gv ? gv.contentY : 0,
            isCollection: collectionGamesLoader.active,
            collectionIndex: cIdx
        })
        if (index === 12 || index === 14) {
            api.memory.set("steamGridSource", 1)
        }
    }
    nextPageIndex = index
    exitAnim.start()
}

    // DECKOS: the page host kept this page alive behind the game page and shows it again as it was
    // (tab, collection, focus, scroll position), instead of rebuilding it from libraryReturnContext
    function resumePage() {
        api.memory.set("libraryReturnContext", null)
        enterAnim.start()
        focusTimer.start()
    }


    Component.onCompleted: {
    applySortMode(sortMode)
    enterAnim.start()
    topNavRow.currentIndex = currentPage

    var ctx = api.memory.has("libraryReturnContext") ? api.memory.get("libraryReturnContext") : null
    if (ctx) {
        api.memory.set("libraryReturnContext", null)
                var tab = (ctx.tab !== undefined) ? ctx.tab : 0
        var gridIdx = (ctx.gridIndex !== undefined) ? ctx.gridIndex : 0
        var savedY = (ctx.contentY !== undefined) ? ctx.contentY : 0 
        var isColl = (ctx.isCollection !== undefined) ? ctx.isCollection : false
        var cIdx = (ctx.collectionIndex !== undefined) ? ctx.collectionIndex : 0

        root.currentPage = tab
        topNavRow.currentIndex = tab

        if (tab === 2 && isColl) {
            var collPage = contentContainer.loadedPages[2]
            if (collPage && collPage.gridCollections) {
                collPage.gridCollections.currentIndex = cIdx
            }
            collectionGamesLoader.collection = api.collections.get(cIdx)
            collectionGamesLoader.active = true
        }

        Qt.callLater(function() {
            var gv = getCurrentGridView()
            if (gv) {
                gv.currentIndex = gridIdx
                gv.positionViewAtIndex(gridIdx, GridView.Contain)
                gv.contentY = savedY
                gv.forceActiveFocus()
            }
            root.focusZone = 2
        })

    } else {
        root.goToZone(2)
        focusTimer.start()
    }
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