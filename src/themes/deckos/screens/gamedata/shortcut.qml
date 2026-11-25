import QtQuick 2.0

Item {
    id: customizationPage
    anchors.fill: parent

    property bool showBootAnimation: api.memory.has("showBootAnimation") ? api.memory.get("showBootAnimation") : true
    property int activeItemIndex: 0
    property int maxItemIndex: 2
    
    property string steamGridApiKey: api.memory.has("steamGridApiKey") ? api.memory.get("steamGridApiKey") : ""
property bool keyboardOpen: false

onSteamGridApiKeyChanged: { api.memory.set("steamGridApiKey", steamGridApiKey); if (steamGridApiKey !== "" && typeof deckos !== "undefined" && deckos) deckos.scraper.steamGridDbKey = steamGridApiKey } // DECKOS: one key for picker + scraper

function handleAccept() {
    if (keyboardOpen) return
    if (activeItemIndex === 0) showBootAnimation = !showBootAnimation
    else if (activeItemIndex === 1) openKeyboard()
    else if (activeItemIndex === 2) Qt.openUrlExternally("https://www.steamgriddb.com/profile/preferences/api")
}
function handleLeft() {}
function handleRight() {}
function handleCancel() {}

function getMetaDir(game) {
    // Пробуем получить директорию из пути файла
    if (game.files.count > 0) {
        var fp = game.files.get(0).path
        if (fp.indexOf("/") >= 0)
            return fp.substring(0, fp.lastIndexOf("/"))
    }
    // Если android:-схема — ищем директорию через соседние игры коллекции
    var coll = game.collections.get(0)
    if (coll) {
        for (var i = 0; i < coll.games.count; i++) {
            var g = coll.games.get(i)
            if (g && g.files.count > 0) {
                var fp2 = g.files.get(0).path
                if (fp2.indexOf("/") >= 0)
                    return fp2.substring(0, fp2.lastIndexOf("/"))
            }
        }
    }
    return ""
}

function getLaunchCmd(game) {
    if (game.files.count === 0) return ""

    var filePath = game.files.get(0).path
    var fileName = filePath.indexOf("/") >= 0
        ? filePath.substring(filePath.lastIndexOf("/") + 1)
        : filePath

    var dir = getMetaDir(game)
    if (dir === "") return ""

    var xhr = new XMLHttpRequest()
    xhr.open("GET", "file://" + dir + "/metadata.pegasus.txt", false)
    xhr.send()
    if (!xhr.responseText) return ""

    var raw = xhr.responseText.split("\n")

    // Склеиваем многострочные значения (строки с отступом — продолжение)
    var lines = []
    for (var i = 0; i < raw.length; i++) {
        var line = raw[i]
        if (line.length > 0 && (line[0] === " " || line[0] === "\t") && lines.length > 0)
            lines[lines.length - 1] += " " + line.trim()
        else
            lines.push(line.trim())
    }

    // Разбиваем на блоки по game:
    var blocks = []
    var cur = []
    for (var j = 0; j < lines.length; j++) {
        if (lines[j].startsWith("game:") && cur.length > 0) {
            blocks.push(cur)
            cur = []
        }
        cur.push(lines[j])
    }
    if (cur.length > 0) blocks.push(cur)

    // Дефолтный launch коллекции
    var collLaunch = ""
    for (var k = 0; k < blocks[0].length; k++) {
        if (blocks[0][k].startsWith("launch:")) {
            collLaunch = blocks[0][k].substring(7).trim()
            break
        }
    }

    // Нормализуем имя файла — убираем android: и ./
    var normName = fileName.replace(/^android:/, "").replace(/^\.\//, "")

    // Ищем нужный блок
    for (var m = 1; m < blocks.length; m++) {
        var block = blocks[m]
        var matched = false
        var blockLaunch = ""

        for (var n = 0; n < block.length; n++) {
            var bl = block[n]
            if (bl.startsWith("file:")) {
                var val = bl.substring(5).trim()
                    .replace(/^android:/, "")
                    .replace(/^\.\//, "")
                if (normName === val || filePath.endsWith(val))
                    matched = true
            }
            if (bl.startsWith("launch:"))
                blockLaunch = bl.substring(7).trim()
        }

        if (matched)
            return blockLaunch !== "" ? blockLaunch : collLaunch
    }

    return collLaunch
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

    Text {
        id: pageTitle
        text: "Shortcut"
        color: "white"
        font.pixelSize: 50 
        font.family: bold.name
        font.bold: true
        anchors.top: parent.top
        anchors.topMargin: 70
        anchors.left: parent.left
        anchors.leftMargin: 50
    }

    Column {
    anchors.top: pageTitle.bottom
    anchors.topMargin: 15
    width: parent.width
    spacing: 0

    // 1. Квадрат (20%) слева и Поле ввода (80%) справа
    Rectangle {
        width: parent.width
        height: 180
        color:  "transparent"

        Item {
            anchors.fill: parent
            anchors.leftMargin: 50
            anchors.rightMargin: 50

            // Квадрат (20%) - Фокус 1
            Rectangle {
    id: gameicon
    width: height 
    height: parent.height * 0.75
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    color: (activeZone === 1 && activeItemIndex === 1) ? "white" : "#31343B"
    Behavior on color { ColorAnimation { duration: 150 } }
                
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: theme.getAssetSource("icon", theme.currentGame)
        visible: source != ""
        cache: true
        z: 1
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (activeZone === 1 && activeItemIndex === 1) {
            } else {
                activeZone = 1
                activeItemIndex = 1
            }
        }
    }
}

            // Поле ввода (80%) - Фокус 2
            Rectangle {
                width: ((parent.width * 0.98)- gameicon.width)
                height: 75
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: (activeZone === 1 && activeItemIndex === 2) ? "white" : "#31343B"
                Behavior on color { ColorAnimation { duration: 150 } }
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: (activeZone === 1 && activeItemIndex === 2) ? "black" : "white"
                    font.pixelSize: 28
                    font.family: bold.name
                    text: theme.currentGame.title
                    opacity: 0.4
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (activeZone === 1 && activeItemIndex === 2) {
                            // Действие при клике
                        } else {
                            activeZone = 1
                            activeItemIndex = 2
                        }
                    }
                }
            }
        }

        Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
    }

    // 2. Текст "DIRECTORY" и Поле ввода на 100% длины
    Rectangle {
        width: parent.width
        height: 335
        color: "transparent"

        Column {
            anchors.fill: parent 
            anchors.topMargin: 20
            anchors.leftMargin: 50
            anchors.rightMargin: 50
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15

            Text { 
                text: "DIRECTORY"
                color: "white"
                font.pixelSize: 30
                font.family: bold.name 
            }

            // Ввод "DIRECTORY" - Фокус 3
            Rectangle {
                width: parent.width
                height: 75
                color: (activeZone === 1 && activeItemIndex === 3) ? "white" : "#31343B"
                Behavior on color { ColorAnimation { duration: 150 } }
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: (activeZone === 1 && activeItemIndex === 3) ? "black" : "white"
                    font.pixelSize: 28
                    font.family: bold.name
                    text: theme.currentGame && theme.currentGame.files.count > 0 
          ? theme.currentGame.files.get(0).path 
          : "Path not found"
          
                    opacity: 0.4
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (activeZone === 1 && activeItemIndex === 3) {
                            // Действие при клике
                        } else {
                            activeZone = 1
                            activeItemIndex = 3
                        }
                    }
                }
            }
        }
        
        Column {
            anchors.fill: parent 
            anchors.topMargin: 175
            anchors.leftMargin: 50
            anchors.rightMargin: 50
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15

            Text { 
                text: "LAUNCH COMMAND"
                color: "white"
                font.pixelSize: 30
                font.family: bold.name 
            }

            // Ввод "LAUNCH COMMAND" - Фокус 4
            Rectangle {
    width: parent.width
    height: Math.max(75, launchText.contentHeight + 30)
    color: (activeZone === 1 && activeItemIndex === 4) ? "white" : "#31343B"
    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        id: launchText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        color: (activeZone === 1 && activeItemIndex === 4) ? "black" : "white"
        font.pixelSize: 28
        font.family: bold.name
        text: getLaunchCmd(currentGame)
        opacity: 0.4
        wrapMode: Text.WrapAnywhere
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (activeZone === 1 && activeItemIndex === 4) {
            } else {
                activeZone = 1
                activeItemIndex = 4
            }
        }
    }
}
}

        Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
    }
}


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
