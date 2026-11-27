# Landscape checklist

An ongoing list of every screen to screenshot and check in landscape. Tick a row when it has been checked on screen, and add the date and any issue found. New screens get a row when they land.

**How to check:**
- Device: iPhone 17 rotated left. iPad when the screen has an iPad layout.
- Launch with `-enable_full_product_surface` so the play-mode, multi-side, objectives and boards switches are on.
- Check at default text size, then at the largest accessibility size. Do a dark-mode spot check.
- Save screenshots to `docs/screenshots/landscape/<screen>.png`.

**Pass means:**
- nothing is clipped or truncated
- the primary action is reachable without hunting
- no wasted half-screen; side-by-side where the spec says so (`ux.landscapeSplit`, IOS26PlatformSpec)
- the keyboard doesn't cover the field being typed in
- the safe area and Dynamic Island are respected

Status: ✅ checked and fine · ⚠️ checked, issue noted · ⬜ not checked

## Battle (the table view, FUTURE-PLAN 1.7)

| Screen | How to reach | Status | Notes |
|---|---|---|---|
| BattleFlowView / battle stage | Any game, turn 1 | ⬜ | 1.7 wants Side A \| Side B in two columns with the dock on the right |
| Side headers, pinned side (PM5) | 3–4 side game | ⬜ | |
| Dense unit rows, 4 sides (PM7) | 1v1v1v1 preset | ⬜ | |
| InitiativeStep | Turn start, 2 sides | ⬜ | |
| MultiSideInitiativeStep (PM7) | Turn start, 3–4 sides | ⬜ | |
| MovementStep, incl. dense list (PM11 follow-up) | Movement phase, 4 sides | ⬜ | |
| CombatStep / shot picker | Combat phase | ✅ | Rear weapons checked earlier; re-check "All sides shoot" with 3–4 sides |
| CombatSolverSheet | Resolve a shot | ⬜ | |
| DamagePreviewCard | Shot result | ⬜ | |
| CriticalPendingStep / CritSheet | A crit | ⬜ | Check that the attacker side name fits |
| CleanUpStep | End phase | ⬜ | |
| ObjectiveStrip (PM8) | Game with an objective | ⬜ | Under the step bar |
| ObjectiveScoreCard (PM8) | Clean up with an objective | ⬜ | |
| UnitFocusSheet | Tap a unit | ⬜ | |
| EventLogSheet | Toolbar | ⬜ | |
| BoardSheet (PM12) | Battle toolbar → Board | ⬜ | |
| UseSupportView / BattlefieldSupportView / BuildingRulesView (PM11) | Game with support or buildings | ⬜ | |
| Mission 5 withdrawal; Close Quarters punch | Missions 4–5 | ✅ | |
| VictoryView | End a game | ✅ | Checked 2026-11-26; re-check the points tally and tie text from PM8 |

## Play setup

| Screen | How to reach | Status | Notes |
|---|---|---|---|
| PlayModeHomeView / PlayHomeView | Play tab | ⬜ | Rows for Saved forces, Boards and Last setup |
| PlaySidesStep, team presets (PM6/7) | Setup → Sides | ⬜ | |
| PlaySizeStep | Setup → Size | ⬜ | |
| PlayForcesStep | Setup → Forces | ⬜ | Save/Load force buttons |
| PlayUnitPickerSheet | Add a unit | ⬜ | Search field and keyboard |
| PlayCardEntrySheet (PM9) | Add your own card | ⬜ | Keyboard covers the lower fields? |
| PlaySavedForcesSheet (PM9) | Load a saved force | ⬜ | |
| PlayMapStep, board section (PM12/13) | Setup → Battlefield | ⬜ | Includes the stretch prompt |
| PlayRulesStep, objectives and per-side rolls (PM8/11) | Setup → Rules | ⬜ | |
| PlayHouseRulesSheet | Rules → House rules | ⬜ | |
| PlayReviewStep | Setup → Review | ⬜ | |
| TableSetupStep / PlaceMiniaturesStep | Start a game | ⬜ | Board briefing |
| MechWarrior cards (PM11) | Where the PM11 leftovers put them | ⬜ | |

## Boards (PM12/13)

| Screen | How to reach | Status | Notes |
|---|---|---|---|
| PlayBoardsView (boards list) | Play home → Boards | ⬜ | |
| BoardEditorView: canvas, palette | Build a board | ⬜ | PM12 has a landscape right column; verify it |
| BoardInspectorView | Select a piece | ⬜ | |
| BoardPieceListView (list editor) | Editor → list | ⬜ | |
| BoardSaveSheet | Save board | ⬜ | Keyboard |
| Import refusal messages | Import a bad `.mechboard` | ⬜ | |

## Learn, rules, lore, force, onboarding, settings

| Screen | How to reach | Status | Notes |
|---|---|---|---|
| Onboarding steps (Welcome, Track, Boxes, Kit, Mechs, First mission) | Fresh install | ⬜ | Spec: tiles go two-up in landscape |
| RulesHomeView / RulesTopicDetailView | Rules tab | ⬜ | |
| BoxRulesSheet | Rules → box | ⬜ | |
| LoreOverviewView / LoreTimelineView / LoreEraDetailView | Rules → History | ⬜ | |
| HowToPlayRidgeLineView, MissionDetailSheet | Learn → mission | ⬜ | |
| ForceListView, collection cards and sheets | Force tab | ⬜ | Saved forces row (PM11 follow-up) |
| SettingsHomeView | Settings | ⬜ | |
| ClassicComingSoonSheet | Pick Classic | ⬜ | |
