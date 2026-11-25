import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15
// QtMultimedia больше не требуется для gif

FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    // --- свойства ---
    property var theme
    property real topH: 95
    property real bottomH: topH
    property bool hasFocus: activeFocus
    property bool isReady: true
    property bool fromGameMenu: false

    Item {
        id: animatedContent
        anchors.fill: parent

        Rectangle {
            id: background
            anchors.fill: parent
            color: "#0F1318"
            z: 0
        }

        // ================= GIF ПОСЕРЕДИНЕ =================
        AnimatedImage {
            id: loadingGif
            source: "../assets/video/loading.webp" // Путь к вашему gif
            anchors.centerIn: parent
            width: parent.width * 0.3
            height: parent.height * 0.3
            fillMode: AnimatedImage.PreserveAspectFit
            playing: true // Включает анимацию
            z: 1000000000
        }
    }

    // Появление: страница идет «вперед» (из глубины на пользователя)
    SequentialAnimation {
        id: enterAnim
        running: true
        ScriptAction {
            script: {
                animatedContent.opacity = 0
                animatedContent.scale = 0.95 
            }
        }
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 1; duration: 225; easing.type: Easing.OutQuad }
            NumberAnimation { target: animatedContent; property: "scale"; to: 1.0; duration: 225; easing.type: Easing.OutQuad }
        }
    }
}
