import QtQuick 2.0

Item {
    id: highContrastPage
    anchors.fill: parent

    property bool highContrastHome: api.memory.has("highContrastHome") ? api.memory.get("highContrastHome") : false
    property bool highContrastGameMenu: api.memory.has("highContrastGameMenu") ? api.memory.get("highContrastGameMenu") : false
    property bool highContrastLogo: api.memory.has("highContrastLogo") ? api.memory.get("highContrastLogo") : false
    property bool highContrastBottomBar: api.memory.has("highContrastBottomBar") ? api.memory.get("highContrastBottomBar") : false
    property int activeItemIndex: 0
    property int maxItemIndex: 3

    onHighContrastHomeChanged: api.memory.set("highContrastHome", highContrastHome)
    onHighContrastGameMenuChanged: api.memory.set("highContrastGameMenu", highContrastGameMenu)
    onHighContrastLogoChanged: api.memory.set("highContrastLogo", highContrastLogo)
    onHighContrastBottomBarChanged: api.memory.set("highContrastBottomBar", highContrastBottomBar)
    
    property bool sliderActive: false  // для совместимости, не используется

function handleAccept() {
    if (activeItemIndex === 0) highContrastHome = !highContrastHome
    else if (activeItemIndex === 1) highContrastGameMenu = !highContrastGameMenu
    else if (activeItemIndex === 2) highContrastLogo = !highContrastLogo
    else if (activeItemIndex === 3) highContrastBottomBar = !highContrastBottomBar
}

function handleLeft() {}
function handleRight() {}
function handleCancel() {}

    Text {
        id: pageTitle
        text: "High Contrast"
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

    Column {
        anchors.top: titleDivider.bottom
        anchors.topMargin: 30 
        width: parent.width
        spacing: 0

        // 1. High Contrast Home Page
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 0) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text { text: "High Contrast Home Page"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                Text { text: "Remove background image and gradients on Home screen."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
            }

            Rectangle {
                width: 72; height: 44; radius: 44
                color: highContrastHome ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 0) ? "gray" : "transparent"; border.width: 6 
                anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44; height: 44; radius: 44; color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 0) ? "gray" : "transparent"; border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: highContrastHome ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 0) {
                        highContrastHome = !highContrastHome
                        if (typeof theme !== "undefined") theme.highContrastHome = highContrastHome
                    } else { activeZone = 1; activeItemIndex = 0 }
                }
            }
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // 2. High Contrast Game Menu
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 1) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text { text: "High Contrast Game Menu"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                Text { text: "Remove background image in Game Menu."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
            }

            Rectangle {
                width: 72; height: 44; radius: 44
                color: highContrastGameMenu ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 1) ? "gray" : "transparent"; border.width: 6 
                anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44; height: 44; radius: 44; color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 1) ? "gray" : "transparent"; border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: highContrastGameMenu ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 1) {
                        highContrastGameMenu = !highContrastGameMenu
                        if (typeof theme !== "undefined") theme.highContrastGameMenu = highContrastGameMenu
                    } else { activeZone = 1; activeItemIndex = 1 }
                }
            }
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // 3. High Contrast Logo
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 2) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text { text: "High Contrast Logo"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                Text { text: "Remove game logos to improve interface readability."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
            }

            Rectangle {
                width: 72; height: 44; radius: 44
                color: highContrastLogo ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 2) ? "gray" : "transparent"; border.width: 6 
                anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44; height: 44; radius: 44; color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 2) ? "gray" : "transparent"; border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: highContrastLogo ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 2) {
                        highContrastLogo = !highContrastLogo
                        if (typeof theme !== "undefined") theme.highContrastLogo = highContrastLogo
                    } else { activeZone = 1; activeItemIndex = 2 }
                }
            }
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // 4. High Contrast Bottom Bar
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 3) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text { text: "High Contrast Bottom Bar"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                Text { text: "Apply high contrast solid background for the bottom navigation bar."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
            }

            Rectangle {
                width: 72; height: 44; radius: 44
                color: highContrastBottomBar ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 3) ? "gray" : "transparent"; border.width: 6 
                anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44; height: 44; radius: 44; color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 3) ? "gray" : "transparent"; border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: highContrastBottomBar ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 3) {
                        highContrastBottomBar = !highContrastBottomBar
                        if (typeof theme !== "undefined") theme.highContrastBottomBar = highContrastBottomBar
                    } else { activeZone = 1; activeItemIndex = 3 }
                }
            }
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
