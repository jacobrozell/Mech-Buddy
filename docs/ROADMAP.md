# Mech Buddy roadmap

The single starting point for future work. Each item links to the doc that holds its details. Last updated 2026-11-24, after TestFlight 1.0.0 (3).

## Now: before and after the table test

- [ ] Upload **1.0.0 (3)** from Xcode's Organizer (`build/archives/MechBuddy-1.0.0-3.xcarchive`), then play it at the table. Steps: [release/todo.md](release/todo.md#uploading-a-build).
- [ ] Merge the `release/1.0.0-build-3` branch (the build-number bump, the mission guide and these docs). Delete the merged `feature/guided-mission-ladder` branch.
- [ ] Note table issues in `ongoing/play-<date>/NOTES.md`, as in earlier playtests.
- [ ] Alpha Strike polish checklist (on-screen checks and small layout fixes): [release/todo.md § Next session](release/todo.md#next-session-alpha-strike-polish-owners-focus-2026-11-24).

## App Store (owner)

- [ ] Publish `docs/` on GitHub Pages (privacy, support, accessibility).
- [ ] App Store Connect: age rating, and the "Data Not Collected" privacy label.

## Alpha Strike

| Item | State | Details |
|---|---|---|
| Training path, Missions 1–5 | Built | Player's guide: [missions/alpha-strike-missions.md](missions/alpha-strike-missions.md) |
| Meet and Greet (box scenario) | Built | [game-modes/book-scenarios.md](game-modes/book-scenarios.md) |
| Clash of Steel (box scenario) | Scoped | Needs Battlefield Support, formations (Lucky rerolls, Combat Intuition, Command Lance reroll) and buildings. Rules: [alpha-strike/clash-of-steel-rules-intake.md](game-modes/alpha-strike/clash-of-steel-rules-intake.md). Cards: [book-scenarios.md](game-modes/book-scenarios.md) |
| Open play with objectives | Planned | 250 PV forces and six objectives (Raid, Hold the Fort and so on): [book-scenarios.md § Open play](game-modes/book-scenarios.md), [PRODUCT_SCOPE.md](game-modes/PRODUCT_SCOPE.md#long-term-roadmap-owner-2026-11-24) |
| Rules still open | Open | "0*" minimal damage, water, and four printing conflicts marked [OPEN] in the Clash of Steel intake |
| Mission map suggestions | Planned | Each mission suggests a map from the collection; experienced players can pick any (scope O3) |

**How to add a mission:**
1. Add its JSON pack in `Resources/Content/AlphaStrike/`.
2. Add a catalog entry in `as-scenarios.json`. Use `stage` for sections after the training path.
3. Add its cards to `MissionLadderTests.checkedCards`, checked on the Master Unit List.
4. Run `python3 scripts/generate_mission_guide.py`.

## Classic BattleTech

| Item | State | Details |
|---|---|---|
| 10-mission path | Scoped | [classic/mission-path-scope.md](game-modes/classic/mission-path-scope.md) |
| Rules checked against the box rulebook | Done | [classic/rules-check-2026-11-24.md](game-modes/classic/rules-check-2026-11-24.md) |
| Record sheets (15) and engine (to-hit, hit locations, damage) | Started | `Resources/Content/Classic/`, `Domain/Engines/ClassicTW/` (scope § 4, milestones C0–C1) |
| Next: Mission 1 | To do | Movement and facing tracking, the Classic turn loop, the first screens |
| Book scenarios: Trial by Fire, Divide and Conquer, campaign link | Planned | [book-scenarios.md](game-modes/book-scenarios.md) |
| Stand-ins and maps for Classic missions | Planned | Scope O3 and O5 |

## Content to finish

- **Mercenaries box:** contents unconfirmed, so it ships with no unit list (`as-box-sets.json`).
- **Map catalog:** about 20 Sarna entries were left out until their names are checked; see `sourceNote` in `Resources/Content/map-catalog.json`.
- **Alpha Strike box map names:** not listed on Sarna.

## Reference

- Product scope and long-term roadmap: [game-modes/PRODUCT_SCOPE.md](game-modes/PRODUCT_SCOPE.md)
- Alpha Strike rules audits: [game-modes/alpha-strike/](game-modes/alpha-strike/)
- Specs: `specs/` (GuidedMissionSpec, RosterSpec, RulesReferenceSpec, OnboardingSpec, AccessibilitySpec, TestPlanSpec)
- Rulebooks and record sheets: the owner's copies in `ongoing/` (git-ignored, never committed)
