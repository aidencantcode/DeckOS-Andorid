import QtQuick 2.15
import QtMultimedia 5.9
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15
import SortFilterProxyModel 0.2 
import "../javascript/news.js" as NewsJS

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

property bool hasImage: {
    if (typeof gameData === "undefined" || !gameData) return false; // DECKOS: no gameData at page level

    // 1. Проверка веб-ассетов (capsule или wideCapsule)
    if (typeof api !== "undefined" && api.memory) {
        var customData = api.memory.get("custom_assets_" + gameData.title);
        if (customData && customData.assets) {
            var hasWebCapsule = customData.assets.capsule !== "" && customData.assets.capsule !== undefined;
            var hasWebWide = customData.assets.wideCapsule !== "" && customData.assets.wideCapsule !== undefined;
            if (hasWebCapsule || hasWebWide) return true;
        }
    }

    // 2. Проверка локальных метаданных
    var hasLocalPoster = !!(gameData.assets && (gameData.assets.poster || gameData.assets.boxFront));
    var hasLocalSteam = !!(gameData.assets && gameData.assets.steam);

    return hasLocalPoster || hasLocalSteam;
}


    
    // Виртуальная высота страницы теперь 1.5 экрана
property real pageHeight: root.height * 1.9
property real topH: 95
property bool safeAltHomeScreen: theme ? theme.alternativeHomeScreen : false
property int safeGameListSize: theme ? theme.gameListSize : 2
property real middleH: root.safeAltHomeScreen ? (root.height * 0.91) : (root.height * (0.635 + (root.safeGameListSize - 1.5) * 0.08125))
property real bottomH: pageHeight - topH - middleH

// Свойства для анимации переключения табов в нижней зоне
property int bottomCurrentTab: 0
property real bottomAnimX: 0
property real bottomAnimOpacity: 1.0

    // current focus zone: 0 = top, 1 = middle, 2 = bottom
    property int focusZone: 1
    // DECKOS: off for a moment on return to the front, which restarts the selection highlight (resumeFocus)
    property bool highlightOn: true
    property var theme
    // для навигации по кнопкам What's New (1-4)
property int newsListFocusHelper: 1
    
    // меню опций
property bool optionsMenuVisible: false
property var currentFocusedGame: null

// меню закрытия (новое)
property bool closeMenuVisible: false
property var newsData: []

property bool isBottomZoneMerged: false






    SoundEffect { id: sNav; source: "../assets/audio/nav.wav"; volume: 1.0 }
    SoundEffect { id: sAccept; source: "../assets/audio/accept.wav"; volume: 1.0 }
    SoundEffect { id: sBack; source: "../assets/audio/back.wav"; volume: 1.0 }
    SoundEffect { id: sLeftOpen; source: "../assets/audio/deck_ui_side_menu_fly_in.wav"; volume: 1.0 }
    SoundEffect { id: sLeftClose; source: "../assets/audio/deck_ui_side_menu_fly_out.wav"; volume: 1.0 }
    SoundEffect { id: sShowui; source: "../assets/audio/deck_ui_show_ui.wav"; volume: 1.0 }

// Анимация переключения табов в BottomZone
SequentialAnimation {
    id: bottomTabAnim
    property int targetIdx: 0
    property int direction: 1 // 1 для Next, -1 для Prev
    
    // Кадр 1: Старый контент уходит
    ParallelAnimation {
        NumberAnimation { 
            target: root; 
            property: "bottomAnimOpacity"; 
            to: 0.2; 
            duration: 100
        }
        NumberAnimation { 
            target: root; 
            property: "bottomAnimX"; 
            to: -listsContainer.width * 0.2 * bottomTabAnim.direction; 
            duration: 150; 
            easing.type: Easing.OutQuad 
        }        
    }
    
    // Кадр 2: Мгновенная подмена
    ScriptAction {
        script: {
            root.bottomCurrentTab = bottomTabAnim.targetIdx
            bottomTabsRow.currentIndex = bottomTabAnim.targetIdx
            root.bottomAnimX = listsContainer.width * 0.2 * bottomTabAnim.direction
        }
    }
    
    // Кадр 3: Новый контент встает на место
    ParallelAnimation {
        NumberAnimation { 
            target: root; 
            property: "bottomAnimOpacity"; 
            to: 1.0; 
            duration: 250
        }
        NumberAnimation { 
            target: root; 
            property: "bottomAnimX"; 
            to: 0; 
            duration: 500; 
            easing.type: Easing.OutExpo
        }
    }
}

// Функция для безопасного переключения табов
function safeBottomNav(newIdx) {
    if (newIdx === bottomCurrentTab) return;
    
    if (bottomTabAnim.running) {
        bottomTabAnim.stop();
    }
    
    bottomTabAnim.direction = (newIdx > bottomCurrentTab) ? 1 : -1;
    bottomTabAnim.targetIdx = newIdx;
    bottomTabAnim.start();
}

function toggleOptionsMenu() {
    if (optionsMenuVisible) {
        // ЗАКРЫТИЕ
        optionsMenuVisible = false
        optionsMenu.focus = false
        
        // Возвращаем фокус в зону с играми
        if (focusZone === 1) {
            gameList.forceActiveFocus()
        }
    } else if (focusZone === 1 && gameList.focus) {
        // ОТКРЫТИЕ — только если в фокусе список игр
        // Проверяем, что есть игры и текущий индекс не указывает на плейсхолдер
        if (middleSorted.count > 0 && gameList.currentIndex < middleSorted.count) {
            
            // Получаем индекс в отсортированном списке
            var proxyIndex = gameList.currentIndex
            
            // Преобразуем его в индекс ГЛАВНОГО списка (api.allGames)
            var sourceIndex = middleSorted.mapToSource(proxyIndex)
            
            // Получаем НАСТОЯЩИЙ объект игры из api.allGames
            currentFocusedGame = api.allGames.get(sourceIndex)
            
            if (currentFocusedGame) {
                // Снимаем фокус со всех элементов
                topButtonsRow.focus = false
                gameList.focus = false
                bottomTabsRow.focus = false
                newsList.focus = false
                friendsList.focus = false
                recommendedList.focus = false
                
                // Открываем меню и даём ему фокус
                optionsMenuVisible = true
                optionsMenu.forceActiveFocus()
            }
        }
    }
}

    
    // фильтр 1 игры
    property string lastGameTitle: ""

    function goToZone(zoneIndex) {
    if (zoneIndex < 0) zoneIndex = 0
    if (zoneIndex > 2) zoneIndex = 2
    
    
    // Снимаем фокус со ВСЕХ элементов
    topButtonsRow.focus = false
    gameList.focus = false
    bottomTabsRow.focus = false
    newsList.focus = false
    friendsList.focus = false
    recommendedList.focus = false
    
    focusZone = zoneIndex
    
    // Прокрутка Flickable в зависимости от зоны
    var targetY = 0
    if (zoneIndex === 1) targetY = 0 // Средняя зона - В САМОЕ НАЧАЛО
    else if (zoneIndex === 2) targetY = topH + (middleH * 0.78) // Нижняя зона
    
    // Плавный скролл (только для middle и bottom зон)
    if (zoneIndex !== 0) {
        flick.contentY = targetY
    }
    
    // Устанавливаем фокус ТОЛЬКО на одну зону
    if (zoneIndex === 0) {
        topButtonsRow.forceActiveFocus()
        topButtonsRow.focus = true
    }
    else if (zoneIndex === 1) {
        gameList.forceActiveFocus()
        gameList.focus = true
        if (gameList.count > 0) gameList.currentIndex = 0
    }
    else if (zoneIndex === 2) {
        bottomTabsRow.forceActiveFocus()
        bottomTabsRow.focus = true
        // Автоматически фокусируемся на активном списке в зависимости от выбранного таба
        if (bottomTabsRow.currentIndex === 0) newsList.forceActiveFocus()
        else if (bottomTabsRow.currentIndex === 1) friendsList.forceActiveFocus()
        else if (bottomTabsRow.currentIndex === 2) recommendedList.forceActiveFocus()
    }
}

    // Поведение (анимация) для плавного скролла
    Behavior on pageHeight { NumberAnimation { duration: 200 } }

    Rectangle { // фон
        anchors.fill: parent
        color: "#111"
    }
Item {
        id: animatedContent
        anchors.fill: parent
        
        // === ДИНАМИЧЕСКИЙ КОНТЕЙНЕР ДЛЯ ВКЛАДОК ===
Rectangle {
    id: dynamicTabsContainer
    width: parent.width
    height: 90 // Высота контейнера под вкладки (74px высота вкладок + отступы)
    z: root.isBottomZoneMerged ? 200000000000 : 6

    readonly property real naturalY: (root.middleH) - flick.contentY
y: Math.max(root.topH, naturalY)


    // Изменение цвета: черный при слиянии, прозрачный в обычном состоянии
    color: naturalY <= root.topH ? "black" : "transparent"

    onYChanged: {
        root.isBottomZoneMerged = (naturalY <= root.topH)
    }

    Behavior on color { ColorAnimation { duration: 150 } }
    
    // ТЕКСТ СЛЕВА (на уровне кнопок, смещен на 10% ниже)
Text {
    id: leftSideText
    anchors {
        left: parent.left
        leftMargin: 40
        top: bottomTabsRow.top
    }
    y: bottomTabsRow.height * 0.3 // Смещение на 10% ниже
    text: "<"
    color: "white"
    font.pixelSize: 70
    font.family: icons.name
    opacity: root.focusZone === 2 ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }
}

// ТЕКСТ СПРАВА
Text {
    id: rightSideText
    anchors {
        right: parent.right
        rightMargin: 40
        top: bottomTabsRow.top
    }
    y: bottomTabsRow.height * 0.3
    text: ">"
    color: "white"
    font.pixelSize: 70
    font.family: icons.name
    opacity: root.focusZone === 2 ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }
    horizontalAlignment: Text.AlignRight
}
    
    

    // === ВАШ РЯД ВКЛАДОК (БЕЗ ИЗМЕНЕНИЙ ВНУТРЕННЕЙ ЛОГИКИ) ===
    Row {
        id: bottomTabsRow
        spacing: 24
        anchors.centerIn: parent // Центрирование внутри нового контейнера
        property int currentIndex: 0
        property bool inContent: false
        focus: true

        // === WHAT'S NEW ===
        Rectangle {
            id: bottomFirstTab
            width: 240; height: 74
            radius: 40
            focus: false
            
            property bool isFocused: activeFocus || (bottomTabsRow.focus && bottomTabsRow.currentIndex === 0 && !bottomTabsRow.inContent)
            
            color: isFocused ? "white" : (bottomTabsRow.currentIndex === 0 ? "#31343B" : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "WHAT'S NEW"
                font.pixelSize: 25
                font.family: bold.name
                color: bottomFirstTab.isFocused ? "black" : "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (bottomTabsRow.currentIndex === 0 && bottomTabsRow.focus && !bottomTabsRow.inContent) {
                        return
                    }
                    root.safeBottomNav(0)
                    bottomTabsRow.inContent = false
                    bottomTabsRow.forceActiveFocus()
                    flick.contentY = topH + (middleH * 0.78)
                    sTab.stop();
                    sTab.play();
                }
            }
        }

        // === FRIENDS ===
        Rectangle {
            id: bottomSecondTab
            width: 240; height: 74
            radius: 40
            focus: false
            
            property bool isFocused: activeFocus || (bottomTabsRow.focus && bottomTabsRow.currentIndex === 1 && !bottomTabsRow.inContent)
            
            color: isFocused ? "white" : (bottomTabsRow.currentIndex === 1 ? "#31343B" : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "FRIENDS"
                font.pixelSize: 25
                font.family: bold.name
                color: bottomSecondTab.isFocused ? "black" : "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (bottomTabsRow.currentIndex === 1 && bottomTabsRow.focus && !bottomTabsRow.inContent) {
                        return
                    }
                    root.safeBottomNav(1)
                    bottomTabsRow.inContent = false
                    bottomTabsRow.forceActiveFocus()
                    flick.contentY = topH + (middleH * 0.78)
                    sTab.stop();
                    sTab.play();
                }
            }
        }

        // === RECOMMENDED ===
        Rectangle {
            id: bottomThirdTab
            width: 240; height: 74
            radius: 40
            focus: false
            
            property bool isFocused: activeFocus || (bottomTabsRow.focus && bottomTabsRow.currentIndex === 2 && !bottomTabsRow.inContent)
            
            color: isFocused ? "white" : (bottomTabsRow.currentIndex === 2 ? "#31343B" : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "RECOMMENDED"
                font.pixelSize: 25
                font.family: bold.name
                color: bottomThirdTab.isFocused ? "black" : "white"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (bottomTabsRow.currentIndex === 2 && bottomTabsRow.focus && !bottomTabsRow.inContent) {
                        return
                    }
                    root.safeBottomNav(2)
                    bottomTabsRow.inContent = false
                    bottomTabsRow.forceActiveFocus()
                    flick.contentY = topH + (middleH * 0.78)
                    sTab.stop();
                    sTab.play();
                }
            }
        }

        // Навигация клавишами
        Keys.onLeftPressed: {
            if (bottomTabsRow.currentIndex > 0) {
                root.safeBottomNav(bottomTabsRow.currentIndex - 1)
                bottomTabsRow.forceActiveFocus()
                sTab.stop();
                sTab.play();
            }
        }

        Keys.onRightPressed: {
            if (bottomTabsRow.currentIndex < 2) {
                root.safeBottomNav(bottomTabsRow.currentIndex + 1)
                bottomTabsRow.forceActiveFocus()
                sTab.stop();
                sTab.play();
            }
        }
        
        Keys.onDownPressed: {
            bottomTabsRow.inContent = true
            if (bottomTabsRow.currentIndex === 0) newsList.forceActiveFocus()
            else if (bottomTabsRow.currentIndex === 1) friendsList.forceActiveFocus()
            else if (bottomTabsRow.currentIndex === 2) recommendedList.forceActiveFocus()
            sNav.stop();
            sNav.play();
        }
    }
}


    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: content.height
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds 
        interactive: true
        clip: true

        // сделать плавный переход при программном изменении contentY
        Behavior on contentY { 
            NumberAnimation { 
                duration: 200 
                easing.type: Easing.OutCubic
            } 
        }

        Column {
            id: content
            width: flick.width
            height: root.pageHeight
            spacing: 0

           /* ================ MIDDLE ZONE (игры) ================ */
Rectangle {
    id: middleZone
    width: content.width
    height: root.middleH
    color: theme.highContrastHome ? "#0F1318" : "black"
    z: 5

    // ======== ФОН ========
   Item {
    id: backgroundContainer
    anchors.fill: parent
    clip: true 
    
    function isAnimated(url) {
        if (!url) return false;
        var str = url.toString().toLowerCase();
        return str.indexOf(".gif") !== -1 || str.indexOf(".webp") !== -1;
    }

    // === 1. УХОДЯЩИЙ СЛОЙ (Только статика) ===
    Item {
        id: exitAnimationLayer
        anchors.fill: parent
        opacity: 0
        z: 2 

        // DECKOS: the outgoing picture starts exactly where and as bright as it was
        // (it may still have been fading in), so the hand-over has no jump.
        property real startOpacity: 0.4

        function prepareExit(source, direction, fromOpacity, fromX) {
            exitParallelAnimation.stop();
            exitTransform.x = fromX;
            exitTransform.y = 0;
            exitStatic.source = source;
            startOpacity = fromOpacity;
            exitAnimationLayer.opacity = fromOpacity;
            exitAnimX.to = fromX + (backgroundContainer.width * 0.05) * direction;
            exitParallelAnimation.restart();
        }

        transform: Translate {
            id: exitTransform
            x: 0
            y: 0
        }

        Image {
            id: exitStatic
            width: parent.width * 1.15
            height: parent.height * 1.15
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // DECKOS: same size as staticBackground so the decoded picture comes
            // straight from the cache instead of popping in mid-fade
            sourceSize.width: 1920
            sourceSize.height: 1080
            visible: source != "" && !theme.highContrastHome
            z: 0
        }

        ParallelAnimation {
            id: exitParallelAnimation

            PropertyAnimation {
                target: exitAnimationLayer
                property: "opacity"
                from: exitAnimationLayer.startOpacity
                to: 0
                duration: 700
                easing.type: Easing.InOutQuad
            }


            PropertyAnimation {
                id: exitAnimX // Добавлен ID для управления из prepareExit
                target: exitTransform
                property: "x"
                to: -backgroundContainer.width * 0.05
                duration: 700 
                easing.type: Easing.OutCubic
            }
            
            PropertyAnimation {
                target: exitTransform
                property: "y"
                to: -backgroundContainer.height * 0.05 // Движение вверх остается неизменным
                duration: 700 
                easing.type: Easing.OutCubic
            }
            
            onStopped: {
                exitStatic.source = ""; 
            }
        }        
    }


    // === 2. ОСНОВНЫЕ ФОНЫ (Нижний слой) ===
    Image {
        id: staticBackground
        width: parent.width * 1.15
        height: parent.height * 1.15
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 1920
        sourceSize.height: 1080
        visible: source != "" && !theme.highContrastHome
        opacity: 0.4
        z: 0
        transform: Translate { x: backgroundTransform.x }
        // DECKOS: fade the new picture in once it has loaded (it used to appear at
        // full strength the moment the async load finished)
        onSourceChanged: backgroundContainer.fadeIn(staticBackground, staticFadeIn)
        onStatusChanged: if (status === Image.Ready && opacity === 0) staticFadeIn.restart()
        NumberAnimation { id: staticFadeIn; target: staticBackground; property: "opacity"; to: 0.4; duration: 650; easing.type: Easing.InOutQuad }
    }

    AnimatedImage {
        id: middleBackground
        width: parent.width * 1.15
        height: parent.height * 1.15
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: source != "" && !theme.highContrastHome
        playing: visible && status === AnimatedImage.Ready && theme.animatedCovers && (!theme.animationInFocus || root.focusZone === 1)


        cache: false
        opacity: 0.4
        z: 0
        transform: Translate { id: backgroundTransform; x: 0 }
        onSourceChanged: backgroundContainer.fadeIn(middleBackground, middleFadeIn)
        onStatusChanged: if (status === AnimatedImage.Ready && opacity === 0) middleFadeIn.restart()
        NumberAnimation { id: middleFadeIn; target: middleBackground; property: "opacity"; to: 0.4; duration: 650; easing.type: Easing.InOutQuad }
    }

    function fadeIn(img, anim) {
        anim.stop();
        img.opacity = 0;
        if (img.source != "" && img.status === Image.Ready) anim.restart();
    }

    // --- НЕПРЕРЫВНАЯ АНИМАЦИЯ ДВИЖЕНИЯ ---
    SequentialAnimation {
        id: moveFlow
        running: true 
        loops: Animation.Infinite
        
        PropertyAnimation {
            target: backgroundTransform
            property: "x"
            from: 0
            to: backgroundContainer.width * 0.02
            duration: 12000 
            easing.type: Easing.InOutSine
        }
        
        PropertyAnimation {
            target: backgroundTransform
            property: "x"
            from: backgroundContainer.width * 0.02
            to: -backgroundContainer.width * 0.02
            duration: 12000 
            easing.type: Easing.InOutSine
        }
        
        PropertyAnimation {
            target: backgroundTransform
            property: "x"
            from: -backgroundContainer.width * 0.02
            to: 0
            duration: 12000 
            easing.type: Easing.InOutSine
        }
    }


    // === 3. ОБНОВЛЕНИЕ ПРИ СМЕНЕ ИГРЫ     // === 3. ОБНОВЛЕНИЕ ПРИ СМЕНЕ ИГРЫ ===
    Connections {
        target: gameList
        property int lastIndex: 0 // Свойство для сохранения предыдущего индекса
        
        function onCurrentIndexChanged() { // DECKOS: Qt 5.15 Connections syntax
            if (gameList.currentIndex >= 0 && gameList.currentIndex < (gameList.displayCount - 1)) {
                var game = middleSorted.get(gameList.currentIndex);
                if (game && game.assets) {
                    var newBackground = theme.getAssetSource("background", game) || "";
                    
                    var currentSource = "";
                    var currentOpacity = 0.4;
                    if (middleBackground.source != "") {
                        currentSource = middleBackground.source;
                        currentOpacity = middleBackground.status === Image.Ready ? middleBackground.opacity : 0;
                    } else if (staticBackground.source != "") {
                        currentSource = staticBackground.source;
                        currentOpacity = staticBackground.status === Image.Ready ? staticBackground.opacity : 0;
                    }
                    if (currentSource != "" && currentSource == newBackground) { // same picture: nothing to cross-fade
                        lastIndex = gameList.currentIndex;
                        return;
                    }

                    // Вычисляем направление: если листаем вправо (индекс растет), фон едет влево (-1)
                    var direction = (gameList.currentIndex > lastIndex) ? -1 : 1;
                    lastIndex = gameList.currentIndex; // Обновляем индекс

                    if (currentSource != "" && currentOpacity > 0.01) {
                        exitAnimationLayer.prepareExit(currentSource, direction, currentOpacity, backgroundTransform.x);
                    }

                    var isNewAnim = backgroundContainer.isAnimated(newBackground);
                    if (isNewAnim) {
                        staticBackground.source = ""; 
                        middleBackground.source = theme.getAssetSource("background", game) || "";
                    } else {
                        middleBackground.source = ""; 
                        staticBackground.source = theme.getAssetSource("background", game) || "";;
                    }
                }
            } else {
                exitParallelAnimation.stop();
            }
        }
    }
}


    // Устанавливаем начальный фон
        Component.onCompleted: {
    // Создаем одноразовый таймер, который подождет загрузки данных
    var checkData = function() {
        if (middleSorted.count > 0) {
            var game = middleSorted.get(gameList.currentIndex);
            if (game && game.assets) {
                var asset = theme ? theme.getAssetSource("background", game) : ""; // DECKOS: theme is set after creation
                // Проверяем тип ассета и кладем в нужный слот
                if (backgroundContainer.isAnimated(asset)) {
                    middleBackground.source = asset;
                } else {
                    staticBackground.source = asset;
                }
            }
            initialLoadTimer.stop(); // Останавливаем, когда данные получены
        }
    }

    // Запускаем проверку (интервал 100мс)
    initialLoadTimer.triggered.connect(checkData);
    initialLoadTimer.start();
}

// Добавь этот объект рядом с Component.onCompleted
Timer {
    id: initialLoadTimer
    interval: 1
    repeat: true
    running: false
}



      // Градиент поверх фона
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 1.0; color: "#0F1318" }
            GradientStop { position: 0.3; color: "transparent" }
        }
        z: 4
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 1.0; color: "#0F1318" }
            GradientStop { position: 0.8; color: "transparent" }
        }
        z: 10
    }

    property real innerH: root.safeAltHomeScreen
        ? (260 + (root.safeGameListSize - 1) * 60)
        : (middleZone.height - middleZone.vMargin - 150)
    property real vMargin: middleZone.height * 0.3

    // ======== Сортировка и фильтрация ========
SortFilterProxyModel {
    id: middleSorted
    sourceModel: api.allGames

    sorters: RoleSorter {
        roleName: "lastPlayed"
        sortOrder: Qt.DescendingOrder
    }

    // DECKOS: bumped when the order changes (a game was just played): the tiles look their game up again.
    // Their binding only followed `count`, so they kept the old order while A opened the new one.
    property int revision: 0
    onLayoutChanged: revision++
    onModelReset: revision++
    onRowsMoved: revision++
 }

    // ======== Список игр ========
    ListView {
        id: gameList
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 60
            rightMargin: 45
            topMargin: root.safeAltHomeScreen ? (middleZone.height - middleZone.innerH - 70) : middleZone.vMargin
        }
        height: middleZone.innerH
        orientation: ListView.Horizontal
        spacing: 33
        clip: false
                // Моделью становится число: количество игр + 1 (максимум 11)
        model: Math.min(11, (middleSorted.count + 1))
        property int currentIndex: 0
        property int displayCount: count                 
z: 5
// DECKOS: only animateToIndex scrolls the row. ListView's own highlight range and arrow keys moved its
// internal current item (this currentIndex shadows it) and scrolled the row away from the selection.
highlightRangeMode: ListView.NoHighlightRange
keyNavigationEnabled: false
cacheBuffer: 100000 // all (at most 11) tiles exist, so their real positions are known (scrollTarget)
onWidthChanged: snapLater() // DECKOS: updateScrollPosition() belongs to the news list
onHeightChanged: snapLater() // the tiles' widths follow the height
onCountChanged: snapLater()
onOriginXChanged: if (!moving && !scrollAnim.running) snapLater()

onCurrentIndexChanged: {
    animateToIndex(currentIndex)
}

NumberAnimation {
    id: scrollAnim
    target: gameList
    property: "contentX"
    duration: 300
    easing.type: Easing.OutCubic
}

// DECKOS: where the row scrolls to center tile idx, from the tiles' real positions. StMini computed them
// from 0, but Qt can lay the row out from a shifted origin: when Home was rebuilt (after Settings) the
// tiles had no size yet, and when DeckOS came back the window could change size. The row then sat on
// empty space - the icons "vanished" and a tap on View more scrolled instead of opening the Library.
function scrollTarget(idx) {
    var it = itemAtIndex(idx)
    var x, w
    if (it) {
        x = it.x
        w = it.width
    } else { // not built yet: StMini's layout, from the row's origin
        var wideW = height * 92 / 43, normalW = height * 6 / 9
        x = originX + (idx === 0 ? 0 : wideW + spacing + (idx - 1) * (normalW + spacing))
        w = idx === 0 ? wideW : normalW
    }
    var first = itemAtIndex(0), last = itemAtIndex(count - 1)
    var minX = first ? first.x : originX
    var maxX = Math.max(minX, last ? last.x + last.width - width : minX + contentWidth - width)
    return Math.max(minX, Math.min(maxX, x - width / 2 + w / 2))
}

function animateToIndex(idx) {
    if (idx < 0 || idx >= count || width <= 0 || height <= 0) return;
    scrollAnim.stop();
    scrollAnim.to = scrollTarget(idx);
    scrollAnim.start();
}

// at once, without the animation: after a layout change, or when Home is shown again
function snapToIndex(idx) {
    if (idx < 0 || idx >= count || width <= 0 || height <= 0) return;
    forceLayout()
    scrollAnim.stop();
    contentX = scrollTarget(idx);
}

property bool snapPending: false
function snapLater() {
    if (snapPending) return
    snapPending = true
    Qt.callLater(function () { snapPending = false; snapToIndex(currentIndex) })
}
        
// === ИСПРАВЛЕННЫЙ БЛОК: Получение ИСХОДНОГО объекта игры ===
Keys.onPressed: {
    if (api.keys.isAccept(event) && gameList.focus) {
        if (gameList.count > 0) {
            
            // 1. Проверка на плейсхолдер (всегда последний в списке)
            if (gameList.currentIndex === gameList.count - 1) {            
                theme.openPage(1) 
                event.accepted = true
                return
            }
            
            // 2. Получаем индекс исходной модели через mapToSource
            var sourceIndex = middleSorted.mapToSource(gameList.currentIndex)
            
            // 3. Берем ЖИВОЙ объект из api.allGames (а не из прокси!)
            var gameData = api.allGames.get(sourceIndex)
            
            if (gameData) {
                // Передаем настоящий объект, который понимает движок
                theme.currentGame = gameData
                theme.openPage(8)
                event.accepted = true
            }            
        }
    }
}

// ==========================================================
        
        Keys.onLeftPressed: {
        if (gameList.currentIndex > 0) {
            gameList.currentIndex--
            event.accepted = true
            sNav.stop();
sNav.play();

        }
    }
    
    Keys.onRightPressed: {
        if (gameList.currentIndex < gameList.displayCount - 1) {
        gameList.currentIndex++
        event.accepted = true
        sNav.stop();
sNav.play();

    }
    }
    
    

                        delegate: Item {
    id: gameDelegate

    // 1. ПРАВИЛЬНЫЙ объект игры
    property var modelData: middleSorted.revision >= 0 && index < middleSorted.count ? api.allGames.get(middleSorted.mapToSource(index)) : null
    property bool isGrayPlaceholder: index === (gameList.count - 1)
    property bool isWide: index === 0
    property real dH: gameList.height
    property real scaleFactor: index === gameList.currentIndex && gameList.focus ? 1.04 : 1.0

    // 2. СИНХРОНИЗИРОВАННАЯ проверка изображения (как в Bottom Zone)
    // Используем theme.getAssetSource, так как это конечная инстанция истины
    property string posterSource: {
        if (isGrayPlaceholder || !modelData) return ""
        return isWide ? theme.getAssetSource("steam", modelData) : theme.getAssetSource("poster", modelData)
    }
    property bool hasImg: posterSource !== ""

    visible: true
    height: dH
    width: isWide ? dH * 92 / 43 : dH * 6 / 9

    // ======== Контейнер игры ========
Rectangle {
    id: gameContainer
    anchors.fill: parent
    radius: theme.roundedCovers ? 24 : 0
    
    // Серый фон виден ТОЛЬКО если это игра и у неё НЕТ картинки
    color: (isGameItem && !hasImg) ? "#555" : (isGrayPlaceholder ? "#AA2A2E35" : "transparent")
    
    // Вспомогательное свойство для читаемости
    property bool isGameItem: !isGrayPlaceholder && modelData !== null

    scale: scaleFactor
    Behavior on scale { NumberAnimation { duration: 150 } }

    // Изображение
    AnimatedImage {
        id: gamePoster
        anchors.fill: parent
        source: posterSource
        fillMode: AnimatedImage.PreserveAspectCrop
        playing: visible && status === AnimatedImage.Ready && theme.animatedCovers && (!theme.animationInFocus || (index === gameList.currentIndex && root.focusZone === 1))
        cache: true
        asynchronous: true
        // Видно только если это игра и путь к картинке найден
        visible: !isGrayPlaceholder && hasImg
        z: 10
        
        // Скругление через графический слой и маску
        layer.enabled: theme.roundedCovers
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: gamePoster.width
                height: gamePoster.height
                radius: gameContainer.radius
            }
        }
    }

        // Текст названия игры (внутри карточки)
        Text {
            id: gameTitleText
            anchors.centerIn: parent
            // Берем название из modelData
            text: (modelData && modelData.title) ? modelData.title : ""
            color: "white"
            font.pixelSize: 26
            font.family: bold.name 
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            width: parent.width * 0.9
            // Виден ТОЛЬКО если это реальная игра, но картинка НЕ загрузилась
            visible: !isGrayPlaceholder && modelData !== null && !hasImg
            z: 11
        }
                
                // ======== ИНДИКАТОР FAVORITES ========
Rectangle {
    id: favoritesIndicator
    anchors {
        right: parent.right
        bottom: parent.bottom
        rightMargin: 2
        bottomMargin: 2
    }
    width: 110
    height: 55
    radius: 45
    color: "#0F1318"
    visible: modelData && modelData.favorite === true && !isGrayPlaceholder && index === gameList.currentIndex
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

                // Текст для плейсхолдера
Text {
    anchors.centerIn: parent
    text: "View more 
in your 
Library"
    color: "white"
    font.pixelSize: 40
    font.family: bold.name
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    visible: isGrayPlaceholder
}


                // Обводка активного элемента (ТОЛЬКО когда в фокусе)
                Rectangle {
                    id: highlightBorder
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 5
                    border.color: "grey"
                    radius: theme.roundedCovers ? 32 : 0
                    anchors.margins: -10
                    opacity: (index === gameList.currentIndex && root.focusZone === 1 && root.highlightOn) ? 1.0 : 0.0
                    visible: !leftBar.isOpen && !optionsMenuVisible && !root.closeMenuVisible && opacity > 0
                    z: 20

                    // ======== Анимация появления + «прыжок» ========
                    SequentialAnimation {
                        id: appearAnim
                        running: (index === gameList.currentIndex && root.focusZone === 1 && root.highlightOn)
                        loops: 1

                        // Фаза 1: растёт больше нужного
                        ParallelAnimation {
                            NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                            NumberAnimation { target: highlightBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.OutBack }
                            NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -17; duration: 200; easing.type: Easing.OutBack }
                            ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 200 }
                            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 200 }
                        }

                        // Фаза 2: «сжимается» до финального размера
                        ParallelAnimation {
                            NumberAnimation { target: highlightBorder; property: "radius"; to: theme.roundedCovers ? 32 : 2; duration: 200; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -10; duration: 200; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: highlightBorder; property: "border.width"; to: 5; duration: 200; easing.type: Easing.OutBack }
                        }

                        // Фаза 3: мигание
                        SequentialAnimation {
                            loops: Animation.Infinite
                            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.2; duration: 500 }
                            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 500 }
                        }
                    }
                }
            }

            // ======== Название под игрой (или НАД игрой в Alternative Home Screen) ========
Column {
    id: titleColumn
    Component.onCompleted: parent = middleZone 
    z: 110 
    
    // 1. Жесткая привязка по X
    x: gameDelegate.x - gameList.contentX + 60 - 7
    
    // 2. Базовая позиция по Y + смещение для анимации
    property real appearanceOffset: visible ? 0 : 15 
    y: root.safeAltHomeScreen
        ? (gameList.y - height - 30 - appearanceOffset)
        : (gameList.y + gameDelegate.height + 25 + appearanceOffset)
    
    // 3. Анимируем только смещение!
    Behavior on appearanceOffset {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutQuad
        }
    }
    
    // 4. Плавность прозрачности
    Behavior on opacity { 
        NumberAnimation { duration: 300 } 
    }
    
    // Условие видимости
    visible: (index === gameList.currentIndex && gameList.focus && !leftBar.isOpen && !optionsMenuVisible)
    opacity: visible ? 1 : 0
    spacing: 5 // Расстояние между строками
    
    // Основное название игры
Text {
    id: gameTitleUnder
    text: isGrayPlaceholder ? "" : (modelData && modelData.title ? modelData.title : ("Game " + (index + 1)))
    color: "white"
    font.pixelSize: 38
    font.family: extrabold.name
}

// === ДОБАВЬТЕ ЭТОТ КОМПОНЕНТ ПОД ТЕКСТОМ С НАЗВАНИЕМ ИГРЫ ===
// Контейнер для иконки и текста Last Played
Row {
    id: lastPlayedRow
    spacing: 11 // Расстояние между треугольником и текстом
    visible: (index === gameList.currentIndex && gameList.focus && !leftBar.isOpen && !optionsMenuVisible && !isGrayPlaceholder)
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200 } }
    
    // ЗЕЛЁНЫЙ ТРЕУГОЛЬНИК
    Text {
        id: triangleIcon
        text: "♥︎" // Unicode символ треугольника
        color: "#54B63D" // Зелёный цвет
        font.pixelSize: 30 // Размер поменьше чем у текста
        font.family: icons.name
        anchors.verticalCenter: parent.verticalCenter
    }
    
    // Текст с информацией о Last Played
    Text {
        id: lastPlayedText
        text: getLastPlayedText(modelData)
        color: "white" // Серый цвет для подписи
        font.pixelSize: 27
        opacity: 0.5
        font.family: extrabold.name
        anchors.verticalCenter: parent.verticalCenter
        
        function getLastPlayedText(game) {
            // DECKOS: still running behind DeckOS (PServer / root), like Steam's "Running"
            if (game && deckos.ingame && deckos.ingame.running
                && (deckos.ingame.runningGame === game || game.title === deckos.ingame.runningTitle)) return "RUNNING"
            // DECKOS: a never-launched game has an invalid date (truthy, NaN arithmetic): was "PLAYED JUST NOW"
            if (!game || !game.lastPlayed || game.playCount === 0) return "NEVER PLAYED"
            var lastPlayed = new Date(game.lastPlayed)
            if (isNaN(lastPlayed.getTime()) || lastPlayed.getFullYear() < 1980) return "NEVER PLAYED"

            var now = new Date()
            var diffMs = now - lastPlayed
            var diffMins = Math.floor(diffMs / 60000)
            var diffHours = Math.floor(diffMins / 60)
            var diffDays = Math.floor(diffHours / 24)
            var diffWeeks = Math.floor(diffDays / 7)
            var diffMonths = Math.floor(diffDays / 30)
            var diffYears = Math.floor(diffDays / 365)
            
            if (diffYears > 0) {
                return diffYears === 1 ? "PLAYED 1 YEAR AGO" : "PLAYED " + diffYears + " YEARS AGO"
            } else if (diffMonths > 0) {
                return diffMonths === 1 ? "PLAYED 1 MONTH AGO" : "PLAYED " + diffMonths + " MONTHS AGO"
            } else if (diffWeeks > 0) {
                return diffWeeks === 1 ? "PLAYED 1 WEEK AGO" : "PLAYED " + diffWeeks + " WEEKS AGO"
            } else if (diffDays > 0) {
                return diffDays === 1 ? "PLAYED YESTERDAY" : "PLAYED " + diffDays + " DAYS AGO"
            } else if (diffHours > 0) {
                return diffHours === 1 ? "PLAYED 1 HOUR AGO" : "PLAYED " + diffHours + " HOURS AGO"
            } else if (diffMins > 0) {
                return diffMins === 1 ? "PLAYED 1 MINUTE AGO" : "PLAYED " + diffMins + " MINUTES AGO"
            } else {
                return "PLAYED JUST NOW"
            }
        }
    }
}
}



 // Размытие для игр 
Rectangle {
    width: 1111
    height: 500
    scale: isWide ? 2: 1
    color: "transparent"
    clip: true
    visible: (index === gameList.currentIndex && gameList.focus && !leftBar.isOpen && !optionsMenuVisible && !isGrayPlaceholder)
    opacity: visible ? 0.5 : 0
    x: -445
    y: isWide? parent.height- 250 : parent.height - 185
    z: -2
    
    Image {
        width: parent.width * 200
        height: parent.height * 200
        x: -parent.width * 1
        y: -parent.height * 1
        source: theme.getAssetSource("steam", modelData)
        fillMode: Image.PreserveAspectCrop
    }
    
    // Анимации
    
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }
    
    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Item {
            width: 200
            height: 200
            
            Canvas {
                anchors.fill: parent
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    
                    // Создаем радиальный градиент
                    var gradient = ctx.createRadialGradient(
                        width/2, height/2, 0,        // центр
                        width/2, height/2, width/2   // внешний радиус
                    )
                    
                    gradient.addColorStop(0.0, "white")
                    gradient.addColorStop(0.5, "#40FFFFFF")
                    gradient.addColorStop(1.0, "transparent")
                    
                    ctx.fillStyle = gradient
                    ctx.fillRect(0, 0, width, height)
                }
            }
        }
    }
}
// Текст над первой игрой (скрывается в Alternative Home Screen)
            Text {
                visible: index === 0 && !root.safeAltHomeScreen
                text: "Recent games"
                color: "white"
                font.pixelSize: 47
                font.family: extrabold.name
                anchors.bottomMargin: 0
                z:3
                x: -7
                y: -middleZone.vMargin * 0.4
            }
            
            
            // ======== Управление ========
MouseArea {
    anchors.fill: parent
    property bool isHolding: false
    property Timer holdTimer: Timer {
        interval: 1000 // 3 секунды
        repeat: false
        onTriggered: {
            if (parent.isHolding && !parent.parent.isGrayPlaceholder) {
                root.currentFocusedGame = modelData
                root.toggleOptionsMenu()
            }
        }
    }
    
    onPressAndHold: {
    if (!isGrayPlaceholder && gameList.moving === false) {
        root.currentFocusedGame = modelData
        root.toggleOptionsMenu()
    }
}
    
    onReleased: {
        // Останавливаем таймер при отпускании
        isHolding = false
        holdTimer.stop()
    }
    
    onClicked: {
        if (!holdTimer.running) { // Только если не было удержания
            // DECKOS: a tap opens the tile at once, like touch on the Deck - it took a second tap (and
            // a third while the row sat on empty space, see scrollTarget). Selected first, so B comes
            // back to it.
            if (root.focusZone !== 1) root.goToZone(1)
            gameList.currentIndex = index
            gameList.forceActiveFocus()
            if (isGrayPlaceholder) {
                theme.openPage(1)
            } else if (modelData) {
                theme.currentGame = modelData
                theme.openPage(8)
            }
        }
    }
}
        }
    }
} // middleZone


// ================= BOTTOM ZONE (вкладки + новости) =================
Rectangle {
    id: bottomZone
    width: content.width
    height: root.bottomH
    color: "#0F1318"
    z: 10
    
    Item { // DECKOS: was a Column whose children use anchors (Column ignored them and warned)
        anchors.fill: parent
        anchors.margins: 36
        // spacing: 30 (DECKOS: Item has no spacing)

        // Контейнер для списков
        Item {
    id: listsContainer
    anchors.top: parent.top 
    anchors.topMargin: bottomTabsRow.currentIndex === 0 ? 150:210
    width: parent.width
    height: bottomZone.height * 0.6
    
    // ДОБАВЬ ЭТИ СТРОКИ:
    x: root.bottomAnimX
    opacity: root.bottomAnimOpacity
    Behavior on x { enabled: false } // Отключаем стандартное поведение
    Behavior on opacity { enabled: false }

 // ======== WHAT'S NEW (Динамический список) ========
ListView {
    id: newsList
    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        bottom: parent.bottom
        leftMargin: 60
        rightMargin: 45
    }
    orientation: ListView.Horizontal
    spacing: 30
    clip: false
    visible: bottomTabsRow.currentIndex === 0
    model: root.newsData

    highlightMoveDuration: 0
    highlightRangeMode: ListView.NoHighlightRange
    interactive: false 
    onWidthChanged: updateScrollPosition()

    property real itemWidth: (width - (spacing * 2.3)) / 3.3

    onCurrentIndexChanged: {
        animateNewsToIndex(currentIndex)
    }

    NumberAnimation {
        id: newsScrollAnim
        target: newsList
        property: "contentX"
        duration: 300
        easing.type: Easing.OutCubic
    }

    function animateNewsToIndex(idx) {
        if (idx < 0 || idx >= count) return;

        var itemW = newsList.itemWidth;
        var sp = newsList.spacing;

        var itemX = idx * (itemW + sp);
        var totalContentWidth = count * (itemW + sp);
        var maxTargetX = Math.max(0, totalContentWidth - width);
        var targetX = itemX - (width / 2) + (itemW / 2);

        if (targetX < 0) targetX = 0;
        if (targetX > maxTargetX) targetX = maxTargetX;

        newsScrollAnim.stop();
        newsScrollAnim.to = targetX;
        newsScrollAnim.start();
    }

    function updateScrollPosition() {
        animateNewsToIndex(currentIndex)
    }

    onFocusChanged: {
        if (focus) {
            flick.contentY = topH + (middleH * 0.78)
        }
    }

    Keys.onLeftPressed: {
        if (currentIndex > 0) {
            currentIndex--
            flick.contentY = topH + (middleH * 0.78)
            sNav.stop(); sNav.play();
        }
    }
    Keys.onRightPressed: {
        if (currentIndex < count - 1) {
            currentIndex++
            flick.contentY = topH + (middleH * 0.78)
            sNav.stop(); sNav.play();
        }
    }
    Keys.onUpPressed: {
        bottomTabsRow.inContent = false
        bottomTabsRow.forceActiveFocus()
        sNav.stop(); sNav.play();
    }
    Keys.onPressed: {
    if (api.keys.isAccept(event)) {
        if (currentIndex >= 0 && currentIndex < count) {
            root.openNewsDetail(root.newsData[currentIndex], currentIndex)
        }
        event.accepted = true
    }
}

    delegate: Item {
        width: newsList.itemWidth
        height: width 
        
        Text {
            text: "news"
            color: "#B0B398"
            font.pixelSize: 25
            font.family: bold.name
            font.capitalization: Font.AllUppercase
            anchors.bottom: parent.top
            anchors.bottomMargin: 20
        }

        Rectangle {
            anchors.fill: parent
            color: "#32353C"
            scale: newsList.currentIndex === index && newsList.focus ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: 150 } }

            Rectangle {
                id: imgPart
                anchors.top: parent.top
                width: parent.width
                height: parent.height * 0.56 
                color: "#1A1E25"
                clip: true

                Image {
                    anchors.fill: parent
                    source: modelData.image || "../assets/news/new.jpg"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                
                Rectangle {
                id: blueOverlay
                anchors.fill: parent
                color: "#0A1C59"
                opacity: newsList.currentIndex === index && newsList.focus ? 0.8 : 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            Text {
                id: newsText
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                    topMargin: newsList.currentIndex === index && newsList.focus ? 12 : 50
                }
                text: modelData.desc || ""
                color: "white"
                font.pixelSize: 26
                wrapMode: Text.WordWrap
                maximumLineCount: 12
                elide: Text.ElideRight
                opacity: newsList.currentIndex === index && newsList.focus ? 0.95 : 0
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on anchors.topMargin { NumberAnimation { duration: 340; easing.type: Easing.OutQuad } }
            }
            }

            Column {
                anchors {
                    top: imgPart.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 15
                }
                spacing: 5

                Row {
                    width: parent.width
                    spacing: 6
                    
                    Text {
                        id: pubLabel
                        text: "PUBLISHED"
                        color: "lightgrey"
                        font.pixelSize: 23
                    }
                    
                    Text {
                        text: modelData.pubDate || ""
                        color: "grey"
                        font.pixelSize: 23
                        elide: Text.ElideRight
                        width: parent.width - pubLabel.width - parent.spacing
                    }
                }

                Text {
                    text: modelData.title || ""
                    color: "white"
                    font.pixelSize: 26
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Rectangle {
                id: newsBorder
                anchors.fill: parent
                color: "transparent"
                border.width: 4
                border.color: "grey"
                radius: 0
                anchors.margins: -7
                opacity: (newsList.currentIndex === index && newsList.focus) ? 0.5 : 0.0
                visible: opacity > 0

                SequentialAnimation {
                    id: appearAnim
                    running: (newsList.currentIndex === index && newsList.focus)
                    loops: 1

                    ParallelAnimation {
                        NumberAnimation { target: newsBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: newsBorder; property: "radius"; to: 0; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: newsBorder; property: "anchors.margins"; to: -17; duration: 200; easing.type: Easing.OutBack }
                        ColorAnimation  { target: newsBorder; property: "border.color"; to: "white"; duration: 200 }
                        NumberAnimation { target: newsBorder; property: "opacity"; to: 0.5; duration: 200 }
                    }

                    ParallelAnimation {
                        NumberAnimation { target: newsBorder; property: "radius"; to: 0; duration: 200; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: newsBorder; property: "anchors.margins"; to: -7; duration: 200; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: newsBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                    }

                    SequentialAnimation {
                        loops: Animation.Infinite
                        NumberAnimation { target: newsBorder; property: "opacity"; to: 0.2; duration: 500 }
                        NumberAnimation { target: newsBorder; property: "opacity"; to: 0.5; duration: 500 }
                    }
                }
            }
        }

                MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.focusZone !== 2 || !newsList.activeFocus) {
                    root.goToZone(2)
                    sNav.stop(); sNav.play();
                    newsList.currentIndex = index
                    newsList.forceActiveFocus()
                    flick.contentY = topH + (middleH * 0.78)
                } else if (newsList.currentIndex !== index) {
                    newsList.currentIndex = index
                    sNav.stop(); sNav.play();
                    flick.contentY = topH + (middleH * 0.78)
                } else {
                    // Открываем детальную новость
                    root.openNewsDetail(modelData, index)
                }                 
            }
        }
    }
}



            // ======== FRIENDS ========
ListView {
    id: friendsList
    anchors.fill: parent
    orientation: ListView.Horizontal
    spacing: 28
    clip: false
    model: 4
    visible: bottomTabsRow.currentIndex === 1
    highlightRangeMode: ListView.ApplyRange
    preferredHighlightBegin: width * 0.2
    preferredHighlightEnd: width * 0.8
    highlightMoveDuration: 120

Text {
    text: "Work In Progress"
    anchors.centerIn: parent
    color: "white" // Замени на цвет своего интерфейса
    font.pixelSize: 28 // Настрой размер под себя
    font.bold: true
}

}

// ======== RECOMMENDED ========

Item {
    id: recommendedContainer
    anchors.fill: parent
    visible: bottomTabsRow.currentIndex === 2
    
    // Размеры как у игр в средней зоне
    property real gameWidth: middleZone.innerH * 6 / 9
    property real gameHeight: middleZone.innerH
    property real sideMargin: 60
    
    // Динамические свойства
    property var unfilteredGames: []
    property int totalSlots: 0
    
    Text {
    text: "Work In Progress"
    anchors.centerIn: parent
    color: "white" // Замени на цвет своего интерфейса
    font.pixelSize: 28 // Настрой размер под себя
    font.bold: true
}


    // Функция фильтрации
    function updateUnfilteredGames() {
    var games = []
    var now = Date.now()
    
    // Жесткий фильтр - только игры, которые не запускались неделю или более
    var daysThreshold = 1
    var timeThreshold = daysThreshold * 24 * 60 * 60 * 1000
    
    for (var i = 0; i < middleSorted.count && games.length < 13; i++) {
        var game = middleSorted.get(i)
        
        if (game) {
            // DECKOS: never played = an invalid date (NaN); StMini's check dropped exactly those games
            var lastPlayed = game.lastPlayed ? new Date(game.lastPlayed).getTime() : NaN
            if (isNaN(lastPlayed) || now - lastPlayed > timeThreshold)
                games.push(game)
        }
    }
    
    // ТОЛЬКО отфильтрованные игры, без заполнения остатка
    unfilteredGames = games
    totalSlots = Math.max(1, Math.min(games.length + 1, 14))
}
    
    // Контейнер для сетки
    Item {
        id: recommendedGrid
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: recommendedContainer.sideMargin // DECKOS: defined there (out of scope here)
            rightMargin: 45
        }
        height: parent.height
        
        // СЕТКА
        Grid {
            id: recommendedList
            anchors.fill: parent
            columns: theme.homeRows
            rows: 2
            columnSpacing: 28
            rowSpacing: 28
            visible: false            
            property int currentIndex: 0
            property int displayCount: recommendedContainer.totalSlots
            
            Repeater {
                model: recommendedList.displayCount
                
              delegate: Item {
    width: (recommendedGrid.width - (recommendedList.columns - 1) * recommendedList.columnSpacing) / recommendedList.columns
    height: width * 9 / 6 
    
    property bool isLibraryButton: index === recommendedContainer.totalSlots - 1
    property bool isGame: !isLibraryButton && index < recommendedContainer.unfilteredGames.length
    property var gameData: isGame ? recommendedContainer.unfilteredGames[index] : null
    
    // Получаем реальный путь к ассету (локальный или веб)
    property string posterSource: isGame ? theme.getAssetSource("poster", gameData) : ""
    // Проверяем, удалось ли что-то найти
    property bool hasImg: posterSource !== ""

    Rectangle {
        anchors.fill: parent
        // Серый фон виден ТОЛЬКО если это игра без найденного изображения
        color: (isGame && !hasImg) ? "#555" : (isLibraryButton ? "#AA2A2E35" : "transparent")
        scale: recommendedList.currentIndex === index ? 1.04 : 1.0
        Behavior on scale { NumberAnimation { duration: 150 } }
        
        // Постер (поддерживает и локальные пути, и URL из Steam/Web)
        AnimatedImage {
            anchors.fill: parent
            source: posterSource
            fillMode: AnimatedImage.PreserveAspectCrop
            playing: visible && status === AnimatedImage.Ready && theme.animatedCovers && (!theme.animationInFocus || (recommendedList.currentIndex === index && recommendedList.focus))
            cache: true
            asynchronous: true
            visible: isGame && hasImg
        }

        // Текст названия игры (появляется только если постер пуст)
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            text: isGame ? gameData.title : ""
            color: "white"
            font.pixelSize: 24
            font.family: bold.name
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            visible: isGame && !hasImg
        }
        
                        // Blur эффект за игрой
Item {
    width: parent.width * 1.02
    height: parent.height * 1.02
    anchors.centerIn: parent
    clip: false
    opacity: recommendedList.currentIndex === index && recommendedList.focus ? 0.5 : 0.0
    z: -1
    
    Image {
        id: blurSource
        anchors.fill: parent
        source: theme.getAssetSource("poster", gameData)
        fillMode: Image.PreserveAspectCrop
        visible: false
        
        // Показываем левый нижний угол
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
    
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }
}
                        
                        Text {
    anchors.centerIn: parent
    text: "View more 
in your 
Library"
    color: "white"
    font.pixelSize: 40
    font.family: bold.name
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
                            visible: isLibraryButton
                        }

                        // ОБВОДКА (ОДНА, КАК БЫЛО)
                        Rectangle {
                            id: recommendedBorder
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 4
                            border.color: "grey"
                            radius: 0
                            anchors.margins: -7
                            opacity: recommendedList.currentIndex === index && recommendedList.focus ? 0.5 : 0.0
                            visible: opacity > 0

                            SequentialAnimation {
                                id: appearAnim
                                running: (recommendedList.currentIndex === index && recommendedList.focus)
                                loops: 1

                                ParallelAnimation {
                                    NumberAnimation { target: recommendedBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: recommendedBorder; property: "radius"; to: 0; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: recommendedBorder; property: "anchors.margins"; to: -17; duration: 200; easing.type: Easing.OutBack }
                                    ColorAnimation  { target: recommendedBorder; property: "border.color"; to: "white"; duration: 200 }
                                    NumberAnimation { target: recommendedBorder; property: "opacity"; to: 0.5; duration: 200 }
                                }

                                ParallelAnimation {
                                    NumberAnimation { target: recommendedBorder; property: "radius"; to: 0; duration: 200; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: recommendedBorder; property: "anchors.margins"; to: -7; duration: 200; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: recommendedBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                                }

                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    NumberAnimation { target: recommendedBorder; property: "opacity"; to: 0.2; duration: 500 }
                                    NumberAnimation { target: recommendedBorder; property: "opacity"; to: 0.5; duration: 500 }
                                }
                            }
                        }
                    }
                    
                    // MOUSEAREA С 2 УСЛОВИЯМИ
                   MouseArea {
    anchors.fill: parent
    
    onClicked: {
        // Проверяем: находимся ли мы в нужной зоне И имеет ли сам список фокус
        if (root.focusZone !== 2 || !recommendedList.activeFocus) {
            // Если фокуса нет или зона не та — только фокусируемся
            root.goToZone(2)
            sNav.stop();
sNav.play();
            recommendedList.currentIndex = index
            recommendedList.forceActiveFocus()
            flick.contentY = topH + (middleH * (index >= 7 ? 1.140 : 0.78))
        } 
        else if (recommendedList.currentIndex !== index) {
            // Если мы уже в зоне, но кликнули на другой индекс
            recommendedList.currentIndex = index
            sNav.stop();
sNav.play();
            flick.contentY = topH + (middleH * (index >= 7 ? 1.140 : 0.78))
        } 
        else {
            // ТОЛЬКО если зона 2, список в фокусе И индекс совпал — запускаем
            if (isLibraryButton) {
                theme.openPage(1)
            } else if (isGame && gameData) {
                var sourceIndex = -1
                for (var i = 0; i < middleSorted.count; i++) {
                    var sortedGame = middleSorted.get(i)
                    if (sortedGame && sortedGame.title === gameData.title) {
                        sourceIndex = i
                        break
                    }
                }
                
                if (sourceIndex !== -1) {
                    var realSourceIndex = middleSorted.mapToSource(sourceIndex)
                    var realGame = api.allGames.get(realSourceIndex)
                    if (realGame) {
                        theme.currentGame = realGame
                        theme.openPage(8)
                    }
                }
            }
        }
    }
}
}
}
   
            
            // Навигация клавишами
            Keys.onLeftPressed: {
    if (currentIndex > 0) {
        currentIndex--
        // УСЛОВИЕ: если индекс > 7, двигаем камеру на 1.1, иначе 0.78
        flick.contentY = topH + (middleH * (currentIndex >= 7 ? 1.140 : 0.78))
        sNav.stop();
            sNav.play();
    }
}

Keys.onRightPressed: {
    if (currentIndex < displayCount - 1) {
        currentIndex++
        // УСЛОВИЕ: если индекс > 7, двигаем камеру на 1.1, иначе 0.78
        flick.contentY = topH + (middleH * (currentIndex >= 7 ? 1.140 : 0.78))
        sNav.stop();
            sNav.play();
    }
}

Keys.onUpPressed: {
    if (currentIndex >= 7) {
        currentIndex -= 7
        // УСЛОВИЕ: если индекс > 7, двигаем камеру на 1.1, иначе 0.78
        flick.contentY = topH + (middleH * (currentIndex >= 7 ? 1.140 : 0.78))
        sNav.stop();
            sNav.play();
    } else {
        bottomTabsRow.inContent = false
        bottomTabsRow.forceActiveFocus()
        sNav.stop();
            sNav.play();
    }
}

Keys.onDownPressed: {
    if (currentIndex + 7 < displayCount) {
        currentIndex += 7
        // УСЛОВИЕ: если индекс > 7, двигаем камеру на 1.1
        flick.contentY = topH + (middleH * 1.140)
        sNav.stop();
            sNav.play();
    }
}
            
            Keys.onPressed: {
    if (api.keys.isAccept(event) && focus) {
        var item = children[currentIndex]
        if (item) {
            if (item.isLibraryButton) {
                theme.openPage(1)
            } else if (item.isGame && item.gameData) {
                theme.currentGame = item.gameData
                theme.openPage(8)
            }
            event.accepted = true
        }
    }
}
          
            onFocusChanged: {
                if (focus && displayCount > 0) {
                    currentIndex = Math.min(currentIndex, displayCount - 1)
                }
            }
        }
    }
    
    Component.onCompleted: updateUnfilteredGames()
    
    Connections {
        target: middleSorted
        function onCountChanged() {
            recommendedContainer.updateUnfilteredGames() // DECKOS: out of scope here
        }
    }
}
}
}
} // bottomZone
       } // Column content
        
        

        // клавишами управляем переходом зон и прокруткой
        
        Keys.onPressed: {
    if (event.key === Qt.Key_Down) {
        if (root.focusZone === 0) {
            // С верхней зоны переходим в среднюю
            root.goToZone(1)
            event.accepted = true
            sNav.stop();
            sNav.play();
        } else if (root.focusZone === 1) {
            // Со средней зоны переходим в нижнюю
            root.goToZone(2)
            event.accepted = true
            sNav.stop();
            sNav.play();
        } else if (root.focusZone === 2 && !bottomTabsRow.inContent) {
            // С табов переходим в контент
            bottomTabsRow.inContent = true
            newsList.forceActiveFocus()
            event.accepted = true
            sNav.stop();
            sNav.play();
        }
    } 
    else if (event.key === event.key === Qt.Key_Up) {
        if (root.focusZone === 2 && bottomTabsRow.inContent) {
            // Из контента возвращаемся к табам
            bottomTabsRow.inContent = false
            bottomTabsRow.forceActiveFocus()
            event.accepted = true
            sNav.stop();
            sNav.play();
        } else if (root.focusZone === 2) {
            // С нижних табов переходим в среднюю зону
            root.goToZone(1)
            event.accepted = true
            sNav.stop();
            sNav.play();
        } else if (root.focusZone === 1) {
            // Со средней зоны переходим в верхнюю
            root.goToZone(0)
            event.accepted = true
            sNav.stop();
            sNav.play();
        }
    }
    // Обработка PrevPage/NextPage для BottomZone
else if (api.keys.isPrevPage(event) || api.keys.isNextPage(event)) {
    if (root.focusZone === 2) {
        sTab.stop();
        sTab.play();
        
        let oldIndex = bottomTabsRow.currentIndex;
        let newIndex = oldIndex;
        
        if (api.keys.isPrevPage(event)) {
            newIndex = Math.max(0, oldIndex - 1);
        } else if (api.keys.isNextPage(event)) {
            newIndex = Math.min(2, oldIndex + 1);
        }
        
        if (oldIndex !== newIndex) {
            // Используем новую анимацию
            root.safeBottomNav(newIndex);
            
            // Возвращаем управление на кнопки табов
            bottomTabsRow.inContent = false
            bottomTabsRow.forceActiveFocus()
            
            // Сбрасываем камеру на заголовки
            flick.contentY = topH + (middleH * 0.78)
            
            // Сброс индексов списков
            if (newsList) newsList.currentIndex = 0
            if (friendsList) friendsList.currentIndex = 0
            if (recommendedList) recommendedList.currentIndex = 0
        }
        event.accepted = true
    }
}

// Добавить после блока с PrevPage/NextPage
else if (api.keys.isDetails(event) || event.key === Qt.Key_X) {
    if (!optionsMenuVisible && focusZone === 1 && gameList.focus) {
        toggleOptionsMenu()
        event.accepted = true
    }
}
    else if (event.key === Qt.Key_Left) {
        if (root.focusZone === 0) { 
            if (topButtonsRow.currentIndex > 0) topButtonsRow.currentIndex-- 
            sTab.stop();
            sTab.play();
        }
        else if (root.focusZone === 1) { 
            if (gameList.currentIndex > 0) gameList.currentIndex-- 
            sTab.stop();
            sTab.play();
        }
        else if (root.focusZone === 2 && bottomTabsRow.inContent) { 
            if (newsList.currentIndex > 0) newsList.currentIndex-- 
            sTab.stop();
            sTab.play();
        }
        else if (root.focusZone === 2) { 
            if (bottomTabsRow.currentIndex > 0) bottomTabsRow.currentIndex-- 
            sTab.stop();
            sTab.play();
        }
    } 
    else if (event.key === Qt.Key_Right) {
        if (root.focusZone === 0) { 
            if (topButtonsRow.currentIndex < 3) topButtonsRow.currentIndex++ 
            sTab.stop();
            sTab.play();
        }
        else if (root.focusZone === 1) { 
            if (gameList.currentIndex < gameList.count - 1) gameList.currentIndex++ 
            sTab.stop();
            sTab.play();
        }
        else if (root.focusZone === 2 && bottomTabsRow.inContent) { 
            if (newsList.currentIndex < newsList.count - 1) newsList.currentIndex++ 
            sTab.stop();
            sTab.play();
        }
        else if (root.focusZone === 2) { 
            if (bottomTabsRow.currentIndex < 2) bottomTabsRow.currentIndex++ 
            sTab.stop();
            sTab.play();
        }
        }
    }
} // Flickable
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
            Behavior on color { ColorAnimation { duration: 200 } }
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
    
    // ВЕРНУЛИ декларативную привязку (определяет стартовую позицию и реагирует на ресайз)
    x: posRight 

    // Component.onCompleted ПОЛНОСТЬЮ УДАЛЕН

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
                // В конце скрываем полностью
                PropertyAction { target: searchText; property: "visible"; value: false }
            }
        }
    ]
}



        MouseArea { 
        anchors.fill: parent
        onClicked: if (!root.closeMenuVisible) {
            // Если мы уже находимся в верхней зоне и уже выбрана кнопка поиска (индекс 0)
            if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                theme.openPage(9) // Открываем Library
            } else {
                // Если нет — просто переходим в верхнюю зону и выбираем поиск
                root.goToZone(0)
                topButtonsRow.currentIndex = 0
                topButtonsRow.forceActiveFocus()
                sNav.play ()
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
                    text: theme.isOnline ? "°" : "o" 
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsRow.currentIndex === 1 && topButtonsRow.focus) ? "black" : "white"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0)
                        topButtonsRow.currentIndex = 1
                        sNav.play ()
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
            visible: theme.showBatteryPercent // Скрываем текст, если выключено
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
        onClicked: if (!root.closeMenuVisible) {
            root.goToZone(0)
            topButtonsRow.currentIndex = 2
            sNav.play ()
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

                AnimatedImage {
                    id: userImage
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    height: parent.height * 0.8
                    source: (root.theme && root.theme.profilePictureSource !== "") ? root.theme.profilePictureSource : "../assets/logo/logo.jpg" /* DECKOS */
                    fillMode: Image.PreserveAspectFit
                    playing: visible && status === AnimatedImage.Ready && (api.memory.has("animatedCovers") ? api.memory.get("animatedCovers") : false)
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
                        sNav.stop();
            sNav.play();
                    }
                }
            }

            Keys.onLeftPressed:{ if (topButtonsRow.currentIndex > 0) topButtonsRow.currentIndex--
            sNav.stop();
            sNav.play(); 
}
            Keys.onRightPressed: {if (topButtonsRow.currentIndex < 3) topButtonsRow.currentIndex++
            sNav.stop();
            sNav.play();
        }
            Keys.onDownPressed: {root.goToZone(1)
sNav.stop();
            sNav.play(); 
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
    visible: !theme.highContrastBottomBar
     // до любого нужного значения
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

        // === В BOTTOM BAR (кнопка MENU) ===
MouseArea {
    anchors.fill: parent
    onClicked: {
        if (root.closeMenuVisible || root.optionsMenuVisible || root.newsDetailVisible) return;
        
        // DECKOS: focus the first button only when opening; doing it on close pulled focus back into the
        // closed menu (fast double taps then left the page without focus)
        if (!leftBar.isOpen) leftBar.currentIndex = 0
        leftBar.toggle()
        if (leftBar.isOpen === false) {
            focusTimer.start()
        }
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
        visible: root.closeMenuVisible ? 0 : 1 && !leftBar.isOpen && !root.optionsMenuVisible && !root.newsDetailVisible
        anchors.verticalCenter: parent.verticalCenter
        Text { text: theme.nintendoLayout ? (theme.universalIcons ? "У" : "Y") : (theme.universalIcons ? "Х" : "X")
; font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025 }
        Text { text: "OPTIONS"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23 }
    }

    // --- Подсказка SELECT ---
    Row {
        spacing: 18
        anchors.verticalCenter: parent.verticalCenter
        Text { text: theme.nintendoLayout ? (theme.universalIcons ? "В" : "B") : (theme.universalIcons ? "А" : "A")
; font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025}
        Text { text: "SELECT"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23 }
    }

    // === КНОПКА BACK (с MouseArea) ===
    Rectangle {
        id: btnBack
        width: 140; height: parent.height
        color: "transparent"

        Row {
            anchors.centerIn: parent
            spacing: 18
            Text { 
                text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B")
; font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025}
            Text { 
                text: root.newsDetailVisible ? "CANCEL" : "BACK"
                font.family: bold.name; 
                font.pixelSize: 25; 
                color: "white";
                y:parent.height *0.23 
            }
        }            

        // === MouseArea для BACK / CANCEL ===
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.newsDetailVisible) {
                    root.closeNewsDetail()
                } 
                else if (root.closeMenuVisible) {
                    root.closeMenuVisible = false
                    sLeftClose.play()
                    focusTimer.start()
                } 
                else if (root.optionsMenuVisible) {
                    root.toggleOptionsMenu()
                    sLeftClose.play()
                }
                else if (root.focusZone === 2 && (newsList.focus || friendsList.focus || recommendedList.focus)) {
                    bottomTabsRow.forceActiveFocus()
                } 
                else if (root.focusZone === 2) {
                    root.goToZone(1)
                } 
                else if (root.focusZone === 1) {
                    leftBar.toggle()
                } 
                else if (root.focusZone === 0) {
                    root.goToZone(1)
                }
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
            // Блокируем все другие клавиши, чтобы не было случайных переходов
            event.accepted = true
        }
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
            
            // СВОЙСТВО ДЛЯ ПРОВЕРКИ ФОКУСА
            property bool isFocused: leftBar.isOpen && leftBar.currentIndex === buttonIndex // DECKOS: the selected button, not Qt focus (which can drift)
            
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
// Центральное окно меню
Rectangle {
width: 550
height: 550 // Увеличено для размещения 5 кнопок
anchors.centerIn: parent
color: "#181B20"
// Название игры сверху
Text {
anchors {
horizontalCenter: parent.horizontalCenter
bottom: parent.top
bottomMargin: 25
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
// ===== 0. КНОПКА "ИГРАТЬ" =====
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
} else {
if (currentFocusedGame) {
currentFocusedGame.launch()
root.toggleOptionsMenu()
}
}
}
}
}
// ===== 1. КНОПКА "ИЗБРАННОЕ" =====
Rectangle {
id: favoriteButton
width: parent.width
height: parent.height / 5
color: optionsMenu.currentButtonIndex === 1 ? "white" : "transparent"
Text {
text: {
if (currentFocusedGame) {
return currentFocusedGame.favorite ? "   Delete from favorites" : "   Add to favorites"
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
sNav.stop(); sNav.play();
} else {
if (currentFocusedGame) {
currentFocusedGame.favorite = !currentFocusedGame.favorite
root.toggleOptionsMenu()
}
}
}
}
}
// ===== 2. КНОПКА "СВОЙСТВА" =====
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
        } else {
            if (currentFocusedGame) {
                theme.currentGame = currentFocusedGame;
                // ВАЖНО: Добавляем запись в память!
                api.memory.set("targetGameName", currentFocusedGame.title);
            }
            root.toggleOptionsMenu()
            theme.openPage(14)
        }
    }
}
}
// ===== 3. КНОПКА "СМЕНА АРТА" =====
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
} else {
if (currentFocusedGame) {
theme.currentGame = root.currentFocusedGame
}
root.toggleOptionsMenu()
theme.openPage(12)
}
}
}
}
// ===== 4. КНОПКА "ОТМЕНА" =====
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
else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
if (currentButtonIndex === 0) {
if (currentFocusedGame) { currentFocusedGame.launch(); root.toggleOptionsMenu(); }
} else if (currentButtonIndex === 1) {
if (currentFocusedGame) { currentFocusedGame.favorite = !currentFocusedGame.favorite; root.toggleOptionsMenu(); }
} else if (currentButtonIndex === 2) {
if (currentFocusedGame) { theme.currentGame = currentFocusedGame; api.memory.set("targetGameName", currentFocusedGame.title) } root.toggleOptionsMenu(); theme.openPage(14) // DECKOS: Properties did nothing with a controller (mouse only)
} else if (currentButtonIndex === 3) {
if (currentFocusedGame) theme.currentGame = root.currentFocusedGame;
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
sShowui.play()
forceActiveFocus()
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
    // Массив теперь содержит только 2 кнопки
    property var buttons: [exitButton, cancelButton]

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
        z:1
        
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


    Keys.onPressed: {
    if (event.key === Qt.Key_Down) {
        if (root.focusZone === 0) {
            // С верхней зоны переходим в среднюю
            root.goToZone(1)
            event.accepted = true
            sNav.stop();
            sNav.play();
        } else if (root.focusZone === 1) {
            // Со средней зоны переходим в нижнюю
            root.goToZone(2)
            event.accepted = true
            sNav.stop();
            sNav.play();
        } else if (root.focusZone === 2) {
            // В нижней зоне - переходим в контент соответствующих вкладок
            if (bottomTabsRow.currentIndex === 0) {
                newsList.forceActiveFocus()
                sNav.stop();
            sNav.play();
                if (newsList.count > 0) newsList.currentIndex = 0
                sNav.stop();
            sNav.play();
            } else if (bottomTabsRow.currentIndex === 1) {
                friendsList.forceActiveFocus()
                sNav.stop();
            sNav.play();
                if (friendsList.count > 0) friendsList.currentIndex = 0
            } else if (bottomTabsRow.currentIndex === 2) {
                recommendedList.forceActiveFocus()
                sNav.stop();
            sNav.play();
                if (recommendedList.count > 0) recommendedList.currentIndex = 0
            }
            event.accepted = true
        }
    } 
    else if (event.key === Qt.Key_Up) {
        if (root.focusZone === 2) {
            // Из нижней зоны переходим в среднюю
            root.goToZone(1)
            event.accepted = true
            sNav.stop();
            sNav.play();
        } else if (root.focusZone === 1) {
            // Со средней зоны переходим в верхнюю
            root.goToZone(0)
            event.accepted = true
            sNav.stop();
            sNav.play();
        }
    }
    else if (event.key === Qt.Key_Left) {
        if (root.focusZone === 0) { 
            if (topButtonsRow.currentIndex > 0) {
                topButtonsRow.currentIndex--
                event.accepted = true
                sNav.stop();
            sNav.play();
            }
        }
        else if (root.focusZone === 1) { 
            if (gameList.currentIndex > 0) {
                gameList.currentIndex--
                event.accepted = true
                sNav.stop();
            sNav.play();
            }
        }
        else if (root.focusZone === 2) {
            // Навигация по вкладкам или контенту
            if (newsList.focus && newsList.currentIndex > 0) {
                newsList.currentIndex--
                event.accepted = true
                sNav.stop();
            sNav.play();
            } else if (friendsList.focus && friendsList.currentIndex > 0) {
                friendsList.currentIndex--
                event.accepted = true
                sNav.stop();
            sNav.play();
            } else if (recommendedList.focus && recommendedList.currentIndex > 0) {
                recommendedList.currentIndex--
                event.accepted = true
                sNav.stop();
            sNav.play();
            } else if (bottomTabsRow.focus && bottomTabsRow.currentIndex > 0) {
                bottomTabsRow.currentIndex--
                event.accepted = true
                sNav.stop();
            sNav.play();
            }
        }
    } 
    else if (event.key === Qt.Key_Right) {
        if (root.focusZone === 0) { 
            if (topButtonsRow.currentIndex < 3) {
                topButtonsRow.currentIndex++
                event.accepted = true
                sNav.stop();
            sNav.play();
            }
        }
        else if (root.focusZone === 1) { 
            if (gameList.currentIndex < gameList.count - 1) {
                gameList.currentIndex++
                event.accepted = true
                sNav.stop();
            sNav.play();
            }
        }
        else if (root.focusZone === 2) {
            // Навигация по вкладкам или контенту
            if (newsList.focus && newsList.currentIndex < newsList.count - 1) {
                newsList.currentIndex++
                event.accepted = true
                sNav.stop();
            sNav.play();
            } else if (friendsList.focus && friendsList.currentIndex < friendsList.count - 1) {
                friendsList.currentIndex++
                event.accepted = true
                sNav.stop();
            sNav.play();
            } else if (recommendedList.focus && recommendedList.currentIndex < recommendedList.count - 1) {
                recommendedList.currentIndex++
                event.accepted = true
                sNav.stop();
            sNav.play();
            } else if (bottomTabsRow.focus && bottomTabsRow.currentIndex < 2) {
                bottomTabsRow.currentIndex++
                event.accepted = true
                sNav.stop();
            sNav.play();
            }
        }
    }
    // ===== ОТКРЫТИЕ OPTIONS MENU =====
    else if (api.keys.isDetails(event) || event.key === Qt.Key_X) {
        if (!optionsMenuVisible && focusZone === 1 && gameList.focus) {
            toggleOptionsMenu()
            event.accepted = true
        }
    }
    
    // ===== ЗАКРЫТИЕ OPTIONS MENU =====
else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
    if (optionsMenuVisible) {
        toggleOptionsMenu()
        sLeftClose.play()
        event.accepted = true
    } 
    // Обработка кнопки Cancel (B/Back) - возврат через зоны И открытие левого меню
    else if (root.focusZone === 2 && (newsList.focus || friendsList.focus || recommendedList.focus)) {
        // Возврат из контента к вкладкам
        bottomTabsRow.forceActiveFocus()
        event.accepted = true
    } 
    else if (root.focusZone === 2 && bottomTabsRow.focus) {
        // Возврат из нижней зоны в среднюю
        root.goToZone(1)
        event.accepted = true
    } 
    else if (root.focusZone === 1 && gameList.focus) {
        // В средней зоне - открытие левого меню
        leftBar.toggle()
        event.accepted = true
    } 
    else if (root.focusZone === 0 && topButtonsRow.focus) {
        // В верхней зоне - переходим в среднюю
        root.goToZone(1)
        event.accepted = true
    }
}
    // === В Keys.onPressed главного экрана ===
else if (api.keys.isMenu(event)) {
    if (!optionsMenuVisible && !closeMenuVisible && !newsDetailVisible) {
        leftBar.toggle()
        event.accepted = true
    }
}
}


    // --- ЛОГИКА АНИМАЦИИ ---
    
        property int nextPageIndex: 0

        function startExitAnimation(index) {
    if (index === 8 || index === 12) {
        api.memory.set("homeReturnContext", {
            listIndex: gameList.currentIndex,
            contentX: gameList.contentX
        })
        if (index === 12 || index === 14) {
            api.memory.set("steamGridSource", 0)
        }
    }
    nextPageIndex = index
    exitAnim.start()
}

        // DECKOS: the page host kept this page alive behind the game page and shows it again as it was
        // (focus, scroll position), instead of rebuilding it from homeReturnContext
        function resumePage() {
            api.memory.set("homeReturnContext", null)
            recommendedContainer.updateUnfilteredGames() // a game may have been played meanwhile
            gameList.snapLater() // the row back on the selected game (scrollTarget)
            enterAnim.start()
            focusTimer.start()
        }

        // DECKOS: DeckOS is in front again (theme.qml): the highlight restarts and the zone has the focus
        function resumeFocus() {
            highlightOn = false
            Qt.callLater(function () { highlightOn = true })
            if (closeMenuVisible || optionsMenuVisible || leftBar.isOpen) return
            if (focusZone === 0) topButtonsRow.forceActiveFocus()
            else if (focusZone === 1) gameList.forceActiveFocus()
            else if (bottomTabsRow.currentIndex === 0) newsList.forceActiveFocus()
            else if (bottomTabsRow.currentIndex === 1) friendsList.forceActiveFocus()
            else recommendedList.forceActiveFocus()
        }

        Component.onCompleted: {
        NewsJS.fetchNews(function(items) {
            root.newsData = items;
        });
        enterAnim.start()        

        var ctx = api.memory.has("homeReturnContext") ? api.memory.get("homeReturnContext") : null
        if (ctx) {
            api.memory.set("homeReturnContext", null)
            var lIdx = (ctx.listIndex !== undefined) ? ctx.listIndex : 0

            // 1. Сначала переходим в зону (это вызовет сброс на 0)
            root.goToZone(1)

            // 2. Теперь возвращаем правильный сохраненный индекс
            gameList.currentIndex = Math.max(0, Math.min(lIdx, gameList.count - 1))

            // 3. DECKOS: the row on that game once it's laid out - not the saved contentX, which belonged
            // to the old layout (scrollTarget)
            gameList.snapLater()
            focusTimer.start()
        } else {
            root.goToZone(1)
            focusTimer.start()
        }
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
    interval: 100
    running: false
    repeat: false
    onTriggered: {
    // DECKOS: not while the Steam menu is open - it took the focus from the open menu
    if (!root.closeMenuVisible && !leftBar.isOpen && !optionsMenuVisible && root.focusZone === 1) {
        gameList.forceActiveFocus()
        if (gameList.count > 0) {
            gameList.currentIndex = gameList.currentIndex // перезапуск выделения
        }
    }
    }
}

// === NEWS DETAIL LOADER ===
property var selectedNewsItem: null
property int selectedNewsIndex: 0
property bool newsDetailVisible: false

Loader {
    id: newsDetailLoader
    anchors.fill: parent
    active: newsDetailVisible
    asynchronous: true
    focus: true

    
    source: "newspage.qml"
    
    onLoaded: {
        if (item) {
            item.newsItem = root.selectedNewsItem
            item.visible = true
            item.forceActiveFocus()
            item.newsData = root.newsData
item.currentNewsIndex = root.selectedNewsIndex
        }
    }
    
    // Закрытие по Escape / Back
    Keys.onPressed: {
        if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
            root.closeNewsDetail()
            event.accepted = true
        }
    }
}



function openNewsDetail(news, newsIndex) {
    if (!news) return;
    selectedNewsItem = news;
    selectedNewsIndex = newsIndex || 0;
    newsDetailVisible = true;
    sShowui.play();
}

function closeNewsDetail() {
    newsDetailVisible = false
    selectedNewsItem = null
    // Возвращаем фокус на список новостей
    if (bottomTabsRow.currentIndex === 0) {
        newsList.forceActiveFocus()
    }
}
} 