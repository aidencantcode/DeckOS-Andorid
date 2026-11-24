# 05 — Emulators & launching

## Principles
- **Auto when known, editable always, generic when unknown.**
- The user never has to type an `am start` line — but can see and edit every one.
- The emulator catalog is **data**, not code: JSON files in `catalog/emulators/`, bundled in the APK, plus user overrides in the app data dir. New emulators can be added without a rebuild (Settings → Emulators → Add / Import JSON).

## Catalog entry (see `catalog/emulators.example.json` for the full schema)
Key fields: `id`, `name`, `systems[]`, `android.packages[]` (all known package IDs incl. forks/variants), `android.profiles[]` (one or more launch profiles, each with `label`, `activity`, `command_template`, `file_access` = `path` | `content_uri` | `document_uri`, `extras`, `flags`), `pc` (exe names + args, for dev testing only), `notes`, `verified` (bool), `verified_on` (device + date), `source` (where the intent info came from).

Templates use Pegasus placeholders already supported by `ProcessLauncher`: `{file.path}` `{file.uri}` `{file.documenturi}` `{file.name}` `{file.basename}` `{file.dir}` `{env.VAR}`. Add DeckOS placeholders in the resolver (expanded before handing to Pegasus): `{pkg}`, `{activity}`, `{core.path}`, `{retroarch.config}`, `{system.id}`, `{game.serial}`, `{steam.appid}`.

## Detection (Android)
- Java `PackageScanner`: list installed packages (needs `QUERY_ALL_PACKAGES` or `<queries>` entries — we sideload, so `QUERY_ALL_PACKAGES` is fine), match against catalog `android.packages[]`, read version names, resolve launcher activity for unknown apps.
- **RetroArch**: detect variants (64-bit/32-bit/Play Store/nightly packages — *verify current IDs*), find available cores (from RetroArch's `cores` dir or core info files where readable; otherwise from a known-default list and let launch fail gracefully), map system → preferred core with user override.
- Rescan on app resume (cheap) so newly installed emulators appear.

## Resolution order when the user presses Play
1. Per-game override (Properties → Compatibility).
2. Per-system default emulator + profile (Settings → Emulators → by system).
3. First installed catalog emulator for the system (ranked by catalog `priority`).
4. **Generic fallback** (unknown emulator / user picked "any app"): `am start -a android.intent.action.VIEW -d {file.uri} -t <mime or */*> -n {pkg}/{activity}` with read-URI permission grant via our FileProvider, where `{activity}` = the package's launcher/VIEW-capable activity. If that fails, offer "Open with…" chooser.

## UI
- **Play button** long-press / **Y** → "Launch with…" list (all installed emulators/profiles for the system).
- **Properties → Compatibility**: emulator, profile, RetroArch core, extra arguments, *resolved command preview* (read-only, monospace), **Edit custom command** (multi-line editor with on-screen keyboard and a placeholder palette), **Reset to default**, **Test launch**.
- **Settings → Emulators**: per system default; per emulator page (detected version, packages found, profiles, verify status, "Report working" toggle that sets `verified` locally).
- **Launch log**: last 50 launches with resolved command, result, errors (Settings → System → Launch log). Shown automatically when a launch fails, with "Edit command" shortcut.

## Owner's list (to add and verify on device — names as given, owner will confirm exact apps/packages)
| Name as given | Likely system | Notes |
|---|---|---|
| ARMSX2 | PS2 | |
| ARMSX3 | PS3 | owner launches it from ES-DE/Pegasus already; installed PKG games vs ISO need different handling |
| "hakux" | ? | confirm with owner |
| XenDroid+ | Xbox 360 | |
| Bachta PS4 ("bachtas4") | PS4 | |
| Vita3K | PS Vita | |
| "peanuts native" | ? | confirm |
| "banana native" | ? | confirm |
| "lichi" (Switch 2 emulator) | Switch 2? | confirm |
| Eden | Switch | |
| Ludashi | PC (Windows games) | confirm what it is |
| Winlator | PC | per-game shortcut launching |
| BannerHub | PC | confirm |
| GameHub | PC | |
| GameNative | PC / Steam | may have Steam app-ID launching — research |

Plus the standard set to seed and verify (get intents from each project's docs/source or from ES-DE / Daijishō definitions — facts, not copied files): RetroArch, DuckStation, AetherSX2/NetherSX2-family, PPSSPP, Dolphin (+ MMJR-family forks), Azahar / Citra forks, melonDS, DraStic, Flycast, Redream, Mupen64Plus FZ, Yaba Sanshiro, Saturn emus, ScummVM, Eden / other Switch forks, Vita3K.

## PC-on-Android launchers (Winlator family, GameHub, GameNative…)
These usually launch games via their own shortcuts, not a file path. Support:
- `launch_kind: "shortcut"` profiles: DeckOS stores which launcher + which shortcut/game ID; command template uses `{game.extra.<key>}` from metadata.
- Import: if the launcher exports `.desktop`/shortcut files to a readable folder, scan them as a "PC Games" collection. Research each launcher's intents (`docs/DECISIONS.md` entry per launcher).

## PC (dev only)
Catalog `pc` blocks let you launch e.g. RetroArch/PPSSPP on the dev PC to test the launch path. Don't spend time beyond that.
