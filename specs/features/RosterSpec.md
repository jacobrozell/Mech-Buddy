# Roster Spec — Force tab (Alpha Strike)

## User story

As a player, I keep my box’s eight cards (and match forces) on-device: stats, armor/structure pips, heat, crits, side assignment, and PV balance — so Shoot/SATOR never depends on dry-erase alone.

## Screens

| ID | Role |
|----|------|
| `force.roster` | Shell — hosts mode-specific list |
| `force.as.list` | Alpha Strike roster UI |
| `force.as.unitEdit` | Edit stats / flip variant |
| `force.as.import` | MUL paste |
| `force.as.addUnit` | Add blank / template |

Maps HTML **Roster** tab.

## `force.as.list`

### Chrome

- PV balance bar (Side A vs Side B totals; warn if gap large)
- Actions: **Add ’Mech**, **Repair all**, **Reset to box roster**
- **Import** → `force.as.import`

### Unit row → Unit Focus / edit

- Name (editable), Flip variant (front/back)
- Side A/B toggle
- Stat strip: PV, MV, TMM, SZ, S/M/L, OV, Skill
- Armor / structure **pip tracks**
- Heat level 0–4
- Crit flags: ammo, engine×N, fire control×N, weapon×N, MP, destroyed
- Special abilities text (ENE, CASE, STL, …)
- Dead state when structure exhausted (still listable until End Phase removal in match)

### Box roster seed

Eight double-sided cards from the walkthrough. Reset restores names + default stats; Ridge Line load upserts the four mission units from bundled stats.

## Your collection

Which boxes and minis the player owns. Set in onboarding (Boxes and Your ’Mechs screens) or here. Shown on the Force tab under the PV balance bar (`ForceCollectionSection`, `force.collection`).

- **Not answered yet:** a card “Which boxes do you own?” with **Add your boxes** (`force.collection.start`), which opens the edit sheet.
- **Answered:** Eyebrow “Your collection” with **Edit** (`force.collection.edit`). One card per owned box in catalog order (`force.collection.box.<id>`): title, “×N” for more than one copy, the units you have, and “Missing: …” (chassis names) for unticked units. Unconfirmed boxes say “List not confirmed yet. Add its ’Mechs as singles.” Then a **Singles** card (`force.collection.singles`). Nothing owned: “No minis yet. Coins or any minis work as stand-ins.” (`force.collection.empty`).
- **Edit sheet** (`force.collection.sheet`), a Form with Cancel (`force.collection.cancel`) and Done (`force.collection.done`, saves): **Boxes** — a stepper per box, 0–9 copies (`force.collection.sheet.box.<id>`); one section per owned box with a toggle per unit (`force.collection.unit.<boxId>.<name>`), or the unconfirmed note (`force.collection.unconfirmed.<boxId>`); **Singles** — a stepper per single (`force.collection.single.<name>`, 0 removes, swipe to delete) and the add field (`force.collection.addField`, `force.collection.addButton`).

### Model (`Data/Collection/CollectionModel.swift`)

- `OwnedCollection`: `boxes` (id → copies), `missing` (box id → unit name → copies), `singles` (name → copies). `nil` in `AppPreferences.collection` = not answered.
- Derived with `CollectionMath`: `groups` (owned boxes, then Singles), `ownedUnits` (merged by name with counts), `chassisCounts`, `miniCheck(forces:)` for missions.
- **Chassis matching:** `UnitChassis.name` drops the last word when it has a digit (“Locust LCT-1V” → “Locust”; “Mad Cat Mk II” stays). Matching is case-insensitive. `PlayForceMath.shortName` uses the same rule.
- Singles are free text; adding “locust” to an existing “Locust” adds a copy. No stats are stored.
- Persisted by `CollectionStore` under `collection.owned` (JSON), an `AppPreferences` owned key, so `reset()` / `-reset_state` clears it. Saving the collection also ticks the kit’s Miniatures when anything is owned.

## Import: `force.as.import`

- MUL QuickList URL pattern + paste JSON → upsert
- **No network in Release by default**; `-enable_mul_fetch` for dogfood

## Heat vs ScenarioRuleset

Roster **may** store heat always. Scenarios with `overheatAllowed == false` must not offer OV push in SATOR or End-phase heat coaching. Free Battle defaults allow heat tools when release surface permits.

## Domain type (library record)

```swift
struct AlphaStrikeUnit: Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var variantBack: String?
    var side: ForceSide
    var pv, skill, sz: Int
    var mv: String          // e.g. "10\"j6\""
    var tmm, s, m, l, ov: Int
    var armorCap, structureCap: Int
    var armorDamage, structureDamage: Int
    var heat: Int           // 0...4
    var crits: CritFlags
    var abilities: String
}
```

Match play copies these into `MatchSession.units` — see [MatchSessionSpec](MatchSessionSpec.md).

## Accessibility

- `force.as.list`, `force.as.unit.{id}`, `force.as.pips.armor.{id}`, `force.as.import`
- `force.collection`, `force.collection.start`, `force.collection.edit`, `force.collection.box.{id}`, `force.collection.singles`, `force.collection.empty`, `force.collection.sheet` and its controls (above)

Pip buttons: “Armor bubble 3 of 5, filled/empty”.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-11-24 (Your collection) |
| Commit | — |
| Code paths | Your collection: `Data/Collection/CollectionModel.swift`, `Features/Play/ForceCollection.swift`, `Features/Play/ForceListView.swift`, `App/AppPreferences.swift`. Unit editing / import: *not implemented* |
