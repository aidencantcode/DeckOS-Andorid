# 06 — RetroAchievements

Owner's current #1 goal: **each game's RetroAchievements shown under the game page, with a separate Achievements view listing them like Steam does.**

## What BigScreenFE does (study, don't copy — see `reference/REFERENCE_NOTES.md`)
- QML-only, `XMLHttpRequest` straight to `https://retroachievements.org/API/…?y=<key>`; key + user saved in `api.memory` in plain text.
- Matches games **by title**: fetches the user's `API_GetUserCompletionProgress` (first 500 games), fuzzy-scores titles (+0.5 console match bonus, thresholds 0.60 / F1 ≥ 0.70), falls back to `API_GetGameList` for the console and fuzzy matches again (threshold 0.55). Then `API_GetGameInfoAndUserProgress`.
- Weaknesses to fix: wrong/missed matches for hacks, regional titles and games the user never played; no caching; only first 500 games; no hashing; key in plain text; heavy UI code in one 1400-line file.

## DeckOS design

### Account
- Settings → Accounts → RetroAchievements: username + **Web API key** (from the user's RA settings page; help text explains where). Verify with `API_GetUserSummary` → show avatar, points, rank. Store in the secret store.
- We only read public data via the Web API. **Do not** implement RA login/token "Connect" API usage (that's for emulators awarding achievements).
- Optional QoL later: offer to write RA username into RetroArch's config if readable (never the password).

### Matching (accurate)
1. Compute the **RA hash** with **rcheevos `rc_hash`** (MIT license; vendor as a submodule under `thirdparty/rcheevos`). It implements per-console hashing rules (headers stripped for NES/SNES/Lynx…, disc-based logic for PS1/PS2/PSP/Saturn/Sega CD/PC Engine CD/Dreamcast, archives, `.m3u`). Use its custom file reader hooks so it works with content URIs (SAF) too. *Verify the current rcheevos hashing API — it has changed between versions.*
2. Per console, download the hash list once: `API_GetGameList.php?i=<consoleId>&h=1` (games with their hashes; *verify params*), cache in `ra_hashlists` (refresh weekly or on demand). Local lookup hash → GameID. Zero API calls per game for matching.
3. No hash match → fuzzy title match (keep the idea, write our own normalizer) → mark **"Unverified match"** with a small warning badge.
4. Manual: Properties → RetroAchievements → "Link to RA game…" (search RA list for that console) / "Not on RA". Stored in `launch_overrides`/`ra_links`.
5. Hashing cost: cache by path+size+mtime. Large discs (PS2/PSP/Dreamcast) are hashed lazily in the background, never on the UI thread; show "Checking RetroAchievements…" only on the Achievements tab.

### Data (verify each against https://api-docs.retroachievements.org before coding)
- `API_GetGameInfoAndUserProgress` (g, u, `a=1` for award metadata) → achievements with titles, descriptions, points, `BadgeName`, `DateEarned`, `DateEarnedHardcore`, `NumAwarded`/`NumAwardedHardcore`, `NumDistinctPlayers`, type (progression / win_condition / missable), plus game images.
- `API_GetUserCompletionProgress` (paginate fully, not just 500) and/or `API_GetUserAwards` → mastered/beaten badges for capsules.
- `API_GetUserRecentAchievements` → Home shelf and session toast diffs.
- Images: `https://media.retroachievements.org/Badge/<BadgeName>.png`, locked: `<BadgeName>_lock.png`; game icon/title/ingame/boxart from the game info `Image*` paths.
- Cache in SQLite with TTL (game info 7 days; user progress 10 min; force refresh on return from game). Respect rate limits: global request queue, max ~1–2 req/s, exponential backoff on 429/5xx. Offline → show cached with "Last updated …".

### UI (Steam-faithful)
- **Game page stats row:** "ACHIEVEMENTS 12/45" with a mini progress bar (RA icon). Hidden if no set.
- **Game page → Achievements tab (summary card):** progress bar + %, points earned / total, hardcore vs softcore indicator, "Recently unlocked" (3 icons), "Rarest unlocked", "Next up" (locked progression achievements), button **View all achievements**.
- **Full Achievements view:** Steam-style list. Unlocked rows in color with unlock date/time and "HC" tag; locked rows greyscale (`_lock` badge) with % of players unlocked (rarity) and points; tags for **Missable**, **Progression**, **Win condition**. Sort: default (RA display order), unlock date, rarity, points. Filter: all / unlocked / locked / missable. L1/R1 switch filters; focus scrolls smoothly; A on a row shows a detail popup (bigger badge, full description, global stats).
- **Capsules:** small RA badge if the game has a set; gold ring when mastered, silver when beaten.
- **Home:** "Recent achievements" shelf across RA + (later) Steam.
- **Session toast:** after returning from a game, diff user progress; "🏆 Unlocked 3 achievements in Castlevania" Steam-style toast with sound; tapping opens the list.
- **Library filter:** "Has achievements", "Mastered", "In progress".

### API surface (example)
```
deckos.ra.account          { loggedIn, user, avatar, points, verify(user,key) }
deckos.ra.forGame(game)    → GameAchievements { state: loading|ready|notFound|unverified|offline|error,
                             raGameId, title, consoleName, total, unlocked, unlockedHardcore,
                             points, pointsEarned, achievements: ListModel, refresh() }
deckos.ra.recent           ListModel
signal deckos.ra.sessionUnlocks(game, count, list)
```
