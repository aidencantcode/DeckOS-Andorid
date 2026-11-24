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
    // Найдите Keys.onPressed в самом начале root FocusScope
Keys.onPressed: {
    if (leftBar.isOpen) return;

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

        // ========== НАВИГАЦИЯ ВНИЗ ==========
        else if (event.key === Qt.Key_Down || api.keys.isDetails(event)) {
            if (focusZone === 0) {
                // С верхнего навигатора в верхние кнопки
                console.log("Zone 1 → Zone 0 (top buttons)")
                goToZone(1)
                event.accepted = true
            }
            else if (focusZone === 1) {
                // С верхних кнопок в основной контент
                goToZone(2)
                event.accepted = true
            }
            else if (focusZone === 2) {
                // В основном контенте - проверяем, можно ли двигаться вниз
                var currentGridView = getCurrentGridView();
                if (currentGridView) {
                    var currentRow = Math.floor(currentGridView.currentIndex / currentGridView.columns);
                    var totalRows = Math.ceil(currentGridView.count / currentGridView.columns);
                    
                    // Если на последней строке - остаемся на месте
                    if (currentRow === totalRows - 1) {
                        // Можно добавить вибрацию или звук
                    }
                }
                // Разрешаем GridView обработать это нажатие
                event.accepted = false;
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
        
        // ========== НАВИГАЦИЯ ВВЕРХ ==========
        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
            if (focusZone === 2) {
                // В основном контенте - проверяем, можно ли двигаться вверх
                var currentGridView = getCurrentGridView();
                if (currentGridView) {
                    var currentRow = Math.floor(currentGridView.currentIndex / currentGridView.columns);
                    
                    // Если на первой строке - возвращаемся в зону 0
                    if (currentRow === 0) {
                        console.log("Top boundary reached, going back to Zone 0")
                        goToZone(1);
                        event.accepted = true;
                    } else {
                        // Разрешаем GridView обработать это нажатие
                        event.accepted = false;
                    }
                }
            }
            else if (focusZone === 1) {
                // С верхних кнопок в верхний навигатор
                console.log("Zone 0 → Zone 1 (top nav)")
                goToZone(0)
                event.accepted = true
            }
            else if (focusZone === 1) {
                // На верхнем навигаторе - ничего не делаем
                console.log("Already at top nav")
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
            currentPage--
            console.log("Previous page:", currentPage)
            // Обновляем индекс в topNavRow
            topNavRow.currentIndex = currentPage
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
            currentPage++
            console.log("Next page:", currentPage)
            // Обновляем индекс в topNavRow
            topNavRow.currentIndex = currentPage
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
            else if (focusZone === 2) {
                // Запуск игры из GridView
                var currentGridView = getCurrentGridView();
                if (currentGridView && currentGridView.currentIndex >= 0) {
                    var game = currentGridView.model.get(currentGridView.currentIndex);
                    if (game && game.launch) {
                        game.launch()
                    }
                }
                event.accepted = true
            }
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
        // УБРАТЬ ЭТИ СТРОКИ:
        // if (currentGridView.count > 0) {
        //     currentGridView.currentIndex = 0
        
    }
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
    y: topZone.y + topZone.height      // Начало сразу под topZone
    width: parent.width
    height: parent.height - (topZone.y + topZone.height + bottomBar.height) // До верхней границы bottomBar
    sourceComponent: [
        pageAllGames,
        pageFavorites,
        pageCollections,  // ← заменили pageConsoles
        pageOther
    ][currentPage]
}

    
     // ===============================
    // === 4 СТРАНИЦЫ ===
    // ===============================
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
                    topMargin: 20
                    leftMargin: parent.width * 0.015
                    rightMargin: parent.width * 0.015
                    bottomMargin: 20                   
                }

                clip: false
                cellWidth: width / 6
                cellHeight: cellWidth * 1.5
                model: api.allGames
                currentIndex: 0
                focus: false
                
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange
                highlightMoveDuration: 200

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        if (event.key === Qt.Key_Left) {
                            if (currentIndex > 0) {
                                currentIndex--;
                                event.accepted = true;
                            }
                        }
                        else if (event.key === Qt.Key_Right) {
                            if (currentIndex < count - 1) {
                                currentIndex++;
                                event.accepted = true;
                            }
                        }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < columnsCount) {
                                root.goToZone(1);
                                event.accepted = true;
                            } else {
                                currentIndex -= columnsCount;
                                event.accepted = true;
                            }
                        }
                        else if (event.key === Qt.Key_Down || api.keys.isDetails(event)) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < count - columnsCount) {
                                currentIndex += columnsCount;
                                event.accepted = true;
                            }
                        }
                        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (model.get(currentIndex) && model.get(currentIndex).launch) {
                                model.get(currentIndex).launch();
                            }
                            event.accepted = true;
                        }
                    }
                }

                delegate: Item {
                    width: gridView.cellWidth 
                    height: gridView.cellHeight 
                    property bool hasImage: modelData.assets && (modelData.assets.boxFront || modelData.assets.poster)
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: "transparent"
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        // Серая заглушка вместо цвета контейнера
                        Rectangle {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
                            anchors.centerIn: parent
                            color: "#555"
                            visible: !hasImage
                        }

                        Image {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
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
                                source: modelData && modelData.assets.poster ? modelData.assets.poster : ""
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
                            text: modelData.title || ("Game " + (index + 1))
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
            NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947 + 12; duration: 100; easing.type: Easing.OutBack }
            NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935 + 12; duration: 100; easing.type: Easing.OutBack }
            ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
        }
        ParallelAnimation {
            NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935; duration: 100; easing.type: Easing.InOutQuad }
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
                                if (modelData && modelData.launch) {
                                    modelData.launch()
                                }
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
    id: pageFavorites
    FocusScope {
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
                cellWidth: width / 6
                cellHeight: cellWidth * 1.5
                model: {
                    var favorites = []
                    for (var i = 0; i < api.allGames.count; i++) {
                        var game = api.allGames.get(i)
                        if (game.favorite) {
                            favorites.push(game)
                        }
                    }
                    return favorites
                }
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange
                highlightMoveDuration: 200
                currentIndex: 0
                focus: false
                
                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        if (event.key === Qt.Key_Left) {
                            if (currentIndex > 0) { currentIndex--; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Right) {
                            if (currentIndex < count - 1) { currentIndex++; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; }
                            else { currentIndex -= columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Down) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (model[currentIndex] && model[currentIndex].launch) {
                                model[currentIndex].launch();
                            }
                            event.accepted = true;
                        }
                        else if (api.keys.isDetails(event) || event.key === Qt.Key_X) {
                            if (model[currentIndex]) {
                                root.currentFocusedGame = model[currentIndex];
                                root.toggleOptionsMenu();
                            }
                            event.accepted = true;
                        }
                    }
                }
                
                delegate: Item {
                    width: gridView.cellWidth 
                    height: gridView.cellHeight 
                    property bool hasImage: modelData.assets && (modelData.assets.boxFront || modelData.assets.poster)
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2 
                    z:5

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: "transparent"
                        z: 1
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        Rectangle {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
                            anchors.centerIn: parent
                            color: "#555"
                            visible: !hasImage
                        }

                        Image {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
                            anchors.centerIn: parent
                            z: 10
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
                                source: modelData && modelData.assets.poster ? modelData.assets.poster : ""
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
                            text: modelData.title || ("Game " + (index + 1))
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
            NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947 + 12; duration: 100; easing.type: Easing.OutBack }
            NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935 + 12; duration: 100; easing.type: Easing.OutBack }
            ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
        }
        ParallelAnimation {
            NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935; duration: 100; easing.type: Easing.InOutQuad }
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
                                if (modelData && modelData.launch) {
                                    modelData.launch()
                                }
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
                        if (event.key === Qt.Key_Left) {
                            if (currentIndex > 0) { currentIndex--; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Right) {
                            if (currentIndex < count - 1) { currentIndex++; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; }
                            else { currentIndex -= columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Down) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; }
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
        id: appearAnimCollection
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
                cellWidth: width / 6
                cellHeight: cellWidth * 1.5
                model: collectionGamesLoader.collection ? collectionGamesLoader.collection.games : null
                currentIndex: 0
                focus: false
                
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange
                highlightMoveDuration: 200

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        if (event.key === Qt.Key_Left) {
                            if (currentIndex > 0) { currentIndex--; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Right) {
                            if (currentIndex < count - 1) { currentIndex++; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; }
                            else { currentIndex -= columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Down) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (model.get(currentIndex) && model.get(currentIndex).launch) {
                                model.get(currentIndex).launch();
                            }
                            event.accepted = true;
                        }
                    }
                }

                delegate: Item {
                    width: gridView.cellWidth
                    height: gridView.cellHeight 
                    property bool hasImage: modelData.assets && (modelData.assets.boxFront || modelData.assets.poster)
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: "transparent"
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        Rectangle {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
                            anchors.centerIn: parent
                            color: "#555"
                            visible: !hasImage
                        }

                        Image {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
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
                                source: modelData && modelData.assets.poster ? modelData.assets.poster : ""
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
                            text: modelData.title || ("Game " + (index + 1))
                            font.family: bold.name
                            color: "white"
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
            NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947 + 12; duration: 100; easing.type: Easing.OutBack }
            NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935 + 12; duration: 100; easing.type: Easing.OutBack }
            ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
        }
        ParallelAnimation {
            NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935; duration: 100; easing.type: Easing.InOutQuad }
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
                                if (modelData && modelData.launch) {
                                    modelData.launch()
                                }
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
                cellWidth: width / 6
                cellHeight: cellWidth * 1.5
                model: api.allGames
                currentIndex: 0
                focus: false
                
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.SnapToRow
                highlightRangeMode: GridView.NoHighlightRange
                highlightMoveDuration: 200

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        if (event.key === Qt.Key_Left) {
                            if (currentIndex > 0) { currentIndex--; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Right) {
                            if (currentIndex < count - 1) { currentIndex++; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < columnsCount) { root.goToZone(1); event.accepted = true; }
                            else { currentIndex -= columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Down) {
                            var columnsCount = Math.floor(width / cellWidth);
                            if (currentIndex < count - columnsCount) { currentIndex += columnsCount; event.accepted = true; }
                        }
                        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (model.get(currentIndex) && model.get(currentIndex).launch) {
                                model.get(currentIndex).launch();
                            }
                            event.accepted = true;
                        }
                    }
                }

                delegate: Item {
                    width: gridView.cellWidth 
                    height: gridView.cellHeight 
                    property bool hasImage: modelData.assets && (modelData.assets.boxFront || modelData.assets.poster)
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: "transparent"
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        Rectangle {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
                            anchors.centerIn: parent
                            color: "#555"
                            visible: !hasImage
                        }

                        Image {
                            width: gridView.cellWidth * 0.9
                            height: gridView.cellHeight * 0.9
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
                                source: modelData && modelData.assets.poster ? modelData.assets.poster : ""
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
                            text: modelData.title || ("Game " + (index + 1))
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
    id: highlightBorder
    width: gridView.cellWidth * 0.947
    height: gridView.cellHeight * 0.935
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
            NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947 + 12; duration: 100; easing.type: Easing.OutBack }
            NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935 + 12; duration: 100; easing.type: Easing.OutBack }
            ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
        }
        ParallelAnimation {
            NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: highlightBorder; property: "width"; to: gridView.cellWidth * 0.947; duration: 100; easing.type: Easing.InOutQuad }
            NumberAnimation { target: highlightBorder; property: "height"; to: gridView.cellHeight * 0.935; duration: 100; easing.type: Easing.InOutQuad }
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
                                if (modelData && modelData.launch) {
                                    modelData.launch()
                                }
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
        color: "black"
        z: 10000

        

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

            // Обработка клавиш для навигации внутри бара
            Keys.onLeftPressed: if (currentIndex > 0) currentIndex--
            Keys.onRightPressed: if (currentIndex < 3) currentIndex++
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
        
        // ЖЕСТКО УСТАНАВЛИВАЕМ НАЧАЛЬНУЮ ПОЗИЦИЮ СПРАВА
        Component.onCompleted: {
            x = posRight
            opacity = 1
        }
        
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
  
    // Текст поиска
    Text {
        id: searchText
        anchors.verticalCenter: parent.verticalCenter
        
        // Базовая позиция: x зависит от ширины иконки и отступа
        readonly property real targetX: 15 + 50 // posLeft лупы + отступ
        x: targetX + 20 // По умолчанию сдвинут вправо

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
                PropertyChanges { target: searchText; x: targetX; opacity: 1; visible: true }
            }
        ]

        transitions: [
            Transition {
                from: "*"; to: "focused"
                SequentialAnimation {
                    // Сначала делаем видимым, но прозрачным
                    PropertyAction { target: searchText; property: "visible"; value: true }
                    // Пауза, чтобы текст начал появляться, когда лупа уже почти доехала (синхронизация)
                    PauseAnimation { duration: 150 }
                    ParallelAnimation {
                        NumberAnimation { target: searchText; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                        NumberAnimation { target: searchText; property: "x"; to: targetX; duration: 100; easing.type: Easing.OutCubic }
                    }
                }
            },
            Transition {
                from: "focused"; to: "*"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: searchText; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                        NumberAnimation { target: searchText; property: "x"; to: targetX + 20; duration: 150; easing.type: Easing.InCubic }
                    }
                    // В конце скрываем полностью
                    PropertyAction { target: searchText; property: "visible"; value: false }
                }
            }
        ]
    }

    MouseArea { 
        anchors.fill: parent
        onClicked: {
            if (root.focusZone === 0 && topButtonsNames.currentIndex === 0) {
                theme.openPage(9) // Повторный клик - в библиотеку
            } else {
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
