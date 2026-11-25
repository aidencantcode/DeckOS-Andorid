// DECKOS: generic Steam-style settings page for the pages DeckOS adds to StMini's Settings screen
// (Library, Profile, the rebuilt General/System pages). Looks and behaves like StMini's own pages:
// settings.qml drives it through activeItemIndex / maxItemIndex / sliderActive / handleAccept() /
// handleLeft() / handleRight() / handleCancel().
//
// rows: array of plain objects
//   { type: "section", label }                          - heading, skipped by navigation
//   { type: "toggle",  label, desc, value(), toggle() }  - on/off switch
//   { type: "choice",  label, desc, value(), next(), prev() }  - Left/Right (or A) cycles the value
//   { type: "button",  label, desc, value(), activate(), accent } - A runs it; value() = text on the right
//   { type: "info",    label, desc, value() }            - read-only text
// optional on every row: enabled() -> bool (greyed out and ignored when false)
// value()/enabled()/desc may read QML properties; the page updates when those change.
import QtQuick 2.15

Item {
    id: page
    anchors.fill: parent

    property string title: ""
    property var rows: []

    property int activeItemIndex: 0
    property int maxItemIndex: Math.max(0, rows.length - 1)
    readonly property var activeRow: (activeItemIndex >= 0 && activeItemIndex < rows.length) ? rows[activeItemIndex] : null
    // settings.qml hands Left/Right to the page only while this is true (otherwise they switch panes)
    readonly property bool sliderActive: activeZone === 1 && !!activeRow && activeRow.type === "choice"

    function rowEnabled(r) { return !r.enabled || r.enabled() }

    function playAccept() { try { sAccept.stop(); sAccept.play() } catch (e) {} }
    function playNav() { try { sNav.stop(); sNav.play() } catch (e) {} }

    function handleAccept() {
        var r = activeRow
        if (!r || !rowEnabled(r)) return
        if (r.type === "toggle") { r.toggle(); playAccept() }
        else if (r.type === "choice") { r.next(); playNav() }
        else if (r.type === "button") { playAccept(); r.activate() }
    }
    function handleLeft() {
        var r = activeRow
        if (r && r.type === "choice" && rowEnabled(r)) { r.prev(); playNav() }
    }
    function handleRight() {
        var r = activeRow
        if (r && r.type === "choice" && rowEnabled(r)) { r.next(); playNav() }
    }
    // sub-pages (e.g. one system on the Emulators page) set this: B returns true when it went back itself
    property var backHandler: null
    function handleBack() { return backHandler ? backHandler() === true : false }
    function handleCancel() {
        activeZone = 0 // back to the left menu, like StMini's pages
        try { sBack.stop(); sBack.play() } catch (e) {}
    }

    // headings are not selectable: keep moving in the direction of travel
    property int _lastIndex: 0
    // first selectable row from `from` in direction `dir`, else in the other direction; -1 if none
    function nearestSelectable(from, dir) {
        var i
        for (i = from; i >= 0 && i < rows.length; i += dir)
            if (rows[i] && rows[i].type !== "section") return i
        for (i = from; i >= 0 && i < rows.length; i -= dir)
            if (rows[i] && rows[i].type !== "section") return i
        return -1
    }
    // iterative (no re-entry): a recursive skip ping-ponged between two headings and overflowed the stack
    property bool _adjusting: false
    function fixIndex(dir) {
        if (_adjusting) return
        var n = nearestSelectable(Math.max(0, Math.min(rows.length - 1, activeItemIndex)), dir)
        if (n >= 0 && n !== activeItemIndex) {
            _adjusting = true
            activeItemIndex = n
            _adjusting = false
        }
    }
    onActiveItemIndexChanged: {
        if (_adjusting) return
        fixIndex(activeItemIndex >= _lastIndex ? 1 : -1)
        _lastIndex = activeItemIndex
        ensureVisible()
    }
    onRowsChanged: fixIndex(1)
    Component.onCompleted: fixIndex(1)

    function ensureVisible() {
        var item = repeater.itemAt(activeItemIndex)
        if (!item) return
        var top = item.y
        var bottom = item.y + item.height
        if (top < flick.contentY + 20) flick.contentY = Math.max(0, top - 20)
        else if (bottom > flick.contentY + flick.height - 20)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), bottom - flick.height + 20)
    }

    Text {
        id: pageTitle
        text: page.title
        color: "white"
        font.pixelSize: 50
        font.family: bold.name
        font.bold: true
        anchors.top: parent.top
        anchors.topMargin: 70
        anchors.left: parent.left
        anchors.leftMargin: 50
    }

    Flickable {
        id: flick
        anchors.top: pageTitle.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 90 // above the button-hint footer
        contentWidth: width
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentY { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        Column {
            id: column
            width: flick.width

            Repeater {
                id: repeater
                // an int model: handing the array itself to the Repeater would copy each row into a
                // QVariantMap and drop its functions (value/toggle/...)
                model: page.rows.length

                delegate: Rectangle {
                    id: rowItem
                    readonly property var row: page.rows[index] || ({})
                    readonly property bool isSection: row.type === "section"
                    readonly property bool active: activeZone === 1 && page.activeItemIndex === index && !isSection
                    readonly property bool on: row.enabled ? row.enabled() : true
                    readonly property string descText: typeof row.desc === "function" ? row.desc() : (row.desc || "")
                    readonly property var val: row.value ? row.value() : undefined

                    width: column.width
                    height: isSection ? 80 : (descText !== "" ? 130 : 90)
                    color: active ? "#30343A" : "transparent"
                    opacity: on ? 1.0 : 0.45

                    // heading
                    Text {
                        visible: rowItem.isSection
                        text: row.label
                        color: "#8b929a"
                        font.pixelSize: 24
                        font.family: bold.name
                        font.capitalization: Font.AllUppercase
                        anchors.left: parent.left
                        anchors.leftMargin: 50
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                    }

                    Column {
                        visible: !rowItem.isSection
                        anchors.left: parent.left
                        anchors.leftMargin: 50
                        anchors.right: rightSide.left
                        anchors.rightMargin: 30
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 22

                        Text {
                            width: parent.width
                            text: row.label
                            color: row.accent ? "#1a9fff" : "white"
                            font.pixelSize: 30
                            font.family: bold.name
                            elide: Text.ElideMiddle
                        }
                        Text {
                            visible: rowItem.descText !== ""
                            width: parent.width
                            text: rowItem.descText
                            color: "lightgray"
                            font.pixelSize: 24
                            font.family: bold.name
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        id: rightSide
                        visible: !rowItem.isSection
                        anchors.right: parent.right
                        anchors.rightMargin: 50
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: row.type === "toggle" ? 72
                             : row.type === "choice" ? 430
                             : valueText.text !== "" ? Math.min(valueText.implicitWidth + 50, rowItem.width * 0.45)
                             : 40

                        // toggle switch (same look as StMini's)
                        Rectangle {
                            visible: row.type === "toggle"
                            width: 72; height: 44; radius: 44
                            anchors.verticalCenter: parent.verticalCenter
                            color: rowItem.val === true ? "#00ACFF" : "#31343B"
                            border.color: rowItem.active ? "gray" : "transparent"
                            border.width: 6
                            Rectangle {
                                width: 44; height: 44; radius: 44
                                color: "white"
                                border.color: rowItem.active ? "gray" : "transparent"
                                border.width: 3
                                anchors.verticalCenter: parent.verticalCenter
                                x: rowItem.val === true ? parent.width - width : 0
                                Behavior on x { NumberAnimation { duration: 150 } }
                            }
                        }

                        // choice box with arrows
                        Rectangle {
                            visible: row.type === "choice"
                            anchors.fill: parent
                            anchors.topMargin: (parent.height - 80) / 2
                            anchors.bottomMargin: (parent.height - 80) / 2
                            radius: 5
                            color: rowItem.active ? "gray" : "#31343B"
                            Text {
                                text: "◀"
                                visible: rowItem.active
                                color: "white"; font.pixelSize: 20
                                anchors.left: parent.left; anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: row.type === "choice" && rowItem.val !== undefined ? String(rowItem.val) : ""
                                color: "white"
                                font.pixelSize: 28
                                font.family: bold.name
                                width: parent.width - 100
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                anchors.centerIn: parent
                            }
                            Text {
                                text: "▶"
                                visible: rowItem.active
                                color: "white"; font.pixelSize: 20
                                anchors.right: parent.right; anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // value text (button / info) and chevron
                        Text {
                            id: valueText
                            visible: row.type === "button" || row.type === "info"
                            text: (row.type === "button" || row.type === "info") && rowItem.val !== undefined && rowItem.val !== null ? String(rowItem.val) : ""
                            color: "lightgray"
                            font.pixelSize: 26
                            font.family: bold.name
                            elide: Text.ElideLeft
                            width: Math.min(implicitWidth, parent.width - (chevron.visible ? 40 : 0))
                            anchors.right: chevron.visible ? chevron.left : parent.right
                            anchors.rightMargin: chevron.visible ? 16 : 0
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: chevron
                            visible: row.type === "button"
                            text: "›"
                            color: rowItem.active ? "white" : "#8b929a"
                            font.pixelSize: 44
                            font.family: bold.name
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        visible: !rowItem.isSection
                        height: 1; width: parent.width - 100; color: "#333"
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !rowItem.isSection
                        onClicked: {
                            if (activeZone === 1 && page.activeItemIndex === index) {
                                page.handleAccept()
                            } else {
                                activeZone = 1
                                page.activeItemIndex = index
                            }
                        }
                    }
                }
            }
        }
    }
}
