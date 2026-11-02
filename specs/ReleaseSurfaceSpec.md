# Release Surface Spec — Mech Buddy

## Principle

Build wide internally; ship narrow. One module answers “is X reachable?”

## v1.0 defaults (owner-locked 2026-08-21)

| Flag | Release | Full surface | Notes |
|------|---------|--------------|-------|
| Alpha Strike Play | on | on | |
| Ridge Line mission | on | on | |
| Full Lances scenario | off | on | |
| Free Battle | **off** | on | **1.1** |
| Physical / OV / Forced Withdrawal tools | off | on | |
| Classic mode entry | **on (Coming soon)** | on | Visible teaser — not playable |
| Classic play / tools | off | on | |
| MUL network fetch | off | on | Paste import OK |
| Match history | off | on | |
| Tip jar row | **off** | off | Owner: no tip jar |

### Classic “Coming soon”

- Mode picker / Play shows Classic with badge **Coming soon**
- Tap → short explanation sheet (record sheets / hex tools planned); **no** Classic battle
- Not a hidden gate — honest visibility

**Copy (locked draft):**  
Title: Classic BattleTech  
Body: Record sheets, heat, and hit locations are coming in a later update. For now, play Alpha Strike guided matches — start with Ridge Line.  
CTA: **Play Alpha Strike** (dismisses sheet)

### Swift API

```swift
enum ReleaseFlag: String, CaseIterable, Sendable {
    case alphaStrikePlay
    case ridgeLineMission
    case fullLancesScenario
    case freeBattle
    case physicalOvWithdrawal
    case classicComingSoonEntry
    case classicPlayTools
    case mulNetworkFetch
    case matchHistory
    case tipJar
}

struct ReleaseSurface: ReleaseSurfaceProviding {
    var isFullProductSurface: Bool  // ProcessInfo launch arg
    func isEnabled(_ flag: ReleaseFlag) -> Bool
}
```

Defaults: match table above when `isFullProductSurface == false`. Tip jar always false.

Launch arg `-enable_full_product_surface` enables Full column (Classic tools, Full Lances, Free Battle, etc.). Never in App Store builds.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-08-21 |
| Commit | — |
| Code paths | *not implemented* |
