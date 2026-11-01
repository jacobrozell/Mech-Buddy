# Bundled content resources

Offline JSON loaded by `ContentCatalogRepository` (see [DataSchemaSpec](../../specs/DataSchemaSpec.md)).

## Layout

```
Resources/Content/
  game-modes-manifest.json
  AlphaStrike/
    as-ridge-line.json       # Ridge Line scenario + golden stats
    as-box-roster.json       # Eight box cards (4 with stats, 4 name/size seeds)
    as-crit-table.json       # Critical 2–12
    as-rules-topics.json     # Rules browser copy
    as-getting-started.json  # Checklist items
    as-scenarios.json        # Scenario catalog / gates
```

## Rules

- Every file has `schemaVersion` + `contentVersion`
- Unknown schema → fail soft in the loader
- Human-readable twins: [docs/game-modes/alpha-strike/bundled-fixtures.md](../../docs/game-modes/alpha-strike/bundled-fixtures.md)
- Do not commit copyrighted card art or full MUL dumps
- 1.0 ships Ridge Line only. Later army-building cards are looked up on [masterunitlist.battletech.com](https://masterunitlist.battletech.com/), not copied in as a catalog dump

## Phase 0 note

Wire these into the app target’s Copy Bundle Resources when XcodeGen lands (`Resources/**` or explicit paths).
