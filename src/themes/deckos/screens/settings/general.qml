// DECKOS: Settings > General, rebuilt on DeckSettingsPage. StMini's page only had a placeholder
// language box and the clock format; Pegasus's general settings live here now.
import QtQuick 2.15
import QtQml 2.15
import "parts"

DeckSettingsPage {
    id: generalPage
    title: "General"

    readonly property var th: (typeof theme !== "undefined" && theme) ? theme : null
    readonly property bool isAndroid: Qt.platform.os === "android"

    Instantiator { id: localeList; model: Internal.settings.locales; delegate: QtObject { readonly property string name: model.name } }

    readonly property var hideDelays: [
        { label: "Immediately", value: 0 },
        { label: "After 2 seconds", value: 2 },
        { label: "After 5 seconds", value: 5 },
        { label: "After 10 seconds", value: 10 },
        { label: "Never", value: -1 }
    ]
    function hideDelayIndex() {
        for (var i = 0; i < hideDelays.length; i++)
            if (hideDelays[i].value === Internal.settings.hideDelayAfterLaunch) return i
        return 0
    }
    readonly property var trailerModes: ["Off", "Muted", "With sound"]
    readonly property var trailerDelays: [2, 3, 5, 8]
    function cycleTrailerDelay(step) {
        if (!th) return
        var i = trailerDelays.indexOf(th.trailerDelay)
        var n = trailerDelays.length
        th.trailerDelay = trailerDelays[((i < 0 ? 1 : i) + step + n) % n]
    }
    function cycleLocale(step) {
        var n = localeList.count
        if (n < 2) return
        Internal.settings.locales.currentIndex = (Internal.settings.locales.currentIndex + step + n) % n
    }
    function cycleHideDelay(step) {
        var n = hideDelays.length
        Internal.settings.hideDelayAfterLaunch = hideDelays[(hideDelayIndex() + step + n) % n].value
    }

    function buildRows() {
        var r = []
        r.push({ type: "choice", label: "Language",
                 value: function () { return Internal.settings.locales.currentName },
                 next: function () { generalPage.cycleLocale(1) }, prev: function () { generalPage.cycleLocale(-1) } })
        r.push({ type: "toggle", label: "24-Hour Format", desc: "Display time in 24-hour format.",
                 value: function () { return th ? th.use24HourFormat : true },
                 toggle: function () { if (th) th.use24HourFormat = !th.use24HourFormat } })
        if (!isAndroid)
            r.push({ type: "toggle", label: "Fullscreen",
                     value: function () { return Internal.settings.fullscreen },
                     toggle: function () { Internal.settings.fullscreen = !Internal.settings.fullscreen } })
        r.push({ type: "toggle", label: "Mouse and touch",
                 desc: "Show the pointer and react to clicks and taps",
                 value: function () { return Internal.settings.mouseSupport },
                 toggle: function () { Internal.settings.mouseSupport = !Internal.settings.mouseSupport } })
        // DECKOS: Android keeps DeckOS loaded while playing instead (Settings > Overlay); PC only
        if (!isAndroid)
            r.push({ type: "choice", label: "Hide DeckOS after launching a game",
                     desc: "When the game takes over the screen",
                     value: function () { return generalPage.hideDelays[generalPage.hideDelayIndex()].label },
                     next: function () { generalPage.cycleHideDelay(1) }, prev: function () { generalPage.cycleHideDelay(-1) } })

        // DECKOS: the game page's trailer (the game's video behind its logo)
        r.push({ type: "section", label: "Game page" })
        r.push({ type: "choice", label: "Trailers",
                 desc: "The game's video fades in behind its logo after a few seconds",
                 value: function () { return th ? generalPage.trailerModes[th.trailerMode] : "Muted" },
                 next: function () { if (th) th.trailerMode = (th.trailerMode + 1) % 3 },
                 prev: function () { if (th) th.trailerMode = (th.trailerMode + 2) % 3 } })
        r.push({ type: "choice", label: "Trailer delay",
                 enabled: function () { return !!th && th.trailerMode > 0 },
                 value: function () { return th ? th.trailerDelay + " seconds" : "3 seconds" },
                 next: function () { generalPage.cycleTrailerDelay(1) }, prev: function () { generalPage.cycleTrailerDelay(-1) } })
        return r
    }
    rows: buildRows()
}
