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

    property real topH: 95
    property var theme
    // Система фокуса - 3 зоны (1-0-2)
    property int focusZone: 1 // 1 = верхний бар, 0 = верхние кнопки, 2 = gridView
    
    // Свойство для полноэкранного просмотра
    property bool fullscreenView: false
    property var currentScreenshotGame: null
    
    // Самый нижний слой (фоновая подложка)
    Rectangle {
        id: globalBackground
        anchors.fill: parent
        color: "#0F1318"
        z: -100
    }
    
    function toggleFullscreen(game) {
        if (fullscreenView) {
            fullscreenView = false
            currentScreenshotGame = null
            // Возвращаем фокус в GridView
            goToZone(2)
        } else if (game && game.assets && game.assets.screenshot) {
            fullscreenView = true
            currentScreenshotGame = game
            // Снимаем фокус со всех
            topButtonsNames.focus = false
            gridView.focus = false
        }
    }

    // ============================================
    // ГЛАВНЫЙ ОБРАБОТЧИК КЛАВИШ
    // ============================================
    Keys.onPressed: {
        if (leftBar.isOpen) return;
        
        if (fullscreenView) {
            // Управление в полноэкранном режиме
            if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
                toggleFullscreen(null)
                event.accepted = true
            }
            return
        }

        // ========== НАВИГАЦИЯ ВНИЗ ==========
        if (event.key === Qt.Key_Down || api.keys.isDetails(event)) {
            if (focusZone === 0) {
                goToZone(1)
                event.accepted = true
            }
            else if (focusZone === 1) {
                goToZone(2)
                event.accepted = true
            }
        }
        
        // ========== НАВИГАЦИЯ ВВЕРХ ==========
        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
            if (focusZone === 2) {
                var currentRow = Math.floor(gridView.currentIndex / gridView.columns);
                if (currentRow === 0) {
                    goToZone(1);
                }
                event.accepted = true;
            }
            else if (focusZone === 1) {
                goToZone(0)
                event.accepted = true
            }
        }
        
        // ========== ГОРИЗОНТАЛЬНАЯ НАВИГАЦИЯ ==========
        else if (event.key === Qt.Key_Left) {
            if (focusZone === 0 && topButtonsNames.currentIndex > 0) {
                topButtonsNames.currentIndex--
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Right) {
            if (focusZone === 0 && topButtonsNames.currentIndex < 3) {
                topButtonsNames.currentIndex++
                event.accepted = true
            }
        }
        
        // ========== КНОПКА ACCEPT (SELECT/A) ==========
        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
            if (focusZone === 0) {
                event.accepted = true
            }
            else if (focusZone === 2) {
                if (gridView.currentIndex >= 0) {
                    var game = gridView.model.get(gridView.currentIndex);
                    if (game && game.assets && game.assets.screenshot) {
                        toggleFullscreen(game)
                    }
                }
                event.accepted = true
            }
        }
        
        // ========== КНОПКА CANCEL (BACK/B) ==========
else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {      
    if (fullscreenView) {
        // Выход из полноэкранного просмотра
        toggleFullscreen(null)
        event.accepted = true
    }
    else if (focusZone === 2) {
        // Нажатие B в GridView - открываем меню
        leftBar.toggle()
        event.accepted = true
    }
}
}
    
    function goToZone(zoneIndex) {
        if (zoneIndex < 0) zoneIndex = 0
        if (zoneIndex > 2) zoneIndex = 2
        
        topButtonsNames.focus = false
        gridView.focus = false
        
        focusZone = zoneIndex
        
        if (zoneIndex === 0) {
            topButtonsNames.focus = true
            topButtonsNames.forceActiveFocus()
        }
        else if (zoneIndex === 1) {
            // Нет навигатора в Media
            goToZone(2)
        }
        else if (zoneIndex === 2) {
            gridView.focus = true
            gridView.forceActiveFocus()
        }
    }
    
    Item {
    id: animatedContent
    anchors.fill: parent

    // ===============================
    // === ПОЛНОЭКРАННЫЙ ПРОСМОТР ===
    // ===============================
    Item {
    id: fullscreenOverlay
    anchors.fill: parent
    visible: fullscreenView
    z: 1000
    
    Rectangle {
    id: fullscreenBg
    anchors.fill: parent
    color: "black"
    opacity: 0.5
    visible: fullscreenView
    z: 0
    }
    
    Image {
        id: fullscreenScreenshot
        z:1
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            topMargin: 95 // Высота topBar
            bottomMargin: 115 // Высота bottomBar
            leftMargin: 40
            rightMargin: 40
        }
        source: currentScreenshotGame && currentScreenshotGame.assets ? currentScreenshotGame.assets.screenshot : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    
    
    MouseArea {
    anchors.fill: parent
    }
}

    // ===============================
    // === ОСНОВНОЙ КОНТЕНТ ===
    // ===============================
    Rectangle {
        id: contentArea
        anchors.fill: parent
        color: "#0F1318" // Темный фон
        
        // GridView с играми
        GridView {
            id: gridView
            anchors {
                fill: parent
                leftMargin: parent.width * 0.035
                topMargin: topBar.height + 20
                bottomMargin: bottomBar.height + 20
            }

            clip: false
            cellWidth: width / 3 // 3 игры в ряд
            cellHeight: cellWidth * (9/16) // Соотношение 16:9
            currentIndex: 0
            focus: false
            
            boundsBehavior: Flickable.StopAtBounds
            snapMode: GridView.SnapToRow
            highlightRangeMode: GridView.ApplyRange
            preferredHighlightBegin: height
            preferredHighlightEnd: height * 0.7
            highlightMoveDuration: 200

            // Фильтрованная модель ТОЛЬКО со скриншотами
            model: {
                var gamesWithScreenshots = []
                for (var i = 0; i < api.allGames.count; i++) {
                    var game = api.allGames.get(i)
                    // Проверяем наличие скриншота
                    if (game.assets && game.assets.screenshot && game.assets.screenshot !== "") {
                        gamesWithScreenshots.push(game)
                    }
                }
                return gamesWithScreenshots
            }

            // Обработка клавиш в GridView
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
                        var columnsCount = 3;
                        if (currentIndex < columnsCount) {
                            root.goToZone(1);
                            event.accepted = true;
                        } else {
                            currentIndex -= columnsCount;
                            event.accepted = true;
                        }
                    }
                    else if (event.key === Qt.Key_Down || api.keys.isDetails(event)) {
                        if (currentIndex < count - 3) {
                            currentIndex += 3;
                            event.accepted = true;
                        }
                    }
                    else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                        // Открытие скриншота на полный экран
                        if (currentIndex >= 0) {
                            var game = model[currentIndex];
                            if (game) {
                                root.toggleFullscreen(game)
                            }
                        }
                        event.accepted = true;
                    }
                }
            }

            delegate: Item {
    width: gridView.cellWidth * 0.9
    height: gridView.cellHeight * 0.9
    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2
    
    // Размытый фон (только для сфокусированного элемента)
    Item {
        width: gridView.cellWidth * 1.05
        height: gridView.cellHeight * 1.05
        anchors.centerIn: parent
        clip: false
        opacity: isFocused ? 0.4 : 0.0
        z: parent.z - 1
        
        // Изображение для размытия (используем скриншот)
        Image {
            id: blurSource
            anchors.fill: parent
            source: modelData && modelData.assets && modelData.assets.screenshot
            fillMode: Image.PreserveAspectCrop
            visible: false
            
            // Показываем левый нижний угол
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            z: parent.z - 1
        }
        
        // Размытие
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
        id: gameContainer
        anchors.fill: parent
        color: "transparent"

        // Скриншот игры
        Image {
            anchors.fill: parent
            source: modelData.assets.screenshot
            fillMode: Image.PreserveAspectCrop
        }
    } 

                // Обводка при фокусе
                Rectangle {
                    id: highlightBorder
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 4
                    border.color: "grey"
                    radius: 2
                    anchors.margins: -7
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
                            NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -17; duration: 100; easing.type: Easing.OutBack }
                            ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
                            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
                        }

                        ParallelAnimation {
                            NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -7; duration: 100; easing.type: Easing.InOutQuad }
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
                            root.toggleFullscreen(modelData)
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

    
    Rectangle {
    anchors.fill: parent
    color: "black"
    property real currentScrollY: gridView ? gridView.contentY : 0   
    // Если меню открыто - 100% непрозрачность, иначе зависит от прокрутки
    opacity: leftBar.isOpen ? 1.0 : Math.min(1.0, Math.max(0.0, (currentScrollY + 0) / 100))
    Behavior on opacity { NumberAnimation { duration: 200 } }
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
        leftBar.currentIndex = 4
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
        Text { 
            text: "B"; 
            font.family: icons.name; 
            font.pixelSize: 53; 
            color: "white";
            y: parent.height * -0.025
        }
        Text { 
            text: "BACK"; 
            font.family: bold.name; 
            font.pixelSize: 25; 
            color: "white";
            y: parent.height * 0.23
        }
    }
    
    MouseArea { 
        anchors.fill: parent
        onClicked: {
            if (root.fullscreenView) {
                // Выход из полноэкранного режима просмотра
                root.toggleFullscreen(null)
            }
            else if (root.focusZone === 2) {
                // Из основного грида возвращаемся к верхним кнопкам
                console.log("Back from grid to top buttons")
                leftBar.toggle()
            }
            else if (root.focusZone === 1) {
                // Верхний бар - открываем меню
                console.log("Open menu from top bar")
                leftBar.toggle()
            }
            else if (root.focusZone === 0) {
                // Из верхних кнопок возвращаемся к гриду
                console.log("Back from top buttons to grid")
                root.goToZone(2)
            }
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
    property int currentIndex: 4
    property var buttons: []
    
   
    Keys.onPressed: {
        if (leftBar.isOpen && leftBar.focus) {
            if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
                if (currentIndex > 0) {
                    currentIndex--
                    updateFocus()
                    event.accepted = true
                }
            }
            else if (event.key === Qt.Key_Down || api.keys.isDetails(event)) {
                if (currentIndex < buttons.length - 1) {
                    currentIndex++
                    updateFocus()
                    event.accepted = true
                }
            }
            else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                theme.openPage(currentIndex)
                toggle()
                event.accepted = true
            }
            else if (event.key === Qt.Key_Right || api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                toggle()
                // Возвращаем фокус в библиотеку
                root.goToZone(1)
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
            "title": "Freands and Chat", 
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
        currentIndex = 4
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

            property int nextPageIndex: 0

    function startExitAnimation(index) {
        nextPageIndex = index
        exitAnim.start()
    }

    Component.onCompleted: {
    enterAnim.start()
    topButtonsNames.currentIndex = 0 // Фокус на поиск по умолчанию
    focusTimer.start() // Запускаем таймер для авто-фокуса на игры
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
        // Устанавливаем фокус на первую игру в GridView
        if (gridView && gridView.count > 0) {
            gridView.currentIndex = 0
            root.goToZone(2) // Переводим фокус в зону 2 (GridView)
            gridView.forceActiveFocus()
        } else {
            // Если скриншотов нет, фокус на поиск
            root.goToZone(0)
            topButtonsNames.forceActiveFocus()
        }
    }
}
}