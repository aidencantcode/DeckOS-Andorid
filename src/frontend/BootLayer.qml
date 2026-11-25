// DeckOS boot screen: replaces Pegasus's logo + progress bar splash (SplashLayer.qml).
//
// First start: plays the Steam Deck boot animation over black while the library loads, then fades into
// the interface. If loading takes longer than the video, the last frame (the logo) stays up with a thin
// progress line under it. Any button skips the rest of the video. Later reloads (e.g. after changing
// game folders) show only the black screen with the progress line - the video plays once per start.
import QtQuick 2.8
import QtMultimedia 5.9


Rectangle {
    id: root
    color: "#000"
    anchors.fill: parent

    property real progress: 0
    property bool showDataProgressText: true
    property string stage: ""

    // true once the video has finished (or was skipped, failed or is not wanted)
    property bool videoDone: !playVideo
    property bool playVideo: true
    property bool loading: true

    function skip() {
        if (videoDone) return;
        video.pause();
        videoDone = true;
    }

    Keys.onPressed: { skip(); event.accepted = true; }

    Video {
        id: video
        anchors.fill: parent
        source: root.playVideo ? "qrc:/frontend/assets/boot.mp4" : ""
        fillMode: VideoOutput.PreserveAspectCrop
        autoPlay: root.playVideo
        visible: root.playVideo
        onStatusChanged: {
            if (status === MediaPlayer.EndOfMedia || status === MediaPlayer.InvalidMedia)
                root.videoDone = true;
        }
        onErrorChanged: {
            if (error !== MediaPlayer.NoError) {
                console.warn("DeckOS boot video:", errorString);
                root.videoDone = true;
            }
        }
    }

    // the video never reports its end on some backends; never wait longer than this
    Timer {
        interval: 8000
        running: root.playVideo && !root.videoDone
        onTriggered: root.videoDone = true
    }

    // thin Deck-style progress line, only while still loading after the video
    Rectangle {
        id: track
        visible: root.loading && root.videoDone
        width: Math.min(parent.width, parent.height) * 0.3
        height: Math.max(2, parent.height * 0.004)
        radius: height / 2
        color: "#2a2f37"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: parent.height * 0.17

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.max(0.03, Math.min(1, root.progress))
            color: "#1a9fff"
            Behavior on width { NumberAnimation { duration: 200 } }
        }
    }

    Text {
        visible: track.visible && root.showDataProgressText && root.stage !== ""
        text: root.stage
        color: "#8b929a"
        font.pixelSize: Math.max(12, parent.height * 0.018)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: track.bottom
        anchors.topMargin: parent.height * 0.015
    }
}
