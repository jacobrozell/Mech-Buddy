# Data Schema Spec — TableMech

Persistence: **SwiftData** + `SchemaV1`… Content: versioned JSON bundles.

## Bundled files (on disk)

```
Resources/Content/game-modes-manifest.json
Resources/Content/AlphaStrike/as-ridge-line.json
Resources/Content/AlphaStrike/as-box-roster.json
Resources/Content/AlphaStrike/as-crit-table.json
Resources/Content/AlphaStrike/as-rules-topics.json
Resources/Content/AlphaStrike/as-getting-started.json
Resources/Content/AlphaStrike/as-scenarios.json
```

See [Resources/README.md](../Resources/README.md). Loader paths are relative to the app bundle.

All packs include:

```json
{
  "schemaVersion": 1,
  "contentVersion": "1.0.0"
}
```

Unknown `schemaVersion` → fail soft (empty content + error banner); do not crash.

### `game-modes-manifest.json`

```json
{
  "schemaVersion": 1,
  "contentVersion": "1.0.0",
  "modes": [
    {
      "id": "alpha-strike",
      "displayName": "Alpha Strike",
      "playEngine": "alphaStrikePhased",
      "availability": "shipped",
      "catalogBundle": "as-quickstart-v1",
      "capabilities": {
        "showsGuidedMission": true,
        "showsSATOR": true,
        "showsArmorStructurePips": true,
        "showsHitLocations": false,
        "showsHeatScale": true,
        "showsPVBalance": true,
        "showsPhysicalAttacks": true,
        "allowsMULPasteImport": true
      }
    },
    {
      "id": "classic-tw",
      "displayName": "Classic",
      "playEngine": "classicTWPhased",
      "availability": "stub",
      "catalogBundle": null,
      "capabilities": {
        "showsGuidedMission": false,
        "showsSATOR": false,
        "showsArmorStructurePips": false,
        "showsHitLocations": true,
        "showsHeatScale": true,
        "showsPVBalance": false,
        "showsPhysicalAttacks": true,
        "allowsMULPasteImport": false
      }
    }
  ]
}
```

### `as-ridge-line.json` (shape)

```json
{
  "schemaVersion": 1,
  "contentVersion": "1.0.0",
  "scenarioId": "ridge-line",
  "title": "Ridge Line",
  "ruleset": {
    "overheatAllowed": false,
    "physicalAttacksAllowed": false,
    "forcedWithdrawal": false,
    "maxTurns": 6,
    "victory": { "type": "destroyAllEnemiesOrStructureAfterTurn", "maxTurn": 6 }
  },
  "sides": {
    "lanceA": [
      { "name": "Shadow Hawk SHD-2H", "pv": 30, "mv": "10\"/6\"j", "tmm": 2, "sz": 2, "s": 2, "m": 2, "l": 1, "ov": 0, "armor": 5, "structure": 5, "skill": 4, "abilities": "IF0*,JMPW1" },
      { "name": "Commando COM-2D", "pv": 17, "mv": "12\"", "tmm": 2, "sz": 1, "s": 2, "m": 2, "l": 0, "ov": 0, "armor": 2, "structure": 2, "skill": 4, "abilities": "SRM1/1" }
    ],
    "lanceB": [
      { "name": "Wolverine WVR-6M", "pv": 32, "mv": "10\"j", "tmm": 2, "sz": 2, "s": 2, "m": 2, "l": 0, "ov": 1, "armor": 6, "structure": 5, "skill": 4, "abilities": "" },
      { "name": "Locust LCT-1V", "pv": 18, "mv": "16\"", "tmm": 3, "sz": 1, "s": 1, "m": 1, "l": 0, "ov": 0, "armor": 2, "structure": 2, "skill": 4, "abilities": "" }
    ]
  },
  "tableSteps": [
    "Both mapsheets grassland up (~36\"×22\")",
    "Measure in inches",
    "Woods only (+1\" move, +1 to hit in/behind)",
    "Ignore elevation, water, buildings",
    "Deploy within 6\" of own short edge; initiative loser places first"
  ]
}
```

### `as-box-roster.json`

Array of card seeds: `name`, `back`, `sz`, `defaultSide`, optional stats (nullable → user fills). Ridge Line four should match ridge-line stats when present.

### `as-crit-table.json`

```json
{
  "schemaVersion": 1,
  "contentVersion": "1.0.0",
  "entries": [
    { "roll": 2, "id": "ammo", "title": "Ammo hit" },
    { "roll": 3, "id": "engine", "title": "Engine hit" },
    { "roll": 4, "id": "fireControl", "title": "Fire control" },
    { "roll": 5, "id": "none", "title": "No critical" },
    { "roll": 6, "id": "weapon", "title": "Weapon hit" },
    { "roll": 7, "id": "mp", "title": "MP hit" },
    { "roll": 8, "id": "weapon", "title": "Weapon hit" },
    { "roll": 9, "id": "none", "title": "No critical" },
    { "roll": 10, "id": "fireControl", "title": "Fire control" },
    { "roll": 11, "id": "engine", "title": "Engine hit" },
    { "roll": 12, "id": "destroyed", "title": "Destroyed" }
  ]
}
```

Effects implemented in Domain (not only JSON copy).

### `as-rules-topics.json`

```json
{
  "schemaVersion": 1,
  "topics": [
    { "id": "turn", "title": "The turn", "sections": [ { "heading": "…", "body": "…" } ] },
    { "id": "movement", "title": "Moving", "sections": [] },
    { "id": "combat", "title": "Shooting checks", "sections": [] },
    { "id": "sator", "title": "SATOR reference", "sections": [] },
    { "id": "damage", "title": "Damage, criticals, heat", "sections": [] },
    { "id": "tables", "title": "Quick tables", "sections": [] },
    { "id": "abbreviations", "title": "Card abbreviations", "sections": [] },
    { "id": "odds", "title": "2D6 odds", "sections": [] }
  ]
}
```

Screen IDs: `rules.as.{id}` with `sator` → screen `rules.as.satorRef` alias OK; prefer topic id == screen suffix except `sator`↔`satorRef` and `abbreviations`↔`abbreviations`.

---

## SwiftData SchemaV1 (conceptual → implement as `@Model`)

| Model | Key attributes |
|-------|----------------|
| `SDASUnitRecord` | id, name, back, sideRaw, skill, pv, sz, mv, tmm, s, m, l, ov, armorCap, structureCap, armorDamage, structureDamage, heat, abilities, crit JSON |
| `SDMatchSession` | id, modeId, scenarioId?, statusRaw, turn, phaseRaw, activeSideRaw, ruleset JSON, units JSON, eventLog JSON, initiative JSON, flags, updatedAt |
| `SDChecklistState` | keys → bool map or discrete bools |
| `SDUserPreferences` | appearanceRaw, haptics, defaultSkill, defaultModeId |

**Versioning:** `SchemaV1` registered in `VersionedSchema`; `MigrationPlan` empty initially; next bump = `SchemaV2` + tests.

`SDMatchSession.statusRaw` stays a plain string. Gameplay writes `active`, `completed`, and `abandoned`. `loadActive` writes `unreadable` when a payload will not decode or its schema version is newer than `MatchSession.currentSchemaVersion`, then returns the next readable active row, or nil. Unreadable rows are kept. `delete(id:)` and `deleteAll()` still remove them and clear those ids from `unreadableSessionIDs`. Play drops the set-aside notice when that list is empty. A SwiftData container failure falls back to memory and Play shows a non-dismissible banner (`AppDependencies.isUsingVolatileStore`), except when `-ui_testing` asked for an in-memory store.

Bootstrap failure → full-screen recovery: Retry / Delete All Local Data (Settings path). The unreadable-row path is the per-save version of that recovery: the bad row is set aside and a new game can start.

## MUL paste (v1)

Accept QuickList-like JSON with `Units` array; map `Name`, AS damage fields when present. Upsert Force library by normalized name. On failure: inline error string (no throw to UI). Exact MUL field map: best-effort; document supported keys in import sheet footnote.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-11-01 |
| Commit | — |
| Code paths | `Persistence/SwiftDataMatchSessionRepository.swift`; `Persistence/SchemaV1/SchemaV1.swift`; `App/AppDependencies.swift` |
