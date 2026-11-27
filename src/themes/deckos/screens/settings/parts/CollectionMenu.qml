// DECKOS: X on a collection in the Library's Collections tab. Scrape or re-scrape its games, rename it,
// its properties (the icon: dynamic collage or a picture of your own) and hide it. Same look as the
// games' options menu. A picks, B closes. Backed by deckos.scraper (Scraper.h) and deckos.collections
// (UserCollections.h); renaming uses the Steam keyboard (TextEntry).
import QtQuick 2.15
import QtGraphicalEffects 1.15

FocusScope {
    id: menu
    anchors.fill: parent
    visible: false

    property var collection: null
    property string name: ""
    property int current: 0
    property string message: ""
    /// the blurred picture behind the menu (the Library's globalBlurSource), optional
    property var blurSource: null

    signal closed()
    signal propertiesRequested(var collection)

    readonly property var store: (typeof deckos !== "undefined" && deckos) ? deckos.collections : null
    readonly property var scraper: (typeof deckos !== "undefined" && deckos) ? deckos.scraper : null
    readonly property bool skipWithMedia: api.memory.has("rescrapeSkipWithMedia") ? api.memory.get("rescrapeSkipWithMedia") : true
    readonly property bool scraping: !!scraper && scraper.running

    readonly property var rows: [
        { label: "Scrape missing artwork", icon: "♠︎",
          desc: "Artwork and info for its games that have none yet" },
        { label: "Re-scrape this collection", icon: "♠︎",
          desc: skipWithMedia ? "Fills in the games without artwork (Settings > Scraping can replace everything)"
                              : "Replaces the scraped artwork and info of all its games" },
        { label: "Rename…", icon: "✎", desc: "" },
        { label: "Properties…", icon: "⚙︎", desc: "Its icon: the dynamic one or a picture of your own" },
        { label: "Hide from Library", icon: "✕", desc: "Show it again in Settings > Collections" },
        { label: "Cancel", icon: "", desc: "" }
    ]

    function open(coll) {
        collection = coll
        name = coll && coll.name ? coll.name : ""
        current = 0
        message = ""
        visible = true
        forceActiveFocus()
    }
    function close() {
        if (!visible) return
        visible = false
        closed()
    }
    function notify(title, text) {
        if (typeof theme !== "undefined" && theme && typeof theme.notify === "function")
            theme.notify({ id: "collectionmenu", icon: "L", title: title, text: text, timeout: 3500 })
    }

    function activate(i) {
        if (i === 0 || i === 1) {
            if (!scraper) return
            var n = i === 0 ? scraper.scrapeAll(true, [name], false) : scraper.scrapeAll(false, [name], skipWithMedia)
            if (n === 0) {
                message = (scraper.steamGridDbKey === "" && scraper.theGamesDbKey === "" && !scraper.useLibretroThumbnails)
                          ? "Add an API key in Settings > Scraping first" : "Nothing to scrape in " + name
                return
            }
            close() // the progress shows in the top-left corner
        } else if (i === 2) {
            renameEntry.open(name)
        } else if (i === 3) {
            var c = collection
            close()
            propertiesRequested(c)
        } else if (i === 4) {
            if (store && store.setHidden(name, true)) {
                notify("Collection hidden", name + " - show it again in Settings > Collections")
                close()
            } else {
                message = "Couldn't hide " + name
            }
        } else {
            close()
        }
    }

    Keys.onPressed: {
        event.accepted = true
        if (event.isAutoRepeat && !(event.key === Qt.Key_Up || event.key === Qt.Key_Down)) return
        if (event.key === Qt.Key_Up) {
            if (current > 0) { current--; sNav.stop(); sNav.play() }
        } else if (event.key === Qt.Key_Down) {
            if (current < rows.length - 1) { current++; sNav.stop(); sNav.play() }
        } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
            sAccept.stop(); sAccept.play()
            activate(current)
        } else if (api.keys.isCancel(event) || api.keys.isDetails(event) || event.key === Qt.Key_Escape) {
            sBack.stop(); sBack.play()
            close()
        }
    }

    Item { // backdrop
        anchors.fill: parent
        MouseArea { anchors.fill: parent; onClicked: menu.close() }
        FastBlur {
            anchors.fill: parent
            source: menu.blurSource
            visible: !!menu.blurSource
            radius: 50
            transparentBorder: false
        }
        Rectangle { anchors.fill: parent; color: "black"; opacity: 0.7 }
    }

    Rectangle {
        id: panel
        width: 620
        height: rowHeight * menu.rows.length
        readonly property real rowHeight: 100
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 20
        color: "#181B20"

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 22 }
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: menu.name
            color: "white"
            font.pixelSize: 38
            font.family: bold.name
            elide: Text.ElideRight
        }

        Column {
            anchors.fill: parent
            Repeater {
                model: menu.rows
                delegate: Rectangle {
                    readonly property bool selected: menu.current === index
                    width: panel.width
                    height: panel.rowHeight
                    color: selected ? "white" : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.right: parent.right
                        anchors.rightMargin: 30
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 28
                        Text {
                            width: 50
                            text: modelData.icon
                            color: selected ? "black" : "white"
                            font.pixelSize: 44
                            font.family: icons.name
                            horizontalAlignment: Text.AlignHCenter
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                            spacing: 2
                            Text {
                                width: parent.width
                                text: modelData.label
                                color: selected ? "black" : "white"
                                font.pixelSize: 32
                                font.family: bold.name
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                visible: selected && modelData.desc !== ""
                                text: modelData.desc
                                color: "#5c636c"
                                font.pixelSize: 19
                                font.family: bold.name
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (menu.current !== index) { menu.current = index; sNav.stop(); sNav.play() }
                            else menu.activate(index)
                        }
                    }
                }
            }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 18 }
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: menu.message !== "" || menu.scraping
            text: menu.message !== "" ? menu.message : "Scraping is running - new games join the queue"
            color: menu.message !== "" ? "#ff8080" : "#8b929a"
            font.pixelSize: 22
            font.family: bold.name
            wrapMode: Text.WordWrap
        }
    }

    TextEntry {
        id: renameEntry
        title: "Rename " + menu.name
        hint: "Done, B or Start saves. Kept across library scans; a system's games still use its emulator."
        maxLength: 60
        onAccepted: {
            var clean = text.trim()
            if (clean === "" || clean === menu.name || !menu.store) { menu.forceActiveFocus(); return }
            var err = menu.store.rename(menu.name, clean)
            if (err !== "") { menu.message = err; menu.forceActiveFocus(); return }
            menu.notify("Collection renamed", menu.name + " is now " + clean)
            menu.close()
        }
    }
}
