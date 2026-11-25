# Content Pack Spec — Scaling modes & rules

Long-term rule: **adding a mode or scenario is data + one engine registration**, not 25 feature `switch` arms.

## Concepts (do not conflate)

| Concept | Example | Owns |
|---------|---------|------|
| `GameModeId` | `alpha-strike`, `classic-tw` | Namespace for content + sessions |
| `PlayEngineId` | `alphaStrikePhased`, `classicTWPhased` | Turn/phase behavior family |
| `PlayCapabilities` | booleans / optionals | What UI may show |
| `ContentPack` | `as-quickstart-v1` | Bundled JSON version |
| `ScenarioId` | `ridge-line` | Guided mission definition |
| `ScenarioRuleset` | flags | Which optional rules are on |

## Manifest (`game-modes-manifest.json`)

```json
{
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
    }
  ]
}
```

`availability`: `shipped` | `gated` | `stub`. Release surface may further hide `shipped` items for lean cuts.

## PlayEngine protocol (Domain)

```swift
public protocol PlayEngine: Sendable {
    var id: PlayEngineId { get }
    var phaseOrder: [PhaseId] { get }
    func advance(from phase: PhaseId) -> PhaseId?
    func prompt(for context: PhaseContext) -> PhasePrompt
}

public protocol CombatResolver: Sendable {
    // Mode-specific; AS implements SATOR path, Classic implements weapon+location
}
```

Features ask the registry for `any PlayEngine` / capabilities. **Never** `if modeId == "alpha-strike"` in Views.

## ScenarioRuleset

```swift
public struct ScenarioRuleset: Sendable, Equatable, Codable {
    public var overheatAllowed: Bool
    public var physicalAttacksAllowed: Bool
    public var forcedWithdrawal: Bool
    public var maxTurns: Int?          // e.g. 6 for Ridge Line tiebreak
    public var victory: VictoryRule
}
```

Ridge Line: OV/physical/withdrawal = `false`. Free Battle defaults: all `true` (subject to release surface).

## Add a new mode checklist

1. Add engine implementation under `Domain/Engines/<Name>/` + unit tests  
2. Add manifest entry + content pack JSON  
3. Add capabilities; extend `PlayCapabilities` only if a **new UI family** appears  
4. Add screen IDs to ScreenCatalog + feature specs  
5. Gate in ReleaseSurface until QA matrix passes  
6. Update PRODUCT_SCOPE + feature inventory  

**Forbidden:** copying an entire Features folder and swapping strings.

## Content versioning

- Packs carry `schemaVersion` + `contentVersion`
- App refuses unknown schema (fail soft → empty state + telemetry)
- User data references `GameModeId` + pack version at write time for migrations

## Rules topics

`RulesTopicDTO` (`Data/Content/ContentDTOs.swift`) and `as-rules-topics.json` include two optional fields:

| Field | When present | When omitted |
|-------|----------------|--------------|
| `summary` | One-line row subtitle on Rules | First sentence of the first section (`RulesGroup.summary`) |
| `group` | `start`, `during`, or `reference` | `RulesGroup.resolve` maps by topic id |

Sections stay `{ heading, body }`. The pack has no structured table block.

## Box sets

`as-box-sets.json` → `BoxSetsDTO` / `BoxSetDTO` (`Data/Content/ContentDTOs.swift`), loaded by `ContentCatalogRepository.boxSets()` and held once in `AppDependencies.boxSets`. It feeds the onboarding box question and the Force tab collection ([RosterSpec](features/RosterSpec.md#your-collection)).

| Field | Meaning |
|-------|---------|
| `id` | Stable box id (`onboarding.box.<id>`, stored in the collection) |
| `title`, `subtitle` | Tile copy. Subtitle ≤ 48 characters |
| `game` | `alphaStrike`, `classic`, or `both`; shown as the tile badge |
| `miniCount` | Minis in the box, vehicles included |
| `units` | Unit names only. A variant code only when the publisher states it. **No card stats**: those come from the Master Unit List |
| `requires` | Optional box ids needed to play it |
| `sourceURL` | https source for the contents |
| `contentsConfirmed` | `false` → `units: []`; the UI says the list isn’t confirmed and the player adds units by hand |

Shipped boxes:

| id | Title | Game | Minis | Units |
|----|-------|------|-------|-------|
| `agoac` | A Game of Armored Combat (2019) | both | 8 | Awesome AWS-8Q, BattleMaster BLR-1G, Catapult CPLT-C1, Commando COM-2D, Locust LCT-1V, Shadow Hawk SHD-2H, Thunderbolt TDR-5S, Wolverine WVR-6M (same as `as-box-roster.json`) |
| `alpha-strike-box` | Alpha Strike Box Set | alphaStrike | 13 | Fire Moth, Nova, Pouncer, Timber Wolf, Warhawk, Archer, Atlas, Blackjack, Locust, Phoenix Hawk, Warhammer, Wasp, Wraith |
| `starter-box` | Starter Box | classic | 2 | Hammerhead, Kontio |
| `core-box` | Core Box Set | classic | 8 | Hollander, Rakshasa, Solitaire, Uziel, Mad Cat Mk II, Vulture Mk IV, Regent, Eris |
| `mercenaries-box` | Mercenaries Box Set | classic | 12 (8 ’Mechs, 4 vehicles) | Not confirmed (`units: []`). Requires `agoac` |

`Tests/Unit/CollectionTests.swift` (`BoxSetsContentTests`): unique ids, unit count = `miniCount` for confirmed boxes, Mercenaries unconfirmed, A Game of Armored Combat = box roster, no stat keys.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-10-28 |
| Commit | `b9acebb` (tag `0.2.0`) |
| Code paths | `Data/Content/ContentDTOs.swift` (`RulesTopicDTO.summary`, `RulesTopicDTO.group`, `BoxSetsDTO`), `Data/Content/BundleContentCatalogRepository.swift` (`boxSets()`), `Resources/Content/AlphaStrike/as-rules-topics.json`, `Resources/Content/AlphaStrike/as-box-sets.json`, `Features/Play/RulesHomeView.swift` (`RulesGroup`) |
