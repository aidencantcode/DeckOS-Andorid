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
    // Виртуальная высота страницы теперь 1.5 экрана
property real pageHeight: root.height * 1.9
property real topH: 95
property real middleH: root.height * 0.715
property real bottomH: pageHeight - topH - middleH


    // current focus zone: 0 = top, 1 = middle, 2 = bottom
    property int focusZone: 1
    property var theme
    // для навигации по кнопкам What's New (1-4)
property int newsListFocusHelper: 1
    
    // меню опций
    property bool optionsMenuVisible: false
property var currentFocusedGame: null

    SoundEffect { id: sNav; source: "../assets/audio/nav.wav"; volume: 1.0 }
    SoundEffect { id: sAccept; source: "../assets/audio/accept.wav"; volume: 1.0 }
    SoundEffect { id: sBack; source: "../assets/audio/back.wav"; volume: 1.0 }
    SoundEffect { id: sLeftOpen; source: "../assets/audio/deck_ui_side_menu_fly_in.wav"; volume: 1.0 }
    SoundEffect { id: sLeftClose; source: "../assets/audio/deck_ui_side_menu_fly_out.wav"; volume: 1.0 }
    SoundEffect { id: sShowui; source: "../assets/audio/deck_ui_show_ui.wav"; volume: 1.0 }



function toggleOptionsMenu() {
    if (optionsMenuVisible) {
        // ЗАКРЫТИЕ
        optionsMenuVisible = false
        optionsMenu.focus = false
        
        // Возвращаем фокус в зону с играми
        if (focusZone === 1) {
            gameList.forceActiveFocus()
        }
    } else if (focusZone === 1 && gameList.currentIndex !== 10) { // 10 - плейсхолдер
        // ОТКРЫТИЕ
        if (gameList.model && gameList.model.count > 0) {
            
            // 1. Получаем индекс в отсортированном списке
            var proxyIndex = gameList.currentIndex;
            
            // 2. Преобразуем его в индекс ГЛАВНОГО списка (api.allGames)
            // Это самая важная часть!
            var sourceIndex = middleSorted.mapToSource(proxyIndex);
            
            // 3. Получаем НАСТОЯЩИЙ объект игры из api.allGames
            // У этого объекта есть функции launch() и свойство favorite
            currentFocusedGame = api.allGames.get(sourceIndex);
            
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

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: content.height
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.DragAndOvershootBounds
        interactive: true
        clip: true

        // сделать плавный переход при программном изменении contentY
        Behavior on contentY { 
            NumberAnimation { 
                duration: 100 
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
    color: "black"
    z: 5

    // ======== ФОН ========
    Item {
        id: backgroundContainer
        anchors.fill: parent
        clip: true // Обрезаем всё что выходит за границы
        
        
        Image {
            id: middleBackground
            width: parent.width * 1.15  // 15% больше
            height: parent.height * 1.15
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectCrop
            opacity: 0
            z: 0
            
            // === 1. ПОЯВЛЕНИЕ ФОНА ===
            PropertyAnimation {
                id: fadeInAnimation
                target: middleBackground
                property: "opacity"
                from: 0
                to: 0.4
                duration: 200
                easing.type: Easing.OutCubic
                
                onStopped: {
                    // После появления ждем 2 секунды                   
                    idleTimer.start();
                }
            }
            
            // === 2. ТАЙМЕР ОЖИДАНИЯ (2 секунды) ===
            Timer {
                id: idleTimer
                interval: 2000
                
                onTriggered: {
                    moveAnimation.start();
                }
            }
            
            // === 3. АНИМАЦИЯ ДВИЖЕНИЯ ===
            // Используем transform вместо x
            transform: Translate {
                id: backgroundTransform
                x: 0
            }
            
            SequentialAnimation {
                id: moveAnimation
                loops: Animation.Infinite
                
                // Движение ВПРАВО на 15% ширины
                PropertyAnimation {
                    target: backgroundTransform
                    property: "x"
                    from: 0
                    to: middleZone.width * 0.02
                    duration: 10000 // 10 секунд - ОЧЕНЬ МЕДЛЕННО
                    easing.type: Easing.InOutSine
                }
                
                // Движение ВЛЕВО на 30% (от +15% до -15%)
                PropertyAnimation {
                    target: backgroundTransform
                    property: "x"
                    from: middleZone.width * 0.02
                    to: -middleZone.width * 0.02
                    duration: 15000 // 20 секунд
                    easing.type: Easing.InOutSine
                }
                
                // Возврат вправо на 15%
                PropertyAnimation {
                    target: backgroundTransform
                    property: "x"
                    from: -middleZone.width * 0.02
                    to: 0
                    duration: 10000 // 10 секунд
                    easing.type: Easing.InOutSine
                }
            }
            
            // При смене фона сбрасываем всё
            onSourceChanged: {
                moveAnimation.stop();
                idleTimer.stop();
                backgroundTransform.x = 0;
                
                if (opacity > 0) {
                    idleTimer.start();
                }
            }
        }
    }

    // Обновление фона при смене игры
    Connections {
        target: gameList
        onCurrentIndexChanged: {
        if (gameList.focus) {
    }
            if (gameList.model && gameList.model.count > 0) {
                var currentIndex = gameList.currentIndex;
                
                if (currentIndex !== 10) {
                    var game = gameList.model.get(currentIndex);
                    if (game && game.assets) {
                        var newBackground = game.assets.background || "";
                        
                        // 1. Скрываем
                        middleBackground.opacity = 0;
                        
                        // 2. Меняем картинку
                        middleBackground.source = newBackground;
                        
                        // 3. Показываем
                        fadeInAnimation.start();
                    }
                }
            }
        }
    }
    
    // Устанавливаем начальный фон
    Component.onCompleted: {
        if (gameList.model && gameList.model.count > 0 && gameList.currentIndex !== 10) {
            var game = gameList.model.get(gameList.currentIndex);
            if (game && game.assets) {
                middleBackground.source = game.assets.background || "";
                middleBackground.opacity = 0.5;
                
                // Сразу запускаем таймер ожидания
                idleTimer.start();
            }
        }
    }

    // Градиент поверх фона
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 1.0; color: "#0F1318" }
            GradientStop { position: 0.2; color: "transparent" }
        }
        z: 4
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 1.0; color: "#0F1318" }
            GradientStop { position: 0.9; color: "transparent" }
        }
        z: 10
    }

    property real innerH: middleZone.height * 0.6
    property real vMargin: middleZone.height * 0.25

    // ======== Сортировка и фильтрация ========
SortFilterProxyModel {
    id: middleSorted
    sourceModel: api.allGames

    sorters: RoleSorter {
        roleName: "lastPlayed"
        sortOrder: Qt.DescendingOrder
    }
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
            topMargin: middleZone.vMargin
        }
        height: middleZone.innerH
        orientation: ListView.Horizontal
        spacing: 28
        clip: false
        model: middleSorted
        property int currentIndex: 0
        // Главное изменение: вместо model.count используем фиксированное число
    property int displayCount: 11 // Показываем 11 игр + 1 плейсхолдер
    // Искусственно ограничиваем количество создаваемых делегатов
    property int effectiveCount: Math.min(displayCount, model ? model.count : 0)
                z: 5
        highlightMoveDuration: 120
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: width * 0.3
        preferredHighlightEnd: width * 0.6

         // === ЖЁСТКОЕ ВЫРАВНИВАНИЕ ===
    onCurrentIndexChanged: {
    if (currentIndex >= 0 && currentIndex < count) {
        // Если это последние 2 игры (или одна последняя), 
        // просто прижимаем список к правому краю, а не центрируем.
        if (currentIndex >= count - 2) {
            positionViewAtEnd()
        } else {
            positionViewAtIndex(currentIndex, ListView.Center)
        }
    }
}

        
// === ИСПРАВЛЕННЫЙ БЛОК: Получение ИСХОДНОГО объекта игры ===
Keys.onPressed: {
    if (api.keys.isAccept(event) && gameList.focus) {
        if (gameList.model && gameList.model.count > 0) {
            
            // Проверяем, если это серый плейсхолдер
            if (gameList.currentIndex === 10) {
                theme.openPage(1)  // Открываем Library
                event.accepted = true
                return
            }
            
            // 1. Получаем индекс в SortFilterProxyModel (middleSorted)
            var proxyIndex = gameList.currentIndex
            
            // 2. Получаем исходный индекс (source index) из прокси-модели
            //    Используем метод mapToSource, который преобразует индекс
            //    из proxy в индекс в исходной модели.
            var sourceIndex = middleSorted.mapToSource(proxyIndex)
            
            // 3. Получаем ИСХОДНЫЙ объект игры из исходной модели (api.allGames)
            //    ВАЖНО: Должен быть прямой доступ к sourceModel, т.к. get() 
            //    из SortFilterProxyModel возвращает "скомпилированные" данные.
            var gameData = api.allGames.get(sourceIndex)
            
            if (gameData) {
                // Передаем исходный объект игры в theme
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
            ////sNav.stop();
////sNav.play();

        }
    }
    
    Keys.onRightPressed: {
        if (gameList.currentIndex < gameList.displayCount - 1) {
        gameList.currentIndex++
        event.accepted = true
        ////sNav.stop();
////sNav.play();

    }
    }
    
    

        delegate: Item {
            id: gameDelegate
            property bool isWide: index === 0
            property real dH: gameList.height
            property real scaleFactor: index === gameList.currentIndex && gameList.focus ? 1.04 : 1.0
            property bool hasImage: isWide ? (modelData && modelData.assets.steam) : (modelData && modelData.assets.poster)
            property bool isGrayPlaceholder: index === gameList.displayCount - 1    
    // Скрываем элементы, которые идут после лимита
    visible: index < gameList.displayCount
    height: visible ? (dH) : 0
    width: index < 11 ? (isWide ? dH * 92 / 46 : dH * 6 / 9) : -gameList.spacing

            

            // ======== Контейнер игры ========
            Rectangle {
                id: gameContainer
                anchors.fill: parent
                // ВАЖНОЕ ИЗМЕНЕНИЕ: Полупрозрачный тёмно-серый цвет для плейсхолдера
color: isGrayPlaceholder ? "#AA2A2E35" : (hasImage ? "transparent" : "#555")
                scale: scaleFactor
                Behavior on scale { NumberAnimation { duration: 150 } }

                // Изображение
                Image {
                    anchors.fill: parent
                    source: isWide ? (modelData && modelData.assets.steam) : (modelData && modelData.assets.poster)
                    fillMode: Image.PreserveAspectCrop
                    visible: hasImage && !isGrayPlaceholder
                    z: 10
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

// Старый текст для игр (переименуйте его id)
Text {
    id: gameTitleText  // Добавьте id
    anchors.centerIn: parent
    text: modelData && modelData.title ? modelData.title : ("Game " + (index + 1))
    color: "white"
    font.pixelSize: 26
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    wrapMode: Text.WordWrap
    width: parent.width * 0.9
    visible: !hasImage && !isGrayPlaceholder  // Скрыть для плейсхолдера
}

                // Обводка активного элемента (ТОЛЬКО когда в фокусе)
                Rectangle {
                    id: highlightBorder
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 5
                    border.color: "grey"
                    radius: 0
                    anchors.margins: -10
                    opacity: (index === gameList.currentIndex && root.focusZone === 1) ? 1.0 : 0.0
                    visible: !leftBar.isOpen && !optionsMenuVisible &&  opacity > 0
                    z: 20

                    // ======== Анимация появления + «прыжок» ========
                    SequentialAnimation {
                        id: appearAnim
                        running: (index === gameList.currentIndex && root.focusZone === 1)
                        loops: 1

                        // Фаза 1: растёт больше нужного
                        ParallelAnimation {
                            NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                            NumberAnimation { target: highlightBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                            NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -17; duration: 100; easing.type: Easing.OutBack }
                            ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 100 }
                            NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 100 }
                        }

                        // Фаза 2: «сжимается» до финального размера
                        ParallelAnimation {
                            NumberAnimation { target: highlightBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -10; duration: 100; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: highlightBorder; property: "border.width"; to: 5; duration: 100; easing.type: Easing.OutBack }
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

            // ======== Название под игрой ========
Column {
    id: titleColumn
    Component.onCompleted: parent = middleZone 
    z: 11 
    
    // 1. Жесткая привязка по X
    x: gameDelegate.x - gameList.contentX + 60 - 7
    
    // 2. Базовая позиция по Y + смещение для анимации
    property real appearanceOffset: visible ? 0 : 15 
    y: gameList.y + gameDelegate.height + 25 + appearanceOffset
    
    // 3. Анимируем только смещение!
    Behavior on appearanceOffset {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }
    
    // 4. Плавность прозрачности
    Behavior on opacity { 
        NumberAnimation { duration: 100 } 
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
}



 // Размытие для игр 
Rectangle {
    width: isWide ? 3100 : 1111
    height: isWide ? 1500 : 500
    color: "transparent"
    clip: true
    visible: (index === gameList.currentIndex && gameList.focus && !leftBar.isOpen && !optionsMenuVisible && !isGrayPlaceholder)
    opacity: visible ? 0.8 : 0
    x: isWide ? - 1200 : -445
    y: isWide ? parent.height - 350 : parent.height - 185
    z: -2
    
    Image {
        width: parent.width * 2000
        height: parent.height * 2000
        x: -parent.width * 1
        y: -parent.height * 1
        source: modelData && modelData.assets.steam
        fillMode: Image.PreserveAspectCrop
    }
    
    // Анимации
    
    Behavior on opacity {
        NumberAnimation { duration: 100 }
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
// Текст над первой игрой
            Text {
                visible: index === 0
                text: "Recent games"
                color: "white"
                font.pixelSize: 48
                font.family: extrabold.name
                anchors.bottomMargin: 40
                z:3
                x: -7
                y: parent.height - 553
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
            if (root.focusZone !== 1) {
                root.goToZone(1)
                gameList.currentIndex = index
                gameList.forceActiveFocus()
                ////sNav.stop();
            ////sNav.play();
            } else if (gameList.currentIndex === index && gameList.focus) {
                // Если это серый плейсхолдер - открываем Library
                if (isGrayPlaceholder) {
                    theme.openPage(1)
                } else {
                    // Иначе открываем меню игры (быстрое нажатие)
                    theme.currentGame = modelData
                    theme.openPage(8)
                }
            } else {
                gameList.currentIndex = index
                gameList.forceActiveFocus()
                ////sNav.stop();
            ////sNav.play();
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
    
  // ТЕКСТ СЛЕВА (на уровне кнопок, смещен на 10% ниже)
Text {
    id: leftSideText
    anchors {
        left: parent.left
        leftMargin: 40
        top: bottomTabsRow.bottom
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
        top: bottomTabsRow.bottom
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
    
    
    Column {
        anchors.fill: parent
        anchors.margins: 36
        spacing: 30

        // вкладки
        Row {
    id: bottomTabsRow
    spacing: 24
    anchors.horizontalCenter: parent.horizontalCenter
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
                bottomTabsRow.currentIndex = 0
                bottomTabsRow.inContent = false
                bottomFirstTab.forceActiveFocus()
                flick.contentY = topH + (middleH * 0.78)
                ////sNav.play ()
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
                bottomTabsRow.currentIndex = 1
                bottomTabsRow.inContent = false
                bottomSecondTab.forceActiveFocus()
                flick.contentY = topH + (middleH * 0.78)
                ////sNav.stop();
            ////sNav.play();
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
                bottomTabsRow.currentIndex = 2
                bottomTabsRow.inContent = false
                bottomThirdTab.forceActiveFocus()
                flick.contentY = topH + (middleH * 0.78)
                ////sNav.play ()
            }
        }
    }

    // Навигация клавишами по табам и спуск в контент
    Keys.onLeftPressed: {
        if (bottomTabsRow.currentIndex > 0) {
            bottomTabsRow.currentIndex--
            bottomTabsRow.inContent = false
            bottomTabsRow.forceActiveFocus()
            ////sNav.stop();
           ////sNav.play();
        }
    }
    
    Keys.onRightPressed: {
        if (bottomTabsRow.currentIndex < 2) {
            bottomTabsRow.currentIndex++
            bottomTabsRow.inContent = false
            bottomTabsRow.forceActiveFocus()
            ////sNav.stop();
            ////sNav.play();
        }
    }
    
    Keys.onDownPressed: {
        // при спуске явно отдать фокус нужному списку
        bottomTabsRow.inContent = true
        if (bottomTabsRow.currentIndex === 0) newsList.forceActiveFocus()
        else if (bottomTabsRow.currentIndex === 1) friendsList.forceActiveFocus()
        else if (bottomTabsRow.currentIndex === 2) recommendedList.forceActiveFocus()
        ////sNav.stop();
            ////sNav.play();
    }
}

        // Контейнер для списков
        Item {
            id: listsContainer
            anchors.fill: parent
            anchors.topMargin: 220
            width: parent.width
            height: bottomZone.height * 0.6

 // ======== WHAT'S NEW ========
Grid {
    id: newsList
    anchors.fill: parent
    columns: 4
    rows: 2
    columnSpacing: 30
    rowSpacing: 25
    visible: bottomTabsRow.currentIndex === 0
    
    property real rowHeight: parent.height / 3
    
    /*
    Repeater {
        model: 8
        delegate: Item {
            width: parent.width / 4 - parent.columnSpacing * 0.75
            height: index < 4 ? parent.rowHeight * 0.5 : parent.rowHeight * 2.5  // 1-4 в 2 раза ниже, 5-8 в 2.5 раза выше
            property real scaleFactor: newsListFocusHelper === (index + 1) ? 1.04 : 1.0
            
            // Позиционирование по рядам
            y: index < 4 ? 0 : parent.rowHeight * 0.5
            
            
            Rectangle {
                anchors.fill: parent
                color: "#2A2E35"
                scale: scaleFactor
                Behavior on scale { NumberAnimation { duration: 150 } }
                
                Text {
                    anchors.centerIn: parent
                    text: "Button " + (index + 1)
                    color: "white"
                    font.pixelSize: 24
                    font.family: bold.name
                }
                
                
                // Обводка как у других элементов               
                Rectangle {
                    id: newsBorder
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 4
                    border.color: "grey"
                    radius: 0
                    anchors.margins: -7
                    opacity: newsListFocusHelper === (index + 1) ? 0.5 : 0.0
                    visible: opacity > 0

                    SequentialAnimation {
                        id: appearAnim
                        running: newsListFocusHelper === (index + 1)
                        loops: 1

                        ParallelAnimation {
                            NumberAnimation { target: newsBorder; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                            NumberAnimation { target: newsBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                            NumberAnimation { target: newsBorder; property: "anchors.margins"; to: -17; duration: 100; easing.type: Easing.OutBack }
                            ColorAnimation { target: newsBorder; property: "border.color"; to: "white"; duration: 100 }
                            NumberAnimation { target: newsBorder; property: "opacity"; to: 0.5; duration: 100 }
                        }

                        ParallelAnimation {
                            NumberAnimation { target: newsBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: newsBorder; property: "anchors.margins"; to: -7; duration: 100; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: newsBorder; property: "border.width"; to: 4; duration: 100; easing.type: Easing.OutBack }
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
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                        flick.contentY = topH + (middleH * 0.78)
                    }
                    newsListFocusHelper = index + 1
                    //sNav.play()
                }
            }
        }
    }
    
    Keys.onLeftPressed: {
        if (newsListFocusHelper > 1) {
            newsListFocusHelper--
            //sNav.play()
        }
    }
    
    Keys.onRightPressed: {
        if (newsListFocusHelper < 8) {
            newsListFocusHelper++
            //sNav.play()
        }
    }
    
    Keys.onUpPressed: {
        if (newsListFocusHelper > 4) {
            newsListFocusHelper -= 4
        } else {
            bottomTabsRow.inContent = false
            bottomTabsRow.forceActiveFocus()
        }
        //sNav.play()
    }
    
    Keys.onDownPressed: {
        if (newsListFocusHelper <= 4 && newsListFocusHelper + 4 <= 8) {
            newsListFocusHelper += 4
            //sNav.play()
        }
    }
*/
}



Text {
    //text:"Recently updated on yourdevice"
    text: "WORK IN PROGRESS"
    color: "white"
    font.pixelSize: 40
    font.family: bold.name
    y: -130
    visible: bottomTabsRow.currentIndex === 0
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

    delegate: Item {
        width: 420; height: friendsList.height
        property real scaleFactor: ListView.isCurrentItem && friendsList.focus ? 1.04 : 1.0

/*
        Rectangle {
            anchors.fill: parent
            color: "#2A2E35"
            scale: scaleFactor
            Behavior on scale { NumberAnimation { duration: 150 } }

            // Обводка как у игр (анимация идентична newsList)
            Rectangle {
                id: friendsBorder
                anchors.fill: parent
                color: "transparent"
                border.width: 4
                border.color: "grey"
                radius: 2
                anchors.margins: -7
                opacity: (index === friendsList.currentIndex && friendsList.focus) ? 0.5 : 0.0

                SequentialAnimation {
                    id: appearAnim
                    running: (index === friendsList.currentIndex && friendsList.focus)
                    loops: 1

                    ParallelAnimation {
                        NumberAnimation { target: friendsBorder; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                        NumberAnimation { target: friendsBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                        NumberAnimation { target: friendsBorder; property: "anchors.margins"; to: -17; duration: 100; easing.type: Easing.OutBack }
                        ColorAnimation  { target: friendsBorder; property: "border.color"; to: "white"; duration: 100 }
                        NumberAnimation { target: friendsBorder; property: "opacity"; to: 0.5; duration: 100 }
                    }

                    ParallelAnimation {
                        NumberAnimation { target: friendsBorder; property: "radius"; to: 2; duration: 100; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: friendsBorder; property: "anchors.margins"; to: -7; duration: 100; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: friendsBorder; property: "border.width"; to: 4; duration: 100; easing.type: Easing.OutBack }
                    }

                    SequentialAnimation {
                        loops: Animation.Infinite
                        NumberAnimation { target: friendsBorder; property: "opacity"; to: 0.2; duration: 500 }
                        NumberAnimation { target: friendsBorder; property: "opacity"; to: 0.5; duration: 500 }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: "Friend " + (index + 1)
                    color: "white"
                    font.pixelSize: 24
                    font.family: bold.name
                }
                Text {
                    text: "Online now"
                    color: "#00FF00"
                    font.pixelSize: 18
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.focusZone !== 2) {
                    root.goToZone(2)
                    flick.contentY = topH + (middleH * 0.78)
                }
                friendsList.currentIndex = index
                friendsList.forceActiveFocus()
                //sNav.play ()
            }
        }
*/
    }

/*
    Keys.onLeftPressed: {
        if (friendsList.currentIndex > 0) friendsList.currentIndex--
        //sNav.stop();
        ////sNav.play(); 
    }
    Keys.onRightPressed: {
        if (friendsList.currentIndex < friendsList.count - 1) friendsList.currentIndex++
        //sNav.stop();
        //sNav.play();          
    }
    Keys.onUpPressed: {
        bottomTabsRow.inContent = false
        bottomTabsRow.forceActiveFocus()
        //sNav.stop();
        //sNav.play();
    }
*/

}

Text {
    //text:"Recently updated on yourdevice"
    text: "WORK IN PROGRESS"
    color: "white"
    font.pixelSize: 40
    font.family: bold.name
    y: -130
    visible: bottomTabsRow.currentIndex === 1
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
    
    // Заголовки
    Text {
        text: "Play next in your Library"
        color: "white"
        font.pixelSize: 40
        font.family: bold.name
        y: -130
    }
    
    Text {
        text: "Games from your library that you haven't played for a long time"
        color: "grey"
        font.pixelSize: 35
        font.family: bold.name
        y: -75
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
            // Если есть lastPlayed и он старше недели
            if (game.lastPlayed) {
                var lastPlayed = new Date(game.lastPlayed).getTime()
                if (now - lastPlayed > timeThreshold) {
                    games.push(game)
                }
            }
            // Если нет lastPlayed (никогда не запускалась)
            else if (!game.lastPlayed) {
                games.push(game)
            }
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
            leftMargin: sideMargin
            rightMargin: 45
        }
        height: parent.height
        
        // СЕТКА
        Grid {
            id: recommendedList
            anchors.fill: parent
            columns: 7
            rows: 2
            columnSpacing: 28
            rowSpacing: 28
            
            property int currentIndex: 0
            property int displayCount: recommendedContainer.totalSlots
            
            Repeater {
                model: recommendedList.displayCount
                
                delegate: Item {
                    width: (recommendedGrid.width - (recommendedList.columns - 1) * recommendedList.columnSpacing) / recommendedList.columns
                    height: width * 9 / 6 // Правильное соотношение 6:9 как в играх
                    
                    property bool isLibraryButton: index === recommendedContainer.totalSlots - 1
                    property bool isGame: !isLibraryButton && index < recommendedContainer.unfilteredGames.length
                    property var gameData: isGame ? recommendedContainer.unfilteredGames[index] : null
                    property real scaleFactor: recommendedList.currentIndex === index ? 1.04 : 1.0
                    property bool firstClickDone: false
                    property bool isSelected: recommendedList.currentIndex === index && firstClickDone
                    
                    Rectangle {
                        anchors.fill: parent
                        color: isLibraryButton ? "#AA2A2E35" : 
                               (isGame && gameData && gameData.assets && gameData.assets.poster ? "transparent" : "#2A2E35")
                        scale: scaleFactor
                        Behavior on scale { NumberAnimation { duration: 150 } }
                        
                        Image {
                            anchors.fill: parent
                            source: isGame && gameData && gameData.assets && gameData.assets.poster ? gameData.assets.poster : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: isGame && source !== ""
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
        source: isGame && gameData && gameData.assets && gameData.assets.poster ? gameData.assets.poster : ""
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
                                    NumberAnimation { target: recommendedBorder; property: "border.width"; to: 10; duration: 100; easing.type: Easing.OutBack }
                                    NumberAnimation { target: recommendedBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.OutBack }
                                    NumberAnimation { target: recommendedBorder; property: "anchors.margins"; to: -17; duration: 100; easing.type: Easing.OutBack }
                                    ColorAnimation  { target: recommendedBorder; property: "border.color"; to: "white"; duration: 100 }
                                    NumberAnimation { target: recommendedBorder; property: "opacity"; to: 0.5; duration: 100 }
                                }

                                ParallelAnimation {
                                    NumberAnimation { target: recommendedBorder; property: "radius"; to: 0; duration: 100; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: recommendedBorder; property: "anchors.margins"; to: -7; duration: 100; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: recommendedBorder; property: "border.width"; to: 4; duration: 100; easing.type: Easing.OutBack }
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
            recommendedList.currentIndex = index
            recommendedList.forceActiveFocus()
            flick.contentY = topH + (middleH * (index >= 7 ? 1.140 : 0.78))
        } 
        else if (recommendedList.currentIndex !== index) {
            // Если мы уже в зоне, но кликнули на другой индекс
            recommendedList.currentIndex = index
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
    }
}

Keys.onRightPressed: {
    if (currentIndex < displayCount - 1) {
        currentIndex++
        // УСЛОВИЕ: если индекс > 7, двигаем камеру на 1.1, иначе 0.78
        flick.contentY = topH + (middleH * (currentIndex >= 7 ? 1.140 : 0.78))
    }
}

Keys.onUpPressed: {
    if (currentIndex >= 7) {
        currentIndex -= 7
        // УСЛОВИЕ: если индекс > 7, двигаем камеру на 1.1, иначе 0.78
        flick.contentY = topH + (middleH * (currentIndex >= 7 ? 1.140 : 0.78))
    } else {
        bottomTabsRow.inContent = false
        bottomTabsRow.forceActiveFocus()
    }
}

Keys.onDownPressed: {
    if (currentIndex + 7 < displayCount) {
        currentIndex += 7
        // УСЛОВИЕ: если индекс > 7, двигаем камеру на 1.1
        flick.contentY = topH + (middleH * 1.140)
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
            updateUnfilteredGames()
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
            //sNav.stop();
            //sNav.play();
        } else if (root.focusZone === 1) {
            // Со средней зоны переходим в нижнюю
            root.goToZone(2)
            event.accepted = true
            //sNav.stop();
            //sNav.play();
        } else if (root.focusZone === 2 && !bottomTabsRow.inContent) {
            // С табов переходим в контент
            bottomTabsRow.inContent = true
            newsList.forceActiveFocus()
            event.accepted = true
            //sNav.stop();
            //sNav.play();
        }
    } 
    else if (event.key === event.key === Qt.Key_Up) {
        if (root.focusZone === 2 && bottomTabsRow.inContent) {
            // Из контента возвращаемся к табам
            bottomTabsRow.inContent = false
            bottomTabsRow.forceActiveFocus()
            event.accepted = true
            //sNav.stop();
            //sNav.play();
        } else if (root.focusZone === 2) {
            // С нижних табов переходим в среднюю зону
            root.goToZone(1)
            event.accepted = true
            //sNav.stop();
            //sNav.play();
        } else if (root.focusZone === 1) {
            // Со средней зоны переходим в верхнюю
            root.goToZone(0)
            event.accepted = true
            //sNav.stop();
            //sNav.play();
        }
    }
    // Обработка PrevPage/NextPage для BottomZone
else if (api.keys.isPrevPage(event) || api.keys.isNextPage(event)) {
    if (root.focusZone === 2) {
        // Переключаемся между кнопками табов
        if (api.keys.isPrevPage(event)) {
            if (bottomTabsRow.currentIndex > 0) {
                bottomTabsRow.currentIndex--
                bottomTabsRow.inContent = false
                bottomTabsRow.forceActiveFocus()
            }
        } else if (api.keys.isNextPage(event)) {
            if (bottomTabsRow.currentIndex < 2) {
                bottomTabsRow.currentIndex++
                bottomTabsRow.inContent = false
                bottomTabsRow.forceActiveFocus()
            }
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
        }
        else if (root.focusZone === 1) { 
            if (gameList.currentIndex > 0) gameList.currentIndex-- 
        }
        else if (root.focusZone === 2 && bottomTabsRow.inContent) { 
            if (newsList.currentIndex > 0) newsList.currentIndex-- 
        }
        else if (root.focusZone === 2) { 
            if (bottomTabsRow.currentIndex > 0) bottomTabsRow.currentIndex-- 
        }
    } 
    else if (event.key === Qt.Key_Right) {
        if (root.focusZone === 0) { 
            if (topButtonsRow.currentIndex < 3) topButtonsRow.currentIndex++ 
        }
        else if (root.focusZone === 1) { 
            if (gameList.currentIndex < gameList.count - 1) gameList.currentIndex++ 
        }
        else if (root.focusZone === 2 && bottomTabsRow.inContent) { 
            if (newsList.currentIndex < newsList.count - 1) newsList.currentIndex++ 
        }
        else if (root.focusZone === 2) { 
            if (bottomTabsRow.currentIndex < 2) bottomTabsRow.currentIndex++ 
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
    z: 100000000000
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
       if (leftBar.isOpen === false) {
            focusTimer.start()
        }
        // Сразу выставляем фокус на кнопку с индексом 0
        leftBar.currentIndex = 0
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
            onClicked: { 
leftBar.toggle()
focusTimer.start()
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

    if (leftBar.currentIndex === buttonIndex) {
        // Второе нажатие — запускаем страницу
        theme.openPage(buttonIndex)
        leftBar.toggle()
        if (buttonIndex === 6) {
        ////sShowui.play()
        }
    } else {
        // Первое нажатие — переводим фокус
        leftBar.currentIndex = buttonIndex
        leftBar.updateFocus()
        //sNav.play ()
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
                            //sNav.stop();
            //sNav.play();
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
                            //sNav.stop();
            //sNav.play();
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
                            //sNav.stop();
            //sNav.play();
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
                            //sNav.stop();
            //sNav.play();
                        } else {
                            root.toggleOptionsMenu()
                            sLeftClose.play()
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
                ////sNav.stop();
            ////sNav.play();
            }
            else if (event.key === Qt.Key_Down) {
                // Навигация вниз
                if (currentButtonIndex < 3) {
                    currentButtonIndex++
                }
                event.accepted = true
                ////sNav.stop();
            ////sNav.play();
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
            //sShowui.play()
            forceActiveFocus() // Важно: берем фокус при открытии
        }
    }
}

    Keys.onPressed: {
    if (event.key === Qt.Key_Down) {
        if (root.focusZone === 0) {
            // С верхней зоны переходим в среднюю
            root.goToZone(1)
            event.accepted = true
        } else if (root.focusZone === 1) {
            // Со средней зоны переходим в нижнюю
            root.goToZone(2)
            event.accepted = true
        } else if (root.focusZone === 2) {
            // В нижней зоне - переходим в контент соответствующих вкладок
            if (bottomTabsRow.currentIndex === 0) {
                newsList.forceActiveFocus()
                if (newsList.count > 0) newsList.currentIndex = 0
            } else if (bottomTabsRow.currentIndex === 1) {
                friendsList.forceActiveFocus()
                if (friendsList.count > 0) friendsList.currentIndex = 0
            } else if (bottomTabsRow.currentIndex === 2) {
                recommendedList.forceActiveFocus()
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
        } else if (root.focusZone === 1) {
            // Со средней зоны переходим в верхнюю
            root.goToZone(0)
            event.accepted = true
        }
    }
    else if (event.key === Qt.Key_Left) {
        if (root.focusZone === 0) { 
            if (topButtonsRow.currentIndex > 0) {
                topButtonsRow.currentIndex--
                event.accepted = true
            }
        }
        else if (root.focusZone === 1) { 
            if (gameList.currentIndex > 0) {
                gameList.currentIndex--
                event.accepted = true
            }
        }
        else if (root.focusZone === 2) {
            // Навигация по вкладкам или контенту
            if (newsList.focus && newsList.currentIndex > 0) {
                newsList.currentIndex--
                event.accepted = true
            } else if (friendsList.focus && friendsList.currentIndex > 0) {
                friendsList.currentIndex--
                event.accepted = true
            } else if (recommendedList.focus && recommendedList.currentIndex > 0) {
                recommendedList.currentIndex--
                event.accepted = true
            } else if (bottomTabsRow.focus && bottomTabsRow.currentIndex > 0) {
                bottomTabsRow.currentIndex--
                event.accepted = true
            }
        }
    } 
    else if (event.key === Qt.Key_Right) {
        if (root.focusZone === 0) { 
            if (topButtonsRow.currentIndex < 3) {
                topButtonsRow.currentIndex++
                event.accepted = true
            }
        }
        else if (root.focusZone === 1) { 
            if (gameList.currentIndex < gameList.count - 1) {
                gameList.currentIndex++
                event.accepted = true
            }
        }
        else if (root.focusZone === 2) {
            // Навигация по вкладкам или контенту
            if (newsList.focus && newsList.currentIndex < newsList.count - 1) {
                newsList.currentIndex++
                event.accepted = true
            } else if (friendsList.focus && friendsList.currentIndex < friendsList.count - 1) {
                friendsList.currentIndex++
                event.accepted = true
            } else if (recommendedList.focus && recommendedList.currentIndex < recommendedList.count - 1) {
                recommendedList.currentIndex++
                event.accepted = true
            } else if (bottomTabsRow.focus && bottomTabsRow.currentIndex < 2) {
                bottomTabsRow.currentIndex++
                event.accepted = true
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
    else if (event.key === Qt.Key_Menu || api.keys.isPageUp(event)) {
        // Кнопка Menu (левый нижний угол) - открытие левого меню
        leftBar.toggle()
        event.accepted = true
    }
}


    // --- ЛОГИКА АНИМАЦИИ ---
    
        property int nextPageIndex: 0

    function startExitAnimation(index) {
        nextPageIndex = index
        exitAnim.start()
    }

    Component.onCompleted: {
enterAnim.start()
    root.goToZone(1)
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
    interval: 100
    running: false
    repeat: false
    onTriggered: {
        // Просто возвращаем фокус в среднюю зону
        if (root.focusZone === 1) {
            gameList.forceActiveFocus()
            if (gameList.count > 0) {
                gameList.currentIndex = gameList.currentIndex // Перезапускаем выделение
            }
        }
    }
}
}
