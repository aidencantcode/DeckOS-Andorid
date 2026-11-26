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
    
    onActiveFocusChanged: {
    if (activeFocus && theme && theme.mediaFilterGame && theme.mediaFilterGame !== "") {
        var filterTitle = theme.mediaFilterGame
        theme.mediaFilterGame = ""
        for (var i = 0; i < api.allGames.count; i++) {
            var game = api.allGames.get(i)
            if (game.title === filterTitle) {
                selectedGameForGrid = game
                break
            }
        }
        updateGridModel()
    }
}


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
    property int focusZone: 1

    property bool fullscreenView: false
    property var currentScreenshotGame: null

    property bool closeMenuVisible: false

    // --- Новые свойства для меню выбора игр ---
    property bool selectGamesMenuVisible: false
    property string searchQuery: ""
    property var filteredGames: []          // все игры с доступными скриншотами (отфильтрованные по поиску)
    property var recentGames: []           // массив из трёх случайных игр (из filteredGames)    
    property var selectedGameForGrid: null  // игра, скриншоты которой показываются в сетке (null = все игры)
    property var gridModel: []              // модель для GridView

    property var currentScreenshots: []
    property int currentScreenshotIndex: 0
    property bool uiVisible: true

    // --- Функции управления меню ---
    function toggleSelectGamesMenu() {
        if (selectGamesMenuVisible) {
            selectGamesMenuVisible = false
            // вернуть фокус на сетку, если есть
            if (gridView.count > 0) {
                gridView.forceActiveFocus()
                focusZone = 2
            }
        } else {
            selectGamesMenuVisible = true
            // подготовить данные
            updateFilteredGames()
            // сбросить индекс выбранной кнопки
            selectGamesMenu.forceActiveFocus()
            // закрыть клавиатуру, если открыта
            if (keyboardContainer.visible) {
                keyboardContainer.visible = false
                keyboardContainer.focus = false
            }
        }
    }

    function updateFilteredGames() {
        var all = []
        var query = searchQuery.toLowerCase().trim()
        for (var i = 0; i < api.allGames.count; i++) {
            var game = api.allGames.get(i)
            if (!game.assets) continue
            // есть ли скриншоты
            var hasScreenshot = (game.assets.screenshots && game.assets.screenshots.length > 0) ||
                                (game.assets.screenshot && game.assets.screenshot !== "")
            if (!hasScreenshot) continue
            // фильтр по поиску
            if (query !== "") {
                var title = game.title.toLowerCase()
                if (title.indexOf(query) === -1) {
                    // проверить custom search title
                    var custom = getCustomSearchTitle(game.title)
                    if (custom.toLowerCase().indexOf(query) === -1)
                        continue
                }
            }
            all.push(game)
        }
                filteredGames = all
        updateRecentGames() // <-- Изменение здесь
    }


        function updateRecentGames() {
        var list = filteredGames.slice()
        
        // Сортировка по убыванию даты последнего запуска
        list.sort(function(a, b) {
            var timeA = a.lastPlayed ? new Date(a.lastPlayed).getTime() : 0
            var timeB = b.lastPlayed ? new Date(b.lastPlayed).getTime() : 0
            return timeB - timeA
        })
        
        var selected = []
        var count = Math.min(3, list.length)
        for (var k = 0; k < count; k++) {
            selected.push(list[k])
        }
        recentGames = selected
    }


    function getCustomSearchTitle(title) {
        var data = api.memory.get("custom_assets_" + title)
        if (data && data.customTitles && data.customTitles.searchTitle && data.customTitles.searchTitle !== "")
            return data.customTitles.searchTitle
        return ""
    }

    // --- Обновление модели сетки ---
    function updateGridModel() {
        if (selectedGameForGrid) {
            var screenshots = selectedGameForGrid.assets.screenshots || []
            if (screenshots.length === 0 && selectedGameForGrid.assets.screenshot) {
                screenshots = [selectedGameForGrid.assets.screenshot]
            }
            gridModel = screenshots.map(function(s) {
                return { game: selectedGameForGrid, screenshot: s }
            })
            currentScreenshotIndex = 0
        } else {
            var items = []
            for (var i = 0; i < api.allGames.count; i++) {
                var game = api.allGames.get(i)
                if (!game.assets) continue
                var screens = game.assets.screenshots || []
                if (screens.length === 0 && game.assets.screenshot) {
                    screens = [game.assets.screenshot]
                }
                for (var j = 0; j < screens.length; j++) {
                    if (screens[j] && screens[j] !== "") {
                        items.push({ game: game, screenshot: screens[j] })
                    }
                }
            }
            gridModel = items
            // сбросить индекс, если был выбран
            if (currentScreenshotIndex >= gridModel.length)
                currentScreenshotIndex = 0
        }
    }

    function toggleFullscreen(data) {
        if (fullscreenView) {
        fullimageAnim.start()
            enterAnim.start()
            sBack.play ()
            fullscreenView = false
            currentScreenshotGame = null
            goToZone(2)
        } else {
            if (!data) return
            sShowui.play()
            fullimageAnim.start()
            enterAnim.start()
            fullscreenView = true
            currentScreenshotGame = data.game ? data.game : data

            var idx = 0
            var targetScreenshot = data.screenshot ? data.screenshot : ""
            for (var i = 0; i < gridView.model.length; i++) {
                if (gridView.model[i].screenshot === targetScreenshot) {
                    idx = i
                    break
                }
            }

            currentScreenshotIndex = idx

            uiVisible = true
            buttonsTimer.restart()

            topButtonsNames.focus = false
            gridView.focus = false
        }
    }
    
    // DECKOS: `theme` is now set while the page is being created: filter once it's complete
    onThemeChanged: Qt.callLater(applyMediaFilter)
    function applyMediaFilter() {
    if (!theme || theme.mediaFilterGame === "") return
    var filterTitle = theme.mediaFilterGame
    theme.mediaFilterGame = ""
    for (var i = 0; i < api.allGames.count; i++) {
        var game = api.allGames.get(i)
        if (game.title === filterTitle) {
            selectedGameForGrid = game
            break
        }
    }
    updateGridModel()
}

    Keys.onPressed: {
        if (leftBar.isOpen) return

        // --- Обработка кнопки X (isFilters) для открытия меню выбора игр ---
        if (!root.selectGamesMenuVisible && !root.closeMenuVisible && !root.fullscreenView && api.keys.isDetails(event)) {
            root.toggleSelectGamesMenu()
            event.accepted = true
            return
        }

        if (fullscreenView) {
            uiVisible = true
            buttonsTimer.restart()

            if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
                toggleFullscreen(null)
                event.accepted = true
            } else if (api.keys.isPrevPage(event)) {
                if (currentScreenshotIndex > 0) currentScreenshotIndex--
                event.accepted = true
            } else if (api.keys.isNextPage(event)) {
                if (currentScreenshotIndex < gridView.model.length - 1) currentScreenshotIndex++
                event.accepted = true
            }
            return
        }

        // --- Навигация по зонам ---
        if (event.key === Qt.Key_Down) {
            if (focusZone === 0) {
                goToZone(1)
                event.accepted = true
                sNav.stop()
                sNav.play()
            } else if (focusZone === 1) {
                goToZone(2)
                event.accepted = true
                sNav.stop()
                sNav.play()
            }
        } else if (event.key === Qt.Key_Up ) {
            // isFilters уже обработано выше, но здесь оставим для навигации вверх из грида
            if (focusZone === 2) {
                var currentRow = Math.floor(gridView.currentIndex / gridView.columns)
                if (currentRow === 0) {
                    goToZone(1)
                    sNav.stop()
                    sNav.play()
                }
                event.accepted = true
            } else if (focusZone === 1) {
                goToZone(0)
                sNav.stop()
                sNav.play()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Left) {
            if (focusZone === 0 && topButtonsNames.currentIndex > 0) {
                topButtonsNames.currentIndex--
                sNav.stop()
                sNav.play()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Right) {
            if (focusZone === 0 && topButtonsNames.currentIndex < 3) {
                topButtonsNames.currentIndex++
                sNav.stop()
                sNav.play()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
            if (focusZone === 0) {
                event.accepted = true
            } else if (focusZone === 2) {
                if (gridView.currentIndex >= 0) {
                    var game = gridView.model.get(gridView.currentIndex)
                    if (game && game.assets && game.assets.screenshot) {
                        toggleFullscreen(game)
                    }
                }
                event.accepted = true
            }
        } else if (!closeMenuVisible && api.keys.isMenu(event)) {
            leftBar.toggle()
            event.accepted = true
        } else if (!closeMenuVisible && api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
            if (fullscreenView) {
                toggleFullscreen(null)
                event.accepted = true
            } else if (focusZone === 2) {
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
        } else if (zoneIndex === 1) {
            goToZone(2)
        } else if (zoneIndex === 2) {
            gridView.focus = true
            gridView.forceActiveFocus()
        }
    }

    Item {
        id: animatedContent
        anchors.fill: parent

        Rectangle {
            id: globalBackground
            anchors.fill: parent
            color: "#0F1318"
            z: -100
        }

        Item {
            id: fullscreenOverlay
            anchors.fill: parent
            visible: fullscreenView
            z: 1000

            Rectangle {
                id: fullscreenBg
                anchors.fill: parent
                color: "#090A0B"
                opacity: 1
                visible: fullscreenView
                z: 0
            }

            Timer {
                id: buttonsTimer
                interval: 3000
                running: fullscreenView
                repeat: false
                onTriggered: uiVisible = false
            }

            Item {
                id: fullscreenImageContainer
                z: 1
                anchors {
                    left: parent.left; right: parent.right
                    top: parent.top; bottom: parent.bottom
                    topMargin: 95; bottomMargin: 115
                    leftMargin: 40; rightMargin: 40
                }

                Image {
                    anchors.fill: parent
                    source: gridView.model[currentScreenshotIndex] ? gridView.model[currentScreenshotIndex].screenshot : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            // Кнопка ВЛЕВО
            Text {
                text: "<"
                color: "white"
                font.pixelSize: 70
                font.family: icons.name
                anchors { left: parent.left; leftMargin: 60; verticalCenter: parent.verticalCenter }
                z: 2
                opacity: uiVisible ? 1.0 : 0.0
                visible: currentScreenshotIndex > 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -30
                    onClicked: {
                        uiVisible = true
                        buttonsTimer.restart()
                        if (currentScreenshotIndex > 0) currentScreenshotIndex--
                    }
                }
            }

            // Кнопка ВПРАВО
            Text {
                text: ">"
                color: "white"
                font.pixelSize: 70
                font.family: icons.name
                anchors { right: parent.right; rightMargin: 60; verticalCenter: parent.verticalCenter }
                z: 2
                opacity: uiVisible ? 1.0 : 0.0
                visible: currentScreenshotIndex < gridView.model.length - 1
                Behavior on opacity { NumberAnimation { duration: 300 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -30
                    onClicked: {
                        uiVisible = true
                        buttonsTimer.restart()
                        if (currentScreenshotIndex < gridView.model.length - 1) currentScreenshotIndex++
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 0
                onClicked: {
                    uiVisible = true
                    buttonsTimer.restart()
                }
            }
        }

        Rectangle {
            id: contentArea
            anchors.fill: parent
            color: "#0F1318"

            GridView {
                id: gridView
                anchors {
                    fill: parent
                    leftMargin: parent.width * 0.035
                    topMargin: topBar.height + 20
                    bottomMargin: bottomBar.height + 20
                }

                clip: false
                cellWidth: width / 3
                cellHeight: cellWidth * (9/16)
                currentIndex: 0
                focus: false

                snapMode: GridView.NoSnap
                highlightRangeMode: GridView.ApplyRange
                highlightMoveDuration: 250
                cacheBuffer: cellHeight * 3

                model: root.gridModel   // Используем динамическую модель

                Keys.onPressed: {
                    if (root.focusZone === 2) {
                        if (event.key === Qt.Key_Left) {
                            if (currentIndex > 0) {
                                currentIndex--
                                sNav.stop()
                                sNav.play()
                                event.accepted = true
                            }
                        } else if (event.key === Qt.Key_Right) {
                            if (currentIndex < count - 1) {
                                currentIndex++
                                sNav.stop()
                                sNav.play()
                                event.accepted = true
                            }
                        } else if (event.key === Qt.Key_Up) {
                            var columnsCount = 3
                            if (currentIndex < columnsCount) {
                                root.goToZone(1)
                                sNav.stop()
                                sNav.play()
                                event.accepted = true
                            } else {
                                currentIndex -= columnsCount
                                event.accepted = true
                                sNav.stop()
                                sNav.play()
                            }
                        } else if (event.key === Qt.Key_Down ) {
                            if (currentIndex < count - 3) {
                                currentIndex += 3
                                sNav.stop()
                                sNav.play()
                                event.accepted = true
                            }
                        } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (currentIndex >= 0) {
                                var game = model[currentIndex]
                                if (game) {
                                    root.toggleFullscreen(game)
                                }
                            }
                            event.accepted = true
                        }
                    }
                }

                delegate: Item {
                    width: gridView.cellWidth * 0.9
                    height: gridView.cellHeight * 0.9
                    property bool isFocused: GridView.isCurrentItem && gridView.focus && root.focusZone === 2

                    Item {
                        width: gridView.cellWidth * 1.05
                        height: gridView.cellHeight * 1.05
                        anchors.centerIn: parent
                        clip: false
                        opacity: isFocused ? 0.4 : 0.0
                        z: parent.z - 1

                        Image {
                            id: blurSource
                            anchors.fill: parent
                            source: modelData.screenshot
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

                    Rectangle {
                        id: gameContainer
                        anchors.fill: parent
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            source: modelData.screenshot
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

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
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 0; duration: 200; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -17; duration: 200; easing.type: Easing.OutBack }
                                ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 200 }
                                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 200 }
                            }

                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 200; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -7; duration: 200; easing.type: Easing.InOutQuad }
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
                            if (!isFocused) {
                                gridView.currentIndex = index
                                gridView.forceActiveFocus()
                                root.goToZone(2)
                                sNav.stop()
                                sNav.play()
                            } else {
                                root.toggleFullscreen(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- TOP BAR ----
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
            opacity: leftBar.isOpen ? 1.0 : Math.min(1.0, Math.max(0.0, (currentScrollY + 0) / 100))
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

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

            Keys.onLeftPressed: if (currentIndex > 0) { currentIndex--; sNav.stop(); sNav.play() }
            Keys.onRightPressed: if (currentIndex < 3) { currentIndex++; sNav.stop(); sNav.play() }
            Keys.onPressed: if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
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
                            root.goToZone(0)
                            sNav.stop()
                            sNav.play()
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
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0)
                        sNav.stop()
                        sNav.play()
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
                        if (isNaN(api.device.batteryPercent)) return "../assets/theme-icons/battery" + getSuffix() + ".png"
                        const batteryPercent = api.device.batteryPercent * 100
                        if (batteryPercent <= 20) return "../assets/theme-icons/20" + getSuffix() + ".png"
                        else if (batteryPercent <= 40) return "../assets/theme-icons/40" + getSuffix() + ".png"
                        else if (batteryPercent <= 60) return "../assets/theme-icons/60" + getSuffix() + ".png"
                        else if (batteryPercent <= 80) return "../assets/theme-icons/80" + getSuffix() + ".png"
                        else return "../assets/theme-icons/battery" + getSuffix() + ".png"
                    }

                    function getSuffix() {
                        return (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "B" : ""
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
                        root.goToZone(0)
                        sNav.stop()
                        sNav.play()
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
                    font.family: bold.name
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
                    source: (root.theme && root.theme.profilePictureSource !== "") ? root.theme.profilePictureSource : "../assets/logo/logo.jpg" /* DECKOS */
                    fillMode: Image.PreserveAspectFit
                }

                Rectangle {
                    anchors { top: userImage.top; bottom: userImage.bottom; right: userImage.right }
                    width: 10
                    color: "#00BFFF"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0)
                        sNav.stop()
                        sNav.play()
                        topButtonsNames.currentIndex = 3
                    }
                }
            }
        }
    }

    // ---- BOTTOM BAR ----
    Item {
        id: bottomBar
        width: parent.width
        height: root.topH
        anchors.bottom: parent.bottom
        z: 50000
        clip: true

        ShaderEffectSource {
            id: bottomAreaSource
            sourceItem: globalBlurSource
            sourceRect: Qt.rect(0, root.height - root.topH, root.width, root.topH)
            live: true
            visible: false
        }

        GaussianBlur {
            anchors.fill: parent
            source: bottomAreaSource
            radius: 150
            visible: !theme.highContrastBottomBar
            samples: 64
            transparentBorder: false
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: theme.highContrastBottomBar ? 1.0 : (leftBar.isOpen || root.closeMenuVisible || root.selectGamesMenuVisible ? 0.9 : 0.6)
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
                    leftBar.currentIndex = 4
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

    // === SELECT GAMES (X) — делаем как sortBtn ===
    Item {
        id: selectGamesBtn
        width: selectGamesLayout.width
        height: 53
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.fullscreenView && !root.selectGamesMenuVisible && !root.closeMenuVisible && !leftBar.isOpen

        Row {
            id: selectGamesLayout
            spacing: 18
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "X"
                font.family: icons.name
                font.pixelSize: 53
                color: "white"
                y: parent.height * -0.025
            }
            Text {
                text: "SELECT GAMES"
                font.family: bold.name
                font.pixelSize: 25
                color: "white"
                y: parent.height * 0.23
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggleSelectGamesMenu()
        }
    }

    // Обычная SELECT (A)
    Row {
        spacing: 18
        anchors.verticalCenter: parent.verticalCenter
        Text { 
            text: theme.nintendoLayout ? (theme.universalIcons ? "В" : "B") : (theme.universalIcons ? "А" : "A")
            font.family: icons.name
            font.pixelSize: 53
            color: "white"
            y: parent.height * -0.025 
        }
        Text { 
            text: "SELECT"
            font.family: bold.name
            font.pixelSize: 25
            color: "white"
            y: parent.height * 0.23 
        }
    }

            Rectangle {
                id: btnBack
                width: 140; height: parent.height
                color: "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Text {
                        text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B")
                        font.family: icons.name
                        font.pixelSize: 53
                        color: "white"
                        y: parent.height * -0.025
                    }
                    Text {
                        text: "BACK"
                        font.family: bold.name
                        font.pixelSize: 25
                        color: "white"
                        y: parent.height * 0.23
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        if (root.fullscreenView) {
                            root.toggleFullscreen(null)
                        } else if (root.focusZone === 2) {
                            leftBar.toggle()
                        } else if (root.focusZone === 1) {
                            leftBar.toggle()
                        } else if (root.focusZone === 0) {
                            root.goToZone(2)
                        }
                    }
                }
            }
        }
    }

    // ---- LEFT OVERLAY (затемнение) ----
    Item {
        id: leftOverlay
        anchors.fill: parent
        z: 0
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

    // ---- CLOSE MENU ----
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
        property var buttons: [exitButton, cancelButton]

        Item {
            id: closeMenuOverlay
            anchors.fill: parent
            z: 0
            visible: root.closeMenuVisible

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
                                sNav.stop()
                                sNav.play()
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
                                sNav.stop()
                                sNav.play()
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
                        sNav.stop()
                        sNav.play()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    if (currentButtonIndex < 1) {
                        currentButtonIndex++
                        sNav.stop()
                        sNav.play()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    event.accepted = true
                } else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                    // ignore
                } else if (api.keys.isMenu(event)) {
                    // ignore
                } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
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

    // ---- НОВОЕ МЕНЮ ВЫБОРА ИГР (SELECT GAMES) ----
        FocusScope {
        id: selectGamesMenu
        width: parent.width
        height: parent.height
        visible: selectGamesMenuVisible
        focus: selectGamesMenuVisible
        enabled: visible
        z: 9999

        opacity: selectGamesMenuVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        property int currentButtonIndex: 0
        property var buttons: [
            searchGamesButton,
            allGamesButton,
            game1Button,
            game2Button,
            game3Button,
            cancelSelectButton
        ]

        Item {
            anchors.fill: parent
            z: 0
            visible: selectGamesMenu.visible

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
            id: selectMenuPanel
            width: 600
            height: menuColumn.implicitHeight
            y: parent.height * 0.2
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#181B20"

            Column {
                id: menuColumn
                width: parent.width
                spacing: 5

                Rectangle {
                    id: searchGamesButton
                    width: parent.width
                    height: 85
                    color: selectGamesMenu.currentButtonIndex === 0 ? "white" : "#80000000"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        color: selectGamesMenu.currentButtonIndex === 0 ? "black" : "#66FFFFFF"
                        text: root.searchQuery === "" ? "Games search..." : root.searchQuery
                        font.family: bold.name
                        elide: Text.ElideRight 
                        width: parent.width - 40
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (selectGamesMenu.currentButtonIndex !== 0) {
                                selectGamesMenu.currentButtonIndex = 0
                                sNav.stop(); sNav.play()
                            } else {
                                keyboardContainer.visible = true
                                keyboardContainer.focus = true
                                keyboardContainer.cursorPosition = root.searchQuery.length
                                keyboardContainer.forceActiveFocus()
                                sShowui.play()
                            }
                        }
                    }
                }

                Rectangle {
                    id: allGamesButton
                    visible: root.searchQuery === "" && !keyboardContainer.visible
                    width: parent.width
                    height: 110
                    color: selectGamesMenu.currentButtonIndex === 1 ? "white" : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: "All Games"
                        color: selectGamesMenu.currentButtonIndex === 1 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (selectGamesMenu.currentButtonIndex !== 1) {
                                selectGamesMenu.currentButtonIndex = 1
                                sNav.stop(); sNav.play()
                            } else {
                                root.searchQuery = ""
                                root.selectedGameForGrid = null
                                root.updateGridModel()
                                root.toggleSelectGamesMenu()
                                sLeftClose.play()
                            }
                        }
                    }
                }

                Rectangle {
                    id: game1Button
                    visible: root.recentGames.length >= 1 && (root.searchQuery !== "" || !keyboardContainer.visible)
                    width: parent.width
                    height: 110
                    color: selectGamesMenu.currentButtonIndex === 2 ? "white" : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.recentGames.length >= 1 ? root.recentGames[0].title : ""
                        color: selectGamesMenu.currentButtonIndex === 2 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        elide: Text.ElideRight
                        width: parent.width - 80
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (selectGamesMenu.currentButtonIndex !== 2) {
                                selectGamesMenu.currentButtonIndex = 2
                                sNav.stop(); sNav.play()
                            } else {
                                if (root.recentGames.length >= 1) {
                                    root.selectedGameForGrid = root.recentGames[0]
                                    root.updateGridModel()
                                    root.toggleSelectGamesMenu()
                                    sLeftClose.play()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: game2Button
                    visible: root.recentGames.length >= 2 && (root.searchQuery !== "" || !keyboardContainer.visible)
                    width: parent.width
                    height: 110
                    color: selectGamesMenu.currentButtonIndex === 3 ? "white" : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.recentGames.length >= 2 ? root.recentGames[1].title : ""
                        color: selectGamesMenu.currentButtonIndex === 3 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        elide: Text.ElideRight
                        width: parent.width - 80
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (selectGamesMenu.currentButtonIndex !== 3) {
                                selectGamesMenu.currentButtonIndex = 3
                                sNav.stop(); sNav.play()
                            } else {
                                if (root.recentGames.length >= 2) {
                                    root.selectedGameForGrid = root.recentGames[1]
                                    root.updateGridModel()
                                    root.toggleSelectGamesMenu()
                                    sLeftClose.play()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: game3Button
                    visible: root.recentGames.length >= 3 && (root.searchQuery !== "" || !keyboardContainer.visible)
                    width: parent.width
                    height: 110
                    color: selectGamesMenu.currentButtonIndex === 4 ? "white" : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.recentGames.length >= 3 ? root.recentGames[2].title : ""
                        color: selectGamesMenu.currentButtonIndex === 4 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        elide: Text.ElideRight
                        width: parent.width - 80
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (selectGamesMenu.currentButtonIndex !== 4) {
                                selectGamesMenu.currentButtonIndex = 4
                                sNav.stop(); sNav.play()
                            } else {
                                if (root.recentGames.length >= 3) {
                                    root.selectedGameForGrid = root.recentGames[2]
                                    root.updateGridModel()
                                    root.toggleSelectGamesMenu()
                                    sLeftClose.play()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: cancelSelectButton
                    width: parent.width
                    height: 110
                    color: selectGamesMenu.currentButtonIndex === 5 ? "white" : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Cancel"
                        color: selectGamesMenu.currentButtonIndex === 5 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (selectGamesMenu.currentButtonIndex !== 5) {
                                selectGamesMenu.currentButtonIndex = 5
                                sNav.stop(); sNav.play()
                            } else {
                                root.searchQuery = ""
                                root.toggleSelectGamesMenu()
                                sLeftClose.play()
                            }
                        }
                    }
                }
            }
        }

        Keys.onPressed: {
            if (selectGamesMenuVisible && selectGamesMenu.focus) {
                if (event.key === Qt.Key_Up) {
                    if (currentButtonIndex > 0) {
                        currentButtonIndex--
                        // Перескок невидимых кнопок
                        while (currentButtonIndex > 0 && !buttons[currentButtonIndex].visible) {
                            currentButtonIndex--
                        }
                        sNav.stop(); sNav.play()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    if (currentButtonIndex < 5) {
                        currentButtonIndex++
                        // Перескок невидимых кнопок
                        while (currentButtonIndex < 5 && !buttons[currentButtonIndex].visible) {
                            currentButtonIndex++
                        }
                        sNav.stop(); sNav.play()
                    }
                    event.accepted = true
                } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    var btn = buttons[currentButtonIndex]
                    if (btn && btn.visible) {
                        if (currentButtonIndex === 0) {
                            keyboardContainer.visible = true
                            keyboardContainer.focus = true
                            keyboardContainer.cursorPosition = root.searchQuery.length
                            keyboardContainer.forceActiveFocus()
                            sShowui.play()
                        } else if (currentButtonIndex === 1) {
                            root.searchQuery = ""
                            root.selectedGameForGrid = null
                            root.updateGridModel()
                            root.toggleSelectGamesMenu()
                            sLeftClose.play()
                        } else if (currentButtonIndex === 2) {
                            if (root.recentGames.length >= 1) {
                                root.selectedGameForGrid = root.recentGames[0]
                                root.updateGridModel()
                                root.toggleSelectGamesMenu()
                                sLeftClose.play()
                            }
                        } else if (currentButtonIndex === 3) {
                            if (root.recentGames.length >= 2) {
                                root.selectedGameForGrid = root.recentGames[1]
                                root.updateGridModel()
                                root.toggleSelectGamesMenu()
                                sLeftClose.play()
                            }
                        } else if (currentButtonIndex === 4) {
                            if (root.recentGames.length >= 3) {
                                root.selectedGameForGrid = root.recentGames[2]
                                root.updateGridModel()
                                root.toggleSelectGamesMenu()
                                sLeftClose.play()
                            }
                        } else if (currentButtonIndex === 5) {
                            root.searchQuery = ""
                            root.toggleSelectGamesMenu()
                            sLeftClose.play()
                        }
                    }
                    event.accepted = true
                } else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                    root.searchQuery = ""
                    root.toggleSelectGamesMenu()
                    sLeftClose.play()
                    event.accepted = true
                }
            }
        }

                onVisibleChanged: {
            if (visible) {
                forceActiveFocus()
                sShowui.play()
                
                // Принимаем игру из gamemenu
                if (theme.selectedGameForMedia) {
                    root.selectedGameForGrid = theme.selectedGameForMedia
                    theme.selectedGameForMedia = null // Сразу очищаем
                } else {
                    root.selectedGameForGrid = null
                }              
            }
        }
    }


    // ---- КЛАВИАТУРА (скопирована из search.qml и адаптирована) ----
    FocusScope {
        id: keyboardContainer
        anchors.fill: parent
        visible: false
        focus: false
        z: 10000001
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        property int r: 2
        property int c: 5
        property bool isCaps: false
        property int cursorPosition: 0

        onVisibleChanged: {
            if (visible) {
                opacity = 1
                kbPanel.anchors.bottomMargin = 0
                // блокируем фокус с меню
            } else {
                opacity = 0
                kbPanel.anchors.bottomMargin = -kbPanel.height
                // возвращаем фокус на меню
                if (selectGamesMenuVisible) {
                    selectGamesMenu.forceActiveFocus()
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                keyboardContainer.visible = false
                keyboardContainer.focus = false
            }
        }

        // Скрытый помощник для буфера обмена
        TextEdit {
            id: clipboardHelper
            visible: false
            function getClipboard() {
                text = ""
                paste()
                return text
            }
        }

        function processInput(v) {
            if (!v || v === "") return
            if (v === "Done") {
                keyboardContainer.visible = false
                keyboardContainer.focus = false
                if (selectGamesMenuVisible) {
                    selectGamesMenu.forceActiveFocus()
                }
                return
            }

            var cur = root.searchQuery
            var maxLength = 35

            if (v === "paste") {
                var clipboardText = clipboardHelper.getClipboard()
                if (clipboardText) {
                    clipboardText = clipboardText.replace(/[\r\n\t]+/g, " ")
                    var availableSpace = Math.max(0, maxLength - cur.length)
                    var textToInsert = clipboardText.substring(0, availableSpace)
                    root.searchQuery = cur.substring(0, cursorPosition) + textToInsert + cur.substring(cursorPosition)
                    cursorPosition += textToInsert.length
                }
                return
            }

            if (v === "caps") {
                isCaps = !isCaps
            } else if (v === "backspace") {
                if (cursorPosition > 0) {
                    root.searchQuery = cur.substring(0, cursorPosition - 1) + cur.substring(cursorPosition)
                    cursorPosition--
                }
            } else if (v === "left") {
                if (cursorPosition > 0) cursorPosition--
            } else if (v === "right") {
                if (cursorPosition < cur.length) cursorPosition++
            } else {
                if (cur.length < maxLength) {
                    var letter = (v.length === 1 && isCaps) ? v.toUpperCase() : v
                    root.searchQuery = cur.substring(0, cursorPosition) + letter + cur.substring(cursorPosition)
                    cursorPosition += letter.length
                }
            }
            // обновить фильтрацию после изменения searchQuery
            root.updateFilteredGames()
        }

        Rectangle {
            id: kbPanel
            width: parent.width
            height: 405
            color: "#22262F"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -height

            Behavior on anchors.bottomMargin {
                NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 4

                Repeater {
                    model: [
                        {row: 0, wSum: 15, keys: [{l:"`",v:"`"},{l:"1",v:"1"},{l:"2",v:"2"},{l:"3",v:"3"},{l:"4",v:"4"},{l:"5",v:"5"},{l:"6",v:"6"},{l:"7",v:"7"},{l:"8",v:"8"},{l:"9",v:"9"},{l:"0",v:"0"},{l:"-",v:"-"},{l:"=",v:"="},{l:"X",v:"backspace",w:2,isBS:true,isSpec:true}]},
                        {row: 1, wSum: 15, keys: [{l:"Tab",v:"   ",w:1.5,isSpec:true},{l:"Q",v:"q"},{l:"W",v:"w"},{l:"E",v:"e"},{l:"R",v:"r"},{l:"T",v:"t"},{l:"Y",v:"y"},{l:"U",v:"u"},{l:"I",v:"i"},{l:"O",v:"o"},{l:"P",v:"p"},{l:"[",v:"["},{l:"]",v:"]"},{l:"\\",v:"\\",w:1.5}]},
                        {row: 2, wSum: 15, keys: [{l:"Caps",v:"caps",w:1.8,isSpec:true},{l:"A",v:"a"},{l:"S",v:"s"},{l:"D",v:"d"},{l:"F",v:"f"},{l:"G",v:"g"},{l:"H",v:"h"},{l:"J",v:"j"},{l:"K",v:"k"},{l:"L",v:"l"},{l:";",v:";"},{l:"'",v:"'"},{l:"Enter",v:"Done",w:2.2,c:"#1A9EFF",isSpec:true}]},
                        {row: 3, wSum: 15, keys: [{l:"Shift",v:"caps",w:2.5,isSpec:true},{l:"Z",v:"z"},{l:"X",v:"x"},{l:"C",v:"c"},{l:"V",v:"v"},{l:"B",v:"b"},{l:"N",v:"n"},{l:"M",v:"m"},{l:",",v:","},{l:".",v:"."},{l:"/",v:"/"},{l:"Shift",v:"caps",w:2.5,isSpec:true}]},
                        {row: 4, wSum: 13.1, keys: [{l:"☺",v:"",w:1.2,isSpec:true},{l:" ",v:" ",w:6.5},{l:"🌐",v:"paste",w:1.2,isSpec:true},{l:"<",v:"left",w:1.2,isSpec:true},{l:">",v:"right",w:1.2,isSpec:true},{l:"Hide",v:"Done",w:1.8,isSpec:true}]}
                    ]

                    delegate: Row {
                        width: kbPanel.width - 10
                        height: 75
                        spacing: 4
                        property int rowIndex: modelData.row
                        property real tWeight: modelData.wSum

                        Repeater {
                            model: modelData.keys
                            delegate: Rectangle {
                                width: (parent.width / parent.tWeight) * (modelData.w || 1.0) - parent.spacing
                                height: parent.height
                                color: (keyboardContainer.r === parent.rowIndex && keyboardContainer.c === index) ? "white" : (modelData.isSpec ? "black" : "#0F1318")

                                MouseArea {
                                    id: keyMa
                                    anchors.fill: parent

                                    onPressed: {
                                        keyboardContainer.r = parent.parent.rowIndex
                                        keyboardContainer.c = index

                                        if (modelData.v !== "Done" && modelData.v !== "caps" && modelData.v !== "paste") {
                                            autoRepeatAnim.start()
                                        } else {
                                            keyboardContainer.processInput(modelData.v)
                                        }
                                    }

                                    onReleased: autoRepeatAnim.stop()
                                    onExited: autoRepeatAnim.stop()
                                    onCanceled: autoRepeatAnim.stop()

                                    SequentialAnimation {
                                        id: autoRepeatAnim
                                        ScriptAction { script: keyboardContainer.processInput(modelData.v) }
                                        PauseAnimation { duration: 500 }
                                        SequentialAnimation {
                                            loops: Animation.Infinite
                                            ScriptAction { script: keyboardContainer.processInput(modelData.v) }
                                            PauseAnimation { duration: 60 }
                                        }
                                    }
                                }

                                Item {
                                    anchors.fill: parent

                                    // Текст для специальных кнопок (такой же как в search.qml)
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

                                    Text {
                                        id: backspaceIcon
                                        font.family: icons.name
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.v === "backspace"
                                        font.pixelSize: 40
                                        text: theme.nintendoLayout ? (theme.universalIcons ? "У" : "Y") : (theme.universalIcons ? "Х" : "X")
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

                                    Text {
                                        id: hideIcon
                                        font.family: icons.name
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Hide" && modelData.v === "Done"
                                        font.pixelSize: 40
                                        text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B")
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

                                    Text {
                                        id: arrowText
                                        font.family: bold.name
                                        font.pixelSize: 30
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        text: {
                                            if (modelData.v === "left") return "<"
                                            if (modelData.v === "right") return ">"
                                            return ""
                                        }
                                        visible: modelData.v === "left" || modelData.v === "right"
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 10
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        id: emojiGlobeText
                                        font.family: (modelData.l === "☺") ? icons.name : bold.name
                                        font.pixelSize: (modelData.l === "☺") ? 45 : 26
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        text: {
                                            if (modelData.l === "☺") return "😀"
                                            if (modelData.l === "🌐") return "Paste"
                                            return ""
                                        }
                                        visible: modelData.l === "☺" || modelData.l === "🌐"
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: (modelData.l === "☺") ? 13 : 20
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Text {
                                        id: specTextOnly
                                        font.family: bold.name
                                        font.pixelSize: 26
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        text: {
                                            if (modelData.l === "Tab") return "Tab"
                                            if (modelData.l === "   ") return "   "
                                            return ""
                                        }
                                        visible: !!modelData.isSpec && !spaceIcon.visible && !backspaceIcon.visible &&
                                                !enterIcon.visible && !hideIcon.visible && !leftShiftText.visible &&
                                                !capsText.visible && !rightShiftIcon.visible && !arrowText.visible &&
                                                !emojiGlobeText.visible
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 10
                                        anchors.left: parent.left
                                        anchors.leftMargin: 15
                                    }

                                    Text {
                                        id: normalKeyText
                                        font.family: bold.name
                                        font.pixelSize: 26
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        text: {
                                            if (modelData.isSpec) return ""
                                            if (modelData.v.length === 1) {
                                                return keyboardContainer.isCaps ? modelData.l.toUpperCase() : modelData.l.toLowerCase()
                                            }
                                            return modelData.l
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

        Keys.onPressed: {
            var rowCounts = [14, 14, 13, 12, 6]
            if (api.keys.isLeft(event)) {
                if (c > 0) {
                    c--
                    sNav.stop(); sNav.play()
                }
                event.accepted = true
            } else if (api.keys.isRight(event)) {
                if (c < rowCounts[r] - 1) {
                    c++
                    sNav.stop(); sNav.play()
                }
                event.accepted = true
            } else if (api.keys.isUp(event)) {
                if (r > 0) {
                    r--
                    c = Math.min(c, rowCounts[r] - 1)
                    sNav.stop(); sNav.play()
                }
                event.accepted = true
            } else if (api.keys.isDown(event)) {
                if (r < 4) {
                    r++
                    c = Math.min(c, rowCounts[r] - 1)
                    sNav.stop(); sNav.play()
                }
                event.accepted = true
            } else if (api.keys.isDetails(event)) {
                processInput("backspace")
                event.accepted = true
            } else if (api.keys.isFilters(event)) {
                processInput(" ")
                event.accepted = true
            } else if (api.keys.isNextPage(event)) {
                processInput("Done")
                event.accepted = true
            } else if (api.keys.isPrevPage(event)) {
                isCaps = !isCaps
                event.accepted = true
            } else if (api.keys.isCancel(event)) {
                processInput("Done")
                event.accepted = true
            } else if (api.keys.isAccept(event)) {
                var values = [
                    ["`","1","2","3","4","5","6","7","8","9","0","-","=","backspace"],
                    ["   ","q","w","e","r","t","y","u","i","o","p","[","]","\\"],
                    ["caps","a","s","d","f","g","h","j","k","l",";","'","Done"],
                    ["caps","z","x","c","v","b","n","m",",",".","/","caps"],
                    ["",""," ","left","right","Done"]
                ]
                sType.play()
                processInput(values[r][c])
                event.accepted = true
            }
        }
    }

    // ---- LEFT BAR ----
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
                if (event.key === Qt.Key_Up) {
                    if (currentIndex > 0) {
                        currentIndex--
                        updateFocus()
                        sNav.stop()
                        sNav.play()
                        event.accepted = true
                    }
                } else if (api.keys.isMenu(event)) {
                    toggle()
                    event.accepted = true
                    root.goToZone(1)
                } else if (event.key === Qt.Key_Down) {
                    if (currentIndex < buttons.length - 1) {
                        currentIndex++
                        updateFocus()
                        event.accepted = true
                        sNav.stop()
                        sNav.play()
                    }
                } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                    if (currentIndex === 7) {
                        toggle()
                        theme.openPowerMenu() /* DECKOS: one Close menu (theme.qml) */
                        focusTimer.start()
                    } else {
                        theme.openPage(currentIndex)
                        toggle()
                        if (currentIndex === 6) {
                            sShowui.play()
                        }
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                    toggle()
                    root.goToZone(1)
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
                                theme.openPowerMenu() /* DECKOS: one Close menu (theme.qml) */
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
                            sNav.stop()
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

            currentIndex = 4
            updateFocus()
        }

        function updateFocus() {
            if (currentIndex >= 0 && currentIndex < buttons.length) {
                buttons[currentIndex].forceActiveFocus()
            }
        }

        function toggle() {
            theme.toggleLeftBar(leftBar)
        }
    }

    // ---- АНИМАЦИИ ПЕРЕХОДА ----
    property int nextPageIndex: 0

    function startExitAnimation(index) {
        nextPageIndex = index
        exitAnim.start()
    }

    Component.onCompleted: {
        enterAnim.start()
        topButtonsNames.currentIndex = 0
        focusTimer.start()
        // инициализация сетки
        updateGridModel()
        // начальные случайные игры
        updateFilteredGames()
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
    
    SequentialAnimation {
        id: fullimageAnim
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 0; duration: 225; easing.type: Easing.InQuad }
            NumberAnimation { target: animatedContent; property: "scale"; to: 0.95; duration: 225; easing.type: Easing.InQuad }
        }
    }
    
    

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            if (!root.closeMenuVisible && !root.selectGamesMenuVisible) {
                if (gridView && gridView.count > 0) {
                    gridView.currentIndex = gridView.currentIndex
                    root.goToZone(2)
                    gridView.forceActiveFocus()
                } else {
                    root.goToZone(0)
                    topButtonsNames.forceActiveFocus()
                }
            }
        }
    }
}