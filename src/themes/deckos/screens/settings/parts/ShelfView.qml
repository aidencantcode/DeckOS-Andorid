// DECKOS: Home's What's New / Friends / Recommended tabs as Steam-style shelves: a title over a row of
// cards (ShelfCard.qml), one row under another. UP / DOWN go between shelves (UP from the first leaves:
// exitTop), LEFT / RIGHT along a shelf, A opens the card (activated), X its second action (secondary:
// "Open in YouTube"...). Each shelf remembers its position by id, also when the content is refreshed.
//
// shelves: [ { id, title, subtitle, kind, items: [...] } ] - `kind` is the cards' look (ShelfCard.qml).
import QtQuick 2.15

FocusScope {
    id: view
    property var shelves: []
    property int currentShelf: 0
    property var positions: ({})       // shelf id -> card index
    property string emptyText: "Nothing here yet"
    // for Home's older code, which treated each tab as one list
    property alias currentIndex: view.currentShelf
    readonly property int count: shelves.length

    signal activated(var shelf, var item, int index)
    signal secondary(var shelf, var item, int index)
    signal exitTop()

    readonly property var currentShelfData: shelves.length > 0 ? shelves[Math.min(currentShelf, shelves.length - 1)] : null
    readonly property int currentCard: currentShelfData ? Math.min(positions[currentShelfData.id] || 0, currentShelfData.items.length - 1) : 0

    function cardHeight(kind) {
        if (kind === "game") return 300
        if (kind === "news") return 330
        if (kind === "raweekly") return 230
        if (kind === "raset" || kind === "raaward" || kind === "friend" || kind === "discord" || kind === "action" || kind === "update") return 170
        return 250 // wide, video, system
    }

    function setPosition(id, i) {
        var p = positions
        p[id] = i
        positions = p
    }

    function sound() { try { sNav.stop(); sNav.play() } catch (e) {} }

    onShelvesChanged: {
        if (currentShelf >= shelves.length) currentShelf = Math.max(0, shelves.length - 1)
        rows.currentIndex = currentShelf
        Qt.callLater(scrollToShelf)
    }
    onCurrentShelfChanged: scrollToShelf()

    // the selected shelf glides to the top (the last ones as far as they go); ListView's own highlight
    // range does nothing without a highlight item
    function scrollToShelf() {
        if (shelves.length === 0 || rows.height <= 0) return
        var it = rows.itemAtIndex(currentShelf)
        if (!it) { rows.positionViewAtIndex(currentShelf, ListView.Beginning); return }
        var top = rows.originY - rows.topMargin
        var bottom = rows.originY + rows.contentHeight + rows.bottomMargin - rows.height
        rowsScroll.to = Math.max(top, Math.min(Math.max(top, bottom), it.y - rows.topMargin))
        rowsScroll.restart()
    }
    NumberAnimation { id: rowsScroll; target: rows; property: "contentY"; duration: 240; easing.type: Easing.OutCubic }

    Keys.onPressed: {
        if (shelves.length === 0) {
            if (event.key === Qt.Key_Up) { exitTop(); event.accepted = true }
            return
        }
        var s = currentShelfData
        var idx = currentCard
        if (event.key === Qt.Key_Up) {
            if (currentShelf > 0) { currentShelf--; sound() } else exitTop()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            if (currentShelf < shelves.length - 1) { currentShelf++; sound() }
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            if (idx > 0) { setPosition(s.id, idx - 1); sound() }
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            if (idx < s.items.length - 1) { setPosition(s.id, idx + 1); sound() }
            event.accepted = true
        } else if (api.keys.isAccept(event) && !event.isAutoRepeat) {
            if (s.items[idx]) activated(s, s.items[idx], idx)
            event.accepted = true
        } else if (api.keys.isDetails(event) && !event.isAutoRepeat) {
            if (s.items[idx]) secondary(s, s.items[idx], idx)
            event.accepted = true
        }
    }

    Text {
        visible: view.shelves.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.25
        width: parent.width * 0.7
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: view.emptyText
        color: "#8F98A3"
        font.family: bold.name
        font.pixelSize: 26
    }

    ListView {
        id: rows
        anchors.fill: parent
        model: view.shelves
        currentIndex: view.currentShelf
        spacing: 26
        clip: true
        interactive: false
        topMargin: 22   // room for a selected card's glow and scale at the top
        bottomMargin: 60
        highlightFollowsCurrentItem: false
        cacheBuffer: 900

        delegate: Item {
            id: shelf
            readonly property var shelfData: modelData
            readonly property bool isCurrent: index === view.currentShelf
            readonly property real cardH: view.cardHeight(modelData.kind)
            width: rows.width
            height: header.height + 14 + cardH + 24

            Text {
                id: header
                x: 6
                text: modelData.title || ""
                color: shelf.isCurrent && view.activeFocus ? "white" : "#B8C0C9"
                font.family: bold.name
                font.pixelSize: 28
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Text {
                anchors { left: header.right; leftMargin: 18; baseline: header.baseline }
                text: modelData.subtitle || ""
                color: "#7C8692"
                font.pixelSize: 19
            }

            ListView {
                id: row
                y: header.height + 14
                x: 6
                width: parent.width - 6
                height: shelf.cardH
                orientation: ListView.Horizontal
                spacing: 24
                clip: false
                interactive: false
                model: modelData.items
                currentIndex: Math.min(view.positions[modelData.id] || 0, count - 1)
                highlightFollowsCurrentItem: false
                cacheBuffer: 1400
                // the selected card stays in view: the row glides only when it would leave the left
                // edge or the right 25 %
                onCurrentIndexChanged: glide()
                // laid out before its size was known (a page building its shelves at once): back in range
                onWidthChanged: contentX = Math.max(originX, Math.min(contentX, originX + contentWidth - width))
                function glide() {
                    if (currentIndex < 0 || count === 0 || width <= 0) return
                    var it = itemAtIndex(currentIndex)
                    if (!it) { positionViewAtIndex(currentIndex, ListView.Contain); return }
                    var maxX = Math.max(originX, originX + contentWidth - width)
                    var to = contentX
                    if (it.x < contentX) to = it.x
                    else if (it.x + it.width > contentX + width * 0.75) to = it.x + it.width - width * 0.75
                    to = Math.max(originX, Math.min(maxX, to))
                    if (to !== contentX) { rowScroll.to = to; rowScroll.restart() }
                }
                NumberAnimation { id: rowScroll; target: row; property: "contentX"; duration: 200; easing.type: Easing.OutCubic }

                delegate: ShelfCard {
                    kind: shelf.shelfData.kind
                    item: modelData
                    height: shelf.cardH
                    focused: shelf.isCurrent && view.activeFocus && index === row.currentIndex
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var si = shelfIndex()
                            var wasHere = view.activeFocus && view.currentShelf === si && row.currentIndex === index
                            view.currentShelf = si
                            view.setPosition(shelf.shelfData.id, index)
                            view.forceActiveFocus()
                            if (wasHere) view.activated(shelf.shelfData, modelData, index)
                        }
                        function shelfIndex() {
                            for (var i = 0; i < view.shelves.length; i++) if (view.shelves[i].id === shelf.shelfData.id) return i
                            return 0
                        }
                    }
                }
            }
        }
    }
}
