import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15

FocusScope {
    id: root
    anchors.fill: parent
    focus: true
    
    ShaderEffectSource {
    id: globalBlurSource
    // DECKOS: only ever seen blurred (the top and bottom bars): a third of the resolution looks the same
    // and costs a ninth of the work - it was the whole page drawn a second time, every frame
    textureSize: Qt.size(Math.max(1, Math.ceil(width / 3)), Math.max(1, Math.ceil(height / 3)))
    anchors.fill: parent
    sourceItem: animatedContent
    live: true
    visible: false
    // ClampToEdge гарантирует отсутствие щелей при размытии
    wrapMode: ShaderEffectSource.ClampToEdge
}




    // --- свойства ---
    property var theme
    property real topH: 95
    property real bottomH: topH
    property bool hasFocus: activeFocus
    property bool isReady: true
    property bool closeMenuVisible: false

    // ============================================
    // ГЛАВНЫЙ ОБРАБОТЧИК КЛАВИШ
    // ============================================
    Keys.onPressed: {
        // ОТКРЫТИЕ/ЗАКРЫТИЕ МЕНЮ ПО BACK И MENU
        if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || 
            event.key === Qt.Key_Menu || api.keys.isPageUp(event)) {
            leftBar.toggle()
            event.accepted = true
        }
        else if (api.keys.isMenu(event)) {
        // Кнопка Menu (левый нижний угол) - открытие левого меню
        leftBar.toggle()
        event.accepted = true
    }
    }
    
    Item {
        id: animatedContent
        anchors.fill: parent 

    Rectangle {
        id: background
        anchors.fill: parent
        color: "#0F1318"
    }
    
    // DECKOS: the page's content - the Store (2), Friends and Chat (3), Downloads (5) - under StMini's top
    // and bottom bars and Steam menu. StMini had a "nothing here" placeholder for all of them.
    Loader {
        id: contentLoader
        anchors.fill: parent
        focus: true
        source: root.pageIndex === 2 ? "pages/StoreContent.qml"
              : root.pageIndex === 3 ? "pages/FriendsContent.qml"
              : root.pageIndex === 5 ? "pages/DownloadsContent.qml" : ""
        onLoaded: {
            item.theme = root.theme
            if (!leftBar.isOpen) item.forceActiveFocus()
        }
    }
    Text {
        visible: contentLoader.status !== Loader.Ready && root.pageIndex >= 0
        anchors.centerIn: parent
        text: contentLoader.status === Loader.Error ? "This page couldn't be opened" : ""
        color: "white"
        font.pixelSize: 40
        font.family: bold.name
    }
    }

    // DECKOS: which page this is, read once (theme.currentPage moves on while the page fades out)
    property int pageIndex: -1
    onThemeChanged: if (theme && pageIndex < 0) pageIndex = theme.currentPage

    // DECKOS: the Steam menu closing hands the controller back to the page's content (the menu's code
    // started a timer of this name that didn't exist)
    Timer {
        id: focusTimer
        interval: 80
        onTriggered: if (!leftBar.isOpen && !root.closeMenuVisible) contentLoader.forceActiveFocus()
    }
    function resumeFocus() {
        if (!leftBar.isOpen && !root.closeMenuVisible) contentLoader.forceActiveFocus()
    }
    
    /* ================= TOP BAR ================= */
    Rectangle {
        id: topBar
        width: parent.width 
        height: root.topH
        color: "transparent"
        z: 10000

        property real scrollRatio: 0 // DECKOS: this page has no scrolling list (StMini read a missing `flick`)

        Rectangle {
            anchors.fill: parent
            color: "black"
            z: -1
        }

        // ======= ROW: TOP BUTTONS =======
        Row {
            id: topButtonsRow
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 28
            }
            property int currentIndex: 0
            spacing: 0

            // // ===== SEARCH =====
Rectangle {
    id: topBtnSearch
    width: topBar.width - (topBtnNet.width + topBarBattery.width + topBtnClock.width + topBtnUser.width + topButtonsRow.spacing * 3 + topButtonsRow.anchors.rightMargin * 2)
    height: root.topH
                color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "white" : "transparent"
                border.width: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                
                // Иконка Лупы
                               Text {
    id: searchIcon
    anchors.verticalCenter: parent.verticalCenter
    text: "¿"
    font.pixelSize: 35
    font.family: icons.name
    color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "black" : "white"
    
    // Начальные координаты
    readonly property real posRight: topBtnSearch.width - 50
    readonly property real posLeft: 15
    x: posRight

    // Состояния: "default" (справа) и "focused" (слева)
    states: [
        State {
            name: "focused"
            when: topButtonsRow.currentIndex === 0 && topButtonsRow.focus
            PropertyChanges { target: searchIcon; x: posLeft; opacity: 1 }
        },
        State {
            name: "default"
            when: !(topButtonsRow.currentIndex === 0 && topButtonsRow.focus)
            PropertyChanges { target: searchIcon; x: posRight; opacity: 1 }
        }
    ]

        // Описание самой анимации перехода
    transitions: [
        Transition {
            from: "default"; to: "focused" // Явный переход ТУДА
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
            from: "focused"; to: "default" // Явный переход ОБРАТНО
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
    
    // Базовая позиция: x зависит от ширины иконки и отступа
    readonly property real targetX: 15 + 50 // posLeft лупы + отступ
    x: targetX + 20 // По умолчанию сдвинут вправо
    y: 0

    text: "Search games in your Library..."
    font.pixelSize: 30
    font.family: bold.name
    color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "grey" : "transparent"
    opacity: 0
    visible: false

    states: [
        State {
            name: "focused"
            when: topButtonsRow.currentIndex === 0 && topButtonsRow.focus
            PropertyChanges { target: searchText; x: searchText.targetX; opacity: 1; visible: true }
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
                    NumberAnimation { target: searchText; property: "x"; to: searchText.targetX; duration: 250; easing.type: Easing.OutCubic }
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
                // В конце скрываем полностью
                PropertyAction { target: searchText; property: "visible"; value: false }
            }
        }
    ]
}



    MouseArea { 
        anchors.fill: parent
        onClicked: if (!root.closeMenuVisible) {
            root.goToZone(0)
            topButtonsRow.currentIndex = 0
        }
    }
}

            // ===== NETWORK =====
            Rectangle {
                id: topBtnNet
                width: 72; height: root.topH
                color: (topButtonsRow.currentIndex === 1 && topButtonsRow.focus) ? "white" : "transparent"
                border.width: (topButtonsRow.currentIndex === 1 && topButtonsRow.focus) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: theme.isOnline ? "°" : "o"   // ← вот здесь меняем    
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsRow.currentIndex === 1 && topButtonsRow.focus) ? "black" : "white"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0)
                        topButtonsRow.currentIndex = 1
                    }
                }
            }
            
            
          // Battery icon           
Item {
    id: topBarBattery
    width: theme.showBatteryPercent ? 170 : 70
    height: root.topH

    // === Фон (реагирует на фокус) ===
    Rectangle {
        id: batteryBg
        anchors.fill: parent
        color: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "white" : "transparent"
        border.width: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? 2 : 0
        border.color: "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // === Контент (текст + иконки) ===
    Row {
        id: batteryRow
        spacing: 5
        anchors.centerIn: parent

        // Выбор правильной иконки батареи
        function getBatteryIcon() {
            if (isNaN(api.device.batteryPercent)) {
                return "../assets/theme-icons/battery" + getSuffix() + ".png";
            }

            const batteryPercent = api.device.batteryPercent * 100;

            if (batteryPercent <= 20) {
                return "../assets/theme-icons/20" + getSuffix() + ".png";
            } else if (batteryPercent <= 40) {
                return "../assets/theme-icons/40" + getSuffix() + ".png";
            } else if (batteryPercent <= 60) {
                return "../assets/theme-icons/60" + getSuffix() + ".png";
            } else if (batteryPercent <= 80) {
                return "../assets/theme-icons/80" + getSuffix() + ".png";
            } else {
                return "../assets/theme-icons/battery" + getSuffix() + ".png";
            }
        }

        // Добавляем суффикс B при фокусе
        function getSuffix() {
            return (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "B" : "";
        }

        Text {
            text: {
                if (isNaN(api.device.batteryPercent)) {
                    return "N/A"
                } else {
                    return (api.device.batteryPercent * 100).toFixed(0) + "%"
                }
            }
            color: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "black" : "white"
            font.family: bold.name
            font.pixelSize: 36
            verticalAlignment: Text.AlignVCenter
            visible: theme.showBatteryPercent // Скрываем текст, если выключено
        }

        // === Контейнер для иконок (основная батарея + зарядка) ===
        Item {
            width: 57
            height: 33
            anchors.verticalCenter: parent.verticalCenter

            // Основная иконка батареи
            Image {
                id: batteryBase
                anchors.fill: parent
                source: batteryRow.getBatteryIcon()
                mipmap: true
            }

            // Иконка зарядки (поверх основной)
            Image {
                id: chargingOverlay
                anchors.fill: parent
                source: "../assets/theme-icons/charging" + batteryRow.getSuffix() + ".png"
                mipmap: true
                visible: api.device.batteryCharging
            }
        }
    }

    // === Область клика ===
    MouseArea {
        anchors.fill: parent
        onClicked: if (!root.closeMenuVisible) {
            root.goToZone(0)
            topButtonsRow.currentIndex = 2
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

            // ===== USER =====
            Rectangle {
                id: topBtnUser
                width: root.topH * 1.1; height: root.topH
                color: (topButtonsRow.currentIndex === 3 && topButtonsRow.focus) ? "white" : "transparent"
                border.width: (topButtonsRow.currentIndex === 3 && topButtonsRow.focus) ? 2 : 0
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
                    anchors {
                        top: userImage.top
                        bottom: userImage.bottom
                        right: userImage.right
                    }
                    width: 10
                    color: "#00BFFF"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0)
                        topButtonsRow.currentIndex = 3
                    }
                }
            }

            Keys.onLeftPressed: if (topButtonsRow.currentIndex > 0) topButtonsRow.currentIndex--
            Keys.onRightPressed: if (topButtonsRow.currentIndex < 3) topButtonsRow.currentIndex++
            Keys.onDownPressed: {
        // Переходим в среднюю зону
        root.goToZone(1)
            }
            Keys.onPressed: 
                      if (event.key === Qt.Key_Return || api.keys.isAccept(event)){
                     if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                theme.openPage(9) // Открываем Library
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

          // ====== Левая кнопка MENU ======
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
                anchors.fill: parent; 
                onClicked: if (!root.closeMenuVisible) { 
leftBar.toggle() 
leftBar.currentIndex = theme ? theme.menuIndex() : 0 // DECKOS: a menu button for every page
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
            Text { text: theme.nintendoLayout ? (theme.universalIcons ? "В" : "B") : (theme.universalIcons ? "А" : "A")
; font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025}
            Text { text: "SELECT"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23 }
        }

            // --- Кнопка BACK ---
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
                    anchors.fill: parent; 
                    onClicked: if (!root.closeMenuVisible) {leftBar.toggle()}
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
    
    /* ================= CLOSE MENU ================= */
FocusScope {
    id: closeMenu
    width: parent.width
    height: parent.height
    visible: closeMenuVisible
    focus: closeMenuVisible
    enabled: visible
    z: 99
    
    opacity: closeMenuVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    property int currentButtonIndex: 0
    // Массив теперь содержит только 2 кнопки
    property var buttons: [exitButton, cancelButton1] // DECKOS: the button's id (was a missing name)

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


    // Серый прямоугольник посередине
    Rectangle {
        width: 550
        height: 240 // Уменьшено, так как кнопок теперь 2
        anchors.centerIn: parent
        color: "#181B20"
        
        // Текст сверху
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
        
        // Контейнер для кнопок
        Column {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            spacing: 0
            
            // ===== 1. КНОПКА "EXIT" =====
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
                            sNav.stop();
                            sNav.play();
                        } else {
                            Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                        }
                    }
                }
            }
            
            // ===== 2. КНОПКА "CANCEL" =====
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
                            sNav.stop();
                            sNav.play();
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
    
    // ОБРАБОТКА КЛАВИШ
    Keys.onPressed: {
        if (closeMenuVisible) {
            if (event.key === Qt.Key_Up) {
                if (currentButtonIndex > 0) {
                    currentButtonIndex--
                    sNav.stop();
                    sNav.play();
                }
                event.accepted = true
            }
            else if (event.key === Qt.Key_Down) {
                if (currentButtonIndex < 1) { // Всего 2 кнопки (0 и 1)
                    currentButtonIndex++
                    sNav.stop();
                    sNav.play(); 
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
                    // Активация Exit
                    event.accepted = true
                    Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                    return
                } else if (currentButtonIndex === 1) {
                    // Активация Cancel
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
                sNav.stop();
            sNav.play();
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
                sNav.stop();
            sNav.play();
            } else {
                // Если уже на нижней кнопке - остаемся на ней
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
    if (currentIndex === 7) { // Close button
        toggle() // Закрываем левое меню
        theme.openPowerMenu() /* DECKOS: one Close menu (theme.qml) */ // Открываем CloseMenu
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
        else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
            toggle()
            focusTimer.start()
            event.accepted = true
        }
        else if (api.keys.isMenu(event)) {
            toggle()
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
            x: leftBar.isOpen ? width * 0.2 : 0
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

        // КОМПОНЕНТ КНОПКИ
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
    anchors.leftMargin: menuPanel.width * 0.083                     // отступ слева, можно менять
    spacing: 38                                // расстояние между иконкой и текстом

    // Иконка
    Text {
        text: icon
        font.family: icons.name
        font.pixelSize: menuPanel.width * 0.075
        color: "white"
        verticalAlignment: Text.AlignVCenter // DECKOS: was parent.verticalCenter (an anchor line)
        horizontalAlignment: Text.AlignHCenter
    }

    // Основной текст
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
            // Второе нажатие
            if (buttonIndex === 7) { // Close button
                leftBar.toggle() // Закрываем левое меню
                closeMenu.forceActiveFocus()
                theme.openPowerMenu() /* DECKOS: one Close menu (theme.qml) */ // Открываем CloseMenu
            } else {
                theme.openPage(buttonIndex)
                leftBar.toggle()
                if (buttonIndex === 6) {
                    sShowui.play()
                }
            }
        } else {
            // Первое нажатие — переводим фокус
            leftBar.currentIndex = buttonIndex
            leftBar.updateFocus()
            sNav.play()
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
        currentIndex = theme ? theme.menuIndex() : 0 // DECKOS: theme is assigned after creation
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
    if (theme && pageIndex < 0) pageIndex = theme.currentPage // DECKOS: (StMini set a topNavRow this page doesn't have)
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
}