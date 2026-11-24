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

    property int currentPage: 0
    property real topH: 95
    property var theme
    
    
    property int kbCurrentIndex: 0

    
    // Клавиатура
    property bool keyboardOpen: false
// В самом верху root, где свойства
property string searchQuery: "" 

function handleInput(val) {
    console.log("Input received:", val); // Для отладки в логах
    if (val === "⌫") {
        root.searchQuery = root.searchQuery.slice(0, -1);
    } else if (val === "Done") {
        root.keyboardOpen = false;
        root.goToZone(0);
    } else {
        root.searchQuery += val;
    }
}


    function openKeyboard() {
    keyboardOpen = true;
    keyboardContainer.forceActiveFocus();
}
    
    // В корневой FocusScope добавь:
property bool optionsMenuVisible: false
property var currentFocusedGame: null

    // Система фокуса - 3 зоны (1-0-2)
    property int focusZone: 1 // 1 = верхний бар, 0 = верхние кнопки, 2 = gridView
    
    // Самый нижний слой (фоновая подложка)
Rectangle {
    id: globalBackground
    anchors.fill: parent
    color: "#0F1318" // Тот самый цвет темы
    z: -100 // Всегда сзади всех
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

    // Функция для получения текущего активного GridView
    function getCurrentGridView() {
        if (collectionGamesLoader.active && collectionGamesLoader.item) {
            return collectionGamesLoader.item.gridView;
        } else if (pageLoader.item) {
            if (currentPage === 0 || currentPage === 3) {
                // All Games или Other
                return pageLoader.item.gridView;
            } else if (currentPage === 1) {
                // Favorites
                return pageLoader.item.gridView;
            } else if (currentPage === 2) {
                // Collections
                return pageLoader.item.gridCollections;
            }
        }
        return null;
    }

    // ============================================
    // ГЛАВНЫЙ ОБРАБОТЧИК КЛАВИШ ДЛЯ ВСЕХ ЗОН
    // ============================================
    // В root FocusScope
Keys.onPressed: {
    if (keyboardOpen) {
        // Если клава открыта, разрешаем только Вверх (на поиск) или управление внутри клавы
        if (api.keys.isUp(event)) {
            topButtonsNames.currentIndex = 0;
            topButtonsNames.forceActiveFocus();
            event.accepted = true;
        }
        return; 
    }
    
    // В основном Keys.onPressed в корне
if (api.keys.isDetails(event) && !optionsMenuVisible) {
    // Условие: мы в зоне контента (2) 
    // И ПРИ ЭТОМ: либо это не страница коллекций, либо мы уже ВНУТРИ лоадера игр коллекции
    var isOnCollectionGrid = (currentPage === 2 && !collectionGamesLoader.active);

    if (focusZone === 2 && !isOnCollectionGrid) {
        toggleOptionsMenu();
        event.accepted = true;
        return;
    } else if (focusZone === 2 && isOnCollectionGrid) {
        event.accepted = true; // Поглощаем нажатие, чтобы ничего не происходило
        return;
    }
}

// В корневом Keys.onPressed, после блока горизонтальной навигации, перед блоком ACCEPT:

// ========== PAGE UP/DOWN ПЕРЕКЛЮЧЕНИЕ СТРАНИЦ ==========
else if (api.keys.isPrevPage(event)) {
    if (focusZone === 2 || focusZone === 1) {
        if (currentPage > 0) {
            currentPage--
            topNavRow.currentIndex = currentPage
            console.log("Prev page:", currentPage)
            
            // Сразу ставим фокус на новую страницу
            goToZone(1) // Фокус на верхний навигатор
        }
        event.accepted = true
    }
}
else if (api.keys.isNextPage(event)) {
    if (focusZone === 2 || focusZone === 1) {
        if (currentPage < 3) {
            currentPage++
            topNavRow.currentIndex = currentPage
            console.log("Next page:", currentPage)
            
            // Сразу ставим фокус на новую страницу
            goToZone(1) // Фокус на верхний навигатор
        }
        event.accepted = true
    }
}

    // Навигация между зонами (0: Поиск, 1: Табы, 2: Игры)
    if (api.keys.isDown(event)) {
        if (focusZone === 0) goToZone(1);
        else if (focusZone === 1) goToZone(2);
        event.accepted = true;
    }
    else if (api.keys.isUp(event)) {
        if (focusZone === 2) {
            var gv = getCurrentGridView();
            var cols = gv ? Math.floor(gv.width / gv.cellWidth) : 1;
            if (gv && gv.currentIndex < cols) goToZone(1);
        } else if (focusZone === 1) {
            goToZone(0);
        }
        event.accepted = true;
    }
    // ========== КНОПКА CANCEL (BACK/B) ==========
        else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {      
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
    focusZone = zoneIndex;
    // Сбрасываем фокусы, чтобы не было "двойного фокуса"
    topNavRow.focus = false;
    topButtonsNames.focus = false;
    var gv = getCurrentGridView();
    if (gv) gv.focus = false;

    if (zoneIndex === 0) {
        topButtonsNames.focus = true;
        topButtonsNames.forceActiveFocus();
    } else if (zoneIndex === 1) {
        topNavRow.focus = true;
        topNavRow.forceActiveFocus();
    } else if (zoneIndex === 2 && gv) {
        gv.focus = true;
        gv.forceActiveFocus();
    }
}

Item {
        id: animatedContent
        anchors.fill: parent

   // ===============================
// === ВЕРХНЯЯ ЗОНА (КНОПКИ) ===
// ===============================
Rectangle {
    id: topZone
    y: 95
    width: parent.width
    height: topH
    z: 2
    
    // Вычисляем прозрачность: 0 на старте, 1.0 после прокрутки на 100 пикселей
    // clamp(0, 1) гарантирует, что значение не выйдет за пределы
    property real bgOpacity: Math.min(1.0, Math.max(0.0, (root.currentScrollY + 0) / 100))

    // Используем два слоя: прозрачный контейнер и заливка с изменяемой прозрачностью
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: "#0F1318"
        opacity: parent.bgOpacity // Плавное появление фона
    }
    
    // ТЕКСТ СЛЕВА
    Text {
        id: leftSideText
        anchors {
            left: parent.left
            leftMargin: 40 // Отступ от края экрана
            verticalCenter: parent.verticalCenter
        }
        text: "<" // Замените на нужный текст
        color: "white"
        font.pixelSize: 70
        font.family: icons.name
        opacity: (root.focusZone === 2||root.focusZone === 1) ? 1.0 : 0.0

Behavior on opacity {
    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
}
    }

    // ТЕКСТ СПРАВА (ЗЕРКАЛЬНО)
    Text {
        id: rightSideText
        anchors {
            right: parent.right
            rightMargin: 40 // Такой же отступ как слева
            verticalCenter: parent.verticalCenter
        }
        text: ">" // Замените на нужный текст
        color: "white"
        font.pixelSize: 70
        font.family: icons.name
        opacity: (root.focusZone === 2||root.focusZone === 1) ? 1.0 : 0.0

Behavior on opacity {
    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
}
        horizontalAlignment: Text.AlignRight
    }

    Row {
        id: topNavRow
        anchors.centerIn: parent
        spacing: 80
        focus: true
        property int currentIndex: 0
        
            
    // КОМПОНЕНТ ДОЛЖЕН БЫТЬ FOCUSSCOPE ИЛИ ИМЕТЬ ФОКУС
    // focus: true - уже есть
    
    
    // ЯВНО объявляем что принимаем клавиши
    Keys.enabled: true
    Keys.forwardTo: []  // Никому не передаём
    
    // ЛЕВАЯ КЛАВИША - переключение табов
    Keys.onLeftPressed: {
        if (currentIndex > 0) {
            currentIndex--;
            // Можно сразу переключить страницу
            if (collectionGamesLoader.active) collectionGamesLoader.active = false
            currentPage = currentIndex;
        }
        event.accepted = true;  // ← ВАЖНО!
    }
    
    // ПРАВАЯ КЛАВИША - переключение табов  
    Keys.onRightPressed: {
        if (currentIndex < 3) {
            currentIndex++;
            if (collectionGamesLoader.active) collectionGamesLoader.active = false
            currentPage = currentIndex;
        }
        event.accepted = true;  // ← ВАЖНО!
    }
    
    // ENTER - подтверждение выбора (оставляем как было)
    Keys.onReturnPressed: {
        if (collectionGamesLoader.active) collectionGamesLoader.active = false
        currentPage = currentIndex
        event.accepted = true
    }

        Repeater {
            model: [
                { name: "All Games" },
                { name: "Favorites" },
                { name: "Collections" },
                { name: "Other" }
            ]

            delegate: Rectangle {
                width: 240
                height: 74
                radius: 40
                color: {
                    if (root.focusZone === 1 && index === currentPage) {
                        return "white" // ФОКУС НА КНОПКАХ + АКТИВНАЯ ВКЛАДКА
                    } else if (index === currentPage) {
                        return "#31343B" // АКТИВНАЯ ВКЛАДКА БЕЗ ФОКУСА
                    } else {
                        return "transparent" // НЕАКТИВНАЯ ВКЛАДКА
                    }
                }
                border.width: 0
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    font.pixelSize: 25
                    font.family: bold.name 
                    color: (root.focusZone === 1 && index === currentPage) ? "black" : "white"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (collectionGamesLoader.active) collectionGamesLoader.active = false
                        currentPage = index
                        root.goToZone(1) // ОСТАЕМСЯ В ВЕРХНЕЙ ЗОНЕ КНОПОК
                    }
                }
            }
        }
    }
} // ← ЗАКРЫВАЕМ topZone ЗДЕСЬ!

// ===============================
// === НИЖНЯЯ ЗОНА (КОНТЕНТ) ===
// ===============================
Loader {
    id: pageLoader
    y: topZone.y + topZone.height * 1.3     // Начало сразу под topZone
    width: parent.width
    height: parent.height - (topZone.y + topZone.height + bottomBar.height) // До верхней границы bottomBar
    sourceComponent: [
        pageAllGames,
        pageFavorites,
        pageCollections,  // ← заменили pageConsoles
        pageOther
    ][currentPage]
}

    // ============================================================================
// 1. PAGE ALL GAMES (ЭТАЛОН)
// ============================================================================
Component {
    id: pageAllGames
    FocusScope {
        width: parent.width
        height: parent.height
        property color flickableColor: "#0F1318"
        property alias gridView: gridView

        Rectangle {
            anchors.fill: parent
            color: flickableColor
            z: 1
            clip: false

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
                cellWidth: width / 5
                cellHeight: cellWidth * 0.6
                model: root.searchQuery === "" ? api.allGames : searchModel
                currentIndex: 0
                focus: false
                
                // === НАСТРОЙКИ СКРОЛЛА (ИДЕНТИЧНЫЕ ВЕЗДЕ) ===
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange

                highlightMoveDuration: 200

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        var columnsCount = Math.floor(width / cellWidth); // Считаем колонки динамически

                        if (event.key === Qt.Key_Left) {
                            if (currentIndex > 0) { currentIndex--; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Right) {
                            if (currentIndex < count - 1) { currentIndex++; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
                            if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; }
                            else { currentIndex -= columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Down || api.keys.isDetails(event)) {
                            if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (model.get(currentIndex) && model.get(currentIndex).launch) { model.get(currentIndex).launch(); }
                            event.accepted = true;
                        }
                    }
                }

                delegate: Item {
                    width: gridView.cellWidth 
                    height: width * 0.467
                    property bool hasImage: modelData.assets && (modelData.assets.steam)
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: hasImage ? "transparent" : "#555"                                           

                        Image {
                            id: gameImage
                            width: parent.width * 0.9
                            height: parent.height * 0.9
                            anchors.centerIn: parent
                            source: (modelData.assets && modelData.assets.steam) ? modelData.assets.steam : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: hasImage
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
                                source: modelData && modelData.assets.steam
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                            }
                            FastBlur {
                                anchors.fill: parent
                                anchors.margins: -20
                                source: blurSource
                                radius: 144
                                transparentBorder: true
                            }
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: modelData.title || ("Game " + (index + 1))
                            color: "white"
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            width: parent.width * 0.9
                            visible: !hasImage
                        }
                    } 
                    
                    Row {
                    anchors.left: parent.left
                    anchors.top: parent.top 
                    anchors.bottom: parent.bottom 
                    anchors.topMargin: 258
                    anchors.leftMargin: 23
                    anchors.verticalCenter: parent.verticalCenter
                    z: 800000
                    spacing: 17
                 
                    Text {
                        text: "L"
                        color: "#8C939B"
                        font.pixelSize: 30
                        font.family: icons.name
                        anchors.verticalCenter: parent.verticalCenter
                    }                  
                    Text {
    id: libraryText
    text: {
        var collectionName = "";
        // Ищем в какой коллекции находится игра
        for (var i = 0; i < api.collections.count; i++) {
            var coll = api.collections.get(i);
            for (var j = 0; j < coll.games.count; j++) {
                if (coll.games.get(j).title === modelData.title) {
                    collectionName = "From " + coll.name;
                    break;
                }
            }
            if (collectionName !== "") break;
        }
        return collectionName;
    }
    color: "#8C939B"
    font.pixelSize: 30
    font.family: bold.name
    anchors.verticalCenter: parent.verticalCenter
    width: parent.parent.width * 0.85
    elide: Text.ElideRight
    maximumLineCount: 1
}
                }

                    Rectangle {
                        id: highlightBorder
                        width: gameContainer.width * 0.93
                        height: gameContainer.height * 0.97
                        anchors.centerIn: parent
                        color: "transparent"
                        border.width: 4
                        border.color: "grey"
                        radius: 2
                        opacity: isFocused ? 1.0 : 0.0
                        visible: isFocused
                        z: 1000
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        SequentialAnimation {
                            id: appearAnim
                            running: isFocused
                            loops: 1
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "width"; to: gameContainer.width * 0.92 + 12; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "height"; to: gameContainer.height * 0.97 + 12; duration: 100; easing.type: Easing.OutBack }
                                ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
                                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "width"; to: gameContainer.width * 0.92; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "height"; to: gameContainer.height * 0.97; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 4; duration: 100; easing.type: Easing.OutBack }
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
                            if (!isFocused) {
                                gridView.currentIndex = index
                                gridView.forceActiveFocus()
                                root.goToZone(2)
                            } else {
                                if (modelData && modelData.launch) modelData.launch()
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

// ============================================================================
// 2. PAGE FAVORITES (ПОЛНАЯ КОПИЯ ALL GAMES)
// ============================================================================
Component {
    id: pageFavorites
    FocusScope {
        width: parent.width
        height: parent.height
        property color flickableColor: "#0F1318"
        property alias gridView: gridView

        Rectangle {
            anchors.fill: parent
            color: flickableColor
            z: 1
            clip: false

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
                cellWidth: width / 5
                cellHeight: cellWidth * 0.6
                model: {
                    var source = root.searchQuery === "" ? api.allGames : searchModel
                    var favorites = []
                    for (var i = 0; i < source.count; i++) {
                        var game = source.get(i)
                        if (game.favorite) favorites.push(game)
                    }
                    return favorites
                }
                currentIndex: 0
                focus: false
                
                // === НАСТРОЙКИ СКРОЛЛА (ИДЕНТИЧНЫЕ ВЕЗДЕ) ===
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange
                highlightMoveDuration: 200

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        var columnsCount = Math.floor(width / cellWidth);
                        if (event.key === Qt.Key_Left) { if (currentIndex > 0) currentIndex--; event.accepted = true; }
                        else if (event.key === Qt.Key_Right) { if (currentIndex < count - 1) currentIndex++; event.accepted = true; }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) { if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; } else { currentIndex -= columnsCount; event.accepted = true; } }
                        else if (event.key === Qt.Key_Down || api.keys.isDetails(event)) { if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; } }
                        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                             // Обращаемся к массиву, так как model здесь - массив JS
                            if (model[currentIndex] && model[currentIndex].launch) { model[currentIndex].launch(); }
                            event.accepted = true;
                        }
                    }
                }

                // === DELEGATE (ПОЛНАЯ КОПИЯ) ===
                delegate: Item {
                    width: gridView.cellWidth 
                    height: width * 0.467
                    property bool hasImage: modelData.assets && (modelData.assets.steam)
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: hasImage ? "transparent" : "#555"                                           

                        Image {
                            id: gameImage
                            width: parent.width * 0.9
                            height: parent.height * 0.9
                            anchors.centerIn: parent
                            source: (modelData.assets && modelData.assets.steam) ? modelData.assets.steam : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: hasImage
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
                                source: modelData && modelData.assets.steam
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                            }
                            FastBlur {
                                anchors.fill: parent
                                anchors.margins: -20
                                source: blurSource
                                radius: 144
                                transparentBorder: true
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.title || ("Game " + (index + 1))
                            color: "white"
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            width: parent.width * 0.9
                            visible: !hasImage
                        }
                    } 
                    
                    Row {
                    anchors.left: parent.left
                    anchors.top: parent.top 
                    anchors.bottom: parent.bottom 
                    anchors.topMargin: 258
                    anchors.leftMargin: 23
                    anchors.verticalCenter: parent.verticalCenter
                    z: 800000
                    spacing: 17
                 
                    Text {
                        text: "L"
                        color: "#8C939B"
                        font.pixelSize: 30
                        font.family: icons.name
                        anchors.verticalCenter: parent.verticalCenter
                    }                  
                    Text {
    id: libraryText
    text: {
        var collectionName = "";
        // Ищем в какой коллекции находится игра
        for (var i = 0; i < api.collections.count; i++) {
            var coll = api.collections.get(i);
            for (var j = 0; j < coll.games.count; j++) {
                if (coll.games.get(j).title === modelData.title) {
                    collectionName = "From " + coll.name;
                    break;
                }
            }
            if (collectionName !== "") break;
        }
        return collectionName;
    }
    color: "#8C939B"
    font.pixelSize: 30
    font.family: bold.name
    anchors.verticalCenter: parent.verticalCenter
    width: parent.parent.width * 0.85
    elide: Text.ElideRight
    maximumLineCount: 1
}
                }

                    Rectangle {
                        id: highlightBorder
                        width: gameContainer.width * 0.93
                        height: gameContainer.height * 0.97
                        anchors.centerIn: parent
                        color: "transparent"
                        border.width: 4
                        border.color: "grey"
                        radius: 2
                        opacity: isFocused ? 1.0 : 0.0
                        visible: isFocused
                        z: 1000
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        SequentialAnimation {
                            running: isFocused
                            loops: 1
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "width"; to: gameContainer.width * 0.92 + 12; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "height"; to: gameContainer.height * 0.97 + 12; duration: 100; easing.type: Easing.OutBack }
                                ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
                                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "width"; to: gameContainer.width * 0.92; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "height"; to: gameContainer.height * 0.97; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 4; duration: 100; easing.type: Easing.OutBack }
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
                            if (!isFocused) {
                                gridView.currentIndex = index
                                gridView.forceActiveFocus()
                                root.goToZone(2)
                            } else {
                                if (modelData && modelData.launch) modelData.launch()
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

// ============================================================================
// 3. PAGE COLLECTIONS (Свой стиль, без изменений)
// ============================================================================
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

                clip: false
                cellWidth: width / 6
                cellHeight: cellWidth * 1
                model: api.collections
                currentIndex: 0
                focus: false

                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange

                highlightMoveDuration: 200

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        var columnsCount = Math.floor(width / cellWidth);
                        if (event.key === Qt.Key_Left) { if (currentIndex > 0) { currentIndex--; event.accepted = true; } }
                        else if (event.key === Qt.Key_Right) { if (currentIndex < count - 1) { currentIndex++; event.accepted = true; } }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) { if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; } else { currentIndex -= columnsCount; event.accepted = true; } }
                        else if (event.key === Qt.Key_Down) { if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; } }
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
                    property bool hasImage: modelData.assets && (modelData.assets.boxFront || modelData.assets.poster)
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

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name || ("Collection " + (index + 1))
                            color: "white"
                            font.pixelSize: 20
                            font.family: bold.name
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            width: parent.width * 0.9
                            visible: !hasImage
                        }
                    }

                    Rectangle {
                        id: highlightBorderCollection
                        width: gridCollections.cellWidth * 0.93
                        height: gridCollections.cellHeight * 0.93
                        anchors.centerIn: parent
                        color: "transparent"
                        border.width: 4
                        border.color: "grey"
                        radius: 2
                        opacity: isFocused ? 1.0 : 0.0
                        z: 1000
                        scale: isFocused ? 1.028 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        SequentialAnimation {
                            running: isFocused
                            loops: 1
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorderCollection; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorderCollection; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorderCollection; property: "width"; to: gridCollections.cellWidth * 0.93 + 12; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorderCollection; property: "height"; to: gridCollections.cellHeight * 0.93 + 12; duration: 100; easing.type: Easing.OutBack }
                                ColorAnimation { target: highlightBorderCollection; property: "border.color"; to: "white"; duration: 100 }
                                NumberAnimation { target: highlightBorderCollection; property: "opacity"; to: 0.5; duration: 100 }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorderCollection; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorderCollection; property: "width"; to: gridCollections.cellWidth * 0.93; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorderCollection; property: "height"; to: gridCollections.cellHeight * 0.93; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorderCollection; property: "border.width"; to: 4; duration: 100; easing.type: Easing.OutBack }
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
                            if (!isFocused) {
                                gridCollections.currentIndex = index
                                gridCollections.forceActiveFocus()
                                root.goToZone(2)
                            } else {
                                collectionGamesLoader.collection = modelData
                                collectionGamesLoader.active = true
                            }
                        }
                    }
                }
            }
        }
    }
}

// ============================================================================
// 4. LOADER (ВНУТРИ - ПОЛНАЯ КОПИЯ ALL GAMES)
// ============================================================================
Loader {
    id: collectionGamesLoader
    y: topZone.y + topZone.height
    width: parent.width
    height: parent.height - (topZone.y + topZone.height + bottomBar.height)
    active: false
    property var collection
    
    sourceComponent: FocusScope {
        width: parent.width
        height: parent.height
        property color flickableColor: "#0F1318"
        property alias gridView: gridView

        Rectangle {
            anchors.fill: parent
            color: flickableColor
            z: 1
            clip: false

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
                cellWidth: width / 5
                cellHeight: cellWidth * 0.6
                
                // *** ЕДИНСТВЕННОЕ ИЗМЕНЕНИЕ: MODEL ***
                model: {
                    if (root.searchQuery === "") {
                        return collectionGamesLoader.collection ? collectionGamesLoader.collection.games : null
                    } else {
                        var collectionGames = collectionGamesLoader.collection ? collectionGamesLoader.collection.games : null
                        if (!collectionGames) return null
                        var filtered = []
                        for (var i = 0; i < collectionGames.count; i++) {
                            var game = collectionGames.get(i)
                            if (game.title && game.title.toLowerCase().includes(root.searchQuery.toLowerCase())) {
                                filtered.push(game)
                            }
                        }
                        return filtered
                    }
                }
                
                currentIndex: 0
                focus: false
                
                // === НАСТРОЙКИ СКРОЛЛА (КОПИЯ) ===
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange

                highlightMoveDuration: 200

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        var columnsCount = Math.floor(width / cellWidth);
                        if (event.key === Qt.Key_Left) { if (currentIndex > 0) { currentIndex--; event.accepted = true; } }
                        else if (event.key === Qt.Key_Right) { if (currentIndex < count - 1) { currentIndex++; event.accepted = true; } }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) { if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; } else { currentIndex -= columnsCount; event.accepted = true; } }
                        else if (event.key === Qt.Key_Down || api.keys.isDetails(event)) { if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; } }
                        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (model.get(currentIndex) && model.get(currentIndex).launch) { model.get(currentIndex).launch(); }
                            event.accepted = true;
                        }
                    }
                }

                // === DELEGATE (ПОЛНАЯ КОПИЯ) ===
                delegate: Item {
                    width: gridView.cellWidth 
                    height: width * 0.467
                    property bool hasImage: modelData.assets && (modelData.assets.steam)
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: hasImage ? "transparent" : "#555"                                           

                        Image {
                            id: gameImage
                            width: parent.width * 0.9
                            height: parent.height * 0.9
                            anchors.centerIn: parent
                            source: (modelData.assets && modelData.assets.steam) ? modelData.assets.steam : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: hasImage
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
                                source: modelData && modelData.assets.steam
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                            }
                            FastBlur {
                                anchors.fill: parent
                                anchors.margins: -20
                                source: blurSource
                                radius: 144
                                transparentBorder: true
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.title || ("Game " + (index + 1))
                            color: "white"
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            width: parent.width * 0.9
                            visible: !hasImage
                        }
                    } 
                    
                    Row {
                    anchors.left: parent.left
                    anchors.top: parent.top 
                    anchors.bottom: parent.bottom 
                    anchors.topMargin: 258
                    anchors.leftMargin: 23
                    anchors.verticalCenter: parent.verticalCenter
                    z: 800000
                    spacing: 17
                 
                    Text {
                        text: "L"
                        color: "#8C939B"
                        font.pixelSize: 30
                        font.family: icons.name
                        anchors.verticalCenter: parent.verticalCenter
                    }                  
                    Text {
    id: libraryText
    text: {
        var collectionName = "";
        // Ищем в какой коллекции находится игра
        for (var i = 0; i < api.collections.count; i++) {
            var coll = api.collections.get(i);
            for (var j = 0; j < coll.games.count; j++) {
                if (coll.games.get(j).title === modelData.title) {
                    collectionName = "From " + coll.name;
                    break;
                }
            }
            if (collectionName !== "") break;
        }
        return collectionName;
    }
    color: "#8C939B"
    font.pixelSize: 30
    font.family: bold.name
    anchors.verticalCenter: parent.verticalCenter
    width: parent.parent.width * 0.85
    elide: Text.ElideRight
    maximumLineCount: 1
}
                }

                    Rectangle {
                        id: highlightBorder
                        width: gameContainer.width * 0.93
                        height: gameContainer.height * 0.97
                        anchors.centerIn: parent
                        color: "transparent"
                        border.width: 4
                        border.color: "grey"
                        radius: 2
                        opacity: isFocused ? 1.0 : 0.0
                        visible: isFocused
                        z: 1000
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        SequentialAnimation {
                            running: isFocused
                            loops: 1
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "width"; to: gameContainer.width * 0.92 + 12; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "height"; to: gameContainer.height * 0.97 + 12; duration: 100; easing.type: Easing.OutBack }
                                ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
                                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "width"; to: gameContainer.width * 0.92; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "height"; to: gameContainer.height * 0.97; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 4; duration: 100; easing.type: Easing.OutBack }
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
                            if (!isFocused) {
                                gridView.currentIndex = index
                                gridView.forceActiveFocus()
                                root.goToZone(2)
                            } else {
                                if (modelData && modelData.launch) modelData.launch()
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

// ============================================================================
// 5. PAGE OTHER (ПОЛНАЯ КОПИЯ ALL GAMES)
// ============================================================================
Component {
    id: pageOther
    FocusScope {
        width: parent.width
        height: parent.height
        property color flickableColor: "#0F1318"
        property alias gridView: gridView

        Rectangle {
            anchors.fill: parent
            color: flickableColor
            z: 1
            clip: false

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
                cellWidth: width / 5
                cellHeight: cellWidth * 0.6
                model: root.searchQuery === "" ? api.allGames : searchModel // Используем базовый поиск
                currentIndex: 0
                focus: false
                
                // === НАСТРОЙКИ СКРОЛЛА (КОПИЯ) ===
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange
                highlightMoveDuration: 200

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        var columnsCount = Math.floor(width / cellWidth);
                        if (event.key === Qt.Key_Left) { if (currentIndex > 0) { currentIndex--; event.accepted = true; } }
                        else if (event.key === Qt.Key_Right) { if (currentIndex < count - 1) { currentIndex++; event.accepted = true; } }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) { if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; } else { currentIndex -= columnsCount; event.accepted = true; } }
                        else if (event.key === Qt.Key_Down || api.keys.isDetails(event)) { if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; } }
                        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (model.get(currentIndex) && model.get(currentIndex).launch) { model.get(currentIndex).launch(); }
                            event.accepted = true;
                        }
                    }
                }

                // === DELEGATE (ПОЛНАЯ КОПИЯ) ===
                delegate: Item {
                    width: gridView.cellWidth 
                    height: width * 0.467
                    property bool hasImage: modelData.assets && (modelData.assets.steam)
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: hasImage ? "transparent" : "#555"                                           

                        Image {
                            id: gameImage
                            width: parent.width * 0.9
                            height: parent.height * 0.9
                            anchors.centerIn: parent
                            source: (modelData.assets && modelData.assets.steam) ? modelData.assets.steam : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: hasImage
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
                                source: modelData && modelData.assets.steam
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                            }
                            FastBlur {
                                anchors.fill: parent
                                anchors.margins: -20
                                source: blurSource
                                radius: 144
                                transparentBorder: true
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.title || ("Game " + (index + 1))
                            color: "white"
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            width: parent.width * 0.9
                            visible: !hasImage
                        }
                    } 
                    
                    Row {
                    anchors.left: parent.left
                    anchors.top: parent.top 
                    anchors.bottom: parent.bottom 
                    anchors.topMargin: 258
                    anchors.leftMargin: 23
                    anchors.verticalCenter: parent.verticalCenter
                    z: 800000
                    spacing: 17
                 
                    Text {
                        text: "L"
                        color: "#8C939B"
                        font.pixelSize: 30
                        font.family: icons.name
                        anchors.verticalCenter: parent.verticalCenter
                    }                  
                    Text {
    id: libraryText
    text: {
        var collectionName = "";
        // Ищем в какой коллекции находится игра
        for (var i = 0; i < api.collections.count; i++) {
            var coll = api.collections.get(i);
            for (var j = 0; j < coll.games.count; j++) {
                if (coll.games.get(j).title === modelData.title) {
                    collectionName = "From " + coll.name;
                    break;
                }
            }
            if (collectionName !== "") break;
        }
        return collectionName;
    }
    color: "#8C939B"
    font.pixelSize: 30
    font.family: bold.name
    anchors.verticalCenter: parent.verticalCenter
    width: parent.parent.width * 0.85
    elide: Text.ElideRight
    maximumLineCount: 1
}
                }

                    Rectangle {
                        id: highlightBorder
                        width: gameContainer.width * 0.93
                        height: gameContainer.height * 0.97
                        anchors.centerIn: parent
                        color: "transparent"
                        border.width: 4
                        border.color: "grey"
                        radius: 2
                        opacity: isFocused ? 1.0 : 0.0
                        visible: isFocused
                        z: 1000
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        SequentialAnimation {
                            running: isFocused
                            loops: 1
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "width"; to: gameContainer.width * 0.92 + 12; duration: 100; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "height"; to: gameContainer.height * 0.97 + 12; duration: 100; easing.type: Easing.OutBack }
                                ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
                                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "width"; to: gameContainer.width * 0.92; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "height"; to: gameContainer.height * 0.97; duration: 100; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 4; duration: 100; easing.type: Easing.OutBack }
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
                            if (!isFocused) {
                                gridView.currentIndex = index
                                gridView.forceActiveFocus()
                                root.goToZone(2)
                            } else {
                                if (modelData && modelData.launch) modelData.launch()
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
}
    

        /* ================= TOP BAR ================= */
    Rectangle {
        id: topBar
        anchors.left: root.left   
        anchors.right: root.right 
        height: root.topH
        color: "transparent"
        z: 10000

        // Фоновая подложка бара
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

            // Внутри Row { id: topButtonsNames ... }
// Внутри Row { id: topButtonsNames ... }
Keys.onPressed: {
    // Если мы в поиске и он АКТИВЕН (фокус на нем)
    if (currentIndex === 0 && root.focusZone === 0) {
        if (root.keyboardOpen) {
            // Если клава открыта - стрелки двигают курсор
            if (event.key === Qt.Key_Left && keyboardContainer.cursorPosition > 0) {
                keyboardContainer.cursorPosition--;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right && keyboardContainer.cursorPosition < root.searchQuery.length) {
                keyboardContainer.cursorPosition++;
                event.accepted = true;
            }
        } else {
            // Если клава закрыта - стрелки ПЕРЕКЛЮЧАЮТ кнопки в баре
            if (event.key === Qt.Key_Right) { currentIndex = 1; event.accepted = true; }
        }
        
        if (api.keys.isAccept(event)) { root.openKeyboard(); event.accepted = true; }
    } 
    // Навигация по остальным кнопкам (Сеть, Батарея и т.д.)
    else if (root.focusZone === 0) {
        if (event.key === Qt.Key_Left) { 
            currentIndex--; 
            event.accepted = true; 
        } else if (event.key === Qt.Key_Right && currentIndex < 3) { 
            currentIndex++; 
            event.accepted = true; 
        }
    }
}


            // ===== 0. SEARCH =====
            Rectangle {
                id: topBtnSearch
                // Авто-ширина: занимает всё место, кроме остальных кнопок
                width: topBar.width - (topBtnNet.width + topBarBattery.width + topBtnClock.width + topBtnUser.width + (topButtonsNames.spacing * 4) + (topButtonsNames.anchors.rightMargin * 2))
                height: root.topH
                color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                
                // Иконка Лупы
                Text {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: "¿"
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "black" : "white"
                    
                    readonly property real posRight: topBtnSearch.width - 50
                    readonly property real posLeft: 15
                    
                    // Позиция зависит от фокуса
                    x: posLeft 
                }
  
                // Текст поиска в верхнем баре
Text {
    id: searchText
    anchors.verticalCenter: parent.verticalCenter
    x: 15 + 50
    // Текст: подсказка видна только если поисковый запрос пуст И клавиатура закрыта
    text: (root.searchQuery === "" && !root.keyboardOpen) ? "Search games in your Library..." : root.searchQuery
    font.pixelSize: 30
    font.family: bold.name
    color: (root.searchQuery === "" && !root.keyboardOpen) ? "#8C939B" : ((topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "black" : "white")

    // Мигающий курсор
    Rectangle {
        id: cursorBar
        width: 3; height: 35
        color: parent.color
        visible: root.keyboardOpen && topButtonsNames.currentIndex === 0 && root.focusZone === 0
        x: cursorWidthProvider.width // Текст до позиции курсора
        anchors.verticalCenter: parent.verticalCenter
        
        SequentialAnimation on opacity {
            running: cursorBar.visible; loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0; duration: 500 }
            NumberAnimation { from: 0; to: 1; duration: 500 }
        }
    }
    Text { id: cursorWidthProvider; visible: false; text: root.searchQuery.substring(0, keyboardContainer.cursorPosition); font: parent.font }
}


                MouseArea { 
    anchors.fill: parent
    onClicked: {
        if (root.focusZone === 0 && topButtonsNames.currentIndex === 0) {
            openKeyboard(); // Второе нажатие открывает клавиатуру
        } else {
            root.goToZone(0);
            topButtonsNames.currentIndex = 0;
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
                    text: "o"
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsNames.currentIndex === 1 && root.focusZone === 0) ? "black" : "white"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: {
                        root.goToZone(0)
                        topButtonsNames.currentIndex = 1
                    }
                }
            }
            
            // ===== 2. BATTERY =====
            Item {
                id: topBarBattery
                width: 170
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
                    onClicked: {
                        root.goToZone(0)
                        topButtonsNames.currentIndex = 2
                    }
                }
            }

            // ===== CLOCK (Static) =====
            Rectangle {
                id: topBtnClock
                width: 200; height: root.topH
                color: "transparent"

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), "hh:mm AP")
                    font.pixelSize: 35
                    font.family: bold.name
                    color: "white"
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm AP")
                }                
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
                    source: "../assets/logo/logo.jpg"
                    fillMode: Image.PreserveAspectFit
                }

                Rectangle {
                    anchors { top: userImage.top; bottom: userImage.bottom; right: userImage.right }
                    width: 10
                    color: "#00BFFF"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: {
                        root.goToZone(0)
                        topButtonsNames.currentIndex = 3
                    }
                }
            }
        }
    }



    /* ================= BOTTOM BAR ================= */
Rectangle {
    id: bottomBar
    width: parent.width
    height: topH
    color: "black"
    z: 10000000
    anchors.bottom: parent.bottom

    // ====== Левая кнопка MENU ======
    Rectangle {
        id: btnMenu
        width: 180; height: parent.height
        anchors.left: parent.left
        anchors.leftMargin: 35
        color: "transparent"

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text { text: ":"; font.family: icons.name; font.pixelSize: 54; color: "white" }
            Text { text: "MENU"; font.family: bold.name; font.pixelSize: 28; color: "white";y:parent.height *0.21 }
        }

        MouseArea { anchors.fill: parent; onClicked: leftBar.toggle() }MouseArea {
    anchors.fill: parent
    onClicked: {
        // Открываем/закрываем меню
        leftBar.toggle()

        // Сразу выставляем фокус на кнопку с индексом 0
        leftBar.currentIndex = 1
        leftBar.updateFocus()
    }
}
    }

    // ====== Правая часть (подсказки + BACK) ======
    Row {
        id: rightGroup
        anchors.right: parent.right
        anchors.rightMargin: 35
        anchors.verticalCenter: parent.verticalCenter
        spacing: 38

        // --- Подсказка OPTIONS ---
        Row {
            spacing: 18
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "X"; font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025 }
            Text { text: "OPTIONS"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23 }
        }

        // --- Подсказка SELECT ---
        Row {
            spacing: 18
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "A"; font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025}
            Text { text: "SELECT"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23}
        }

        // --- Кнопка BACK ---
        Rectangle {
            id: btnBack
            width: 140; height: parent.height
            color: "transparent"
            Row {
                anchors.centerIn: parent
                spacing: 18
                Text { text: "B"; font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025}
                Text { text: "BACK"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23 }
            }
            MouseArea { 
anchors.fill: parent
onClicked: 
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
    }
}

// ФОН
    Rectangle {
        id: dimLayer
        anchors.fill: parent
        color: "black"
        opacity: leftBar.isOpen ? 0.7 : 0.0
        visible: leftBar.visible
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

        MouseArea {
            anchors.fill: parent
            onClicked: leftBar.toggle()
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
    
   
    // Исправленный блок внутри leftBar
Keys.onPressed: {
    if (leftBar.isOpen && leftBar.focus) {
        if (event.key === Qt.Key_Up) {
            // НОВОЕ: Убираем переход на topbar. Фокус остается внутри меню
            if (currentIndex > 0) {
                currentIndex--
                updateFocus()
                event.accepted = true
                ////sNav.stop();
            ////sNav.play();
            } else {
                // Если уже на верхней кнопке - остаемся на ней
                // Никакого перехода на topbar
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Down) {
            if (currentIndex < buttons.length - 1) {
                currentIndex++
                updateFocus()
                event.accepted = true
                ////sNav.stop();
            ////sNav.play();
            } else {
                // Если уже на нижней кнопке - остаемся на ней
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
            theme.openPage(currentIndex)
            toggle()
            event.accepted = true
        }
        else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
            toggle()
            focusTimer.start()
            event.accepted = true
        }
        else {
            // Блокируем все другие клавиши, чтобы не было случайных переходов
            event.accepted = true
        }
    }
}
    
    // ПАНЕЛЬ МЕНЮ
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

        Column {
            id: buttonColumn
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 0
                topMargin: parent.height * 0.11
            }
            spacing: 0
        }
    }

    // КОМПОНЕНТ КНОПКИ
    Component {
        id: menuButtonComponent

        FocusScope {
            id: buttonScope
            property string title: ""
            property int buttonIndex: 0
            width: menuPanel.width
            height: 106
            
            // СВОЙСТВО ДЛЯ ПРОВЕРКИ ФОКУСА
            property bool isFocused: activeFocus
            
            onIsFocusedChanged: {
                if (isFocused) {
                    bgColor = "#27303A"  // цвет при фокусе
                    textColor = "white"
                } else {
                    bgColor = "transparent"  // обычный цвет
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
                
                // ГОЛУБОЙ ПРЯМОУГОЛЬНИК - ТОЛЬКО ДЛЯ ТЕКУЩЕЙ СТРАНИЦЫ
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
    
    // 2. Закруглённая правая часть
    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        width: 27  // Ширина радиуса × 2
        color: "#1A9EFF"
        radius: 40  // ЛЮБОЙ радиус
    }
}
                
        Row {
    anchors.verticalCenter: parent.verticalCenter  // центр по вертикали
    anchors.left: parent.left                       // прижимаем к левому краю
    anchors.leftMargin: 50                         // отступ слева, можно менять
    spacing: 38                                // расстояние между иконкой и текстом

    // Иконка
    Text {
        text: icon
        font.family: icons.name
        font.pixelSize: Math.min(43, menuPanel.width / 7)
        color: "white"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    // Основной текст
    Text {
        text: title
        font.family: bold.name
        font.pixelSize: Math.min(43, menuPanel.width / 7)
        color: "white"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
}
}

            MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: {
    console.log("Нажатие на кнопку:", buttonIndex)

    if (leftBar.currentIndex === buttonIndex) {
        // Второе нажатие — запускаем страницу
        theme.openPage(buttonIndex)
        leftBar.toggle()
    } else {
        // Первое нажатие — переводим фокус
        leftBar.currentIndex = buttonIndex
        leftBar.updateFocus()
    }
}
}
        }
    }

    // СОЗДАЕМ КНОПКИ
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
        
        // Устанавливаем начальный фокус
        currentIndex = 1
        updateFocus()
    }

    // ОБНОВЛЕНИЕ ФОКУСА
    function updateFocus() {
        if (currentIndex >= 0 && currentIndex < buttons.length) {
            buttons[currentIndex].forceActiveFocus()
        }
    }

    // ОТКРЫТИЕ/ЗАКРЫТИЕ МЕНЮ
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

    property int currentButtonIndex: 0
    property var buttons: [playButton, favoriteButton, propertiesButton, cancelButton]

    // ФОН (полупрозрачный оверлей)
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.5       
    }
    
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // Пусто - просто блокирует
        }
    }

    // Серый прямоугольник посередине
    Rectangle {
        width: 550
        height: 450
        anchors.centerIn: parent
        color: "#181B20"
        
        // Название игры сверху
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
        }
        
        // Контейнер для кнопок
        Column {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            spacing: 0
            
            // ===== 1. КНОПКА "ИГРАТЬ" =====
            Rectangle {
                id: playButton
                width: parent.width
                height: parent.height / 4
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
                        id: playText
                        text: "Play"
                        color: optionsMenu.currentButtonIndex === 0 ? "white" : "white"
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
                        } else {
                            if (currentFocusedGame) {
                                currentFocusedGame.launch()
                                root.toggleOptionsMenu()
                            }
                        }
                    }
                }
            }
            
            // ===== 2. КНОПКА "ДОБАВИТЬ В ИЗБРАННОЕ" =====
            Rectangle {
                id: favoriteButton
                width: parent.width
                height: parent.height / 4
                color: optionsMenu.currentButtonIndex === 1 ? "white" : "transparent"
                
                Text {
                    id: favoriteText
                    text: {
                        if (currentFocusedGame) {
                            return currentFocusedGame.favorite ? 
                                "   Delete from favorites" : "   Add to favorites"
                        }
                        return "   Add to favorites"
                    }
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
                        } else {
                            if (currentFocusedGame) {
                                currentFocusedGame.favorite = !currentFocusedGame.favorite
                                root.toggleOptionsMenu()
                            }
                        }
                    }
                }
            }
            
            // ===== 3. КНОПКА "СВОЙСТВА" =====
            Rectangle {
                id: propertiesButton
                width: parent.width
                height: parent.height / 4
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
                        } else {
                            // Properties - ничего не делаем
                        }
                    }
                }
            }
            
            // ===== 4. КНОПКА "ОТМЕНА" =====
            Rectangle {
                id: cancelButton
                width: parent.width
                height: parent.height / 4
                color: optionsMenu.currentButtonIndex === 3 ? "white" : "transparent"
                
                Text {
                    text: "   Cancel"
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
                        } else {
                            root.toggleOptionsMenu()
                        }
                    }
                }
            }
        }
    }
    // ОБРАБОТКА КЛАВИШ
    Keys.onPressed: {
        if (optionsMenuVisible && optionsMenu.focus) {
            if (event.key === Qt.Key_Up) {
                // Навигация вверх
                if (currentButtonIndex > 0) {
                    currentButtonIndex--
                }
                event.accepted = true
            }
            else if (event.key === Qt.Key_Down) {
                // Навигация вниз
                if (currentButtonIndex < 3) {
                    currentButtonIndex++
                }
                event.accepted = true
            }
            else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                // Активация выбранной кнопки
                if (currentButtonIndex === 0) {
                    // Play
                    if (currentFocusedGame) {
                        currentFocusedGame.launch()
                        root.toggleOptionsMenu()
                    }
                } else if (currentButtonIndex === 1) {
                    // Favorite
                    if (currentFocusedGame) {
                        currentFocusedGame.favorite = !currentFocusedGame.favorite
                        root.toggleOptionsMenu()
                    }
                } else if (currentButtonIndex === 2) {
                    // Properties - ничего не делаем
                } else if (currentButtonIndex === 3) {
                    // Cancel - закрываем меню
                    root.toggleOptionsMenu()
                }
                event.accepted = true
            }
            else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
                // Нажатие B/Back - закрываем меню
                root.toggleOptionsMenu()
                event.accepted = true
            }
        }
    }
    
    // При открытии устанавливаем фокус на первую кнопку
    onVisibleChanged: {
        if (visible) {
            currentButtonIndex = 0
            forceActiveFocus() // Важно: берем фокус при открытии
        }
    }
}


// ===============================
// === КЛАВИАТУРА STEAM DECK STYLE ===
// ===============================
FocusScope {
    id: keyboardContainer
    anchors.fill: parent
    visible: keyboardOpen
    focus: keyboardOpen
    z: 10000001

    property int r: 2 
    property int c: 5 
    property bool isCaps: false
    property int cursorPosition: 0

    // Зона закрытия кликом
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.keyboardOpen = false;
            root.goToZone(2); 
        }
    }

    function processInput(v) {
        if (!v || v === "") return;
        if (v === "Done") {
            root.keyboardOpen = false;
            root.goToZone(2);
            return;
        }
        
        var cur = root.searchQuery;
        if (v === "caps") {
            isCaps = !isCaps;
        } else if (v === "backspace") {
            if (cursorPosition > 0) {
                root.searchQuery = cur.substring(0, cursorPosition - 1) + cur.substring(cursorPosition);
                cursorPosition--;
            }
        } else if (v === "left") {
            if (cursorPosition > 0) cursorPosition--;
        } else if (v === "right") {
            if (cursorPosition < cur.length) cursorPosition++;
        } else {
            var letter = (v.length === 1 && isCaps) ? v.toUpperCase() : v;
            root.searchQuery = cur.substring(0, cursorPosition) + letter + cur.substring(cursorPosition);
            cursorPosition += letter.length;
        }
    }

    Rectangle {
        id: kbPanel
        width: parent.width; height: 405; color: "#22262F"; anchors.bottom: parent.bottom
        
        MouseArea { anchors.fill: parent; onClicked: { /* стоп клик */ } }

        Column {
            anchors.fill: parent; anchors.margins: 5; spacing: 4
            Repeater {
                model: [
                    {row:0, wSum:15, keys:[{l:"`",v:"`"},{l:"1",v:"1"},{l:"2",v:"2"},{l:"3",v:"3"},{l:"4",v:"4"},{l:"5",v:"5"},{l:"6",v:"6"},{l:"7",v:"7"},{l:"8",v:"8"},{l:"9",v:"9"},{l:"0",v:"0"},{l:"-",v:"-"},{l:"=",v:"="},{l:"X",v:"backspace",w:2,isBS:true,isSpec:true}]},
                    {row:1, wSum:15, keys:[{l:"Tab",v:"   ",w:1.5,isSpec:true},{l:"Q",v:"q"},{l:"W",v:"w"},{l:"E",v:"e"},{l:"R",v:"r"},{l:"T",v:"t"},{l:"Y",v:"y"},{l:"U",v:"u"},{l:"I",v:"i"},{l:"O",v:"o"},{l:"P",v:"p"},{l:"[",v:"["},{l:"]",v:"]"},{l:"\\",v:"\\",w:1.5}]},
                    {row:2, wSum:15, keys:[{l:"Caps",v:"caps",w:1.8,isSpec:true},{l:"A",v:"a"},{l:"S",v:"s"},{l:"D",v:"d"},{l:"F",v:"f"},{l:"G",v:"g"},{l:"H",v:"h"},{l:"J",v:"j"},{l:"K",v:"k"},{l:"L",v:"l"},{l:";",v:";"},{l:"'",v:"'"},{l:"Enter",v:"Done",w:2.2,c:"#1A9EFF",isSpec:true}]},
                    {row:3, wSum:15, keys:[{l:"Shift",v:"caps",w:2.5,isSpec:true},{l:"Z",v:"z"},{l:"X",v:"x"},{l:"C",v:"c"},{l:"V",v:"v"},{l:"B",v:"b"},{l:"N",v:"n"},{l:"M",v:"m"},{l:",",v:","},{l:".",v:"."},{l:"/",v:"/"},{l:"Shift",v:"caps",w:2.5,isSpec:true}]},
                    {row:4, wSum:13.1, keys:[{l:"☺",v:"",w:1.2,isSpec:true},{l:" ",v:" ",w:6.5},{l:"🌐",v:"",w:1.2,isSpec:true},{l:"<",v:"left",w:1.2,isSpec:true},{l:">",v:"right",w:1.2,isSpec:true},{l:"Hide",v:"Done",w:1.8,isSpec:true}]}
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
                            color: (keyboardContainer.r === parent.rowIndex && keyboardContainer.c === index) ? "white" : (modelData.isSpec ? "black" : "#0F1318")
                            
                            MouseArea { 
                                anchors.fill: parent
                                onClicked: {
                                    keyboardContainer.r = parent.parent.rowIndex;
                                    keyboardContainer.c = index;
                                    keyboardContainer.processInput(modelData.v);
                                }
                            }

                            Item {
    anchors.fill: parent
    
    // 1. Space (только иконка Y справа)
    Text {
        id: spaceIcon
        font.family: icons.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.v === " "
        
        font.pixelSize: 40
        text: "Y"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 20
    }
    
    // 2. Backspace (иконка слева, текст справа)
    Text {
        id: backspaceIcon
        font.family: icons.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.v === "backspace"
        
        font.pixelSize: 40
        text: "X"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 15
    }
    
    Text {
        id: backspaceText
        font.family: bold.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.v === "backspace"
        
        font.pixelSize: 22
        text: "Backspace"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 15
        width: Math.min(implicitWidth, parent.width - anchors.leftMargin - 15)
        elide: Text.ElideRight
    }
    
    // 3. Enter (иконка слева, текст справа)
    Text {
        id: enterIcon
        font.family: icons.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.l === "Enter"
        
        font.pixelSize: 45
        text: ">"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 15
    }
    
    Text {
        id: enterText
        font.family: bold.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.l === "Enter"
        
        font.pixelSize: 26
        text: "Enter"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 15
        width: Math.min(implicitWidth, parent.width - anchors.leftMargin - 15)
        elide: Text.ElideRight
    }
    
    // 4. Hide (иконка слева, текст справа)
    Text {
        id: hideIcon
        font.family: icons.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.l === "Hide" && modelData.v === "Done"
        
        font.pixelSize: 40
        text: "B"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 15
    }
    
    Text {
        id: hideText
        font.family: bold.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.l === "Hide" && modelData.v === "Done"
        
        font.pixelSize: 24
        text: "Hide"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 15
        width: Math.min(implicitWidth, parent.width - anchors.leftMargin - 15)
        elide: Text.ElideRight
    }
    
    // 5. Левый Shift (текст слева, иконка справа) - row 3, index 0
    Text {
        id: leftShiftText
        font.family: bold.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.l === "Shift" && index === 0
        
        font.pixelSize: 26
        text: "Shift"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 15
        width: Math.min(implicitWidth, parent.width * 0.5 - anchors.leftMargin)
        elide: Text.ElideRight
    }
    
    Text {
        id: leftShiftIcon
        font.family: icons.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.l === "Shift" && index === 0
        
        font.pixelSize: 45
        text: "<"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 15
    }
    
    // 6. Caps (текст слева, иконка справа)
    Text {
        id: capsText
        font.family: bold.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.v === "caps" && modelData.l !== "Shift"
        
        font.pixelSize: 26
        text: "Caps"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 15
        width: Math.min(implicitWidth, parent.width * 0.5 - anchors.leftMargin)
        elide: Text.ElideRight
    }
    
    Text {
        id: capsIcon
        font.family: icons.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.v === "caps" && modelData.l !== "Shift"
        
        font.pixelSize: 45
        text: "<"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 15
    }
    
    // 7. Правый Shift (row 3, index 11) - иконка слева, текст справа
    Text {
        id: rightShiftIcon
        font.family: icons.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.l === "Shift" && index === 11
        
        font.pixelSize: 45
        text: "<"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 15
    }
    
    Text {
        id: rightShiftText
        font.family: bold.name
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        visible: modelData.l === "Shift" && index === 11
        
        font.pixelSize: 26
        text: "Shift"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 15
        width: Math.min(implicitWidth, parent.width - anchors.leftMargin - 15)
        elide: Text.ElideRight
    }
    
    // 8. Кнопки со стрелками
    Text {
        id: arrowText
        font.family: bold.name
        font.pixelSize: 30
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        
        text: {
            if (modelData.v === "left") return "<";
            if (modelData.v === "right") return ">";
            return "";
        }
        
        visible: modelData.v === "left" || modelData.v === "right"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
    }
    
    // 9. Emoji и Globe
    Text {
        id: emojiGlobeText
        font.family: (modelData.l === "☺") ? icons.name : bold.name
        font.pixelSize: (modelData.l === "☺") ? 45:26
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        
        text: {
            if (modelData.l === "☺") return "😀";
            if (modelData.l === "🌐") return "Paste";
            return "";
        }
        
        visible: modelData.l === "☺" || modelData.l === "🌐"
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (modelData.l === "☺") ? 13:20
        anchors.horizontalCenter: parent.horizontalCenter
    }
    
    // 10. Tab и другие текстовые спецкнопки без иконки
    Text {
        id: specTextOnly
        font.family: bold.name
        font.pixelSize: 26
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        
        text: {
            if (modelData.l === "Tab") return "Tab";
            if (modelData.l === "   ") return "   ";
            return "";
        }
        
        visible: modelData.isSpec && !spaceIcon.visible && !backspaceIcon.visible && 
                !enterIcon.visible && !hideIcon.visible && !leftShiftText.visible &&
                !capsText.visible && !rightShiftIcon.visible && !arrowText.visible &&
                !emojiGlobeText.visible
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 15
    }
    
    // 11. Обычные кнопки (НЕ специальные)
    Text {
        id: normalKeyText
        font.family: bold.name
        font.pixelSize: 26
        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
        
        text: {
            if (modelData.isSpec) return "";
            if (modelData.v.length === 1) {
                return keyboardContainer.isCaps ? modelData.l.toUpperCase() : modelData.l.toLowerCase();
            }
            return modelData.l;
        }
        
        visible: !modelData.isSpec
        
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.3
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
                        }
                    }
                }
            }
        }
    }

    // Внутреннее управление клавишами
    Keys.onPressed: {
        var rowCounts = [14, 14, 13, 12, 6];
        if (api.keys.isLeft(event)) { if (c > 0) c--; event.accepted = true; }
        else if (api.keys.isRight(event)) { if (c < rowCounts[r] - 1) c++; event.accepted = true; }
        else if (api.keys.isUp(event)) { if (r > 0) { r--; c = Math.min(c, rowCounts[r] - 1); } event.accepted = true; }
        else if (api.keys.isDown(event)) { if (r < 4) { r++; c = Math.min(c, rowCounts[r] - 1); } event.accepted = true; }
        else if (api.keys.isDetails(event)) { processInput("backspace"); event.accepted = true; }
        else if (api.keys.isFilters(event)) { processInput(" "); event.accepted = true; }
        else if (api.keys.isNextPage(event)) { processInput("Done"); event.accepted = true; }
        else if (api.keys.isPrevPage(event)) { isCaps = !isCaps; event.accepted = true; }
        else if (api.keys.isCancel(event)) { processInput("Done"); event.accepted = true; }
        else if (api.keys.isAccept(event)) {
            var values = [
                ["`","1","2","3","4","5","6","7","8","9","0","-","=","backspace"],
                ["   ","q","w","e","r","t","y","u","i","o","p","[","]","\\"],
                ["caps","a","s","d","f","g","h","j","k","l",";","'","Done"],
                ["caps","z","x","c","v","b","n","m",",",".","/","caps"],
                ["",""," ","left","right","Done"]
            ];
            processInput(values[r][c]);
            event.accepted = true;
        }
    }
}




SortFilterProxyModel {
    id: searchModel
    sourceModel: api.allGames
    filters: RegExpFilter {
        roleName: "title"
        pattern: root.searchQuery // Привязка к строке поиска
        caseSensitivity: Qt.CaseInsensitive
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
    root.goToZone(2)
    focusTimer.start()
}

    // Появление: страница идет «вперед» (из глубины на пользователя)
    SequentialAnimation {
        id: enterAnim
        ScriptAction { 
            script: { 
                animatedContent.opacity = 0
                animatedContent.scale = 0.95 // Начинаем из глубины
            } 
        }
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 1; duration: 225; easing.type: Easing.OutQuad }
            NumberAnimation { target: animatedContent; property: "scale"; to: 1.0; duration: 225; easing.type: Easing.OutQuad }
        }
    }

    // Уход: страница идет «назад» (от пользователя вглубь)
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
            if (gridView.count > 0) {
                gridView.currentIndex = 0
                gridView.forceActiveFocus()
            }
        }
    }
}
}