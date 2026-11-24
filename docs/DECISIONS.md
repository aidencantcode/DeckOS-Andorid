# Decisions log

Format: `## YYYY-MM-DD — Title` · **Decision** · **Why** · **Alternatives considered** · **Revisit if**

## 2026-11-25 — Starter kit baseline
- **Decision:** Fork Pegasus Frontend (GPLv3) on Qt 5.15 as upstream does; DeckOS shell is a new built-in QML theme; new features are C++ services exposed as a `deckos` QML object; reference themes are study-only.
- **Why:** Upstream Android toolchain (prebuilt Qt 5.15.10, NDK r21e) already works; all reference themes target Qt 5; license separation (BigScreenFE is CC BY-NC-SA, StMini unlicensed with Valve assets).
- **Alternatives:** Qt 6 port (more work, breaks QtGraphicalEffects-based themes); keep everything in QML like BigScreenFE (insecure keys, no caching, no hashing).
- **Revisit if:** a Qt 5 limitation blocks a headline feature on Android.

## 2026-11-25 — Branch model and where the docs live
- **Decision:** In `./deckos`, branch `master` stays a pristine mirror of `upstream/master`; all DeckOS work happens on `main` (feature branches `feat/<area>-<thing>` off `main`). `docs/`, `catalog/` and `CHANGELOG.md` moved into the repo; the top-level `CLAUDE.md` stays outside (unversioned) and notes the new paths.
- **Why:** A clean `master` makes upstream syncs a plain fast-forward followed by `git merge master` into `main`, and keeps the diff against upstream easy to read. Versioning the docs keeps the roadmap/decisions in step with the code.
- **Alternatives:** Commit straight on `master` (muddles upstream syncs); keep docs outside the repo (unversioned, drift).
- **Revisit if:** the owner wants a different default branch name on GitHub.

## 2026-11-25 — Release flow, version numbers, GitHub presentation
- **Decision:** Windows PC build is the test gate; only builds that pass it are shipped. Shipping = `tools/ship.ps1` tags `v0.<phase>.<build>` and pushes; the tag triggers the Android workflow, which publishes a GitHub pre-release with the signed APK. `versionCode = major*1000000 + phase*1000 + build`. Full spec: `docs/13-release-flow.md`.
- **Why:** Owner wants to test on device only builds that already work on PC, and to grab APKs straight from the Releases page on the handheld (artifacts need a GitHub login and come zipped). A version-derived `versionCode` is reproducible and identical locally and in CI, unlike the CI run number (which differs per workflow and resets if workflows are renamed) or upstream's commit count (meaningless across forks).
- **Alternatives:** Build an APK on every push (wastes CI time, floods the owner with untested builds); CI run number as `versionCode` (the original `03-dev-loop.md` plan).
- **Also:** Upstream `.github/FUNDING.yml` and Pegasus issue templates replaced by DeckOS issue forms (upstream support is credited in the README instead). Upstream tags are not pushed to the DeckOS repo so its tag list shows only DeckOS versions. These files may conflict on upstream syncs — keep ours.
- **Revisit if:** the owner wants nightly builds of every push, or a Play Store/F-Droid channel.
