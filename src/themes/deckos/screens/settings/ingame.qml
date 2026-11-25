// DECKOS: Settings > In-Game - the Android in-game layer (deckos.ingame, Java com.deckos.ingame):
// the "Playing ..." notification that opens the Steam-style Quick Access overlay, and the performance
// overlay drawn over games (Steam Deck's levels 0-4).
import QtQuick 2.15
import "parts"

DeckSettingsPage {
    id: ingamePage
    title: "In-Game"

    readonly property var ig: (typeof deckos !== "undefined" && deckos) ? deckos.ingame : null
    readonly property var levelNames: ["Off", "1 - Battery and play time", "2 - One bar", "3 - Detailed", "4 - Everything"]

    // the overlay permission is granted in Android's settings: look again whenever DeckOS comes back
    Connections {
        target: Qt.application
        function onStateChanged() { if (Qt.application.state === Qt.ApplicationActive && ingamePage.ig) ingamePage.ig.recheck() }
    }

    function cycleLevel(step) {
        if (!ig) return
        ig.hudLevel = (ig.hudLevel + step + 5) % 5
    }

    rows: [
        { type: "section", label: "While you play" },
        { type: "toggle", label: "In-game notification",
          desc: "Shows the game and its play time while DeckOS is in the background. Tap it for the quick access menu (performance, achievements).",
          value: function () { return ig ? ig.notification : false },
          enabled: function () { return !!ig },
          toggle: function () { if (ig) ig.notification = !ig.notification } },
        { type: "choice", label: "Performance overlay",
          desc: "Battery, CPU, GPU, memory and temperatures over the game, like the Steam Deck. Also in the quick access menu.",
          value: function () { return ig ? ingamePage.levelNames[ig.hudLevel] : "Off" },
          enabled: function () { return !!ig },
          next: function () { ingamePage.cycleLevel(1) }, prev: function () { ingamePage.cycleLevel(-1) } },
        { type: "button", label: "Allow drawing over games",
          desc: function () {
              if (!ig || !ig.available) return "Android only"
              return ig.overlayAllowed ? "Allowed" : "Android's \"Display over other apps\" permission - needed for the performance overlay"
          },
          value: function () { return ig && ig.overlayAllowed ? "✓" : "" },
          enabled: function () { return !!ig && ig.available && !ig.overlayAllowed },
          activate: function () { if (ig) ig.requestOverlayPermission() } },
        { type: "section", label: "About" },
        { type: "info", label: "Frame rate",
          desc: "Android doesn't let apps read another app's frame rate. A Shizuku option is planned." },
        { type: "info", label: "Performance mode",
          desc: "The quick access menu has the switch already; it starts working once the AYN and Retroid commands are added." }
    ]
}
