# Classic Mode Spec — Normal BattleTech (Coming soon)

**Status:** **Visible Coming soon** in Release (owner 2026-08-21). Not playable until tools slice.  
Screen map locked; deep rules engine deferred until Alpha Strike vertical slice ships.

## Intent

“Normal mode” = **Classic / Total Warfare–style** play: hex movement, record sheets with **hit locations**, heat scale, weapon-by-weapon attacks, piloting skill rolls — not Alpha Strike cards.

## v1.0 UI

| Surface | Behavior |
|---------|----------|
| Mode picker / Play | Classic row with **Coming soon** badge |
| Tap | Info sheet — copy in [ReleaseSurfaceSpec](../ReleaseSurfaceSpec.md). Does not start Classic. The badge stays one line; the row stacks at large type. |
| A11y | `play.classicComingSoon`, `classic.comingSoon.sheet`, `classic.comingSoon.playAS` |
| Force / Rules Classic | Not shown until tools ungated |

## Play engine

`PlayEngineId.classicTWPhased` with capabilities:

| Capability | Value |
|------------|-------|
| showsGuidedMission | false (initially) |
| showsSATOR | false |
| showsArmorStructurePips | false |
| showsHitLocations | true |
| showsHeatScale | true |
| showsPVBalance | false (BV later) |
| showsPhysicalAttacks | true |

## Phase model (v1 tools assume)

1. Initiative  
2. Movement  
3. Weapon Attack  
4. Physical Attack  
5. Heat Phase  

Exact substeps and optional Advanced Rules modules stay out of v1.

## Screens (see ScreenCatalog)

| ID | Purpose | v1 depth |
|----|---------|----------|
| `classic.modeHome` | Entry | Stub CTA |
| `classic.recordSheet` | Location boxes CT/LT/RT/LA/RA/LL/RL/HD + IS | **Tools MVP** candidate |
| `classic.heatScale` | Mark heat, shutdown/ammo cues | Tools MVP |
| `classic.weaponAttack` | TN helpers + cluster/hit location handoff | Tools MVP |
| `classic.hitLocation` | 2D6 location tables (front/side/rear) | Tools MVP |
| `classic.critical` | Location criticals | Tools MVP |
| `classic.piloting` | PSR modifier stack | Planned |
| `classic.battle` | Full guided table | Post-tools |
| `force.classic.*` | Sheet library | With tools |

## Architecture note

Classic math lives in `Domain/Engines/ClassicTW/` — **zero** shared types with SATOR except dice odds utilities. Do not overload `AlphaStrikeUnit`.

## Content / legal

User-entered record sheets preferred. Bundled blank sheet templates OK. No copyrighted record-sheet scans.

## Verification

| Field | Value |
|-------|-------|
| Target release | post-1.0 (tools slice TBD) |
| Last verified | 2026-11-01 |
| Commit | — |
| Code paths | `Features/Play/PlayHomeView.swift` (`classicBlock`); `Features/Play/ClassicComingSoonSheet.swift`. Play tools are not implemented. |
