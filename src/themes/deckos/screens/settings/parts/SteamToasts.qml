// DECKOS: Steam-style notifications in the top-left corner, over every page: a dark card with an icon,
// a title, a line of text and an optional progress bar. theme.notify({ id, title, text, icon, progress,
// timeout }) adds one, or updates the one with the same id in place (scraping progress, scans, and later
// achievements or anything else). progress: 0..1 shows a bar, -1 none. timeout: ms, 0 = stays until
// updated or dismissed. At most three cards, newest on top.
import QtQuick 2.15

Item {
    id: toasts

    /// 1080p canvas unit: the cards keep their size on any screen
    readonly property real unit: height / 1080

    function notify(n) {
        var id = n.id ? String(n.id) : "n" + Date.now()
        var entry = {
            nid: id,
            title: n.title || "",
            text: n.text || "",
            icon: n.icon || "i",
            progress: (n.progress === undefined || n.progress === null) ? -1 : Number(n.progress),
            until: n.timeout === 0 ? 0 : Date.now() + (n.timeout || 4000)
        }
        for (var i = 0; i < items.count; i++) {
            if (items.get(i).nid === id) {
                items.set(i, entry)
                return id
            }
        }
        items.insert(0, entry)
        while (items.count > 3)
            items.remove(items.count - 1)
        return id
    }
    function dismiss(id) {
        for (var i = 0; i < items.count; i++) {
            if (items.get(i).nid === id) { items.remove(i); return }
        }
    }

    ListModel { id: items }

    Timer { // takes cards away once their time is up
        interval: 250
        repeat: true
        running: items.count > 0
        onTriggered: {
            var now = Date.now()
            for (var i = items.count - 1; i >= 0; i--) {
                var until = items.get(i).until
                if (until > 0 && now > until) items.remove(i)
            }
        }
    }

    ListView {
        id: list
        x: 24 * toasts.unit
        y: 24 * toasts.unit
        width: 500 * toasts.unit
        height: toasts.height
        interactive: false
        spacing: 12 * toasts.unit
        model: items

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; from: -list.width; to: 0; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "x"; to: -list.width * 0.4; duration: 220; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: 220 }
            }
        }
        displaced: Transition { NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic } }

        delegate: Rectangle {
            width: list.width
            height: 108 * toasts.unit
            radius: 4 * toasts.unit
            gradient: Gradient {
                GradientStop { position: 0; color: "#F22A303A" }
                GradientStop { position: 1; color: "#F21C2128" }
            }
            border.color: "#3D4450"
            border.width: Math.max(1, toasts.unit)
            clip: true

            Rectangle { // icon
                id: iconBox
                width: 72 * toasts.unit
                height: width
                radius: 4 * toasts.unit
                anchors.left: parent.left
                anchors.leftMargin: 16 * toasts.unit
                anchors.verticalCenter: parent.verticalCenter
                color: "#1A9FFF"
                Text {
                    anchors.centerIn: parent
                    text: model.icon
                    color: "white"
                    font.family: icons.name
                    font.pixelSize: 42 * toasts.unit
                }
            }
            Column {
                anchors.left: iconBox.right
                anchors.leftMargin: 16 * toasts.unit
                anchors.right: parent.right
                anchors.rightMargin: 16 * toasts.unit
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: model.progress >= 0 ? -5 * toasts.unit : 0
                spacing: 4 * toasts.unit
                Text {
                    width: parent.width
                    text: model.title
                    color: "white"
                    elide: Text.ElideRight
                    font.family: bold.name
                    font.pixelSize: 27 * toasts.unit
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: model.text
                    color: "#B8BCBF"
                    elide: Text.ElideRight
                    font.family: bold.name
                    font.pixelSize: 21 * toasts.unit
                }
            }
            Rectangle { // progress
                visible: model.progress >= 0
                anchors.left: iconBox.right
                anchors.leftMargin: 16 * toasts.unit
                anchors.right: parent.right
                anchors.rightMargin: 16 * toasts.unit
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12 * toasts.unit
                height: 6 * toasts.unit
                radius: height / 2
                color: "#3D4450"
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.max(0, Math.min(1, model.progress))
                    color: "#1A9FFF"
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }
        }
    }
}
