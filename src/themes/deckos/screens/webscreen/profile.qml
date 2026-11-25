import QtQuick 2.15
import ".." // DECKOS: ProfileBadge
import QtMultimedia 5.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import SortFilterProxyModel 0.2
import QtQuick.Window 2.15
import "../../javascript/RetroAchievementsApi.js" as RAApi

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
        wrapMode: ShaderEffectSource.ClampToEdge
    }

    property real topH: 95
    property var theme
    // Система фокуса - 3 зоны (0 = topBar, 2 = profile content)
    property int focusZone: 2 
    
    property bool closeMenuVisible: false
    
    // Свойства профиля
    property string displayUserName: theme.globalUserName
property string displayUserPic: theme.globalUserPic
property string displayUserLevel: theme.globalUserLevel

    
    // Самый нижний слой (фоновая подложка)
    Rectangle {
        id: globalBackground
        anchors.fill: parent
        color: "#0F1318"
        z: -100
    }

    // ============================================
    // ГЛАВНЫЙ ОБРАБОТЧИК КЛАВИШ
    // ============================================
    Keys.onPressed: {
        if (leftBar.isOpen) return;
        
        // ========== НАВИГАЦИЯ ВНИЗ ==========
        if (event.key === Qt.Key_Down || api.keys.isDetails(event)) {
            if (focusZone === 0) {
                goToZone(2)
                event.accepted = true
                sNav.stop()
                sNav.play()
            }
        }
        
        // ========== НАВИГАЦИЯ ВВЕРХ ==========
        else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
            if (focusZone === 2 && (btnTopLeft.activeFocus || btnTopRight1.activeFocus)) {
                goToZone(0)
                sNav.stop()
                sNav.play()
                event.accepted = true
            }
        }
        
        // ========== ГОРИЗОНТАЛЬНАЯ НАВИГАЦИЯ (Только для TopBar) ==========
        else if (event.key === Qt.Key_Left) {
            if (focusZone === 0 && topButtonsNames.currentIndex > 0) {
                topButtonsNames.currentIndex--
                sNav.stop()
                sNav.play()
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Right) {
            if (focusZone === 0 && topButtonsNames.currentIndex < 3) {
                topButtonsNames.currentIndex++
                sNav.stop()
                sNav.play()
                event.accepted = true
            }
        }
        
        // Кнопка Menu
        else if (!closeMenuVisible && api.keys.isMenu(event)) {
            leftBar.toggle()
            event.accepted = true
        }
        
        // ========== КНОПКА CANCEL (BACK/B) ==========
        else if (!closeMenuVisible && (api.keys.isCancel(event) || event.key === Qt.Key_Escape)) {      
            if (focusZone === 2) {
                leftBar.toggle()
                event.accepted = true
            }
        }
    }
    
    function goToZone(zoneIndex) {
        if (zoneIndex < 0) zoneIndex = 0
        if (zoneIndex > 2) zoneIndex = 2
        
        topButtonsNames.focus = false
        btnTopLeft.focus = false
        
        focusZone = zoneIndex
        
        if (zoneIndex === 0) {
            topButtonsNames.focus = true
            topButtonsNames.forceActiveFocus()
        }
        else if (zoneIndex === 1) {
            goToZone(2)
        }
        else if (zoneIndex === 2) {
            btnTopLeft.focus = true
            btnTopLeft.forceActiveFocus()
        }
    }
    
        SortFilterProxyModel {
        id: recentGamesModel
        sourceModel: api.allGames
        sorters: RoleSorter {
            roleName: "lastPlayed"
            sortOrder: Qt.DescendingOrder
        }
    }


    Item {
        id: animatedContent
        anchors.fill: parent

        // ===============================
        // === ОСНОВНОЙ КОНТЕНТ ===
        // ===============================
        Item {
            id: contentArea
            anchors.fill: parent 
            anchors.topMargin: root.topH
anchors.bottomMargin: root.topH
            clip: true

            Flickable {
                id: scrollView
                anchors.fill: parent
                contentWidth: width
                contentHeight: contentCol.height
                boundsBehavior: Flickable.StopAtBounds

                // --- ДИНАМИЧЕСКИЙ ФОН С ГРАДИЕНТАМИ ---
                Item {
                    id: backgroundContainer
                    width: scrollView.contentWidth
                    height: scrollView.contentHeight
                    z: -1

                    Rectangle { anchors.fill: parent; color: "#20222E"; z: -3 }
                    Rectangle { height: scrollView.height * 0.25; width: parent.width; color: "#232532"; z: 0 }

                    RadialGradient {
                        anchors.fill: parent
                        horizontalOffset: -parent.width * 0.5
                        verticalOffset: -parent.height * 0.0
                        horizontalRadius: parent.width * 1
                        verticalRadius: parent.height * 1
                        z: -2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#2A4D45" }
                            GradientStop { position: 0.6; color: "#000F1318" }
                        }
                        opacity: 0.7
                    }

                    RadialGradient {
                        anchors.fill: parent
                        horizontalOffset: parent.width * 0.5
                        verticalOffset: -parent.height * 0.0
                        horizontalRadius: parent.width * 1
                        verticalRadius: parent.height * 1
                        z: -2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#3D2A4D" }
                            GradientStop { position: 0.6; color: "#000F1318" }
                        }
                        opacity: 0.7
                    }
                }

                // --- КОНТЕНТ ПРОФИЛЯ ---
                Column {
                    id: contentCol
                    width: parent.width

                    // 1. ВЕРХ (0.51 экрана)
                    Row {
                        width: parent.width
                        height: contentArea.height * 0.51

                        // Левая часть
                        Rectangle {
                            id: topLeftZone
                            width: parent.width * 0.7; height: parent.height; color: "transparent"
                            
                            Rectangle {
                                id: btnTopLeft
                                width: parent.width * 0.8; height: parent.height * 0.8                            
                                anchors.top: parent.top; anchors.left: parent.left; anchors.leftMargin: 45
                                color: activeFocus ? "white" : "transparent"
                                
                                Keys.onUpPressed: { root.goToZone(0); event.accepted = true }
                                KeyNavigation.right: btnTopRight1
                                KeyNavigation.down: middleListView
                                MouseArea { anchors.fill: parent; onClicked: btnTopLeft.forceActiveFocus() }
                                
                                Row {
                                    anchors.left: parent.left; anchors.top: parent.top; anchors.topMargin: 20; spacing: 40
                                    Rectangle { 
                                        width: 300; height: 300; color: "#222"
                                        Image { anchors.fill: parent; source: root.displayUserPic } 
                                    }
                                    Text { 
                                        text: root.displayUserName; font.pixelSize: 50; font.family: bold.name
                                        color: btnTopLeft.activeFocus ? "#000000" : "white" 
                                    }
                                }
                            }
                        }

                        // Правая часть
                        Rectangle {
                            id: topRightZone
                            width: parent.width * 0.3; height: parent.height; color: "transparent"
                            
                            Column {
                                anchors.fill: parent; anchors.rightMargin: 45; anchors.leftMargin: 29; anchors.topMargin: 20; spacing: 5
                                
                                Rectangle {
                                    id: btnTopRight1
                                    width: parent.width; height: 100; radius: 0
                                    color: activeFocus ? "white" : "#80000000"
                                    
                                    KeyNavigation.left: btnTopLeft
                                    Keys.onUpPressed: { root.goToZone(0); event.accepted = true }
                                    KeyNavigation.down: btnTopRight2
                                    MouseArea { anchors.fill: parent; onClicked: btnTopRight1.forceActiveFocus() }
                                    
                                    Text { 
                                        text: "Level: " + root.displayUserLevel; anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter 
                                        font.family: bold.name; color: parent.activeFocus ? "#000000" : "white" 
                                    }
                                }
                                
                                Rectangle {
                                    id: btnTopRight2
                                    width: parent.width; height: 120; radius: 0
                                    color: activeFocus ? "white" : "#80000000"
                                    
                                    KeyNavigation.left: btnTopLeft; KeyNavigation.up: btnTopRight1; KeyNavigation.down: btnTopRight3
                                    MouseArea { anchors.fill: parent; onClicked: btnTopRight2.forceActiveFocus() }
                                    
                                    Text { text: "Кнопка 2"; anchors.centerIn: parent; font.family: bold.name; color: parent.activeFocus ? "#000000" : "white" }
                                }
                                
                                Item { width: parent.width; height: 23 }
                                
                                Rectangle {
                                    id: btnTopRight3
                                    width: parent.width; height: 80; radius: 2
                                    color: activeFocus ? "white" : "#2B3445"
                                    
                                    KeyNavigation.left: btnTopLeft; KeyNavigation.up: btnTopRight2; KeyNavigation.down: middleListView
                                    MouseArea { anchors.fill: parent; onClicked: btnTopRight3.forceActiveFocus() }
                                    
                                    Text { text: "Edit profile"; anchors.centerIn: parent; font.family: bold.name; color: parent.activeFocus ? "#000000" : "white" }
                                }
                            }
                        }
                    }

                    // 2. СЕРЕДИНА (0.22 экрана)
                    Rectangle {
                        id: middleZone
                        width: parent.width; height: contentArea.height * 0.22; color: "transparent"
                        
                        ListModel {
                            id: middleModel
                            ListElement { name: "Icons" }
                            ListElement { name: "Games" }
                            ListElement { name: "Screenshots" }
                            ListElement { name: "Videos" }
                        }

                        ListView {
                            id: middleListView
                            anchors.fill: parent; anchors.leftMargin: 45; anchors.verticalCenter: parent.verticalCenter 
                            orientation: ListView.Horizontal; spacing: 7; model: middleModel 
                            
                            delegate: Rectangle {
                                id: delegateBtn
                                width: (middleListView.width - (20 * 3)) / 6.3; height: middleListView.height * 0.86
                                color: activeFocus ? "white" : "#73000000"
                                anchors.verticalCenter: parent.verticalCenter 
                                
                                KeyNavigation.up: btnTopLeft
                                KeyNavigation.down: btnGame1
                                MouseArea { anchors.fill: parent; onClicked: delegateBtn.forceActiveFocus() }
                                
                                Text { 
                                    text: name; anchors.left: parent.left; anchors.top: parent.top; anchors.topMargin: 20; anchors.leftMargin: 10
                                    color: parent.activeFocus ? "#000000" : "white"; font.pixelSize: 25; font.family: bold.name
                                }
                            }
                        }
                    }

                    // 3. НИЗ
Rectangle {
    id: bottomZone1
    width: parent.width
    height: contentArea.height
    color: "transparent"

    Rectangle {
        id: bgBottom
        anchors.fill: parent
        anchors.leftMargin: 45
        anchors.rightMargin: 45
        anchors.bottomMargin: 20
        color: "#40000000"

        // Основной вертикальный стек для контента
        Column {
            id: mainBottomColumn
            anchors.fill: parent
            anchors.margins: 20
            spacing: 25

            // Заголовок секции
            Item {
                width: parent.width
                height: 70
                Text {
                    text: "НЕДАВНЯЯ АКТИВНОСТЬ"
                    color: "white"
                    font.pixelSize: 25
                    font.family: bold.name
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "3,6 Ч. ЗА ПОСЛЕДНИЕ 2 НЕДЕЛИ"
                    color: "#a0a0a0"
                    font.pixelSize: 16
                    font.family: bold.name
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Repeater {
    model: Math.min(recentGamesModel.count, 3) // Например, выводим последние 3 игры
    
    delegate: Rectangle {
        id: btnGame
        width: parent.width
        height: (contentArea.height * 0.17) * 1.7
        color: activeFocus ? "white" : "#73000000"
        
        // Мапим данные из прокси-модели по индексу
        property var gameData: api.allGames.get(recentGamesModel.mapToSource(index))

        // Навигация (динамическая привязка к соседним элементам в списке)
        KeyNavigation.up: index === 0 ? middleListView : null
        focus: index === 0 // Фокус на первую игру по умолчанию

        MouseArea { 
            anchors.fill: parent
            onClicked: btnGame.forceActiveFocus() 
        }

        Column {
            anchors.fill: parent
            
            // Верхняя часть: Изображение и Название
            Item {
                width: parent.width
                height: contentArea.height * 0.17
                Image {
                    id: imagePlaceholder
                    height: parent.height - 30
                    width: height * 2.7
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.verticalCenter: parent.verticalCenter
                    source: btnGame.gameData ? theme.getAssetSource("steam", btnGame.gameData) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Text {
                    text: btnGame.gameData ? btnGame.gameData.title : "Нет данных"
                    anchors.left: imagePlaceholder.right
                    anchors.top: parent.top
                    anchors.leftMargin: 40
                    anchors.topMargin: 40
                    font.family: bold.name
                    color: btnGame.activeFocus ? "black" : "white"
                }
            }

            // Нижняя часть: Ачивки
            Item {
                width: parent.width
                height: btnGame.height - (contentArea.height * 0.17)
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 15
                    color: "#22222E"
                    radius: 10
                    
                    ListModel { id: achievementsModel }

                    Connections {
                        target: root
                        function onThemeChanged() {
                            if (root.theme && root.theme.savedUsername && btnGame.gameData) {
                                var targetGame = btnGame.gameData.title; 
                                RAApi.findGameIdByTitle(root.theme.savedUsername, root.theme.savedApiKey, targetGame, function(foundId) {
                                    if (foundId) {
                                        RAApi.getUserGameProgress(root.theme.savedUsername, root.theme.savedApiKey, foundId, function(data) {
                                            achievementsModel.clear(); 
                                            var addedCount = 0;
                                            for (var i = 0; i < data.achievements.length; i++) { 
                                                if (data.achievements[i].isUnlocked) {
                                                    achievementsModel.append({
                                                        "badgeName": data.achievements[i].badgeName
                                                    });
                                                    addedCount++;
                                                    if (addedCount >= 8) break;
                                                }
                                            }
                                        });
                                    }
                                });
                            }
                        }
                    }

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 10
                        orientation: ListView.Horizontal
                        spacing: 15
                        model: achievementsModel
                        clip: true
                        delegate: Image {
                            width: 50
                            height: 50
                            source: "https://media.retroachievements.org/Badge/" + model.badgeName + ".png"
                            fillMode: Image.PreserveAspectFit
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}

        } // Конец Column

        // Нижние функциональные кнопки
        Row {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 15

            Rectangle {
                id: btnBottomList1
                width: 220; height: 50; color: activeFocus ? "white" : "#26FFFFFF"
                KeyNavigation.up: btnGame3
                KeyNavigation.right: btnBottomList2
                MouseArea { anchors.fill: parent; onClicked: btnBottomList1.forceActiveFocus() }
                Text { text: "Кнопка 1"; anchors.centerIn: parent; font.family: bold.name; color: parent.activeFocus ? "black" : "white" }
            }
            Rectangle {
                id: btnBottomList2
                width: 180; height: 50; color: activeFocus ? "white" : "#26FFFFFF"
                KeyNavigation.up: btnGame3
                KeyNavigation.left: btnBottomList1
                KeyNavigation.right: btnBottomList3
                MouseArea { anchors.fill: parent; onClicked: btnBottomList2.forceActiveFocus() }
                Text { text: "Кнопка 2"; anchors.centerIn: parent; font.family: bold.name; color: parent.activeFocus ? "black" : "white" }
            }
            Rectangle {
                id: btnBottomList3
                width: 180; height: 50; color: activeFocus ? "white" : "#26FFFFFF"
                KeyNavigation.up: btnGame3
                KeyNavigation.left: btnBottomList2
                MouseArea { anchors.fill: parent; onClicked: btnBottomList3.forceActiveFocus() }
                Text { text: "Кнопка 3"; anchors.centerIn: parent; font.family: bold.name; color: parent.activeFocus ? "black" : "white" }
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
            anchors.top: root.top
            height: root.topH
            color: "transparent"
            z: 10000

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: leftBar.isOpen ? 1.0 : 1.0
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
                property int currentIndex: 3 // По умолчанию фокус на юзере в профиле
                spacing: 0
                focus: false

                Keys.onLeftPressed: if (currentIndex > 0) { currentIndex--; sNav.stop(); sNav.play() }
                Keys.onRightPressed: if (currentIndex < 3) { currentIndex++; sNav.stop(); sNav.play() }
                Keys.onPressed: {
                    if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                        if (root.focusZone === 0 && currentIndex === 0) { theme.openPage(9) }
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
                        x: posRight
                        color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "black" : "white"
                        
                        readonly property real posRight: topBtnSearch.width - 50
                        readonly property real posLeft: 15
                        
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
                                    PropertyAction { target: searchText; property: "visible"; value: true }
                                    PauseAnimation { duration: 150 }
                                    ParallelAnimation {
                                        NumberAnimation { target: searchText; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: searchText; property: "x"; to: targetX; duration: 200; easing.type: Easing.OutCubic }
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
                                    PropertyAction { target: searchText; property: "visible"; value: false }
                                }
                            }
                        ]
                    }

                    MouseArea { 
                        anchors.fill: parent
                        onClicked: if (!root.closeMenuVisible) {
                            if (root.focusZone === 0 && topButtonsNames.currentIndex === 0) { theme.openPage(9) } 
                            else { root.goToZone(0); sNav.stop(); sNav.play(); topButtonsNames.currentIndex = 0 }
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
                        onClicked: if (!root.closeMenuVisible) {
                            root.goToZone(0)
                            sNav.stop(); sNav.play()
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
                            if (isNaN(api.device.batteryPercent)) return "../../assets/theme-icons/battery" + getSuffix() + ".png";
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
                            font.family: bold.name
                            font.pixelSize: 36
                            visible: theme.showBatteryPercent
                            verticalAlignment: Text.AlignVCenter
                        }

                        Item {
                            width: 57; height: 33
                            anchors.verticalCenter: parent.verticalCenter
                            Image { id: batteryBase; anchors.fill: parent; source: batteryRow.getBatteryIcon(); mipmap: true }
                            Image { id: chargingOverlay; anchors.fill: parent; source: "../../assets/theme-icons/charging" + batteryRow.getSuffix() + ".png"; mipmap: true; visible: api.device.batteryCharging }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (!root.closeMenuVisible) {
                            root.goToZone(0)
                            sNav.stop(); sNav.play()
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

                    property string timeFormat: theme.use24HourFormat ? "HH:mm" : "hh:mm AP"

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: Qt.formatTime(new Date(), topBtnClock.timeFormat)
                        font.pixelSize: 35
                        font.family: bold.name
                        color: "white"
                    }

                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat) }                
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
                        width: parent.width * 0.85; height: parent.height * 0.8
                        source: (root.theme && root.theme.profilePictureSource !== "") ? root.theme.profilePictureSource : "../../assets/logo/logo.jpg" /* DECKOS */
                        fillMode: Image.PreserveAspectFit
                    }

                    Rectangle { anchors { top: userImage.top; bottom: userImage.bottom; right: userImage.right } width: 10; color: "#00BFFF" }

                    MouseArea { 
                        anchors.fill: parent; 
                        onClicked: if (!root.closeMenuVisible) {
                            root.goToZone(0)
                            sNav.stop(); sNav.play()
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
                    Text { text: theme.nintendoLayout ? (theme.universalIcons ? "В" : "B") : (theme.universalIcons ? "А" : "A"); font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025 }
                    Text { text: "SELECT"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
                }

                // --- Кнопка BACK ---
                Rectangle {
                    id: btnBack
                    width: 140; height: parent.height
                    color: "transparent"
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 18
                        Text { text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B"); font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025 }
                        Text { text: "BACK"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
                    }
                    
                    MouseArea { 
                        anchors.fill: parent
                        onClicked: if (!root.closeMenuVisible) {
                            if (root.focusZone === 2) { leftBar.toggle() }
                            else if (root.focusZone === 1) { leftBar.toggle() }
                            else if (root.focusZone === 0) { root.goToZone(2) }
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
        
        opacity: leftBar.isOpen ? (leftBar.x + leftBar.width) / leftBar.width : 0
        visible: opacity > 0

        MouseArea {
            anchors.fill: parent
            enabled: leftBar.isOpen
            onClicked: {
                leftBar.toggle()
                focusTimer.start()
            }
        }

        FastBlur { anchors.fill: parent; source: globalBlurSource; radius: 50; transparentBorder: false }
        Rectangle { anchors.fill: parent; color: "black"; opacity: 0.7 }
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
            visible: root.closeMenuVisible

            MouseArea { anchors.fill: parent }
            FastBlur { anchors.fill: parent; source: globalBlurSource; radius: 50; transparentBorder: false }
            Rectangle { anchors.fill: parent; color: "black"; opacity: 0.7 }
        }

        // Серый прямоугольник посередине
        Rectangle {
            width: 550
            height: 240
            anchors.centerIn: parent
            color: "#181B20"
            
            Text {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: -65 }
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
                    width: parent.width; height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 0 ? "#DE3619" : "transparent"
                                  
                    Text { text: "   Exit"; color: "white"; font.pixelSize: 35; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }               
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 0) { closeMenu.currentButtonIndex = 0; sNav.stop(); sNav.play(); } 
                            else { Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */ }
                        }
                    }
                }
                
                Rectangle {
                    id: cancelButton1
                    width: parent.width; height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 1 ? "white" : "transparent"
                    
                    Text { text: "   Cancel"; color: closeMenu.currentButtonIndex === 1 ? "black" : "white"; font.pixelSize: 35; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 1) { closeMenu.currentButtonIndex = 1; sNav.stop(); sNav.play(); } 
                            else { closeMenuVisible = false; sLeftClose.play(); focusTimer.start() }
                        }
                    }
                }
            }
        }
        
        Keys.onPressed: {
            if (closeMenuVisible) {
                if (event.key === Qt.Key_Up) { if (currentButtonIndex > 0) { currentButtonIndex--; sNav.stop(); sNav.play(); }; event.accepted = true }
                else if (event.key === Qt.Key_Down) { if (currentButtonIndex < 1) { currentButtonIndex++; sNav.stop(); sNav.play(); }; event.accepted = true }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) { event.accepted = true }
                else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {}
                else if (api.keys.isMenu(event)) {}
                else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    if (currentButtonIndex === 0) { event.accepted = true; Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */; return } 
                    else if (currentButtonIndex === 1) { closeMenuVisible = false; sLeftClose.play(); focusTimer.start() }
                    event.accepted = true
                }            
            }
        }
        
        onVisibleChanged: { if (visible) { currentButtonIndex = 0; sShowui.play(); forceActiveFocus() } }
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
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        property bool isOpen: false
        property int currentIndex: 4
        property var buttons: []
        
        Keys.onPressed: {
            if (leftBar.isOpen && leftBar.focus) {
                if (event.key === Qt.Key_Up) {
                    if (currentIndex > 0) { currentIndex--; updateFocus(); sNav.stop(); sNav.play(); event.accepted = true }
                }
                else if (api.keys.isMenu(event)) { toggle(); event.accepted = true; root.goToZone(2) }         
                else if (event.key === Qt.Key_Down) {
                    if (currentIndex < buttons.length - 1) { currentIndex++; updateFocus(); event.accepted = true; sNav.stop(); sNav.play(); }
                }
                else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                    if (currentIndex === 7) { toggle(); root.closeMenuVisible = true; focusTimer.start() } 
                    else { theme.openPage(currentIndex); toggle(); if (currentIndex === 6) { sShowui.play() } }
                    event.accepted = true
                }
                else if (event.key === Qt.Key_Right || api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                    toggle(); root.goToZone(2); event.accepted = true            
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

            ProfileBadge { // DECKOS: user picture + name (Settings > Profile)
                theme: root.theme
                anchors.left: parent.left; anchors.leftMargin: 40
                anchors.right: parent.right; anchors.rightMargin: 20
                y: parent.height * 0.105; height: parent.height * 0.075
            }
            Column { id: buttonColumn; anchors { left: parent.left; top: parent.top; leftMargin: 0; topMargin: parent.height * 0.2 /* DECKOS: was 0.11, room for the profile */ } spacing: 0 }
        }

        Component {
            id: menuButtonComponent

            FocusScope {
                id: buttonScope
                property string title: ""
                property int buttonIndex: 0
                width: menuPanel.width
                height: Math.min(106, menuPanel.height * 0.085) /* DECKOS: was 106 */
                
                property bool isFocused: activeFocus
                onIsFocusedChanged: { if (isFocused) { bgColor = "#27303A"; textColor = "white" } else { bgColor = "transparent"; textColor = "#AAA" } }
                
                property color bgColor: "transparent"
                property color textColor: "#AAA"
                property string icon: ""

                Rectangle {
                    anchors.fill: parent; color: bgColor; Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Item {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 20; bottomMargin: 20 } width: 11; visible: theme.currentPage === buttonIndex   
Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 27; color: "#1A9EFF"; radius: 40 }
                    }
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: menuPanel.width * 0.083; spacing: 38
                        Text { text: icon; font.family: icons.name; font.pixelSize: menuPanel.width * 0.075; color: "white"; verticalAlignment: Text.AlignVCenter /* DECKOS: was parent.verticalCenter */; horizontalAlignment: Text.AlignHCenter }
                        Text { text: title; font.family: bold.name; font.pixelSize: menuPanel.width * 0.075; color: "white"; verticalAlignment: Text.AlignVCenter /* DECKOS: was parent.verticalCenter */; horizontalAlignment: Text.AlignHCenter }
                    }
                }         

                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (leftBar.currentIndex === buttonIndex) {
                            if (buttonIndex === 7) { leftBar.toggle(); closeMenu.forceActiveFocus(); closeMenuVisible = true } 
                            else { theme.openPage(buttonIndex); leftBar.toggle(); if (buttonIndex === 6) { sShowui.play() } }
                        } else {
                            leftBar.currentIndex = buttonIndex; leftBar.updateFocus(); sNav.stop(); sNav.play();
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
            
            currentIndex = 4
            updateFocus()
        }

        function updateFocus() { if (currentIndex >= 0 && currentIndex < buttons.length) { buttons[currentIndex].forceActiveFocus() } }
        function toggle() { theme.toggleLeftBar(leftBar); }
    }

    // --- АНИМАЦИИ ПЕРЕХОДА ---
    property int nextPageIndex: 0

    function startExitAnimation(index) {
        nextPageIndex = index
        exitAnim.start()
    }

    SequentialAnimation {
        id: enterAnim
        ScriptAction { script: { animatedContent.opacity = 0; animatedContent.scale = 0.95 } }
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
        ScriptAction { script: theme.finalizeNavigation(nextPageIndex) }
    }

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            if (!root.closeMenuVisible) {
                root.goToZone(2)
                btnTopLeft.forceActiveFocus() 
            }
        }
    }
}
