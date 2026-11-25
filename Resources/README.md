# Bundled content resources

Offline JSON loaded by `ContentCatalogRepository` (see [DataSchemaSpec](../../specs/DataSchemaSpec.md)).

## Layout

```
Resources/Content/
  game-modes-manifest.json
  rules-both-games.json      # Rules tab pages tagged `both` (how the two games differ)
  AlphaStrike/
    as-ridge-line.json       # Mission 1: Ridge Line scenario + golden stats
    as-broken-ground.json    # Mission 2: Broken Ground (same four checked cards)
    as-running-hot.json      # Mission 3: Running Hot (overheat)
    as-close-quarters.json   # Mission 4: Close Quarters (punch or kick, 3 vs 3)
    as-full-lances.json      # Mission 5: Full Lances (all eight box cards, Forced Withdrawal)
    as-box-roster.json       # Eight box cards (4 with stats, 4 name/size seeds)
    as-box-sets.json         # Boxes a player can own: unit names only, for the collection
    as-crit-table.json       # Critical 2–12
    as-rules-topics.json     # Rules tab, Alpha Strike topics (game: alphaStrike)
    as-getting-started.json  # Checklist items
    as-scenarios.json        # Mission ladder: order, what each adds, gates, bundle file
  Classic/
    classic-agoac-sheets.json   # A Game of Armored Combat record sheets
    classic-rules-topics.json   # Rules tab, Classic topics (game: classic). Reading only
```

## Rules

- Every file has `schemaVersion` + `contentVersion`
- Unknown schema → fail soft in the loader
- Human-readable twins: [docs/game-modes/alpha-strike/bundled-fixtures.md](../../docs/game-modes/alpha-strike/bundled-fixtures.md)
- Do not commit copyrighted card art or full MUL dumps
- Missions load by id through `as-scenarios.json` → `bundle`. A gated entry has `bundle: null`
- Mission card numbers must come from a Master Unit List check (see `MissionLadderTests`)
- 1.0 ships Ridge Line only. The 1.1 branch adds Broken Ground behind `missionLadder`. Later army-building cards are looked up on [masterunitlist.battletech.com](https://masterunitlist.battletech.com/), not copied in as a catalog dump

## Phase 0 note

Wire these into the app target’s Copy Bundle Resources when XcodeGen lands (`Resources/**` or explicit paths).
