# Changelog

One entry per build the owner tests. Newest first.

## Unreleased
- Windows dev toolchain (Qt 5.15.2 MinGW, SDL2 2.32.10) and scripts: `tools/build.ps1`, `tools/test.ps1`, and the release gate `tools/check.ps1` (build + all unit tests). Unmodified Pegasus builds clean and passes 191/191 tests.
- New README, docs index, release-flow spec (`docs/13-release-flow.md`), GitHub issue forms.
- Phase 0: upstream Pegasus cloned into `deckos/` (DeckOS work on branch `main`, `master` mirrors upstream); docs, catalog and changelog now versioned in the repo; reference/toolchain dirs gitignored.
- `tools/bootstrap.ps1` fixed to run under Windows PowerShell 5.1 (non-ASCII dashes in a UTF-8 file without BOM broke parsing).
- Starter kit: brief, specs, references, bootstrap scripts.
