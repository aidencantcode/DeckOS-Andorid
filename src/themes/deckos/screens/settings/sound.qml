import QtQuick 2.0

Item {
    id: soundPage
    anchors.fill: parent

    // Инициализация состояний из встроенного JSON-хранилища
    property real interfaceVolume: api.memory.has("interfaceVolume") ? api.memory.get("interfaceVolume") : 1.0
    property bool interfaceSoundEnabled: api.memory.has("interfaceSoundEnabled") ? api.memory.get("interfaceSoundEnabled") : true
    property int activeItemIndex: 0
    property int maxItemIndex: 1

    // Автоматическое сохранение в JSON при изменениях
    onInterfaceVolumeChanged: api.memory.set("interfaceVolume", interfaceVolume)
    onInterfaceSoundEnabledChanged: api.memory.set("interfaceSoundEnabled", interfaceSoundEnabled)
    
    property bool sliderActive: false

function handleAccept() {
    if (sliderActive) {
        sliderActive = false
    } else {
        if (activeItemIndex === 1) {
            sliderActive = true
            focusAnim.start()   // запуск анимации ползунка
        } else if (activeItemIndex === 0) {
            interfaceSoundEnabled = !interfaceSoundEnabled
        }
    }
}

function handleLeft() {
    if (sliderActive) {
        interfaceVolume = Math.max(0, interfaceVolume - 0.05)
        if (interfaceVolume > 0) interfaceSoundEnabled = true
        else interfaceSoundEnabled = false
    }
}

function handleRight() {
    if (sliderActive) {
        interfaceVolume = Math.min(1, interfaceVolume + 0.05)
        if (interfaceVolume > 0) interfaceSoundEnabled = true
    }
}

function handleCancel() {
    if (sliderActive) sliderActive = false
}

    Text {
        id: pageTitle
        text: "Sound"
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

        // 1. Interface Sound (Switch)
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
                    text: "Interface Sound"
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Text {
                    text: "Enable or disable UI navigation sounds."
                    color: "lightgray"
                    font.pixelSize: 25
                    font.family: bold.name
                }
            }

            Rectangle {
                width: 72
                height: 44
                radius: 44
                color: interfaceSoundEnabled ? "#00ACFF" : "#31343B"
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
                    x: interfaceSoundEnabled ? parent.width - width : 0
                    Behavior on x { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 0) {
                        interfaceSoundEnabled = !interfaceSoundEnabled
                        
                        // Связка с ползунком громкости
                        if (!interfaceSoundEnabled) {
                            interfaceVolume = 0.0
                        } else if (interfaceVolume === 0.0) {
                            interfaceVolume = 1.0 // Возвращаем звук при включении переключателя
                        }
                    } else {
                        activeZone = 1
                        activeItemIndex = 0
                    }
                }
            }
            
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // 2. Volume (Slider)
        Rectangle {
            width: parent.width
            height: 185
            color: (activeZone === 1 && activeItemIndex === 1) ? "#30343A" : "transparent"

            Column {
                anchors.fill: parent
                anchors.leftMargin: 50
                anchors.rightMargin: 50
                anchors.topMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 35

                Text {
                    text: "Volume"
                    color: "white"
                    font.pixelSize: 30
                    font.family: bold.name
                }

                Item {
                    width: parent.width
                    height: 40

                    Item {
                        id: sliderTrack
                        width: parent.width
                        height: 13
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "#555"
                            radius: 5
                            
                            Rectangle {
                                width: parent.width * interfaceVolume
                                height: parent.height
                                color: "#00ACFF"
                                radius: 5
                            }
                        }

                        Rectangle {
                            id: sliderThumb
                            width: 60
                            height: 60
                            radius: 60
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (parent.width * interfaceVolume) - (width / 2)

                            property bool isFocused: (activeZone === 1 && activeItemIndex === 1)
                         
                            SequentialAnimation {
                                id: focusAnim
                                NumberAnimation { target: sliderThumb; property: "scale"; to: 1.3; duration: 100 }
                                NumberAnimation { target: sliderThumb; property: "scale"; to: 1.0; duration: 100 }
                            }
                        }
                    }

                    Text {
                        text: "MINIMAL VOLUME"
                        color: "white"
                        font.pixelSize: 23
                        font.family: bold.name
                        font.bold: true
                        anchors.left: parent.left
                        anchors.top: sliderTrack.bottom
                        anchors.topMargin: 33
                    }

                    Text {
                        text: "MAXIMUM VOLUME"
                        color: "white"
                        font.pixelSize: 23
                        font.family: bold.name
                        font.bold: true
                        anchors.right: parent.right
                        anchors.top: sliderTrack.bottom
                        anchors.topMargin: 33
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (activeZone === 1 && activeItemIndex === 1) {
                        var newVolume = mouseX / width
                        interfaceVolume = Math.max(0, Math.min(1, newVolume))
                        
                        // Связка с переключателем
                        if (interfaceVolume > 0) {
                            interfaceSoundEnabled = true
                        } else {
                            interfaceSoundEnabled = false
                        }
                    } else {
                        focusAnim.start()
                        activeZone = 1
                        activeItemIndex = 1
                    }
                }
            }
            
            Rectangle { height: 1; width: parent.width - 100; color: "#333"; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
