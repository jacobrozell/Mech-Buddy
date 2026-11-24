# Guided Mission Spec — Alpha Strike

## User story

As a first-night player, I load Ridge Line forces, set the table from a short list, then get phase-by-phase coaching until a winner is decided.

## Scenarios: `as.scenarios`

| # | Scenario ID | Title | Forces | Est. time | Adds | Release |
|---|-------------|-------|--------|-----------|------|---------|
| 1 | `ridge-line` | Ridge Line | 2v2 | ~40 min | Move, shoot, woods, damage, crits | **1.0** |
| 2 | `broken-ground` | Broken Ground | 2v2 | ~50 min | Hills, partial cover, rear shots, jumping for position. 8 turns | 1.1 (`missionLadder`) |
| 3 | `running-hot` | Running Hot | 2v2 | ~50 min | Overheat, heat scale, shutdown. Catapult and Thunderbolt join. 8 turns | 1.2 (`missionLadder`) |
| 4 | `close-quarters` | Close Quarters | 3v3 | — | Physical attacks; Awesome + BattleMaster join | gated |
| 5 | `full-lances` | Full Lances | 4v4 | ~90 min | All eight box ’Mechs, every rule, Forced Withdrawal | gated |

### Mission ladder

Each mission adds a few rules over the one before, ending in a full Alpha Strike match. (Classic BattleTech is a separate game with its own future track; see `ClassicModeSpec`.)

**Play: mission path.** Play shows the ladder as a path (`MissionPathView`), not a list:

- **Header** (`as.modeHome.ladder.progress`): "Mission path", "N of M cleared", one segment per mission. Title and count stack at accessibility text sizes. While any mission is **Ready** (playable, not up next), a line under the header reads "Know the basics? Tap any mission to jump ahead." (`as.modeHome.ladder.skipAheadHint`).
- **Nodes** (`as.modeHome.ladder.<id>`): raised round buttons that snake down the screen. Cleared = signal colour + check badge. Up next = larger, pulsing ring, bobbing START tag. Ready = ringed, icon in signal colour. Coming soon = grey lock. The icon is the catalog's `icon` (SF Symbol). Cleared labels read "Cleared · Replay" with a replay glyph.
- **Info button** (`as.modeHome.ladder.info.<id>`): a `list.bullet.clipboard` button (44 pt) beside every node's label, whatever its state. VoiceOver: "What you’ll learn in <title>". Opens the mission sheet, same as tapping the node. At accessibility sizes it sits under the label.
- **Line:** runs from under each label to the next node (never through text). Solid signal colour after a cleared mission, dotted otherwise. Straight, not zig-zag, at accessibility text sizes. Reduce Motion stops the pulse and bob.
- **Up next card** (`as.modeHome.upNext`): hangs under the current node. Mission number, title, size/time/turns, **Unlocks** chips (the catalog's `introduces`), forces, the **Your minis** line, and the play button (`as.modeHome.ridgeLine` for Ridge Line, else `as.modeHome.mission.<id>`). Mission 1 adds a How to play link (`as.modeHome.howToPlay`).
- **Mission sheet** (`as.modeHome.missionSheet`): from a node or its info button. Sections, in order: **Objective** (the pack's `winningSummary`, plus "Turn limit: N turns"; `as.modeHome.missionSheet.objective`), **You’ll learn** (catalog `introduces` chips), **Tips** (the pack's `coachNotes`; `as.modeHome.missionSheet.tips`), **Forces** (stacked at accessibility sizes), **Your minis**, then the button. Button title by state: Up next "Play <title>", Ready "Skip ahead to <title>", Cleared "Play again", or "Start new <title>" while a game is in progress. Coming-soon missions show `introduces` and `comingSoonSummary` and no button.
- **Your minis** (`as.modeHome.minis`): under the forces on the Up next card and the mission sheet (the sheet adds a “Your minis” heading). Shown only once the player has recorded a collection (`AppPreferences.collection` not `nil`; see [RosterSpec](RosterSpec.md#your-collection)). Both sides' units are matched by chassis (`CollectionMath.miniCheck`). All owned: “You have all 4 ’Mechs” with a check. Some missing: “Missing: Catapult. Use any mini or a coin as a stand-in.” (“Catapult and Thunderbolt”, “A, B, and C”; a chassis short twice reads “Locust ×2”). VoiceOver reads “Your minis. …”.
- **Finish:** a "Trained pilot" trophy after the last mission, lit when every mission is cleared.
- A game in progress shows as a compact row above the path (`as.modeHome.resume`), and play buttons become "Start new …".

"Up next" is the first playable mission the player hasn't cleared (`AppPreferences.completedMissions`, set when the Victory screen appears). Every playable mission can be started; the path doesn't lock later ones. `completedMissions` only grows (`markMissionCompleted` inserts), so replaying a cleared mission never resets path progress.

**Victory:** a **Mission N cleared** card (`as.victory.missionCleared`) shows path progress and what the next mission unlocks. When the next mission is playable, **Next: <title>** (`as.victory.nextMission`) is the primary button and Play again becomes secondary.

**Briefing roster:** each 'Mech has a **Mark mini** menu (`MiniMarkerMenu`) to tag its miniature's colour (`MatchUnitState.mini`). The colour dot then shows on unit cards, the mover card and the shot picker, so proxies and unpainted minis don't get mixed up (playtest note 24). When every 'Mech shares a skill, the briefing says "Every 'Mech uses Skill 4. Write it on the card's blank Skill line." (`as.mission.skill`).

Missions after Ridge Line also show a **New in this mission** card (`as.mission.newRules`) on the briefing with their coach notes. Ridge Line's briefing is unchanged.

**Card rule:** a mission may only use card numbers checked against the Master Unit List: Ridge Line’s four, plus Catapult CPLT-C1, Thunderbolt TDR-5S, Awesome AWS-8Q and BattleMaster BLR-1G (checked 2026-11-24, see `docs/game-modes/alpha-strike/mission-ladder-rules-intake.md`). `MissionLadderTests.cardsAreChecked` enforces it.

**Rules source:** Alpha Strike Box Set Quick-Start Rulebook (3rd printing). Answers and page numbers are in the rules intake doc.

**Unblocking 4–5:** Close Quarters needs a physical-attack action (Standard only: within 1″, Size damage, no weapon attack that turn). Full Lances also needs Forced Withdrawal. Open question P5 (rear +1 on physical attacks) must be settled first.

### Heat (Running Hot and later)

`AlphaStrikeHeat` follows the rulebook:

| Rule | App |
|------|-----|
| Overheat | Shot sheet **Overheat** picker (`as.sator.overheat`), only when `ruleset.overheatAllowed` and the card has OV. 0…OV, Short/Medium only (Long with OVL). Declared before the roll; heat comes hit or miss |
| Heat gain | End Phase: + overheat used, +1 if it fired with an engine hit. Max 4 |
| Cooling | End Phase: no weapon attack this turn → heat 0. Began the End Phase shut down → heat 0, restarts. Water (−1) not tracked |
| Effects next turn | +heat to its weapon attacks; −2″ ground move per level; −1 TMM at heat 2+ (not when it jumped) |
| Shutdown (heat 4, card **S**) | No move, no shot; immobile target (−4). Chip “Shut down · heat” |
| Cards | HEAT cell on unit cards for ’Mechs with OV or heat |

Heat applies in every mission because engine hits make heat; only the Overheat picker is gated by the mission.

### Broken Ground defaults

| Side | Units |
|------|-------|
| Lance A | Shadow Hawk SHD-2H, Locust LCT-1V (PV 48) |
| Lance B | Wolverine WVR-6M, Commando COM-2D (PV 49) |

One jumper per side. Victory: same rule as Ridge Line with an 8-turn cap. OV / physical / withdrawal stay off. Hills cost no extra movement in this mission (house simplification); they matter for line of sight and partial cover.

### Running Hot defaults

| Side | Units |
|------|-------|
| Lance A | Catapult CPLT-C1, Locust LCT-1V (PV 50) |
| Lance B | Thunderbolt TDR-5S, Commando COM-2D (PV 53) |

One OV 1 heavy per side. `overheatAllowed: true`; physical / withdrawal stay off. Victory: same as Broken Ground, 8-turn cap.

### Ridge Line defaults

| Side | Units |
|------|-------|
| Lance A | Shadow Hawk SHD-2H, Commando COM-2D |
| Lance B | Wolverine WVR-6M, Locust LCT-1V |

Skill 4 all. Bundled AS stats (user-editable).

**Victory (locked):** Destroy both enemy ’Mechs. If both sides still have living ’Mechs after turn **6**, higher remaining **structure** wins (tie → draw UI).  

**ScenarioRuleset:** `overheatAllowed`, `physicalAttacksAllowed`, `forcedWithdrawal` = **false**. (Catalog copy must not say “cripple” for Ridge Line — that wording is Full Lances / later.)

### Full Lances (planned)

Forces and VP rules per walkthrough. Awesome vs BattleMaster card conflict → prompt to track one on Force roster.

## Setup screen: `as.mission.ridgeLine.setup`

### Step 1 — Forces

- **Load Ridge Line forces** → writes four units into match roster (and optionally Force tab)
- Editable quick grid (PV, MV, TMM, SZ, S/M/L, OV, A, S, skill)
- Optional: MUL paste import sheet (live network fetch **gated**)

### Step 2 — Table

Read-only checklist:

- Maps grassland side; ~36"×22" or equivalent
- Measure in inches (hexes decorative)
- Woods only terrain (+1" move, +1 to hit in/behind)
- Ignore elevation, water, buildings
- Deploy within 6" of own short edge; initiative loser places first

Mark step complete manually (“Table ready”).

### Step 3 — Play

Primary CTA **Start battle** → `as.battle` with mission coach enabled.

## Acceptance criteria (Ridge Line)

| # | Given / When / Then |
|---|---------------------|
| 1 | Given fresh install, When Load Ridge Line forces, Then four units appear with bundled fixtures + skill 4 |
| 2 | Given forces loaded but table not ready, When Start battle, Then CTA disabled or alert |
| 3 | Given table ready, When Start battle, Then battle cover opens turn 1 initiative |
| 4 | Given both enemies structure 0 and End resolved, When victory check, Then winner is the surviving side |
| 5 | Given turn 6 End and both sides have living ’Mechs, When victory check, Then higher remaining structure wins (equal → draw) |
| 6 | Given active battle, When kill app and relaunch Resume, Then turn/phase/pips/`activeSide` restore |

Rematch → new session id; no Force library write-back.

**DoD:** [phase-6-vertical-slice.md](../../docs/development/phase-6-vertical-slice.md)

## Victory: `as.victory`

- Show winner or draw, turns played, remaining structure totals  
- Actions: **Rematch**, **Done** (history gated off in 1.0)  
- Rematch = new `MatchSession` with fresh Ridge Line armor/structure  

## Mission coach (during battle)

Phase prompts (examples):

| Phase | Prompt intent |
|-------|----------------|
| Initiative | Both roll 2D6; winner acts **last** |
| Movement | Loser moves first; alternate; set movement mode tokens |
| Combat | Loser resolves **all** attacks, then winner; destroyed still shoot until End |
| End | Apply destruction; heat if enabled; check victory |

## Persistence

- `MatchSession` keyed by mode (+ scenario id) — see [MatchSessionSpec](MatchSessionSpec.md)
- Survive app relaunch; resume from Play home
- Battle mutates session **snapshots**, not Force library alone

## Accessibility

- `as.mission.setup`, `as.mission.loadForces`, `as.mission.startBattle`, `as.victory.screen`

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 (Ridge Line) |
| Last verified | 2026-08-21 |
| Commit | — |
| Code paths | *not implemented* |
