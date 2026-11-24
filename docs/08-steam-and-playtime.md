# 08 — Steam profile & playtime

## Steam (public data only — never ask for the Steam password)
### Linking
Settings → Accounts → Steam: enter profile URL, vanity name or SteamID64, plus the user's own **Steam Web API key** (help text: how to get one). Resolve vanity via `ISteamUser/ResolveVanityURL`, show `GetPlayerSummaries` avatar/name to confirm. Check privacy: if owned games come back empty, explain that "Game details" must be Public.

### Data (*verify current endpoint versions*)
- `IPlayerService/GetOwnedGames` (`include_appinfo=1`, `include_played_free_games=1`): app ID, name, `playtime_forever`, `playtime_2weeks`, `rtime_last_played`, icon hash.
- `IPlayerService/GetRecentlyPlayedGames` for the Home shelf.
- `ISteamUserStats/GetPlayerAchievements` (per app) + `GetSchemaForGame` (names, descriptions, icons, hidden flag) + `GetGlobalAchievementPercentagesForApp` (rarity).
- Art: Steam CDN library assets by app ID (vertical capsule, hero, logo, header) — *verify current CDN URL patterns*; fall back to SteamGridDB by app ID.
- Cache in `steam_cache` with TTL; background refresh on app start (max once per hour) and on demand.

### Presentation
- **Steam** collection/tab in the Library (toggle in settings). Same Capsule, GamePage, Achievements UI as RA (shared components; data source differs). Steam playtime shown as Steam's own numbers ("Steam: 120 hrs").
- **Play** on a Steam game: Steam games can't run natively on Android, so Properties → Compatibility lets the user map it to a **PC-on-Android launcher** profile (GameNative / GameHub / Winlator-family — research which accept an app ID or shortcut via intent) or **Steam Link** / remote play app if installed. If nothing is mapped, Play shows "Choose how to play this game" with those options, or "View on Steam" only.
- Optional: merge a Steam game and a local PC-launcher shortcut that are the same title into one entry (user confirms).

## Playtime (all launched games)
Upstream Pegasus already has `pegasus_playtime`, but on Android it can't tell when the emulator really stopped. DeckOS:
- Records a session start when launching (game, emulator package, time).
- Uses **UsageStatsManager** (`PACKAGE_USAGE_STATS`, user grants in system settings — guided step in Setup Wizard, optional) to count only the time the emulator package was in the foreground until DeckOS resumes. Without the permission: fall back to launch → DeckOS-resume interval, minus time the screen was off.
- Stores sessions in `playtime_sessions`; keeps Pegasus playtime fields in sync so third-party themes still see `game.playTime` / `lastPlayed` / `playCount`.
- Game page stats row like Steam: **LAST PLAYED** (date) · **PLAY TIME** (hrs) · **ACHIEVEMENTS** (x/y). Activity tab: recent sessions list.
- Session toast on return: "Played 42 min · 2 achievements".
- Settings → System → Playtime: export CSV, reset per game.
