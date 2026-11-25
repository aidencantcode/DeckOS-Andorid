import QtQuick 2.15
import QtMultimedia 5.9
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15

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

    // ── Звуки ──────────────────────────────────────────────────────────────
    SoundEffect { id: sNav;       source: "../assets/audio/nav.wav";                       volume: 1.0 }
    SoundEffect { id: sAccept;    source: "../assets/audio/accept.wav";                    volume: 1.0 }
    SoundEffect { id: sBack;      source: "../assets/audio/back.wav";                      volume: 1.0 }
    SoundEffect { id: sLeftOpen;  source: "../assets/audio/deck_ui_side_menu_fly_in.wav";  volume: 1.0 }
    SoundEffect { id: sLeftClose; source: "../assets/audio/deck_ui_side_menu_fly_out.wav"; volume: 1.0 }
    SoundEffect { id: sShowui;    source: "../assets/audio/deck_ui_show_ui.wav";           volume: 1.0 }

    // ── Свойства ───────────────────────────────────────────────────────────
    property var  theme
    property real topH:    95
    property real bottomH: topH
    property bool hasFocus:          activeFocus
    property bool isReady:           true
    property bool closeMenuVisible:  false
    property bool optionsMenuVisible: false

    // activeZone: 0 = левая панель настроек, 1 = правый контент
    // (именно это значение читают страницы типа general.qml)
    property int activeZone:     0
    property int activeMenuIndex: 0

        property int focusZone: 1

    property string nextSource: ""
    property int animDirection: 1 // 1 = вниз, -1 = вверх

    function switchPage(newIndex) {
        if (activeMenuIndex === newIndex) return;
        animDirection = newIndex > activeMenuIndex ? 1 : -1;
        activeMenuIndex = newIndex;
        nextSource = left.buttons[newIndex].qmlSource;
        pageTransitionAnim.restart();
    }

    // DECKOS: open a section directly (theme.openSettingsPage, e.g. from the profile in the side menu)
    function selectSection(source) {
        if (theme) theme.pendingSettingsPage = ""
        for (var i = 0; i < left.buttons.length; i++) {
            if (left.buttons[i].qmlSource === source) {
                switchPage(i)
                activeZone = 1
                goToZone(1)
                return
            }
        }
    }
    onThemeChanged: if (theme && theme.pendingSettingsPage !== "") selectSection(theme.pendingSettingsPage)


    // ── goToZone ───────────────────────────────────────────────────────────
    // Аналог home.qml: снимаем фокус со всего, отдаём нужному элементу
    function goToZone(zoneIndex) {
        topButtonsRow.focus        = false
        settingsZoneFocusProxy.focus = false

        focusZone = zoneIndex

        if (zoneIndex === 0) {
            topButtonsRow.forceActiveFocus()
            topButtonsRow.focus = true
        } else {
            // Зона 1 (левая) или 2 (правая) — proxy получает QML-фокус
            settingsZoneFocusProxy.forceActiveFocus()
            settingsZoneFocusProxy.focus = true
        }
    }
    
    

    // ── Глобальный Keys.onPressed (только то, что не ловит proxy/topBar) ──
    Keys.onPressed: {
        if (leftBar.isOpen || closeMenuVisible) return

        // MENU — всегда открывает боковое меню
        if (api.keys.isMenu(event)) {
            leftBar.toggle()
            event.accepted = true
        }
        // BACK из топ-бара → возврат в контент настроек
        else if ((api.keys.isCancel(event) || event.key === Qt.Key_Escape) && focusZone === 0) {
            goToZone(1)
            sBack.stop(); sBack.play()
            event.accepted = true
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ANIMATED CONTENT — НЕ ТРОГАТЬ!
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: animatedContent
        anchors.fill: parent

        Rectangle {
            id: background
            anchors.fill: parent
            color: "#0F1318"
        }

        Row {
            id: settingsLayout
            anchors.fill: parent
            spacing: 0

            // ── ЛЕВАЯ ЗОНА (меню настроек) ─────────────────────────────
            Rectangle {
                id: left
                width: parent.width * 0.26
                height: parent.height
                color: "#23262B"

                property var buttons: []

                Column {
                    id: leftButtonColumn
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                }

                Component {
                    id: leftMenuButtonComponent

                    Rectangle {
                        id: btnRoot
                        width: parent.width
                        height: Math.max(58, Math.min(90, (root.height - 260) / 11)) // DECKOS: 11 sections must fit (was 90)

                        property string title: ""
                        property int    buttonIndex: 0
                        property string icon: ""
                        property string qmlSource: ""

                        // Подсветка активной кнопки
                        color: (activeMenuIndex === btnRoot.buttonIndex) ? "#464950" : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 35

                            Text {
                                text: btnRoot.icon
                                font.family: icons.name
                                font.pixelSize: 40
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: btnRoot.title
                                font.pixelSize: 30
                                font.family: bold.name
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                                                MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (activeMenuIndex !== btnRoot.buttonIndex) {
                                    switchPage(btnRoot.buttonIndex)
                                }
                                activeZone = 0
                                goToZone(1)
                                sNav.stop(); sNav.play()
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    // DECKOS: Library and Profile added (Pegasus settings + user profile live here now)
                    var pages = [
                        ["General",       "w", "settings/general.qml"],
                        ["Library",       "L", "settings/library.qml"],
                        ["Emulators",     "D", "settings/emulators.qml"],
                        ["Profile",       "F", "settings/profile.qml"],
                        ["Accessibility", "¹", "settings/accessibility.qml"],
                        ["Sound",         "S", "settings/sound.qml"],
                        ["Power",         "~", "settings/power.qml"],
                        ["High Contrast", "●", "settings/highcontrast.qml"],
                        ["Customization", "☆", "settings/customization.qml"],
                        ["Controller",    "G", "settings/controller.qml"],
                        ["System",        "М", "settings/system.qml"]
                    ]
                    var btns = []
                    for (var i = 0; i < pages.length; i++)
                        btns.push(leftMenuButtonComponent.createObject(leftButtonColumn, { "title": pages[i][0], "buttonIndex": i, "icon": pages[i][1], "qmlSource": pages[i][2] }))
                    left.buttons = btns
                }
            }

                        // ── ПРАВАЯ ЗОНА (контент) ──────────────────────────────────
            Rectangle {
                id: rightZone
                width: parent.width * 0.74
                height: parent.height - topBar.height
                anchors.verticalCenter: parent.verticalCenter
                color: "#0F1318"
                clip: false // ВАЖНО: обрезает контент при анимации за пределами зоны

                Loader {
                    id: contentLoader
                    width: parent.width
                    height: parent.height
                    source: "settings/general.qml"
                }

                SequentialAnimation {
                    id: pageTransitionAnim
                    
                    // 1. Старая страница уходит (на 5% высоты) со снижением Opacity
                    ParallelAnimation {
                        NumberAnimation { target: contentLoader; property: "opacity"; to: 0.1; duration: 150; easing.type: Easing.InOutQuad }
                        NumberAnimation { 
                            target: contentLoader; 
                            property: "y"; 
                            to: animDirection === 1 ? -rightZone.height * 0.05 : rightZone.height * 0.05; 
                            duration: 150; 
                            easing.type: Easing.InOutQuad 
                        }
                    }
                    
                    // 2. Подмена источника и установка начальной позиции для новой страницы (противоположные 5%)
                    ScriptAction {
                        script: {
                            contentLoader.source = nextSource
                            contentLoader.y = animDirection === 1 ? rightZone.height * 0.05 : -rightZone.height * 0.05
                        }
                    }
                    
                    // 3. Новая страница плавно появляется и сдвигается в 0 координату
                    ParallelAnimation {
                        NumberAnimation { target: contentLoader; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: contentLoader; property: "y"; to: 0; duration: 150; easing.type: Easing.InOutQuad }
                    }
                }
            }

        }
    }
    // ══════════════════════════════════════════════════════════════════════
    // END ANIMATED CONTENT
    // ══════════════════════════════════════════════════════════════════════

    // ── Сброс activeItemIndex при загрузке новой страницы ─────────────────
    Connections {
        target: contentLoader
        function onStatusChanged() { // DECKOS: Qt 5.15 Connections syntax
            if (contentLoader.status === Loader.Ready &&
                contentLoader.item &&
                contentLoader.item.hasOwnProperty("activeItemIndex")) {
                contentLoader.item.activeItemIndex = 0
            }
        }
    }

    // ── settingsZoneFocusProxy ─────────────────────────────────────────────
    // Невидимый Item — получает QML-фокус для зон 1 и 2 (левая + правая панели).
    // Аналог gameList / bottomTabsRow в home.qml: содержит всю логику навигации.
    Item {
        id: settingsZoneFocusProxy
        anchors.fill: parent
        focus: false
        z: -1   // Ниже всего визуального; MouseArea нет → мышь не перехватывает

        Keys.onPressed: {
    if (leftBar.isOpen || closeMenuVisible) return

    var page = contentLoader.item

      // ── ВВЕРХ ── (навигация по пунктам правой зоны или левой панели)
    if (event.key === Qt.Key_Up) {
        if (activeZone === 0) {
            if (activeMenuIndex > 0) {
                switchPage(activeMenuIndex - 1)
                sNav.stop(); sNav.play()
            } else {
                goToZone(0)
                sNav.stop(); sNav.play()
            }
        } else if (activeZone === 1 && page && page.hasOwnProperty("activeItemIndex")) {
            if (page.activeItemIndex > 0) {
                page.activeItemIndex--
                sNav.stop(); sNav.play()
            }
        }
        event.accepted = true
    }
    // ── ВНИЗ ──
    else if (event.key === Qt.Key_Down) {
        if (activeZone === 0) {
            if (left.buttons.length > 0 && activeMenuIndex < left.buttons.length - 1) {
                switchPage(activeMenuIndex + 1)
                sNav.stop(); sNav.play()
            }
        } else if (activeZone === 1 && page && page.hasOwnProperty("activeItemIndex")) {
            var maxIdx = page.hasOwnProperty("maxItemIndex") ? page.maxItemIndex : 20
            if (page.activeItemIndex < maxIdx) {
                page.activeItemIndex++
                sNav.stop(); sNav.play()
            }
        }
        event.accepted = true
    }
    // ── ВЛЕВО ── (переключение зоны или вызов слайдера страницы)
    else if (event.key === Qt.Key_Left) {
        if (activeZone === 1) {
            // Если страница поддерживает слайдер и он активен → передаём странице
            if (page && page.hasOwnProperty("sliderActive") && page.sliderActive) {
                if (page.hasOwnProperty("handleLeft")) page.handleLeft()
            } else {
                activeZone = 0
                sNav.stop(); sNav.play()
            }
        }
        event.accepted = true
    }
    // ── ВПРАВО ── (переключение зоны или вызов слайдера страницы)
    else if (event.key === Qt.Key_Right) {
        if (activeZone === 0) {
            activeZone = 1
            if (page && page.hasOwnProperty("activeItemIndex")) {
                page.activeItemIndex = 0
            }
            sNav.stop(); sNav.play()
        } else if (activeZone === 1) {
            if (page && page.hasOwnProperty("sliderActive") && page.sliderActive) {
                if (page.hasOwnProperty("handleRight")) page.handleRight()
            }
        }
        event.accepted = true
    }
    // ── ПРИНЯТЬ (A) ──
    else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
        if (activeZone === 0) {
            if (activeMenuIndex >= 0 && left.buttons.length > activeMenuIndex) {
                contentLoader.source = left.buttons[activeMenuIndex].qmlSource
                activeZone = 1
            }
        } else if (activeZone === 1 && page && page.hasOwnProperty("handleAccept")) {
            page.handleAccept()
        }
        event.accepted = true
    }
    // ── НАЗАД / ОТМЕНА ──
    else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
        if (activeZone === 1 && page && typeof page.handleBack === "function" && page.handleBack()) {
            sBack.stop(); sBack.play() // DECKOS: the page went back within itself (sub-list)
        } else if (activeZone === 1 && page && page.hasOwnProperty("sliderActive") && page.sliderActive) {
            if (page.hasOwnProperty("handleCancel")) page.handleCancel()
        } else if (activeZone === 1) {
            activeZone = 0
            sBack.stop(); sBack.play()
        } else {
            leftBar.toggle()
        }
        event.accepted = true
    }
    else if (api.keys.isMenu(event)) {
        leftBar.toggle()
        event.accepted = true
    }
}
    }

    // ══════════════════════════════════════════════════════════════════════
    // TOP BAR
    // ══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: topBar
        width: parent.width
        height: root.topH
        color: "transparent"
        z: 10000

        Rectangle {
            anchors.fill: parent
            color: leftBar.isOpen || topButtonsRow.focus
                   ? Qt.rgba(0, 0, 0, 1.0)
                   : Qt.rgba(0, 0, 0, 0.85)
            Behavior on color { ColorAnimation { duration: 200 } }
            z: -1
        }

        Row {
            id: topButtonsRow
            anchors {
                left:          parent.left
                right:         parent.right
                verticalCenter: parent.verticalCenter
                rightMargin:   15
            }
            property int currentIndex: 0
            spacing: 0

            // ── ПОИСК ─────────────────────────────────────────────────
            Rectangle {
                id: topBtnSearch
                width: topBar.width - (topBtnNet.width + topBarBattery.width + topBtnClock.width + topBtnUser.width + topButtonsRow.spacing * 3 + topButtonsRow.anchors.rightMargin * 2)
                height: root.topH
                color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "white" : "transparent"
                border.width: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: "¿"
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "black" : "white"

                    readonly property real posRight: topBtnSearch.width - 50
                    readonly property real posLeft:  15
                    x: posRight

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
                                    NumberAnimation { target: searchIcon; property: "x";       to: searchIcon.posRight - 20; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                                }
                                PropertyAction { target: searchIcon; property: "x"; value: searchIcon.posLeft + 20 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x";       to: searchIcon.posLeft; duration: 200; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 1; duration: 200 }
                                }
                            }
                        },
                        Transition {
                            from: "focused"; to: "default"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x";       to: searchIcon.posLeft + 20; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                                }
                                PropertyAction { target: searchIcon; property: "x"; value: searchIcon.posRight - 20 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x";       to: searchIcon.posRight; duration: 200; easing.type: Easing.OutQuad }
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
                                PropertyAction { target: searchText; property: "visible"; value: true }
                                PauseAnimation { duration: 150 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchText; property: "opacity"; to: 1;       duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchText; property: "x";       to: targetX; duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        },
                        Transition {
                            from: "focused"; to: "*"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: searchText; property: "opacity"; to: 0;             duration: 150; easing.type: Easing.InCubic }
                                    NumberAnimation { target: searchText; property: "x";       to: targetX + 20; duration: 150; easing.type: Easing.InCubic }
                                }
                                PropertyAction { target: searchText; property: "visible"; value: false }
                            }
                        }
                    ]
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                            theme.openPage(9)
                        } else {
                            root.goToZone(0)
                            topButtonsRow.currentIndex = 0
                            topButtonsRow.forceActiveFocus()
                            sNav.stop(); sNav.play()
                        }
                    }
                }
            }

            // ── СЕТЬ ──────────────────────────────────────────────────
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
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0); topButtonsRow.currentIndex = 1
                        topButtonsRow.forceActiveFocus(); sNav.stop(); sNav.play()
                    }
                }
            }

            // ── БАТАРЕЯ ───────────────────────────────────────────────
            Item {
                id: topBarBattery
                width: theme.showBatteryPercent ? 170 : 70
                height: root.topH

                Rectangle {
                    id: batteryBg
                    anchors.fill: parent
                    color: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "white" : "transparent"
                    border.width: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? 2 : 0
                    border.color: "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    id: batteryRow
                    spacing: 5
                    anchors.centerIn: parent

                    function getBatteryIcon() {
                        if (isNaN(api.device.batteryPercent)) return "../assets/theme-icons/battery" + getSuffix() + ".png"
                        const p = api.device.batteryPercent * 100
                        if (p <= 20) return "../assets/theme-icons/20" + getSuffix() + ".png"
                        if (p <= 40) return "../assets/theme-icons/40" + getSuffix() + ".png"
                        if (p <= 60) return "../assets/theme-icons/60" + getSuffix() + ".png"
                        if (p <= 80) return "../assets/theme-icons/80" + getSuffix() + ".png"
                        return "../assets/theme-icons/battery" + getSuffix() + ".png"
                    }
                    function getSuffix() {
                        return (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "B" : ""
                    }

                    Text {
                        text: isNaN(api.device.batteryPercent) ? "N/A" : (api.device.batteryPercent * 100).toFixed(0) + "%"
                        visible: theme.showBatteryPercent
                        color: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "black" : "white"
                        font.family: bold.name; font.pixelSize: 36
                        verticalAlignment: Text.AlignVCenter
                    }
                    Item {
                        width: 57; height: 33
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            anchors.fill: parent
                            source: batteryRow.getBatteryIcon()
                            mipmap: true
                        }
                        Image {
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
                        root.goToZone(0); topButtonsRow.currentIndex = 2
                        topButtonsRow.forceActiveFocus(); sNav.stop(); sNav.play()
                    }
                }
            }

            // ── ЧАСЫ ──────────────────────────────────────────────────
            Rectangle {
                id: topBtnClock
                width: theme.use24HourFormat ? 130 : 200; height: root.topH
                color: "transparent"; border.color: "transparent"
                property string timeFormat: theme.use24HourFormat ? "HH:mm" : "hh:mm AP"
                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), topBtnClock.timeFormat)
                    font.pixelSize: 35; font.family: bold.name; color: "white"
                }
                Timer { interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat) }
                onTimeFormatChanged: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
            }

            // ── ПОЛЬЗОВАТЕЛЬ ──────────────────────────────────────────
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
                    width: parent.width * 0.85; height: parent.height * 0.8
                    source: (root.theme && root.theme.profilePictureSource !== "") ? root.theme.profilePictureSource : "../assets/logo/logo.jpg" /* DECKOS */
                    fillMode: Image.PreserveAspectFit
                    playing: visible && status === AnimatedImage.Ready &&
                             (api.memory.has("animatedCovers") ? api.memory.get("animatedCovers") : false)
                }
                Rectangle {
                    anchors { top: userImage.top; bottom: userImage.bottom; right: userImage.right }
                    width: 10; color: "#00BFFF"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0); topButtonsRow.currentIndex = 3
                        topButtonsRow.forceActiveFocus(); sNav.stop(); sNav.play()
                    }
                }
            }

            // ── Клавиши топ-бара (аналог home.qml) ───────────────────
            Keys.onLeftPressed: {
                if (topButtonsRow.currentIndex > 0) topButtonsRow.currentIndex--
                sNav.stop(); sNav.play()
            }
            Keys.onRightPressed: {
                if (topButtonsRow.currentIndex < 3) topButtonsRow.currentIndex++
                sNav.stop(); sNav.play()
            }
            Keys.onDownPressed: {
                // Всегда приземляемся на ЛЕВУЮ панель
                activeZone = 0
                root.goToZone(1)
                sNav.stop(); sNav.play()
            }
            Keys.onPressed: {
                if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                    if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                        theme.openPage(9)
                        event.accepted = true
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // BOTTOM BAR
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: bottomBar
        width: parent.width; height: root.topH
        anchors.bottom: parent.bottom
        z: 100000000000
        clip: true
        visible: !(contentLoader.item && contentLoader.item.hasOwnProperty("keyboardOpen") && contentLoader.item.keyboardOpen)

        ShaderEffectSource {
            id: bottomAreaSource
            sourceItem: globalBlurSource
            sourceRect: Qt.rect(0, root.height - root.topH, root.width, root.topH)
            live: true; visible: false
        }
        GaussianBlur {
            anchors.fill: parent; source: bottomAreaSource
            radius: 150; samples: 64; transparentBorder: false
            visible: !theme.highContrastBottomBar
        }
        Rectangle {
            anchors.fill: parent; color: "black"
            opacity: theme.highContrastBottomBar ? 1.0
                     : (leftBar.isOpen || root.closeMenuVisible || root.optionsMenuVisible ? 0.9 : 0.6)
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Кнопка MENU
        Rectangle {
            id: btnMenu
            width: 180; height: parent.height
            anchors.left: parent.left; anchors.leftMargin: 18
            color: "transparent"
            Row {
                anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Text { text: ":";  font.family: icons.name; font.pixelSize: 54; color: "white" }
                Text {
                    text: root.closeMenuVisible ? "PEGASUS MENU" : "MENU"
                    font.family: bold.name; font.pixelSize: 28; color: "white"
                    y: parent.height * 0.21
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: if (!root.closeMenuVisible) {
                    leftBar.toggle()
                    leftBar.currentIndex = theme ? theme.currentPage : 0 // DECKOS: theme is assigned after creation
                    leftBar.updateFocus()
                }
            }
        }

        // Правая группа подсказок + BACK
        Row {
            id: rightGroup
            anchors.right: parent.right; anchors.rightMargin: 35
            anchors.verticalCenter: parent.verticalCenter
            spacing: 38
            Row {
                spacing: 18; anchors.verticalCenter: parent.verticalCenter
                Text { text: theme.nintendoLayout ? (theme.universalIcons ? "В":"B") : (theme.universalIcons ? "А":"A")
                       font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025 }
                Text { text: "SELECT"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
            }
            Rectangle {
                id: btnBack
                width: 140; height: parent.height; color: "transparent"
                Row {
                    anchors.centerIn: parent; spacing: 18
                    Text { text: theme.nintendoLayout ? (theme.universalIcons ? "А":"A") : (theme.universalIcons ? "В":"B")
                           font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025 }
                    Text { text: "BACK"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.closeMenuVisible) {
                            root.closeMenuVisible = false
                            sLeftClose.play(); focusTimer.start()
                        } else if (root.focusZone === 1 && root.activeZone === 1) {
                            root.activeZone = 0
                            sBack.stop(); sBack.play()
                        } else if (root.focusZone === 1 && root.activeZone === 0) {
                            leftBar.toggle()
                            sBack.stop(); sBack.play()
                        } else if (root.focusZone === 0) {
                            root.goToZone(1)
                            sBack.stop(); sBack.play()
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // CLOSE MENU
    // ══════════════════════════════════════════════════════════════════════
    FocusScope {
        id: closeMenu
        anchors.fill: parent
        visible: closeMenuVisible; focus: closeMenuVisible; enabled: visible
        z: 9999
        opacity: closeMenuVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        property int currentButtonIndex: 0

        Item {
            anchors.fill: parent; z: 0
            MouseArea { anchors.fill: parent }
            FastBlur { anchors.fill: parent; source: globalBlurSource; radius: 50; transparentBorder: false }
            Rectangle { anchors.fill: parent; color: "black"; opacity: 0.7 }
        }

        Rectangle {
            width: 550; height: 240
            anchors.centerIn: parent; color: "#181B20"; z: 1

            Text {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: -65 }
                text: "Close"; color: "white"; font.pixelSize: 38; font.family: bold.name
            }

            Column { anchors.centerIn: parent; width: parent.width; height: parent.height; spacing: 0
                Rectangle {
                    id: exitButton
                    width: parent.width; height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 0 ? "#DE3619" : "transparent"
                    Text { text: "   Exit"; color: "white"; font.pixelSize: 35; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }
                    MouseArea { anchors.fill: parent; onClicked: {
                        if (closeMenu.currentButtonIndex !== 0) { closeMenu.currentButtonIndex = 0; sNav.stop(); sNav.play() }
                        else Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                    }}
                }
                Rectangle {
                    id: cancelButton1
                    width: parent.width; height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 1 ? "white" : "transparent"
                    Text { text: "   Cancel"; color: closeMenu.currentButtonIndex === 1 ? "black" : "white"
                           font.pixelSize: 35; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }
                    MouseArea { anchors.fill: parent; onClicked: {
                        if (closeMenu.currentButtonIndex !== 1) { closeMenu.currentButtonIndex = 1; sNav.stop(); sNav.play() }
                        else { closeMenuVisible = false; sLeftClose.play(); focusTimer.start() }
                    }}
                }
            }
        }

        Keys.onPressed: {
            if (!closeMenuVisible) return
            if (event.key === Qt.Key_Up) {
                if (currentButtonIndex > 0) { currentButtonIndex--; sNav.stop(); sNav.play() }
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                if (currentButtonIndex < 1) { currentButtonIndex++; sNav.stop(); sNav.play() }
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                event.accepted = true
            } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                if (currentButtonIndex === 0) { Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */ }
                else { closeMenuVisible = false; sLeftClose.play(); focusTimer.start() }
                event.accepted = true
            } else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                closeMenuVisible = false; sLeftClose.play(); focusTimer.start()
                event.accepted = true
            }
        }

        onVisibleChanged: {
            if (visible) { currentButtonIndex = 0; sShowui.play(); forceActiveFocus() }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // LEFT OVERLAY
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: leftOverlay
        anchors.fill: parent; z: 0
        opacity: (leftBar.x + leftBar.width) / leftBar.width
        visible: opacity > 0
        MouseArea { anchors.fill: parent; enabled: leftBar.isOpen; onClicked: { leftBar.toggle(); focusTimer.start() } }
        FastBlur { anchors.fill: parent; source: globalBlurSource; radius: 50; transparentBorder: false }
        Rectangle { anchors.fill: parent; color: "black"; opacity: 0.7 }
    }

    // ══════════════════════════════════════════════════════════════════════
    // LEFT BAR
    // ══════════════════════════════════════════════════════════════════════
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

        property bool isOpen:   false
        property int  currentIndex: 6
        property var  buttons: []

        Keys.onPressed: {
            if (!leftBar.isOpen || !leftBar.focus) return
            if (event.key === Qt.Key_Up) {
                if (currentIndex > 0) { currentIndex--; updateFocus(); sNav.stop(); sNav.play() }
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                if (currentIndex < buttons.length - 1) { currentIndex++; updateFocus(); sNav.stop(); sNav.play() }
                event.accepted = true
            } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                if (currentIndex === 7) { toggle(); root.closeMenuVisible = true; focusTimer.start() }
                else { theme.openPage(currentIndex); toggle(); if (currentIndex === 6) sShowui.play() }
                event.accepted = true
            } else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                toggle(); focusTimer.start(); event.accepted = true
            } else if (api.keys.isMenu(event)) {
                toggle(); focusTimer.start(); event.accepted = true
            } else {
                event.accepted = true
            }
        }

        Rectangle {
            id: menuPanel
            width: parent.width * 0.25; height: parent.height
            color: "#181B20"; anchors.left: parent.left; z: 1000
            x: leftBar.isOpen ? width * 0.2 : 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            ProfileBadge { // DECKOS: user picture + name (Settings > Profile)
                theme: root.theme
                anchors.left: parent.left; anchors.leftMargin: 40
                anchors.right: parent.right; anchors.rightMargin: 20
                y: parent.height * 0.105; height: parent.height * 0.075
            }
            Column {
                id: buttonColumn
                anchors { left: parent.left; top: parent.top; topMargin: parent.height * 0.2 /* DECKOS: was 0.11, room for the profile */ }
                spacing: 0
            }
        }

        Component {
            id: menuButtonComponent
            FocusScope {
                id: buttonScope
                property string title: ""; property int buttonIndex: 0; property string icon: ""
                width: menuPanel.width; height: Math.min(106, menuPanel.height * 0.085) /* DECKOS: was 106 */
                property bool  isFocused: activeFocus
                property color bgColor:   "transparent"
                property color textColor: "#AAA"
                onIsFocusedChanged: {
                    bgColor   = isFocused ? "#27303A"     : "transparent"
                    textColor = isFocused ? "white"       : "#AAA"
                }
                Rectangle {
                    anchors.fill: parent; color: bgColor
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Item {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 20; bottomMargin: 20 }
                        width: 11; visible: theme.currentPage === buttonIndex
                        Rectangle {
                            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                            width: 27; color: "#1A9EFF"; radius: 40
                        }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: menuPanel.width * 0.083
                        spacing: 38
                        Text { text: icon;  font.family: icons.name; font.pixelSize: menuPanel.width * 0.075; color: "white" }
                        Text { text: title; font.family: bold.name;  font.pixelSize: menuPanel.width * 0.075; color: "white" }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (leftBar.currentIndex === buttonIndex) {
                            if (buttonIndex === 7) { leftBar.toggle(); root.closeMenuVisible = true; focusTimer.start() }
                            else { theme.openPage(buttonIndex); leftBar.toggle(); if (buttonIndex === 6) sShowui.play() }
                        } else {
                            leftBar.currentIndex = buttonIndex; leftBar.updateFocus(); sNav.play()
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            var b0 = menuButtonComponent.createObject(buttonColumn, { "title": "Home",             "buttonIndex": 0, "icon": "^"  })
            var b1 = menuButtonComponent.createObject(buttonColumn, { "title": "Library",          "buttonIndex": 1, "icon": "L"  })
            var b2 = menuButtonComponent.createObject(buttonColumn, { "title": "Store",            "buttonIndex": 2, "icon": "€"  })
            var b3 = menuButtonComponent.createObject(buttonColumn, { "title": "Friends and Chat", "buttonIndex": 3, "icon": "F"  })
            var b4 = menuButtonComponent.createObject(buttonColumn, { "title": "Media",            "buttonIndex": 4, "icon": "M"  })
            var b5 = menuButtonComponent.createObject(buttonColumn, { "title": "Downloads",        "buttonIndex": 5, "icon": "♠︎" })
            var b6 = menuButtonComponent.createObject(buttonColumn, { "title": "Settings",         "buttonIndex": 6, "icon": "w"  })
            var b7 = menuButtonComponent.createObject(buttonColumn, { "title": "Close",            "buttonIndex": 7, "icon": "C"  })
            leftBar.buttons = [b0, b1, b2, b3, b4, b5, b6, b7]
            currentIndex = theme ? theme.currentPage : 0 // DECKOS: theme is assigned after creation
            updateFocus()
        }

        function updateFocus() {
            if (currentIndex >= 0 && currentIndex < buttons.length)
                buttons[currentIndex].forceActiveFocus()
        }
        function toggle() { theme.toggleLeftBar(leftBar) }
    }

    // ══════════════════════════════════════════════════════════════════════
    // АНИМАЦИИ И ИНИЦИАЛИЗАЦИЯ
    // ══════════════════════════════════════════════════════════════════════
    property int nextPageIndex: 0

    function startExitAnimation(index) {
        nextPageIndex = index
        exitAnim.start()
    }

    Component.onCompleted: {
        enterAnim.start()
        goToZone(1)          // Стартуем на левой панели (как home.qml стартует на zone 1)
        focusTimer.start()
    }

    SequentialAnimation {
        id: enterAnim
        ScriptAction { script: { animatedContent.opacity = 0; animatedContent.scale = 0.95 } }
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 1;   duration: 225; easing.type: Easing.OutQuad }
            NumberAnimation { target: animatedContent; property: "scale";   to: 1.0; duration: 225; easing.type: Easing.OutQuad }
        }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 0;    duration: 225; easing.type: Easing.InQuad }
            NumberAnimation { target: animatedContent; property: "scale";   to: 0.95; duration: 225; easing.type: Easing.InQuad }
        }
        ScriptAction { script: theme.finalizeNavigation(nextPageIndex) }
    }

    // Таймер восстановления фокуса после закрытия оверлеев
    Timer {
        id: focusTimer
        interval: 100; running: false; repeat: false
        onTriggered: {
            if (!root.closeMenuVisible) {
                if (root.focusZone === 0) {
                    topButtonsRow.forceActiveFocus()
                } else {
                    settingsZoneFocusProxy.forceActiveFocus()
                    settingsZoneFocusProxy.focus = true
                }
            }
        }
    }
}
