import QtQuick 2.0

Item {
    id: customizationPage
    anchors.fill: parent

    property bool showBootAnimation: api.memory.has("showBootAnimation") ? api.memory.get("showBootAnimation") : true
    property int activeItemIndex: 0
    property int maxItemIndex: 5

    property bool sliderActive: false
    property int activeSliderIndex: -1

    // Перенесено из Accessibility: размер игровой зоны/карточек
    property int gameListSize: api.memory.has("gameListSize") ? api.memory.get("gameListSize") : 2
    // Полная альтернативная компоновка Home
    property bool alternativeHomeScreen: api.memory.has("alternativeHomeScreen") ? api.memory.get("alternativeHomeScreen") : false
    // Скругление обложек игр
    property bool roundedCovers: api.memory.has("roundedCovers") ? api.memory.get("roundedCovers") : false

    onGameListSizeChanged: api.memory.set("gameListSize", gameListSize)
    onAlternativeHomeScreenChanged: api.memory.set("alternativeHomeScreen", alternativeHomeScreen)
    onRoundedCoversChanged: api.memory.set("roundedCovers", roundedCovers)

    onActiveItemIndexChanged: {
        var heights = [130, 160, 110, 130, 185, 130]
        var itemTop = settingsItem0.y
        for (var i = 0; i < activeItemIndex; ++i) itemTop += heights[i]
        var itemBottom = itemTop + heights[activeItemIndex]

        var viewTop = flickable.contentY
        var viewBottom = viewTop + flickable.height
        var topMargin = 100
        var bottomMargin = 100
        var newY = flickable.contentY

        if (itemTop - topMargin < viewTop) {
            newY = Math.max(0, itemTop - topMargin)
        } else if (itemBottom + bottomMargin > viewBottom) {
            newY = Math.min(flickable.contentHeight - flickable.height, itemBottom + bottomMargin - flickable.height)
        }

        flickable.contentY = newY
    }
    
    property string steamGridApiKey: api.memory.has("steamGridApiKey") ? api.memory.get("steamGridApiKey") : ""
property bool keyboardOpen: false

onSteamGridApiKeyChanged: { api.memory.set("steamGridApiKey", steamGridApiKey); if (steamGridApiKey !== "" && typeof deckos !== "undefined" && deckos) deckos.scraper.steamGridDbKey = steamGridApiKey } // DECKOS: one key for picker + scraper

function handleAccept() {
    if (keyboardOpen) return
    if (sliderActive) {
        sliderActive = false
        activeSliderIndex = -1
        return
    }
    if (activeItemIndex === 0) showBootAnimation = !showBootAnimation
    else if (activeItemIndex === 1) openKeyboard()
    else if (activeItemIndex === 2) Qt.openUrlExternally("https://www.steamgriddb.com/profile/preferences/api")
    else if (activeItemIndex === 3) alternativeHomeScreen = !alternativeHomeScreen
    else if (activeItemIndex === 4) {
        sliderActive = true
        activeSliderIndex = 4
        focusAnimGameListSize.start()
    }
    else if (activeItemIndex === 5) roundedCovers = !roundedCovers
}
function handleLeft() {
    if (sliderActive && activeSliderIndex === 4) gameListSize = Math.max(1, gameListSize - 1)
}
function handleRight() {
    if (sliderActive && activeSliderIndex === 4) gameListSize = Math.min(5, gameListSize + 1)
}
function handleCancel() {
    if (sliderActive) {
        sliderActive = false
        activeSliderIndex = -1
    }
}

TextEdit {
    id: clipboardHelper
    visible: false
    function getClipboard() {
        text = "";
        paste();
        return text;
    }
}

function openKeyboard() {
    keyboardOpen = true;
    kbScope.forceActiveFocus();
}

    onShowBootAnimationChanged: api.memory.set("showBootAnimation", showBootAnimation)

    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: settingsColumn.height + root.topH
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

    Column {
        id: settingsColumn
        width: parent.width
        spacing: 0

        Item { width: 1; height: 70 }

        Text {
            id: pageTitle
            text: "Customization"
            color: "white"
            font.pixelSize: 50 
            font.family: bold.name
            font.bold: true
            anchors.left: parent.left
            anchors.leftMargin: 50
        }

        Item { width: 1; height: 20 }

        Rectangle {
            id: titleDivider
            height: 1
            width: parent.width - 100
            color: "#333"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item { width: 1; height: 30 }

        // 1. Show Boot Animation (Заглушка)
        Rectangle {
            id: settingsItem0
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 0) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text { text: "Show Boot Animation"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                Text { text: "Play the Steam Deck boot animation when DeckOS starts." /* DECKOS */; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
            }

            Rectangle {
                width: 72; height: 44; radius: 44
                color: showBootAnimation ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 0) ? "gray" : "transparent"; border.width: 6 
                anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44; height: 44; radius: 44; color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 0) ? "gray" : "transparent"; border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: showBootAnimation ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 0) {
                        showBootAnimation = !showBootAnimation
                        if (typeof theme !== "undefined") theme.showBootAnimation = showBootAnimation
                    } else { activeZone = 1; activeItemIndex = 0 }
                }
            }
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }
        
        // 2. SteamGridDB API Key
Rectangle {
    width: parent.width
    height: 160
    color: (activeZone === 1 && activeItemIndex === 1) ? "#30343A" : "transparent"

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text { text: "SteamGridDB API Key"; color: "white"; font.pixelSize: 30; font.family: bold.name }
        Text { text: "Used to fetch game artwork from SteamGridDB."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
    }

    Rectangle {
        id: sgdbInput
        width: parent.width * 0.38
        height: 75
        anchors.right: parent.right
        anchors.rightMargin: 50
        anchors.verticalCenter: parent.verticalCenter
        color: (activeZone === 1 && activeItemIndex === 1) ? "white" : "#31343B"
        Behavior on color { ColorAnimation { duration: 150 } }
        clip: true

        Item {
            id: sgdbScrollContent
            height: parent.height
            width: parent.width

            property real cursorLocalX: sgdbCursorProvider.width
            property real idealX: (parent.width / 2) - cursorLocalX
            x: Math.min(20, idealX)
            Behavior on x { NumberAnimation { duration: 100 } }

            Text {
                id: sgdbTextInner
                anchors.verticalCenter: parent.verticalCenter
                color: (activeZone === 1 && activeItemIndex === 1) ? "black" : "white"
                font.pixelSize: 28
                font.family: bold.name
                text: customizationPage.steamGridApiKey === "" ? "Enter API Key..." : customizationPage.steamGridApiKey.replace(/./g, '•')
                opacity: customizationPage.steamGridApiKey === "" ? 0.4 : 1
            }

            Rectangle {
                width: 3; height: 38
                color: sgdbTextInner.color
                visible: customizationPage.keyboardOpen
                x: sgdbScrollContent.cursorLocalX
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: visible; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0; duration: 500 }
                    NumberAnimation { from: 0; to: 1; duration: 500 }
                }
            }

            Text {
                id: sgdbCursorProvider
                visible: false
                font: sgdbTextInner.font
                text: customizationPage.steamGridApiKey.substring(0, kbScope.cursorPosition).replace(/./g, '•')
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (activeZone === 1 && activeItemIndex === 1) {
                customizationPage.openKeyboard()
            } else {
                activeZone = 1
                activeItemIndex = 1
            }
        }
    }

    Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
}

// 3. SteamGridDB — ссылка на страницу API
Rectangle {
    width: parent.width
    height: 110
    color: (activeZone === 1 && activeItemIndex === 2) ? "#30343A" : "transparent"

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.verticalCenter: parent.verticalCenter
        text: "Get your SteamGridDB API Key"
        color: "white"
        font.pixelSize: 30
        font.family: bold.name
    }

    Rectangle {
        width: 220; height: 60
        anchors.right: parent.right
        anchors.rightMargin: 50
        anchors.verticalCenter: parent.verticalCenter
        color: (activeZone === 1 && activeItemIndex === 2) ? "white" : "#31343B"
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "Open Page"
            color: (activeZone === 1 && activeItemIndex === 2) ? "black" : "white"
            font.pixelSize: 26
            font.family: bold.name
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (activeZone === 1 && activeItemIndex === 2) {
                Qt.openUrlExternally("https://www.steamgriddb.com/profile/preferences/api")
            } else {
                activeZone = 1
                activeItemIndex = 2
            }
        }
    }

    Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
}

// 4. Alternative Home Screen (Switch)
Rectangle {
    width: parent.width
    height: 130
    color: (activeZone === 1 && activeItemIndex === 3) ? "#30343A" : "transparent"

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.verticalCenter: parent.verticalCenter
        spacing: 30

        Text { text: "Alternative Home Screen"; color: "white"; font.pixelSize: 30; font.family: bold.name }
        Text { text: "Fullscreen background, game list moved to the bottom."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
    }

    Rectangle {
        width: 72; height: 44; radius: 44
        color: alternativeHomeScreen ? "#00ACFF" : "#31343B"
        border.color: (activeZone === 1 && activeItemIndex === 3) ? "gray" : "transparent"; border.width: 6 
        anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: 44; height: 44; radius: 44; color: "white"
            border.color: (activeZone === 1 && activeItemIndex === 3) ? "gray" : "transparent"; border.width: 3 
            anchors.verticalCenter: parent.verticalCenter
            x: alternativeHomeScreen ? parent.width - width : 0
            Behavior on x { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (activeZone === 1 && activeItemIndex === 3) {
                alternativeHomeScreen = !alternativeHomeScreen
            } else { activeZone = 1; activeItemIndex = 3 }
        }
    }
    Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
}

// 5. GameList / Game Size (Slider)
Rectangle {
    width: parent.width
    height: 185
    color: (activeZone === 1 && activeItemIndex === 4) ? "#30343A" : "transparent"

    Column {
        anchors.fill: parent
        anchors.leftMargin: 50
        anchors.rightMargin: 50
        anchors.topMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 55

        Text {
            text: (alternativeHomeScreen ? "Game Size: " : "GameList Size: ") + gameListSize
            color: "white"
            font.pixelSize: 30
            font.family: bold.name
        }

        Item {
            width: parent.width
            height: 50

            Item {
                id: sliderTrackGameListSize
                width: parent.width
                height: 13
                
                Rectangle {
                    anchors.fill: parent
                    color: "#555"
                    radius: 5
                    
                    Rectangle {
                        width: parent.width * ((gameListSize - 1) / 4)
                        height: parent.height
                        color: "#00ACFF"
                        radius: 5
                    }
                }

                Rectangle {
                    id: sliderThumbGameListSize
                    width: 60
                    height: 60
                    radius: 60
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: (parent.width * ((gameListSize - 1) / 4)) - (width / 2)

                    SequentialAnimation {
                        id: focusAnimGameListSize
                        NumberAnimation { target: sliderThumbGameListSize; property: "scale"; to: 1.3; duration: 100 }
                        NumberAnimation { target: sliderThumbGameListSize; property: "scale"; to: 1.0; duration: 100 }
                    }
                }
            }

            Text {
                text: "SMALLER"
                color: "white"
                font.pixelSize: 23
                font.family: bold.name
                font.bold: true
                anchors.left: parent.left
                anchors.top: sliderTrackGameListSize.bottom
                anchors.topMargin: 30
            }

            Text {
                text: "LARGER"
                color: "white"
                font.pixelSize: 23
                font.family: bold.name
                font.bold: true
                anchors.right: parent.right
                anchors.top: sliderTrackGameListSize.bottom
                anchors.topMargin: 30
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (activeZone === 1 && activeItemIndex === 4) {
                var percent = mouseX / width
                var val = Math.round(1 + percent * 4)
                gameListSize = Math.max(1, Math.min(5, val))
            } else {
                focusAnimGameListSize.start()
                activeZone = 1
                activeItemIndex = 4
            }
        }
    }
    
    Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
}

// 6. Rounded Covers (Switch)
Rectangle {
    width: parent.width
    height: 130
    color: (activeZone === 1 && activeItemIndex === 5) ? "#30343A" : "transparent"

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 50
        anchors.verticalCenter: parent.verticalCenter
        spacing: 30

        Text { text: "Rounded Covers"; color: "white"; font.pixelSize: 30; font.family: bold.name }
        Text { text: "Adds rounded corners to game covers."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
    }

    Rectangle {
        width: 72; height: 44; radius: 44
        color: roundedCovers ? "#00ACFF" : "#31343B"
        border.color: (activeZone === 1 && activeItemIndex === 5) ? "gray" : "transparent"; border.width: 6 
        anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: 44; height: 44; radius: 44; color: "white"
            border.color: (activeZone === 1 && activeItemIndex === 5) ? "gray" : "transparent"; border.width: 3 
            anchors.verticalCenter: parent.verticalCenter
            x: roundedCovers ? parent.width - width : 0
            Behavior on x { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (activeZone === 1 && activeItemIndex === 5) {
                roundedCovers = !roundedCovers
            } else { activeZone = 1; activeItemIndex = 5 }
        }
    }
    Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
}
    }
    } // Flickable
    
    FocusScope {
    id: kbScope
    anchors.fill: parent
    visible: customizationPage.keyboardOpen
    focus: customizationPage.keyboardOpen
    
    

    property int r: 2
    property int c: 5
    property bool isCaps: false
    property int cursorPosition: 0

     // Анимация прозрачности
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

        onVisibleChanged: {
        if (visible) {
            opacity = 1;
            kbPanel.anchors.bottomMargin = -48;
            root.goToZone(0);
        } else {
            opacity = 0;
            kbPanel.anchors.bottomMargin = -kbPanel.height;
        }
    }


    function processInput(v) {
        if (!v || v === "") return;
        if (v === "Done") {
            customizationPage.keyboardOpen = false
            return
        }

        var cur = customizationPage.steamGridApiKey
        var maxLength = 40

        if (v === "paste") {
            var clip = clipboardHelper.getClipboard()
            if (clip) {
                clip = clip.replace(/[\r\n\t]+/g, "")
                var available = Math.max(0, maxLength - cur.length)
                var toInsert = clip.substring(0, available)
                cur = cur.substring(0, cursorPosition) + toInsert + cur.substring(cursorPosition)
                cursorPosition += toInsert.length
                customizationPage.steamGridApiKey = cur
            }
            return
        }

        if (v === "caps") {
            isCaps = !isCaps
        } else if (v === "backspace") {
            if (cursorPosition > 0) {
                cur = cur.substring(0, cursorPosition - 1) + cur.substring(cursorPosition)
                cursorPosition--
            }
        } else if (v === "left") {
            if (cursorPosition > 0) cursorPosition--
        } else if (v === "right") {
            if (cursorPosition < cur.length) cursorPosition++
        } else {
            if (cur.length < maxLength) {
                var letter = (v.length === 1 && isCaps) ? v.toUpperCase() : v
                cur = cur.substring(0, cursorPosition) + letter + cur.substring(cursorPosition)
                cursorPosition += letter.length
            }
        }

        customizationPage.steamGridApiKey = cur
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            customizationPage.keyboardOpen = false
        }
    }

    Rectangle {
        id: kbPanel
        // 3. Новые размеры и привязки
        width: animatedContent.width 
        height: 405
        color: "#22262F"
        
        anchors.bottom: parent.bottom 
        anchors.right: parent.right
        
        // Стартовое положение: спрятана внизу за пределами экрана
        

        // 1. Анимация плавного выезда снизу вверх
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        
        
        
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent; anchors.margins: 5; spacing: 4
            Repeater {
                    model: [
                        {row:0, wSum:15, keys:[{l:"`",v:"`"},{l:"1",v:"1"},{l:"2",v:"2"},{l:"3",v:"3"},{l:"4",v:"4"},{l:"5",v:"5"},{l:"6",v:"6"},{l:"7",v:"7"},{l:"8",v:"8"},{l:"9",v:"9"},{l:"0",v:"0"},{l:"-",v:"-"},{l:"=",v:"="},{l:"X",v:"backspace",w:2,isBS:true,isSpec:true}]},
                        {row:1, wSum:15, keys:[{l:"Tab",v:"   ",w:1.5,isSpec:true},{l:"Q",v:"q"},{l:"W",v:"w"},{l:"E",v:"e"},{l:"R",v:"r"},{l:"T",v:"t"},{l:"Y",v:"y"},{l:"U",v:"u"},{l:"I",v:"i"},{l:"O",v:"o"},{l:"P",v:"p"},{l:"[",v:"["},{l:"]",v:"]"},{l:"\\",v:"\\",w:1.5}]},
                        {row:2, wSum:15, keys:[{l:"Caps",v:"caps",w:1.8,isSpec:true},{l:"A",v:"a"},{l:"S",v:"s"},{l:"D",v:"d"},{l:"F",v:"f"},{l:"G",v:"g"},{l:"H",v:"h"},{l:"J",v:"j"},{l:"K",v:"k"},{l:"L",v:"l"},{l:";",v:";"},{l:"'",v:"'"},{l:"Enter",v:"Done",w:2.2,c:"#1A9EFF",isSpec:true}]},
                        {row:3, wSum:15, keys:[{l:"Shift",v:"caps",w:2.5,isSpec:true},{l:"Z",v:"z"},{l:"X",v:"x"},{l:"C",v:"c"},{l:"V",v:"v"},{l:"B",v:"b"},{l:"N",v:"n"},{l:"M",v:"m"},{l:",",v:","},{l:".",v:"."},{l:"/",v:"/"},{l:"Shift",v:"caps",w:2.5,isSpec:true}]},
                        {row:4, wSum:13.1, keys:[{l:"☺",v:"",w:1.2,isSpec:true},{l:" ",v:" ",w:6.5},{l:"🌐",v:"paste",w:1.2,isSpec:true},{l:"<",v:"left",w:1.2,isSpec:true},{l:">",v:"right",w:1.2,isSpec:true},{l:"Hide",v:"Done",w:1.8,isSpec:true}]}
                    ]
                delegate: Row {
                    width: kbPanel.width - 10; height: 75; spacing: 4
                    property int rowIndex: modelData.row
                    property real tWeight: modelData.wSum
                    Repeater {
                        model: modelData.keys
                        delegate: Rectangle {
    width: (parent.width / parent.tWeight) * (modelData.w || 1.0) - parent.spacing
    height: parent.height
    color: (kbScope.r === parent.rowIndex && kbScope.c === index) ? "white" : (modelData.isSpec ? "black" : "#0F1318")

    MouseArea {
        anchors.fill: parent
        onPressed: {
            kbScope.r = parent.parent.rowIndex
            kbScope.c = index
            if (typeof sType !== "undefined") sType.play()
            if (modelData.v !== "Done" && modelData.v !== "caps" && modelData.v !== "paste") {
                kbAutoRepeat.start()
            } else {
                kbScope.processInput(modelData.v)
            }
        }
        onReleased: kbAutoRepeat.stop()
        onExited: kbAutoRepeat.stop()
        onCanceled: kbAutoRepeat.stop()

        SequentialAnimation {
            id: kbAutoRepeat
            ScriptAction { script: kbScope.processInput(modelData.v) }
            PauseAnimation { duration: 500 }
            SequentialAnimation {
                loops: Animation.Infinite
                ScriptAction { script: { kbScope.processInput(modelData.v); if (typeof sType !== "undefined") sType.play() } }
                PauseAnimation { duration: 60 }
            }
        }
    }

    Item {
        anchors.fill: parent
        
        Text {
            id: spaceIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === " "
            font.pixelSize: 40
            text: "Y"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 20
        }
        
        Text {
            id: backspaceIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === "backspace"
            font.pixelSize: 40
            text: theme.nintendoLayout ? (theme.universalIcons ? "У" : "Y") : (theme.universalIcons ? "Х" : "X")
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }
        
        Text {
            id: backspaceText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === "backspace"
            font.pixelSize: 22
            text: "Backspace"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
            width: Math.min(implicitWidth, parent.width - 40); elide: Text.ElideRight
        }
        
        Text {
            id: enterIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Enter"
            font.pixelSize: 45
            text: ">"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }
        
        Text {
            id: enterText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Enter"
            font.pixelSize: 26
            text: "Enter"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
            width: Math.min(implicitWidth, parent.width - 40); elide: Text.ElideRight
        }
        
        Text {
            id: hideIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Hide" && modelData.v === "Done"
            font.pixelSize: 40
            text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B")
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }
        
        Text {
            id: hideText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Hide" && modelData.v === "Done"
            font.pixelSize: 24
            text: "Hide"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
            width: Math.min(implicitWidth, parent.width - 40); elide: Text.ElideRight
        }
        
        Text {
            id: leftShiftText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Shift" && index === 0
            font.pixelSize: 26
            text: "Shift"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
            width: Math.min(implicitWidth, parent.width * 0.5 - 15); elide: Text.ElideRight
        }
        
        Text {
            id: leftShiftIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Shift" && index === 0
            font.pixelSize: 45
            text: "<"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
        }
        
        Text {
            id: capsText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === "caps" && modelData.l !== "Shift"
            font.pixelSize: 26
            text: "Caps"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
            width: Math.min(implicitWidth, parent.width * 0.5 - 15); elide: Text.ElideRight
        }
        
        Text {
            id: capsIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.v === "caps" && modelData.l !== "Shift"
            font.pixelSize: 45
            text: "<"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
        }
        
        Text {
            id: rightShiftIcon
            font.family: icons.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Shift" && index === 11
            font.pixelSize: 45
            text: "<"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }
        
        Text {
            id: rightShiftText
            font.family: bold.name
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            visible: modelData.l === "Shift" && index === 11
            font.pixelSize: 26
            text: "Shift"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
            width: Math.min(implicitWidth, parent.width - 40); elide: Text.ElideRight
        }
        
        Text {
            id: arrowText
            font.family: bold.name
            font.pixelSize: 30
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            text: modelData.v === "left" ? "<" : (modelData.v === "right" ? ">" : "")
            visible: modelData.v === "left" || modelData.v === "right"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Text {
            id: emojiGlobeText
            font.family: (modelData.l === "☺") ? icons.name : bold.name
            font.pixelSize: (modelData.l === "☺") ? 45 : 26
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            text: modelData.l === "☺" ? "😀" : (modelData.l === "🌐" ? "Paste" : "")
            visible: modelData.l === "☺" || modelData.l === "🌐"
            anchors.bottom: parent.bottom; anchors.bottomMargin: (modelData.l === "☺") ? 13 : 20
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Text {
            id: specTextOnly
            font.family: bold.name
            font.pixelSize: 26
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            text: modelData.l === "Tab" ? "Tab" : (modelData.l === "   " ? "   " : "")
            visible: !!modelData.isSpec && !spaceIcon.visible && !backspaceIcon.visible && !enterIcon.visible && !hideIcon.visible && !leftShiftText.visible && !capsText.visible && !rightShiftIcon.visible && !arrowText.visible && !emojiGlobeText.visible
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
        }
        
        Text {
            id: normalKeyText
            font.family: bold.name
            font.pixelSize: 26
            color: (kbScope.r === parent.parent.parent.rowIndex && kbScope.c === index) ? "black" : "white"
            text: {
                if (modelData.isSpec) return ""
                if (modelData.v.length === 1) return kbScope.isCaps ? modelData.l.toUpperCase() : modelData.l.toLowerCase()
                return modelData.l
            }
            visible: !modelData.isSpec
            anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.3; anchors.horizontalCenter: parent.horizontalCenter
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
        if (api.keys.isLeft(event)) { if (c > 0) { c--; if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } } event.accepted = true }
        else if (api.keys.isRight(event)) { if (c < rowCounts[r] - 1) { c++; if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } } event.accepted = true }
        else if (api.keys.isUp(event)) { if (r > 0) { r--; c = Math.min(c, rowCounts[r] - 1); if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } } event.accepted = true }
        else if (api.keys.isDown(event)) { if (r < 4) { r++; c = Math.min(c, rowCounts[r] - 1); if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } } event.accepted = true }
        else if (api.keys.isDetails(event)) { processInput("backspace"); event.accepted = true }
        else if (api.keys.isFilters(event)) { processInput(" "); event.accepted = true }
        else if (api.keys.isNextPage(event)) { processInput("Done"); event.accepted = true }
        else if (api.keys.isPrevPage(event)) { isCaps = !isCaps; event.accepted = true }
        else if (api.keys.isCancel(event)) { processInput("Done"); event.accepted = true }
        else if (api.keys.isAccept(event)) {
            var values = [
                ["`","1","2","3","4","5","6","7","8","9","0","-","=","backspace"],
                ["   ","q","w","e","r","t","y","u","i","o","p","[","]","\\"],
                ["caps","a","s","d","f","g","h","j","k","l",";","'","Done"],
                ["caps","z","x","c","v","b","n","m",",",".","/","caps"],
                ["",""," ","left","right","Done"]
            ]
            if (typeof sType !== "undefined") sType.play()
            processInput(values[r][c])
            event.accepted = true
        }
    }
}
}
