# 07 — Scraping (art, metadata, video)

Owner preference: **SteamGridDB first** for library art (it's what makes a library look like Steam). Owner previously built a SteamGridDB + IGDB scraper for Pegasus called "Cartridge" because ScreenScraper felt slow, inaccurate and weak for indie titles, so use ScreenScraper mainly for what only it does well (box art by hash, wheels, **videos**). Ask the owner if you want Cartridge's code as reference.

## Providers (plugin interface `IScrapeProvider`: capabilities, auth, rate limit, search, fetch, download)
| Provider | Auth | Best for | Notes (*verify all endpoints/params*) |
|---|---|---|---|
| **SteamGridDB** | user API key (free) | grids (600×900 poster, 920×430 / 460×215 horizontal), heroes, logos, icons | v2 API: search/autocomplete by name, then `/grids|heroes|logos|icons/game/{id}` with dimension/style filters; also by Steam app ID. Honor nsfw/humor filters (default off). |
| **ScreenScraper** | dev credentials (app) + user account | box 2D/3D, wheel/logo, screenshots, fanart, **normalized videos**, descriptions; hash-based ID | `api2` `jeuInfos` by crc/md5/sha1 + size + filename + system id; per-user thread & daily quota limits — read them from the user-info response and obey. Apply for DeckOS dev credentials; until then let users enter their own. |
| **IGDB** | Twitch client id/secret (user) | metadata (summary, genres, developer, publisher, release date, rating), covers, artworks, screenshots | OAuth client-credentials token caching; Apicalypse queries; platform filter from systems catalog. |
| **libretro-thumbnails** | none | box art, title screens, snaps for No-Intro/Redump-named ROMs | Static URLs by system + exact No-Intro name (special chars replaced per libretro rules). Great free fallback; no API load. |
| **RetroAchievements** | RA key (already have) | icon, title screen, in-game screenshot, box art for RA-matched games | Free once matched by hash. |
| **TheGamesDB** | API key | metadata, box art, fanart, banners | Fallback. |
| **OpenVGDB** (if that's what the owner meant by "openbd" — confirm) | none, offline SQLite | hash → canonical release name/region/cover URL | Ship or download the DB; great for offline identification. |
| **Steam CDN** | none | official library art for Steam games (Phase 5) | Library capsule / hero / logo / header by app ID. |

## Identification (shared by all providers)
`Identity` = system + cleaned title + region + (lazy) CRC32/MD5/SHA1 + RA GameID + serial (PS1/PS2 from SYSTEM.CNF, PSP/PS3/Vita from PARAM.SFO, Switch title ID from filename/NCA if available). Each provider match gets a **confidence score**; below threshold → job lands in **Needs review** (Downloads page) with candidates to pick from. User choices are remembered.

## Art slots → Pegasus asset names (keep themes compatible; log final mapping in DECISIONS.md)
| Slot (Steam name) | Size target | Pegasus asset |
|---|---|---|
| Library capsule (vertical grid) | 600×900 | `poster` (also fill `boxFront` if empty? → decide) |
| Horizontal capsule | 920×430 / 460×215 | `steam` |
| Hero (game page header) | 1920×620 | `background` (+ keep original as `hero` in DeckOS DB) |
| Logo | transparent PNG | `logo` |
| Icon | square | `tile` |
| Box front / back / 3D | — | `boxFront`, `boxBack`, `boxFull` |
| Screenshot / title screen | — | `screenshot`, `titlescreen` |
| Video | mp4 (H.264) | `video` |
| Fanart | — | `background` only if hero missing |

Files go to `<media root>/<system>/<game basename>/<asset>.<ext>` so `pegasus_media` picks them up. Store provenance (provider, id, url, chosen-by-user) in `scrape_results`.

## Default priority per slot (user-editable, drag-to-reorder in settings)
- poster / horizontal / hero / logo / icon: **SteamGridDB → ScreenScraper → libretro-thumbnails → RA → IGDB/TGDB**
- box front: ScreenScraper → libretro-thumbnails → SteamGridDB → TGDB
- screenshot / title: ScreenScraper → libretro-thumbnails → RA → IGDB
- metadata text: IGDB → ScreenScraper → TGDB → OpenVGDB
- video: ScreenScraper (normalized) only, unless another source is added later

## Queues
- **Fast queue**: identification + metadata + images. Parallel per provider within its limits (e.g. SGDB 4, SS = user's thread allowance, libretro 4). Small downloads, resized on device (Qt image scaling on worker thread) to slot target size; generate small capsule thumbnails in cache for scrolling performance.
- **Heavy queue**: videos, manuals, fanart, 3D boxes. Low concurrency (1–2), Wi-Fi-only by default, pause/resume, survives app restarts, never runs while a game is running (setting).
- Both persisted in `scrape_jobs`; Downloads page shows active, queued, failed, needs review, with per-game retry.

## UI
- **Library Settings → Scraper**: Scrape all / Scrape system… / Only missing vs overwrite; per-slot source order; which slots to fetch; video on/off + quality; Wi-Fi only; concurrency; credentials per provider with Verify; storage used per type + "Clear videos", "Clear all media" (confirm).
- **Game → Properties → Artwork**: one row per slot showing current image; A → candidate grid from all providers (with source + resolution labels), switch provider with L1/R1, "Search with a different name…", "Pick local file…", "Reset to automatic". Changes apply instantly.
- **Game → Properties → Details**: edit title, description, developer, genre, release, players, region; "Re-scrape metadata".
- Context menu on capsule: "Re-scrape artwork".

## Etiquette
Identify DeckOS with a proper User-Agent (`DeckOS/<version> (+repo url)`), cache aggressively, never hammer APIs, respect each service's ToS and quotas, surface quota errors clearly to the user.
