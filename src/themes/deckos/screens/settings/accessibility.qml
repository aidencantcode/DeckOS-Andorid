import QtQuick 2.0

Item {
    id: accessibilityPage
    anchors.fill: parent
    
    // Инициализация состояний из встроенного JSON-хранилища (theme_settings)
    property real interfaceScale: api.memory.has("interfaceScale") ? api.memory.get("interfaceScale") : 0.5
    property bool asyncLoading: api.memory.has("asyncLoading") ? api.memory.get("asyncLoading") : false
    property bool animatedCovers: api.memory.has("animatedCovers") ? api.memory.get("animatedCovers") : false
    property bool animationInFocus: api.memory.has("animationInFocus") ? api.memory.get("animationInFocus") : false
    property int activeItemIndex: 0
    property int maxItemIndex: 6
    
    onActiveItemIndexChanged: {
    // Вычисляем верхнюю границу текущего элемента (y)
    var itemTop = 0
    for (var i = 0; i < activeItemIndex; ++i) {
        itemTop += (i === 0 || i === 4 || i === 5) ? 185 : 130
    }
    var itemBottom = itemTop + ((activeItemIndex === 0 || activeItemIndex === 4 || activeItemIndex === 5) ? 185 : 130)

    // Текущие границы видимой области
    var viewTop = flickable.contentY
    var viewBottom = viewTop + flickable.height

    // Заданные отступы (сверху 60, снизу 60)
    var topMargin = 120
    var bottomMargin = 120

    var newY = flickable.contentY

    // Если элемент выходит за верхнюю границу
    if (itemTop - topMargin < viewTop) {
        newY = Math.max(0, itemTop - topMargin)
    }
    // Если элемент выходит за нижнюю границу
    else if (itemBottom + bottomMargin > viewBottom) {
        newY = Math.min(flickable.contentHeight - flickable.height,
                        itemBottom + bottomMargin - flickable.height)
    }

    // Принудительно оставляем contentY = 0 для первых четырёх элементов (индексы 0,1,2,3)
    if (activeItemIndex <= 3) {
        newY = 0
    }

    flickable.contentY = newY
}

    // Автоматическое сохранение в JSON при любых изменениях
    onInterfaceScaleChanged: {
        api.memory.set("interfaceScale", interfaceScale)
        if (typeof theme !== "undefined" && theme) theme.interfaceScale = interfaceScale // DECKOS: apply live
    }
    onAsyncLoadingChanged: api.memory.set("asyncLoading", asyncLoading)
    onAnimatedCoversChanged: api.memory.set("animatedCovers", animatedCovers)
    onAnimationInFocusChanged: api.memory.set("animationInFocus", animationInFocus)
    
        property int libraryRows: api.memory.has("libraryRows") ? api.memory.get("libraryRows") : 3
    property int homeRows: api.memory.has("homeRows") ? api.memory.get("homeRows") : 3
    property int searchRows: api.memory.has("searchRows") ? api.memory.get("searchRows") : 3

    onLibraryRowsChanged: api.memory.set("libraryRows", libraryRows)
    onHomeRowsChanged: api.memory.set("homeRows", homeRows)
    onSearchRowsChanged: api.memory.set("searchRows", searchRows)
    
    property bool sliderActive: false
property int activeSliderIndex: -1

property bool gameLaunchingAnimation: api.memory.has("gameLaunchingAnimation") ? api.memory.get("gameLaunchingAnimation") : true
onGameLaunchingAnimationChanged: api.memory.set("gameLaunchingAnimation", gameLaunchingAnimation)


function handleAccept() {
    if (sliderActive) {
        sliderActive = false
        activeSliderIndex = -1
    } else {
        // 0=Scale, 4=Library, 5=Search
        if (activeItemIndex === 0 || activeItemIndex === 4 || activeItemIndex === 5) {
            sliderActive = true
            activeSliderIndex = activeItemIndex
            if (activeItemIndex === 0) focusAnim.start()
            else if (activeItemIndex === 4) focusAnimLibrary.start()
            else if (activeItemIndex === 5) focusAnimSearch.start()
        } else {
            if (activeItemIndex === 1) asyncLoading = !asyncLoading
            else if (activeItemIndex === 2) animatedCovers = !animatedCovers
            else if (activeItemIndex === 3) animationInFocus = !animationInFocus
            else if (activeItemIndex === 6) gameLaunchingAnimation = !gameLaunchingAnimation
        }
    }
}

function handleLeft() {
    if (sliderActive) {
        if (activeSliderIndex === 0) interfaceScale = Math.max(0, interfaceScale - 0.05)
        else if (activeSliderIndex === 4) libraryRows = Math.max(3, libraryRows - 1)
        else if (activeSliderIndex === 5) searchRows = Math.max(3, searchRows - 1)
    }
}

function handleRight() {
    if (sliderActive) {
        if (activeSliderIndex === 0) interfaceScale = Math.min(1, interfaceScale + 0.05)
        else if (activeSliderIndex === 4) libraryRows = Math.min(8, libraryRows + 1)
        else if (activeSliderIndex === 5) searchRows = Math.min(8, searchRows + 1)
    }
}

function handleCancel() {
    if (sliderActive) {
        sliderActive = false
        activeSliderIndex = -1
    }
}


    Text {
        id: pageTitle
        text: "Accessibility"
        color: "white"
        font.pixelSize: 50 
        font.family: bold.name
        font.bold: true
        anchors.top: parent.top
        anchors.topMargin: 70
        anchors.left: parent.left
        anchors.leftMargin: 50
    }

    Rectangle {
        id: titleDivider
        height: 1
        width: parent.width - 100
        color: "#333"
        anchors.top: pageTitle.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Flickable {
        id: flickable
        anchors.top: titleDivider.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        contentHeight: settingsColumn.height + bottomBar.height 
        clip: true
        boundsBehavior: Flickable.StopAtBounds // Жесткая фиксация верха и низа
        
        Behavior on contentY { 
            NumberAnimation { 
                duration: 200 
                easing.type: Easing.OutCubic
            } 
        }

        Column {
            id: settingsColumn
            width: parent.width
            spacing: 0

        // 1. Interface Scale (Slider)
        Rectangle {
            width: parent.width
            height: 185
            color: (activeZone === 1 && activeItemIndex === 0) ? "#30343A" : "transparent"

            Column {
                anchors.fill: parent
                anchors.leftMargin: 50
                anchors.rightMargin: 50
                anchors.topMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 55

                Text {
                    text: "Interface Scale"
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Item {
                    width: parent.width
                    height: 50

                    Item {
                        id: sliderTrack
                        width: parent.width
                        height: 13
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "#555"
                            radius: 5
                            
                            Rectangle {
                                width: parent.width * interfaceScale
                                height: parent.height
                                color: "#00ACFF"
                                radius: 5
                            }
                        }

                        // Каретка ползунка с анимацией при фокусе
                        Rectangle {
                            id: sliderThumb
                            width: 60
                            height: 60
                            radius: 60
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (parent.width * interfaceScale) - (width / 2)

                            // Отслеживание фокуса для запуска анимации
                            property bool isFocused: (activeZone === 1 && activeItemIndex === 0)
                         
                            // Анимация увеличения и возврата (0.5 секунды в сумме)
                            SequentialAnimation {
                                id: focusAnim
                                NumberAnimation { target: sliderThumb; property: "scale"; to: 1.3; duration: 100 }
                                NumberAnimation { target: sliderThumb; property: "scale"; to: 1.0; duration: 100 }
                            }
                        }
                    }

                    Text {
                        text: "SMALLER TEXT"
                        color: "white"
                        font.pixelSize: 23
                        font.family: bold.name
                        font.bold: true
                        anchors.left: parent.left
                        anchors.top: sliderTrack.bottom
                        anchors.topMargin:  30
                    }

                    Text {
                        text: "LARGE TEXT"
                        color: "white"
                        font.pixelSize: 23
                        font.family: bold.name
                        font.bold: true
                        anchors.right: parent.right
                        anchors.top: sliderTrack.bottom
                        anchors.topMargin:  30
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 0) {
                        var newScale = mouseX / width
                        interfaceScale = Math.max(0, Math.min(1, newScale))
                    } else {
                    focusAnim.start()
                        activeZone = 1
                        activeItemIndex = 0
                    }
                }
            }
            
            Rectangle { 
                height: 1
                width: parent.width - 100
                color: "#333"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter 
            }
        }


        // 2. Asynchronous Loading (Switch)
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 1) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text {
                    text: "Asynchronous Loading"
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Text {
                    text: "Asynchronous UI component loading,may cause visual errors but improves loading speed."
                    color: "lightgray"
                    font.pixelSize: 25
                    font.family: bold.name
                }
            }

            Rectangle {
                width: 72
                height: 44
                radius: 44
                color: asyncLoading ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 1) ? "gray" : "transparent"
                border.width: 6 
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44
                    height: 44
                    radius: 44
                    color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 1) ? "gray" : "transparent"
                    border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: asyncLoading ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 1) {
                        asyncLoading = !asyncLoading
                    } else {
                        activeZone = 1
                        activeItemIndex = 1
                    }
                }
            }
            
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // 3. Animated Cover Arts (Switch)
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 2) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text {
                    text: "Animated Cover Arts"
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Text {
                    text: "Enabling animation for assets,may cause performance degradation."
                    color: "lightgray"
                    font.pixelSize: 25
                    font.family: bold.name
                }
            }

            Rectangle {
                width: 72
                height: 44
                radius: 44
                color: animatedCovers ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 2) ? "gray" : "transparent"
                border.width: 6 
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44
                    height: 44
                    radius: 44
                    color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 2) ? "gray" : "transparent"
                    border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: animatedCovers ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 2) {
                        animatedCovers = !animatedCovers
                    } else {
                        activeZone = 1
                        activeItemIndex = 2
                    }
                }
            }
            
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // 4. Animation in Focus (Switch)
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 3) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text {
                    text: "Animation in Focus"
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Text {
                    text: "Play animation only for the currently focused game."
                    color: "lightgray"
                    font.pixelSize: 25
                    font.family: bold.name
                }
            }

            Rectangle {
                width: 72
                height: 44
                radius: 44
                color: animationInFocus ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 3) ? "gray" : "transparent"
                border.width: 6 
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44
                    height: 44
                    radius: 44
                    color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 3) ? "gray" : "transparent"
                    border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: animationInFocus ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 3) {
                        animationInFocus = !animationInFocus
                    } else {
                        activeZone = 1
                        activeItemIndex = 3
                    }
                }
            }
            
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }
        
                // 5. Library Rows (Slider)
        Rectangle {
            width: parent.width
            height: 185
            color: (activeZone === 1 && activeItemIndex === 4) ? "#30343A" : "transparent"

            Column {
                anchors.fill: parent
                anchors.leftMargin: 50
                anchors.rightMargin: 50
                anchors.topMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 55

                Text {
                    text: "Library Rows: " + libraryRows
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Item {
                    width: parent.width
                    height: 50

                    Item {
                        id: sliderTrackLibrary
                        width: parent.width
                        height: 13
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "#555"
                            radius: 5
                            
                            Rectangle {
                                width: parent.width * ((libraryRows - 3) / 5)
                                height: parent.height
                                color: "#00ACFF"
                                radius: 5
                            }
                        }

                        Rectangle {
                            id: sliderThumbLibrary
                            width: 60
                            height: 60
                            radius: 60
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (parent.width * ((libraryRows - 3) / 5)) - (width / 2)

                            SequentialAnimation {
                                id: focusAnimLibrary
                                NumberAnimation { target: sliderThumbLibrary; property: "scale"; to: 1.3; duration: 100 }
                                NumberAnimation { target: sliderThumbLibrary; property: "scale"; to: 1.0; duration: 100 }
                            }
                        }
                    }

                    Text {
                        text: "3 ROWS"
                        color: "white"
                        font.pixelSize: 23
                        font.family: bold.name
                        font.bold: true
                        anchors.left: parent.left
                        anchors.top: sliderTrackLibrary.bottom
                        anchors.topMargin: 30
                    }

                    Text {
                        text: "8 ROWS"
                        color: "white"
                        font.pixelSize: 23
                        font.family: bold.name
                        font.bold: true
                        anchors.right: parent.right
                        anchors.top: sliderTrackLibrary.bottom
                        anchors.topMargin: 30
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 4) {
                        var percent = mouseX / width
                        var val = Math.round(3 + percent * 5)
                        libraryRows = Math.max(3, Math.min(8, val))
                    } else {
                        focusAnimLibrary.start()
                        activeZone = 1
                        activeItemIndex = 4
                    }
                }
            }
            
            Rectangle { 
                height: 1; width: parent.width - 100; color: "#333"
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter 
            }
        }

        // 6. Search Rows (Slider)
        Rectangle {
            width: parent.width
            height: 185
            color: (activeZone === 1 && activeItemIndex === 5) ? "#30343A" : "transparent"

            Column {
                anchors.fill: parent
                anchors.leftMargin: 50
                anchors.rightMargin: 50
                anchors.topMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 55

                Text {
                    text: "Search Rows: " + searchRows
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Item {
                    width: parent.width
                    height: 50

                    Item {
                        id: sliderTrackSearch
                        width: parent.width
                        height: 13
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "#555"
                            radius: 5
                            
                            Rectangle {
                                width: parent.width * ((searchRows - 3) / 5)
                                height: parent.height
                                color: "#00ACFF"
                                radius: 5
                            }
                        }

                        Rectangle {
                            id: sliderThumbSearch
                            width: 60
                            height: 60
                            radius: 60
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (parent.width * ((searchRows - 3) / 5)) - (width / 2)

                            SequentialAnimation {
                                id: focusAnimSearch
                                NumberAnimation { target: sliderThumbSearch; property: "scale"; to: 1.3; duration: 100 }
                                NumberAnimation { target: sliderThumbSearch; property: "scale"; to: 1.0; duration: 100 }
                            }
                        }
                    }

                    Text {
                        text: "3 ROWS"
                        color: "white"
                        font.pixelSize: 23
                        font.family: bold.name
                        font.bold: true
                        anchors.left: parent.left
                        anchors.top: sliderTrackSearch.bottom
                        anchors.topMargin: 30
                    }

                    Text {
                        text: "8 ROWS"
                        color: "white"
                        font.pixelSize: 23
                        font.family: bold.name
                        font.bold: true
                        anchors.right: parent.right
                        anchors.top: sliderTrackSearch.bottom
                        anchors.topMargin: 30
                    }
                }
            }

            // Внутри Search Rows (Rectangle №6)
MouseArea {
    anchors.fill: parent
    onClicked: {
        // БЫЛО 6, СТАЛО 5
        if (activeZone === 1 && activeItemIndex === 5) { 
            var percent = mouseX / width
            var val = Math.round(3 + percent * 5)
            searchRows = Math.max(3, Math.min(8, val))
        } else {
            focusAnimSearch.start()
            activeZone = 1
            activeItemIndex = 5 // СТАЛО 5
        }
    }
}

            
            Rectangle { 
                height: 1; width: parent.width - 100; color: "#333"
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter 
            }
        }

        // 7. Game Launching Animation (Switch)
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 6) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text {
                    text: "Game Launching Animation"
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Text {
                    text: "Enable animation when launching a game."
                    color: "lightgray"
                    font.pixelSize: 25
                    font.family: bold.name
                }
            }

            Rectangle {
                width: 72
                height: 44
                radius: 44
                color: gameLaunchingAnimation ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 6) ? "gray" : "transparent"
                border.width: 6 
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44
                    height: 44
                    radius: 44
                    color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 6) ? "gray" : "transparent"
                    border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: gameLaunchingAnimation ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 6) {
                        gameLaunchingAnimation = !gameLaunchingAnimation
                    } else {
                        activeZone = 1
                        activeItemIndex = 6
                    }
                }
            }
            
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }
}
    }
}