import QtQuick 2.0

Item {
    id: controllerPage
    anchors.fill: parent

    property int activeItemIndex: 0
    
    // Переменная для имитации подключения (поменяй на false, чтобы увидеть экран отключения)
    property bool isControllerConnected: Internal.gamepad.devices.count > 0 || Qt.platform.os === "android" // DECKOS: was always true
    readonly property string padName: Internal.gamepad.devices.count > 0 ? Internal.gamepad.devices.get(0).name : "Built-in controls" 
    property int maxItemIndex: 4 // DECKOS: + shortcuts editor
    
    // Инициализация состояний из встроенного JSON-хранилища
    property bool nintendoLayout: api.memory.has("nintendoLayout") ? api.memory.get("nintendoLayout") : false
    property bool universalIcons: api.memory.has("universalIcons") ? api.memory.get("universalIcons") : false

    onNintendoLayoutChanged: api.memory.set("nintendoLayout", nintendoLayout)
    onUniversalIconsChanged: api.memory.set("universalIcons", universalIcons)
    
    function handleAccept() {
    if (activeItemIndex === 1) nintendoLayout = !nintendoLayout
    else if (activeItemIndex === 2) universalIcons = !universalIcons
    else if (activeItemIndex === 3) editor.setSource("qrc:/frontend/menu/settings/GamepadEditor.qml") // DECKOS
    else if (activeItemIndex === 4) editor.setSource("qrc:/frontend/menu/settings/KeyEditor.qml") // DECKOS
}
function handleLeft() {}
function handleRight() {}
function handleCancel() {}

    Text {
        id: pageTitle
        text: "Controller"
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
        anchors.topMargin: 20 // Взято из эталона (было 25)
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // ==========================================
    // ЕСЛИ КОНТРОЛЛЕР ОТКЛЮЧЕН
    // ==========================================
    Column {
        anchors.centerIn: parent
        spacing: 30 // Выровнял под общий spacing эталона
        visible: !isControllerConnected

        Text {
            text: "G" // Иконка геймпада
            color: "grey"
            font.pixelSize: 100
            font.family: icons.name
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "Controller is not connected"
            color: "grey"
            font.pixelSize: 30
            font.family: bold.name
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ==========================================
    // ЕСЛИ КОНТРОЛЛЕР ПОДКЛЮЧЕН
    // ==========================================
    Item {
        anchors.top: titleDivider.bottom
        anchors.topMargin: 30 // Взято из эталона
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: isControllerConnected

        // Верхняя плашка с названием геймпада
        Rectangle {
            id: activeControllerBadge
            width: 400
            height: 85
            radius: 50
            color: "#31343B"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10

            Row {
                anchors.centerIn: parent
                spacing: 15
                Text { text: "G"; font.family: icons.name; font.pixelSize: 45; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: controllerPage.padName /* DECKOS: was "Pegasus Controller" */; color: "white"; font.pixelSize: 30; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Column {
            anchors.top: activeControllerBadge.bottom
            anchors.topMargin: 30 // Причесал под эталон
            width: parent.width
            spacing: 0

            // 1. Controller Name (Только отображение)
            Rectangle {
                width: parent.width
                height: 130 // Выровнял под общий height эталона
                color: (activeZone === 1 && activeItemIndex === 0) ? "#30343A" : "transparent"

                Text { anchors.left: parent.left; anchors.leftMargin: 50; anchors.verticalCenter: parent.verticalCenter; text: "Controller Name"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                
                Rectangle {
                    width: 450; height: 65; radius: 3; color: "#2A2E35"
                    anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter
                    Text { text: controllerPage.padName /* DECKOS: was "Pegasus Controller" */; color: "grey"; font.pixelSize: 30; font.family: bold.name; anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea { anchors.fill: parent; onClicked: { activeZone = 1; activeItemIndex = 0 } }
                Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
            }

            // 2. Nintendo Layout (Switch)
            Rectangle {
                width: parent.width
                height: 130
                color: (activeZone === 1 && activeItemIndex === 1) ? "#30343A" : "transparent"

                Column {
                    anchors.left: parent.left; anchors.leftMargin: 50; anchors.verticalCenter: parent.verticalCenter; spacing: 30
                    Row {
                        spacing: 20
                        Text { text: "s"; font.family: icons.name; font.pixelSize: 30; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Use Nintendo Layout"; color: "white"; font.pixelSize: 30; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: "Swaps the A/B and X/Y buttons for this controller."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
                }

                Rectangle {
                    width: 72; height: 44; radius: 44; color: nintendoLayout ? "#00ACFF" : "#31343B"
                    border.color: (activeZone === 1 && activeItemIndex === 1) ? "gray" : "transparent"; border.width: 6 
                    anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 44; height: 44; radius: 44; color: "white"
                        border.color: (activeZone === 1 && activeItemIndex === 1) ? "gray" : "transparent"; border.width: 3 
                        anchors.verticalCenter: parent.verticalCenter
                        x: nintendoLayout ? parent.width - width : 0
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (activeZone === 1 && activeItemIndex === 1) {
                            nintendoLayout = !nintendoLayout
                            if (typeof theme !== "undefined") theme.nintendoLayout = nintendoLayout
                        } else { activeZone = 1; activeItemIndex = 1 }
                    }
                }
                Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
            }

            // 3. Universal Icons (Switch)
            Rectangle {
                width: parent.width
                height: 130
                color: (activeZone === 1 && activeItemIndex === 2) ? "#30343A" : "transparent"

                Column {
                    anchors.left: parent.left; anchors.leftMargin: 50; anchors.verticalCenter: parent.verticalCenter; spacing: 30
                    Row {
                        spacing: 20
                        Text { text: "U"; font.pixelSize: 30; font.family: icons.name; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Universal face button icons"; color: "white"; font.pixelSize: 30; font.family: bold.name; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: "Face button icons will be replaced with universal ones."; color: "lightgray"; font.pixelSize: 25; font.family: bold.name }
                }

                Rectangle {
                    width: 72; height: 44; radius: 44; color: universalIcons ? "#00ACFF" : "#31343B"
                    border.color: (activeZone === 1 && activeItemIndex === 2) ? "gray" : "transparent"; border.width: 6 
                    anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 44; height: 44; radius: 44; color: "white"
                        border.color: (activeZone === 1 && activeItemIndex === 2) ? "gray" : "transparent"; border.width: 3 
                        anchors.verticalCenter: parent.verticalCenter
                        x: universalIcons ? parent.width - width : 0
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (activeZone === 1 && activeItemIndex === 2) {
                            universalIcons = !universalIcons
                            if (typeof theme !== "undefined") theme.universalIcons = universalIcons
                        } else { activeZone = 1; activeItemIndex = 2 }
                    }
                }
                Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
            }

            // 4. Test Device Input (Button)
            Rectangle {
                width: parent.width
                height: 85 // Выровнял под общий height эталона
                color: (activeZone === 1 && activeItemIndex === 3) ? "#30343A" : "transparent"

                Text { anchors.left: parent.left; anchors.leftMargin: 50; anchors.verticalCenter: parent.verticalCenter; text: "Test and remap buttons" /* DECKOS: was "Test device input" */; color: "white"; font.pixelSize: 30; font.family: bold.name }
                
                Rectangle {
                    width: 280; height: 65; radius: 3
                    color: (activeZone === 1 && activeItemIndex === 3) ? "white" : "#32353C"
                    anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter
                    
                    Text { 
                        text: "Begin test"
                        color: (activeZone === 1 && activeItemIndex === 3) ? "black" : "white"
                        font.pixelSize: 30; font.family: bold.name; anchors.centerIn: parent 
                    }
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: { 
                        if (activeZone === 1 && activeItemIndex === 3) {
                            editor.setSource("qrc:/frontend/menu/settings/GamepadEditor.qml") // DECKOS
                        } else {
                            activeZone = 1; activeItemIndex = 3 
                        }
                    } 
                }
                Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
            }
            // DECKOS: 5. keyboard and controller shortcuts (Pegasus's key editor)
            Rectangle {
                width: parent.width
                height: 85
                color: (activeZone === 1 && activeItemIndex === 4) ? "#30343A" : "transparent"

                Text { anchors.left: parent.left; anchors.leftMargin: 50; anchors.verticalCenter: parent.verticalCenter; text: "Button shortcuts"; color: "white"; font.pixelSize: 30; font.family: bold.name }

                Rectangle {
                    width: 280; height: 65; radius: 3
                    color: (activeZone === 1 && activeItemIndex === 4) ? "white" : "#32353C"
                    anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "Edit"
                        color: (activeZone === 1 && activeItemIndex === 4) ? "black" : "white"
                        font.pixelSize: 30; font.family: bold.name; anchors.centerIn: parent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (activeZone === 1 && activeItemIndex === 4) editor.setSource("qrc:/frontend/menu/settings/KeyEditor.qml")
                        else { activeZone = 1; activeItemIndex = 4 }
                    }
                }
                Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }

    // DECKOS: Pegasus's gamepad tester/remapper and shortcut editor, shown over this page
    Loader {
        id: editor
        anchors.fill: parent
        z: 100
        onLoaded: item.forceActiveFocus()
    }
    Connections {
        target: editor.item
        function onClose() { editor.source = ""; goToZone(1) }
    }
}
