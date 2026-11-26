// DECKOS: Settings > Customization, rebuilt on DeckSettingsPage, with StMini's Accessibility page merged
// in (owner request). StMini's own SteamGridDB key field is gone: Settings > Scraping holds the one key
// the scraper and Change artwork… share. Every value lives in the theme (theme.qml), which saves it.
import QtQuick 2.15
import QtQml 2.15
import "parts"

DeckSettingsPage {
    id: customizationPage
    title: "Customization"

    readonly property var th: (typeof theme !== "undefined" && theme) ? theme : null

    // only read when DeckOS starts, so it isn't one of the theme's properties
    property bool showBootAnimation: api.memory.has("showBootAnimation") ? api.memory.get("showBootAnimation") : true
    onShowBootAnimationChanged: api.memory.set("showBootAnimation", showBootAnimation)

    readonly property var sizeNames: ["Smallest", "Small", "Medium", "Large", "Largest"]

    function step(name, delta, min, max) {
        if (!th) return
        th[name] = Math.max(min, Math.min(max, th[name] + delta))
    }
    function cycle(name, min, max) {
        if (!th) return
        th[name] = th[name] >= max ? min : th[name] + 1
    }
    function scaleStep(delta) {
        if (!th) return
        th.interfaceScale = Math.round(Math.max(0, Math.min(1, th.interfaceScale + delta)) * 100) / 100
    }

    rows: [
        { type: "section", label: "Look" },
        { type: "toggle", label: "Show boot animation", desc: "Play the Steam Deck boot animation when DeckOS starts",
          value: function () { return customizationPage.showBootAnimation },
          toggle: function () { customizationPage.showBootAnimation = !customizationPage.showBootAnimation } },
        { type: "toggle", label: "Alternative Home screen", desc: "Fullscreen background, game list moved to the bottom",
          value: function () { return th ? th.alternativeHomeScreen : false },
          toggle: function () { if (th) th.alternativeHomeScreen = !th.alternativeHomeScreen } },
        { type: "choice", label: "Game size on Home", desc: "How big the games in Home's row are",
          value: function () { return th ? customizationPage.sizeNames[Math.max(1, Math.min(5, th.gameListSize)) - 1] : "Small" },
          next: function () { customizationPage.step("gameListSize", 1, 1, 5) },
          prev: function () { customizationPage.step("gameListSize", -1, 1, 5) } },
        { type: "toggle", label: "Rounded covers", desc: "Rounded corners on game covers",
          value: function () { return th ? th.roundedCovers : false },
          toggle: function () { if (th) th.roundedCovers = !th.roundedCovers } },

        // was Settings > Accessibility
        { type: "section", label: "Accessibility" },
        { type: "choice", label: "Interface scale", desc: "Bigger or smaller text and controls everywhere",
          value: function () { return th ? Math.round((0.8 + 0.4 * th.interfaceScale) * 100) + "%" : "100%" },
          next: function () { customizationPage.scaleStep(0.05) }, prev: function () { customizationPage.scaleStep(-0.05) } },
        { type: "choice", label: "Library rows", desc: "Games per row in the Library",
          value: function () { return th ? th.libraryRows + " per row" : "3 per row" },
          next: function () { customizationPage.step("libraryRows", 1, 3, 8) }, prev: function () { customizationPage.step("libraryRows", -1, 3, 8) } },
        { type: "choice", label: "Search rows", desc: "Games per row in Search",
          value: function () { return th ? th.searchRows + " per row" : "3 per row" },
          next: function () { customizationPage.step("searchRows", 1, 3, 8) }, prev: function () { customizationPage.step("searchRows", -1, 3, 8) } },
        { type: "toggle", label: "Asynchronous loading", desc: "Pages load faster; pictures may pop in a moment later",
          value: function () { return th ? th.asyncLoading : false },
          toggle: function () { if (th) th.asyncLoading = !th.asyncLoading } },
        { type: "toggle", label: "Animated covers", desc: "Play animated artwork (can slow the interface down)",
          value: function () { return th ? th.animatedCovers : false },
          toggle: function () { if (th) th.animatedCovers = !th.animatedCovers } },
        { type: "toggle", label: "Animate only the selected game",
          enabled: function () { return !!th && th.animatedCovers },
          value: function () { return th ? th.animationInFocus : false },
          toggle: function () { if (th) th.animationInFocus = !th.animationInFocus } },
        { type: "toggle", label: "Game launch animation", desc: "The animation when a game starts",
          value: function () { return th ? th.gameLaunchingAnimation : true },
          toggle: function () { if (th) th.gameLaunchingAnimation = !th.gameLaunchingAnimation } }
    ]
}
