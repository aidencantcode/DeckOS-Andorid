// DECKOS: Settings > Overlay - the Android in-game layer (deckos.ingame, Java com.deckos.ingame):
// the Quick Access menu over games (how it opens, its size, whether the game keeps running), the
// performance overlay, the launch cover, the AYN / Retroid controls it uses, and the device check. The overlay's own
// Overlay tab changes the same values (shared Android preferences), so both always agree.
import QtQuick 2.15
import "parts"

DeckSettingsPage {
    id: ingamePage
    title: "Overlay"

    readonly property var ig: (typeof deckos !== "undefined" && deckos) ? deckos.ingame : null
    readonly property bool android: !!ig && ig.available
    readonly property var levelNames: ["Off", "1 - Battery and play time", "2 - One bar", "3 - Detailed", "4 - Everything"]
    readonly property var shortcutNames: ["Off", "Select + Start", "Select + R1", "L3 + R3"]
    readonly property var positionNames: ["Top left", "Top right", "Bottom left", "Bottom right"]
    readonly property var scales: [75, 90, 100, 110, 125, 150, 175, 200]
    readonly property var coverTimes: [2, 3, 5, 8, 12, 20]
    property string importMessage: ""

    // permissions are granted in Android's settings: look again whenever DeckOS comes back
    Connections {
        target: Qt.application
        function onStateChanged() { if (Qt.application.state === Qt.ApplicationActive && ingamePage.ig) ingamePage.ig.recheck() }
    }

    function cycle(value, count, step) { return (value + step + count) % count }
    function scaleStep(step) {
        if (!ig) return
        var i = scales.indexOf(ig.overlayScale)
        if (i < 0) i = 4
        ig.overlayScale = scales[Math.max(0, Math.min(scales.length - 1, i + step))]
    }

    function coverStep(step) {
        if (!ig) return
        var i = 0
        while (i < coverTimes.length - 1 && coverTimes[i] < ig.launchCoverSeconds) i++
        ig.launchCoverSeconds = coverTimes[Math.max(0, Math.min(coverTimes.length - 1, i + step))]
    }

    // "Device info": the page shows the dump instead of the settings until B
    property bool showingInfo: false
    property string infoText: ""
    backHandler: function () { if (!showingInfo) return false; showingInfo = false; return true }
    function infoRows() {
        var r = [{ type: "button", label: "Copy to clipboard", accent: true,
                   desc: "Paste it into a message to the DeckOS developer",
                   activate: function () { clipboard.text = ingamePage.infoText; clipboard.selectAll(); clipboard.copy(); ingamePage.importMessage = "Copied" },
                   value: function () { return ingamePage.importMessage === "Copied" ? "✓" : "" } }]
        var lines = infoText.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.trim() === "") continue
            if (line.charAt(0) !== " " && line.charAt(line.length - 1) === ":")
                r.push({ type: "section", label: line.slice(0, -1) })
            else
                r.push({ type: "info", label: line.trim() })
        }
        return r
    }
    TextEdit { id: clipboard; visible: false }

    function buildRows() {
        if (showingInfo) return infoRows()
        var r = []
        r.push({ type: "section", label: "Quick Access menu" })
        r.push({ type: "toggle", label: "In-game notification",
                 desc: "Shows the game and its play time while DeckOS is in the background. Tap it for the quick access menu.",
                 value: function () { return ig ? ig.notification : false },
                 enabled: function () { return !!ig },
                 toggle: function () { if (ig) ig.notification = !ig.notification } })
        r.push({ type: "choice", label: "Controller shortcut",
                 desc: function () {
                     if (!android) return "Android only"
                     return ig.shortcutEnabled ? "Opens the menu over any game"
                                               : "Needs DeckOS's accessibility service - turn it on below"
                 },
                 value: function () { return ig ? ingamePage.shortcutNames[ig.shortcut] : "Off" },
                 enabled: function () { return !!ig },
                 next: function () { ig.shortcut = ingamePage.cycle(ig.shortcut, 4, 1) },
                 prev: function () { ig.shortcut = ingamePage.cycle(ig.shortcut, 4, -1) } })
        r.push({ type: "button", label: "Turn on the controller shortcut",
                 desc: "Android › Accessibility › DeckOS controller shortcut. It only watches controller buttons.",
                 value: function () { return ig && ig.shortcutEnabled ? "✓" : "" },
                 enabled: function () { return android && !ig.shortcutEnabled },
                 activate: function () { if (ig) ig.openAccessibilitySettings() } })
        r.push({ type: "toggle", label: "Keep game running",
                 desc: "The game keeps running behind the menu instead of pausing. Needs \"Display over other apps\".",
                 value: function () { return ig ? ig.keepRunning : false },
                 enabled: function () { return !!ig },
                 toggle: function () { if (ig) ig.keepRunning = !ig.keepRunning } })
        r.push({ type: "choice", label: "Menu and overlay size",
                 desc: "Also in the menu itself (Overlay tab), where it changes as you move it",
                 value: function () { return ig ? ig.overlayScale + "%" : "125%" },
                 enabled: function () { return !!ig },
                 next: function () { ingamePage.scaleStep(1) }, prev: function () { ingamePage.scaleStep(-1) } })

        r.push({ type: "section", label: "Performance overlay" })
        r.push({ type: "choice", label: "Level",
                 desc: "Battery, CPU, GPU, memory, temperatures and frame rate over the game, like the Steam Deck",
                 value: function () { return ig ? ingamePage.levelNames[ig.hudLevel] : "Off" },
                 enabled: function () { return !!ig },
                 next: function () { ig.hudLevel = ingamePage.cycle(ig.hudLevel, 5, 1) },
                 prev: function () { ig.hudLevel = ingamePage.cycle(ig.hudLevel, 5, -1) } })
        r.push({ type: "choice", label: "Position",
                 value: function () { return ig ? ingamePage.positionNames[ig.hudPosition] : "Top left" },
                 enabled: function () { return !!ig },
                 next: function () { ig.hudPosition = ingamePage.cycle(ig.hudPosition, 4, 1) },
                 prev: function () { ig.hudPosition = ingamePage.cycle(ig.hudPosition, 4, -1) } })
        r.push({ type: "toggle", label: "Show frame rate",
                 desc: function () { return ig && ig.privileged ? "Read through the AYN / Retroid system service"
                                                               : "Needs the AYN / Retroid system service (not found on this device)" },
                 value: function () { return ig ? ig.showFps : false },
                 enabled: function () { return !!ig },
                 toggle: function () { if (ig) ig.showFps = !ig.showFps } })
        r.push({ type: "button", label: "Allow drawing over games",
                 desc: function () {
                     if (!android) return "Android only"
                     return ig.overlayAllowed ? "Allowed" : "Android's \"Display over other apps\" - for the performance overlay and Keep game running"
                 },
                 value: function () { return ig && ig.overlayAllowed ? "✓" : "" },
                 enabled: function () { return android && !ig.overlayAllowed },
                 activate: function () { if (ig) ig.requestOverlayPermission() } })

        r.push({ type: "section", label: "Game launch" })
        r.push({ type: "toggle", label: "Hide emulator loading screens",
                 desc: function () {
                     if (!android) return "Android only"
                     if (typeof theme !== "undefined" && theme && !theme.gameLaunchingAnimation) return "Needs the game launch animation (Settings › Accessibility)"
                     if (!ig.launchCoverPossible) return "Needs \"Display over other apps\" (above) or the controller shortcut"
                     return "The launch screen stays over the game while it starts, then fades away to it. With the controller shortcut on, any button shows the game sooner."
                 },
                 value: function () { return ig ? ig.launchCover : false },
                 enabled: function () { return !!ig },
                 toggle: function () { if (ig) ig.launchCover = !ig.launchCover } })
        r.push({ type: "choice", label: "Keep the launch screen for",
                 desc: "Longer for slow starters (Winlator)",
                 value: function () { return (ig ? ig.launchCoverSeconds : 5) + " seconds" },
                 enabled: function () { return !!ig && ig.launchCover },
                 next: function () { ingamePage.coverStep(1) }, prev: function () { ingamePage.coverStep(-1) } })

        r.push({ type: "section", label: "Device (AYN / Retroid)" })
        r.push({ type: "info", label: "Performance mode, fan and underclock",
                 desc: function () { return ig && ig.privileged ? "In the quick access menu's Performance tab"
                                                               : "Need the AYN / Retroid system service (PServer), which wasn't found" } })
        r.push({ type: "button", label: "Underclocking profiles",
                 desc: "ClusterTune is built in: its presets, your own profiles and ClusterTune files are in Settings › Underclocking",
                 activate: function () { if (typeof theme !== "undefined" && theme) theme.openSettingsPage("settings/underclock.qml") } })
        r.push({ type: "button", label: "Device info",
                 desc: "Model, chip, system service, vendor settings and sensors - to check a new handheld",
                 enabled: function () { return !!ig },
                 activate: function () {
                     ingamePage.infoText = ig.deviceInfo()
                     ingamePage.importMessage = ""
                     ingamePage.showingInfo = true
                     ingamePage.activeItemIndex = 0
                 } })

        r.push({ type: "section", label: "DeckOS" })
        r.push({ type: "toggle", label: "Keep DeckOS loaded while playing",
                 desc: "Coming back from a game is instant and lands where you left, and play time is counted until you return. Turn off to give the game DeckOS's memory (DeckOS then restarts after each game).",
                 value: function () { return ig ? ig.keepLoaded : true },
                 enabled: function () { return !!ig },
                 toggle: function () { if (ig) ig.keepLoaded = !ig.keepLoaded } })
        return r
    }

    rows: (showingInfo, buildRows())
}
