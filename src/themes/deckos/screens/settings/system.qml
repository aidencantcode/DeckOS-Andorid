// DECKOS: Settings > System, rebuilt on DeckSettingsPage: about DeckOS, the interface theme picker
// (Pegasus's "Theme" setting) and the open-source licenses (Pegasus's Help screen).
import QtQuick 2.15
import QtQml 2.15
import "parts"

DeckSettingsPage {
    id: systemPage
    title: "System"

    Instantiator { id: themeList; model: Internal.settings.themes; delegate: QtObject { readonly property string name: model.name } }

    // Left/Right only picks a theme; "Switch theme" applies it (an accidental press must not swap the UI)
    property int pendingTheme: Internal.settings.themes.currentIndex
    function cycleTheme(step) {
        var n = themeList.count
        if (n < 2) return
        pendingTheme = (pendingTheme + step + n) % n
    }
    function pendingThemeName() {
        var o = themeList.objectAt(pendingTheme)
        return o ? o.name : Internal.settings.themes.currentName
    }

    rows: [
        { type: "section", label: "About" },
        { type: "info", label: "DeckOS version", value: function () { return Internal.meta.gitRevision } },
        { type: "info", label: "Build date", value: function () { return Internal.meta.gitDate } },
        { type: "info", label: "Platform", value: function () { return Qt.platform.os === "android" ? "Android" : Qt.platform.os } },
        { type: "info", label: "Interface", value: function () { return "StMini 0.4.22 + DeckOS" } },
        { type: "info", label: "Log file", desc: "Attach it to bug reports",
          value: function () { return Internal.meta.logFilePath } },
        { type: "section", label: "Interface" },
        { type: "choice", label: "Theme",
          desc: "Other themes have no settings screen: press Start there for the classic menu",
          value: function () { return systemPage.pendingThemeName() },
          next: function () { systemPage.cycleTheme(1) }, prev: function () { systemPage.cycleTheme(-1) } },
        { type: "button", label: "Switch theme",
          enabled: function () { return systemPage.pendingTheme !== Internal.settings.themes.currentIndex },
          activate: function () { Internal.settings.themes.currentIndex = systemPage.pendingTheme } },
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
