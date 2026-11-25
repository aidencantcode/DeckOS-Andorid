import QtQuick 2.15
import QtMultimedia 5.9
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15
import "../ra" // DECKOS: RetroAchievements (from BigScreenFE)

FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    ShaderEffectSource {
        id: globalBlurSource
        anchors.fill: parent
        sourceItem: animatedContent
        live: true
        visible: false
        wrapMode: ShaderEffectSource.ClampToEdge
    }

    property real topH: 95
    property var theme
    property int focusZone: 0 // 0 = top, 1 = zone2 buttons, 2 = zone3 tabs, 3 = achievements list (DECKOS)
    readonly property int achievementsTab: 2 // DECKOS: the third tab (was COMMUNITY) shows RetroAchievements

    // DECKOS: move focus from the tab row into the achievements panel and back
    function enterAchievements() {
        topButtonsRow.focus = false
        zone2.focus = false
        zone3Tabs.focus = false
        focusZone = 3
        flick.contentY = Math.max(0, flick.contentHeight - flick.height) // whole panel above the footer
        raSection.forceActiveFocus()
        raSection.gridFocusAtZero()
    }
    function leaveAchievements() {
        goToZone(2)
        zone3Tabs.currentIndex = achievementsTab
    }
    property bool optionsMenuVisible: false
    property var currentFocusedGame: null
    property bool isLaunching: false
    property bool coverLaunch: false   // DECKOS: this launch goes under the launch cover
    property var coverGame: null
    property int originalZone1Height: 620
    property bool closeMenuVisible: false
    property var selectedGameForMedia: null

    // ---- Fullscreen properties ----
    property bool fullscreenView: false
    property var currentScreenshotGame: null
    property int currentScreenshotIndex: 0
    property bool uiVisible: true
    property var fullscreenScreenshots: [] // список путей к скриншотам

    function startLaunchAnimation() {
        if (isLaunching) return

        isLaunching = true
        // DECKOS: launch cover - the launch screen stays over the game while it loads (Settings › Overlay)
        coverLaunch = theme.gameLaunchingAnimation && !!deckos.ingame && deckos.ingame.launchCover && deckos.ingame.launchCoverPossible
        flick.interactive = false
        masterReverseAnim.stop()

        try { sGame.play() } catch(e) {}
        masterLaunchAnim.start()
    }

    function cancelLaunchAnimation() {
        if (!isLaunching) return

        isLaunching = false
        coverLaunchTimer.stop()
        if (coverLaunch) deckos.ingame.hideLaunchCover()
        masterLaunchAnim.stop()
        masterReverseAnim.start()
        flick.interactive = true
        zone2.forceActiveFocus()

        try { sLeftClose.play() } catch(e) {}
    }

    // DECKOS: starts the game - under the launch cover when it can be shown (Java LaunchCover: a snapshot of
    // this screen over everything, the Steam logo and spinner still moving; it fades after its time)
    function launchCurrentGame() {
        var g = theme.currentGame
        if (!g || typeof g.launch !== "function") return
        if (coverLaunch && deckos.ingame.showLaunchCover(loadingCircles, loadingCircles.step, themeLogo,
                                                          deckos.ingame.launchCoverSeconds * 1000)) {
            coverGame = g
            coverLaunchTimer.start() // the cover's window first, then the game
        } else {
            g.launch()
        }
    }

    Timer {
        id: coverLaunchTimer
        interval: 200
        onTriggered: {
            var g = root.coverGame
            root.coverGame = null
            if (root.isLaunching && g) g.launch()
        }
    }

    function toggleOptionsMenu() {
        if (optionsMenuVisible) {
            optionsMenuVisible = false
            optionsMenu.focus = false
            if (focusZone === 1) {
                zone2.forceActiveFocus()
            }
        } else if (focusZone === 1) {
            currentFocusedGame = theme.currentGame
            topButtonsRow.focus = false
            zone2.focus = false
            zone3Tabs.focus = false
            optionsMenuVisible = true
            optionsMenu.forceActiveFocus()
        }
    }

    // ---- Toggle Fullscreen ----
    function toggleFullscreen(data) {
        if (fullscreenView) {
            // Закрыть полноэкранный режим
            sBack.play()
            fullimageAnim.start()
            enterAnim.start()
            fullscreenView = false
            currentScreenshotGame = null
            fullscreenScreenshots = []
            // вернуть фокус
            focusTimer.start()
        } else {
            if (!data) return
            sShowui.play()
            fullimageAnim.start()
            enterAnim.start()
            fullscreenView = true
            currentScreenshotGame = data.game ? data.game : data

            // Получаем список скриншотов
            var screenshots = currentScreenshotGame.assets.screenshots || []
            if (screenshots.length === 0 && currentScreenshotGame.assets.screenshot) {
                screenshots = [currentScreenshotGame.assets.screenshot]
            }
            fullscreenScreenshots = screenshots

            // Находим индекс переданного скриншота
            var targetScreenshot = data.screenshot ? data.screenshot : ""
            var idx = screenshots.indexOf(targetScreenshot)
            if (idx === -1) idx = 0
            currentScreenshotIndex = idx

            uiVisible = true
            buttonsTimer.restart()

            // Снять фокус с других элементов
            topButtonsRow.focus = false
            zone2.focus = false
            zone3Tabs.focus = false
            if (stuffGrid) stuffGrid.focus = false
        }
    }

    function goToZone(zoneIndex) {
        if (zoneIndex < 0) zoneIndex = 0
        if (zoneIndex > 2) zoneIndex = 2

        topButtonsRow.focus = false
        zone2.focus = false
        zone3Tabs.focus = false

        focusZone = zoneIndex

        if (zoneIndex === 1) {
            flick.contentY = 0
        } else if (zoneIndex === 2) {
            flick.contentY = zone1.height + zone2.height + zone2_5.height - 330
        }

        if (zoneIndex === 0) {
            topButtonsRow.forceActiveFocus()
            topButtonsRow.focus = true
        } else if (zoneIndex === 1) {
            zone2.forceActiveFocus()
            zone2.focus = true
        } else if (zoneIndex === 2) {
            zone3Tabs.forceActiveFocus()
            zone3Tabs.focus = true
        }
    }

    Keys.onPressed: {
        // ---- Fullscreen handling (must come first) ----
        if (fullscreenView) {
            uiVisible = true
            buttonsTimer.restart()
            if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
                toggleFullscreen(null)
                event.accepted = true
                return
            } else if (api.keys.isPrevPage(event)) {
                if (currentScreenshotIndex > 0) currentScreenshotIndex--
                event.accepted = true
                return
            } else if (api.keys.isNextPage(event)) {
                if (currentScreenshotIndex < fullscreenScreenshots.length - 1) currentScreenshotIndex++
                event.accepted = true
                return
            }
            // Остальные клавиши игнорируем в fullscreen
            event.accepted = true
            return
        }

        // DECKOS: the achievements panel handles its own keys
        if (focusZone === 3) {
            if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) { leaveAchievements(); event.accepted = true }
            return
        }

        // ---- Normal navigation ----
        if (event.key === Qt.Key_Down) {
            if (focusZone === 0) {
                goToZone(1)
                sNav.stop();
                sNav.play();
                zone2.currentButtonIndex = 0
                event.accepted = true
            } else if (focusZone === 1) {
                goToZone(2)
                sNav.stop();
                sNav.play();
                zone3Tabs.currentIndex = 0
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Up || api.keys.isFilters(event)) {
            if (focusZone === 2) {
                goToZone(1)
                sNav.stop();
                sNav.play();
                zone2.currentButtonIndex = 0
                event.accepted = true
            } else if (focusZone === 1) {
                goToZone(0)
                sNav.stop();
                sNav.play();
                topButtonsRow.currentIndex = 0
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Left || api.keys.isPrevPage(event)) {
            if (focusZone === 0) {
                if (topButtonsRow.currentIndex > 0) {
                    topButtonsRow.currentIndex--
                    sNav.stop();
                    sNav.play();
                    event.accepted = true
                }
            } else if (focusZone === 1) {
                if (zone2.currentButtonIndex > 0) {
                    zone2.currentButtonIndex--
                    sNav.stop();
                    sNav.play();
                    event.accepted = true
                }
            } else if (focusZone === 2) {
                if (zone3Tabs.currentIndex > 0) {
                    zone3Tabs.currentIndex--
                    sTab.play()
                    event.accepted = true
                }
            }
        } else if (event.key === Qt.Key_Right || api.keys.isNextPage(event)) {
            if (focusZone === 0) {
                if (topButtonsRow.currentIndex < 3) {
                    topButtonsRow.currentIndex++
                    sNav.stop();
                    sNav.play();
                    event.accepted = true
                }
            } else if (focusZone === 1) {
                if (zone2.currentButtonIndex < 2) {
                    zone2.currentButtonIndex++
                    sNav.stop();
                    sNav.play();
                    event.accepted = true
                }
            } else if (focusZone === 2) {
                if (zone3Tabs.currentIndex < 3) {
                    zone3Tabs.currentIndex++
                    sTab.play()
                    event.accepted = true
                }
            }
        } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
            if (focusZone === 1) {
                if (zone2.currentButtonIndex === 0) {
    if (root.isLaunching && !theme.gameLaunchingAnimation) {
        root.cancelLaunchAnimation()
        event.accepted = true
    } else if (theme.currentGame) {
        root.startLaunchAnimation()
        event.accepted = true
    }
                } else if (zone2.currentButtonIndex === 2) {
                    root.toggleOptionsMenu()
                    sShowui.play()
                    event.accepted = true
                } else {
                    event.accepted = true
                }
            } else if (focusZone === 2) {
                event.accepted = true
            }
        } else if (!closeMenuVisible && (api.keys.isCancel(event) || event.key === Qt.Key_Escape)) {
            if (root.isLaunching && theme.gameLaunchingAnimation) {
                root.cancelLaunchAnimation()
                event.accepted = true
            } else {
                if (api.memory.previousPage !== undefined) {
                    theme.openPage(api.memory.previousPage);
                } else {
                    theme.openPage(0);
                }
                event.accepted = true;
            }
        } else if (!closeMenuVisible && api.keys.isMenu(event)) {
            leftBar.toggle()
            sLeftClose.play()
            event.accepted = true
        }
    }

    Item {
        id: animatedContent
        anchors.fill: parent

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: parent.width
            contentHeight: zone3Tabs.currentIndex === 1
                ? Math.max(parent.height * 1.5,
                           zone1.height + zone2.height + zone2_5.height +
                           zone3Tabs.height + 40 + yourStuffContent.realHeight + 120)
                : zone3Tabs.currentIndex === 0 // DECKOS: ACTIVITY is as tall as its feed
                ? Math.max(parent.height * 1.5,
                           zone1.height + zone2.height + zone2_5.height +
                           zone3Tabs.height + 40 + activityContent.height + 160)
                : parent.height * 1.5
                  // DECKOS: +260 while the ACHIEVEMENTS tab is open, so the locked row can scroll above the footer
                  + (zone3Tabs.currentIndex === root.achievementsTab ? 260 : 0)
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: true
            clip: true

            Behavior on contentY {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }

            AnimatedImage {
                id: zone1
                width: flick.contentWidth
                height: 620
                source: theme.getAssetSource("background", theme.currentGame)
                fillMode: Image.PreserveAspectCrop
                opacity: 0.9
                visible: !theme.highContrastGameMenu
                playing: visible && status === AnimatedImage.Ready && (api.memory.has("animatedCovers") ? api.memory.get("animatedCovers") : false)
            }

            // DECKOS: trailer - after a few seconds on the page the hero cross-fades into the game's video
            // (Pegasus `video` asset: media/<game>/video.*); the logo stays on top. Settings > General.
            Video {
                id: trailer
                x: zone1.x
                y: zone1.y
                width: zone1.width
                height: zone1.height
                readonly property string clipUrl: (theme.currentGame && theme.currentGame.assets)
                                               ? (theme.currentGame.assets.video || "") : ""
                readonly property bool wanted: theme.trailerMode > 0 && clipUrl !== "" && !root.isLaunching
                                               && !theme.highContrastGameMenu && root.visible
                                               && Qt.application.state === Qt.ApplicationActive
                fillMode: VideoOutput.PreserveAspectCrop
                muted: theme.trailerMode !== 2
                volume: 0.7
                loops: MediaPlayer.Infinite
                opacity: 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }

                onWantedChanged: {
                    if (wanted) return
                    opacity = 0
                    pause()
                }
                // the first frames are on screen: fade in
                onPositionChanged: if (wanted && position > 150 && opacity === 0) opacity = 1
                onClipUrlChanged: { opacity = 0; stop(); source = "" }

                Timer {
                    interval: Math.max(1, theme.trailerDelay) * 1000
                    running: trailer.wanted && trailer.opacity === 0
                    onTriggered: {
                        if (trailer.source.toString() !== trailer.clipUrl) trailer.source = trailer.clipUrl
                        trailer.play()
                    }
                }
            }

            Rectangle {
                id: launchOverlay
                anchors.fill: parent
                color: "black"
                opacity: 0
            }

            AnimatedImage {
                id: logo
                width: zone1.width / 1.5
                height: zone1.height / 1.5
                source: theme.getAssetSource("logo", theme.currentGame)
                fillMode: Image.PreserveAspectFit
                anchors.centerIn: zone1
                visible: !theme.highContrastLogo
                playing: visible && status === AnimatedImage.Ready && (api.memory.has("animatedCovers") ? api.memory.get("animatedCovers") : false)
                z: 100
            }

            FocusScope {
                id: zone2
                width: flick.contentWidth
                height: 200
                anchors.top: zone1.bottom
                z: 20
                focus: false

                property int currentButtonIndex: 0

                Rectangle {
                    id: playButton
                    width: height * (root.width < 1500 ? 2.8 : 4) // DECKOS: narrower on near-square screens, so PLAY TIME fits
                    height: parent.height * 0.6
                    radius: 5
                    anchors {
                        left: parent.left
                        leftMargin: 60
                        verticalCenter: parent.verticalCenter
                    }
                    color: isLaunching ? "#1A9EFF" : (zone2.currentButtonIndex === 0 && zone2.focus) ? (theme.currentGame && theme.currentGame.extra && theme.currentGame.extra["missing"] !== undefined ? "#1A9EFF" : "#54B63D") : "#20FEFEFE"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 30

                        Text {
                            text: isLaunching ? "х" : (theme.currentGame && theme.currentGame.extra && theme.currentGame.extra["missing"] !== undefined ? "♠︎" : "♥︎")
                            color: "white"
                            font.pixelSize: isLaunching ? 40 : 55
                            font.family: icons.name
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: isLaunching ? "Cancel" : (theme.currentGame && theme.currentGame.extra && theme.currentGame.extra["missing"] !== undefined ? "Not Installed" : "Play")
                            color: "white"
                            font.pixelSize: 35
                            font.family: bold.name
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
    anchors.fill: parent
    onClicked: {
        if (root.focusZone !== 1) {
            root.goToZone(1)
            zone2.currentButtonIndex = 0
            zone2.forceActiveFocus()
            sNav.stop();
            sNav.play();
        } else if (zone2.currentButtonIndex === 0 && zone2.focus) {
            if (root.isLaunching && theme.gameLaunchingAnimation) {
                root.cancelLaunchAnimation()
            } else if (theme.currentGame && (!theme.currentGame.extra || theme.currentGame.extra["missing"] === undefined)) {
                root.startLaunchAnimation()
            }
        } else {
            zone2.currentButtonIndex = 0
            sNav.stop();
            sNav.play();
            zone2.forceActiveFocus()
        }
    }
}

                    
                    Item {
                        id: launchTextContainer
                        width: 300
                        height: playButton.height
                        visible: isLaunching ? true : false 
                        anchors {
                            left: playButton.right
                            leftMargin: 40
                            verticalCenter: playButton.verticalCenter
                        }

                        Text {
                            id: launchTextLabel
                            anchors {
                                left: parent.left
                                top: parent.top
                                topMargin: 13
                            }
                            text: "LAUNCHING:"
                            color: "white"
                            opacity: 0.5
                            font.pixelSize: 30
                            font.family: extrabold.name
                        }

                        Text {
                            id: launchTextValue
                            anchors {
                                left: parent.left
                                top: launchTextLabel.bottom
                                topMargin: 7
                            }
                            text: "Launching executable"
                            color: "white"
                            font.pixelSize: 38
                            font.family: bold.name                         
                }
                }
                

                    Item {
                        id: lastPlayedContainer
                        width: 300
                        height: playButton.height
                        anchors {
                            left: playButton.right
                            leftMargin: isLaunching ? 500 : 40
                            verticalCenter: playButton.verticalCenter
                        }

                        Text {
                            id: lastPlayedLabel
                            anchors {
                                left: parent.left
                                top: parent.top
                                topMargin: 13
                            }
                            text: "LAST PLAYED:"
                            color: "white"
                            opacity: 0.5
                            font.pixelSize: 30
                            font.family: extrabold.name
                        }

                        Text {
                            id: lastPlayedValue
                            anchors {
                                left: parent.left
                                top: lastPlayedLabel.bottom
                                topMargin: 7
                            }
                            text: isLaunching ? "Now" : getLastPlayedText()
                            color: "white"
                            font.pixelSize: 38
                            font.family: bold.name

                            function getLastPlayedText() {
                                // DECKOS: a game that was never launched has an invalid date, which is a
                                // truthy Date whose arithmetic gives NaN - StMini showed "Just now" for it
                                var g = theme.currentGame
                                if (!g || !g.lastPlayed || g.playCount === 0) return "Never"
                                var lastPlayed = new Date(g.lastPlayed)
                                if (isNaN(lastPlayed.getTime()) || lastPlayed.getFullYear() < 1980) return "Never"

                                var now = new Date()
                                var diffMs = now - lastPlayed
                                var diffMins = Math.floor(diffMs / 60000)
                                var diffHours = Math.floor(diffMins / 60)
                                var diffDays = Math.floor(diffHours / 24)
                                var diffWeeks = Math.floor(diffDays / 7)
                                var diffMonths = Math.floor(diffDays / 30)
                                var diffYears = Math.floor(diffDays / 365)

                                if (diffYears > 0) {
                                    return diffYears === 1 ? "1 year ago" : diffYears + " years ago"
                                } else if (diffMonths > 0) {
                                    return diffMonths === 1 ? "1 month ago" : diffMonths + " months ago"
                                } else if (diffWeeks > 0) {
                                    return diffWeeks === 1 ? "1 week ago" : diffWeeks + " weeks ago"
                                } else if (diffDays > 0) {
                                    return diffDays === 1 ? "Yesterday" : diffDays + " days ago"
                                } else if (diffHours > 0) {
                                    return diffHours === 1 ? "1 hour ago" : diffHours + " hours ago"
                                } else if (diffMins > 0) {
                                    return diffMins === 1 ? "1 minute ago" : diffMins + " minutes ago"
                                } else {
                                    return "Just now"
                                }
                            }
                        }
                    }

                    // DECKOS: Steam's PLAY TIME next to LAST PLAYED (Pegasus play time, in seconds)
                    Item {
                        id: playTimeContainer
                        width: 300
                        height: playButton.height
                        visible: !isLaunching
                        anchors {
                            left: lastPlayedContainer.left
                            leftMargin: Math.max(lastPlayedLabel.implicitWidth, lastPlayedValue.implicitWidth) + 70
                            verticalCenter: playButton.verticalCenter
                        }

                        Text {
                            id: playTimeLabel
                            anchors { left: parent.left; top: parent.top; topMargin: 13 }
                            text: "PLAY TIME:"
                            color: "white"
                            opacity: 0.5
                            font.pixelSize: 30
                            font.family: extrabold.name
                        }
                        Text {
                            anchors { left: parent.left; top: playTimeLabel.bottom; topMargin: 7 }
                            text: formatPlayTime(theme.currentGame ? theme.currentGame.playTime : 0)
                            color: "white"
                            font.pixelSize: 38
                            font.family: bold.name

                            function formatPlayTime(seconds) {
                                if (!seconds || seconds < 60) return seconds > 0 ? "Under a minute" : "None yet"
                                var mins = Math.floor(seconds / 60)
                                var hours = Math.floor(mins / 60)
                                mins = mins % 60
                                if (hours === 0) return mins + " min"
                                return hours + " h" + (mins > 0 ? " " + mins + " min" : "")
                            }
                        }
                    }

                    Keys.onReturnPressed: {
                        if (theme.currentGame) root.startLaunchAnimation()
                    }
                }

                Rectangle {
                    id: wButton
                    width: height
                    height: parent.height * 0.6
                    radius: 5
                    anchors {
                        right: parent.right
                        rightMargin: 200
                        verticalCenter: parent.verticalCenter
                    }
                    color: (zone2.currentButtonIndex === 1 && zone2.focus) ? "white" : "#20FEFEFE"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "G"
                        color: (zone2.currentButtonIndex === 1 && zone2.focus) ? "black" : "white"
                        font.pixelSize: 60
                        font.family: icons.name
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.focusZone !== 1) {
                                root.goToZone(1)
                                sNav.stop();
                                sNav.play();
                            }
                            zone2.currentButtonIndex = 1
                            sNav.stop();
                            sNav.play();
                            zone2.forceActiveFocus()
                        }
                    }
                }

                Rectangle {
                    id: gButton
                    width: height
                    height: parent.height * 0.6
                    radius: 5
                    anchors {
                        right: parent.right
                        rightMargin: 60
                        verticalCenter: parent.verticalCenter
                    }
                    color: (zone2.currentButtonIndex === 2 && zone2.focus) ? "white" : "#20FEFEFE"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "w"
                        color: (zone2.currentButtonIndex === 2 && zone2.focus) ? "black" : "white"
                        font.pixelSize: 60
                        font.family: icons.name
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.focusZone !== 1) {
                                root.goToZone(1)
                                zone2.currentButtonIndex = 2
                                zone2.forceActiveFocus()
                                sNav.stop();
                                sNav.play();
                            } else if (zone2.currentButtonIndex === 2 && zone2.focus) {
                                root.toggleOptionsMenu()
                                sShowui.play()
                            } else {
                                zone2.currentButtonIndex = 2
                                sNav.stop();
                                sNav.play();
                                zone2.forceActiveFocus()
                            }
                        }
                    }
                }

                Keys.onLeftPressed: if (!isLaunching && currentButtonIndex > 0) {currentButtonIndex--; sNav.stop(); sNav.play();}
                Keys.onRightPressed: if (!isLaunching && currentButtonIndex < 2) {currentButtonIndex++; sNav.stop(); sNav.play();}
                Keys.onDownPressed: if (!isLaunching) {root.goToZone(2); sNav.stop(); sNav.play();}
                Keys.onUpPressed: if (!isLaunching) {root.goToZone(0); sNav.stop(); sNav.play();}
            }

            Rectangle {
                id: zone2_5
                width: flick.contentWidth
                height: 50
                anchors.top: zone2.bottom
                color: "transparent"
                z: 100

                Rectangle {
                    width: parent.width * 0.85
                    height: 3
                    anchors.centerIn: parent
                    color: "#20FEFEFE"
                }
            }

           Rectangle {
    id: zone3
    width: flick.contentWidth
    anchors.top: zone2_5.bottom
    anchors.bottom: parent.bottom
    color: "transparent"
    z: 100
    
    Text {
                id: leftSideText
                anchors {
                    left: parent.left
                    leftMargin: 40
                    verticalCenter: zone3Tabs.verticalCenter
                }
                text: "<"
                color: "white"
                font.pixelSize: 70
                font.family: icons.name
                opacity: zone3Tabs.activeFocus ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            }

            Text {
                id: rightSideText
                anchors {
                    right: parent.right
                    rightMargin: 40
                    verticalCenter: zone3Tabs.verticalCenter
                }
                text: ">"
                color: "white"
                font.pixelSize: 70
                font.family: icons.name
                opacity: zone3Tabs.activeFocus ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                horizontalAlignment: Text.AlignRight
            }

    Row {
        id: zone3Tabs
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            margins: 60
        }
        height: 74
        spacing: 24
        property int currentIndex: 0
        property bool isContentFocused: root.focusZone === 2 && !tabActivity.activeFocus && !tabYourStuff.activeFocus && !tabCommunity.activeFocus && !tabGameInfo.activeFocus
        focus: false

        Rectangle {
            id: tabActivity
            width: 240; height: parent.height
            radius: 40
            color: {
    if (zone3Tabs.activeFocus && zone3Tabs.currentIndex === 0) "white"
    else if (zone3Tabs.currentIndex === 0 && zone3Tabs.isContentFocused) "#20FEFEFE"
    else "transparent"
}

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "ACTIVITY"
                color: (zone3Tabs.activeFocus && zone3Tabs.currentIndex === 0) ? "black" : "white"
                font.pixelSize: 27
                font.family: bold.name
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                    }
                    zone3Tabs.currentIndex = 0
                    sTab.play()
                    tabActivity.forceActiveFocus()
                }
            }

            Keys.onReturnPressed: {
                zone3Tabs.currentIndex = 0
                tabActivity.forceActiveFocus()
            }
        }

        Rectangle {
            id: tabYourStuff
            width: 240; height: parent.height
            radius: 40
            color: {
    if (zone3Tabs.activeFocus && zone3Tabs.currentIndex === 1) "white"
    else if (zone3Tabs.currentIndex === 1 && zone3Tabs.isContentFocused) "#20FEFEFE"
    else "transparent"
}

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "YOUR STUFF"
                color: (zone3Tabs.activeFocus && zone3Tabs.currentIndex === 1) ? "black" : "white"
                font.pixelSize: 27
                font.family: bold.name
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                    }
                    zone3Tabs.currentIndex = 1
                    sTab.play()
                    tabYourStuff.forceActiveFocus()
                }
            }

            Keys.onReturnPressed: {
                zone3Tabs.currentIndex = 1
                tabYourStuff.forceActiveFocus()
            }
        }

        Rectangle {
            id: tabCommunity
            width: 240; height: parent.height
            radius: 40
            color: {
    if (zone3Tabs.activeFocus && zone3Tabs.currentIndex === 2) "white"
    else if (zone3Tabs.currentIndex === 2 && zone3Tabs.isContentFocused) "#20FEFEFE"
    else "transparent"
}
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "ACHIEVEMENTS" // DECKOS: was COMMUNITY
                color: (zone3Tabs.activeFocus && zone3Tabs.currentIndex === 2) ? "black" : "white"
                font.pixelSize: 27
                font.family: bold.name
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                    }
                    zone3Tabs.currentIndex = 2
                    sTab.play()
                    tabCommunity.forceActiveFocus()
                }
            }

            Keys.onReturnPressed: {
                zone3Tabs.currentIndex = 2
                tabCommunity.forceActiveFocus()
            }
        }

        Rectangle {
            id: tabGameInfo
            width: 240; height: parent.height
            radius: 40
            color: {
    if (zone3Tabs.activeFocus && zone3Tabs.currentIndex === 3) "white"
    else if (zone3Tabs.currentIndex === 3 && zone3Tabs.isContentFocused) "#20FEFEFE"
    else "transparent"
}

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "GAME INFO"
                color: (zone3Tabs.activeFocus && zone3Tabs.currentIndex === 3) ? "black" : "white"
                font.pixelSize: 27
                font.family: bold.name
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.focusZone !== 2) {
                        root.goToZone(2)
                    }
                    zone3Tabs.currentIndex = 3
                    sTab.play()
                    tabGameInfo.forceActiveFocus()
                }
            }

            Keys.onReturnPressed: {
                zone3Tabs.currentIndex = 3
                tabGameInfo.forceActiveFocus()
            }
        }

        Keys.onLeftPressed: {
            if (currentIndex > 0) currentIndex--
            sTab.play()
            event.accepted = true
        }

        Keys.onRightPressed: {
            if (currentIndex < 3) currentIndex++
            sTab.play()
            event.accepted = true
        }

        Keys.onUpPressed: {
            // DECKOS: ACTIVITY scrolls back up to the tabs before leaving them
            var tabsY = zone1.height + zone2.height + zone2_5.height - 330
            if (currentIndex === 0 && flick.contentY > tabsY + 10) {
                flick.contentY = Math.max(tabsY, flick.contentY - 400)
            } else {
                root.goToZone(1)
            }
            sNav.stop();
            sNav.play();
            event.accepted = true
        }

        // DECKOS: Y switches the ACTIVITY achievements between list and grid
        Keys.onPressed: {
            if (event.isAutoRepeat) return
            if (currentIndex === 0 && (api.keys.isFilters(event) || event.key === Qt.Key_Y)) {
                activityContent.toggleView()
                sTab.play()
                event.accepted = true
            }
        }

        Keys.onDownPressed: {
            if (currentIndex === 0) { // DECKOS: ACTIVITY has no focusable items; Down scrolls through it
                flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + 400)
                sNav.stop();
                sNav.play();
            } else if (currentIndex === 1) {
                if (yourStuffContent.mediaCount > 0) {
                    stuffGrid.forceActiveFocus()
                    var baseOffsetY = zone1.height + zone2.height + zone2_5.height + 50
                    var rowOffset = (stuffGrid.currentIndex > 1) ? yourStuffContent.cellHeight + mediaBtn.height : 0
                    flick.contentY = baseOffsetY + rowOffset
                } else {
                    mediaBtn.forceActiveFocus()
                    flick.contentY = zone1.height + zone2.height + zone2_5.height + 50 + yourStuffContent.cellHeight + mediaBtn.height
                }
                sNav.stop();
                sNav.play();
            } else if (currentIndex === root.achievementsTab) { // DECKOS
                root.enterAchievements()
                sNav.stop();
                sNav.play();
            }
            event.accepted = true
        }
    }

    // DECKOS: ACHIEVEMENTS tab content - BigScreenFE's RetroAchievements panel
    RAGameInfoSection {
        id: raSection
        anchors {
            left: zone3.left
            right: zone3.right
            top: zone3Tabs.bottom
            bottom: zone3.bottom
            leftMargin: 60
            rightMargin: 60
            topMargin: 40
            bottomMargin: 40
        }
        visible: zone3Tabs.currentIndex === root.achievementsTab
        game: theme ? theme.currentGame : null
        onTabFocusRequested: root.leaveAchievements()
        onLoginRequested: { theme.loginReturnPage = 8; theme.openPage(13) } // DECKOS: our RA sign-in page
    }

    // DECKOS: ACTIVITY tab content - recent achievements (list or grid, Y) and screenshots
    GameActivity {
        id: activityContent
        anchors {
            left: zone3.left
            right: zone3.right
            top: zone3Tabs.bottom
            leftMargin: 60
            rightMargin: 60
            topMargin: 40
        }
        visible: zone3Tabs.currentIndex === 0
        game: theme ? theme.currentGame : null
        achievements: raSection._achievements
        raLoggedIn: raSection._hasCredentials
        raLoading: raSection._loading || raSection._searching
        numTotal: raSection._raNumAch
    }


                // ================= YOUR STUFF =================
                Item {
    id: yourStuffContent

    anchors {
        left: zone3.left
        right: zone3.right
        top: zone3Tabs.bottom
        leftMargin: 60
        rightMargin: 60
        topMargin: 40
    }
    visible: zone3Tabs.currentIndex === 1

    property real gridPadding: 15
    property real gridSpacing: 28
    property real cellWidth: (width - gridPadding * 2 - gridSpacing) / 2
    property real cellHeight: cellWidth * (9 / 16)
    property int mediaCount: Math.min(stuffRepeater.count, 4)
    property real achievementHeight: 180
    property real realHeight: achievementHeight + 30 + greyBox.height + 120

    height: visible ? realHeight : 0

    Rectangle {
        id: achievementBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: yourStuffContent.achievementHeight
        color: "#20FEFEFE"
        radius: 4
        focus: true
    }

    Text {
        id: mediaLabel
        anchors.top: achievementBox.bottom
        anchors.topMargin: 30
        anchors.left: parent.left
        text: "Media"
        color: "white"
        font.family: bold.name
        font.pixelSize: 36
    }

    Rectangle {
        id: greyBox
        anchors {
            left: parent.left
            right: parent.right
            top: mediaLabel.bottom
            topMargin: 10
        }
        color: "#20FEFEFE"
        radius: 4

        height: {
            var rows = yourStuffContent.mediaCount > 0 ? Math.ceil(yourStuffContent.mediaCount / 2) : 0
            var gridH = rows > 0 ? (rows * yourStuffContent.cellHeight + Math.max(0, rows - 1) * yourStuffContent.gridSpacing) : 100
            return yourStuffContent.gridPadding + gridH + yourStuffContent.gridPadding + 15 + mediaBtn.height + 15
        }

        Text {
            id: noMediaText
            text: "No media files available"
            color: "#888"
            font.pixelSize: 30
            font.family: bold.name
            anchors.top: parent.top
            anchors.topMargin: yourStuffContent.gridPadding + 15
            anchors.horizontalCenter: parent.horizontalCenter
            visible: yourStuffContent.mediaCount === 0
        }

        Grid {
            id: stuffGrid
            anchors {
                top: parent.top
                left: parent.left
                topMargin: yourStuffContent.gridPadding
                leftMargin: yourStuffContent.gridPadding
            }
            width: parent.width - yourStuffContent.gridPadding * 2
            columns: 2
            spacing: yourStuffContent.gridSpacing

            property int currentIndex: 0

            Keys.onPressed: {
                var maxIndex = stuffRepeater.count - 1
                var baseOffsetY = zone1.height + zone2.height + zone2_5.height + 50

                if (event.key === Qt.Key_Left) {
                    if (currentIndex > 0) {
                        currentIndex--
                        sNav.stop()
                        sNav.play()
                        var rowOffset = (currentIndex > 1) ? yourStuffContent.cellHeight + mediaBtn.height : 0
                        flick.contentY = baseOffsetY + rowOffset
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    if (currentIndex < maxIndex) {
                        currentIndex++
                        sNav.stop()
                        sNav.play()
                        var rowOffset = (currentIndex > 1) ? yourStuffContent.cellHeight + mediaBtn.height : 0
                        flick.contentY = baseOffsetY + rowOffset
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    if (currentIndex >= 2) {
                        currentIndex -= 2
                        sNav.stop()
                        sNav.play()
                        var rowOffset = (currentIndex > 1) ? yourStuffContent.cellHeight + mediaBtn.height : 0
                        flick.contentY = baseOffsetY + rowOffset
                    } else {
                        zone3Tabs.forceActiveFocus()
                        sNav.stop()
                        sNav.play()
                        flick.contentY = zone1.height + zone2.height + zone2_5.height - 330
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    if (currentIndex + 2 <= maxIndex) {
                        currentIndex += 2
                        sNav.stop()
                        sNav.play()
                        var rowOffset = (currentIndex > 1) ? yourStuffContent.cellHeight + mediaBtn.height : 0
                        flick.contentY = baseOffsetY + rowOffset
                    } else {
                        mediaBtn.forceActiveFocus()
                        sNav.stop()
                        sNav.play()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                    if (maxIndex >= 0) {
                        root.toggleFullscreen({ game: theme.currentGame, screenshot: stuffRepeater.model[currentIndex] })
                    }
                    event.accepted = true
                }
            }

            Repeater {
                id: stuffRepeater
                model: (theme.currentGame && theme.currentGame.assets && theme.currentGame.assets.screenshots)
                       ? theme.currentGame.assets.screenshots.slice(0, 4)
                       : []

                delegate: Item {
                    width: yourStuffContent.cellWidth
                    height: yourStuffContent.cellHeight

                    property bool isFocused: stuffGrid.currentIndex === index && stuffGrid.focus

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: modelData
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                        }
                    }

                    Rectangle {
                        id: highlightBorder
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 4
                        border.color: "grey"
                        radius: 2
                        anchors.margins: -7
                        opacity: isFocused ? 1.0 : 0.0
                        visible: isFocused
                        z: 1000
                        scale: isFocused ? 1.015 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        onVisibleChanged: {
                            if (visible) appearAnim.restart()
                            else appearAnim.stop()
                        }

                        SequentialAnimation {
                            id: appearAnim
                            loops: 1

                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 10; duration: 200; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 0; duration: 200; easing.type: Easing.OutBack }
                                NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -17; duration: 200; easing.type: Easing.OutBack }
                                ColorAnimation { target: highlightBorder; property: "border.color"; to: "white"; duration: 200 }
                                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 200 }
                            }

                            ParallelAnimation {
                                NumberAnimation { target: highlightBorder; property: "radius"; to: 2; duration: 200; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "anchors.margins"; to: -2; duration: 200; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: highlightBorder; property: "border.width"; to: 4; duration: 200; easing.type: Easing.OutBack }
                            }

                            SequentialAnimation {
                                loops: Animation.Infinite
                                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.2; duration: 500 }
                                NumberAnimation { target: highlightBorder; property: "opacity"; to: 0.5; duration: 500 }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!parent.isFocused) {
                                sNav.stop()
                                sNav.play()
                                stuffGrid.currentIndex = index
                                stuffGrid.forceActiveFocus()
                                var rowOffset = (index > 1) ? yourStuffContent.cellHeight + mediaBtn.height : 0
                                flick.contentY = zone1.height + zone2.height + zone2_5.height + 50 + rowOffset
                            } else {
                                root.toggleFullscreen({ game: theme.currentGame, screenshot: modelData })
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: mediaBtn
            anchors {
                left: parent.left
                bottom: parent.bottom
                margins: yourStuffContent.gridPadding
            }
            width: mediaBtnText.width + 50
            height: 70
            color: activeFocus ? "white" : "#20FEFEFE"
            radius: 4
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                id: mediaBtnText
                anchors.centerIn: parent
                text: "View Media files (" + (theme.currentGame && theme.currentGame.assets && theme.currentGame.assets.screenshots ? theme.currentGame.assets.screenshots.length : 0) + ")"
                color: mediaBtn.activeFocus ? "black" : "white"
                font.family: bold.name
                font.pixelSize: 30
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (!mediaBtn.activeFocus) {
                        mediaBtn.forceActiveFocus()
                        sNav.stop()
                        sNav.play()
                    } else {
                        if (theme.currentGame)
                            theme.mediaFilterGame = theme.currentGame.title
                        theme.openPage(4)
                    }
                }
            }

            Keys.onPressed: {
                if (event.key === Qt.Key_Up) {
                    if (yourStuffContent.mediaCount > 0) {
                        stuffGrid.forceActiveFocus()
                        var baseOffsetY = zone1.height + zone2.height + zone2_5.height + 50
                        var rowOffset = (stuffGrid.currentIndex > 1) ? yourStuffContent.cellHeight + mediaBtn.height : 0
                        flick.contentY = baseOffsetY + rowOffset
                    } else {
                        zone3Tabs.forceActiveFocus()
                    }
                    sNav.stop()
                    sNav.play()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                    if (theme.currentGame)
                        theme.mediaFilterGame = theme.currentGame.title
                    theme.openPage(4)
                    event.accepted = true
                }
            }
        }
    }
}


                Item {
                    id: gameInfoContent
                    anchors {
                        left: zone3.left
                        right: zone3.right
                        top: zone3Tabs.bottom
                        bottom: zone3.bottom
                        leftMargin: 60
                        rightMargin: 60
                        topMargin: 40
                        bottomMargin: 120
                    }
                    visible: zone3Tabs.currentIndex === 3

                    Row {
                        anchors.fill: parent
                        spacing: 40

                        Rectangle {
                            id: imageContainer
                            width: height * 0.666
                            height: parent.height
                            color: "transparent"
                            radius: theme.roundedCovers ? 24 : 0

                            Rectangle {
                                id: posterMask
                                anchors.fill: parent
                                radius: theme.roundedCovers ? 24 : 0
                                visible: false
                            }

                            AnimatedImage {
                                id: posterImage
                                anchors.fill: parent
                                source: theme.getAssetSource("poster", theme.currentGame)
                                fillMode: Image.PreserveAspectFit
                                mipmap: true

                                layer.enabled: theme.roundedCovers
                                layer.effect: OpacityMask {
                                    maskSource: posterMask
                                }

                                Rectangle {
                                    visible: posterImage.source === ""
                                    anchors.fill: parent
                                    color: "#333"
                                    radius: theme.roundedCovers ? 24 : 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "No image"
                                        color: "#888"
                                        font.pixelSize: 20
                                    }
                                }
                            }
                        }


                        Rectangle {
                            id: descriptionContainer
                            width: parent.width - imageContainer.width - parent.spacing
                            height: parent.height
                            color: "transparent"

                            Text {
                                id: descriptionText
                                width: parent.width
                                height: parent.height - 200
                                text: {
                                    if (!theme.currentGame || !theme.currentGame.description || theme.currentGame.description.trim() === "") {
                                        return "No information about this game"
                                    }

                                    var desc = theme.currentGame.summary || theme.currentGame.description
                                    var maxLines = Math.floor(height / 30)

                                    var lines = desc.split('\n ' )

                                    if (lines.length > maxLines) {
                                        var shortened = lines.slice(0, maxLines).join('\n')
                                        return shortened.trim() + "..."
                                    }
                                    return desc
                                }
                                color: "white"
                                font.pixelSize: 30
                                font.family: bold.name
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: Math.floor(height / 30)
                            }

                            Item {
                                id: metadataContainer
                                property real imageBottomY: imageContainer.y + imageContainer.height
                                y: imageBottomY - height
                                anchors.left: parent.left
                                width: parent.width
                                height: 165

                                Column {
                                    anchors.fill: parent
                                    spacing: 10

                                    Row {
                                        width: parent.width
                                        spacing: 10
                                        Text { text: "Developer:"; color: "#808080"; font.pixelSize: 30; font.family: bold.name }
                                        Text { text: theme.currentGame && theme.currentGame.developer ? theme.currentGame.developer : "Unknown"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 10
                                        Text { text: "Publisher:"; color: "#808080"; font.pixelSize: 30; font.family: bold.name }
                                        Text { text: theme.currentGame && theme.currentGame.publisher ? theme.currentGame.publisher : "Unknown"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 10
                                        Text { text: "Genre:"; color: "#808080"; font.pixelSize: 30; font.family: bold.name }
                                        Text { text: theme.currentGame && theme.currentGame.genre ? theme.currentGame.genre : "Unknown"; color: "white"; font.pixelSize: 30; font.family: bold.name }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: 10
                                        Text { text: "Release:"; color: "#808080"; font.pixelSize: 30; font.family: bold.name }
                                        Text {
                                            text: {
                                                var g = theme.currentGame
                                                if (!g || !g.release) return "Unknown"
                                                return Qt.formatDate(g.release, "MMM d, yyyy")
                                            }
                                            color: "white"
                                            font.pixelSize: 30; font.family: bold.name
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Image {
                id: menuBackgroundBlur
                width: flick.contentWidth
                anchors.bottom: zone3.bottom
                anchors.top: zone2.top
                fillMode: Image.PreserveAspectCrop
                source: zone1.source
                opacity: 1
                z: -1
                visible: false
            }

            FastBlur {
                anchors.fill: menuBackgroundBlur
                source: menuBackgroundBlur
                radius: 100
                visible: !theme.highContrastGameMenu
                transform: Scale {
                    origin.x: menuBackgroundBlur.width / 2
                    origin.y: menuBackgroundBlur.height / 2
                    yScale: -1
                }
            }

            Rectangle {
                anchors.fill: menuBackgroundBlur
                color: "#222227"
                opacity: 0.96
                visible: !theme.highContrastGameMenu
                z: 2
            }
        } // Flickable

        // ---- FULLSCREEN OVERLAY (copied from media.qml) ----
        Item {
            id: fullscreenOverlay
            anchors.fill: parent
            visible: fullscreenView
            z: 1000

            Rectangle {
                id: fullscreenBg
                anchors.fill: parent
                color: "#090A0B"
                opacity: 1
                visible: fullscreenView
                z: 0
            }

            Timer {
                id: buttonsTimer
                interval: 3000
                running: fullscreenView
                repeat: false
                onTriggered: uiVisible = false
            }

            Item {
                id: fullscreenImageContainer
                z: 1
                anchors {
                    left: parent.left; right: parent.right
                    top: parent.top; bottom: parent.bottom
                    topMargin: 95
                    bottomMargin: 115
                    leftMargin: 40; rightMargin: 40
                }

                Image {
                    anchors.fill: parent
                    source: fullscreenScreenshots[currentScreenshotIndex] ? fullscreenScreenshots[currentScreenshotIndex] : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            // Кнопка ВЛЕВО
            Text {
                text: "<"
                color: "white"
                font.pixelSize: 70
                font.family: icons.name
                anchors { left: parent.left; leftMargin: 60; verticalCenter: parent.verticalCenter }
                z: 2
                opacity: uiVisible ? 1.0 : 0.0
                visible: currentScreenshotIndex > 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -30
                    onClicked: {
                        uiVisible = true
                        buttonsTimer.restart()
                        if (currentScreenshotIndex > 0) currentScreenshotIndex--
                    }
                }
            }

            // Кнопка ВПРАВО
            Text {
                text: ">"
                color: "white"
                font.pixelSize: 70
                font.family: icons.name
                anchors { right: parent.right; rightMargin: 60; verticalCenter: parent.verticalCenter }
                z: 2
                opacity: uiVisible ? 1.0 : 0.0
                visible: currentScreenshotIndex < fullscreenScreenshots.length - 1
                Behavior on opacity { NumberAnimation { duration: 300 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -30
                    onClicked: {
                        uiVisible = true
                        buttonsTimer.restart()
                        if (currentScreenshotIndex < fullscreenScreenshots.length - 1) currentScreenshotIndex++
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 0
                onClicked: {
                    uiVisible = true
                    buttonsTimer.restart()
                }
            }
        }
    } // animatedContent

    // ================= LAUNCH SCREEN OVERLAY =================
    Item {
        id: mainContentArea
        anchors.top: parent.top
        anchors.bottom: bottomBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: parent.height * 0.03
        z: 900
        opacity: 0

        Item {
            id: zoneThemeLogo
            height: parent.height * 0.5
            width: parent.width
            anchors.centerIn: parent

            AnimatedImage {
                id: themeLogo
                width: parent.width * 0.5
                height: parent.height * 0.9
                source: "../assets/logo/16_9.gif"
                fillMode: Image.PreserveAspectFit
                anchors.centerIn: parent
                playing: false
                opacity: 0
                scale: 0
            }
        }

        Rectangle {
            id: lineTop
            width: parent.width * 5/6
            height: 3
            color: "#20FEFEFE"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            property real offset: 0
            anchors.verticalCenterOffset: offset
            opacity: 0
        }

        Rectangle {
            id: lineBottom
            width: parent.width * 5/6
            height: 3
            color: "#20FEFEFE"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            property real offset: 0
            anchors.verticalCenterOffset: offset
            opacity: 0
        }

        Item {
            id: zoneGameInfoLS
            height: parent.height * 0.25
            width: parent.width
            anchors.top: parent.top
            property int animMargin: parent.height * 0.35
            anchors.topMargin: animMargin
            opacity: 0

            Item {
                id: logoContainer
                width: root.width * 0.3
                height: parent.height * 0.9
                anchors.centerIn: parent

                AnimatedImage{
                    id: gameLogoLS
                    visible: source != "" && !theme.highContrastLogo
                    anchors.fill: parent
                    source: theme.getAssetSource("logo", theme.currentGame)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true

                    Text {
                        visible: gameLogoLS.status !== Image.Ready || gameLogoLS.source == ""
                        anchors.fill: parent
                        text: theme.currentGame && theme.currentGame.title ? theme.currentGame.title : "Game"
                        color: "white"
                        font.pixelSize: 50
                        font.family: bold.name
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item {
            id: zoneLaunchStatus
            height: parent.height * 0.25
            width: parent.width
            anchors.bottom: parent.bottom
            property int animMargin: parent.height * 0.35
            anchors.bottomMargin: animMargin
            opacity: 0

            Row {
                id: launchStatusGroup
                anchors.centerIn: parent
                spacing: 20

                Item {
                    id: loadingCircles
                    width: 50; height: 50
                    anchors.verticalCenter: parent.verticalCenter
                    property int step: 0
                    Repeater {
                        model: 8
                        Rectangle {
                            property real opacityValue: 1.0 - (index * 0.125)
                            width: loadingCircles.width
                            height: loadingCircles.height
                            radius: width / 2
                            color: "transparent"
                            x: (loadingCircles.width - width) / 2
                            y: (loadingCircles.height - height) / 2
                            Rectangle {
                                width: 6; height: 10; radius: 7
                                color: "white"
                                opacity: opacityValue
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top; anchors.topMargin: 5
                            }
                            rotation: ((index - loadingCircles.step + 8) % 8) * 45
                        }
                    }
                    Timer {
                        interval: 70; running: root.isLaunching; repeat: true
                        onTriggered: loadingCircles.step = (loadingCircles.step + 1) % 8
                    }
                }

                Text {
                    id: launchText
                    text: "Launching executable"
                    color: "white"
                    font.pixelSize: 40
                    font.family: bold.name
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ================= ANIMATIONS =================
    SequentialAnimation {
        id: masterLaunchAnim

        ParallelAnimation {
            NumberAnimation { target: theme.gameLaunchingAnimation ? zone1 : null; property: "height"; to: root.height; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { target: theme.gameLaunchingAnimation ? zone1 : null; property: "opacity"; from: 0.9; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { target: theme.gameLaunchingAnimation ? zone2 : null; property: "y"; to: root.height + 100; duration: 600; easing.type: Easing.InBack }
            NumberAnimation { target: theme.gameLaunchingAnimation ? zone2_5 : null; property: "y"; to: root.height + 150; duration: 600; easing.type: Easing.InBack }
            NumberAnimation { target: theme.gameLaunchingAnimation ? zone3 : null; property: "y"; to: root.height + 200; duration: 600; easing.type: Easing.InBack }

            ParallelAnimation {
                NumberAnimation { target: theme.gameLaunchingAnimation ? logo : null; property: "y"; to: Math.round(-logo.height); duration: 600; easing.type: Easing.InBack }
                NumberAnimation { target: theme.gameLaunchingAnimation ? logo : null; property: "opacity"; to: 0; duration: 600; easing.type: Easing.InOutQuad }

                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    NumberAnimation { target: theme.gameLaunchingAnimation ? launchOverlay : null; property: "opacity"; from: 0; to: 0.3; duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }

        PauseAnimation { duration: 300 }

        NumberAnimation { target: theme.gameLaunchingAnimation ? mainContentArea : null; property: "opacity"; to: 1; duration: 100 }

        ParallelAnimation {
            NumberAnimation { target: theme.gameLaunchingAnimation ? zoneGameInfoLS : null; property: "opacity"; to: 1; duration: 600 }
            NumberAnimation {
                target: theme.gameLaunchingAnimation ? zoneGameInfoLS : null;
                property: "animMargin";
                from: Math.round(root.height * 0.1);
                to: Math.round(root.height * 0.21);
                duration: 700;
                easing.type: Easing.OutCubic
            }

            NumberAnimation { target: theme.gameLaunchingAnimation ? lineTop : null; property: "opacity"; to: 1; duration: 700 }
            NumberAnimation { target: theme.gameLaunchingAnimation ? lineBottom : null; property: "opacity"; to: 1; duration: 700 }

            NumberAnimation {
                target: theme.gameLaunchingAnimation ? lineBottom : null;
                property: "offset";
                from: Math.round(-root.height * 0.1);
                to: 0;
                duration: 700;
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: theme.gameLaunchingAnimation ? lineTop : null;
                property: "offset";
                from: Math.round(-root.height * 0.1);
                to: 0;
                duration: 700;
                easing.type: Easing.OutCubic
            }

            NumberAnimation { target: theme.gameLaunchingAnimation ? zoneLaunchStatus : null; property: "opacity"; to: 1; duration: 700 }
            NumberAnimation {
                target: theme.gameLaunchingAnimation ? zoneLaunchStatus : null;
                property: "animMargin";
                from: Math.round(root.height * 0.3);
                to: Math.round(root.height * 0.20);
                duration: 700;
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            PropertyAction { target: theme.gameLaunchingAnimation ? themeLogo : null; property: "playing"; value: true }

            NumberAnimation {
                target: theme.gameLaunchingAnimation ? lineTop : null; property: "offset";
                to: Math.round(-(zoneThemeLogo.height / 2));
                duration: 500; easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: theme.gameLaunchingAnimation ? lineBottom : null; property: "offset";
                to: Math.round(zoneThemeLogo.height / 2);
                duration: 500; easing.type: Easing.InOutQuad
            }

            NumberAnimation { target: theme.gameLaunchingAnimation ? zoneGameInfoLS : null; property: "animMargin"; to: 0; duration: 500; easing.type: Easing.InOutQuad }
            NumberAnimation { target: theme.gameLaunchingAnimation ? zoneLaunchStatus : null; property: "animMargin"; to: 0; duration: 500; easing.type: Easing.InOutQuad }

            NumberAnimation { target: theme.gameLaunchingAnimation ? themeLogo : null; property: "opacity"; to: 1; duration: 500; easing.type: Easing.InOutQuad }
            NumberAnimation { target: theme.gameLaunchingAnimation ? themeLogo : null; property: "scale"; from: 0; to: 1; duration: 500; easing.type: Easing.InOutQuad }
        }

        // DECKOS: under the launch cover, the wait happens over the loading game instead (its own time),
        // and the bars fade first, so no frozen clock or button hints sit over the game
        ParallelAnimation {
            NumberAnimation { target: root.coverLaunch ? topBar : null; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root.coverLaunch ? bottomBar : null; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
            PauseAnimation { duration: theme.gameLaunchingAnimation ? (root.coverLaunch ? 500 : 3200) : 0 }
        }

        ScriptAction { script: root.launchCurrentGame() }
    }


    ParallelAnimation {
        id: masterReverseAnim

        NumberAnimation { target: zone1; property: "height"; to: root.originalZone1Height; duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { target: zone1; property: "opacity"; to: 0.9; duration: 600; easing.type: Easing.InOutQuad }

        NumberAnimation { target: zone2; property: "y"; to: root.originalZone1Height; duration: 600; easing.type: Easing.OutBack }
        NumberAnimation { target: zone2_5; property: "y"; to: root.originalZone1Height + zone2.height; duration: 600; easing.type: Easing.OutBack }
        NumberAnimation { target: zone3; property: "y"; to: root.originalZone1Height + zone2.height + zone2_5.height; duration: 600; easing.type: Easing.OutBack }

        NumberAnimation { target: logo; property: "y"; to: Math.round((root.originalZone1Height - logo.height) / 2); duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { target: logo; property: "opacity"; to: 1; duration: 600; easing.type: Easing.InOutQuad }

        NumberAnimation { target: launchOverlay; property: "opacity"; to: 0; duration: 600; easing.type: Easing.OutCubic }
        NumberAnimation { target: topBar; property: "opacity"; to: 1; duration: 400; easing.type: Easing.OutCubic } // DECKOS: launch cover
        NumberAnimation { target: bottomBar; property: "opacity"; to: 1; duration: 400; easing.type: Easing.OutCubic }

        NumberAnimation { target: mainContentArea; property: "opacity"; to: 0; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: zoneGameInfoLS; property: "opacity"; to: 0; duration: 600 }
        NumberAnimation { target: lineTop; property: "opacity"; to: 0; duration: 600 }
        NumberAnimation { target: lineBottom; property: "opacity"; to: 0; duration: 600 }
        NumberAnimation { target: zoneLaunchStatus; property: "opacity"; to: 0; duration: 600 }
        NumberAnimation { target: themeLogo; property: "opacity"; to: 0; duration: 500; easing.type: Easing.InOutQuad }
        NumberAnimation { target: themeLogo; property: "scale"; to: 0; duration: 500; easing.type: Easing.InOutQuad }

        onFinished: {
            themeLogo.playing = false
            zoneGameInfoLS.animMargin = Math.round(root.height * 0.1)
            lineTop.offset = Math.round(-root.height * 0.1)
            lineBottom.offset = Math.round(-root.height * 0.1)
            zoneLaunchStatus.animMargin = Math.round(root.height * 0.3)

            zone2.y = undefined
            zone2_5.y = undefined
            zone3.y = undefined
            logo.y = undefined
        }
    }

    /* ================= TOP BAR ================= */
    Rectangle {
        id: topBar
        width: parent.width
        height: root.topH
        color: "transparent"
        z: 10000

        property real scrollRatio: (flick.contentHeight > flick.height)
            ? (flick.contentY / (flick.contentHeight - flick.height))
            : 0

        Rectangle {
            anchors.fill: parent
            color: leftBar.isOpen || topButtonsRow.focus ? Qt.rgba(0,0,0) : Qt.rgba(0, 0, 0, Math.min(topBar.scrollRatio / 0.4, 1))
            Behavior on color { ColorAnimation { duration: 100 } }
            z: -1
        }

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

            Rectangle {
                id: topBtnSearch
                width: topBar.width - (topBtnNet.width + topBarBattery.width + topBtnClock.width + topBtnUser.width + topButtonsRow.spacing * 3 + topButtonsRow.anchors.rightMargin * 2)
                height: root.topH
                color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "white" : "transparent"
                border.width: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? 2 : 0
                border.color: "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: "¿"
                    font.pixelSize: 35
                    font.family: icons.name
                    color: (topButtonsRow.currentIndex === 0 && topButtonsRow.focus) ? "black" : "white"

                    readonly property real posRight: topBtnSearch.width - 50
                    readonly property real posLeft: 15

                    x: posRight

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
                                PropertyAction { target: searchText; property: "visible"; value: true }
                                PauseAnimation { duration: 150 }
                                ParallelAnimation {
                                    NumberAnimation { target: searchText; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: searchText; property: "x"; to: searchText.targetX; duration: 100; easing.type: Easing.OutCubic }
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
                                PropertyAction { target: searchText; property: "visible"; value: false }
                            }
                        }
                    ]
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                            theme.openPage(9)
                        } else {
                            root.goToZone(0)
                            topButtonsRow.currentIndex = 0
                            topButtonsRow.forceActiveFocus()
                            sNav.stop();
                            sNav.play();
                        }
                    }
                }
            }

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
                        sNav.stop();
                        sNav.play();
                    }
                }
            }

            Item {
                id: topBarBattery
                width: theme.showBatteryPercent ? 170 : 70
                height: root.topH

                Rectangle {
                    id: batteryBg
                    anchors.fill: parent
                    color: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "white" : "transparent"
                    border.width: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? 2 : 0
                    border.color: "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    id: batteryRow
                    spacing: 5
                    anchors.centerIn: parent

                    function getBatteryIcon() {
                        if (isNaN(api.device.batteryPercent)) {
                            return "../assets/theme-icons/battery" + getSuffix() + ".png";
                        }
                        const batteryPercent = api.device.batteryPercent * 100;
                        if (batteryPercent <= 20) return "../assets/theme-icons/20" + getSuffix() + ".png";
                        else if (batteryPercent <= 40) return "../assets/theme-icons/40" + getSuffix() + ".png";
                        else if (batteryPercent <= 60) return "../assets/theme-icons/60" + getSuffix() + ".png";
                        else if (batteryPercent <= 80) return "../assets/theme-icons/80" + getSuffix() + ".png";
                        else return "../assets/theme-icons/battery" + getSuffix() + ".png";
                    }

                    function getSuffix() {
                        return (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "B" : "";
                    }

                    Text {
                        text: {
                            if (isNaN(api.device.batteryPercent)) return "N/A"
                            else return (api.device.batteryPercent * 100).toFixed(0) + "%"
                        }
                        color: (topButtonsRow.currentIndex === 2 && topButtonsRow.focus) ? "black" : "white"
                        font.family: bold.name
                        font.pixelSize: 36
                        visible: theme.showBatteryPercent
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        width: 57
                        height: 33
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
                            source: "../assets/theme-icons/charging" + batteryRow.getSuffix() + ".png"
                            mipmap: true
                            visible: api.device.batteryCharging
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!root.closeMenuVisible) {
                        root.goToZone(0)
                        topButtonsRow.currentIndex = 2
                        sNav.stop();
                        sNav.play();
                    }
                }
            }

            Rectangle {
                id: topBtnClock
                width: theme.use24HourFormat ? 130 : 200; height: root.topH
                color: "transparent"
                border.color: "transparent"

                property string timeFormat: theme.use24HourFormat ? "HH:mm" : "hh:mm AP"

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatTime(new Date(), topBtnClock.timeFormat)
                    font.pixelSize: 35
                    font.family: bold.name
                    color: "white"
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
                }

                onTimeFormatChanged: clockText.text = Qt.formatTime(new Date(), topBtnClock.timeFormat)
            }

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
                    playing: visible && status === AnimatedImage.Ready && (api.memory.has("animatedCovers") ? api.memory.get("animatedCovers") : false)
                    source: (root.theme && root.theme.profilePictureSource !== "") ? root.theme.profilePictureSource : "../assets/logo/logo.jpg" /* DECKOS */
                    fillMode: Image.PreserveAspectFit
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

            Keys.onLeftPressed:{ if (topButtonsRow.currentIndex > 0) topButtonsRow.currentIndex--; sNav.stop(); sNav.play(); }
            Keys.onRightPressed: {if (topButtonsRow.currentIndex < 3) topButtonsRow.currentIndex++; sNav.stop(); sNav.play(); }
            Keys.onDownPressed: {root.goToZone(1); sNav.stop(); sNav.play(); }
            Keys.onPressed:
                if (event.key === Qt.Key_Return || api.keys.isAccept(event)){
                    if (root.focusZone === 0 && topButtonsRow.currentIndex === 0) {
                        theme.openPage(9)
                    }
                }
        }
    }

    /* ================= BOTTOM BAR ================= */
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
            opacity: theme.highContrastBottomBar ? 1.0 : (leftBar.isOpen || root.closeMenuVisible || root.optionsMenuVisible ? 0.9 : 0.6)

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
                onClicked: if (!root.closeMenuVisible) {
                    leftBar.toggle()
                    leftBar.currentIndex = theme ? theme.currentPage : 0 // DECKOS: theme is assigned after creation
                    leftBar.updateFocus()
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
                anchors.verticalCenter: parent.verticalCenter
                Text { text: theme.nintendoLayout ? (theme.universalIcons ? "В" : "B") : (theme.universalIcons ? "А" : "A"); font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025}
                Text { text: "SELECT"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23 }
            }

            Rectangle {
                id: btnBack
                width: 140; height: parent.height
                color: "transparent"
                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Text { text: theme.nintendoLayout ? (theme.universalIcons ? "А" : "A") : (theme.universalIcons ? "В" : "B"); font.family: icons.name; font.pixelSize: 53; color: "white";y:parent.height * -0.025}
                    Text { text: "BACK"; font.family: bold.name; font.pixelSize: 25; color: "white";y:parent.height *0.23 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!root.closeMenuVisible) {
                            if (root.isLaunching && !theme.gameLaunchingAnimation) {
                                root.cancelLaunchAnimation()
                            } else if (fullscreenView) {
                                root.toggleFullscreen()
                            } else {
                                if (api.memory.previousPage !== undefined) {
                                    theme.openPage(api.memory.previousPage);
                                } else {
                                    theme.openPage(0);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

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
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        property bool isOpen: false
        property int currentIndex: 0
        property var buttons: []

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
                        visible: buttonIndex  === 0

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
                            font.family: icons.name
                            font.pixelSize: menuPanel.width * 0.075
                            color: "white"
                            verticalAlignment: Text.AlignVCenter // DECKOS: was parent.verticalCenter (an anchor line)
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: title
                            font.family: bold.name
                            font.pixelSize: menuPanel.width * 0.075
                            color: "white"
                            verticalAlignment: Text.AlignVCenter // DECKOS: was parent.verticalCenter (an anchor line)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Keys.onPressed: {
                    if (leftBar.isOpen) {
                        event.accepted = true;
                        if (event.key === Qt.Key_Up) {
                            if (leftBar.currentIndex > 0) {
                                leftBar.currentIndex--;
                                leftBar.updateFocus();
                                sNav.stop();
                                sNav.play();
                            }
                        } else if (event.key === Qt.Key_Down) {
                            if (leftBar.currentIndex < leftBar.buttons.length - 1) {
                                leftBar.currentIndex++;
                                leftBar.updateFocus();
                                sNav.stop();
                                sNav.play();
                            }
                        } else if (event.key === Qt.Key_Return || api.keys.isAccept(event)) {
                            if (leftBar.currentIndex === 7) {
                                leftBar.toggle();
                                root.closeMenuVisible = true;
                            } else {
                                theme.openPage(leftBar.currentIndex);
                                leftBar.toggle();
                                if (leftBar.currentIndex === 6) sShowui.play();
                            }
                        } else if (api.keys.isMenu(event) || api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_Right) {
                            leftBar.toggle();
                            focusTimer.start();
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (leftBar.currentIndex === buttonIndex) {
                            if (buttonIndex === 7) {
                                leftBar.toggle()
                                closeMenu.forceActiveFocus()
                                closeMenuVisible = true
                            } else {
                                theme.openPage(buttonIndex)
                                leftBar.toggle()
                                if (buttonIndex === 6) {
                                    sShowui.play()
                                }
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
            var btn1 = menuButtonComponent.createObject(buttonColumn, { "title": "Home", "buttonIndex": 0, "icon": "^" })
            var btn2 = menuButtonComponent.createObject(buttonColumn, { "title": "Library", "buttonIndex": 1, "icon": "L" })
            var btn3 = menuButtonComponent.createObject(buttonColumn, { "title": "Store", "buttonIndex": 2, "icon": "€" })
            var btn4 = menuButtonComponent.createObject(buttonColumn, { "title": "Friends and Chat", "buttonIndex": 3, "icon": "F" })
            var btn5 = menuButtonComponent.createObject(buttonColumn, { "title": "Media", "buttonIndex": 4, "icon": "M" })
            var btn6 = menuButtonComponent.createObject(buttonColumn, { "title": "Downloads", "buttonIndex": 5, "icon": "♠︎" })
            var btn7 = menuButtonComponent.createObject(buttonColumn, { "title": "Settings", "buttonIndex": 6, "icon": "w" })
            var btn8 = menuButtonComponent.createObject(buttonColumn, { "title": "Close", "buttonIndex": 7, "icon": "C" })
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
        z: 99

        opacity: closeMenuVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        property int currentButtonIndex: 0
        property var buttons: [exitButton, cancelButton]

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
                font.family: bold.name
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
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 0) {
                                closeMenu.currentButtonIndex = 0
                                sNav.stop();
                                sNav.play();
                            } else {
                                Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                            }
                        }
                    }
                }

                Rectangle {
                    id: cancelButton
                    width: parent.width
                    height: parent.height / 2
                    color: closeMenu.currentButtonIndex === 1 ? "white" : "transparent"

                    Text {
                        text: "   Cancel"
                        color: closeMenu.currentButtonIndex === 1 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (closeMenu.currentButtonIndex !== 1) {
                                closeMenu.currentButtonIndex = 1
                                sNav.stop();
                                sNav.play();
                            } else {
                                closeMenuVisible = false
                                sLeftClose.play()
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
                        sNav.stop();
                        sNav.play();
                    }
                    event.accepted = true
                }
                else if (event.key === Qt.Key_Down) {
                    if (currentButtonIndex < 1) {
                        currentButtonIndex++
                        sNav.stop();
                        sNav.play();
                    }
                    event.accepted = true
                }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    event.accepted = true
                }
                else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape){
                }
                else if (api.keys.isMenu(event)) {
                }
                else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    if (currentButtonIndex === 0) {
                        event.accepted = true
                        Internal.system.quit() /* DECKOS: was Qt.quit(), which skips DeckOS's shutdown (saving play time etc.) */
                        return
                    } else if (currentButtonIndex === 1) {
                        closeMenuVisible = false
                        sLeftClose.play()
                        focusTimer.start()
                    }
                    event.accepted = true
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                currentButtonIndex = 0
                sShowui.play()
                forceActiveFocus()
            }
        }
    }

    /* ================= OPTIONS MENU ================= */
    FocusScope {
        id: optionsMenu
        width: parent.width
        height: parent.height
        visible: optionsMenuVisible
        focus: optionsMenuVisible
        enabled: visible
        z: 99

        opacity: optionsMenuVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        property int currentButtonIndex: 0
        property var buttons: [favoriteButton, propertiesButton, artworkButton, cancelButton1]

        Item {
            id: optionsOverlay
            anchors.fill: parent
            z: 0
            visible: optionsMenu.visible

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
            height: 400
            anchors.centerIn: parent
            color: "#181B20"

            Text {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: -65
                }
                text: currentFocusedGame ? currentFocusedGame.title : "No game selected"
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
                    id: favoriteButton
                    width: parent.width
                    height: parent.height / 4
                    color: optionsMenu.currentButtonIndex === 1 ? "white" : "transparent"

                    Text {
                        text: {
                            if (currentFocusedGame) {
                                return currentFocusedGame.favorite ? "   Delete from favorites" : "   Add to favorites"
                            }
                            return "   Add to favorites"
                        }
                        color: optionsMenu.currentButtonIndex === 1 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (optionsMenu.currentButtonIndex !== 1) {
                                optionsMenu.currentButtonIndex = 1
                                sNav.stop(); sNav.play();
                            } else {
                                if (currentFocusedGame) {
                                    currentFocusedGame.favorite = !currentFocusedGame.favorite
                                    root.toggleOptionsMenu()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: propertiesButton
                    width: parent.width
                    height: parent.height / 4
                    color: optionsMenu.currentButtonIndex === 2 ? "white" : "transparent"

                    Text {
                        text: "   Properties"
                        color: optionsMenu.currentButtonIndex === 2 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (optionsMenu.currentButtonIndex !== 2) {
                                optionsMenu.currentButtonIndex = 2
                                sNav.stop(); sNav.play();
                            } else {
                                if (currentFocusedGame) {
                                    api.memory.set("targetGameName", currentFocusedGame.title)
                                    theme.currentGame = currentFocusedGame
                                }
                                root.toggleOptionsMenu()
                                theme.openPage(14)
                            }
                        }
                    }
                }

                Rectangle {
                    id: artworkButton
                    width: parent.width
                    height: parent.height / 4
                    color: optionsMenu.currentButtonIndex === 3 ? "white" : "transparent"

                    Text {
                        text: "   Change artwork..."
                        color: optionsMenu.currentButtonIndex === 3 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (optionsMenu.currentButtonIndex !== 3) {
                                optionsMenu.currentButtonIndex = 3
                                sNav.stop(); sNav.play();
                            } else {
                                if (currentFocusedGame) {
                                    api.memory.set("targetGameName", currentFocusedGame.title)
                                }
                                root.toggleOptionsMenu()
                                theme.openPage(12)
                            }
                        }
                    }
                }

                Rectangle {
                    id: cancelButton1
                    width: parent.width
                    height: parent.height / 4
                    color: optionsMenu.currentButtonIndex === 4 ? "white" : "transparent"

                    Text {
                        text: "   Cancel"
                        color: optionsMenu.currentButtonIndex === 4 ? "black" : "white"
                        font.pixelSize: 35
                        font.family: bold.name
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (optionsMenu.currentButtonIndex !== 4) {
                                optionsMenu.currentButtonIndex = 4
                                sNav.stop(); sNav.play();
                            } else {
                                root.toggleOptionsMenu()
                                sLeftClose.play()
                            }
                        }
                    }
                }
            }
        }

        Keys.onPressed: {
            if (optionsMenuVisible && optionsMenu.focus) {
                if (event.key === Qt.Key_Up) {
                    if (currentButtonIndex > 1) {
                        currentButtonIndex--
                        sNav.stop(); sNav.play();
                    }
                    event.accepted = true
                }
                else if (event.key === Qt.Key_Down) {
                    if (currentButtonIndex < 4) {
                        currentButtonIndex++
                        sNav.stop(); sNav.play();
                    }
                    event.accepted = true
                }
                else if (api.keys.isAccept(event) || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                    if (currentButtonIndex === 1) {
                        if (currentFocusedGame) {
                            currentFocusedGame.favorite = !currentFocusedGame.favorite
                            root.toggleOptionsMenu()
                        }
                    } else if (currentButtonIndex === 2) {
                        if (currentFocusedGame) { theme.currentGame = currentFocusedGame; api.memory.set("targetGameName", currentFocusedGame.title) } root.toggleOptionsMenu(); theme.openPage(14) // DECKOS: Properties did nothing with a controller (mouse only)
                    } else if (currentButtonIndex === 3) {
                        root.toggleOptionsMenu()
                        openPage(12)
                    } else if (currentButtonIndex === 4) {
                        sLeftClose.play()
                        root.toggleOptionsMenu()
                    }
                    event.accepted = true
                }
                else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape || event.key === Qt.Key_B) {
                    root.toggleOptionsMenu()
                    sLeftClose.play()
                    event.accepted = true
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                currentButtonIndex = 1
                forceActiveFocus()
            }
        }
    }

    property int nextPageIndex: 0

    function startExitAnimation(index) {
        if (index === 12 || index === 14) {
            api.memory.set("steamGridSource", 8)
        }
        nextPageIndex = index
        exitAnim.start()
    }

    Component.onCompleted: {
        enterAnim.start()
        goToZone(1)
        zone2.currentButtonIndex = 0
        zone2.forceActiveFocus()
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
    
    SequentialAnimation {
        id: fullimageAnim
        ParallelAnimation {
            NumberAnimation { target: animatedContent; property: "opacity"; to: 0; duration: 225; easing.type: Easing.InQuad }
            NumberAnimation { target: animatedContent; property: "scale"; to: 0.95; duration: 225; easing.type: Easing.InQuad }
        }
    }

    Timer {
        id: focusTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            if (!closeMenuVisible && !optionsMenuVisible && !fullscreenView) {
                if (zone3Tabs.currentIndex === 1) {
                    if (yourStuffContent.mediaCount > 0) {
                        stuffGrid.forceActiveFocus()
                    } else {
                        mediaBtn.forceActiveFocus()
                    }
                } else {
                    zone2.forceActiveFocus()
                    zone2.currentButtonIndex = 0
                }
            }
        }
    }

    // DECKOS: on Android DeckOS stays loaded while the game runs; back from it, undo the launch animation
    // and reload what the session changed (achievements; play time and last played update by themselves)
    Connections {
        target: (typeof deckos !== "undefined" && deckos) ? deckos.ingame : null
        function onPlayingChanged() {
            if (deckos.ingame.playing) return
            if (root.isLaunching) root.cancelLaunchAnimation()
            raSection.load()
        }
    }

}
