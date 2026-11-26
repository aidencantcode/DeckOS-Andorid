// DECKOS: game Properties > Details - rename the game, write or fetch its description, scrape its
// artwork and info, or undo all DeckOS changes. Changes are saved at once (deckos.setGameTitle etc.).
import QtQuick 2.15
import "../settings/parts"

DeckSettingsPage {
    id: detailsPage
    title: "Details"

    readonly property var game: (typeof theme !== "undefined" && theme) ? theme.currentGame : null
    readonly property var dk: (typeof deckos !== "undefined" && deckos) ? deckos : null
    readonly property var scraper: dk ? dk.scraper : null

    // refreshed after every change (gameChanges() is a plain call, not a binding source)
    property var changes: ({})
    function refresh() {
        changes = (dk && game) ? dk.gameChanges(game) : ({})
        launchCommand = (dk && game) ? dk.gameLaunchCommand(game) : ""
    }
    Component.onCompleted: refresh()
    onGameChanged: refresh() // the theme hands the game over after this page is created

    property string scrapeMessage: ""
    property bool confirmReset: false

    Connections {
        target: detailsPage.scraper
        function onGameFinished(finishedGame, ok, message) {
            if (finishedGame === detailsPage.game) {
                detailsPage.scrapeMessage = message
                detailsPage.refresh()
            }
        }
    }

    // The SteamGridDB picks and the custom titles (Customization) are kept under the game's name: a
    // renamed game takes them along (the old entry stays, for a rename back)
    function carryCustomAssets(from, to) {
        if (!from || !to || from === to) return
        var oldKey = "custom_assets_" + from, newKey = "custom_assets_" + to
        if (api.memory.has(oldKey) && !api.memory.has(newKey))
            api.memory.set(newKey, api.memory.get(oldKey))
    }

    function shortText(text, n) {
        var t = String(text || "").replace(/\s+/g, " ").trim()
        return t.length > n ? t.substring(0, n) + "…" : t
    }

    // "Launch with...": the page lists the emulators instead of the details until one is picked or B
    property bool pickingEmulator: false
    property string launchCommand: ""
    backHandler: function () { if (!pickingEmulator) return false; pickingEmulator = false; backToLaunchRow(); return true }
    function backToLaunchRow() {
        Qt.callLater(function () {
            for (var i = 0; i < detailsPage.rows.length; i++)
                if (detailsPage.rows[i].label === "Launch with…") { detailsPage.activeItemIndex = i; break }
        })
    }

    function emulatorRows() {
        var r = [{ type: "section", label: "Launch this game with" }]
        r.push({ type: "button", label: "The system's emulator",
                 desc: "Same as the other games of this system (Settings > Emulators)",
                 value: function () { return detailsPage.changes.launchEdited ? "" : "✓" },
                 activate: function () { dk.setGameLaunchCommand(game, ""); detailsPage.pickingEmulator = false; detailsPage.refresh(); detailsPage.backToLaunchRow() } })
        var emus = dk ? dk.gameEmulators(game) : []
        for (var i = 0; i < emus.length; i++) {
            (function (emu) {
                r.push({ type: "button", label: emu.name,
                         desc: (emu.installed ? "Installed" : "Not installed") + (emu.achievements ? "  ·  RetroAchievements" : ""),
                         activate: function () { dk.setGameEmulator(game, emu.id); detailsPage.pickingEmulator = false; detailsPage.refresh(); detailsPage.backToLaunchRow() } })
            })(emus[i])
        }
        if (emus.length === 0)
            r.push({ type: "info", label: "No emulators known for this game's system", desc: "Edit the launch command by hand instead" })
        return r
    }

    rows: pickingEmulator ? emulatorRows() : [
        { type: "section", label: "Game" },
        { type: "button", label: "Name",
          desc: function () { return detailsPage.changes.titleEdited ? "Renamed in DeckOS — clear it to go back" : "" },
          value: function () { return game ? game.title : "" },
          activate: function () { nameEntry.original = game ? game.title : ""; nameEntry.open(nameEntry.original) } },
        { type: "button", label: "Description",
          desc: function () {
              var d = game ? (game.description || game.summary) : ""
              return d ? detailsPage.shortText(d, 90) : "No description yet"
          },
          value: function () { return detailsPage.changes.descriptionEdited ? "Edited" : "" },
          activate: function () { descEntry.original = game ? (game.description || game.summary) : ""; descEntry.open(descEntry.original) } },
        { type: "section", label: "Artwork and info" },
        { type: "button", label: "Scrape this game", accent: true,
          desc: function () {
              if (scraper && scraper.running && scraper.currentTitle === (game ? game.title : "")) return scraper.status
              if (detailsPage.scrapeMessage !== "") return detailsPage.scrapeMessage
              return detailsPage.changes.scraped ? "Last scraped " + detailsPage.changes.scraped.substring(0, 10)
                     + (detailsPage.changes.sources ? " from " + detailsPage.changes.sources : "")
                   : "Fetch artwork (SteamGridDB, libretro) and a description (TheGamesDB) now"
          },
          enabled: function () { return !!scraper && !!game },
          activate: function () { detailsPage.scrapeMessage = "Queued…"; scraper.scrapeGame(game) } },
        { type: "button", label: "Choose artwork by hand…",
          desc: "Browse SteamGridDB covers, heroes and logos for this game",
          activate: function () { if (theme) theme.openPage(12) } },
        { type: "section", label: "Launch" },
        { type: "button", label: "Launch with…",
          desc: "Use another emulator for this game only",
          value: function () { return detailsPage.changes.launchEdited ? "Custom" : "" },
          activate: function () { detailsPage.pickingEmulator = true; detailsPage.activeItemIndex = 0 } },
        { type: "button", label: "Launch command",
          desc: function () { return detailsPage.shortText(detailsPage.launchCommand, 110) || "None" },
          activate: function () { cmdEntry.original = detailsPage.launchCommand; cmdEntry.open(detailsPage.launchCommand) } },
        { type: "section", label: "Undo" },
        { type: "button", label: "Undo all DeckOS changes",
          desc: function () { return detailsPage.confirmReset ? "Press A again: forgets the new name, description and scraped artwork"
                                                             : (detailsPage.changes.edited ? "Back to what the game's files say" : "Nothing changed yet") },
          enabled: function () { return !!detailsPage.changes.edited },
          activate: function () {
              if (!detailsPage.confirmReset) { detailsPage.confirmReset = true; return }
              detailsPage.confirmReset = false
              dk.resetGame(game)
              detailsPage.scrapeMessage = ""
              detailsPage.refresh()
          } }
    ]

    TextEntry {
        id: nameEntry
        property string original: ""
        title: "Game name"
        hint: "Clear it (X) to use the name from the game's files again."
        maxLength: 120
        onAccepted: {
            // closing without changes must not mark the name as edited
            if (detailsPage.dk && detailsPage.game && text !== original) {
                var before = detailsPage.game.title
                detailsPage.dk.setGameTitle(detailsPage.game, text)
                detailsPage.carryCustomAssets(before, detailsPage.game.title)
            }
            detailsPage.refresh()
            goToZone(1)
        }
    }
    TextEntry {
        id: descEntry
        property string original: ""
        title: "Description"
        hint: "Clear it (X) to use the scraped or original description again."
        maxLength: 4000
        multiline: true
        onAccepted: {
            if (detailsPage.dk && detailsPage.game && text.trim() !== original.trim()) detailsPage.dk.setGameDescription(detailsPage.game, text)
            detailsPage.refresh()
            goToZone(1)
        }
    }
    TextEntry {
        id: cmdEntry
        property string original: ""
        title: "Launch command"
        hint: "{file.path} = the game's file, {file.uri} = a content:// link to it. Clear it (X) to use the system's command."
        multiline: true
        maxLength: 1200
        onAccepted: {
            if (detailsPage.dk && detailsPage.game && text.trim() !== original.trim())
                detailsPage.dk.setGameLaunchCommand(detailsPage.game, text)
            detailsPage.refresh()
            goToZone(1)
        }
    }
}
