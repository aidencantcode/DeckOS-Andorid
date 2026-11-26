// DECKOS: Settings > System, rebuilt on DeckSettingsPage: about DeckOS, the interface theme picker
// (removed 0.1.3) and the open-source licenses (Pegasus's Help screen).
import QtQuick 2.15
import QtQml 2.15
import "parts"

DeckSettingsPage {
    id: systemPage
    title: "System"

    rows: [
        { type: "section", label: "About" },
        { type: "info", label: "DeckOS version", value: function () { return Internal.meta.gitRevision } },
        { type: "info", label: "Build date", value: function () { return Internal.meta.gitDate } },
        { type: "info", label: "Platform", value: function () { return Qt.platform.os === "android" ? "Android" : Qt.platform.os } },
        { type: "info", label: "Interface", value: function () { return "StMini 0.4.22 + DeckOS" } },
        { type: "info", label: "Log file", desc: "Attach it to bug reports",
          value: function () { return Internal.meta.logFilePath } },
        // DECKOS: Pegasus's theme switch is gone (owner request): DeckOS is its own interface
        { type: "section", label: "Legal" },
        { type: "button", label: "Open-source licenses",
          desc: "DeckOS is built on Pegasus Frontend (GPLv3) and other open-source software",
          activate: function () { licenses.active = true } }
    ]

    // Pegasus's Help screen (credits + every bundled library's license) as an overlay
    Loader {
        id: licenses
        anchors.fill: parent
        active: false
        z: 100
        source: "qrc:/frontend/menu/help/HelpScreen.qml"
        onLoaded: item.forceActiveFocus()
    }
    Connections {
        target: licenses.item
        function onClose() { licenses.active = false; goToZone(1) }
    }
}
