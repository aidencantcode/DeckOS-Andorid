import QtQuick 2.15
import QtMultimedia 5.9
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15

FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    ShaderEffectSource {
        id: globalBlurSource
        // DECKOS: only ever seen blurred (the top and bottom bars): a third of the resolution looks the same
        // and costs a ninth of the work - it was the whole page drawn a second time, every frame
        textureSize: Qt.size(Math.max(1, Math.ceil(width / 3)), Math.max(1, Math.ceil(height / 3)))
        anchors.fill: parent
        sourceItem: animatedContent
        live: true
        visible: false
        wrapMode: ShaderEffectSource.ClampToEdge
    }

    // ======== PROPERTIES ========
    property real topH: 85

    property real bannerH: parent.width * (40/160)

    property real popularCardW: root.width * 0.3
    property real popularImgH: popularCardW * 9 / 16
    property real popularTextH: popularImgH 
    property real popularCardH: popularImgH + popularTextH

    property real salesCardH: root.height * 0.575
    property real salesCardW: salesCardH * 16 / 22

    property int focusZone: 0
    property int storeNavIndex: 0
    property int salesSubIndex: 0
    property int similarGridIndex: 0
    property int similarCellIndex: 0

    property bool closeMenuVisible: false
    property var theme
    property int nextPageIndex: 0

    // ======== SOUND EFFECTS ========
    SoundEffect { id: sNav;       source: "../assets/audio/nav.wav";                       volume: 1.0 }
    SoundEffect { id: sAccept;    source: "../assets/audio/accept.wav";                    volume: 1.0 }
    SoundEffect { id: sBack;      source: "../assets/audio/back.wav";                      volume: 1.0 }
    SoundEffect { id: sLeftOpen;  source: "../assets/audio/deck_ui_side_menu_fly_in.wav";  volume: 1.0 }
    SoundEffect { id: sLeftClose; source: "../assets/audio/deck_ui_side_menu_fly_out.wav"; volume: 1.0 }
    SoundEffect { id: sShowui;    source: "../assets/audio/deck_ui_show_ui.wav";           volume: 1.0 }

    // ======== NAVIGATION ========
    function goToZone(zoneIndex) {
        if (zoneIndex < 0) zoneIndex = 0
        if (zoneIndex > 6) zoneIndex = 6

        topButtonsRow.focus     = false
        storeNavRow.focus       = false
        bannerCatcher.focus     = false
        popularList.focus       = false
        salesList.focus         = false
        similarCatcher.focus    = false
        wideBannerCatcher.focus = false

        focusZone = zoneIndex

        if (zoneIndex === 0) {
            flick.contentY = 0
            topButtonsRow.forceActiveFocus()
        } else if (zoneIndex === 1) {
            flick.contentY = 0
            storeNavRow.forceActiveFocus()
        } else if (zoneIndex === 2) {
            flick.contentY = 0
            bannerCatcher.forceActiveFocus()
        } else if (zoneIndex === 3) {
            flick.contentY = root.topH + root.bannerH
            popularList.forceActiveFocus()
            if (popularList.count > 0) popularList.currentIndex = 0
        } else if (zoneIndex === 4) {
            flick.contentY = root.topH + root.bannerH + popularSection.height - 50
            salesList.forceActiveFocus()
            if (salesList.count > 0) salesList.currentIndex = 0
            root.salesSubIndex = 0
        } else if (zoneIndex === 5) {
            flick.contentY = root.topH + root.bannerH + popularSection.height + salesSection.height - 50
            similarCatcher.forceActiveFocus()
            root.similarGridIndex = 0
            root.similarCellIndex = 0
        } else if (zoneIndex === 6) {
            flick.contentY = root.topH + root.bannerH + popularSection.height + salesSection.height + similarSection.height - 50
            wideBannerCatcher.forceActiveFocus()
        }
    }


    function startExitAnimation(index) {
        nextPageIndex = index
        exitAnim.start()
    }

    // ======== ANIMATED CONTENT ========
    Item {
        id: animatedContent
        anchors.fill: parent
        anchors.topMargin: topH
        anchors.bottomMargin: topH
        
        Rectangle {
            anchors.fill: parent
            color: "#111"
        }
    
        // ======== FLICKABLE ========
        Flickable {
            id: flick
            anchors.fill: parent 
            contentWidth: parent.width
            contentHeight: content.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: true
            clip: true

            Behavior on contentY {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            

            Column {
                id: content
                width: flick.width
                spacing: 0
                
                // ======== ZONE 1: STORE NAV BAR ========
                Rectangle {
                    id: storeNavBar
                    width: parent.width
                    height: root.topH
                    color: "#1A1D23"
                    z: 10000

                    Row {
                        id: storeNavRow
                        anchors {
                            left: parent.left
                            leftMargin: 30
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 35

                        readonly property var navLabels: ["Featured", "New Releases", "Top Sellers", "Specials", "Browse"]

                        Repeater {
                            model: 5
                            delegate: Rectangle {
                                width: navBtnText.implicitWidth + 50
                                height: root.topH * 0.68
                                color: (root.focusZone === 1 && root.storeNavIndex === index) ? "white" : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                Row {
                                    spacing: 15
                                    anchors.centerIn: parent                              
                                Text {
                                    id: navBtnText
                                    text: storeNavRow.navLabels[index]
                                    font.pixelSize: 26
                                    font.family: bold.name
                                    color: (root.focusZone === 1 && root.storeNavIndex === index) ? "black" : "white"
                                }
                                Text {
                                    text: "⬇️"
                                    font.pixelSize: 26
                                    font.family: icons.name
                                    color: (root.focusZone === 1 && root.storeNavIndex === index) ? "black" : "white"
                                }
                                }
                                
                                Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        color: "transparent"
                                        border.width: (root.focusZone === 1 && root.storeNavIndex === index) ? 4 : 0
                                        border.color: "white"
                                        visible: root.focusZone === 1 && root.storeNavIndex === index
                                        z: 20
                                        Behavior on border.width { NumberAnimation { duration: 150 } }
                                    }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.focusZone = 1
                                        root.storeNavIndex = index
                                        storeNavRow.forceActiveFocus()
                                        sNav.stop(); sNav.play()
                                    }
                                }
                            }
                        }

                        Keys.onPressed: {
                            if (event.key === Qt.Key_Left) {
                                if (root.storeNavIndex > 0) {
                                    root.storeNavIndex--
                                    sNav.stop(); sNav.play()
                                    event.accepted = true
                                }
                            } else if (event.key === Qt.Key_Right) {
                                if (root.storeNavIndex < 5) {
                                    root.storeNavIndex++
                                    sNav.stop(); sNav.play()
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: searchBtn
                        width: searchTextmini.implicitWidth + 50
                        height: root.topH * 0.68
                        anchors {
                            right: parent.right
                            rightMargin: 30
                            verticalCenter: parent.verticalCenter
                        }
                        color: (root.focusZone === 1 && root.storeNavIndex === 5) ? "white" : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        
                        Row {
                        spacing: 10
                        anchors.centerIn: parent
                                                Text {
                            text: "¿"
    font.pixelSize: 26
    font.family: icons.name
                            color: (root.focusZone === 1 && root.storeNavIndex === 5) ? "black" : "white"
                        }
                        Text {
                            id: searchTextmini
                            text: "Search"
                            font.pixelSize: 26
                            font.family: bold.name
                            color: (root.focusZone === 1 && root.storeNavIndex === 5) ? "black" : "white"
                        }
                        }
                        
                        Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        color: "transparent"
                                        border.width: (root.focusZone === 1 && root.storeNavIndex === 5) ? 4 : 0
                                        border.color: "white"
                                        visible: root.focusZone === 1 && root.storeNavIndex === 5
                                        z: 20
                                        Behavior on border.width { NumberAnimation { duration: 150 } }
                                    }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.focusZone = 1
                                root.storeNavIndex = 5
                                storeNavRow.forceActiveFocus()
                                sNav.stop(); sNav.play()
                            }
                        }
                    }
                }


                // ======== ZONE 2: BANNER ========
                Item {
                    id: bannerZone
                    width: parent.width
                    height: root.bannerH

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 24
                        color: "#2A2E35"

                        Rectangle {
                            id: bannerBorder
                            anchors.fill: parent
                            anchors.margins: -4
                            color: "transparent"
                            border.width: root.focusZone === 2 ? 4 : 0
                            border.color: "white"
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.focusZone !== 2) {
                                    root.goToZone(2)
                                    sNav.stop(); sNav.play()
                                }
                            }
                        }
                    }

                    FocusScope {
                        id: bannerCatcher
                        anchors.fill: parent
                    }
                }

                // ======== ZONE 3: POPULAR & RECOMMENDED ========
                Item {
                    id: popularSection
                    width: parent.width
                    height: 40 + popularColumn.height + 40

                    Column {
                        id: popularColumn
                        anchors {
                            top: parent.top
                            topMargin: 40
                            left: parent.left
                            leftMargin: 60
                            right: parent.right
                            rightMargin: 40
                        }
                        spacing: 50

                        Text {
                            text: "Popular & Recommended"
                            color: "white"
                            font.pixelSize: 36
                            font.family: bold.name
                            anchors.left: parent.left 
                            anchors.leftMargin: -20
                        }

                        ListView {
                            id: popularList
                            width: parent.width
                            height: root.popularCardH
                            orientation: ListView.Horizontal
                            spacing: 30
                            clip: false
                            model: 12
                            interactive: true

                            highlightMoveDuration: 120
                            highlightRangeMode: ListView.ApplyRange
                            preferredHighlightBegin: width * 0.1
                            preferredHighlightEnd: width * 0.75

                            NumberAnimation {
                                id: popularScrollAnim
                                target: popularList
                                property: "contentX"
                                duration: 300
                                easing.type: Easing.OutCubic
                            }

                            function animateToIndex(idx) {
                                if (idx < 0 || idx >= count) return
                                var itemW = root.popularCardW + spacing
                                var maxX = Math.max(0, count * itemW - width)
                                var targetX = idx * itemW - width * 0.1
                                if (targetX < 0) targetX = 0
                                if (targetX > maxX) targetX = maxX
                                popularScrollAnim.stop()
                                popularScrollAnim.to = targetX
                                popularScrollAnim.start()
                            }

                            onCurrentIndexChanged: animateToIndex(currentIndex)

                            Keys.onPressed: {
                                if (event.key === Qt.Key_Left) {
                                    if (currentIndex > 0) {
                                        currentIndex--
                                        sNav.stop(); sNav.play()
                                        event.accepted = true
                                    }
                                } else if (event.key === Qt.Key_Right) {
                                    if (currentIndex < count - 1) {
                                        currentIndex++
                                        sNav.stop(); sNav.play()
                                        event.accepted = true
                                    }
                                }
                            }

                            delegate: Item {
                                id: popularDelegate
                                width: root.popularCardW
                                height: root.popularCardH

                                property bool isFocused: popularList.currentIndex === index
                                                      && root.focusZone === 3
                                                      && popularList.focus
                                                      
                                                      

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#1E2128"

                                    scale: popularDelegate.isFocused ? 1.03 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150 } }

                                    Rectangle {
                                        id: popImgArea
                                        anchors {
                                            top: parent.top
                                            left: parent.left
                                            right: parent.right
                                        }
                                        height: root.popularImgH
                                        color: "#2A2E35"
                                    }
                                    
                                    
                                   Row {
                                            anchors {
                                            bottom: parent.bottom
                                            right: parent.right
                                            margins: 20
                                        }
                                           
                                            Rectangle {
                                            id: popDiscTextBg
                                                width: popDiscText.implicitWidth + 28
                                                height: 50
                                                color: "#54B63D"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    id: popDiscText
                                                    anchors.centerIn: parent
                                                    text: "-60%"
                                                    color: "white"
                                                    font.pixelSize: 26
                                                }
                                            }
                                            
Rectangle {
                                                width: popDiscText.implicitWidth + 170
                                                height: popDiscTextBg.height
                                                color: "black"
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Row {
                                                anchors.fill: parent 
                                                anchors.leftMargin: 10
                                                spacing: 10
                                                
                                                Text {
                                                text: "$19.99"
                                                color: "gray"
                                                font.pixelSize: 20
                                                anchors.verticalCenter: parent.verticalCenter 
                                            }
                                                
                                            Text {
                                                text: "$9.99 USD"
                                                color: "white"
                                                font.pixelSize: 26
                                                anchors.verticalCenter: parent.verticalCenter 
                                            }
                                            }
                                            }
                                        } 
                                    

                                    Column {
                                        anchors {
                                            top: popImgArea.bottom
                                            left: parent.left
                                            right: parent.right
                                            bottom: parent.bottom
                                            margins: 30
                                            topMargin: 30
                                        }
                                        spacing: 8

                                        Text {
                                            width: parent.width
                                            text: "Game " + (index + 1)
                                            color: "white"
                                            font.pixelSize: 36
                                            font.family: bold.name
                                            elide: Text.ElideRight
                                        }
                                        
                                        Row {
                                        spacing: 130
                                        Text {
                                            text: "Very Positive"
                                            color: "#66C0F4"
                                            font.pixelSize: 26
                                            font.family: bold.name
                                            }
                                            Text {
                                            text: "(Reviews: 10,000)"
                                            color: "white"
                                            font.pixelSize: 26
                                            font.family: bold.name
                                            }
                                        }                                      
                                    }
                                                                       
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        color: "transparent"
                                        border.width: popularDelegate.isFocused ? 4 : 0
                                        border.color: "white"
                                        visible: popularDelegate.isFocused
                                        z: 26
                                        Behavior on border.width { NumberAnimation { duration: 150 } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (root.focusZone !== 3 || !popularList.activeFocus) {
                                            root.goToZone(3)
                                            popularList.currentIndex = index
                                            popularList.forceActiveFocus()
                                            sNav.stop(); sNav.play()
                                        } else if (popularList.currentIndex !== index) {
                                            popularList.currentIndex = index
                                            sNav.stop(); sNav.play()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ======== ZONE 4: SALES & EVENTS ========
                Item {
                    id: salesSection
                    width: parent.width
                    height: 40 + salesColumn.height + root.topH

                    Column {
                        id: salesColumn
                        anchors {
                            top: parent.top
                            topMargin: 40
                            left: parent.left
                            leftMargin: 80
                            right: parent.right
                            rightMargin: 40
                        }
                        spacing: 50

                        Text {
                            text: "Sales & Events"
                            color: "white"
                            font.pixelSize: 36
                            font.family: bold.name
                            anchors.left: parent.left 
                            anchors.leftMargin: -40
                        }

                        ListView {
                            id: salesList
                            width: parent.width
                            height: root.salesCardH
                            orientation: ListView.Horizontal
                            spacing: 30
                            clip: false
                            model: 12
                            interactive: true
                            displayMarginBeginning: 80
    displayMarginEnd: 40
                            

                            highlightMoveDuration: 120
                            highlightRangeMode: ListView.ApplyRange
                            preferredHighlightBegin: width * 0.1
                            preferredHighlightEnd: width * 0.75
                            
                            NumberAnimation {
                                id: salesScrollAnim
                                target: salesList
                                property: "contentX"
                                duration: 300
                                easing.type: Easing.OutCubic
                            }

                            function animateToIndex(idx) {
                                if (idx < 0 || idx >= count) return
                                var itemW = root.salesCardW + spacing
                                var maxX = Math.max(0, count * itemW - width)
                                var targetX = idx * itemW - width * 0.1
                                if (targetX < 0) targetX = 0
                                if (targetX > maxX) targetX = maxX
                                salesScrollAnim.stop()
                                salesScrollAnim.to = targetX
                                salesScrollAnim.start()
                            }

                            onCurrentIndexChanged: {
                                root.salesSubIndex = 0
                                animateToIndex(currentIndex)
                            }

                            Keys.onPressed: {
                                if (event.key === Qt.Key_Left) {
                                    if (currentIndex > 0) {
                                        currentIndex--
                                        root.salesSubIndex = 0
                                        sNav.stop(); sNav.play()
                                        event.accepted = true
                                    }
                                } else if (event.key === Qt.Key_Right) {
                                    if (currentIndex < count - 1) {
                                        currentIndex++
                                        root.salesSubIndex = 0
                                        sNav.stop(); sNav.play()
                                        event.accepted = true
                                    }
                                } else if (event.key === Qt.Key_Down) {
                                    if ((salesList.currentIndex % 3 === 2) && root.salesSubIndex === 0) {
                                        root.salesSubIndex = 1
                                        sNav.stop(); sNav.play()
                                        event.accepted = true
                                    }
                                } else if (event.key === Qt.Key_Up) {
                                    if ((salesList.currentIndex % 3 === 2) && root.salesSubIndex === 1) {
                                        root.salesSubIndex = 0
                                        sNav.stop(); sNav.play()
                                        event.accepted = true
                                    }
                                }
                            }

                            delegate: Item {
                                id: salesDelegate
                                width: root.salesCardW
                                height: root.salesCardH

                                property bool isDouble: (index % 3 === 2)
                                property bool isCurrent: salesList.currentIndex === index
                                                      && root.focusZone === 4
                                                      && salesList.focus

                                // ---- SINGLE TALL CARD ----
                                Rectangle {
                                    id: singleCard
                                    anchors.fill: parent
                                    color: "transparent"
                                    visible: !salesDelegate.isDouble

                                    property bool isFocused: salesDelegate.isCurrent && !salesDelegate.isDouble

                                    scale: isFocused ? 1.02 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150 } }

                                    Rectangle {
                                        id: singleImgArea
                                        anchors {
                                            top: parent.top
                                            left: parent.left
                                            right: parent.right
                                        }
                                        height: parent.height - singlePriceArea.height
                                        color: "#2A2E35"
                                    }

                                    Rectangle {
                                        id: singlePriceArea
                                        anchors {
                                            bottom: parent.bottom
                                            left: parent.left
                                            right: parent.right
                                        }
                                        height: 60
                                        color: "transparent"

                                        Row {
                                            anchors {
                                                        right: parent.right                                                       
                                                        verticalCenter: parent.verticalCenter
                                                    }

                                            Rectangle {
                                                width: singleDiscText.implicitWidth + 14
                                                height: 60
                                                color: "#54B63D"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    id: singleDiscText
                                                    anchors.centerIn: parent
                                                    text: "-60%"
                                                    color: "white"
                                                    font.pixelSize: 26
                                                }
                                            }


                                     Rectangle {
                                                width: singleDiscText.implicitWidth + 170
                                                height: 60
                                                color: "black"
                                                                    
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Row{
                                                anchors.fill: parent 
                                                anchors.leftMargin: 10
                                                spacing: 10
                                                
                                                Text {
                                                text: "$19.99"
                                                color: "gray"
                                                font.pixelSize: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                                
                                            Text {
                                                text: "$9.99 USD"
                                                color: "white"
                                                font.pixelSize: 26
                                                anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        color: "transparent"
                                        border.width: singleCard.isFocused ? 4 : 0
                                        border.color: "white"
                                        visible: singleCard.isFocused
                                        z: 20
                                        Behavior on border.width { NumberAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (root.focusZone !== 4 || !salesList.activeFocus) {
                                                root.goToZone(4)
                                                salesList.currentIndex = index
                                                salesList.forceActiveFocus()
                                                root.salesSubIndex = 0
                                                sNav.stop(); sNav.play()
                                            } else if (salesList.currentIndex !== index) {
                                                salesList.currentIndex = index
                                                root.salesSubIndex = 0
                                                sNav.stop(); sNav.play()
                                            }
                                        }
                                    }
                                }

                                // ---- DOUBLE COMPONENT ----
                                Column {
                                    anchors.fill: parent
                                    visible: salesDelegate.isDouble
                                    spacing: 8

                                    // Sub-item 0 (top)
                                    Item {
                                        id: subItem0
                                        width: parent.width
                                        height: (root.salesCardH - 8) / 2

                                        property bool isFocused: salesDelegate.isCurrent
                                                              && salesDelegate.isDouble
                                                              && root.salesSubIndex === 0

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"

                                            scale: subItem0.isFocused ? 1.02 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 150 } }

                                            Rectangle {
                                                id: sub0ImgArea
                                                anchors {
                                                    top: parent.top
                                                    left: parent.left
                                                    right: parent.right
                                                }
                                                height: parent.width * 43 / 92
                                                color: "#2A2E35"
                                            }

                                            Rectangle {
                                                anchors {
                                                    top: sub0ImgArea.bottom
                                                    left: parent.left
                                                    right: parent.right
                                                    bottom: parent.bottom
                                                }
                                                color: "transparent"

                                                Row {
                                            anchors {
                                                        right: parent.right
                                                        
                                                    }

                                            Rectangle {
                                                width: sub0DiscText.implicitWidth + 14
                                                height: 60
                                                color: "#54B63D"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    id: sub0DiscText
                                                    anchors.centerIn: parent
                                                    text: "-60%"
                                                    color: "white"
                                                    font.pixelSize: 26
                                                }
                                            }


                                     Rectangle {
                                                width: sub0DiscText.implicitWidth + 170
                                                height: 60
                                                color: "black"
                                                                    
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Row{
                                                anchors.fill: parent 
                                                anchors.leftMargin: 10
                                                spacing: 10
                                                
                                                Text {
                                                text: "$19.99"
                                                color: "gray"
                                                font.pixelSize: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                                
                                            Text {
                                                text: "$9.99 USD"
                                                color: "white"
                                                font.pixelSize: 26
                                                anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        }
                                        }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: -5
                                                anchors.bottomMargin: subItem0.height - sub0ImgArea.height - 60
                                                color: "transparent"
                                                border.width: subItem0.isFocused ? 4 : 0
                                                border.color: "white"
                                                visible: subItem0.isFocused
                                                z: 20
                                                Behavior on border.width { NumberAnimation { duration: 150 } }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (root.focusZone !== 4 || !salesList.activeFocus) {
                                                    root.goToZone(4)
                                                    salesList.currentIndex = index
                                                    salesList.forceActiveFocus()
                                                    root.salesSubIndex = 0
                                                    sNav.stop(); sNav.play()
                                                } else if (salesList.currentIndex !== index) {
                                                    salesList.currentIndex = index
                                                    root.salesSubIndex = 0
                                                    sNav.stop(); sNav.play()
                                                } else {
                                                    root.salesSubIndex = 0
                                                    sNav.stop(); sNav.play()
                                                }
                                            }
                                        }
                                    }

                                    // Sub-item 1 (bottom)
                                    Item {
                                        id: subItem1
                                        width: parent.width
                                        height: (root.salesCardH - 8) / 2

                                        property bool isFocused: salesDelegate.isCurrent
                                                              && salesDelegate.isDouble
                                                              && root.salesSubIndex === 1

                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"

                                            scale: subItem1.isFocused ? 1.02 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 150 } }

                                            Rectangle {
                                                id: sub1ImgArea
                                                anchors {
                                                    top: parent.top
                                                    left: parent.left
                                                    right: parent.right
                                                }
                                                height: parent.width * 43 / 92
                                                color: "#2A2E35"
                                            }

                                            Rectangle {
                                                anchors {
                                                    top: sub1ImgArea.bottom
                                                    left: parent.left
                                                    right: parent.right
                                                    bottom: parent.bottom
                                                }
                                                color: "transparent"

                                                Row {
                                            anchors {
                                                        right: parent.right
                                                        
                                                    }

                                            Rectangle {
                                                width: sub1DiscText.implicitWidth + 14
                                                height: 60
                                                color: "#54B63D"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    id: sub1DiscText
                                                    anchors.centerIn: parent
                                                    text: "-60%"
                                                    color: "white"
                                                    font.pixelSize: 26
                                                }
                                            }


                                     Rectangle {
                                                width: sub1DiscText.implicitWidth + 170
                                                height: 60
                                                color: "black"
                                                                    
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Row{
                                                anchors.fill: parent 
                                                anchors.leftMargin: 10
                                                spacing: 10
                                                
                                                Text {
                                                text: "$19.99"
                                                color: "gray"
                                                font.pixelSize: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                                
                                            Text {
                                                text: "$9.99 USD"
                                                color: "white"
                                                font.pixelSize: 26
                                                anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        }
                                        }
                                            }
                                            
                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.bottomMargin: subItem1.height - sub1ImgArea.height - 60
                                                anchors.margins: -5
                                                color: "transparent"
                                                border.width: subItem1.isFocused ? 4 : 0
                                                border.color: "white"
                                                visible: subItem1.isFocused
                                                z: 20
                                                Behavior on border.width { NumberAnimation { duration: 150 } }
                                            }
                                            }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (root.focusZone !== 4 || !salesList.activeFocus) {
                                                    root.goToZone(4)
                                                    salesList.currentIndex = index
                                                    salesList.forceActiveFocus()
                                                    root.salesSubIndex = 1
                                                    sNav.stop(); sNav.play()
                                                } else if (salesList.currentIndex !== index) {
                                                    salesList.currentIndex = index
                                                    root.salesSubIndex = 1
                                                    sNav.stop(); sNav.play()
                                                } else {
                                                    root.salesSubIndex = 1
                                                    sNav.stop(); sNav.play()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

              // ======== ZONE 5: SIMILAR GAMES ========
                Item {
                    id: similarSection
                    width: parent.width
                    height: 40 + similarColumn.height + 80

                    // === Динамические размеры для Similar Grid ===
                    property real similarCardWidth: 0
                    property real similarCardHeight: 0

                    // Расчёт размеров при изменении ширины
                    onWidthChanged: {
                        var availableWidth = width - 80                  // margins зоны
                        var blockSpacing = 30
                        var oneBlockWidth = (availableWidth - blockSpacing) / 2

                        // Ширина одной карточки (2 колонки в гриде)
                        similarCardWidth = (oneBlockWidth - 48) / 2     // padding + spacing

                        // НОВАЯ ЛОГИКА ВЫСОТЫ — только картинка + цена
                        var imageHeight = similarCardWidth * 9 / 16
                        var priceHeight = 78                   // цена + отступы
                        similarCardHeight = imageHeight + priceHeight
                    }

                    // === Компонент-делегат для ячеек сетки ===
                    Component {
                        id: similarCellDelegate
                        Item {
                            id: similarCell
                            width: similarSection.similarCardWidth
                            height: similarSection.similarCardHeight

                            property int cellIndex: index
                            property int gridIndex: parent.parent.gridIndex

                            property bool isFocused: root.focusZone === 5 &&
                                                      root.similarGridIndex === gridIndex &&
                                                      root.similarCellIndex === cellIndex

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 20
                                color: "transparent"

                                // === Картинка (строго 16:9) ===
                                Rectangle {
                                    id: simCellImg
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                    }
                                    height: parent.width * 9 / 16
                                    color: "#2A2E35"
                                }

                                // === Блок с ценой — жёстко под картинкой ===
                                Rectangle {
                                    id: priceArea
                                    anchors {
                                        top: simCellImg.bottom
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                    }
                                    color: "transparent"

                                    Row {
                                        anchors {
                                            right: parent.right
                                            bottom: parent.bottom
                                        }

                                        Rectangle {
                                            width: simDiscText.implicitWidth + 14
                                            height: 60
                                            color: "#54B63D"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                id: simDiscText
                                                anchors.centerIn: parent
                                                text: "-60%"
                                                color: "white"
                                                font.pixelSize: 26
                                            }
                                        }

                                        Rectangle {
                                            width: simDiscText.implicitWidth + 160
                                            height: 60
                                            color: "black"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                spacing: 10

                                                Text {
                                                    text: "$19.99"
                                                    color: "gray"
                                                    font.pixelSize: 20
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: "$9.99 USD"
                                                    color: "white"
                                                    font.pixelSize: 26
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }
                                }

                                // Обводка при фокусе
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    color: "transparent"
                                    border.width: similarCell.isFocused ? 4 : 0
                                    border.color: "white"
                                    visible: similarCell.isFocused
                                    z: 20
                                    Behavior on border.width { NumberAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.focusZone !== 5) {
                                        root.goToZone(5)
                                        sNav.stop(); sNav.play()
                                    }
                                    root.similarGridIndex = gridIndex
                                    root.similarCellIndex = cellIndex
                                    similarCatcher.forceActiveFocus()
                                }
                            }
                        }
                    }

                    FocusScope {
                        id: similarCatcher
                        anchors.fill: parent

                        Keys.onPressed: {
                            var row = Math.floor(root.similarCellIndex / 2)
                            var col = root.similarCellIndex % 2

                            if (event.key === Qt.Key_Right) {
                                if (col === 0) {
                                    root.similarCellIndex++
                                    sNav.stop(); sNav.play()
                                    event.accepted = true
                                } else if (col === 1 && root.similarGridIndex === 0) {
                                    root.similarGridIndex = 1
                                    root.similarCellIndex = root.similarCellIndex - 1
                                    sNav.stop(); sNav.play()
                                    event.accepted = true
                                }
                            } else if (event.key === Qt.Key_Left) {
                                if (col === 1) {
                                    root.similarCellIndex--
                                    sNav.stop(); sNav.play()
                                    event.accepted = true
                                } else if (col === 0 && root.similarGridIndex === 1) {
                                    root.similarGridIndex = 0
                                    root.similarCellIndex = root.similarCellIndex + 1
                                    sNav.stop(); sNav.play()
                                    event.accepted = true
                                }
                            } else if (event.key === Qt.Key_Down) {
                                if (row === 0) {
                                    root.similarCellIndex += 2
                                    sNav.stop(); sNav.play()
                                    event.accepted = true
                                }
                            } else if (event.key === Qt.Key_Up) {
                                if (row === 1) {
                                    root.similarCellIndex -= 2
                                    sNav.stop(); sNav.play()
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Column {
                        id: similarColumn
                        anchors {
                            top: parent.top
                            topMargin: 40
                            left: parent.left
                            leftMargin: 40
                            right: parent.right
                            rightMargin: 40
                        }
                        spacing: 50

                        Row {
                            width: parent.width
                            spacing: 30

                            // ==== Первый блок (Similar 1) ====
                            Column {
                                width: (parent.width - parent.spacing) / 2
                                spacing: 15

                                Text {
                                    text: "Similar 1"
                                    color: "white"
                                    font.pixelSize: 36
                                    font.family: bold.name
                                }

                                Text {
                                    text: "List of the games with tags same as you played"
                                    color: "#AAAAAA"
                                    font.pixelSize: 28
                                }

                                Rectangle {
                                    id: simRect0
                                    width: parent.width
                                    height: similarSection.similarCardHeight * 2 + 88  // 2 ряда + отступы
                                    color: "#1A1D23"
                                    property int gridIndex: 0

                                    Grid {
                                        anchors.centerIn: parent
                                        columns: 2
                                        spacing: 8
                                        padding: 20

                                        Repeater {
                                            model: 4
                                            delegate: similarCellDelegate
                                        }
                                    }

                                    Row {
                                        anchors.top: simRect0.bottom
                                        anchors.right: simRect0.right
                                        anchors.topMargin: 20
                                        spacing: 10

                                        Text {
                                            text: "Y"
                                            color: "white"
                                            font.pixelSize: 40
                                            font.family: icons.name
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "More"
                                            color: "white"
                                            font.pixelSize: 26
                                            font.family: bold.name
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            // ==== Второй блок (Similar 2) ====
                            Column {
                                width: (parent.width - parent.spacing) / 2
                                spacing: 15

                                Text {
                                    text: "Similar 2"
                                    color: "white"
                                    font.pixelSize: 36
                                    font.family: bold.name
                                }

                                Text {
                                    text: "List of the games with tags same as you played"
                                    color: "#AAAAAA"
                                    font.pixelSize: 28
                                }

                                Rectangle {
                                    id: simRect1
                                    width: parent.width
                                    height: similarSection.similarCardHeight * 2 + 88
                                    color: "#1A1D23"
                                    property int gridIndex: 1

                                    Grid {
                                        anchors.centerIn: parent
                                        columns: 2
                                        spacing: 8
                                        padding: 20

                                        Repeater {
                                            model: 4
                                            delegate: similarCellDelegate
                                        }
                                    }

                                    Row {
                                        anchors.top: simRect1.bottom
                                        anchors.right: simRect1.right
                                        anchors.topMargin: 20
                                        spacing: 10

                                        Text {
                                            text: "Y"
                                            color: "white"
                                            font.pixelSize: 40
                                            font.family: icons.name
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "More"
                                            color: "white"
                                            font.pixelSize: 26
                                            font.family: bold.name
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                } 

                // ======== ZONE 6: WIDE BANNER ========
                Item {
                    id: wideBannerZone
                    width: parent.width
                    height: (parent.width - 48) * 11 / 71 + 48 + root.topH

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 24
                        anchors.bottomMargin: root.topH + 24
                        color: "#2A2E35"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            color: "transparent"
                            border.width: root.focusZone === 6 ? 4 : 0
                            border.color: "white"
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.focusZone !== 6) {
                                    root.goToZone(6)
                                    sNav.stop(); sNav.play()
                                }
                            }
                        }
                    }

                    FocusScope {
                        id: wideBannerCatcher
                        anchors.fill: parent
                    }
                }

            } // Column content
        } // Flickable
    } // animatedContent
    
    /* ================= TOP BAR ================= */
    Rectangle {
        id: topBar
        width: content.width
        height: root.topH
        color: "transparent"
        z: 10000

        property real scrollRatio: (flick.contentHeight > flick.height)
            ? (flick.contentY / (flick.contentHeight - flick.height))
            : 0

        Rectangle {
            anchors.fill: parent
            color: "black"
            //color: leftBar.isOpen || topButtonsRow.focus ? Qt.rgba(0,0,0) : Qt.rgba(0, 0, 0, Math.min(topBar.scrollRatio / 0.4, 1))
            //Behavior on color { ColorAnimation { duration: 200 } }
            z: -1
        }

        // ======= ROW: TOP BUTTONS =======
        Row {
            id: topButtonsRow
            anchors {
                right: parent.right
                left: parent.left   
                verticalCenter: parent.verticalCenter
                rightMargin: 15
            }
            property int currentIndex: 0
            spacing: 0

            // // ===== SEARCH =====
Rectangle {
    id: topBtnSearch
    width: topBar.width - (topBtnNet.width + topBarBattery.width + topBtnClock.width + topBtnUser.width + topButtonsRow.spacing * 3 + topButtonsRow.anchors.rightMargin * 2)
    height: root.topH
                color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "white" : "transparent"
                border.width: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                
                // Иконка Лупы
                               Text {
    id: searchIcon
    anchors.verticalCenter: parent.verticalCenter
    text: "¿"
    font.pixelSize: 35
    font.family: icons.name
    color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "black" : "white"
    
    readonly property real posRight: topBtnSearch.width - 50
    readonly property real posLeft: 15
    
    // ВЕРНУЛИ декларативную привязку (определяет стартовую позицию и реагирует на ресайз)
    x: posRight 

    // Component.onCompleted ПОЛНОСТЬЮ УДАЛЕН

    states: [
        State {
            name: "focused"
            when: topButtonsRow.currentIndex === 0 && topButtonsRow.focus
            PropertyChanges { target: searchIcon; x: posLeft; opacity: 1 }
        },
        State {
            name: "default"
            when: !(topButtonsRow.currentIndex === 0 && topButtonsRow.focus)
            PropertyChanges { target: searchIcon; x: posRight; opacity: 1 }
        }
    ]

    transitions: [
        Transition {
            from: "default"; to: "focused"
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { 
                        target: searchIcon
                        property: "x"
                        to: searchIcon.posRight - 20
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                }

                PropertyAction { 
                    target: searchIcon
                    property: "x"
                    value: searchIcon.posLeft + 20
                }

                ParallelAnimation {
                    NumberAnimation { 
                        target: searchIcon
                        property: "x"
                        to: searchIcon.posLeft
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation { target: searchIcon; property: "opacity"; to: 1; duration: 200 }
                }
            }
        },
        
        Transition {
            from: "focused"; to: "default"
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { 
                        target: searchIcon
                        property: "x"
                        to: searchIcon.posLeft + 20
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                }

                PropertyAction { 
                    target: searchIcon
                    property: "x"
                    value: searchIcon.posRight - 20
                }

                ParallelAnimation {
                    NumberAnimation { 
                        target: searchIcon
                        property: "x"
                        to: searchIcon.posRight
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation { target: searchIcon; property: "opacity"; to: 1; duration: 200 }
                }
            }
        }
    ]
}
  
                  Text {
    id: searchText
    anchors.verticalCenter: parent.verticalCenter
    
    // Базовая позиция: x зависит от ширины иконки и отступа
    readonly property real targetX: 15 + 50 // posLeft лупы + отступ
    x: targetX + 20 // По умолчанию сдвинут вправо
    y: 0

    text: "Search games in your Library..."
    font.pixelSize: 30
    font.family: bold.name
    color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "grey" : "transparent"
    opacity: 0
    visible: false

    states: [
        State {
            name: "focused"
            when: topButtonsRow.currentIndex === 0 && topButtonsRow.focus
            PropertyChanges { target: searchText; x: searchText.targetX; opacity: 1; visible: true }
        }
    ]

    transitions: [
        Transition {
            from: "*"; to: "focused"
            SequentialAnimation {
                // Сначала делаем видимым, но прозрачным
                PropertyAction { target: searchText; property: "visible"; value: true }
                // Пауза, чтобы текст начал появляться, когда лупа уже почти доехала (синхронизация)
                PauseAnimation { duration: 150 }
                ParallelAnimation {
                    NumberAnimation { target: searchText; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: searchText; property: "x"; to: searchText.targetX; duration: 200; easing.type: Easing.OutCubic }
                }
            }
        },
        Transition {
            from: "focused"; to: "*"
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: searchText; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { target: searchText; property: "x"; to: searchText.targetX + 20; duration: 150; easing.type: Easing.InCubic }
                }
                // В конце скрываем полностью
                PropertyAction { target: searchText; property: "visible"; value: false }
            }
        }
    ]
}



        MouseArea { 
        anchors.fill: parent
        onClicked: if (!root.closeMenuVisible) {
            // Если мы уже находимся в верхней зоне и уже выбрана кнопка поиска (индекс 0)
            if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                theme.openPage(9) // Открываем Library
            } else {
                // Если нет — просто переходим в верхнюю зону и выбираем поиск
                root.goToZone(0)
                topButtonsRow.currentIndex = 0
                topButtonsRow.forceActiveFocus()
                sNav.play ()
            }
        }
    }
}


            // ===== NETWORK =====
            Rectangle {
                id: topBtnNet
                width: 72; height: root.topH
                color: (topButtonsRow.currentIndex === 1 && topButtonsRow.focus) ? "white" : "transparent"
                border.width: (topButtonsRow.currentIndex === 1 && topButtonsRow.focus) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: theme.isOnline ? "°" : "o" 
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsRow.currentIndex === 1 && topButtonsRow.focus) ? "black" : "white"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0)
                        topButtonsRow.currentIndex = 1
                        sNav.play ()
                    }
                }
            }
            
            
          // Battery icon           
Item {
    id: topBarBattery
    width: theme.showBatteryPercent ? 170 : 70
    height: root.topH

    // === Фон (реагирует на фокус) ===
    Rectangle {
        id: batteryBg
        anchors.fill: parent
        color: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "white" : "transparent"
        border.width: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? 2 : 0
        border.color: "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // === Контент (текст + иконки) ===
    Row {
        id: batteryRow
        spacing: 5
        anchors.centerIn: parent

        // Выбор правильной иконки батареи
        function getBatteryIcon() {
            if (isNaN(api.device.batteryPercent)) {
                return "../assets/theme-icons/battery" + getSuffix() + ".png";
            }

            const batteryPercent = api.device.batteryPercent * 100;

            if (batteryPercent <= 20) {
                return "../assets/theme-icons/20" + getSuffix() + ".png";
            } else if (batteryPercent <= 40) {
                return "../assets/theme-icons/40" + getSuffix() + ".png";
            } else if (batteryPercent <= 60) {
                return "../assets/theme-icons/60" + getSuffix() + ".png";
            } else if (batteryPercent <= 80) {
                return "../assets/theme-icons/80" + getSuffix() + ".png";
            } else {
                return "../assets/theme-icons/battery" + getSuffix() + ".png";
            }
        }

        // Добавляем суффикс B при фокусе
        function getSuffix() {
            return (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "B" : "";
        }

        Text {
            text: {
                if (isNaN(api.device.batteryPercent)) {
                    return "N/A"
                } else {
                    return (api.device.batteryPercent * 100).toFixed(0) + "%"
                }
            }
            color: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "black" : "white"
            font.family: bold.name
            font.pixelSize: 36
            visible: theme.showBatteryPercent // Скрываем текст, если выключено
            verticalAlignment: Text.AlignVCenter
        }

        // === Контейнер для иконок (основная батарея + зарядка) ===
        Item {
            width: 57
            height: 33
            anchors.verticalCenter: parent.verticalCenter

            // Основная иконка батареи
            Image {
                id: batteryBase
                anchors.fill: parent
                source: batteryRow.getBatteryIcon()
                mipmap: true
            }

            // Иконка зарядки (поверх основной)
            Image {
                id: chargingOverlay
                anchors.fill: parent
                source: "../assets/theme-icons/charging" + batteryRow.getSuffix() + ".png"
                mipmap: true
                visible: api.device.batteryCharging
            }
        }
    }

    // === Область клика ===
    MouseArea {
        anchors.fill: parent
        onClicked: if (!root.closeMenuVisible) {
            root.goToZone(0)
            topButtonsRow.currentIndex = 2
            sNav.play ()
        }
    }
}
                    

            // ===== CLOCK =====
            Rectangle {
                id: topBtnClock
                width: theme.use24HourFormat ? 130 : 200; height: root.topH
                color: "transparent"
                border.color: "transparent"               

                // Динамически определяем формат времени на основе настройки
                property string timeFormat: theme.use24HourFormat ? "HH:mm" : "hh:mm AP"

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    // Инициализация при загрузке
                    text: Qt.formatTime(new Date(), topBtnClock.timeFormat)
                    font.pixelSize: 35
                    font.family: bold.name
                    color: "white"
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
                }                
                
                // Мгновенно обновляем текст, если переключатель нажали
                onTimeFormatChanged: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
            }


            // ===== USER =====
            Rectangle {
                id: topBtnUser
                width: root.topH * 1.1; height: root.topH
                color: (topButtonsRow.currentIndex === 3 && topButtonsRow.focus) ? "white" : "transparent"
                border.width: (topButtonsRow.currentIndex === 3 && topButtonsRow.focus) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                AnimatedImage {
                    id: userImage
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    height: parent.height * 0.8
                    source: (root.theme && root.theme.profilePictureSource !== "") ? root.theme.profilePictureSource : "../assets/logo/logo.jpg" /* DECKOS */
                    fillMode: Image.PreserveAspectFit
                    playing: visible && status === AnimatedImage.Ready && (api.memory.has("animatedCovers") ? api.memory.get("animatedCovers") : false)
                }

                Rectangle {
                    anchors {
                        top: userImage.top
                        bottom: userImage.bottom
                        right: userImage.right
                    }
                    width: 10
                    color: "#00BFFF"
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0)
                        topButtonsRow.currentIndex = 3
                        sNav.stop();
            sNav.play();
                    }
                }
            }

            Keys.onLeftPressed:{ if (topButtonsRow.currentIndex > 0) topButtonsRow.currentIndex--
            sNav.stop();
            sNav.play(); 
}
            Keys.onRightPressed: {if (topButtonsRow.currentIndex < 3) topButtonsRow.currentIndex++
            sNav.stop();
            sNav.play();
        }
            Keys.onDownPressed: {root.goToZone(1)
sNav.stop();
            sNav.play(); 
}
            Keys.onPressed: 
                      if (event.key === Qt.Key_Return || api.keys.isAccept(event)){
                     if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                theme.openPage(9) // Открываем Library
                }
                }
        }
    }

    // ======== BOTTOM BAR ========
    Item {
        id: bottomBar
        width: parent.width
        height: root.topH
        anchors.bottom: parent.bottom
        z: 100000000000
        clip: true

        ShaderEffectSource {
            id: bottomAreaSource
            sourceItem: globalBlurSource
            sourceRect: Qt.rect(0, root.height - root.topH, root.width, root.topH)
            live: true
            visible: false
        }

        GaussianBlur {
            anchors.fill: parent
            source: bottomAreaSource
            radius: 150
            visible: !theme.highContrastBottomBar
            samples: 64
            transparentBorder: false
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: theme.highContrastBottomBar ? 1.0 : (leftBar.isOpen || root.closeMenuVisible ? 0.9 : 0.6)
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Rectangle {
            id: btnMenu
            width: 180; height: parent.height
            anchors.left: parent.left
            anchors.leftMargin: 18
            color: "transparent"

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text { text: ":"; font.family: icons.name; font.pixelSize: 54; color: "white" }
                Text {
                    text: root.closeMenuVisible ? "PEGASUS MENU" : "MENU"
                    font.family: bold.name
                    font.pixelSize: 28
                    color: "white"
                    y: parent.height * 0.21
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.closeMenuVisible) return
                    if (!leftBar.isOpen) leftBar.currentIndex = 0 // DECKOS: see home.qml
                    leftBar.toggle()
                    if (!leftBar.isOpen) focusTimer.start()
                }
            }
        }

        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.rightMargin: 35
            anchors.verticalCenter: parent.verticalCenter
            spacing: 38

            Row {
                spacing: 18
                visible: !leftBar.isOpen && !root.closeMenuVisible
                anchors.verticalCenter: parent.verticalCenter
                Text { text: theme.nintendoLayout ? (theme.universalIcons ? "В" : "B") : (theme.universalIcons ? "А" : "A"); font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025 }
                Text { text: "SELECT"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
            }

            Rectangle {
                width: 140; height: parent.height
                color: "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Text { text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B"); font.family: icons.name; font.pixelSize: 53; color: "white"; y: parent.height * -0.025 }
                    Text { text: "BACK"; font.family: bold.name; font.pixelSize: 25; color: "white"; y: parent.height * 0.23 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.closeMenuVisible) {
                            root.closeMenuVisible = false
                            sLeftClose.play()
                            focusTimer.start()
                        } else if (root.focusZone > 0) {
                            root.goToZone(root.focusZone - 1)
                            sBack.stop(); sBack.play()
                        } else {
                            leftBar.toggle()
                        }
                    }
                }
            }
        }
    }

    // ======== LEFT OVERLAY ========
    Item {
        id: leftOverlay
        anchors.fill: parent
        z: 0
        opacity: (leftBar.x + leftBar.width) / leftBar.width
        visible: opacity > 0

        MouseArea {
            anchors.fill: parent
            enabled: leftBar.isOpen
            onClicked: {
                leftBar.toggle()
                focusTimer.start()
            }
        }

        FastBlur {
            anchors.fill: parent
            source: globalBlurSource
            radius: 50
            transparentBorder: false
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.7
        }
    }

    // ======== LEFT BAR ========
    FocusScope {
        id: leftBar
        width: parent.width
        height: parent.height
        visible: false
        focus: false
        z: 999
        x: leftBar.isOpen ? 0 : -width
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        property bool isOpen: false
        property int currentIndex: 0
        property var buttons: []

        Rectangle {
            id: menuPanel
            width: parent.width * 0.25
            height: parent.height
            color: "#181B20"
            anchors.left: parent.left
            z: 1000
            x: leftBar.isOpen ? width * 0.2 : 0

            ProfileBadge { // DECKOS: user picture + name (Settings > Profile)
                theme: root.theme
                anchors.left: parent.left; anchors.leftMargin: 40
                anchors.right: parent.right; anchors.rightMargin: 20
                y: parent.height * 0.105; height: parent.height * 0.075
            }
            Column {
                id: buttonColumn
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 0
                    topMargin: parent.height * 0.2 /* DECKOS: was 0.11, room for the profile */
                }
                spacing: 0
            }
        }

        Keys.onPressed: {
            if (leftBar.isOpen && leftBar.focus) {
                if (event.key === Qt.Key_Up) {
                    if (currentIndex > 0) {
                        currentIndex--
                        updateFocus()
                        sNav.stop(); sNav.play()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    if (currentIndex < buttons.length - 1) {
                        currentIndex++
                        updateFocus()
                        sNav.stop(); sNav.play()
                    }
                    event.accepted = true
                } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                    if (currentIndex === 7) {
                        leftBar.toggle()
                        theme.openPowerMenu() /* DECKOS: one Close menu (theme.qml) */
                    } else {
                        theme.openPage(currentIndex)
                        leftBar.toggle()
                        if (currentIndex === 6) sShowui.play()
                    }
                    event.accepted = true
                } else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
                    leftBar.toggle()
                    focusTimer.start()
                    event.accepted = true
                }
            }
        }

        Component {
            id: menuButtonComponent
            FocusScope {
                property string title: ""
                property int buttonIndex: 0
                width: menuPanel.width
                height: Math.min(106, menuPanel.height * 0.085) /* DECKOS: was 106 */

                property bool isFocused: leftBar.isOpen && leftBar.currentIndex === buttonIndex // DECKOS: the selected button, not Qt focus (which can drift)
                property color bgColor: "transparent"
                property color textColor: "#AAA"
                property string icon: ""

                onIsFocusedChanged: {
                    if (isFocused) { bgColor = "#27303A"; textColor = "white" }
                    else { bgColor = "transparent"; textColor = "#AAA" }
                }

                Rectangle {
                    anchors.fill: parent
                    color: bgColor
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Item {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 20; bottomMargin: 20 }
                        width: 11
                        visible: theme.currentPage === buttonIndex

                        Rectangle {
                            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                            width: 27
                            color: "#1A9EFF"
                            radius: 40
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: menuPanel.width * 0.083
                        spacing: 38

                        Text { text: icon; font.family: icons.name; font.pixelSize: menuPanel.width * 0.075; color: "white"; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter }
                        Text { text: title; font.family: bold.name; font.pixelSize: menuPanel.width * 0.075; color: "white"; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (leftBar.currentIndex === buttonIndex) {
                            if (buttonIndex === 7) {
                                leftBar.toggle()
                                theme.openPowerMenu() /* DECKOS: one Close menu (theme.qml) */
                            } else {
                                theme.openPage(buttonIndex)
                                leftBar.toggle()
                                if (buttonIndex === 6) sShowui.play()
                            }
                        } else {
                            leftBar.currentIndex = buttonIndex
                            leftBar.updateFocus()
                            sNav.play()
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            var btn1 = menuButtonComponent.createObject(buttonColumn, { "title": "Home",             "buttonIndex": 0, "icon": "^"  })
            var btn2 = menuButtonComponent.createObject(buttonColumn, { "title": "Library",          "buttonIndex": 1, "icon": "L"  })
            var btn3 = menuButtonComponent.createObject(buttonColumn, { "title": "Store",            "buttonIndex": 2, "icon": "€"  })
            var btn4 = menuButtonComponent.createObject(buttonColumn, { "title": "Friends and Chat", "buttonIndex": 3, "icon": "F"  })
            var btn5 = menuButtonComponent.createObject(buttonColumn, { "title": "Media",            "buttonIndex": 4, "icon": "M"  })
            var btn6 = menuButtonComponent.createObject(buttonColumn, { "title": "Downloads",        "buttonIndex": 5, "icon": "♠︎" })
            var btn7 = menuButtonComponent.createObject(buttonColumn, { "title": "Settings",         "buttonIndex": 6, "icon": "w"  })
            var btn8 = menuButtonComponent.createObject(buttonColumn, { "title": "Close",            "buttonIndex": 7, "icon": "C"  })
            leftBar.buttons = [btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8]
            currentIndex = 0
            updateFocus()
        }

        function updateFocus() {
            if (currentIndex >= 0 && currentIndex < buttons.length) {
                buttons[currentIndex].forceActiveFocus()
            }
        }

        function toggle() {
            theme.toggleLeftBar(leftBar)
        }
    }

    // ======== CLOSE MENU ========
    FocusScope {
        id: closeMenu
        width: parent.width
        height: parent.height
        visible: closeMenuVisible
        focus: closeMenuVisible
        enabled: visible
        z: 9999
        opacity: closeMenuVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        property int currentButtonIndex: 0

        Item {
            anchors.fill: parent
            z: 0
            visible: root.closeMenuVisible

            MouseArea { anchors.fill: parent }

            FastBlur {
                anchors.fill: parent
                source: globalBlurSource
                radius: 50
                transparentBorder: false
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.7
            }
        }

        Rectangle {
            width: 550
            height: 240
            anchors.centerIn: parent
            color: "#181B20"
            z: 1

            Text {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: -65 }
                text: "Close"
                color: "white"
                font.pixelSize: 38
                font.family: bold.name
            }

            Column {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                spacing: 0

                Rectangle {
                    id: cmExitBtn
                    width: parent.width
                    height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 0 ? "#DE3619" : "transparent"

                    Text { text: "   Exit"; color: "white"; font.pixelSize: 35; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 0) { closeMenu.currentButtonIndex = 0; sNav.stop(); sNav.play() }
                            else Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                        }
                    }
                }

                Rectangle {
                    id: cmCancelBtn
                    width: parent.width
                    height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 1 ? "white" : "transparent"

                    Text { text: "   Cancel"; color: closeMenu.currentButtonIndex === 1 ? "black" : "white"; font.pixelSize: 35; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 1) { closeMenu.currentButtonIndex = 1; sNav.stop(); sNav.play() }
                            else { closeMenuVisible = false; sLeftClose.play(); focusTimer.start() }
                        }
                    }
                }
            }
        }

        Keys.onPressed: {
            if (closeMenuVisible) {
                if (event.key === Qt.Key_Up) {
                    if (currentButtonIndex > 0) { currentButtonIndex--; sNav.stop(); sNav.play() }
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    if (currentButtonIndex < 1) { currentButtonIndex++; sNav.stop(); sNav.play() }
                    event.accepted = true
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    event.accepted = true
                } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                    if (currentButtonIndex === 0) { Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */; return }
                    else { closeMenuVisible = false; sLeftClose.play(); focusTimer.start() }
                    event.accepted = true
                }
            }
        }

        onVisibleChanged: {
            if (visible) { currentButtonIndex = 0; sShowui.play(); forceActiveFocus() }
        }
    }

    // ======== ROOT KEY HANDLER ========
    Keys.onPressed: {
        if (leftBar.isOpen || root.closeMenuVisible) return

        if (event.key === Qt.Key_Down) {
            if (root.focusZone < 6) {
                root.goToZone(root.focusZone + 1)
                sNav.stop(); sNav.play()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Up) {
            if (root.focusZone > 0) {
                root.goToZone(root.focusZone - 1)
                sNav.stop(); sNav.play()
                event.accepted = true
            }
        } else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
            if (root.focusZone > 0) {
                root.goToZone(root.focusZone - 1)
                sBack.stop(); sBack.play()
            } else {
                leftBar.toggle()
            }
            event.accepted = true
        } else if (api.keys.isMenu(event)) {
            leftBar.toggle()
            event.accepted = true
        }
    }

    // ======== ANIMATIONS ========
    SequentialAnimation {
        id: enterAnim
        ScriptAction { script: { animatedContent.opacity = 0; animatedContent.scale = 0.95 } }
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 1;   duration: 225; easing.type: Easing.OutQuad }
            NumberAnimation { target: animatedContent; property: "scale";   to: 1.0; duration: 225; easing.type: Easing.OutQuad }
        }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 0;    duration: 225; easing.type: Easing.InQuad }
            NumberAnimation { target: animatedContent; property: "scale";   to: 0.95; duration: 225; easing.type: Easing.InQuad }
        }
        ScriptAction { script: theme.finalizeNavigation(nextPageIndex) }
    }

    Timer {
        id: focusTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            if (!root.closeMenuVisible) {
                root.goToZone(root.focusZone)
            }
        }
    }

    Component.onCompleted: {
        enterAnim.start()
        root.goToZone(0)
        focusTimer.start()
    }   
}
