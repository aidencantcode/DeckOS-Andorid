import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15

FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    // --- свойства ---
    property var theme
    property real topH: 95
    property real bottomH: topH
    property bool hasFocus: activeFocus
    property bool isReady: true

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
    }
    
    Item {
        id: animatedContent
        anchors.fill: parent 

    Rectangle {
        id: background
        anchors.fill: parent
        color: "#0F1318"
    }
    
    // ================= ЦЕНТР ЭКРАНА =================
    Text {
        anchors.centerIn: parent
        text: "Sorry Nothing Here Now :("
        color: "white"
        font.pixelSize: 40
        font.family: bold.name
    }
    }
    
    /* ================= TOP BAR ================= */
    Rectangle {
        id: topBar
        width: content.width
        height: root.topH
        color: "transparent"
        z: 10000

        property real scrollRatio: (flick.contentHeight > flick.height)
            ? (flick.contentY / (flick.contentHeight - flick.height))
            : 0

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
            from: "*"; to: "*"
            SequentialAnimation {
                // 1. Уход (движение на 20 ед. и исчезновение)
                ParallelAnimation {
                    NumberAnimation { 
                        target: searchIcon
                        property: "x"
                        to: (searchIcon.state === "focused") ? searchIcon.posRight - 20 : searchIcon.posLeft + 20
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                }

                // 2. Телепорт (пока иконка невидима)
                PropertyAction { 
                    target: searchIcon
                    property: "x"
                    value: (searchIcon.state === "focused") ? searchIcon.posLeft + 20 : searchIcon.posRight - 20
                }

                // 3. Появление (доводка на 20 ед. и проявление)
                ParallelAnimation {
                    NumberAnimation { 
                        target: searchIcon
                        property: "x"
                        to: (searchIcon.state === "focused") ? searchIcon.posLeft : searchIcon.posRight
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
                    NumberAnimation { target: searchText; property: "x"; to: targetX; duration: 250; easing.type: Easing.OutCubic }
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
                    text: "o"
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsRow.currentIndex === 1 && topButtonsRow.focus) ? "black" : "white"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: {
                        root.goToZone(0)
                        topButtonsRow.currentIndex = 1
                    }
                }
            }
            
            
          // Battery icon           
Item {
    id: topBarBattery
    width: 170
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
        onClicked: {
            root.goToZone(0)
            topButtonsRow.currentIndex = 2
        }
    }
}
                    

            // ===== CLOCK =====
            Rectangle {
                id: topBtnClock
                width: 200; height: root.topH
                color: "transparent"
                border.color: "transparent"               

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), "hh:mm AP")
                    font.pixelSize: 35
                    font.family: bold.name
                    color: "white"
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm AP")
                }                
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
                    source: "../assets/logo/logo.jpg"
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
                    onClicked: {
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
    Rectangle {
        id: bottomBar
        width: parent.width
        height: topH
        color: "black"
        z: 1000
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
                Text { text: "MENU"; font.family: bold.name; font.pixelSize: 28; color: "white"; y: parent.height * 0.21 }
            }

            MouseArea { 
                anchors.fill: parent; 
                onClicked: leftBar.toggle() 
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
                    Text { text: "B"; font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025}
                    Text { text: "BACK"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
                }
                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: leftBar.toggle() 
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
            x: leftBar.isOpen ? width * 0.2 : 0
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
                
                property bool isFocused: activeFocus
                
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
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 50
                        spacing: 38

                        Text {
                            text: icon
                            font.family: icons.name
                            font.pixelSize: Math.min(43, menuPanel.width / 7)
                            color: "white"
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

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
                        if (leftBar.currentIndex === buttonIndex) {
                            if (theme && theme.openPage) {
                                theme.openPage(buttonIndex)
                            }
                            leftBar.toggle()
                        } else {
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
        currentIndex = theme.currentPage
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
    topNavRow.currentIndex = currentPage
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