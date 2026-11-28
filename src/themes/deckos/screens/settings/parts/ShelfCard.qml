// DECKOS: one card on a Home shelf (ShelfView.qml). `kind` picks the look:
//   game      a cover (2:3) with a line under it (played when, hours)
//   wide      a game's 16:9 picture with its cover as a small icon in the corner, title and system
//   news      a picture over the headline, source and date
//   video     a 16:9 thumbnail with a play mark, channel and title
//   raset     a RetroAchievements game icon: "New set", title, console, when
//   raaward   a RetroAchievements member's picture: mastered / beat, game, console, when
//   raweekly  the Achievement of the Week: title screen, achievement, description, points
//   friend    a RetroAchievements friend: picture, online dot, rich presence, game icon
//   discord   a Discord friend (Lanyard): avatar, status dot, activity
//   system    a system or collection: a game's picture, name, game count
//   update    an emulator update: icon, name, installed -> new version
//   action    an icon and a line of text that does something (sign in, add a friend, ...)
import QtQuick 2.15
import QtGraphicalEffects 1.15

Item {
    id: card
    property string kind: "game"
    property var item: ({})
    property bool focused: false

    // the game whose artwork shows (a system card names one in `art` without opening it)
    readonly property var game: item && item.game ? item.game : (item && item.art ? item.art : null)
    readonly property real baseWidth: kind === "game" ? height * 2 / 3
                                    : kind === "news" ? height * 1.18
                                    : kind === "action" ? height * 3.0
                                    : kind === "raset" || kind === "raaward" || kind === "friend" || kind === "discord" || kind === "update" ? height * 2.5
                                    : kind === "raweekly" ? height * 3.2
                                    : height * 16 / 9
    width: baseWidth

    function ago(ms) {
        if (!ms) return ""
        var s = Math.max(0, (Date.now() - ms) / 1000)
        if (s < 90) return "just now"
        if (s < 3600) return Math.round(s / 60) + " min ago"
        if (s < 86400) return Math.round(s / 3600) + " h ago"
        if (s < 86400 * 14) return Math.round(s / 86400) + (Math.round(s / 86400) === 1 ? " day ago" : " days ago")
        return new Date(ms).toLocaleDateString(Qt.locale(), "d MMM yyyy")
    }
    function art(type) { return card.game ? theme.getAssetSource(type, card.game) : "" }
    function wideArt() {
        if (!card.game) return ""
        var a = card.game.assets
        return art("background") || art("steam") || (a ? (a.screenshot || a.titlescreen || "") : "")
    }

    scale: focused ? 1.045 : 1.0
    z: focused ? 2 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

    // the blurred glow behind the selected card (Steam's)
    Rectangle {
        anchors.fill: frame
        anchors.margins: -14
        radius: 10
        color: "#2A86C7FF"
        opacity: card.focused ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 4
        color: "#23262E"
        clip: true

        Loader {
            anchors.fill: parent
            sourceComponent: card.kind === "game" ? gameCard
                           : card.kind === "wide" ? wideCard
                           : card.kind === "news" ? newsCard
                           : card.kind === "video" ? videoCard
                           : card.kind === "raset" ? raSetCard
                           : card.kind === "raaward" ? raAwardCard
                           : card.kind === "raweekly" ? raWeeklyCard
                           : card.kind === "friend" || card.kind === "discord" ? friendCard
                           : card.kind === "system" ? systemCard
                           : card.kind === "update" ? updateCard
                           : actionCard
        }
    }

    // the white edge of the selected card, breathing like Steam's
    Rectangle {
        anchors.fill: frame
        anchors.margins: -5
        radius: 7
        color: "transparent"
        border.width: 4
        border.color: "white"
        opacity: 0
        visible: card.focused
        SequentialAnimation on opacity {
            running: card.focused
            loops: Animation.Infinite
            NumberAnimation { from: 0.35; to: 0.85; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.85; to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
        }
    }

    // ---- kinds ------------------------------------------------------------------------------------

    Component {
        id: gameCard
        Item {
            Image {
                id: cover
                anchors.fill: parent
                source: theme.thumb(card.art("poster"))
                sourceSize: Qt.size(Math.round(width), Math.round(height))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
            Text {
                visible: cover.status !== Image.Ready
                anchors.centerIn: parent
                width: parent.width * 0.85
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: card.game ? card.game.title : ""
                color: "white"
                font.family: bold.name
                font.pixelSize: 22
            }
            Rectangle { // the line under the cover: played when, hours
                visible: !!card.item.badge
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 40
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "#E0000000" }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: card.item.badge || ""
                    elide: Text.ElideRight
                    color: "#DDE3EA"
                    font.family: bold.name
                    font.pixelSize: 17
                }
            }
        }
    }

    Component {
        id: wideCard
        Item {
            Image {
                id: pic
                anchors.fill: parent
                source: theme.thumb(card.wideArt())
                sourceSize: Qt.size(Math.round(width), Math.round(height))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.35; color: "#00000000" }
                    GradientStop { position: 1.0; color: "#E6000000" }
                }
            }
            // the game's cover as its icon, a few pixels in from the corner
            Rectangle {
                id: icon
                anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                width: height * 2 / 3
                height: parent.height * 0.42
                radius: 3
                color: "#30343C"
                clip: true
                Image {
                    anchors.fill: parent
                    source: theme.thumb(card.art("poster"))
                    sourceSize: Qt.size(96, 144)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                layer.enabled: true
                layer.effect: DropShadow { radius: 8; samples: 17; color: "#A0000000"; verticalOffset: 2 }
            }
            Column {
                anchors { left: icon.right; leftMargin: 12; right: parent.right; rightMargin: 12; bottom: icon.bottom }
                spacing: 2
                Text {
                    width: parent.width
                    text: card.game ? card.game.title : ""
                    elide: Text.ElideRight
                    color: "white"
                    font.family: bold.name
                    font.pixelSize: 23
                }
                Text {
                    width: parent.width
                    text: card.item.badge || (card.game && card.game.collections && card.game.collections.count > 0
                                                ? card.game.collections.get(0).name : "")
                    elide: Text.ElideRight
                    color: "#AEB6C0"
                    font.pixelSize: 17
                }
            }
        }
    }

    Component {
        id: newsCard
        Item {
            Rectangle {
                id: imgBox
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: width * 9 / 16
                color: "#1A1E25"
                clip: true
                // no picture in the feed (RetroAchievements' news): the source's name on its colours
                Rectangle {
                    anchors.fill: parent
                    visible: !card.item.image
                    gradient: Gradient {
                        GradientStop { position: 0; color: card.item.source === "RetroAchievements" ? "#3B2A10" : "#1E3550" }
                        GradientStop { position: 1; color: "#14171C" }
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width * 0.85
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: card.item.source || ""
                        color: card.item.source === "RetroAchievements" ? "#E5B143" : "#8FB8DD"
                        font.family: bold.name
                        font.pixelSize: 30
                        opacity: 0.85
                    }
                }
                Image {
                    anchors.fill: parent
                    source: card.item.image || ""
                    sourceSize.width: Math.round(width)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
            }
            Column {
                anchors { left: parent.left; right: parent.right; top: imgBox.bottom; margins: 12; topMargin: 8 }
                spacing: 3
                Text {
                    width: parent.width
                    text: (card.item.source || "").toUpperCase() + (card.item.date ? "  ·  " + card.ago(card.item.date) : "")
                    elide: Text.ElideRight
                    color: "#8FB8DD"
                    font.family: bold.name
                    font.pixelSize: 15
                }
                Text {
                    width: parent.width
                    text: card.item.title || ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: "white"
                    font.pixelSize: 20
                    lineHeight: 1.05
                }
            }
        }
    }

    Component {
        id: videoCard
        Item {
            Image {
                anchors.fill: parent
                source: card.item.image || ""
                sourceSize.width: Math.round(width)
                fillMode: Image.PreserveAspectCrop // YouTube's 4:3 frame: the black bars are cut off
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.4; color: "#00000000" }
                    GradientStop { position: 1.0; color: "#F0000000" }
                }
            }
            Rectangle { // play mark
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.08
                width: 74; height: 52; radius: 14
                color: card.focused ? "#E62117" : "#C0000000"
                Behavior on color { ColorAnimation { duration: 150 } }
                Canvas {
                    anchors.centerIn: parent
                    width: 24; height: 26
                    onPaint: {
                        var c = getContext("2d")
                        c.reset()
                        c.fillStyle = "white"
                        c.beginPath(); c.moveTo(2, 0); c.lineTo(24, 13); c.lineTo(2, 26); c.closePath(); c.fill()
                    }
                }
            }
            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                spacing: 2
                Text {
                    width: parent.width
                    text: (card.item.source || "") + (card.item.date ? "  ·  " + card.ago(card.item.date) : "")
                    elide: Text.ElideRight
                    color: "#C9D2DC"
                    font.family: bold.name
                    font.pixelSize: 15
                }
                Text {
                    width: parent.width
                    text: card.item.title || ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: "white"
                    font.pixelSize: 20
                }
            }
        }
    }

    // icon + lines: the RetroAchievements, friend, update and action cards share it
    Component {
        id: raSetCard
        IconCard {
            iconSource: card.item.icon || ""
            chip: "NEW SET"
            chipColor: "#E5B143"
            line1: card.item.title || ""
            line2: card.item.console || ""
            line3: (card.item.author ? "by " + card.item.author + "  ·  " : "") + card.ago(card.item.date)
        }
    }
    Component {
        id: raAwardCard
        IconCard {
            iconSource: card.item.userPic || ""
            round: true
            chip: card.item.award === "mastered" ? "MASTERED" : card.item.award === "completed" ? "COMPLETED"
                : (card.item.award || "").indexOf("beaten") === 0 ? "BEATEN" : (card.item.award || "").toUpperCase()
            chipColor: card.item.award === "mastered" || card.item.award === "completed" ? "#E5B143" : "#6CB2EB"
            line1: card.item.title || ""
            line2: (card.item.user || "") + "  ·  " + (card.item.console || "")
            line3: card.ago(card.item.date)
        }
    }
    Component {
        id: raWeeklyCard
        Item {
            Rectangle {
                id: shot
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: height * 4 / 3
                color: "#111"
                Image {
                    anchors.fill: parent
                    source: card.item.image || card.item.icon || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: false // pixel art stays sharp
                }
            }
            Column {
                anchors { left: shot.right; leftMargin: 20; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 6
                Text {
                    text: "ACHIEVEMENT OF THE WEEK"
                    color: "#E5B143"
                    font.family: bold.name
                    font.pixelSize: 16
                }
                Text {
                    width: parent.width
                    text: card.item.title || ""
                    elide: Text.ElideRight
                    color: "white"
                    font.family: bold.name
                    font.pixelSize: 26
                }
                Text {
                    width: parent.width
                    text: card.item.description || ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: "#C9D2DC"
                    font.pixelSize: 19
                }
                Text {
                    width: parent.width
                    text: (card.item.game || "") + "  ·  " + (card.item.console || "")
                    elide: Text.ElideRight
                    color: "#8F98A3"
                    font.pixelSize: 17
                }
                Text {
                    text: (card.item.points || 0) + " points" + (card.item.players ? "  ·  " + card.item.unlocks + " of " + card.item.players + " players have it" : "")
                    color: "#8F98A3"
                    font.pixelSize: 17
                }
            }
        }
    }
    Component {
        id: friendCard
        IconCard {
            readonly property bool discord: card.kind === "discord"
            readonly property string status: discord ? (card.item.status || "offline") : (card.item.online ? "online" : "offline")
            iconSource: discord ? (card.item.avatar || "") : (card.item.userPic || "")
            round: true
            showDot: true
            dotColor: status === "online" ? "#57CB4D" : status === "idle" ? "#F0B232" : status === "dnd" ? "#F23F43" : status === "unknown" ? "#F0B232" : "#5D6670"
            line1: discord ? (card.item.name || "") : (card.item.user || "")
            line1Color: status === "offline" ? "#AEB6C0" : "#8BD86F"
            line2: discord ? (card.item.activity || (status === "offline" ? "Offline" : "Online"))
                           : (card.item.online ? (card.item.presence || ("Playing " + (card.item.game || ""))) : "Last played " + (card.item.game || "") )
            line3: discord ? (card.item.details || card.item.spotify || "")
                           : (card.item.online ? (card.item.game || "") + (card.item.console ? "  ·  " + card.item.console : "") : card.ago(card.item.seen))
            sideIcon: discord ? (card.item.image || "") : (card.item.gameIcon || "")
        }
    }
    Component {
        id: systemCard
        Item {
            Image {
                anchors.fill: parent
                source: theme.thumb(card.wideArt() || card.art("poster"))
                sourceSize: Qt.size(Math.round(width), Math.round(height))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.2; color: "#30000000" }
                    GradientStop { position: 1.0; color: "#F0000000" }
                }
            }
            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                Text {
                    width: parent.width
                    text: card.item.name || ""
                    elide: Text.ElideRight
                    color: "white"
                    font.family: bold.name
                    font.pixelSize: 28
                }
                Text {
                    text: (card.item.count || 0) + (card.item.count === 1 ? " game" : " games")
                    color: "#AEB6C0"
                    font.pixelSize: 18
                }
            }
        }
    }
    Component {
        id: updateCard
        IconCard {
            iconSource: card.item.package ? "image://androidicons/" + card.item.package : ""
            chip: card.item.state === "downloading" ? "DOWNLOADING" : card.item.state === "ready" ? "READY TO INSTALL" : "UPDATE"
            chipColor: "#57CB4D"
            line1: card.item.name || ""
            line2: (card.item.installed ? card.item.installed + "  →  " : "") + (card.item.latest || "")
            line3: card.item.state === "downloading" ? Math.round((card.item.progress || 0) * 100) + " %" : card.ago(card.item.date)
            progress: card.item.state === "downloading" ? (card.item.progress || 0) : -1
        }
    }
    Component {
        id: actionCard
        IconCard {
            glyph: card.item.glyph || "+"
            line1: card.item.title || ""
            line2: card.item.text || ""
            line3: ""
            wrapLine2: true
        }
    }
}
