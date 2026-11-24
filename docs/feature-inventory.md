# Feature Inventory — Mech Buddy

What the app exposes. Specs describe behavior; this file says whether code exists.

**App version:** 1.0.0 (build 1). Not tagged until the build is approved.  
**Product release target:** 1.0.0 — Alpha Strike Ridge Line. Rows below keep 1.0.0 when that is the product release, including work that already ships in 0.2.0.

| Feature | Status | Release | Notes |
|---------|--------|---------|-------|
| Spec system / screen catalog | **shipped (docs)** | — | Phase 1 + iOS 26 |
| Owner decisions locked | **shipped (docs)** | — | [product-readiness](product-readiness.md). Side A/B, system appearance, physical dice |
| Domain models + engines | **shipped (code)** | 1.0.0 | `Domain/`. `MatchEvent` has turn, phase, message, date. No `kind` |
| Bundled content JSON | **shipped (resources)** | 1.0.0 | `Resources/Content/**`. Rules topics have optional `summary` and `group` |
| Match session + hotseat | **shipped (code)** | 1.0.0 | `MatchReducer`, `BattleCoach`, SwiftData sessions |
| SwiftData SchemaV1 | **shipped (code)** | 1.0.0 | `Persistence/SchemaV1/` |
| App shell | **shipped (code)** | 0.2.0 | Four tabs, sidebar-adaptable, battle `fullScreenCover`. Version 0.2.0 (1) |
| Play home | **shipped (code)** | 1.0.0 | Compact in-progress row and the mission path: nodes, Up next card, mission sheet with objectives, skip ahead and replay. How to play is a push |
| Onboarding | **code** | 1.x | First-run flow: welcome, which BattleTech (Alpha Strike or Classic), what you have, first mission. Replaced Getting Started. See OnboardingSpec |
| Ridge Line guided mission | **shipped (code)** | 1.0.0 | Table setup through victory |
| Battle table + phase dock | **shipped (code)** | 1.0.0 | Header, read-only phase track, coach dock. Initiative is inline |
| SATOR (physical 2D6 primary) | **shipped (code)** | 1.0.0 | Sheet title “Solve a shot”. Crit opens after the sheet dismisses |
| Force roster + pips | **shipped (code)** | 1.0.0 | Display of the Ridge Line (or in-match) units, plus a PV bar. No editor |
| Unit Focus | **shipped (code)** | 1.0.0 | Sheet from a unit card |
| Rules reference (AS) | **shipped (code)** | 1.0.0 | Grouped list and topic detail |
| Settings + legal | **shipped (code)** | 1.0.0 | Dice default, haptics, keep screen awake, theme, delete at the bottom. No skill default. No tip jar |
| Classic coming soon | **shipped (code)** | 1.0.0 | Sheet `classic.modeHome`. Not playable |
| Free Battle | planned | **1.1** | Gated in 1.0 Release |
| Full Lances | planned | 1.x | Gated |
| Physical / OV / withdrawal | partial | 1.x | Overheat picker in Running Hot; Punch or kick in Close Quarters. Forced Withdrawal not built |
| Classic tools / guided | planned | post-1.0 | After the coming-soon sheet |
| MUL network fetch | stub | dogfood | No paste UI in this build |
| Match history | planned | 1.x | |
| Weight-class glyphs | planned | 1.x | No `WeightGlyph` in 0.2.0 |
| App icon image | planned | — | No product icon in the asset catalog in 0.2.0 |
| Tip jar | **out** | — | |
| Telemetry | planned | Phase 14 | Off |
| Localization (non-en) | planned | v1.x | Strings are in code and JSON. No string catalog |

**Legend:** shipped = in the 0.2.0 app or in locked docs; gated = launch arg; stub = boundary; planned = not built; out = will not ship.
