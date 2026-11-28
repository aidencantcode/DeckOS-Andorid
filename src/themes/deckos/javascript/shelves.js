// DECKOS: the shelves of Home's What's New / Friends / Recommended tabs and the Friends & Chat page
// (ShelfView.qml): built from the library's own lists (deckos.stats), the web's (deckos.feeds) and the
// emulator updates (deckos.updates). Each shelf: { id, title, subtitle, kind, items }.
.pragma library

function hoursText(sec) {
    var h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
    if (h === 0) return m + " min"
    return h + " h" + (m > 0 && h < 10 ? " " + m + " min" : "")
}

function agoText(d) {
    var t = d ? new Date(d).getTime() : NaN
    if (isNaN(t)) return ""
    var s = Math.max(0, (Date.now() - t) / 1000)
    if (s < 3600) return "just now"
    if (s < 86400) return Math.round(s / 3600) + " h ago"
    var days = Math.round(s / 86400)
    return days === 1 ? "yesterday" : days + " days ago"
}

function gamesShelf(id, title, kind, games, badge) {
    var items = []
    for (var i = 0; i < games.length; i++) if (games[i]) items.push({ game: games[i], badge: badge ? badge(games[i]) : "" })
    return { id: id, title: title, kind: kind, items: items }
}

function bySource(list, names, keep) {
    var out = []
    for (var i = 0; i < list.length; i++) {
        var hit = names.indexOf(list[i].source) !== -1
        if (hit === keep) out.push(list[i])
    }
    return out
}

function add(list, shelf) { if (shelf && shelf.items && shelf.items.length) list.push(shelf) }

var JOEY = ["Joey's Retro Handhelds"]

function whatsNew(s, f) {
    var wn = []
    if (s) {
        add(wn, gamesShelf("recent", "Recently Played", "game", s.recentlyPlayed(15),
                           function (g) { return "Played " + agoText(g.lastPlayed) }))
        var week = s.weekBest(10), weekItems = [], weekTotal = 0
        for (var w = 0; w < week.length; w++) {
            weekTotal += week[w].seconds
            weekItems.push({ game: week[w].game, badge: hoursText(week[w].seconds) + " this week  ·  " + week[w].sessions
                                                        + (week[w].sessions === 1 ? " session" : " sessions") })
        }
        add(wn, { id: "week", title: "Best Games of the Week", subtitle: hoursText(weekTotal) + " played in the last 7 days",
                  kind: "wide", items: weekItems })
        add(wn, gamesShelf("most", "Most Played So Far", "game", s.mostPlayed(15),
                           function (g) { return hoursText(g.playTime) + " played" }))
    }
    if (f) {
        add(wn, { id: "joey", title: "Joey's Retro Handhelds", subtitle: "Retro Newscast and more", kind: "video",
                  items: bySource(f.videos, JOEY, true).slice(0, 15) })
        add(wn, { id: "rhnews", title: "Retro Handheld News", subtitle: "retrohandhelds.gg", kind: "news",
                  items: bySource(f.news, ["Retro Handhelds"], true).slice(0, 15) })
        if (f.raSignedIn) {
            add(wn, { id: "rasets", title: "New on RetroAchievements", subtitle: "Sets released lately, also for games you don't have",
                      kind: "raset", items: f.raSets.slice(0, 25) })
            if (f.raWeekly && f.raWeekly.title)
                wn.push({ id: "aotw", title: "Achievement of the Week", kind: "raweekly", items: [f.raWeekly] })
            add(wn, { id: "racommunity", title: "RetroAchievements Community", subtitle: "Latest masteries and beaten games",
                      kind: "raaward", items: f.raCommunity.slice(0, 25) })
        } else {
            wn.push({ id: "rasignin", title: "RetroAchievements", kind: "action",
                      items: [{ action: "ra-signin", glyph: "★", title: "Sign in to RetroAchievements",
                                text: "New achievement sets, the Achievement of the Week and the community feed show here" }] })
        }
        add(wn, { id: "ranews", title: "RetroAchievements News", kind: "news", items: bySource(f.news, ["RetroAchievements"], true).slice(0, 12) })
        add(wn, { id: "videos", title: "Latest Videos", subtitle: "Handheld channels", kind: "video",
                  items: bySource(f.videos, JOEY, false).slice(0, 20) })
        add(wn, { id: "news", title: "Gaming News", kind: "news",
                  items: bySource(f.news, ["Retro Handhelds", "RetroAchievements"], false).slice(0, 15) })
    }
    if (s) add(wn, gamesShelf("newtoyou", "Something New to Play", "wide", s.unplayed(12), null))
    return wn
}

function friends(f) {
    var fr = []
    if (!f) return fr
    var online = []
    for (var a = 0; a < f.raFriends.length; a++) if (f.raFriends[a].online) online.push(f.raFriends[a])
    var dOnline = []
    for (var b = 0; b < f.discordFriends.length; b++) {
        var st = f.discordFriends[b].status
        if (st && st !== "offline" && st !== "unknown") dOnline.push(f.discordFriends[b])
    }
    add(fr, { id: "online", title: "Online Now", subtitle: "RetroAchievements", kind: "friend", items: online })
    add(fr, { id: "donline", title: online.length ? "Online on Discord" : "Online Now", kind: "discord", items: dOnline })
    if (f.raSignedIn) {
        if (f.raFriends.length)
            fr.push({ id: "rafriends", title: "RetroAchievements Friends", subtitle: f.raFriends.length + " you follow", kind: "friend", items: f.raFriends })
        else
            fr.push({ id: "rafriends", title: "RetroAchievements Friends", kind: "action",
                      items: [{ action: "ra-site", glyph: "+", title: "Follow people on RetroAchievements",
                                text: "Everyone you follow on retroachievements.org shows here, with what they're playing" }] })
    } else {
        fr.push({ id: "rasignin2", title: "RetroAchievements Friends", kind: "action",
                  items: [{ action: "ra-signin", glyph: "★", title: "Sign in to RetroAchievements",
                            text: "See who's online and what they're playing (their rich presence)" }] })
    }
    add(fr, { id: "discord", title: "Discord", subtitle: "Through Lanyard  ·  X removes a friend", kind: "discord", items: f.discordFriends })
    fr.push({ id: "discordadd", title: f.discordFriends.length ? "Discord friends" : "Discord", kind: "action",
              items: [{ action: "discord-add", glyph: "+", title: "Add a Discord friend",
                        text: "Their Discord user id. They join discord.gg/lanyard once, so their status can be read." },
                      { action: "discord-help", glyph: "?", title: "Why not the whole friends list?",
                        text: "Discord only gives it out with your account's token, which its rules forbid (it can get you banned)." }] })
    return fr
}

function recommended(s, f, updates) {
    var rec = []
    add(rec, { id: "updates", title: "Emulator Updates", subtitle: "New versions of your emulators  ·  A updates", kind: "update",
               items: updates ? updates.emulatorUpdates : [] })
    if (s) {
        add(rec, gamesShelf("unplayed", "Unplayed Retro Games", "wide", s.unplayed(18), null))
        var recent1 = s.recentlyPlayed(1)
        if (recent1.length)
            add(rec, gamesShelf("because", "Because You Played " + recent1[0].title, "game", s.becauseYouPlayed(15), null))
        var sys = s.systems(30), sysItems = []
        for (var k = 0; k < sys.length; k++) sysItems.push({ game: null, art: sys[k].game, name: sys[k].name, count: sys[k].count })
        add(rec, { id: "systems", title: "Your Systems and Collections", kind: "system", items: sysItems })
        add(rec, gamesShelf("mostrec", "Your Favourites", "game", s.mostPlayed(12), function (g) { return hoursText(g.playTime) + " played" }))
    }
    if (f) add(rec, { id: "recvideos", title: "Watch", subtitle: "Handheld news and reviews", kind: "video", items: f.videos.slice(0, 12) })
    return rec
}
