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
| BattleFlowView / battle stage | Any game, turn 1 | ✅ | 2026-11-27: built (1.7). Sides in columns on the left, step and dock in a 300 pt column on the right (iPad: 380 pt, regular width). Set-up and placing minis keep the full-width column. Large text falls back to one column. `battle-mission-initiative.png`, `battle-portrait-initiative.png` (portrait unchanged). iPad not run on a simulator; covered by unit tests only |
| Side headers, pinned side (PM5) | 3–4 side game | ✅ | 2026-11-27: 4 sides make a 2 x 2 grid, acting side first; headers keep `as.battle.side.*` ids. `battle-four-combat.png` |
| Dense unit rows, 4 sides (PM7) | 1v1v1v1 preset | ⚠️ | 2026-11-27: rows use the new half-width `isNarrow` card (name and Shoot on line 1, pips on line 2, status line only when not idle). 8 ’Mechs need a short scroll (~1.5 rows of the grid off screen at default size). `battle-four-initiative.png` |
| InitiativeStep | Turn start, 2 sides | ✅ | 2026-11-27: dice cards scroll in the right column; dock wraps Undo above the primary when narrow. `battle-mission-initiative.png` |
| MultiSideInitiativeStep (PM7) | Turn start, 3–4 sides | ✅ | 2026-11-27: Roll all sides and the dock are reachable with all four sides visible. `battle-four-initiative.png` |
| MovementStep, incl. dense list (PM11 follow-up) | Movement phase, 4 sides | ⚠️ | 2026-11-27: roster stands in for the table list; mover card name and stats stack in the narrow column, move tiles are a short scroll below the fold. `battle-mission-movement.png`, `battle-four-movement.png` |
| CombatStep / shot picker | Combat phase | ✅ | 2026-11-27: Shoot sits inside each row in the table; "All sides shoot" with 4 sides checked. `battle-mission-combat.png`, `battle-four-combat.png` |
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
| PlayModeHomeView / PlayHomeView | Play tab | ✅ | 2026-11-27: fixed. In landscape the hero is one compact row (icon, text, New game), so Saved forces and Boards show. Portrait unchanged. `play-home.png` |
| PlaySidesStep, team presets (PM6/7) | Setup → Sides | ✅ | 2026-11-27: fixed. Landscape uses a 2-column preset grid (one column at accessibility sizes) in a wider 820 pt column; two rows show above Continue, the rest scroll. Portrait unchanged. `setup-sides.png` |
| PlaySizeStep | Setup → Size | ✅ | 2026-11-27: fits; the presets are just above the Continue bar. `setup-size.png` |
| PlayForcesStep | Setup → Forces | ✅ | 2026-11-27: fixed. The setup scroll view has a bottom content margin, so Add ’Mech and Load a saved force clear the Continue bar when scrolled to the end (at the top the button is simply the next thing to scroll to). `setup-forces.png` |
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
| PlayBoardsView (boards list) | Play home → Boards | ✅ | 2026-11-27: fixed. Size now reads "36″ × 22″" (one unit; feet only when both sides are whole feet, like the mat presets). `boards-list.png` |
| BoardEditorView: canvas, palette | Build a board | ⬜ | PM12 has a landscape right column; verify it |
| BoardInspectorView | Select a piece | ⬜ | |
| BoardPieceListView (list editor) | Editor → list | ⬜ | |
| BoardSaveSheet | Save board | ⬜ | Keyboard |
| Starter board preview | Boards → a starter | ✅ | 2026-11-27: fixed. Landscape puts the board (aspect fit to width and height) beside the note and Duplicate to edit; portrait unchanged. `board-starter-preview.png` |
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
