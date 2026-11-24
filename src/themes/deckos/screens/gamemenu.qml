import QtQuick 2.15
import QtMultimedia 5.9
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15
import "../ra" // DECKOS: RetroAchievements (from BigScreenFE)

FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    property real topH: 95
    property var theme
    property int focusZone: 0 // 0 = top, 1 = zone2 buttons, 2 = zone3 tabs, 3 = achievements list (DECKOS)
    readonly property int achievementsTab: 2 // DECKOS: the third tab (was COMMUNITY) shows RetroAchievements

    // DECKOS: move focus from the tab row into the achievements panel and back
    function enterAchievements() {
        topButtonsRow.focus = false
        zone2.focus = false
        zone3Tabs.focus = false
        focusZone = 3
        flick.contentY = Math.max(0, flick.contentHeight - flick.height) // whole panel above the footer
        raSection.forceActiveFocus()
        raSection.gridFocusAtZero()
    }
    function leaveAchievements() {
        goToZone(2)
        zone3Tabs.currentIndex = achievementsTab
    }
    property bool optionsMenuVisible: false
property var currentFocusedGame: null

function toggleOptionsMenu() {
    if (optionsMenuVisible) {
        // ЗАКРЫТИЕ
        optionsMenuVisible = false
        optionsMenu.focus = false
        
        // Возвращаем фокус в зону с играми
        if (focusZone === 1) {
            zone2.forceActiveFocus()
        }
    } else if (focusZone === 1) { 
        // ОТКРЫТИЕ
        currentFocusedGame = theme.currentGame
        
        // Снимаем фокус со всех элементов
        topButtonsRow.focus = false
        zone2.focus = false
        zone3Tabs.focus = false
        
        // Открываем меню и даём ему фокус
        optionsMenuVisible = true
        optionsMenu.forceActiveFocus()
    }
}

function goToZone(zoneIndex) {
    if (zoneIndex < 0) zoneIndex = 0
    if (zoneIndex > 2) zoneIndex = 2
    
    // Снимаем фокус со ВСЕХ
    topButtonsRow.focus = false
    zone2.focus = false  
    zone3Tabs.focus = false
    
    focusZone = zoneIndex
    
    // Прокрутка - ИСПРАВЛЕНО
    if (zoneIndex === 1) {
        flick.contentY = 0
    } else if (zoneIndex === 2) {
        flick.contentY = zone1.height + zone2.height + zone2_5.height - 330 // Добавляем отступ
    }
    
    // Фокус ТОЛЬКО на одну зону
    if (zoneIndex === 0) {
        topButtonsRow.forceActiveFocus()
        topButtonsRow.focus = true
    }
    else if (zoneIndex === 1) {
        zone2.forceActiveFocus()
        zone2.focus = true
    }
    else if (zoneIndex === 2) {
        zone3Tabs.forceActiveFocus()
        zone3Tabs.focus = true
    }
}


// === ДОБАВЛЯЕМ ЭТОТ КОД ===
// Основной обработчик клавиш для всего интерфейса
Keys.onPressed: {
    // DECKOS: the login overlay and the achievements panel handle their own keys
    if (raLogin.visible) { event.accepted = true; return }
    if (focusZone === 3) {
        if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) { leaveAchievements(); event.accepted = true }
        return
    }
    // Клавиша ВНИЗ
    if (event.key === Qt.Key_Down || api.keys.isDetails(event)) {
        if (focusZone === 0) {
            // С верхней панели переходим к кнопкам
            goToZone(1)
            zone2.currentButtonIndex = 0
            event.accepted = true
        } 
        else if (focusZone === 1) {
            // С кнопок переходим к вкладкам
            goToZone(2)
            zone3Tabs.currentIndex = 0
            event.accepted = true
        }
    } 
    
    // Клавиша ВВЕРХ
    else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
        if (focusZone === 2) {
            // С вкладок возвращаемся к кнопкам
            goToZone(1)
            zone2.currentButtonIndex = 0
            event.accepted = true
        } 
        else if (focusZone === 1) {
            // С кнопок возвращаемся на верхнюю панель
            goToZone(0)
            topButtonsRow.currentIndex = 0
            event.accepted = true
        }
    }
    
    // Клавиша ВЛЕВО
    else if (event.key === Qt.Key_Left || api.keys.isPrevPage(event)) {
        if (focusZone === 0) { 
            // Верхняя панель: двигаемся влево
            if (topButtonsRow.currentIndex > 0) {
                topButtonsRow.currentIndex--
                event.accepted = true
            }
        }
        else if (focusZone === 1) { 
            // Кнопки Play/G/w: двигаемся влево
            if (zone2.currentButtonIndex > 0) {
                zone2.currentButtonIndex--
                event.accepted = true
            }
        }
        else if (focusZone === 2) { 
            // Вкладки: двигаемся влево
            if (zone3Tabs.currentIndex > 0) {
                zone3Tabs.currentIndex--
                event.accepted = true
            }
        }
    } 
    
    // Клавиша ВПРАВО
    else if (event.key === Qt.Key_Right || api.keys.isNextPage(event)) {
        if (focusZone === 0) { 
            // Верхняя панель: двигаемся вправо
            if (topButtonsRow.currentIndex < 3) {
                topButtonsRow.currentIndex++
                event.accepted = true
            }
        }
        else if (focusZone === 1) { 
            // Кнопки Play/G/w: двигаемся вправо
            if (zone2.currentButtonIndex < 2) {
                zone2.currentButtonIndex++
                event.accepted = true
            }
        }
        else if (focusZone === 2) { 
            // Вкладки: двигаемся вправо
            if (zone3Tabs.currentIndex < 3) {
                zone3Tabs.currentIndex++
                event.accepted = true
            }
        }
    }
    
   // Кнопка SELECT/A (запуск игры или открытие меню)
else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
    if (focusZone === 1) { // Мы в зоне кнопок
        if (zone2.currentButtonIndex === 0) {
            // Нажали на Play
            if (theme.currentGame) {
                theme.currentGame.launch()
                event.accepted = true
            }
        } 
        else if (zone2.currentButtonIndex === 2) { // Исправлено: добавили zone2.
            // Кнопка G - открытие меню опций
            root.toggleOptionsMenu()
            event.accepted = true
        }
        else {
            event.accepted = true
        }
    }
    else if (focusZone === 2) {
        // Нажали SELECT на вкладке
        event.accepted = true
    }
}

    
    // Кнопка BACK/B (выход в меню)
    else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
        // Нажали BACK - ВОЗВРАЩАЕМСЯ НА ГЛАВНУЮ
        theme.openPage(0)
        event.accepted = true
    }
    
    // Кнопка MENU (открытие бокового меню)
    else if (event.key === Qt.Key_Menu || api.keys.isPageUp(event)) {
        leftBar.toggle()
        event.accepted = true
    }
}
// === КОНЕЦ ДОБАВЛЯЕМОГО КОДА ===

Item {
        id: animatedContent
        anchors.fill: parent 

    // Основная прокручиваемая область
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: parent.width 
        // DECKOS: +260 while the ACHIEVEMENTS tab is open, so the locked row can scroll above the footer
        contentHeight: parent.height * 1.5 + (zone3Tabs.currentIndex === root.achievementsTab ? 260 : 0)
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.DragAndOvershootBounds
        interactive: true
        clip: true
        
        Behavior on contentY { 
    NumberAnimation { 
        duration: 400 
        easing.type: Easing.OutCubic
    } 
}

        Image {
    id: zone1
    width: flick.contentWidth
    height: 620
    source: theme.currentGame && theme.currentGame.assets ? theme.currentGame.assets.background || "" : ""
    fillMode: Image.PreserveAspectCrop
    opacity: 0.9
}

Image {
    id: logo
    width: zone1.width / 1.5
    height: zone1.height / 1.5
    source: theme.currentGame && theme.currentGame.assets ? theme.currentGame.assets.logo || "" : ""
    fillMode: Image.PreserveAspectFit
    anchors.centerIn: zone1
    z: 100
}

       // Зона 2 — активная
FocusScope {
    id: zone2
    width: flick.contentWidth
    height: 200
    anchors.top: zone1.bottom
    z: 20
    focus: false
    
    property int currentButtonIndex: 0

    // 1. Зеленая кнопка Play
    Rectangle {
        id: playButton
        width: height * 4.7
        height: parent.height * 0.6
        radius: 5
        anchors {
            left: parent.left
            leftMargin: 60
            verticalCenter: parent.verticalCenter
        }
        color: (zone2.currentButtonIndex === 0 && zone2.focus) ? "#54B63D":"#20FEFEFE"        
        
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
        if (root.focusZone !== 1) {
            // Первый клик - переключаем фокус на игры
            root.goToZone(1)
            zone2.currentButtonIndex = 0
            zone2.forceActiveFocus()
        } else if (zone2.currentButtonIndex === 0 && zone2.focus) {
            // Второй клик на уже активной игре - запуск
            if (theme.currentGame) theme.currentGame.launch()
        } else {
            // Первый клик на другой кнопке в той же зоне
            zone2.currentButtonIndex = 0
            zone2.forceActiveFocus()
        }
    }
}

        Keys.onReturnPressed: {
            if (theme.currentGame) theme.currentGame.launch()
        }
    }

    // 2. Кнопка W (слева от G)
    Rectangle {
        id: wButton
        width: height
        height: parent.height * 0.6
        radius: 5
        anchors {
            right: parent.right
            rightMargin: 200
            verticalCenter: parent.verticalCenter
        }
        color: (zone2.currentButtonIndex === 1 && zone2.focus) ? "white" : "#20FEFEFE"
        Behavior on color { ColorAnimation { duration: 150 } }
        
        Text {
            anchors.centerIn: parent
            text: "G"
            color: (zone2.currentButtonIndex === 1 && zone2.focus) ? "black" : "white"
            font.pixelSize: 60
            font.family: icons.name
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.focusZone !== 1) {
                    root.goToZone(1)
                }
                zone2.currentButtonIndex = 1
                zone2.forceActiveFocus()
            }
        }
    }

    // 3. Кнопка G (справа)
    Rectangle {
        id: gButton
        width: height
        height: parent.height * 0.6
        radius: 5
        anchors {
            right: parent.right
            rightMargin: 60
            verticalCenter: parent.verticalCenter
        }
        color: (zone2.currentButtonIndex === 2 && zone2.focus) ? "white" : "#20FEFEFE"
        Behavior on color { ColorAnimation { duration: 150 } }
        
        Text {
            anchors.centerIn: parent
            text: "w"
            color: (zone2.currentButtonIndex === 2 && zone2.focus) ? "black" : "white"
            font.pixelSize: 60
            font.family: icons.name
        }

        MouseArea {
    anchors.fill: parent
    onClicked: {
        if (root.focusZone !== 1) {
            // Первый клик - переключаем фокус на зону кнопок
            root.goToZone(1)
            zone2.currentButtonIndex = 2
            zone2.forceActiveFocus()
        } else if (zone2.currentButtonIndex === 2 && zone2.focus) {
            // Второй клик на уже активной кнопке G - открываем меню
            root.toggleOptionsMenu()
        } else {
            // Первый клик на другой кнопке в той же зоне
            zone2.currentButtonIndex = 2
            zone2.forceActiveFocus()
        }
    }
}
    }

    Keys.onLeftPressed: if (currentButtonIndex > 0) currentButtonIndex--
    Keys.onRightPressed: if (currentButtonIndex < 2) currentButtonIndex++
    Keys.onDownPressed: root.goToZone(2)
    Keys.onUpPressed: root.goToZone(0)
}

// Зона 2.5 — разделитель
Rectangle {
    id: zone2_5
    width: flick.contentWidth
    height: 50
    anchors.top: zone2.bottom
    color: "transparent"
    z: 100

    Rectangle {
        width: parent.width * 0.85
        height: 3
        anchors.centerIn: parent
        color: "#20FEFEFE"
    }
}

// Зона 3 — новости
Rectangle {
    id: zone3
    width: flick.contentWidth
    anchors.top: zone2_5.bottom
    anchors.bottom: parent.bottom
    color: "transparent"
    z: 100

    // Вкладки сверху
    Row {
        id: zone3Tabs
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            margins: 60
        }
        height: 74
        spacing: 24
        property int currentIndex: 0
        focus: false

        // ACTIVITY
        Rectangle {
            id: tabActivity
            width: 240; height: parent.height
            radius: 40
            color: {
                if (tabActivity.activeFocus) "white"
                else if (zone3Tabs.currentIndex === 0) "#20FEFEFE" 
                else "transparent"
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Text {
                anchors.centerIn: parent
                text: "ACTIVITY"
                color: tabActivity.activeFocus ? "black" : "white"
                font.pixelSize: 27
                font.family: bold.name
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                    }
                    zone3Tabs.currentIndex = 0
                    tabActivity.forceActiveFocus()
                }
            }

            Keys.onReturnPressed: {
                zone3Tabs.currentIndex = 0
                tabActivity.forceActiveFocus()
            }
        }

        // YOUR STUFF
        Rectangle {
            id: tabYourStuff
            width: 240; height: parent.height
            radius: 40
            color: {
                if (tabYourStuff.activeFocus) "white"
                else if (zone3Tabs.currentIndex === 1) "#20FEFEFE" 
                else "transparent"
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Text {
                anchors.centerIn: parent
                text: "YOUR STUFF"
                color: tabYourStuff.activeFocus ? "black" : "white"
                font.pixelSize: 27
                font.family: bold.name
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                    }
                    zone3Tabs.currentIndex = 1
                    tabYourStuff.forceActiveFocus()
                }
            }

            Keys.onReturnPressed: {
                zone3Tabs.currentIndex = 1
                tabYourStuff.forceActiveFocus()
            }
        }

        // COMMUNITY
        Rectangle {
            id: tabCommunity
            width: 240; height: parent.height
            radius: 40
            color: {
                if (tabCommunity.activeFocus) "white"
                else if (zone3Tabs.currentIndex === 2) "#20FEFEFE" 
                else "transparent"
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Text {
                anchors.centerIn: parent
                text: "ACHIEVEMENTS" // DECKOS: was COMMUNITY
                color: tabCommunity.activeFocus ? "black" : "white"
                font.pixelSize: 27
                font.family: bold.name
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                    }
                    zone3Tabs.currentIndex = 2
                    tabCommunity.forceActiveFocus()
                }
            }

            Keys.onReturnPressed: {
                zone3Tabs.currentIndex = 2
                tabCommunity.forceActiveFocus()
            }
        }

        // GAME INFO
        Rectangle {
            id: tabGameInfo
            width: 240; height: parent.height
            radius: 40
            color: {
                if (tabGameInfo.activeFocus) "white"
                else if (zone3Tabs.currentIndex === 3) "#20FEFEFE" 
                else "transparent"
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Text {
                anchors.centerIn: parent
                text: "GAME INFO"
                color: tabGameInfo.activeFocus ? "black" : "white"
                font.pixelSize: 27
                font.family: bold.name
            }
            
            

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                    }
                    zone3Tabs.currentIndex = 3
                    tabGameInfo.forceActiveFocus()
                }
            }

            Keys.onReturnPressed: {
                zone3Tabs.currentIndex = 3
                tabGameInfo.forceActiveFocus()
            }
        }

        Keys.onLeftPressed: {
            if (currentIndex > 0) currentIndex--
            event.accepted = true
        }

        Keys.onRightPressed: {
            if (currentIndex < 3) currentIndex++
            event.accepted = true
        }

        Keys.onUpPressed: {
            root.goToZone(1)
            event.accepted = true
        }

        Keys.onDownPressed: {
            event.accepted = true
            if (currentIndex === root.achievementsTab) root.enterAchievements() // DECKOS
        }
    }

    // DECKOS: ACHIEVEMENTS tab content - BigScreenFE's RetroAchievements panel
    RAGameInfoSection {
        id: raSection
        anchors {
            left: zone3.left
            right: zone3.right
            top: zone3Tabs.bottom
            bottom: zone3.bottom
            leftMargin: 60
            rightMargin: 60
            topMargin: 40
            bottomMargin: 40
        }
        visible: zone3Tabs.currentIndex === root.achievementsTab
        game: theme ? theme.currentGame : null
        onTabFocusRequested: root.leaveAchievements()
        onLoginRequested: raLogin.open()
    }

    // Содержимое вкладки GAME INFO
Item {
    id: gameInfoContent
    anchors {
        left: zone3.left
        right: zone3.right
        top: zone3Tabs.bottom
        bottom: zone3.bottom
        leftMargin: 60  // отступ от краев
        rightMargin: 60
        topMargin: 40   // отступ от вкладок
        bottomMargin: 120
    }
    visible: zone3Tabs.currentIndex === 3

    Row {
        anchors.fill: parent
        spacing: 40

        // Картинка слева (2:3 соотношение)
        Rectangle {
            id: imageContainer
            width: height * 0.666  // 2:3
            height: parent.height
            color: "transparent"

            Image {
                id: posterImage
                anchors.fill: parent
                source: theme.currentGame && theme.currentGame.assets ? 
                        theme.currentGame.assets.poster || theme.currentGame.assets.boxFront || "" : ""
                fillMode: Image.PreserveAspectFit
                mipmap: true
                
                // Заглушка если нет картинки
                Rectangle {
                    visible: posterImage.source === ""
                    anchors.fill: parent
                    color: "#333"
                    radius: 5
                    
                    Text {
                        anchors.centerIn: parent
                        text: "No image"
                        color: "#888"
                        font.pixelSize: 20
                    }
                }
            }
        }

        // Описание справа
        Rectangle {
            id: descriptionContainer
            width: parent.width - imageContainer.width - parent.spacing
            height: parent.height
            color: "transparent"
            
            Text {
                id: descriptionText
                anchors.fill: parent
                text: {
                    if (!theme.currentGame || !theme.currentGame.description || theme.currentGame.description.trim() === "") {
                        return "No information about this game"
                    }
                    
                    var desc = theme.currentGame.summary || theme.currentGame.description // DECKOS: was an undefined `currentGame`
                    var maxLines = Math.floor(parent.height / 30) // примерная высота строки
                    var lines = desc.split('\n')
                    
                    if (lines.length > maxLines) {
                        var shortened = lines.slice(0, maxLines).join('\n')
                        return shortened.trim() + "..."
                    }
                    return desc
                }
                color: "grey"
                font.pixelSize: 30
                font.family: bold.name
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: Math.floor(parent.height / 30)
            }
        }
    }
}
}

// Размытый фон для зон 2 и 3
Image {
    id: menuBackgroundBlur
    width: flick.contentWidth
    height: parent.height * 0.6
    anchors.top: zone2.top // Начинается с зоны 2
    fillMode: Image.PreserveAspectCrop
    source: zone1.source // Используем тот же источник, что и у zone1
    opacity: 1
    z: -1
    visible: false
}

FastBlur {
    anchors.fill: menuBackgroundBlur
    source: menuBackgroundBlur
    radius: 100
    transform: Scale {
        origin.x: menuBackgroundBlur.width / 2
        origin.y: menuBackgroundBlur.height / 2
        yScale: -1
    }
}

// Затемнение всего размытого фона
Rectangle {
    anchors.fill: menuBackgroundBlur
    color: "#222227"
    opacity: 0.93
    z: 2
}
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
            color: leftBar.isOpen || topButtonsRow.focus ? Qt.rgba(0,0,0) : Qt.rgba(0, 0, 0, Math.min(topBar.scrollRatio / 0.4, 1))
            Behavior on color { ColorAnimation { duration: 100 } }
            z: -1
        }

        // ======= ROW: TOP BUTTONS =======
        Row {
            id: topButtonsRow
            anchors {
                right: parent.right
                left: parent.left   
                verticalCenter: parent.verticalCenter
                rightMargin: 15
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
    
    readonly property real posRight: topBtnSearch.width - 50
    readonly property real posLeft: 15
    
    // ЖЕСТКО УСТАНАВЛИВАЕМ НАЧАЛЬНУЮ ПОЗИЦИЮ СПРАВА
    Component.onCompleted: {
        x = posRight
        opacity = 1
    }
    
    // Убираем начальное значение x, чтобы не было конфликта
    // x: posRight // УДАЛИТЬ ЭТУ СТРОКУ

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
            // Если мы уже находимся в верхней зоне и уже выбрана кнопка поиска (индекс 0)
            if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                theme.openPage(9) // Открываем Library
            } else {
                // Если нет — просто переходим в верхнюю зону и выбираем поиск
                root.goToZone(0)
                topButtonsRow.currentIndex = 0
                topButtonsRow.forceActiveFocus()
                //sNav.play ()
            }
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
                        //sNav.play ()
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
            //sNav.play ()
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
                        //sNav.stop();
            //sNav.play();
                    }
                }
            }

            Keys.onLeftPressed:{ if (topButtonsRow.currentIndex > 0) topButtonsRow.currentIndex--
            //sNav.stop();
            ////sNav.play(); 
}
            Keys.onRightPressed: if (topButtonsRow.currentIndex < 3) topButtonsRow.currentIndex++
            Keys.onDownPressed: {root.goToZone(1)
//sNav.stop();
            ////sNav.play(); 
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
    height: root.topH
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
        leftBar.currentIndex = theme.currentPage
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

    MouseArea {
        anchors.fill: parent
        onClicked: theme.openPage(0) // Возврат на home.qml
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
    visible: buttonIndex  === 0
    
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
        currentIndex = 0
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
        height: 337
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
            
            
            
            // ===== 2. КНОПКА "ДОБАВИТЬ В ИЗБРАННОЕ" =====
            Rectangle {
                id: favoriteButton
                width: parent.width
                height: parent.height / 3
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
                height: parent.height / 3
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
                height: parent.height / 3
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
    
        // ОБРАБОТКА КЛАВИШ ВНУТРИ OPTIONS MENU
    Keys.onPressed: {
        if (optionsMenuVisible && optionsMenu.focus) {
            if (event.key === Qt.Key_Up) {
                // Навигация вверх (ограничиваем минимальный индекс единицей)
                if (currentButtonIndex > 1) {
                    currentButtonIndex--
                }
                event.accepted = true
            }
            else if (event.key === Qt.Key_Down) {
                // Навигация вниз (максимум 3)
                if (currentButtonIndex < 3) {
                    currentButtonIndex++
                }
                event.accepted = true
            }
            else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                // Обрабатываем только индексы с 1 по 3
                if (currentButtonIndex === 1) {
                    // Favorite
                    if (currentFocusedGame) {
                        currentFocusedGame.favorite = !currentFocusedGame.favorite
                        root.toggleOptionsMenu()
                    }
                } else if (currentButtonIndex === 2) {
                    // Properties
                    // Можно добавить вызов свойств, если нужно
                } else if (currentButtonIndex === 3) {
                    // Cancel
                    root.toggleOptionsMenu()
                }
                event.accepted = true
            }
            else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
                root.toggleOptionsMenu()
                event.accepted = true
            }
        }
    }

    
    // При открытии устанавливаем фокус на первую кнопку
    onVisibleChanged: {
        if (visible) {
            currentButtonIndex = 1
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
goToZone(1)
        zone2.currentButtonIndex = 0
        zone2.forceActiveFocus()
        
        // Задержка для гарантии
        focusTimer.start()
        }

    // Появление: страница идет «вперед» (из глубины на пользователя)
    SequentialAnimation {
        id: enterAnim
        ScriptAction { 
            script: { 
                animatedContent.opacity = 0
                animatedContent.scale = 0.95// Начинаем из глубины
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
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            zone2.forceActiveFocus()
            zone2.currentButtonIndex = 0
        }
    }

    // DECKOS: RetroAchievements login (opened from the ACHIEVEMENTS tab)
    RALogin {
        id: raLogin
        onSaved: { raSection.load(); root.enterAchievements() }
        onClosed: root.enterAchievements()
    }
}