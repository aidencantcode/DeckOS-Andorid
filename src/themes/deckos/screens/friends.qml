import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15

FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    // --- свойства, общие с library.qml ---
    property var theme
    property real topH: 95
    property real bottomH: topH
    property bool hasFocus: activeFocus
    property bool isReady: true

    // можно добавить сюда другие свойства, если они участвуют в работе баров
    // property bool showTopZone: true
    // property color bgColor: "#0F1318"

    Rectangle {
        id: background
        anchors.fill: parent
        color: "#0F1318"   // серый фон-заглушка
    }
    
    /* ================= TOP BAR ================= */
    Rectangle {
        id: topBar
        width: parent.width
        height: topH
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
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 28
            }
            property int currentIndex: 0
            spacing: 0
            focus: false

            // ===== SEARCH =====
            Rectangle {
                id: topBtnSearch
                width: 72; height: root.topH
                color: (topButtonsNames.currentIndex === 0 && root.focusZone === 1) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 0 && root.focusZone === 1) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "¿"
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsNames.currentIndex === 0 && root.focusZone === 1) ? "black" : "white"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: {
                        root.goToZone(1)
                        topButtonsNames.currentIndex = 0
                    }
                }
            }

            // ===== NETWORK =====
            Rectangle {
                id: topBtnNet
                width: 72; height: root.topH
                color: (topButtonsNames.currentIndex === 1 && root.focusZone === 1) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 1 && root.focusZone === 1) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "o"
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsNames.currentIndex === 1 && root.focusZone === 1) ? "black" : "white"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: {
                        root.goToZone(1)
                        topButtonsNames.currentIndex = 1
                    }
                }
            }
            
            // Battery icon           
            Item {
                id: topBarBattery
                width: 170
                height: root.topH

                Rectangle {
                    id: batteryBg
                    anchors.fill: parent
                    color: (topButtonsNames.currentIndex === 2 && root.focusZone === 1) ? "white" : "transparent"
                    border.width: (topButtonsNames.currentIndex === 2 && root.focusZone === 1) ? 2 : 0
                    border.color: "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    id: batteryRow
                    spacing: 5
                    anchors.centerIn: parent

                    function getBatteryIcon() {
                        if (isNaN(api.device.batteryPercent)) {
                            return "../assets/theme-icons/battery" + getSuffix() + ".png";
                        }
                        const batteryPercent = api.device.batteryPercent * 100;
                        if (batteryPercent <= 20) return "../assets/theme-icons/20" + getSuffix() + ".png";
                        else if (batteryPercent <= 40) return "../assets/theme-icons/40" + getSuffix() + ".png";
                        else if (batteryPercent <= 60) return "../assets/theme-icons/60" + getSuffix() + ".png";
                        else if (batteryPercent <= 80) return "../assets/theme-icons/80" + getSuffix() + ".png";
                        else return "../assets/theme-icons/battery" + getSuffix() + ".png";
                    }

                    function getSuffix() {
                        return (topButtonsNames.currentIndex === 2 && root.focusZone === 1) ? "B" : "";
                    }

                    Text {
                        text: isNaN(api.device.batteryPercent) ? "N/A" : (api.device.batteryPercent * 100).toFixed(0) + "%"
                        color: (topButtonsNames.currentIndex === 2 && root.focusZone === 1) ? "black" : "white"
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
                        root.goToZone(1)
                        topButtonsNames.currentIndex = 2
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
                    interval: 0; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm AP")
                }                
            }

            // ===== USER =====
            Rectangle {
                id: topBtnUser
                width: root.topH * 1.1; height: root.topH
                color: (topButtonsNames.currentIndex === 3 && root.focusZone === 1) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 3 && root.focusZone === 1) ? 2 : 0
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
                        root.goToZone(1)
                        topButtonsNames.currentIndex = 3
                    }
                }
            }

            Keys.onLeftPressed: if (topButtonsNames.currentIndex > 0) topButtonsNames.currentIndex--
            Keys.onRightPressed: if (topButtonsNames.currentIndex < 3) topButtonsNames.currentIndex++
            Keys.onDownPressed: { root.goToZone(2); event.accepted = true }
            Keys.onUpPressed: { root.goToZone(0); event.accepted = true }
            Keys.onReturnPressed: console.log("Top button pressed:", topButtonsNames.currentIndex)
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
            Text { text: ";"; font.family: icons.name; font.pixelSize: 38; color: "white";y:parent.height *0.21 }
            Text { text: "OPTIONS"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.325 }
        }

        // --- Подсказка SELECT ---
        Row {
            spacing: 18
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
                Text { text: "B"; font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025}
                Text { text: "BACK"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23 }
            }
            MouseArea { anchors.fill: parent; onClicked: console.log("BACK clicked") }
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

    property bool isOpen: false
    property int currentIndex: 0
    property var buttons: []

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
                
        Row {
    anchors.verticalCenter: parent.verticalCenter  // центр по вертикали
    anchors.left: parent.left                       // прижимаем к левому краю
    anchors.leftMargin: 50                         // отступ слева, можно менять
    spacing: 38                                // расстояние между иконкой и текстом

    // Иконка
    Text {
        text: icon
        font.family: icons.name
        font.pixelSize: 43
        color: "white"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    // Основной текст
    Text {
        text: title
        font.family: bold.name
        font.pixelSize: 43
        color: "white"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
}
}

            // УПРАВЛЕНИЕ КЛАВИШАМИ
            Keys.onUpPressed: {
                if (buttonIndex > 0) {
                    leftBar.currentIndex = buttonIndex - 1
                    leftBar.updateFocus()
                }
            }

            Keys.onDownPressed: {
                if (buttonIndex < leftBar.buttons.length - 1) {
                    leftBar.currentIndex = buttonIndex + 1
                    leftBar.updateFocus()
                }
            }

            Keys.onReturnPressed: {
                handleClick()
            }

            Keys.onRightPressed: {
                leftBar.toggle()
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
        currentIndex = 3
        updateFocus()
    }

    // ОБНОВЛЕНИЕ ФОКУСА
    function updateFocus() {
        if (currentIndex >= 3 && currentIndex < buttons.length) {
            buttons[currentIndex].forceActiveFocus()
        }
    }

    // ОТКРЫТИЕ/ЗАКРЫТИЕ МЕНЮ
    function toggle() {
        if (isOpen) {
            // ЗАКРЫТИЕ
            isOpen = false
            visible = false
            focus = false
            // Возвращаем фокус на страницу
            if (pageLoader.item) {
                pageLoader.item.forceActiveFocus()
            }
        } else {
            // ОТКРЫТИЕ
            visible = true
            focus = true
            isOpen = true
            // Восстанавливаем последний фокус
            updateFocus()
        }
    }
}
}