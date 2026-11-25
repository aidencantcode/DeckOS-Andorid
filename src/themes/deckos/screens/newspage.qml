import QtQuick 2.15
import QtGraphicalEffects 1.15
import "../javascript/news.js" as NewsJS

FocusScope {
    id: rootNews

    anchors.fill: parent
    focus: visible
    clip: true

    property var newsItem: null
    property var articleBlocks: []

    property var newsData: []
    property int currentNewsIndex: 0
    property real panelSlideX: 0
    property bool isAnimating: false
    property int pendingDirection: 0

    onNewsItemChanged: {
        articleBlocks = [];
        if (!newsItem) return;

        articleBlocks = NewsJS.parseArticleContent(newsItem.fullContent);

        var targetLink = newsItem.link;
        NewsJS.fetchFullArticle(targetLink, function(articleHtml) {
            if (!articleHtml) return;
            if (!rootNews.newsItem || rootNews.newsItem.link !== targetLink) return;

            rootNews.articleBlocks = NewsJS.parseArticleContent(articleHtml);
        });

        newsFlick.contentY = 0;
    }

    function switchNews(direction) {
        if (isAnimating) return;
        var nextIndex = currentNewsIndex + direction;
        if (nextIndex < 0 || nextIndex >= newsData.length) return;

        isAnimating = true;
        pendingDirection = direction;
        slideOutPhase.to = direction > 0 ? -rootNews.width * 0.6 : rootNews.width * 0.6;
        switchAnim.restart();
    }

    SequentialAnimation {
        id: switchAnim

        NumberAnimation {
            id: slideOutPhase
            target: rootNews
            property: "panelSlideX"
            duration: 120
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: {
                rootNews.currentNewsIndex += rootNews.pendingDirection;
                rootNews.newsItem = rootNews.newsData[rootNews.currentNewsIndex];
                rootNews.panelSlideX = rootNews.pendingDirection > 0
                    ? rootNews.width * 0.6
                    : -rootNews.width * 0.6;
            }
        }

        NumberAnimation {
            target: rootNews
            property: "panelSlideX"
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: {
                rootNews.isAnimating = false;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#090B10"
        opacity: 0.95
    }

    FastBlur {
        anchors.fill: parent
        source: globalBlurSource
        radius: 64
    }

    // Закрытие по тапу на фон + свайп влево/вправо для переключения новостей
    MouseArea {
        anchors.fill: parent
        property real pressX: 0
        property bool wasSwiped: false

        onPressed: {
            pressX = mouse.x;
            wasSwiped = false;
        }
        onPositionChanged: {
            if (Math.abs(mouse.x - pressX) > 30) {
                wasSwiped = true;
            }
        }
        onReleased: {
            if (wasSwiped) {
                var diff = mouse.x - pressX;
                if (Math.abs(diff) > 50) {
                    rootNews.switchNews(diff > 0 ? -1 : 1);
                }
            }
        }
        onClicked: {
            if (!wasSwiped) {
                root.closeNewsDetail();
            }
        }
    }

    Flickable {
        id: newsFlick

        anchors.fill: parent
        clip: true

        contentWidth: width
        contentHeight: panel.y + panel.height + 133

        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: true

        Behavior on contentY {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: panel

            width: parent.width * 0.465
            height: contentColumn.implicitHeight + 56
            
            anchors.horizontalCenter: parent.horizontalCenter
            y: 125

            radius: 2
            color: "#32353C"

            transform: Translate { x: rootNews.panelSlideX }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: contentColumn.y + title.y + title.height + 15
                color: "white"
                opacity: 0.1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                radius: 2        
                color: "transparent"
                border.color: "grey"
                border.width: 3
            }

            Column {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 34
                spacing: 24
                
                Row {
                    width: parent.width
                    spacing: 6
                    
                    Text {
                        id: pubLabel
                        text: "PUBLISHED"
                        color: "lightgrey"
                        font.pixelSize: 23
                    }
                    
                    Text {
                        text: rootNews.newsItem ? (rootNews.newsItem.pubDate || "") : ""
                        color: "grey"
                        font.pixelSize: 23
                        elide: Text.ElideRight
                        width: parent.width - pubLabel.width - parent.spacing
                    }
                }
                
                Text {
                    id: title
                    width: parent.width
                    text: rootNews.newsItem ? rootNews.newsItem.title : ""
                    color: "white"
                    font.pixelSize: 42
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: rootNews.articleBlocks

                    delegate: Item {
                        id: blockItem
                        width: contentColumn.width
                        height: modelData.type === "text" 
                                ? blockText.implicitHeight 
                                : (modelData.type === "image" ? blockImg.height : blockVideo.height)

                        Text {
                            id: blockText
                            visible: modelData.type === "text"
                            width: parent.width
                            text: modelData.type === "text" ? modelData.content : ""
                            color: "#D8DEE9"
                            font.pixelSize: 28
                            wrapMode: Text.WordWrap
                            lineHeight: 1.4
                        }

                        Image {
                            id: blockImg
                            visible: modelData.type === "image"
                            width: parent.width
                            height: modelData.type === "image" ? width * 0.56 : 0
                            source: modelData.type === "image" ? modelData.content : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        Item {
                            id: blockVideo
                            visible: modelData.type === "video"
                            width: parent.width
                            height: modelData.type === "video" ? width * 0.56 : 0

                            Image {
                                anchors.fill: parent
                                source: modelData.type === "video" ? modelData.thumbnail : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: "black"
                                    opacity: 0.25
                                }
                            }

                            Rectangle {
                                width: 100
                                height: 70
                                radius: 14
                                color: "#E62117"
                                anchors.centerIn: parent

                                Text {
                                    text: "▶"
                                    color: "white"
                                    font.pixelSize: 34
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 2
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (modelData.type === "video") {
                                        Qt.openUrlExternally(modelData.content)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onPressed: {
        var step = 120

        if (event.key === Qt.Key_Down) {
            newsFlick.contentY = Math.min(
                newsFlick.contentHeight - newsFlick.height,
                newsFlick.contentY + step
            )
            event.accepted = true
        }
        else if (event.key === Qt.Key_Up) {
            newsFlick.contentY = Math.max(0, newsFlick.contentY - step)
            event.accepted = true
        }
        else if (event.key === Qt.Key_Left) {
            rootNews.switchNews(-1)
            event.accepted = true
        }
        else if (event.key === Qt.Key_Right) {
            rootNews.switchNews(1)
            event.accepted = true
        }
        else if (event.key === Qt.Key_Escape || 
                 event.key === Qt.Key_Back || 
                 api.keys.isCancel(event) || 
                 api.keys.isBack(event)) {
            root.closeNewsDetail()
            event.accepted = true
        }
    }
}
