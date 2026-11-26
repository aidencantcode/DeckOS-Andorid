// DECKOS: Settings > Scraping - artwork and game info (deckos.scraper, Scraper.h), moved out of
// Settings > Library: automatic scraping, the sources, the API keys and keys.txt, and Re-scrape… with
// its collection picker. Progress also shows in the top-left notification (theme.qml) on every page.
import QtQuick 2.15
import QtQml 2.15
import "parts"

DeckSettingsPage {
    id: scrapingPage
    title: "Scraping"

    readonly property var scraper: (typeof deckos !== "undefined" && deckos) ? deckos.scraper : null
    property string keysMessage: ""

    // "Re-scrape…": pick the collections to re-scrape, or everything
    property bool pickingRescrape: false
    property bool rescrapeEverything: true
    property var rescrapeChosen: ({}) // collection name -> true
    // games that already have artwork are left out (remembered)
    property bool skipWithMedia: api.memory.has("rescrapeSkipWithMedia") ? api.memory.get("rescrapeSkipWithMedia") : true
    onSkipWithMediaChanged: api.memory.set("rescrapeSkipWithMedia", skipWithMedia)

    property int returnRow: 0
    function restoreRow() {
        var row = returnRow
        Qt.callLater(function () { scrapingPage.activeItemIndex = row })
    }
    backHandler: function () {
        if (pickingRescrape) { pickingRescrape = false; restoreRow(); return true }
        return false
    }

    function openRescrapePicker() {
        returnRow = activeItemIndex
        rescrapeEverything = true
        rescrapeChosen = {}
        pickingRescrape = true
        activeItemIndex = 0
    }

    function chosenCollections() {
        var names = []
        for (var name in rescrapeChosen)
            if (rescrapeChosen[name]) names.push(name)
        return names
    }

    function rescrapeGameCount() {
        if (rescrapeEverything) return api.allGames.count
        var n = 0
        for (var i = 0; i < api.collections.count; i++) {
            var c = api.collections.get(i)
            if (rescrapeChosen[c.name]) n += c.games.count
        }
        return n // a game in two picked collections counts twice here; the scraper queues it once
    }

    function startScrape(onlyMissing, collections, skip) {
        var n = scraper.scrapeAll(onlyMissing, collections || [], !!skip)
        if (n === 0)
            keysMessage = (scraper.steamGridDbKey === "" && scraper.theGamesDbKey === "" && !scraper.useLibretroThumbnails)
                        ? "Add an API key first" : "Nothing to scrape"
        else
            keysMessage = ""
    }

    function importKeys() {
        var th = (typeof theme !== "undefined" && theme) ? theme : null
        var res = th ? th.importKeysFile() : scraper.importKeys()
        if (res.error) { keysMessage = res.error; return }
        keysMessage = res.found === 0 ? "No keys found in " + res.path
                    : res.found + (res.found === 1 ? " key" : " keys") + " loaded" + (res.raUser ? " (RetroAchievements account too)" : "")
    }

    function rescrapePickRows() {
        var r = [{ type: "section", label: "Re-scrape which games?" }]
        r.push({ type: "toggle", label: "Skip games that already have artwork",
                 desc: "Only games without a cover, hero, logo or wide capsule are scraped again",
                 value: function () { return scrapingPage.skipWithMedia },
                 toggle: function () { scrapingPage.skipWithMedia = !scrapingPage.skipWithMedia } })
        r.push({ type: "toggle", label: "Everything",
                 desc: api.allGames.count + " games - or turn this off and pick collections below",
                 value: function () { return scrapingPage.rescrapeEverything },
                 toggle: function () { scrapingPage.rescrapeEverything = !scrapingPage.rescrapeEverything } })
        for (var i = 0; i < api.collections.count; i++) {
            (function (coll) {
                var name = coll.name
                r.push({ type: "toggle", label: name,
                         desc: coll.games.count + (coll.games.count === 1 ? " game" : " games"),
                         enabled: function () { return !scrapingPage.rescrapeEverything },
                         value: function () { return scrapingPage.rescrapeEverything || !!scrapingPage.rescrapeChosen[name] },
                         toggle: function () {
                             var m = Object.assign({}, scrapingPage.rescrapeChosen)
                             m[name] = !m[name]
                             scrapingPage.rescrapeChosen = m
                         } })
            })(api.collections.get(i))
        }
        r.push({ type: "button", label: "Start re-scrape", accent: true,
                 desc: function () {
                     var n = scrapingPage.rescrapeGameCount()
                     if (n === 0) return "Pick at least one collection"
                     return (scrapingPage.skipWithMedia ? "Fills in the games without artwork among " : "Replaces scraped artwork and info for ")
                            + n + (n === 1 ? " game" : " games")
                 },
                 enabled: function () { return scrapingPage.rescrapeGameCount() > 0 },
                 activate: function () {
                     var names = scrapingPage.rescrapeEverything ? [] : scrapingPage.chosenCollections()
                     scrapingPage.pickingRescrape = false; scrapingPage.restoreRow()
                     scrapingPage.startScrape(false, names, scrapingPage.skipWithMedia)
                 } })
        return r
    }

    function buildRows() {
        if (!scraper)
            return [{ type: "info", label: "Scraping isn't available" }]
        if (pickingRescrape)
            return rescrapePickRows()
        var r = []
        r.push({ type: "section", label: "Artwork and game info" })
        if (keysMessage !== "")
            r.push({ type: "info", label: keysMessage })
        r.push({ type: "toggle", label: "Auto-scrape new games",
                 desc: "After the library loads, fetch artwork and descriptions for games that have none",
                 value: function () { return scraper.autoScrape },
                 toggle: function () { scraper.autoScrape = !scraper.autoScrape } })
        r.push({ type: "button", label: "Scrape games with missing artwork or info",
                 desc: function () { return scraper.running ? scraper.status : (scraper.status !== "" ? scraper.status : "Games scraped before are skipped") },
                 value: function () { return scraper.running ? scraper.done + " / " + scraper.total : "" },
                 enabled: function () { return !scraper.running },
                 activate: function () { scrapingPage.startScrape(true) } })
        r.push({ type: "button", label: "Re-scrape…",
                 desc: "Everything or the collections you pick; can skip games that already have artwork",
                 enabled: function () { return !scraper.running },
                 activate: function () { scrapingPage.openRescrapePicker() } })
        r.push({ type: "button", label: "Stop scraping",
                 enabled: function () { return scraper.running },
                 activate: function () { scraper.cancel() } })

        r.push({ type: "section", label: "Sources" })
        r.push({ type: "toggle", label: "Descriptions",
                 desc: "Also fetch descriptions and release dates (TheGamesDB)",
                 value: function () { return scraper.fetchDescriptions },
                 toggle: function () { scraper.fetchDescriptions = !scraper.fetchDescriptions } })
        r.push({ type: "toggle", label: "libretro thumbnails",
                 desc: "Box art and screenshots by ROM file name, no key needed",
                 value: function () { return scraper.useLibretroThumbnails },
                 toggle: function () { scraper.useLibretroThumbnails = !scraper.useLibretroThumbnails } })

        r.push({ type: "section", label: "Keys" })
        r.push({ type: "button", label: "SteamGridDB API key",
                 desc: "Covers, heroes and logos, and Change artwork… Free key: steamgriddb.com > Preferences > API",
                 value: function () { return scraper.steamGridDbKey !== "" ? "Set" : "Not set" },
                 activate: function () { keyEntry.target = "sgdb"; keyEntry.title = "SteamGridDB API key"; keyEntry.open(scraper.steamGridDbKey) } })
        r.push({ type: "button", label: "TheGamesDB API key",
                 desc: function () { return scraper.theGamesDbAllowance >= 0 ? scraper.theGamesDbAllowance + " lookups left this month" : "Descriptions, release dates and box art" },
                 value: function () { return scraper.theGamesDbKey !== "" ? "Set" : "Not set" },
                 activate: function () { keyEntry.target = "tgdb"; keyEntry.title = "TheGamesDB API key"; keyEntry.open(scraper.theGamesDbKey) } })
        r.push({ type: "button", label: "Load keys from a file",
                 desc: "Reads " + scraper.keysFilePath(),
                 activate: function () { scrapingPage.importKeys() } })
        return r
    }

    rows: (pickingRescrape, keysMessage, api.collections.count, buildRows())

    TextEntry {
        id: keyEntry
        property string target: ""
        secret: true
        maxLength: 128
        hint: "Paste it with Y if you copied it on this device."
        onAccepted: {
            if (target === "sgdb") scrapingPage.scraper.steamGridDbKey = text
            else if (target === "tgdb") scrapingPage.scraper.theGamesDbKey = text
            goToZone(1)
        }
    }
}
