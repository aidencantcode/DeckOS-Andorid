// DECKOS: Friends and Chat - Home's Friends shelves on a page of their own: RetroAchievements users you
// follow (online, what they're playing), Discord friends through Lanyard, adding one. Kept fresh every
// 2 minutes while shown (deckos.feeds.watchFriends). Chat itself isn't possible: neither RetroAchievements
// nor Discord lets other apps send messages for you.
import QtQuick 2.15
import "../settings/parts"
import "../../javascript/shelves.js" as Shelves

FocusScope {
    id: page
    focus: true
    property var theme

    readonly property var feeds: (typeof deckos !== "undefined" && deckos) ? deckos.feeds : null
    property var shelves: []

    function build() { shelves = Shelves.friends(feeds) }
    Component.onCompleted: { build(); if (feeds) feeds.watchFriends(true) }
    Component.onDestruction: if (feeds) feeds.watchFriends(false)
    Connections {
        target: page.feeds
        function onFriendsChanged() { page.build() }
        function onSourcesChanged() { page.build() }
    }

    Text {
        id: title
        anchors { left: parent.left; leftMargin: 70; top: parent.top; topMargin: 125 }
        text: "Friends"
        color: "white"
        font.family: bold.name
        font.pixelSize: 46
    }
    Text {
        anchors { left: title.right; leftMargin: 24; baseline: title.baseline }
        text: page.feeds && page.feeds.loading ? "Updating…" : "A opens  ·  X removes a Discord friend"
        color: "#8F98A3"
        font.pixelSize: 20
    }

    ShelfView {
        id: view
        focus: true
        anchors { left: parent.left; right: parent.right; top: title.bottom; bottom: parent.bottom
                  leftMargin: 64; rightMargin: 40; topMargin: 20; bottomMargin: 100 }
        shelves: page.shelves
        onActivated: if (page.theme) page.theme.openShelfItem(shelf, item, index, null)
        onSecondary: if (page.theme) page.theme.shelfSecondary(shelf, item, index)
    }
}
