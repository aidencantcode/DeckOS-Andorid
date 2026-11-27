# DeckOS system and emulator catalog

`systems.json` is generated — do not edit it by hand. It is converted from the system definitions of
**NeoStation** (copyright © 2025-2026 Miguel Soto, https://github.com/misobadev/neostation-frontend,
`assets/systems/*.json`), licensed under the **GNU GPL v3** like DeckOS. The source commit is recorded in
the file's `source` field.

Regenerate after updating the NeoStation checkout in `../third_party_refs/neostation-frontend`:

```powershell
tools\import-neostation-catalog.ps1
```

What is kept, and how NeoStation's launch placeholders map to Pegasus's, is described at the top of that
script. The file is compiled into the app through `assets/assets.qrc` (`:/deckos/catalog/systems.json`).

`deckos-systems.json` is DeckOS's own, written by hand and **merged on top** of `systems.json` at start-up
(`Catalog::merge`): new systems (PS4, PS5), extra folder names, `gameFolders` markers for games that are folders,
and emulators to add or replace (same `id`). Put new or corrected emulators there, so a re-import of NeoStation's
catalog never loses them. It is compiled in as `:/deckos/catalog/deckos-systems.json`.
