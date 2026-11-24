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
