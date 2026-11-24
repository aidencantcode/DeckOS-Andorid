# 13 — Release flow: Windows test gate → GitHub → Android test build

How a change gets from the PC onto the owner's handhelds. Agreed with the owner on 2026-11-25.

## The loop

```
 develop on Windows ──► tools/check.ps1 (the gate) ──► tools/ship.ps1 ──► tag v0.P.B pushed
                              │ fails → fix, repeat                          │
                                                                             ▼
 owner reports bugs ◄── owner installs APK on Odin 3 / RP Classic ◄── GitHub Actions builds APK,
 (issue form / PROMPTS.md)        (installs over the previous build)      publishes a pre-release
```

1. **Develop on Windows.** The PC build is the proper testing ground: everything is built, run and screenshotted here first. Every build that passes the gate is copied to `windows-build\` (next to `deckos\`, outside the repo) — double-click the exe there to try it yourself; see its `README.txt`.
2. **The gate — `tools/check.ps1`.** Build with warnings visible → unit tests (`make check`) → `qmllint` → offscreen smoke test (fails on any QML warning) → screenshot tour at 1920×1080 and 1240×1080, which Claude Code opens and reviews. Until the smoke test and tour exist (Phase 0 "dev tooling" item), the gate is build + unit tests + a manual run with screenshots.
3. **Ordinary pushes** to `origin/main` are fine at any time (backup, progress). They run a cheap Linux build + tests on GitHub, **not** an Android build.
4. **Shipping a test build — `tools/ship.ps1 [-Phase N] [-DryRun]`.** Picks the next version, turns the `## Unreleased` part of `CHANGELOG.md` into `## 0.P.B — <date>`, commits `Release DeckOS 0.P.B` and tags `v0.P.B` locally, then runs the gate as a clean build of exactly that commit (so `windows-build\` shows the same version). Gate passed → pushes `main` + the tag atomically; gate failed → commit and tag are undone, nothing is pushed.
5. **Tag push → `android.yml`.** Builds the arm64-v8a APK, signs it with the stable DeckOS test key, and publishes a GitHub **pre-release** "DeckOS 0.P.B" with the APK attached and that version's changelog section as release notes.
6. **Owner tests.** Open the repo's *Releases* page on the handheld, download the APK, install it over the previous build (same signing key → settings and data are kept). Follow the checklist Claude Code gave for that build. Report with the **Test report** issue form on GitHub (or the `PROMPTS.md` template in chat).
7. Fixes land in the next build. Repeat.

A manual Android build of any commit can also be started from the Actions tab (*Run workflow*); it produces a downloadable artifact instead of a release.

## Version numbers

| Thing | Format | Example |
|---|---|---|
| Version / tag | `0.<phase>.<build>` → tag `v0.<phase>.<build>` | `0.0.1`, `0.1.4` |
| Android `versionCode` | `major × 1 000 000 + phase × 1 000 + build` | `0.1.4` → `1004` |
| APK file | `DeckOS_<version>_<shortsha>_arm64.apk` | `DeckOS_0.1.4_abc1234_arm64.apk` |
| Untagged build | `git describe` of the last tag | `0.1.4-3-gabc1234` |

- **phase** = the roadmap phase the build belongs to (`docs/02-roadmap.md`). **build** counts 1, 2, 3… within a phase and restarts at 1 when the phase goes up. `1.0.0` is reserved for the first public release (end of Phase 7).
- `versionCode` only ever goes up as versions go up, so Android always accepts the new APK as an update. Limit: build ≤ 999 per phase.
- The full version + commit is shown in Help → About and in the log header (`lastrun.log`), so every bug report says exactly which build it came from.

## Signing

- One stable **test key** (PKCS#12, alias `deckos-test`, RSA 4096, valid until 2056; certificate SHA-256 `DD:9B:25:48:…:3F:49`), generated 2026-11-25 with OpenSSL and kept **outside** the repo in `DECKOS\secrets\` (see the README there). GitHub repo secrets: `DECKOS_KEYSTORE_B64` (base64 of the file), `DECKOS_KEYSTORE_PASSWORD`, `DECKOS_KEY_ALIAS`. `android.yml` refuses to publish an APK that isn't signed with exactly this key (v2 signature checked too).
- Why it matters: Android only installs an update over an existing app if the signature matches. A stable key = no uninstall between builds = the owner's settings, accounts and scrape cache survive.
- Never commit it, never print it in CI logs. The owner keeps a backup copy; losing it means one uninstall/reinstall (data lost), nothing worse.
- The key for public releases (Phase 7) is a separate, new key.

## What lives on GitHub

- **`main`** = DeckOS (default branch). Upstream Pegasus history is included; upstream's own tags are *not* pushed, so the tag list only shows DeckOS versions.
- **Actions:** `android.yml` (tags `v*` + manual), `ci.yml` (Linux build + tests on pushes/PRs).
- **Releases:** one pre-release per test build, newest first.
- **Issues:** *Test report* and *Idea* forms.
