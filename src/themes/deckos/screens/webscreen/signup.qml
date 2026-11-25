import QtQuick 2.15
import ".." // DECKOS: ProfileBadge
import "../settings/parts" // DECKOS: SteamSpinner
import QtGraphicalEffects 1.15
import QtQuick.Layouts 1.15

FocusScope {
    id: root
    anchors.fill: parent
    focus: true
    

    readonly property color focusColor: "#ffffff"
    readonly property color defaultBorder: "transparent"
    readonly property color bgColor: "#0F1318" 
    readonly property color inputBgDark: "#31343B"
    readonly property color buttonBg: "#31343B"
    readonly property color textColor: "#dcdedf"
    readonly property color accentColor: "#1A9EFF"

    property real topH: 95
    property var theme
    
    property int focusZone: 1
    property bool closeMenuVisible: false
    property int nextPageIndex: 0
    
    property bool keyboardOpen: false
    property int activeInput: 0 // 1 = Имя пользователя, 2 = Пароль
    
    // Подтягиваем данные из theme.qml
    property string usernameStr: theme ? theme.savedUsername : ""
    property string passwordStr: theme ? theme.savedApiKey : ""
    
    // Скрытый помощник для работы с буфером обмена
    TextEdit {
        id: clipboardHelper
        visible: false
        function getClipboard() {
            text = "";
            paste();
            return text;
        }
    }

    function openKeyboard(type) {
        activeInput = type;
        keyboardOpen = true;
        keyboardContainer.forceActiveFocus();
    }

    // DECKOS: Sign in checks the account with RetroAchievements first (deckos.ra.verifyAccount) and says
    // whether it worked; StMini saved whatever was typed without a word
    property string checkState: "" // "", "checking", "ok", "failed"
    property string checkMessage: ""
    readonly property var raService: (typeof deckos !== "undefined" && deckos) ? deckos.ra : null

    function saveCredentials() {
        if (!theme || checkState === "checking") return
        theme.rememberMe = rememberMeToggle.checked
        if (!rememberMeToggle.checked) { // StMini: signing in without "Remember me" forgets the account
            theme.savedUsername = ""
            theme.savedApiKey = ""
            checkState = "ok"
            checkMessage = "Signed out of RetroAchievements"
            leaveTimer.start()
            return
        }
        if (!raService) { // no backend (shouldn't happen): keep StMini's behaviour
            theme.savedUsername = root.usernameStr
            theme.savedApiKey = root.passwordStr
            return
        }
        checkState = "checking"
        checkMessage = "Checking with RetroAchievements…"
        raService.verifyAccount(root.usernameStr, root.passwordStr)
    }

    Connections {
        target: root.raService
        function onAccountChecked(ok, user, picture, message) {
            if (root.checkState !== "checking") return
            if (!ok) {
                root.checkState = "failed"
                root.checkMessage = message
                return
            }
            root.checkState = "ok"
            root.checkMessage = "Logged in as " + user
            theme.savedUsername = user
            theme.savedApiKey = root.passwordStr.trim()
            root.usernameStr = user
            leaveTimer.start()
        }
    }
    Timer { id: leaveTimer; interval: 1400; onTriggered: root.leave() }

    // DECKOS: back to where the sign-in was opened from (game page, Settings > Profile) instead of Home
    function leave() {
        var target = theme && theme.loginReturnPage >= 0 ? theme.loginReturnPage : 0
        if (theme) theme.loginReturnPage = -1
        theme.openPage(target)
    }

    ShaderEffectSource {
        id: globalBlurSource
        anchors.fill: parent
        sourceItem: animatedContent
        live: true
        visible: false
        wrapMode: ShaderEffectSource.ClampToEdge
    }

    // Фоновая подложка
    Rectangle {
        id: globalBackground
        anchors.fill: parent
        color: root.bgColor
        z: -100
    }

    // Глобальный перехватчик клавиш
    Keys.onPressed: {
        if (leftBar.isOpen) return;

        // Звук навигации на крестовину
        if (api.keys.isUp(event) || api.keys.isDown(event) || api.keys.isLeft(event) || api.keys.isRight(event)) {
            if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
        }

        if (event.key === Qt.Key_Down && focusZone === 0) {
            goToZone(1);
            event.accepted = true;
        }
        else if (api.keys.isMenu(event) && !root.closeMenuVisible) {
            leftBar.toggle();
            event.accepted = true;
        }
        else if (api.keys.isCancel(event) && !root.closeMenuVisible) {      
            if (focusZone === 1) {
                if (typeof sBack !== "undefined") sBack.play();
                root.leave(); // DECKOS: back where it was opened from
                event.accepted = true;
            }
            else if (focusZone === 0) {
                goToZone(1);
                event.accepted = true;
            }
        }
    }

    function goToZone(zoneIndex) {
        if (zoneIndex < 0) zoneIndex = 0;
        if (zoneIndex > 1) zoneIndex = 1;
        
        topButtonsNames.focus = false;
        mainCanvas.focus = false;
        
        focusZone = zoneIndex;
        
        if (zoneIndex === 0) {
            topButtonsNames.focus = true;
            topButtonsNames.forceActiveFocus();
        }
        else if (zoneIndex === 1) {
            mainCanvas.focus = true;
            mainCanvas.forceActiveFocus();
        }
    }

        Item {
        id: animatedContent
        anchors.fill: parent 

        // Основная рабочая область (Signup)
        FocusScope {
            id: mainCanvas
            anchors.top: parent.top // DECKOS: was topBar1/bottomBar1, ids that never existed (ReferenceError)
            anchors.topMargin: root.topH
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.topH
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width 
            // height follows the anchors
            clip: true

            Component.onCompleted: {
                usernameInput.focus = true;
            }
            
            // Левая половина
            Item {
                id: leftHalf
                width: parent.width * 0.5
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.topMargin: 105

                Column {
                    id: leftContent
                    width: 480
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 35

                    Text {
                        text: "Sign in"
                        color: "white"
                        font.pixelSize: 110
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: typeof extrabold !== 'undefined' ? extrabold.name : ""
                    }

                    Rectangle {
                        id: qrContainer
                        width: 400
                        height: 400
                        color: activeFocus ? "white" : buttonBg
                        anchors.horizontalCenter: parent.horizontalCenter
                        focus: true
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Image {
                            anchors.centerIn: parent
                            width: 330
                            height: 330
                            source: "../../assets/qr.png"
                        }

                        Keys.onPressed: {
                            if (api.keys.isUp(event)) { 
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                root.goToZone(0); 
                                event.accepted = true; 
                            } else if (api.keys.isDown(event)) {
                                createAccountBtn.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isRight(event)) {
                                usernameInput.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                                if (typeof sAccept !== "undefined") sAccept.play();
                                Qt.openUrlExternally("https://retroachievements.org/settings");
                                event.accepted = true;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.goToZone(1);
                                if (!qrContainer.activeFocus) {
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    qrContainer.forceActiveFocus();
                                } else {
                                    if (typeof sAccept !== "undefined") sAccept.play();
                                    Qt.openUrlExternally("https://retroachievements.org/settings");
                                }
                            }
                        }
                    }

                    Text {
                        text: "Scan QR code to find your API Key"
                        color: root.textColor
                        font.pixelSize: 25
                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                        anchors.horizontalCenter: parent.horizontalCenter 
                    }

                    Rectangle {
                        id: createAccountBtn
                        width: 320
                        height: 85
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: (activeFocus) ? root.focusColor : root.buttonBg
                        Behavior on color { ColorAnimation { duration: 150 } }
                        focus: true
                        
                        Text { 
                            anchors.centerIn: parent; text: "Create account"
                            color: (parent.activeFocus) ? "black" : "white"
                            font.pixelSize: 28 
                            font.family: typeof bold !== 'undefined' ? bold.name : ""
                        }

                        Keys.onPressed: {
                            if (api.keys.isUp(event)) {
                                qrContainer.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isRight(event)) {
                                signInBtn.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                                if (typeof sAccept !== "undefined") sAccept.play();
                                Qt.openUrlExternally("https://retroachievements.org/createaccount.php");
                                event.accepted = true;
                            }
                        }

                        MouseArea { 
                            anchors.fill: parent; 
                            hoverEnabled: true; 
                            onClicked: {
                                root.goToZone(1);
                                if (!createAccountBtn.activeFocus) {
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    createAccountBtn.forceActiveFocus();
                                } else {
                                    if (typeof sAccept !== "undefined") sAccept.play();
                                    Qt.openUrlExternally("https://retroachievements.org/createaccount.php");
                                }
                            } 
                        }
                    }
                }
            }

            // Правая половина
            Item {
                id: rightHalf
                width: parent.width * 0.5
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.topMargin: 100

                Column {
                    id: rightContent
                    width: parent.width * 0.78
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 30

                    Text { text: "SIGN IN WITH ACCOUNT NAME"; color: "white"; font.pixelSize: 25; font.family: typeof extrabold !== 'undefined' ? extrabold.name : "" }

                    Rectangle {
                        id: usernameInput
                        width: parent.width 
                        height: 85
                        Behavior on color { ColorAnimation { duration: 150 } }
                        color: (activeFocus || (root.keyboardOpen && root.activeInput === 1)) ? "white" : root.inputBgDark
                        anchors.horizontalCenter: parent.horizontalCenter
                        focus: true
                        clip: true 
                        
                        Item {
                            id: userScrollContent
                            height: parent.height
                            width: parent.width
                            
                            property real cursorLocalX: userCursorProvider.width
                            property real idealX: (parent.width / 2) - cursorLocalX
                            
                            x: Math.min(20, idealX)
                            Behavior on x { NumberAnimation { duration: 100 } } 
                            
                            Text {
                                id: userTextInner
                                anchors.verticalCenter: parent.verticalCenter
                                color: (usernameInput.activeFocus || (root.keyboardOpen && root.activeInput === 1)) ? "black": "white"
                                font.pixelSize: 34
                                font.family: typeof bold !== 'undefined' ? bold.name : ""
                                text: root.usernameStr
                            }

                            Rectangle {
                                width: 3; height: 38
                                color: userTextInner.color
                                visible: root.keyboardOpen && root.activeInput === 1
                                x: userScrollContent.cursorLocalX
                                anchors.verticalCenter: parent.verticalCenter
                                SequentialAnimation on opacity {
                                    running: visible; loops: Animation.Infinite
                                    NumberAnimation { from: 1; to: 0; duration: 500 }
                                    NumberAnimation { from: 0; to: 1; duration: 500 }
                                }
                            }
                            Text { 
                                id: userCursorProvider; visible: false
                                font: userTextInner.font
                                text: root.usernameStr.substring(0, keyboardContainer.cursorPosition)
                            }
                        }

                        Keys.onPressed: {
                            if (api.keys.isUp(event)) {
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                root.goToZone(0); 
                                event.accepted = true; 
                            } else if (api.keys.isDown(event)) {
                                passwordInput.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isLeft(event)) {
                                qrContainer.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                                if (typeof sAccept !== "undefined") sAccept.play();
                                root.openKeyboard(1);
                                event.accepted = true;
                            }
                        }

                        MouseArea { 
                            anchors.fill: parent; 
                            onClicked: {
                                root.goToZone(1);
                                if (!usernameInput.activeFocus) {
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    usernameInput.forceActiveFocus();
                                } else {
                                    if (typeof sAccept !== "undefined") sAccept.play();
                                    root.openKeyboard(1);
                                }
                            } 
                        }                    
                    }

                    Text { text: "API KEY"; color: "white"; font.pixelSize: 25; font.family: typeof extrabold !== 'undefined' ? extrabold.name : "" }

                    Rectangle {
                        id: passwordInput
                        width: parent.width 
                        height: 85
                        Behavior on color { ColorAnimation { duration: 150 } }
                        color: (activeFocus || (root.keyboardOpen && root.activeInput === 2)) ? "white" : root.inputBgDark                        
                        anchors.horizontalCenter: parent.horizontalCenter
                        focus: true
                        clip: true 
                        
                        Item {
                            id: passScrollContent
                            height: parent.height
                            width: parent.width
                            
                            property real cursorLocalX: passCursorProvider.width
                            property real idealX: (parent.width / 2) - cursorLocalX
                            
                            x: Math.min(20, idealX)
                            Behavior on x { NumberAnimation { duration: 100 } } 
                            
                            Text {
                                id: passTextInner
                                anchors.verticalCenter: parent.verticalCenter
                                color: (passwordInput.activeFocus || (root.keyboardOpen && root.activeInput === 2)) ? "black": "white" 
                                font.pixelSize: 34
                                font.family: typeof bold !== 'undefined' ? bold.name : ""
                                text: root.passwordStr.replace(/./g, '•')
                            }

                            Rectangle {
                                width: 3; height: 38
                                color: passTextInner.color
                                visible: root.keyboardOpen && root.activeInput === 2
                                x: passScrollContent.cursorLocalX
                                anchors.verticalCenter: parent.verticalCenter
                                SequentialAnimation on opacity {
                                    running: visible; loops: Animation.Infinite
                                    NumberAnimation { from: 1; to: 0; duration: 500 }
                                    NumberAnimation { from: 0; to: 1; duration: 500 }
                                }
                            }
                            Text { 
                                id: passCursorProvider; visible: false
                                font: passTextInner.font
                                text: root.passwordStr.substring(0, keyboardContainer.cursorPosition).replace(/./g, '•')
                            }
                        }

                        Keys.onPressed: {
                            if (api.keys.isUp(event)) {
                                usernameInput.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isDown(event)) {
                                rememberMeToggle.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isLeft(event)) {
                                qrContainer.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                                if (typeof sAccept !== "undefined") sAccept.play();
                                root.openKeyboard(2);
                                event.accepted = true;
                            }
                        }

                        MouseArea { 
                            anchors.fill: parent; 
                            onClicked: {
                                root.goToZone(1);
                                if (!passwordInput.activeFocus) {
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    passwordInput.forceActiveFocus();
                                } else {
                                    if (typeof sAccept !== "undefined") sAccept.play();
                                    root.openKeyboard(2);
                                }
                            } 
                        }
                    }

                    Item {
                        id: rememberMeToggle
                        width: parent.width
                        height: 55
                        focus: true
                        property bool checked: theme ? theme.rememberMe : true

                        Text { 
                            text: "Remember me" 
                            color: "white" 
                            font.family: typeof bold !== 'undefined' ? bold.name : ""
                            font.pixelSize: 30 
                            anchors.left: parent.left 
                            anchors.verticalCenter: parent.verticalCenter 
                        }

                        Rectangle {
                            id: switchRoot
                            width: 72
                            height: 44
                            radius: 44
                            color: rememberMeToggle.checked ? "#00ACFF" : "#31343B"
                            border.color: parent.activeFocus ? "gray" : "transparent"
                            border.width: 6 
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: switchHandle
                                width: 44
                                height: 44
                                radius: 44
                                border.color: rememberMeToggle.activeFocus ? "gray" : "transparent"
                                border.width: 3 
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                                x: rememberMeToggle.checked ? parent.width - width : 0
                                Behavior on x { NumberAnimation { duration: 150 } }
                            }
                        }

                        Keys.onPressed: {
                            if (api.keys.isUp(event)) {
                                passwordInput.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isDown(event)) {
                                signInBtn.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isLeft(event)) {
                                qrContainer.forceActiveFocus();
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                event.accepted = true;
                            } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                                if (typeof sAccept !== "undefined") sAccept.play();
                                rememberMeToggle.checked = !rememberMeToggle.checked;
                                event.accepted = true;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.goToZone(1);
                                if (!parent.activeFocus) {
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    parent.forceActiveFocus();
                                } else {
                                    if (typeof sAccept !== "undefined") sAccept.play();
                                    parent.checked = !parent.checked;
                                }
                            }
                        }
                    }

                    Rectangle { height: 1; width: parent.width; color: "#333"; anchors.horizontalCenter: parent.horizontalCenter }

                    Row {
                        width: parent.width; spacing: 25
                        Rectangle {
                            id: signInBtn
                            width: (parent.width - 20) / 2; height: 85; 
                            color: (activeFocus || maSignIn.containsMouse) ? root.focusColor : root.buttonBg
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            Text { 
                                anchors.centerIn: parent; text: "Sign in"
                                color: (parent.activeFocus || maSignIn.containsMouse) ? "black" : "white"
                                font.pixelSize: 28 
                                font.family: typeof bold !== 'undefined' ? bold.name : ""
                            }

                            Keys.onPressed: {
                                if (api.keys.isUp(event)) {
                                    rememberMeToggle.forceActiveFocus();
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    event.accepted = true;
                                } else if (api.keys.isRight(event)) {
                                    cancelBtn.forceActiveFocus();
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    event.accepted = true;
                                } else if (api.keys.isLeft(event)) {
                                    createAccountBtn.forceActiveFocus();
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    event.accepted = true;
                                } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                                    if (typeof sAccept !== "undefined") sAccept.play();
                                    root.saveCredentials(); 
                                    event.accepted = true;
                                }
                            }

                            MouseArea { 
                                id: maSignIn; 
                                anchors.fill: parent; 
                                hoverEnabled: true; 
                                onClicked: {
                                    root.goToZone(1);
                                    if (!signInBtn.activeFocus) {
                                        if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                        signInBtn.forceActiveFocus();
                                    } else {
                                        if (typeof sAccept !== "undefined") sAccept.play();
                                        root.saveCredentials(); 
                                    }
                                } 
                            }
                        }
                        
                        Rectangle {
                            id: cancelBtn
                            width: (parent.width - 20) / 2; height: 85;
                            color: (activeFocus || maCancel.containsMouse) ? root.focusColor : root.buttonBg
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            Text { 
                                anchors.centerIn: parent; text: "Cancel"
                                color: (parent.activeFocus || maCancel.containsMouse) ? "black" : "white"
                                font.pixelSize: 28 
                                font.family: typeof bold !== 'undefined' ? bold.name : ""
                            }

                            Keys.onPressed: {
                                if (api.keys.isUp(event)) {
                                    rememberMeToggle.forceActiveFocus();
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    event.accepted = true;
                                } else if (api.keys.isLeft(event)) {
                                    signInBtn.forceActiveFocus();
                                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                    event.accepted = true;
                                } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                                    if (typeof sBack !== "undefined") sBack.play();
                                    root.leave(); // DECKOS
                                    event.accepted = true;
                                }
                            }

                            MouseArea { 
                                id: maCancel; 
                                anchors.fill: parent; 
                                hoverEnabled: true; 
                                onClicked: {
                                    root.goToZone(1);
                                    if (!cancelBtn.activeFocus) {
                                        if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                                        cancelBtn.forceActiveFocus();
                                    } else {
                                        if (typeof sBack !== "undefined") sBack.play();
                                        root.leave(); // DECKOS
                                    }
                                } 
                            }
                        }
                    }

                    // DECKOS: the result of Sign in
                    Row {
                        visible: root.checkState !== ""
                        height: 48
                        spacing: 16
                        SteamSpinner {
                            visible: root.checkState === "checking"
                            size: 40
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            visible: root.checkState === "ok" || root.checkState === "failed"
                            text: root.checkState === "ok" ? "✓" : "✕"
                            color: root.checkState === "ok" ? "#59bf40" : "#e5534b"
                            font.pixelSize: 38
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.checkMessage
                            color: root.checkState === "failed" ? "#ff8a80" : "white"
                            font.pixelSize: 26
                            font.family: typeof bold !== 'undefined' ? bold.name : ""
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }


    /* ================= TOP BAR ================= */
    Rectangle {
        id: topBar
        anchors.left: root.left   
        anchors.right: root.right 
        anchors.top: parent.top
        height: root.topH
        color: "black"
        z: 10000

        Row {
            id: topButtonsNames
            anchors {
                left: parent.left 
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 15
                leftMargin: 0
            }
            property int currentIndex: 0
            spacing: 0
            focus: false

            Keys.onLeftPressed: if (currentIndex > 0) { currentIndex--; if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); } }
            Keys.onRightPressed: if (currentIndex < 2) { currentIndex++; if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); } }
            
            // ===== 0. SEARCH =====
            Rectangle {
                id: topBtnSearch
                width: topBar.width - (topBtnNet.width + topBarBattery.width + topBtnClock.width + (topButtonsNames.spacing * 3) + (topButtonsNames.anchors.rightMargin * 2))
                height: root.topH
                color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: "¿"
                    font.pixelSize: 35
                    font.family: typeof icons !== 'undefined' ? icons.name : ""
                    color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "black" : "white"
                    
                    readonly property real posRight: topBtnSearch.width - 50
                    readonly property real posLeft: 15
                    x: posRight
                    
                    states: [
                        State {
                            name: "focused"
                            when: topButtonsNames.currentIndex === 0 && root.focusZone === 0
                            PropertyChanges { target: searchIcon; x: posLeft; opacity: 1 }
                        },
                        State {
                            name: "default"
                            when: !(topButtonsNames.currentIndex === 0 && root.focusZone === 0)
                            PropertyChanges { target: searchIcon; x: posRight; opacity: 1 }
                        }
                    ]
                    transitions: [
                        Transition {
                            from: "default"; to: "focused"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x"; to: searchIcon.posRight - 20; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                                }
                                PropertyAction { target: searchIcon; property: "x"; value: searchIcon.posLeft + 20 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x"; to: searchIcon.posLeft; duration: 200; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 1; duration: 200 }
                                }
                            }
                        },
                        Transition {
                            from: "focused"; to: "default"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x"; to: searchIcon.posLeft + 20; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 0; duration: 200 }
                                }
                                PropertyAction { target: searchIcon; property: "x"; value: searchIcon.posRight - 20 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchIcon; property: "x"; to: searchIcon.posRight; duration: 200; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: searchIcon; property: "opacity"; to: 1; duration: 200 }
                                }
                            }
                        }
                    ]
                }
              
                Text {
                    id: searchText
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property real targetX: 15 + 50
                    x: targetX + 20
                    text: "Search games in your Library..."
                    font.pixelSize: 30
                    font.family: typeof bold !== 'undefined' ? bold.name : ""
                    color: (topButtonsNames.currentIndex === 0 && root.focusZone === 0) ? "grey" : "transparent"
                    opacity: 0
                    visible: false

                    states: [
                        State {
                            name: "focused"
                            when: topButtonsNames.currentIndex === 0 && root.focusZone === 0
                            PropertyChanges { target: searchText; x: targetX; opacity: 1; visible: true }
                        }
                    ]
                    transitions: [
                        Transition {
                            from: "*"; to: "focused"
                            SequentialAnimation {
                                PropertyAction { target: searchText; property: "visible"; value: true }
                                PauseAnimation { duration: 150 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchText; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchText; property: "x"; to: targetX; duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        },
                        Transition {
                            from: "focused"; to: "*"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: searchText; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                                    NumberAnimation { target: searchText; property: "x"; to: targetX + 20; duration: 150; easing.type: Easing.InCubic }
                                }
                                PropertyAction { target: searchText; property: "visible"; value: false }
                            }
                        }
                    ]
                }

                Keys.onPressed: {
                    if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                        if (typeof sAccept !== "undefined") sAccept.play();
                        theme.openPage(9);
                        event.accepted = true;
                    }
                }

                MouseArea { 
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        if (root.focusZone === 0 && topButtonsNames.currentIndex === 0) {
                            if (typeof sAccept !== "undefined") sAccept.play();
                            theme.openPage(9)
                        } else {
                            if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); } 
                            root.goToZone(0)
                            topButtonsNames.currentIndex = 0
                        }
                    }
                }
            }

            // ===== 1. NETWORK =====
            Rectangle {
                id: topBtnNet
                width: 72; height: root.topH
                color: (topButtonsNames.currentIndex === 1 && root.focusZone === 0) ? "white" : "transparent"
                border.width: (topButtonsNames.currentIndex === 1 && root.focusZone === 0) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "o"
                    font.pixelSize: 35
                    font.family: typeof icons !== 'undefined' ? icons.name : ""
                    color: (topButtonsNames.currentIndex === 1 && root.focusZone === 0) ? "black" : "white"
                }

                Keys.onPressed: {
                    if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                        if (typeof sAccept !== "undefined") sAccept.play();
                        event.accepted = true;
                    }
                }

                MouseArea { 
                    anchors.fill: parent; 
                    onClicked: if (!root.closeMenuVisible) {
                        if (root.focusZone === 0 && topButtonsNames.currentIndex === 1) {
                            if (typeof sAccept !== "undefined") sAccept.play();
                        } else {
                            if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); } 
                            root.goToZone(0)
                            topButtonsNames.currentIndex = 1
                        }
                    }
                }
            }
            
            // ===== 2. BATTERY =====
            Item {
                id: topBarBattery
                width: (theme && theme.showBatteryPercent) ? 170 : 70 
                height: root.topH

                Rectangle {
                    id: batteryBg
                    anchors.fill: parent
                    color: (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "white" : "transparent"
                    border.width: (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? 2 : 0
                    border.color: "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    id: batteryRow
                    spacing: 5
                    anchors.centerIn: parent

                    function getBatteryIcon() {
                        if (isNaN(api.device.batteryPercent)) return "../../assets/theme-icons/battery" + getSuffix() + ".png";
                        const batteryPercent = api.device.batteryPercent * 100;
                        if (batteryPercent <= 20) return "../../assets/theme-icons/20" + getSuffix() + ".png";
                        else if (batteryPercent <= 40) return "../../assets/theme-icons/40" + getSuffix() + ".png";
                        else if (batteryPercent <= 60) return "../../assets/theme-icons/60" + getSuffix() + ".png";
                        else if (batteryPercent <= 80) return "../../assets/theme-icons/80" + getSuffix() + ".png";
                        else return "../../assets/theme-icons/battery" + getSuffix() + ".png";
                    }

                    function getSuffix() {
                        return (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "B" : "";
                    }

                    Text {
                        text: isNaN(api.device.batteryPercent) ? "N/A" : (api.device.batteryPercent * 100).toFixed(0) + "%"
                        color: (topButtonsNames.currentIndex === 2 && root.focusZone === 0) ? "black" : "white"
                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                        font.pixelSize: 36
                        visible: (theme && theme.showBatteryPercent)
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        width: 57; height: 33
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: batteryBase
                            anchors.fill: parent
                            source: batteryRow.getBatteryIcon()
                            mipmap: true
                        }
                        Image {
                            id: chargingOverlay
                            anchors.fill: parent
                            source: "../../assets/theme-icons/charging" + batteryRow.getSuffix() + ".png"
                            mipmap: true
                            visible: api.device.batteryCharging
                        }
                    }
                }

                Keys.onPressed: {
                    if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
                        if (typeof sAccept !== "undefined") sAccept.play();
                        event.accepted = true;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        if (root.focusZone === 0 && topButtonsNames.currentIndex === 2) {
                            if (typeof sAccept !== "undefined") sAccept.play();
                        } else {
                            if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                            root.goToZone(0)
                            topButtonsNames.currentIndex = 2
                        }
                    }
                }
            }

            // ===== CLOCK =====
            Rectangle {
                id: topBtnClock
                width: (theme && theme.use24HourFormat) ? 130 : 200; height: root.topH
                color: "transparent"
                border.color: "transparent"               

                property string timeFormat: (theme && theme.use24HourFormat) ? "HH:mm" : "hh:mm AP"

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), topBtnClock.timeFormat)
                    font.pixelSize: 35
                    font.family: typeof bold !== 'undefined' ? bold.name : ""
                    color: "white"
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
                }                
                
                onTimeFormatChanged: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
            }
        }
    }

        /* ================= BOTTOM BAR ================= */
    Rectangle {
        id: bottomBar
        width: parent.width
        height: topH
        color: "black"
        z: 10000000
        anchors.bottom: parent.bottom

        Rectangle {
            id: btnMenu
            width: 180; height: parent.height
            anchors.left: parent.left
            anchors.leftMargin: 18
            color: "transparent"

            Row {
                anchors.verticalCenter: parent.verticalCenter 
                spacing: 6
                Text { text: ":"; font.family: typeof icons !== 'undefined' ? icons.name : ""; font.pixelSize: 54; color: "white" }
                Text { 
                    text: root.closeMenuVisible ? "PEGASUS MENU" : "MENU"
                    font.family: typeof bold !== 'undefined' ? bold.name : "" 
                    font.pixelSize: 28 
                    color: "white"
                    y: parent.height * 0.21 
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: if (!root.closeMenuVisible) {
                    leftBar.toggle()
                    leftBar.currentIndex = 1
                    leftBar.updateFocus()
                }
            }
        }

        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.rightMargin: 45 // Увеличил отступ, чтобы кнопка BACK не уходила за экран
            anchors.verticalCenter: parent.verticalCenter
            spacing: 38

            // Возвращенный блок SELECT
            Row {
                spacing: 18
                anchors.verticalCenter: parent.verticalCenter
                Text { 
                    text: (theme && theme.nintendoLayout) ? ((theme && theme.universalIcons) ? "В" : "B") : ((theme && theme.universalIcons) ? "А" : "A")
                    font.family: typeof icons !== 'undefined' ? icons.name : ""
                    font.pixelSize: 53 
                    color: "white"
                    y: parent.height * -0.025
                }
                Text { 
                    text: "SELECT"
                    font.family: typeof bold !== 'undefined' ? bold.name : ""
                    font.pixelSize: 25 
                    color: "white"
                    y: parent.height * 0.23
                }
            }

            Rectangle {
                id: btnBack
                width: 140; height: parent.height
                color: "transparent"
                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Text { 
                        text: (theme && theme.nintendoLayout) ? ((theme && theme.universalIcons) ? "А" : "A") : ((theme && theme.universalIcons) ? "В" : "B")
                        font.family: typeof icons !== 'undefined' ? icons.name : ""
                        font.pixelSize: 53 
                        color: "white"
                        y: parent.height * -0.025
                    }
                    Text { 
                        text: "BACK"
                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                        font.pixelSize: 25 
                        color: "white"
                        y: parent.height * 0.23 
                    }
                }
                MouseArea { 
                    anchors.fill: parent
                    onClicked: {
                        if (focusZone === 1) {
                            if (typeof sBack !== "undefined") sBack.play()
                            theme.openPage(0)
                        } else if (focusZone === 0) {
                            goToZone(1)
                        }
                    }
                }
            }
        }
    }


    /* LEFT BAR ФОН */ 
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

    /* ================= LEFT BAR ================= */
    FocusScope {
        id: leftBar
        width: parent.width
        height: parent.height
        visible: false
        focus: false
        z: 999
        x: leftBar.isOpen ? 0 : -width
        Behavior on x {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        property bool isOpen: false
        property int currentIndex: 0
        property var buttons: []
        
        Keys.onPressed: {
            if (leftBar.isOpen && leftBar.focus) {
                if (event.key === Qt.Key_Up) {
                    if (currentIndex > 0) {
                        currentIndex--
                        updateFocus()
                        event.accepted = true
                        if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                    } else {
                        event.accepted = true
                    }
                }
                else if (event.key === Qt.Key_Down) {
                    if (currentIndex < buttons.length - 1) {
                        currentIndex++
                        updateFocus()
                        event.accepted = true
                        if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                    } else {
                        event.accepted = true
                    }
                }
                else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                    if (typeof sAccept !== "undefined") sAccept.play();
                    if (currentIndex === 7) {
                        toggle()
                        root.closeMenuVisible = true
                        focusTimer.start()
                    } else {
                        theme.openPage(currentIndex)
                        toggle()
                        if (currentIndex === 6 && typeof sShowui !== "undefined") {
                            sShowui.play()
                        }
                    }
                    event.accepted = true
                }
                else if (api.keys.isMenu(event)) {
                    toggle()
                    focusTimer.start()
                    event.accepted = true
                }
                else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
                    if (typeof sBack !== "undefined") sBack.play();
                    toggle()
                    focusTimer.start()
                    event.accepted = true
                }
                else {
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: menuPanel
            width: parent.width * 0.25
            height: parent.height
            color: "#181B20"
            radius: 0
            anchors.left: parent.left
            z: 1000
            x: leftBar.isOpen ? width * 0.2: 0
            opacity: leftBar.isOpen ? 1 : 0
            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 0 } }

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

        Component {
            id: menuButtonComponent
            FocusScope {
                id: buttonScope
                property string title: ""
                property int buttonIndex: 0
                width: menuPanel.width
                height: Math.min(106, menuPanel.height * 0.085) /* DECKOS: was 106 */
                
                property bool isFocused: activeFocus
                
                onIsFocusedChanged: {
                    if (isFocused) {
                        bgColor = "#27303A"
                        textColor = "white"
                    } else {
                        bgColor = "transparent"
                        textColor = "#AAA"
                    }
                }
                
                property color bgColor: "transparent"
                property color textColor: "#AAA"
                property string icon: ""

                Rectangle {
                    anchors.fill: parent
                    color: bgColor
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Item {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            topMargin: 20
                            bottomMargin: 20
                        }
                        width: 11
                        visible: (theme && theme.currentPage === buttonIndex)
                        
                        Rectangle {
                            anchors {
                                right: parent.right
                                top: parent.top
                                bottom: parent.bottom
                            }
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

                        Text {
                            text: icon
                            font.family: typeof icons !== 'undefined' ? icons.name : ""
                            font.pixelSize: menuPanel.width * 0.075
                            color: "white"
                            verticalAlignment: Text.AlignVCenter // DECKOS: was parent.verticalCenter (an anchor line)
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: title
                            font.family: typeof bold !== 'undefined' ? bold.name : ""
                            font.pixelSize: menuPanel.width * 0.075
                            color: "white"
                            verticalAlignment: Text.AlignVCenter // DECKOS: was parent.verticalCenter (an anchor line)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }         

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (leftBar.currentIndex === buttonIndex) {
                            if (typeof sAccept !== "undefined") sAccept.play();
                            if (buttonIndex === 7) {
                                leftBar.toggle()
                                closeMenu.forceActiveFocus()
                                root.closeMenuVisible = true
                            } else {
                                theme.openPage(buttonIndex)
                                leftBar.toggle()
                                if (buttonIndex === 6 && typeof sShowui !== "undefined") {
                                    sShowui.play()
                                }
                            }
                        } else {
                            leftBar.currentIndex = buttonIndex
                            leftBar.updateFocus()
                            if (typeof sNav !== "undefined") sNav.play()
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            var btn1 = menuButtonComponent.createObject(buttonColumn, { "title": "Home", "buttonIndex": 0, "icon": "^" })
            var btn2 = menuButtonComponent.createObject(buttonColumn, { "title": "Library", "buttonIndex": 1, "icon": "L" })
            var btn3 = menuButtonComponent.createObject(buttonColumn, { "title": "Store", "buttonIndex": 2, "icon": "€" })
            var btn4 = menuButtonComponent.createObject(buttonColumn, { "title": "Friends and Chat", "buttonIndex": 3, "icon": "F" })
            var btn5 = menuButtonComponent.createObject(buttonColumn, { "title": "Media", "buttonIndex": 4, "icon": "M" })
            var btn6 = menuButtonComponent.createObject(buttonColumn, { "title": "Downloads", "buttonIndex": 5, "icon": "♠︎" })
            var btn7 = menuButtonComponent.createObject(buttonColumn, { "title": "Settings", "buttonIndex": 6, "icon": "w" })
            var btn8 = menuButtonComponent.createObject(buttonColumn, { "title": "Close", "buttonIndex": 7, "icon": "C" })
            leftBar.buttons = [btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8]
            
            currentIndex = 1
            updateFocus()
        }

        function updateFocus() {
            if (currentIndex >= 0 && currentIndex < buttons.length) {
                buttons[currentIndex].forceActiveFocus()
            }
        }

        function toggle() {
            theme.toggleLeftBar(leftBar);
        }
    }

    /* ================= CLOSE MENU ================= */
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
        property var buttons: [exitButton, cancelButton1]

        Item {
            id: closeMenuOverlay
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
            
            Text {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: -65
                }
                text: "Close"
                color: "white"
                font.pixelSize: 38
                font.family: typeof bold !== 'undefined' ? bold.name : ""
            }
            
            Column {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                spacing: 0
                
                Rectangle {
                    id: exitButton
                    width: parent.width
                    height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 0 ? "#DE3619" : "transparent"
                                  
                    Text {
                        text: "   Exit"
                        color: "white"
                        font.pixelSize: 35
                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                        anchors.verticalCenter: parent.verticalCenter
                    }               
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 0) {
                                closeMenu.currentButtonIndex = 0
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                            } else {
                                if (typeof sAccept !== "undefined") sAccept.play();
                                Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                            }
                        }
                    }
                }
                
                Rectangle {
                    id: cancelButton1
                    width: parent.width
                    height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 1 ? "white" : "transparent"
                    
                    Text {
                        text: "   Cancel"
                        color: closeMenu.currentButtonIndex === 1 ? "black" : "white"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        font.pixelSize: 35
                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 1) {
                                closeMenu.currentButtonIndex = 1
                                if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                            } else {
                                if (typeof sBack !== "undefined") sBack.play();
                                closeMenuVisible = false
                                if (typeof sLeftClose !== "undefined") sLeftClose.play()
                                focusTimer.start()
                            }
                        }
                    }
                }
            }
        }
        
        Keys.onPressed: {
            if (closeMenuVisible) {
                if (event.key === Qt.Key_Up) {
                    if (currentButtonIndex > 0) {
                        currentButtonIndex--
                        if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                    }
                    event.accepted = true
                }
                else if (event.key === Qt.Key_Down) {
                    if (currentButtonIndex < 1) {
                        currentButtonIndex++
                        if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); } 
                    }
                    event.accepted = true
                }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    event.accepted = true
                }
                else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape){
                    if (typeof sBack !== "undefined") sBack.play();
                    closeMenuVisible = false
                    if (typeof sLeftClose !== "undefined") sLeftClose.play()
                    focusTimer.start()
                    event.accepted = true
                }
                else if (api.keys.isMenu(event)) {    
                }
                else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    if (currentButtonIndex === 0) {
                        if (typeof sAccept !== "undefined") sAccept.play();
                        event.accepted = true
                        Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                        return
                    } else if (currentButtonIndex === 1) {
                        if (typeof sBack !== "undefined") sBack.play();
                        closeMenuVisible = false
                        if (typeof sLeftClose !== "undefined") sLeftClose.play()
                        focusTimer.start()
                    }
                    event.accepted = true
                }            
            }
        }
        
        onVisibleChanged: {
            if (visible) {
                currentButtonIndex = 0
                if (typeof sShowui !== "undefined") sShowui.play()
                forceActiveFocus()
            }
        }
    }

    // ===============================
    // === КЛАВИАТУРА ===
    // ===============================
    FocusScope {
        id: keyboardContainer
        anchors.fill: parent
        visible: keyboardOpen
        focus: keyboardOpen
        z: 10000001
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        property int r: 2 
        property int c: 5 
        property bool isCaps: false
        property int cursorPosition: 0
        
        onVisibleChanged: {
            if (visible) {
                opacity = 1;
                kbPanel.anchors.bottomMargin = 0;
                cursorPosition = (root.activeInput === 1) ? root.usernameStr.length : root.passwordStr.length;
            } else {
                opacity = 0;
                kbPanel.anchors.bottomMargin = -kbPanel.height;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (typeof sBack !== "undefined") sBack.play();
                root.keyboardOpen = false;
                root.goToZone(1);
            }
        }

                function processInput(v) {
            if (!v || v === "") return;
            if (v === "Done") {
                // Звук закрытия удален, чтобы не конфликтовал и не дублировался
                root.keyboardOpen = false;
                root.goToZone(1);
                if(root.activeInput === 1) usernameInput.forceActiveFocus();
                if(root.activeInput === 2) passwordInput.forceActiveFocus();
                root.activeInput = 0;
                return;
            }
            
            var cur = (root.activeInput === 1) ? root.usernameStr : root.passwordStr;
            var maxLength = (root.activeInput === 2) ? 32 : 255;
            
            if (v === "paste") {
                var clipboardText = clipboardHelper.getClipboard();
                if (clipboardText) {
                    clipboardText = clipboardText.replace(/[\r\n\t]+/g, "");
                    var availableSpace = Math.max(0, maxLength - cur.length);
                    var textToInsert = clipboardText.substring(0, availableSpace);
                    cur = cur.substring(0, cursorPosition) + textToInsert + cur.substring(cursorPosition);
                    cursorPosition += textToInsert.length;
                    
                    if (root.activeInput === 1) root.usernameStr = cur;
                    else if (root.activeInput === 2) root.passwordStr = cur;
                }
                return;
            }
            
            if (v === "caps") {
                isCaps = !isCaps;
            } else if (v === "backspace") {
                if (cursorPosition > 0) {
                    cur = cur.substring(0, cursorPosition - 1) + cur.substring(cursorPosition);
                    cursorPosition--;
                }
            } else if (v === "left") {
                if (cursorPosition > 0) cursorPosition--;
            } else if (v === "right") {
                if (cursorPosition < cur.length) cursorPosition++;
            } else {
                if (cur.length < maxLength) {
                    var letter = (v.length === 1 && isCaps) ? v.toUpperCase() : v;
                    cur = cur.substring(0, cursorPosition) + letter + cur.substring(cursorPosition);
                    cursorPosition += letter.length;
                }
            }
            
            if (root.activeInput === 1) root.usernameStr = cur;
            else if (root.activeInput === 2) root.passwordStr = cur;
        }


        Rectangle {
            id: kbPanel
            width: parent.width; height: 405; color: "#22262F"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -height
            
            Behavior on anchors.bottomMargin {
                NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
            }
            
            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                anchors.fill: parent; anchors.margins: 5; spacing: 4
                Repeater {
                    model: [
                        {row:0, wSum:15, keys:[{l:"`",v:"`"},{l:"1",v:"1"},{l:"2",v:"2"},{l:"3",v:"3"},{l:"4",v:"4"},{l:"5",v:"5"},{l:"6",v:"6"},{l:"7",v:"7"},{l:"8",v:"8"},{l:"9",v:"9"},{l:"0",v:"0"},{l:"-",v:"-"},{l:"=",v:"="},{l:"X",v:"backspace",w:2,isBS:true,isSpec:true}]},
                        {row:1, wSum:15, keys:[{l:"Tab",v:"   ",w:1.5,isSpec:true},{l:"Q",v:"q"},{l:"W",v:"w"},{l:"E",v:"e"},{l:"R",v:"r"},{l:"T",v:"t"},{l:"Y",v:"y"},{l:"U",v:"u"},{l:"I",v:"i"},{l:"O",v:"o"},{l:"P",v:"p"},{l:"[",v:"["},{l:"]",v:"]"},{l:"\\",v:"\\",w:1.5}]},
                        {row:2, wSum:15, keys:[{l:"Caps",v:"caps",w:1.8,isSpec:true},{l:"A",v:"a"},{l:"S",v:"s"},{l:"D",v:"d"},{l:"F",v:"f"},{l:"G",v:"g"},{l:"H",v:"h"},{l:"J",v:"j"},{l:"K",v:"k"},{l:"L",v:"l"},{l:";",v:";"},{l:"'",v:"'"},{l:"Enter",v:"Done",w:2.2,c:"#1A9EFF",isSpec:true}]},
                        {row:3, wSum:15, keys:[{l:"Shift",v:"caps",w:2.5,isSpec:true},{l:"Z",v:"z"},{l:"X",v:"x"},{l:"C",v:"c"},{l:"V",v:"v"},{l:"B",v:"b"},{l:"N",v:"n"},{l:"M",v:"m"},{l:",",v:","},{l:".",v:"."},{l:"/",v:"/"},{l:"Shift",v:"caps",w:2.5,isSpec:true}]},
                        {row:4, wSum:13.1, keys:[{l:"☺",v:"",w:1.2,isSpec:true},{l:" ",v:" ",w:6.5},{l:"🌐",v:"paste",w:1.2,isSpec:true},{l:"<",v:"left",w:1.2,isSpec:true},{l:">",v:"right",w:1.2,isSpec:true},{l:"Hide",v:"Done",w:1.8,isSpec:true}]}
                    ]
                    delegate: Row {
                        width: kbPanel.width - 10; height: 75; spacing: 4
                        property int rowIndex: modelData.row
                        property real tWeight: modelData.wSum
                        Repeater {
                            model: modelData.keys
                            delegate: Rectangle {
                                width: (parent.width / parent.tWeight) * (modelData.w || 1.0) - parent.spacing
                                height: parent.height
                                color: (keyboardContainer.r === parent.rowIndex && keyboardContainer.c === index) ? "white" : (modelData.isSpec ? "black" : "#0F1318")
                                
                                MouseArea {
                                    id: keyMa
                                    anchors.fill: parent
                                    
                                    onPressed: {
                                        keyboardContainer.r = parent.parent.rowIndex;
                                        keyboardContainer.c = index;
                                        if (typeof sType !== "undefined") sType.play();
                                        
                                        if (modelData.v !== "Done" && modelData.v !== "caps" && modelData.v !== "paste") {
                                            autoRepeatAnim.start();
                                        } else {
                                            keyboardContainer.processInput(modelData.v);
                                        }
                                    }
                                    
                                    onReleased: autoRepeatAnim.stop()
                                    onExited: autoRepeatAnim.stop()
                                    onCanceled: autoRepeatAnim.stop()

                                    SequentialAnimation {
                                        id: autoRepeatAnim
                                        ScriptAction { script: keyboardContainer.processInput(modelData.v) }
                                        PauseAnimation { duration: 500 }
                                        SequentialAnimation {
                                            loops: Animation.Infinite
                                            ScriptAction { 
    script: {
        keyboardContainer.processInput(modelData.v); 
        if (typeof sType !== "undefined") sType.play(); 
    }
}
                                            PauseAnimation { duration: 60 } 
                                        }
                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    
                                    Text {
                                        id: spaceIcon
                                        font.family: typeof icons !== 'undefined' ? icons.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.v === " "
                                        font.pixelSize: 40; text: "Y"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 20
                                    }
                                    
                                    Text {
                                        id: backspaceIcon
                                        font.family: typeof icons !== 'undefined' ? icons.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.v === "backspace"
                                        font.pixelSize: 40
                                        text: theme && theme.nintendoLayout ? (theme.universalIcons ? "У" : "Y") : (theme.universalIcons ? "Х" : "X")
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
                                    }
                                    
                                    Text {
                                        id: backspaceText
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.v === "backspace"
                                        font.pixelSize: 22; text: "Backspace"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
                                        width: Math.min(implicitWidth, parent.width - anchors.leftMargin - 15); elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        id: enterIcon
                                        font.family: typeof icons !== 'undefined' ? icons.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Enter"
                                        font.pixelSize: 45; text: ">"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
                                    }
                                    
                                    Text {
                                        id: enterText
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Enter"
                                        font.pixelSize: 26; text: "Enter"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
                                        width: Math.min(implicitWidth, parent.width - anchors.leftMargin - 15); elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        id: hideIcon
                                        font.family: typeof icons !== 'undefined' ? icons.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Hide" && modelData.v === "Done"
                                        font.pixelSize: 40
                                        text: theme && theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B")
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
                                    }
                                    
                                    Text {
                                        id: hideText
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Hide" && modelData.v === "Done"
                                        font.pixelSize: 24; text: "Hide"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
                                        width: Math.min(implicitWidth, parent.width - anchors.leftMargin - 15); elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        id: leftShiftText
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Shift" && index === 0
                                        font.pixelSize: 26; text: "Shift"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
                                        width: Math.min(implicitWidth, parent.width * 0.5 - anchors.leftMargin); elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        id: leftShiftIcon
                                        font.family: typeof icons !== 'undefined' ? icons.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Shift" && index === 0
                                        font.pixelSize: 45; text: "<"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
                                    }
                                    
                                    Text {
                                        id: capsText
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.v === "caps" && modelData.l !== "Shift"
                                        font.pixelSize: 26; text: "Caps"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
                                        width: Math.min(implicitWidth, parent.width * 0.5 - anchors.leftMargin); elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        id: capsIcon
                                        font.family: typeof icons !== 'undefined' ? icons.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.v === "caps" && modelData.l !== "Shift"
                                        font.pixelSize: 45; text: "<"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
                                    }
                                    
                                    Text {
                                        id: rightShiftIcon
                                        font.family: typeof icons !== 'undefined' ? icons.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Shift" && index === 11
                                        font.pixelSize: 45; text: "<"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
                                    }
                                    
                                    Text {
                                        id: rightShiftText
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        visible: modelData.l === "Shift" && index === 11
                                        font.pixelSize: 26; text: "Shift"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.right: parent.right; anchors.rightMargin: 15
                                        width: Math.min(implicitWidth, parent.width - anchors.leftMargin - 15); elide: Text.ElideRight
                                    }
                                    
                                    Text {
                                        id: arrowText
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        font.pixelSize: 30
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        text: {
                                            if (modelData.v === "left") return "<";
                                            if (modelData.v === "right") return ">";
                                            return "";
                                        }
                                        visible: modelData.v === "left" || modelData.v === "right"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    
                                    Text {
                                        id: emojiGlobeText
                                        font.family: (modelData.l === "☺") ? (typeof icons !== 'undefined' ? icons.name : "") : (typeof bold !== 'undefined' ? bold.name : "")
                                        font.pixelSize: (modelData.l === "☺") ? 45 : 26
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        text: {
                                            if (modelData.l === "☺") return "😀";
                                            if (modelData.l === "🌐") return "Paste";
                                            return "";
                                        }
                                        visible: modelData.l === "☺" || modelData.l === "🌐"
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: (modelData.l === "☺") ? 13 : 20; anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    
                                    Text {
                                        id: specTextOnly
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        font.pixelSize: 26
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        text: {
                                            if (modelData.l === "Tab") return "Tab";
                                            if (modelData.l === "   ") return "   ";
                                            return "";
                                        }
                                        visible: !!modelData.isSpec && !spaceIcon.visible && !backspaceIcon.visible && 
                                                !enterIcon.visible && !hideIcon.visible && !leftShiftText.visible &&
                                                !capsText.visible && !rightShiftIcon.visible && !arrowText.visible &&
                                                !emojiGlobeText.visible
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.left: parent.left; anchors.leftMargin: 15
                                    }
                                    
                                    Text {
                                        id: normalKeyText
                                        font.family: typeof bold !== 'undefined' ? bold.name : ""
                                        font.pixelSize: 26
                                        color: (keyboardContainer.r === parent.parent.parent.rowIndex && keyboardContainer.c === index) ? "black" : "white"
                                        text: {
                                            if (modelData.isSpec) return "";
                                            if (modelData.v.length === 1) {
                                                return keyboardContainer.isCaps ? modelData.l.toUpperCase() : modelData.l.toLowerCase();
                                            }
                                            return modelData.l;
                                        }
                                        visible: !modelData.isSpec
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.3; anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Keys.onPressed: {
            var rowCounts = [14, 14, 13, 12, 6];
            if (api.keys.isLeft(event)) { 
                if (c > 0) {
                    c--;
                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                }
                event.accepted = true; 
            }
            else if (api.keys.isRight(event)) { 
                if (c < rowCounts[r] - 1) {
                    c++;
                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                }
                event.accepted = true; 
            }
            else if (api.keys.isUp(event)) { 
                if (r > 0) { 
                    r--; 
                    c = Math.min(c, rowCounts[r] - 1); 
                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                }
                event.accepted = true; 
            }
            else if (api.keys.isDown(event)) { 
                if (r < 4) { 
                    r++; 
                    c = Math.min(c, rowCounts[r] - 1); 
                    if (typeof sNav !== "undefined") { sNav.stop(); sNav.play(); }
                }
                event.accepted = true; 
            }
            else if (api.keys.isDetails(event)) { processInput("backspace"); event.accepted = true; }
            else if (api.keys.isFilters(event)) { processInput(" "); event.accepted = true; }
            else if (api.keys.isNextPage(event)) { processInput("Done"); event.accepted = true; }
            else if (api.keys.isPrevPage(event)) { isCaps = !isCaps; event.accepted = true; }
            else if (api.keys.isCancel(event)) { 
                if (typeof sBack !== "undefined") sBack.play();
                processInput("Done"); 
                event.accepted = true; 
            }
            else if (api.keys.isAccept(event)) {
                var values = [
                    ["`","1","2","3","4","5","6","7","8","9","0","-","=","backspace"],
                    ["   ","q","w","e","r","t","y","u","i","o","p","[","]","\\"],
                    ["caps","a","s","d","f","g","h","j","k","l",";","'","Done"],
                    ["caps","z","x","c","v","b","n","m",",",".","/","caps"],
                    ["",""," ","left","right","Done"]
                ];
                if (typeof sType !== "undefined") sType.play();
                processInput(values[r][c]);
                event.accepted = true;
            }
        }
    }

    function startExitAnimation(index) {
        nextPageIndex = index
        exitAnim.start()
    }

    Component.onCompleted: {
        enterAnim.start()
        root.goToZone(1)                                
        focusTimer.start()
    }

    SequentialAnimation {
        id: enterAnim
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

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 0; duration: 225; easing.type: Easing.InQuad }
            NumberAnimation { target: animatedContent; property: "scale"; to: 0.95; duration: 225; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: theme.finalizeNavigation(nextPageIndex)
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            if (!root.closeMenuVisible && root.focusZone === 1) {
                mainCanvas.forceActiveFocus();
            }
        }
    }
}
