// Pegasus Frontend
// Copyright (C) 2017-2018  Mátyás Mustoha
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.


import "qrc:/qmlutils" as PegasusUtils
import QtQuick 2.8
import QtQuick.Window 2.2


Window {
    id: appWindow
    visible: true
    width: 1280
    height: 720
    title: "DeckOS" // DECKOS
    color: "#000"

    visibility: Internal.settings.fullscreen
                ? Window.FullScreen : Window.AutomaticVisibility

    onClosing: {
        theme.source = "";
        Internal.system.quit();
    }

    FontLoader { id: sansFont; source: "/fonts/Roboto-Regular.ttf" }
    FontLoader { id: sansBoldFont; source: "/fonts/Roboto-Bold.ttf" }
    FontLoader { id: monoFont; source: "/fonts/RobotoMono-Regular.ttf" }
    FontLoader { id: condensedFont; source: "/fonts/RobotoCondensed-Regular.ttf" }
    FontLoader { id: condensedBoldFont; source: "/fonts/RobotoCondensed-Bold.ttf" }


    // a globally avalable utility object
    QtObject {
        id: global

        readonly property real winScale: Math.min(width / 1280.0, height / 720.0)

        property QtObject fonts: QtObject {
            readonly property string sans: sansFont.name
            readonly property string sansBold: sansBoldFont.name
            readonly property string condensed: condensedFont.name
            readonly property string condensedBold: condensedBoldFont.name
            readonly property string mono: monoFont.name
        }
    }


    // legacy global objects
    QtObject {
        id: globalFonts
        readonly property string sans: global.fonts.sans
        readonly property string condensed: global.fonts.condensed
    }
    function vpx(value) {
        return global.winScale * value;
    }


    // the main content
    FocusScope {
        id: content
        anchors.fill: parent
        // DECKOS: the hidden interface ignores buttons under the boot screen. Under the scan's loading screen
        // it stays enabled (only unfocused), so each page keeps the item it had selected.
        enabled: (focus || libraryLoading.activeFocus) && !splashScreen.shown

        Loader {
            id: theme
            anchors.fill: parent

            focus: true
            enabled: focus

            readonly property url apiThemePath: Internal.settings.themes.currentQmlPath
            // DECKOS: the built-in theme has every setting in its own Settings screen, so Pegasus's menu
            // and its "no games" screen are only used with third-party themes (which have no settings UI)
            readonly property bool builtinTheme: String(apiThemePath).indexOf("themes/deckos/theme.qml") >= 0

            function getThemeFile() {
                if (Internal.scanner.running)
                    return "";
                if (api.collections.count === 0 && !builtinTheme)
                    return "messages/NoGamesError.qml";

                return apiThemePath;
            }
            onApiThemePathChanged: source = Qt.binding(getThemeFile)

            Keys.onPressed: {
                if (!builtinTheme && (api.keys.isCancel(event) || api.keys.isMenu(event))) {
                    event.accepted = true;
                    mainMenu.focus = true;
                }

                if (event.key === Qt.Key_F5) {
                    event.accepted = true;

                    theme.source = "";
                    Internal.meta.clearQMLCache();
                    theme.source = Qt.binding(getThemeFile);
                }
            }

            source: getThemeFile()
            asynchronous: true
            onStatusChanged: {
                if (status == Loader.Error)
                    source = "messages/ThemeError.qml";
            }
            onLoaded: item.focus = focus
            onFocusChanged: if (item) item.focus = focus
        }

        Loader {
            id: mainMenu
            anchors.fill: parent

            source: "MenuLayer.qml"
            asynchronous: true

            onLoaded: item.focus = focus
            onFocusChanged: if (item) item.focus = focus
            enabled: focus
        }
        Connections {
            target: mainMenu.item

            function onClose() { theme.focus = true; }

            function onRequestShutdown() {
                powerDialog.source = "dialogs/ShutdownDialog.qml"
                powerDialog.focus = true;
            }
            function onRequestSuspend() {
                Internal.system.suspend()
            }                        
            function onRequestReboot() {
                powerDialog.source = "dialogs/RebootDialog.qml"
                powerDialog.focus = true;
            }
            function onRequestQuit() {
                theme.source = "";
                Internal.system.quit();
            }
        }
        PegasusUtils.HorizontalSwipeArea {
            id: menuSwipe
            enabled: !theme.builtinTheme // DECKOS: see builtinTheme

            width: vpx(40)
            height: parent.height
            anchors.right: parent.right

            onSwipeLeft: {
                if (!mainMenu.focus)
                    mainMenu.focus = true;
            }
        }
    }


    Loader {
        id: powerDialog
        anchors.fill: parent
    }
    Connections {
        target: powerDialog.item
        function onCancel() { content.focus = true; }
    }


    Loader {
        id: multifileSelector
        anchors.fill: parent
    }
    Connections {
        target: multifileSelector.item
        function onCancel() { content.focus = true; }
    }


    Loader {
        id: genericMessage
        anchors.fill: parent
    }
    Connections {
        target: genericMessage.item
        function onClose() { content.focus = true; }
    }


    Connections {
        target: api
        function onEventSelectGameFile(game) {
            multifileSelector.setSource("dialogs/MultifileSelector.qml", {"game": game})
            multifileSelector.focus = true;
        }
        function onEventLaunchError(msg) {
            genericMessage.setSource("dialogs/GenericOkDialog.qml",
                { "title": qsTr("Error"), "message": msg });
            genericMessage.focus = true;
        }
    }
    Connections {
        target: Internal.scanner
        function onRunningChanged() {
            if (Internal.scanner.running) {
                splashScreen.shown = true;
                splashScreen.focus = true;
            }
        }
    }


    // DECKOS: boot animation instead of Pegasus's splash; fades out into the interface
    BootLayer {
        id: splashScreen
        focus: true
        // DECKOS: shown/hidden by `shown`, not by focus: the theme takes focus as soon as it loads (about a
        // second in), which used to fade the boot animation out long before it ended
        property bool shown: true
        opacity: shown ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        // the video is dropped only after the fade, so its last frame (the logo) fades out instead of black
        onVisibleChanged: if (!visible) playVideo = false // once per start; later reloads show only the progress line

        readonly property bool dataLoading: Internal.scanner.running
        readonly property bool skinLoading: theme.status === Loader.Null || theme.status === Loader.Loading

        loading: dataLoading || skinLoading
        showDataProgressText: dataLoading
        // DECKOS: Settings > Customization > "Show Boot Animation" (the built-in theme's memory is loaded
        // before this window is created)
        playVideo: !(api.memory.has("showBootAnimation") && api.memory.get("showBootAnimation") === false)
        progress: Internal.scanner.progress
        stage: Internal.scanner.stage

        function hideMaybe() {
            if (shown && !dataLoading && !skinLoading && videoDone) {
                shown = false;
                content.focus = true;
                Internal.scanner.reset();
            }
        }

        onSkinLoadingChanged: hideMaybe()
        onDataLoadingChanged: hideMaybe()
        onVideoDoneChanged: hideMaybe()
    }

    // DECKOS: a ROM scan the user asked for, then the library reload: one loading screen with a progress
    // bar and tips over everything (also over the boot screen, after the first start)
    LibraryLoading {
        id: libraryLoading
        reloading: splashScreen.shown && !splashScreen.playVideo
        onReleased: content.focus = true
    }
}
