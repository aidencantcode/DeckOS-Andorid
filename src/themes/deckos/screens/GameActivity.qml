// DECKOS: the game page's ACTIVITY tab - what happened in this game, newest first: achievements unlocked
// (RetroAchievements, from the ACHIEVEMENTS tab's data) and screenshots (the player's own from RetroArch or
// DeckOS, then scraped ones). Y switches the achievements between a list (rows like the in-game overlay)
// and a grid of badges; the choice is remembered.
import QtQuick 2.15

Item {
    id: activity

    property var game: null
    property var achievements: []   // RAGameInfoSection._achievements
    property bool raLoggedIn: false
    property bool raLoading: false
    property int numTotal: 0
    property int numEarned: 0

    property string viewMode: api.memory.has("activityView") ? api.memory.get("activityView") : "list"
    onViewModeChanged: api.memory.set("activityView", viewMode)
    function toggleView() { viewMode = viewMode === "list" ? "grid" : "list" }

    readonly property string fontBold: typeof bold !== "undefined" ? bold.name : ""
    readonly property string fontTitle: typeof extrabold !== "undefined" ? extrabold.name : ""

    // --- screenshots ---------------------------------------------------------------------------
    property var shots: []
    function reloadShots() {
        var list = []
        if (game && typeof deckos !== "undefined" && deckos)
            list = deckos.gameScreenshots(game, 8)
        var scraped = (game && game.assets && game.assets.screenshots) ? game.assets.screenshots : []
        for (var i = 0; i < scraped.length && list.length < 8; i++)
            list.push({ url: scraped[i], time: 0 })
        shots = list
    }
    onGameChanged: reloadShots()
    Component.onCompleted: reloadShots()

    // --- achievements, newest first --------------------------------------------------------------
    readonly property var recent: {
        var r = []
        for (var i = 0; i < achievements.length; i++)
            if (achievements[i].earned) r.push(achievements[i])
        r.sort(function (a, b) { return a.dateEarned < b.dateEarned ? 1 : (a.dateEarned > b.dateEarned ? -1 : 0) })
        return r.slice(0, viewMode === "grid" ? 14 : 6)
    }

    function earnedDate(str) {
        if (!str) return ""
        var d = new Date(String(str).replace(" ", "T"))
        if (isNaN(d.getTime())) return str
        var days = Math.floor((Date.now() - d.getTime()) / 86400000)
        if (days < 1) return "Today"
        if (days === 1) return "Yesterday"
        if (days < 7) return days + " days ago"
        return Qt.formatDate(d, d.getFullYear() === new Date().getFullYear() ? "MMM d" : "MMM d, yyyy")
    }

    function shotDate(ms) {
        if (!ms) return ""
        var d = new Date(ms)
        return Qt.formatDate(d, "MMM d, yyyy")
    }

    implicitHeight: column.height
    height: column.height

    Column {
        id: column
        width: parent.width
        spacing: 22

        // header: title + list/grid switch (Y)
        Item {
            width: parent.width
            height: 48

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "RECENT ACHIEVEMENTS"
                color: "white"
                opacity: 0.6
                font.pixelSize: 26
                font.family: activity.fontTitle
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle { // Y glyph
                    width: 40; height: 40; radius: 20
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Y"; color: "#0e141b"; font.pixelSize: 24; font.family: activity.fontBold }
                }
                Repeater {
                    model: [["list", "List"], ["grid", "Grid"]]
                    Rectangle {
                        width: label.implicitWidth + 36
                        height: 40
                        radius: 20
                        color: activity.viewMode === modelData[0] ? "#3d4450" : "transparent"
                        border.width: 1
                        border.color: "#3d4450"
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData[1]
                            color: activity.viewMode === modelData[0] ? "white" : "#8b929a"
                            font.pixelSize: 22
                            font.family: activity.fontBold
                        }
                        MouseArea { anchors.fill: parent; onClicked: activity.viewMode = modelData[0] }
                    }
                }
            }
        }

        // empty / status line
        Text {
            width: parent.width
            visible: text !== ""
            wrapMode: Text.WordWrap
            color: "#8b929a"
            font.pixelSize: 24
            font.family: activity.fontBold
            text: {
                if (!activity.raLoggedIn) return "Log in to RetroAchievements (ACHIEVEMENTS tab) to see your unlocks here."
                if (activity.raLoading) return "Loading…"
                if (activity.numTotal === 0) return "This game has no RetroAchievements set."
                if (activity.recent.length === 0) return "Nothing unlocked yet - " + activity.numTotal + " achievements to go."
                return ""
            }
        }

        // list view: rows like the in-game overlay's
        Column {
            width: parent.width
            spacing: 8
            visible: activity.viewMode === "list" && activity.recent.length > 0

            Repeater {
                model: activity.viewMode === "list" ? activity.recent : []
                Rectangle {
                    width: parent.width
                    height: 96
                    radius: 4
                    color: "#23262e"

                    Image {
                        id: badge
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72; height: 72
                        source: modelData.badgeUrl || ""
                        sourceSize.width: 128
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }
                    Column {
                        anchors.left: badge.right
                        anchors.leftMargin: 18
                        anchors.right: dateCol.left
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            width: parent.width
                            text: modelData.title
                            color: "white"
                            font.pixelSize: 26
                            font.family: activity.fontBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: modelData.description
                            color: "#8b929a"
                            font.pixelSize: 21
                            elide: Text.ElideRight
                        }
                    }
                    Column {
                        id: dateCol
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            anchors.right: parent.right
                            text: "Unlocked " + activity.earnedDate(modelData.dateEarned)
                            color: "#c7d0d9"
                            font.pixelSize: 20
                        }
                        Text {
                            anchors.right: parent.right
                            text: modelData.points + " pts"
                            color: "#e8b84a"
                            font.pixelSize: 20
                            font.family: activity.fontBold
                        }
                    }
                }
            }
        }

        // grid view: badges with names
        Flow {
            width: parent.width
            spacing: 18
            visible: activity.viewMode === "grid" && activity.recent.length > 0

            Repeater {
                model: activity.viewMode === "grid" ? activity.recent : []
                Column {
                    width: 150
                    spacing: 6
                    Rectangle {
                        width: 150; height: 150
                        radius: 4
                        color: "#23262e"
                        Image {
                            anchors.fill: parent
                            anchors.margins: 10
                            source: modelData.badgeUrl || ""
                            sourceSize.width: 160
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                    Text {
                        width: parent.width
                        text: modelData.title
                        color: "white"
                        font.pixelSize: 19
                        font.family: activity.fontBold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: activity.earnedDate(modelData.dateEarned)
                        color: "#8b929a"
                        font.pixelSize: 17
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        Item { width: 1; height: 10 }

        Text {
            text: "SCREENSHOTS"
            color: "white"
            opacity: 0.6
            font.pixelSize: 26
            font.family: activity.fontTitle
        }

        Text {
            width: parent.width
            visible: activity.shots.length === 0
            wrapMode: Text.WordWrap
            color: "#8b929a"
            font.pixelSize: 24
            font.family: activity.fontBold
            text: "No screenshots yet. Screenshots you take of this game in RetroArch show up here."
        }

        Flow {
            id: shotFlow
            width: parent.width
            spacing: 18
            visible: activity.shots.length > 0
            readonly property int perRow: activity.viewMode === "grid" ? 4 : 3
            readonly property real cellW: (width - spacing * (perRow - 1)) / perRow

            Repeater {
                model: activity.shots
                Column {
                    spacing: 6
                    Rectangle {
                        width: shotFlow.cellW
                        height: shotFlow.cellW * 9 / 16
                        radius: 4
                        color: "#23262e"
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.url
                            sourceSize.width: 480
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    Text {
                        visible: modelData.time > 0
                        text: activity.shotDate(modelData.time)
                        color: "#8b929a"
                        font.pixelSize: 18
                    }
                }
            }
        }
    }
}
