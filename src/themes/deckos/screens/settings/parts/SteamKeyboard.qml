// DECKOS: the full-size Steam-style keyboard (StMini's Customization keyboard made reusable), used for
// every text field: names, descriptions, launch commands, API keys, RetroAchievements login.
// Controller: D-pad moves, A presses, X backspace, Y space, L1 caps, R1/Start/B done.
// The Paste key pastes the clipboard. Every key's action comes from the key itself, so touch and
// controller always do the same thing (StMini's own controller table was off by one on the last row).
import QtQuick 2.15

FocusScope {
    id: kb

    property string text: ""
    property int cursorPosition: 0
    property int maxLength: 64
    property bool multiline: false
    /// space left free under the keyboard (the page's button hints)
    property real bottomMargin: 0
    readonly property bool isOpen: opened

    signal edited()
    signal accepted()

    property bool opened: false
    property bool caps: false
    property bool shift: false
    property int r: 2
    property int c: 5

    function show(initial) {
        if (initial !== undefined) text = initial || ""
        cursorPosition = text.length
        r = 2; c = 5
        shift = false
        opened = true
        forceActiveFocus()
    }
    function hide() { opened = false }

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.bottomMargin: bottomMargin
    height: panel.height
    visible: opened || slide.running
    focus: opened

    readonly property var rows: [
        { w: 15, keys: [{l:"`",s:"~"},{l:"1",s:"!"},{l:"2",s:"@"},{l:"3",s:"#"},{l:"4",s:"$"},{l:"5",s:"%"},{l:"6",s:"^"},
                        {l:"7",s:"&"},{l:"8",s:"*"},{l:"9",s:"("},{l:"0",s:")"},{l:"-",s:"_"},{l:"=",s:"+"},
                        {l:"Backspace",short:"Del",a:"backspace",w:2,spec:true,glyph:"x"}] },
        { w: 15, keys: [{l:"Tab",a:"tab",w:1.5,spec:true},{l:"q"},{l:"w"},{l:"e"},{l:"r"},{l:"t"},{l:"y"},{l:"u"},{l:"i"},{l:"o"},{l:"p"},
                        {l:"[",s:"{"},{l:"]",s:"}"},{l:"\\",s:"|",w:1.5}] },
        { w: 15, keys: [{l:"Caps",a:"caps",w:1.8,spec:true},{l:"a"},{l:"s"},{l:"d"},{l:"f"},{l:"g"},{l:"h"},{l:"j"},{l:"k"},{l:"l"},
                        {l:";",s:":"},{l:"'",s:"\""},{l:"Enter",a:"enter",w:2.2,spec:true,glyph:">"}] },
        { w: 15, keys: [{l:"Shift",a:"shift",w:2.5,spec:true},{l:"z"},{l:"x"},{l:"c"},{l:"v"},{l:"b"},{l:"n"},{l:"m"},
                        {l:",",s:"<"},{l:".",s:">"},{l:"/",s:"?"},{l:"Shift",a:"shift",w:2.5,spec:true}] },
        { w: 13.1, keys: [{l:"Clear",a:"clear",w:1.2,spec:true},{l:"Space",a:"space",w:6.5,glyph:"y"},{l:"Paste",a:"paste",w:1.2,spec:true},
                          {l:"<",a:"left",w:1.2,spec:true},{l:">",a:"right",w:1.2,spec:true},{l:"Done",a:"done",w:1.8,spec:true,glyph:"b"}] }
    ]

    function upper() { return caps !== shift }
    function label(key) {
        if (key.a) return key.l
        if (upper()) return key.s ? key.s : key.l.toUpperCase()
        return key.l
    }
    // controller button glyphs of StMini's icon font (Xbox / Nintendo layouts, Latin / Cyrillic sets)
    function glyph(name) {
        var nin = theme && theme.nintendoLayout, uni = theme && theme.universalIcons
        if (name === "x") return nin ? (uni ? "У" : "Y") : (uni ? "Х" : "X")
        if (name === "y") return nin ? (uni ? "Х" : "X") : (uni ? "У" : "Y")
        if (name === "b") return nin ? (uni ? "А" : "A") : (uni ? "В" : "B")
        return name
    }

    function insert(s) {
        if (!s) return
        var room = Math.max(0, maxLength - text.length)
        s = s.substring(0, room)
        if (s === "") return
        text = text.substring(0, cursorPosition) + s + text.substring(cursorPosition)
        cursorPosition += s.length
        edited()
    }
    function press(key) {
        if (!key) return
        switch (key.a) {
        case "backspace":
            if (cursorPosition > 0) {
                text = text.substring(0, cursorPosition - 1) + text.substring(cursorPosition)
                cursorPosition--
                edited()
            }
            return
        case "tab": if (multiline) insert("    "); return
        case "caps": caps = !caps; return
        case "shift": shift = !shift; return
        case "enter": if (multiline) insert("\n"); else accepted(); return
        case "clear": text = ""; cursorPosition = 0; edited(); return
        case "space": insert(" "); return
        case "paste": {
            var clip = clipboard.read().replace(/\r/g, "")
            if (!multiline) clip = clip.replace(/[\n\t]+/g, " ").trim()
            insert(clip)
            return
        }
        case "left": if (cursorPosition > 0) cursorPosition--; return
        case "right": if (cursorPosition < text.length) cursorPosition++; return
        case "done": accepted(); return
        }
        insert(label(key))
        shift = false
    }
    function playNav() { if (typeof sNav !== "undefined") { sNav.stop(); sNav.play() } }
    function playType() { if (typeof sType !== "undefined") sType.play() }

    TextEdit {
        id: clipboard
        visible: false
        function read() { text = ""; paste(); return text }
    }

    Keys.onPressed: {
        if (event.isAutoRepeat && !(api.keys.isLeft(event) || api.keys.isRight(event) || api.keys.isUp(event)
                                    || api.keys.isDown(event) || api.keys.isDetails(event))) {
            event.accepted = true
            return
        }
        var count = rows[r].keys.length
        if (api.keys.isLeft(event)) { if (c > 0) { c--; playNav() } }
        else if (api.keys.isRight(event)) { if (c < count - 1) { c++; playNav() } }
        else if (api.keys.isUp(event)) { if (r > 0) { r--; c = Math.min(c, rows[r].keys.length - 1); playNav() } }
        else if (api.keys.isDown(event)) { if (r < rows.length - 1) { r++; c = Math.min(c, rows[r].keys.length - 1); playNav() } }
        else if (api.keys.isAccept(event)) { playType(); press(rows[r].keys[c]) }
        else if (api.keys.isDetails(event)) { playType(); press({ a: "backspace" }) }
        else if (api.keys.isFilters(event)) { playType(); press({ a: "space" }) }
        else if (api.keys.isPrevPage(event)) { caps = !caps }
        else if (api.keys.isNextPage(event) || api.keys.isMenu(event) || api.keys.isCancel(event)) { accepted() }
        else return
        event.accepted = true
    }

    Rectangle {
        id: panel
        width: kb.width
        height: Math.min(405, Math.max(300, (kb.parent ? kb.parent.height : 1080) * 0.42))
        color: "#22262F"
        y: kb.opened ? 0 : height + kb.bottomMargin
        Behavior on y { NumberAnimation { id: slide; duration: 200; easing.type: Easing.OutQuad } }

        MouseArea { anchors.fill: parent } // taps between keys don't reach the page below

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: 5
            spacing: 4

            Repeater {
                model: kb.rows.length
                delegate: Row {
                    id: keyRow
                    readonly property int rowIndex: index
                    readonly property var rowData: kb.rows[index]
                    width: column.width
                    height: (column.height - column.spacing * (kb.rows.length - 1)) / kb.rows.length
                    spacing: 4

                    Repeater {
                        model: keyRow.rowData.keys.length
                        delegate: Rectangle {
                            id: keyCap
                            readonly property var key: keyRow.rowData.keys[index]
                            readonly property bool current: kb.r === keyRow.rowIndex && kb.c === index
                            readonly property bool lit: (key.a === "caps" && kb.caps) || (key.a === "shift" && kb.shift)
                            width: (keyRow.width / keyRow.rowData.w) * (key.w || 1) - keyRow.spacing
                            height: keyRow.height
                            color: current ? "white" : (key.spec ? "black" : "#0F1318")
                            border.width: lit ? 2 : 0
                            border.color: "#1A9FFF"

                            // controller glyph (bottom left) + name (bottom right) on the action keys
                            Text {
                                id: glyphText
                                visible: !!key.glyph
                                text: kb.glyph(key.glyph || "")
                                font.family: icons.name
                                font.pixelSize: Math.min(40, keyCap.height * 0.55)
                                color: keyCap.current ? "black" : "white"
                                anchors.left: parent.left; anchors.leftMargin: 15
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                            }
                            Text {
                                visible: !!key.spec || key.a === "space"
                                text: key.a === "space" ? "" : (key.short && keyCap.width < 170 ? key.short : key.l)
                                font.family: bold.name
                                font.pixelSize: Math.min(key.a === "backspace" ? 22 : 26, keyCap.height * 0.35)
                                // narrow screens (Retroid Pocket Classic): shrink instead of cutting the name off
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 11
                                color: keyCap.lit && !keyCap.current ? "#1A9FFF" : (keyCap.current ? "black" : "white")
                                horizontalAlignment: key.glyph ? Text.AlignRight : Text.AlignHCenter
                                x: key.glyph ? glyphText.x + glyphText.width + 6 : 6
                                width: keyCap.width - x - (key.glyph ? 12 : 6)
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                            }
                            // letters and symbols
                            Text {
                                visible: !key.a
                                text: kb.label(key)
                                font.family: bold.name
                                font.pixelSize: Math.min(26, keyCap.height * 0.38)
                                color: keyCap.current ? "black" : "white"
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: {
                                    kb.r = keyRow.rowIndex
                                    kb.c = index
                                    kb.playType()
                                    var repeats = !keyCap.key.a || keyCap.key.a === "backspace" || keyCap.key.a === "space"
                                                  || keyCap.key.a === "left" || keyCap.key.a === "right"
                                    if (repeats) autoRepeat.start()
                                    else kb.press(keyCap.key)
                                }
                                onReleased: autoRepeat.stop()
                                onExited: autoRepeat.stop()
                                onCanceled: autoRepeat.stop()

                                SequentialAnimation {
                                    id: autoRepeat
                                    ScriptAction { script: kb.press(keyCap.key) }
                                    PauseAnimation { duration: 500 }
                                    SequentialAnimation {
                                        loops: Animation.Infinite
                                        ScriptAction { script: { kb.press(keyCap.key); kb.playType() } }
                                        PauseAnimation { duration: 60 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
