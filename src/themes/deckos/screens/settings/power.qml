import QtQuick 2.0

Item {
    id: powerPage
    anchors.fill: parent

    // Состояние настройки
    property bool showBatteryPercent: api.memory.has("showBatteryPercent") ? api.memory.get("showBatteryPercent") : true
    property int activeItemIndex: 0
    property int maxItemIndex: 0

    onShowBatteryPercentChanged: api.memory.set("showBatteryPercent", showBatteryPercent)
    
    property bool sliderActive: false

function handleAccept() {
    showBatteryPercent = !showBatteryPercent
    root.showBatteryPercent = showBatteryPercent
}

function handleLeft() {}
function handleRight() {}
function handleCancel() {}

    Text {
        id: pageTitle
        text: "Power"
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

        // Настройка: Show battery percent
        Rectangle {
            width: parent.width
            height: 130
            color: (activeZone === 1 && activeItemIndex === 0) ? "#30343A" : "transparent"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text {
                    text: "Show battery percent"
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Text {
                    text: "Show battery percents on Top Bar"
                    color: "lightgray"
                    font.pixelSize: 25
                    font.family: bold.name
                }
            }

            Rectangle {
                width: 72
                height: 44
                radius: 44
                color: showBatteryPercent ? "#00ACFF" : "#31343B"
                border.color: (activeZone === 1 && activeItemIndex === 0) ? "gray" : "transparent"
                border.width: 6 
                anchors.right: parent.right
                anchors.rightMargin: 50
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 44
                    height: 44
                    radius: 44
                    color: "white"
                    border.color: (activeZone === 1 && activeItemIndex === 0) ? "gray" : "transparent"
                    border.width: 3 
                    anchors.verticalCenter: parent.verticalCenter
                    x: showBatteryPercent ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 0) {
                        showBatteryPercent = !showBatteryPercent
                        // Обновляем глобальное свойство в корне для мгновенного эффекта
                        root.showBatteryPercent = showBatteryPercent 
                    } else {
                        activeZone = 1
                        activeItemIndex = 0
                    }
                }
            }
            
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
