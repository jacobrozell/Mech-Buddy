# Play Mode Spec — Alpha Strike

**Status:** accepted, 2026-11-26. **PM1 (N-side Domain) built** on `feature/pm1-n-sides`, 2026-11-26: domain and payload only, no screen changes. **PM2 (card library)** built. **PM3 (Learn | Play shell) and PM4 (1 v 1 pickup game)** built on `feature/play-pm3-pm4`, 2026-11-26, behind `playMode`; see the PM4 notes under Verification for what is deferred. PM5–PM9 and PM11–PM13 are built (see docs/STATUS.md); PM10 (release) is not. The owner asked for this mode to be fully specced before any work starts, and accepted every recommended default in § 18.

Companions: [ModeHomeSpec](ModeHomeSpec.md) · [AppShellSpec](../AppShellSpec.md) · [MatchSessionSpec](MatchSessionSpec.md) · [HotseatSpec](HotseatSpec.md) · [BattleTableSpec](BattleTableSpec.md) · [RosterSpec](RosterSpec.md) · [GuidedMissionSpec](GuidedMissionSpec.md) · [ReleaseSurfaceSpec](../ReleaseSurfaceSpec.md) · [DataSchemaSpec](../DataSchemaSpec.md) · [ContentPackSpec](../ContentPackSpec.md) · [AccessibilitySpec](../AccessibilitySpec.md).

**Rules source:** *Alpha Strike Box Set Quick-Start Rulebook*, 3rd printing (QSR). Page numbers are **printed** page numbers (the PDF index is printed + 1), as in the rules intake docs. Alpha Strike rules only. Nothing here comes from Classic BattleTech.

**House rules** are marked **[HOUSE]**. They fill gaps the QSR leaves. Each one is also an owner decision (§ 18).

---

## 1. Purpose

The owner's order (2026-11-26): finish Alpha Strike fully before Classic.

Today the app teaches. Play mode lets people who know the game play a whole Alpha Strike battle of their own design: they pick the players, the sides, the 'Mechs and the map. The app does the bookkeeping it already does for missions: initiative, move order, shot math, damage, crits, heat, the End Phase and the winner.

The top level of the app splits into two modes:

| Mode | What it is | Content |
|---|---|---|
| **Learn** | Today's guided path | Training Missions 1–5, box scenarios (Meet and Greet, later Clash of Steel), How to play |
| **Play** | A full game you set up | 2–4 sides, up to 4 players, your forces, your map, an optional objective |

### User stories

- As two friends with the Alpha Strike box, we build 250 PV forces from our minis, pick a mat, and play a pickup game to the last 'Mech.
- As four players, we play every-man-for-himself (1v1v1v1) on a 4′ × 4′ table, and the app tells us who moves next.
- As four players, we play 2v2, each pair sharing a side.
- As a parent and two kids, we play 1v2: the kids share a side against me.
- As a player with a favourite table, I build it once in the board builder by dragging woods, hills and buildings onto it, save it, and pick it next time.
- As a returning player, I resume last night's game at Turn 4, Combat.

### Non-goals (for this spec)

- Networked or multi-device play. One phone or iPad, passed around ([HotseatSpec](HotseatSpec.md), owner lock 2026-08-21).
- Classic BattleTech. Its open play is a separate roadmap item ([PRODUCT_SCOPE](../../docs/game-modes/PRODUCT_SCOPE.md)).
- Rules beyond the QSR: no *Alpha Strike: Commander's Edition* rules, no vehicles, infantry or aerospace units.
- Buildings, Battlefield Support, Formations and MechWarrior cards in the first release. They are built for Clash of Steel first ([FUTURE-PLAN § 4](../../docs/FUTURE-PLAN.md)); Play turns them on later (§ 16, PM11).
- Measuring the table. The app never knows where a mini is. Players measure; the app asks and records.
- Bulk Master Unit List data. Owner lock 2026-11-01: look up cards, don't ship the catalog. The card library (§ 10) holds only cards for minis the owner's boxes contain, checked by hand.
- Campaigns, damage carried between games, match history (gated `matchHistory`).
- AI opponents.

---

## 2. Rules basis: what the QSR says about more than two

| Topic | What the QSR says | Page |
|---|---|---|
| Players and sides | The rules "presume" every game has **two sides**, each played by one player or by a **team** of players. "Player" in the rules can mean a team | p. 13 |
| Initiative | Each player rolls 2D6, re-roll ties, higher wins. The winner acts after "the player(s) with the lower Initiative roll" | p. 13 |
| Movement | Lowest roll moves one 'Mech first, then the sides alternate | p. 13 |
| Unequal numbers | A side with twice as many 'Mechs left to move moves two at a time, three times as many moves three, and so on. Worked example 8 vs 5 | p. 14 |
| Combat | Lowest roll declares and resolves all its attacks, then the winner. Damage is marked now; effects apply in the End Phase | p. 13 |
| End Phase | Both players at once: remove destroyed 'Mechs, heat, check victory | p. 13 |
| Victory | A pickup game ends when all of one player's 'Mechs are destroyed. Otherwise the scenario decides. Checked in the End Phase | p. 13 |
| Setup order | Objectives, forces, initiative and terrain, starting positions | p. 7 |
| Objectives | Pick or roll one of six; both players use the same one by default. Optionally each player rolls their own | p. 7 |
| Forces | 250 PV each. Card PV assumes Skill 4 | p. 7 |
| Force size options | By number of 'Mechs (with a Size cap) or by PV. Players agree first | p. 33 |
| Skills | Players agree min and max Skill. Better Skill costs PV: Improved Skill PV Increase Table. Inner Sphere default Skill 4, Clan default Skill 3, and the Clan PV increase must still be paid | pp. 34–35 |
| Table | 3′ × 4′ to 4′ × 4′ for box-sized games, up to 4′ × 6′. Players deploy along the long side, 4′ apart | p. 7 |
| Home edge | The long table edge on your side | p. 8 |
| Terrain | Setup initiative roll; each player picks 8 pieces; winner places first, then alternate; 4 in the far band, 2 in the near band, 2 in the centre band | p. 8 |
| Starting positions | By default 'Mechs enter on Turn 1 from off the table. If players agree, they start on the table within 6″ of their home edge; the setup roll winner chooses to place first or second, then alternate one 'Mech at a time | p. 11 |
| Optional rules | Battlefield Support, Forced Withdrawal, crippled, Formations, MechWarrior cards, force balance. Agreed by all players before the game | p. 12 |
| Leaving the table | A 'Mech that leaves the play area is destroyed and can't come back | p. 12 |
| Game length | No turn limit. Objective games end at a victory-point total; pickup games end at a wipe | pp. 7, 13 |

**What the QSR does not cover:** three or four sides (free-for-all). It never says how initiative, move order, targets, home edges, deployment or objective scoring work with more than two sides. The "(s)" in "player(s)" on p. 13 is not a rule for it. Play mode fills the gap with the house rules in § 6.

**Teams are covered.** 2v2 and 1v2 are two sides under p. 13. Each side rolls one initiative, has one budget, and moves as one side. Play mode follows this by default (decision D3).

**Page note.** `AlphaStrikePointValue.swift` and `book-scenarios.md` cite p. 33 for the PV table. The force building section starts on p. 33; the table itself is on p. 35. Fix the comments when PM2 touches that file.

---

## 3. Entry: Learn and Play

### Shell change

Today: four tabs, Play · Force · Rules · Settings ([AppShellSpec](../AppShellSpec.md)). Play holds the mission path.

With `playMode` on (§ 16): **five tabs**.

| Tab | SF Symbol | Entry ID | Holds |
|---|---|---|---|
| **Learn** | `graduationcap` | `learn.home` | Everything on today's Play tab: resume row, mission path, box scenarios, How to play, Classic teaser or spotlight |
| **Play** | `flag.checkered` | `as.play.home` | Play mode home (§ 4) |
| Force | `shield.lefthalf.filled` | `force.as.list` | Unchanged; gains **Saved forces** in PM9 |
| Rules | `book` | `rules.home` | Unchanged |
| Settings | `gearshape` | `settings.home` | Unchanged |

Five tabs fit the iPhone tab bar without a More tab. `.sidebarAdaptable` lists them on iPad.

With `playMode` off: no change. The tab is called Play and shows the mission path, as today.

### Why tabs

The owner asked for a top-level choice. Tabs are the top level on iOS. A player can hold a game in Play and still read a mission sheet in Learn. The alternative (a Learn | Play segmented control at the top of one tab) is option B in decision D1.

### What moves

| Today (Play tab) | With Play mode |
|---|---|
| `PlayHomeView` mission path, Up next card, mission sheets | Learn tab, unchanged inside. Root id `learn.home`; keep `play.home` as a sibling id for one release so UI tests still find it |
| "From the Alpha Strike box" (Meet and Greet, later Clash of Steel) | Learn |
| How to play | Learn (push, tab bar stays) |
| Classic teaser / spotlight | Learn |
| "Free battle" row (hidden, 1.1) | Removed. Play mode replaces Free Battle |
| Resume row | Both tabs show the active game. Its label names the mode: "Mission 3 · Running Hot · Turn 2" or "Play · 4 players · Turn 5" |

### Naming

- Tabs: **Learn** and **Play**. Short, verbs, no jargon.
- Inside Play: "New game", not "Free battle" or "Skirmish". "Free Battle" leaves the product; the release flag is renamed (§ 16).
- A game's format reads as the table says it: **1 v 1**, **1 v 2**, **2 v 2**, **1 v 1 v 1**, **1 v 1 v 1 v 1**.

### Landing tab

- New player (onboarding not finished, or no mission cleared): Learn.
- Otherwise: the last tab used. `AppPreferences.lastRootTab`.
- Later (D21): onboarding's track screen adds "I already know Alpha Strike", which lands on Play. Not in this spec's milestones; OnboardingSpec owns it.

### One game at a time

Learn and Play share one active-game slot, as today (MatchSessionSpec, StartMission step 4). Starting a new game while one is active asks first: "You have a game in progress (Mission 2, Turn 3). Start a new one? The old one ends." Decision D15.

---

## 4. Play home: `as.play.home`

Layout (phone, top to bottom):

1. Title **Play**.
2. **Resume** card when the active game is a Play game (`as.play.resume`). Format, side names and colours, turn, phase. Primary button **Continue**.
3. **New game** (`as.play.new`), primary when nothing is in progress.
4. **Last setup** (`as.play.lastSetup`): "1 v 1 · 250 PV · Grassland #2 + Desert #2". Opens Review (§ 5.6) with that setup. Hidden until a game has been started.
5. **Saved forces** (PM9) (`as.play.savedForces`).
6. A one-line note when no collection is recorded: "Tell us which boxes you own to build forces from your minis." with **Add your boxes** (opens the collection sheet, RosterSpec).

Empty state on first visit: hero symbol, "Play a full game of Alpha Strike", one line ("Pick the players, the 'Mechs and the map. The app keeps score."), **New game**.

---

## 5. Setup flow

A pushed flow on the Play tab's `NavigationStack`, six screens. A step strip at the top ("2 of 6 · Forces"). **Back** keeps everything. **Cancel** asks if anything was changed. The draft autosaves (`PlaySetupDraft`, § 12) so leaving the app loses nothing.

| # | Screen | ID |
|---|---|---|
| 1 | Players and sides | `as.play.setup.sides` |
| 2 | Game size | `as.play.setup.size` |
| 3 | Forces | `as.play.setup.forces` |
| 4 | Battlefield | `as.play.setup.map` |
| 5 | Objective and rules | `as.play.setup.rules` |
| 6 | Review | `as.play.setup.review` |

### 5.1 Players and sides

"How many sides?" picks the format. Presets as `ChoiceTile`s:

| Preset | Sides | Players | Rules basis |
|---|---|---|---|
| 1 v 1 | 2 | 2 | QSR |
| 1 v 2 | 2 | 3 | QSR (a team is a player, p. 13) |
| 2 v 2 | 2 | 4 | QSR |
| 1 v 1 v 1 | 3 | 3 | **[HOUSE]** § 6 |
| 1 v 1 v 1 v 1 | 4 | 4 | **[HOUSE]** § 6 |
| More… | 2–4 sides, 1–3 players each, 4 players max | | 1 v 1 v 2, 1 v 3 |

Rules: 2–4 sides. 1–4 players in all. At least one player per side. 1 v 3 is allowed (two sides).

Per side, a row (`as.play.setup.side.<letter>`):

- **Badge**: letter, shape and colour, fixed by slot (§ 14). Not editable, so a side never looks like another.
- **Side name**, optional, max 20 characters. Default "Side A" … "Side D". Placeholder suggests the default.
- **Players**, optional names, one per player on the side (`as.play.setup.side.<letter>.player.<n>`). Used in pass-the-phone lines: "Side C — Sam's turn. Pass the phone."

A free-for-all (3–4 sides) shows a note: "Three or more sides isn't in the Quick-Start rules. Mech Buddy uses house rules for turn order and scoring." with an info button (`as.play.setup.houseRules`) that lists § 6 in plain words.

### 5.2 Game size

| Control | Default | Range | ID |
|---|---|---|---|
| **Budget** per side | 250 (2 sides), 200 (3), 150 (4) **[HOUSE defaults]**, D5 | 50–500 PV, step 5. Presets 150 / 200 / 250 / 300 | `as.play.setup.budget` |
| **Budget by** | Point Value | Point Value, or Number of 'Mechs with a Size cap (p. 33) | `as.play.setup.budgetKind` |
| **Pilot skills** | Card skill (4; Clan 3) | Allow better skills: on/off. Min Skill 2 by default, 0–4 allowed | `as.play.setup.skills` |
| **Which 'Mechs** | "Minis I own" when a collection is recorded, else "Any card" | Minis I own / Any card in the app | `as.play.setup.pool` |

Uneven teams share one budget per side (D6). A 1 v 2 is 250 against 250.

Why the 3- and 4-side defaults are lower: the owner's two boxes hold 21 minis worth about 748 PV at Skill 4 (13 Alpha Strike box cards ≈ 504, A Game of Armored Combat ≈ 244, book faces). Four sides at 250 is 1,000 PV, more than the collection. 150 each is about 3–4 'Mechs per side and a game of about two hours.

A line under the budget estimates time: "About 90 minutes" from the expected unit count (§ 17, R6). It is a guide, not a rule.

Number of 'Mechs mode: per side, a count (1–10) and a Size cap ("Sizes total at most 11", p. 33). PV is still shown but not enforced.

### 5.3 Forces

One page per side, with the side badges as a segmented header (`as.play.setup.forces.side.<letter>`). Each page:

- **Budget bar** (`as.play.setup.forces.budget.<letter>`): "212 of 250 PV". Signal colour under budget, warning colour over. Text says "38 PV left" or "12 PV over"; colour is never the only cue.
- **Units**, one row each (`as.play.setup.forces.unit.<uuid>`):
  - name and variant, Size, card PV;
  - **Skill** stepper (only when better skills are allowed); adjusted PV beside it;
  - **Face** switch when the card has another face ("Locust LCT-7V ⇄ LCT-3M");
  - **Mini** marker (`MiniMarkerMenu`, as in briefings), and a stand-in note when the chassis isn't owned;
  - a badge when the numbers aren't checked (§ 10): "Your numbers";
  - **controller** picker in a team side ("Alex" / "Sam"), so pass lines can name who moves it;
  - swipe to delete.
- **Add 'Mech** (`as.play.setup.forces.add.<letter>`) opens the unit picker.
- **Copy from…** another side (mirror match) and **Clear**.

**Over budget** is allowed. Continue asks: "Side B is 12 PV over budget. Play anyway?" Players agree their own limits (p. 33).

**Unit cap:** 10 per side, 24 in the game **[HOUSE app limit]** (D9). The battle screen and initiative entry stay usable at this size (§ 8).

**PV math** (p. 35, `AlphaStrikePointValue.adjusted`):

- Adjusted PV = card PV + increase × (4 − Skill), for Skill below 4.
- Increase per point: base 0–7 → 1, 8–12 → 2, 13–17 → 3 … 48–52 → 10, then +1 per 5 base PV over 52.
- Skills worse than 4 have no PV rule in the QSR. Not offered (D7).
- Clan cards default to Skill 3, and the increase is paid (p. 35). A Clan 'Mech's row starts at Skill 3 with its adjusted PV.
- Side total = sum of adjusted PV. Shown on every page and on Review.

#### Unit picker: `as.play.setup.unitPicker`

A sheet, large detent, searchable (`as.play.setup.unitPicker.search`).

Sections:

1. **Your minis** (pool = Minis I own): owned chassis from `CollectionMath.ownedUnits`, with "N left" after other sides' picks. Each chassis lists its card faces. Singles typed by hand match by chassis name (`UnitChassis.name`).
2. **All cards in the app**: every face in the card library (§ 10), grouped by box. Shown when pool = Any card, or under a "Show all cards" toggle.
3. **Enter a card by hand** (`as.play.setup.cardEntry`) for a mini with no card in the app.

Filters: Size 1–4, role (when the card has one), Clan / Inner Sphere.

Row: name, Size, Move, PV at the side's default skill, checked or not. Tapping adds it and keeps the sheet open (a toast says "Added Locust LCT-7V to Side B").

A mini on the table can only be one 'Mech. When the same chassis is picked more times than it's owned, the row says "Uses a stand-in" and the Review screen lists stand-ins, as the mission sheet does (`CollectionMath.miniCheck`).

#### Card entry: `as.play.setup.cardEntry`

The same quick grid the mission setup uses: name, PV, Size, MV, TMM, S/M/L (accepting `0*`), OV, Armor, Structure, Skill, specials text, Clan or Inner Sphere. A link **Look it up on the Master Unit List** opens masterunitlist.battletech.com in Safari (a link, not a fetch; owner lock 2026-11-01). Saved as a **user card** (§ 10), reusable in later games, marked "Your numbers".

### 5.4 Battlefield

"What are you playing on?" (`as.play.setup.mapSource`):

| Source | Detail |
|---|---|
| **A saved board** (from PM13) | A board preset (§ 9): yours, or a starter board such as a training mission's table. Sets the table size, mapsheets, terrain and zones in one tap. **Edit board** opens the builder |
| **Build a board** (from PM12) | Opens the terrain board builder (§ 9) with the table chosen below |
| **Mapsheets** | Owned maps first (`CollectionMath.ownedMaps`), then "Any map" with catalog search (`map-catalog.json`, the same 5-suggestion field the collection uses). Pick 1–6 sheets and an arrangement |
| **Mat or table** | Size presets 3′ × 4′, 4′ × 4′, 4′ × 6′, or custom width and depth in inches. The Alpha Strike box has no mapsheets, so this is its default |

Mapsheet arrangements: a standard mapsheet is about 22″ × 17″. 2 sheets long edges together (about 22″ × 34″), 2 × 2 (about 44″ × 34″), 3 × 2 (about 66″ × 34″). The app works out the table size from the arrangement. Measure in inches, as the missions do; hexes are ignored.

Size guidance, shown under the picker (`as.play.setup.mapAdvice`):

- 2 sides: the book's 3′ × 4′ to 4′ × 4′ (p. 7). Over about 300 PV a side, 4′ × 6′.
- 3–4 sides: 4′ × 4′ or bigger, square if possible **[HOUSE]**.
- Under about 34″ deep: "Small table. Forces will meet on Turn 1."

**Layout preview** (`as.play.setup.layout`): `MissionLayoutView` draws the table with each side's home edge and deployment zone in its colour and shape, generated from § 6.4. Without a board, no terrain is drawn; with one, the preview is the board (§ 9). Players can skip the builder and place terrain by the checklist below; the app never requires a board.

**Terrain** checklist (shown here and again at table setup), from p. 8 for two sides:

- Roll 2D6 each for setup; the winner places terrain first.
- Each side picks 8 pieces (woods, hills, water, buildings…), placing in turn.
- Each side places 4 pieces 6″–24″ from the centre line toward the enemy, 2 pieces 6″–24″ toward its own edge, and 2 within 6″ of the centre line.

For 3–4 sides **[HOUSE]**: each side picks 6 pieces; place in setup-roll order, one at a time; none inside a deployment zone; no piece within 4″ of another unless they form one woods area.

Buildings are allowed as terrain for line of sight and movement cost the players work out, but the app tracks no damage for buildings drawn on a board (building rules from PM11 apply only to buildings added in the Rules step). Placing one shows: "Buildings block sight and slow movement. The app doesn't track their damage yet."

### 5.5 Objective and rules

**Objective** (`as.play.setup.objective`):

| Choice | Meaning |
|---|---|
| **None: last side standing** (default) | Pickup game. Win by destroying every enemy 'Mech (p. 13). With Forced Withdrawal on, 'Mechs that leave count as destroyed (p. 12) |
| **Pick one** | Raid, Control the Field, Destroy the Enemy, Hold the Fort, Breakthrough. Find the Target is offered once the table has 3 or more buildings (§ 7.1), otherwise it shows why not |
| **Roll for it** | The app rolls (or you roll 1D6 and enter it): 1 Raid, 2 Control the Field, 3 Destroy the Enemy, 4 Hold the Fort, 5 Breakthrough, 6 Find the Target. A 6 re-rolls until Find the Target is built **[HOUSE mapping]**; the QSR says "randomly determine" with no table (p. 7) |

All sides use the same objective (p. 7 default). "Each side rolls its own" (p. 7 optional, PM11) is a switch (`as.play.setup.objective.perSide`): each side rolls or picks its own objective and wins at its own total **[HOUSE]**. Raid tokens go out for every side if any side plays Raid. Scoring is in § 7.

**Turn limit** (`as.play.setup.turnLimit`): None (default, p. 7/13), 6, 8, 10 or 12 turns **[HOUSE option]**. At the limit the game ends in that End Phase; § 7.3 decides the winner. The hint: "Most 250 PV games take 6–8 turns."

**Rules** (`as.play.setup.rules.<id>`), toggles, defaults per D16:

| Rule | Default | Note |
|---|---|---|
| Overheat | On | `ScenarioRuleset.overheatAllowed` |
| Punch and kick | On | `physicalAttacksAllowed` |
| Forced Withdrawal | On | `forcedWithdrawal` (p. 12) |
| Start on the table | On (D13) | Off = 'Mechs enter from their home edge on Turn 1 (p. 11 default) |
| Buildings, Battlefield Support, Formations | Off | Built (PM11) |
| MechWarrior cards | Off | Built (PM11) **[HOUSE]**: one named pilot per side, set on the Forces step; its skill replaces the 'Mech's (0 to the card skill); the review warns if the sides' cards cost different PV (p. 48) |

**Dice** (`as.play.setup.dice`): Real dice (default, owner lock) or Let the app roll. Same `DiceMode` as missions; it can be changed in game.

### 5.6 Review: `as.play.setup.review`

One screen to check before the game:

- Format and sides: badge, name, players, PV total against budget, unit count.
- Each side's 'Mechs, compact.
- Battlefield and layout preview.
- Objective, turn limit, rules on.
- **Your minis**: the mission sheet's line, for all sides ("Stand-ins: Atlas as Awesome." / "Missing: …").
- Warnings: over budget, unchecked numbers, small table for the force size.

**Start game** (`as.play.setup.start`) creates the session (`MatchCommand.startPlay`) and opens the battle cover at table setup. **Edit** links jump back to each step.

---

## 6. House rules for three or four sides [HOUSE]

These apply only when a game has 3 or 4 sides. With 2 sides (including teams) the app follows the QSR exactly. Each rule is written so that, with 2 sides, it gives the QSR's result.

### 6.1 Initiative order

1. Every side still in the game rolls 2D6.
2. Order the sides from lowest total to highest. Lowest acts first; highest acts last (p. 13 principle).
3. Ties: only the tied sides re-roll, and the re-roll only orders them among themselves. Re-roll until no ties.
4. **Skip the roll** (today's `agreeInitiative`) becomes "Players choose the order": drag the side badges into order.

The highest side is the "initiative winner" for anything that names one (placement choice, setup terrain).

### 6.2 Movement order

Generalises the unequal-numbers rule (p. 14). Before each round:

- Let *r* be each side's 'Mechs left to move. Ignore sides at 0.
- Let *m* be the smallest *r*.
- Each side moves floor(*r* / *m*) 'Mechs this round (at least 1), in initiative order, lowest first.
- When only one side has 'Mechs left, it moves them all.

With 2 sides this is exactly p. 14 and today's `AlphaStrikePhaseEngine.movementSequence` (8 vs 5 gives 1-1, 1-1, 1-2, 1-2, 1-2). PM1 proves that with a test over every count from 0 to 10 per side.

Example, 1 v 1 v 1 with 4, 2 and 2 left (order C, A, B): round 1 — C moves 2, A 1, B 1. Round 2 — 2, 1, 1 left: C 2, A 1, B 1. Done.

### 6.3 Combat

- Combat stays **simultaneous** (owner decision 2026-11-24, HotseatSpec). Any side may shoot in any order; one **Done shooting** ends the phase. The QSR's loser-first order can't change the result because effects wait for the End Phase.
- **Targets:** any 'Mech on another side. In a team game, never a teammate's 'Mech (they share a side).
- A 'Mech on a side that is out (§ 6.5) is off the table and can't be targeted.

### 6.4 Home edges and deployment zones

| Sides | Home edges | Deployment zone |
|---|---|---|
| 2 | The two long edges (p. 8) | Within 6″ of the home edge, full width (p. 11) |
| 3 | Three edges of the table. The setup-roll order picks: highest first | Within 6″ of the home edge, the middle 3⁄8 of that edge (18″ on a 48″ edge) |
| 4 | One edge each, picked in setup-roll order, highest first | Same as 3 |

The narrower zones keep neighbouring zones apart: on 4′ × 4′, neighbours' nearest corners are about 12.7″ apart and opposite zones 36″.

With 3 sides, the side between the other two has two near neighbours. Picking edges in setup-roll order is the balance. The layout preview names the "middle edge" so players see it.

"Opponent's home edge" in an objective means **any enemy side's home edge** with 3–4 sides.

### 6.5 Elimination and conceding

- A side is **out** at the End Phase when it has no 'Mechs left on the table (destroyed, or withdrawn under Forced Withdrawal). Log: "Side C is out." The side drops from initiative, move order, the header and pass lines. Its standing is kept for the result.
- **Concede** (More menu, `as.battle.concede`), confirmed: the side's 'Mechs are removed at once and the side is out. In Destroy the Enemy, conceded 'Mechs score for nobody **[HOUSE]** (D19).
- Two sides: when one side is out, the other wins (p. 13).

### 6.6 Scoring attribution (Destroy the Enemy)

With 3–4 sides someone has to get the points. The side whose attack made the 'Mech destroyed or crippled scores its Size **[HOUSE]** (D11):

- the attack whose damage took Structure to 0 or crossed the crippled line;
- for a critical hit that destroys or immobilises, the attacker who caused the crit roll;
- a 'Mech scores once, when it is first crippled or destroyed;
- a 'Mech that shuts down from its own heat, or leaves under Forced Withdrawal after it was already scored, adds nothing.

The app records the attacker on each damage event (§ 12), so this needs no extra input.

---

## 7. Objectives and victory

### 7.1 Objective scoring in the app

The app can't see the table. Each objective adds a **Score** step to the End Phase. Players answer short questions; the app adds the points and checks the threshold.

| Objective | Setup step | End Phase question (per side) | Points | Win at | Page |
|---|---|---|---|---|---|
| Raid | Place 3 tokens ≥ 21″ from your edge, 18″ apart | "Which 'Mechs picked up a token?" / "Which carried one back to your edge?" The app tracks who carries one; a carrier destroyed drops it | 2 per token returned | 10 | p. 7 |
| Control the Field | — | "Which of your 'Mechs are within 12″ of an enemy home edge, and 12″ from each other?" | Size of each | 12 | p. 7 |
| Destroy the Enemy | — | None: computed from damage (§ 6.6) | Size per enemy destroyed or crippled | 10 (12 for the Clan player) | p. 7 |
| Hold the Fort | Place 2 tokens ≥ 12″ from your edge, 18″ apart | From Turn 3: "Which of your tokens have your 'Mech within 6″ and no enemy within 12″?" | 1 per token, max 2 a turn | 10 | p. 7 |
| Breakthrough | — | "Which of your 'Mechs touch an enemy home edge?" They leave the game (not destroyed) | Size of each | 10 | p. 7 |
| Find the Target | **[HOUSE]** Needs 3+ buildings; the app hides 3 targets among them | "Which buildings did your 'Mechs search?" (end a move beside one). The first side to search a target finds it | 5 per target | 10 | p. 7 |

**Clan and Inner Sphere** (Destroy the Enemy, Breakthrough): when a side of all-Clan 'Mechs plays a side of all-Inner-Sphere 'Mechs, each Clan 'Mech scores 1.5 × Size, and the Clan side needs 12 in Destroy the Enemy (p. 7). Mixed forces use no multiplier **[HOUSE]** (D12). Half points are kept ("7.5") and never rounded.

A VP strip in the battle header (`as.battle.vp`) shows each side's points while an objective is on. VoiceOver reads "Side A 6 points, Side B 4 points, 10 to win".

### 7.2 Win checks (End Phase)

In order:

1. Sides that are out are marked (§ 6.5).
2. Objective: any side at or over the threshold wins. If more than one reaches it in the same End Phase, the higher score wins; equal scores tie **[HOUSE]**.
3. Last side standing: one side left wins. None left (mutual wipe) is a draw.
4. Turn limit reached: § 7.3.

### 7.3 Turn limit and tie-breaks [HOUSE]

At the turn limit's End Phase (D10):

1. Objective game: most victory points.
2. Then: most PV still on the table (adjusted PV of 'Mechs not destroyed or withdrawn).
3. Then: a tie between the sides still level.

Missions use remaining Structure for their cap; Play uses PV because forces differ in size and Structure doesn't reflect cost.

### 7.4 Outcome and result screen

`MatchOutcome` gains `.tied([SideId])` (§ 12). A draw with 3–4 sides can involve only some of them.

`VictoryView` in Play shows **standings**: one row per side in finishing order (winner first, then by points or PV, sides that went out last in reverse order of going out). Each row: badge, name, players, points, PV left, 'Mechs left. Then Match stats as today. Buttons: **Play again** (same setup, new session), **Edit and play again** (Review), **Back to Play**, **Undo the last step**.

No mission-cleared card; Play games don't touch `completedMissions`.

---

## 8. In-game flow

The battle cover, steps and sheets are the same as missions ([BattleTableSpec](BattleTableSpec.md)). What changes:

### 8.1 Table setup (Play)

`TableSetupStep` with a Play checklist instead of a mission's `tableSteps`:

1. Lay out the battlefield (layout preview, table size).
2. Roll for setup: each side 2D6 (`as.play.table.setupRoll`), same entry as initiative. Highest places terrain first and picks its edge first (3–4 sides).
3. Place terrain (§ 5.4 checklist).
4. Place objective tokens, when the objective has them.
5. Deploy: on the table (default) — the setup winner chooses to place first or last, then sides place one 'Mech at a time in setup-roll order (p. 11; 3–4 sides **[HOUSE]** order). Off the table — skip; Turn 1 movement enters from the home edge.

"Who's who" shows every side's card, not just A and B. **Swap** becomes "Reorder sides" before the battle starts.

### 8.2 Initiative

`InitiativeStep` lists every side still in: badge, name, two `DieFacePicker`s (`as.initiative.<sideRaw>.die1/.die2`). 4 sides stack in a 2 × 2 grid on regular width and in a column on phone and at accessibility sizes. Ties are flagged per pair: "Sides A and C tied — roll again" with **Clear** for just those dice. The dock confirm reads "Order: C, A, D, B — start moving" (`as.initiative.confirm`).

"Players choose the order" replaces **Skip the roll**: a reorderable list (`as.initiative.agree`).

### 8.3 Movement

`activeSide` follows the § 6.2 sequence. The header shows who's up; the next two sides show small beside it ("then A, then D"). The pass banner names the side and, on a team, the controller of the next unmoved unit when there is one: "Side B — Alex's turn. Pass the phone."

**Skip remaining** marks every unmoved 'Mech on every side as moved, as today.

Off-table start: Turn 1's mover card says "Enter from your home edge. Measure from the edge."

### 8.4 Combat

As today, both (all) sides in one list, initiative order. The shooter picker groups by side. Targets: enemies only (§ 6.3). Each shot records attacker side for § 6.6.

### 8.5 End Phase

`CleanUpStep` adds, in order: crits and removals as today, heat, **Score** (when an objective is on, § 7.1), sides out, then the win check. The dock says **See result** when this End Phase finishes the game.

### 8.6 Compact battle mode

Play games are bigger than missions: up to 24 'Mechs. Play depends on FUTURE-PLAN section 1:

| Item | Needed for | Play use |
|---|---|---|
| 1.1 Coaching fades | All Play | Play games start in **Brief** coaching. The Settings choice still wins |
| 1.2 One dense row per 'Mech | 3+ sides, or > 8 'Mechs | Required before PM7 |
| 1.3 Header in the nav bar | All Play | The header also holds the side order strip and VP strip |
| 1.4 Smaller dock | All Play | — |
| 1.6 Armor pips stop using Side A's colour | 3+ sides | Required: with four side colours, armor must be neutral |
| 1.7 Landscape table view | Nice to have | Columns per side; 3–4 sides scroll horizontally |

Plus, for Play:

- **Group by side**, with a collapsible header per side showing its badge, 'Mechs left and "N to move" / "N to fire".
- **Filter** chips: All · Still to move · Still to shoot (`as.battle.filter`).
- Sides that are out collapse to one line at the bottom.

### 8.7 Hotseat with four

Today's HotseatSpec holds, generalised:

- One device, passed around. Prompts use side names, then player names; never "you".
- The pass banner appears when `activeSide` changes in Movement. Combat has no banner (simultaneous).
- VoiceOver announces each change: "Side C, Sam, is up."
- Players can hand the phone to whoever is nearest in Combat; any side's shot can be entered.

---

## 9. Terrain board builder

Owner requirement (2026-11-26): in Play, players build the battlefield by dragging terrain onto the table, and save boards as presets to pick next time.

A **board** is a top-down plan of the real table: its size, any mapsheets under it, terrain pieces and deployment zones. The players build the same thing with real terrain. The app never checks the real table.

### 9.1 Screens

| ID | Role |
|---|---|
| `as.play.board.list` | Board presets: starter boards, then yours. Pushed from Battlefield (§ 5.4) and from Play home → **Boards** |
| `as.play.board.editor` | The builder: canvas, palette, inspector |
| `as.play.board.pieceList` | The list editor: every piece as a row (the accessible way to build, § 9.6) |
| `as.play.board.inspector` | Selected piece: kind, size, rotation, level, building class, position |
| `as.play.board.save` | Name and save (sheet, medium detent) |

### 9.2 The canvas

Starting model: `MissionLayoutDTO` and `MissionLayoutView` (inches, origin top-left, `sheets`, `zones`, `features` of kind `hill`, `woods`, `wall`, `tree`). The builder edits the same shape, extended (§ 9.8).

- **Table:** width and depth in inches, from Battlefield (§ 5.4): presets 3′ × 4′, 4′ × 4′, 4′ × 6′, custom 12″–96″.
- **Mapsheets underneath (optional):** from the collection's maps (`CollectionMath.ownedMaps`) or the catalog. Each sheet is a labelled rectangle (about 22″ × 17″) the player can move and rotate by 90°; sheets snap edge to edge. **Built (board follow-ups):** tap a sheet to select it (a drag on an unselected sheet still pans, because sheets cover most of a mapsheet table); drag a selected sheet to move it (grid snap, then flush to a neighbour's or the table's edge within 1½″; no pull with snap off); the round handle or **Turn 90°** turns it about its centre (`Sheet.rotation` 90/180/270, width and depth swap). A sheet may reach past the right or bottom of the table: a warning shows ("1 mapsheet reaches off the table") and **Fit table to sheets** (Board options, or the sheet inspector) sizes the table to the arrangement, 12″–96″, keeps pieces on it and redraws the zones **[HOUSE]**. List editor: a Mapsheets section with the same move, turn and fit actions; VoiceOver actions Move, Turn 90 degrees. Ids `as.board.sheet.*`. The app has no mapsheet art, so a sheet is a tinted rectangle with its printed name. The printed map's own terrain is the map's; the player adds pieces only for extra terrain, as missions do.
- **Grid and snap:** a 1″ grid with a heavier line every 6″ (the distance most rules use). Snap: 1″ (default), ½″, or off. Rotation snaps to 15°, or free with snap off. Alpha Strike measures in inches; there are no hexes, even on mapsheets.
- **Rulers:** the edges show inches every 6″. A **Measure** tool draws a line between two points and shows its length ("14.5″"), for checking the book's placement distances.
- **Zoom and pan:** pinch and two-finger drag; double-tap fits the table. Zoom 50 %–400 %.
- **Home edges and zones:** drawn in each side's colour and shape (§ 14), from § 6.4 for the game's side count. Zones are editable: drag their inner edge to change depth (default 6″, p. 11), drag ends to change width. **Built (board follow-ups):** each zone has a handle on its inner edge (`as.board.handle.zone.<side>`): drag to change that zone's depth, snapped per the Snap setting, 2″–12″ and at most a third of the table across **[HOUSE]**; a readout shows "Side A zone 8″ · 2 inside" and the existing zone warning counts pieces left inside. VoiceOver: the handle is adjustable, ±1″ per swipe. The Zone depth menu (all zones at once) and **Reset zones** stay. Dragging a zone's ends for width is still later. Each change is one undo step. **Reset zones** restores the rule. A board stores zones for 2, 3 and 4 sides, so one board works for any game (§ 9.7).
- **Centre line** (2 sides): a dashed line, with the p. 8 placement bands (6″ and 24″ from it) shown while placing terrain under **Show placement bands**.

### 9.3 Terrain palette

Only terrain the QSR defines. Each piece shows what it does in play in its inspector, in plain words, with the page.

| Piece | Kind | Default size | Movement | Line of sight | Attack | Terrain choices (p. 8 count) | Pages |
|---|---|---|---|---|---|---|---|
| **Single tree** | `tree` | 2″ round, 2″ tall | +1″ to move through; can't end a move in it | Doesn't block; counts as 2″ of woods | Woods +1 when intervening more than 2″ from the attacker, or when the target touches it | 2 trees = 1 choice | pp. 8, 15, 19 |
| **Woods** | `woods` | 5″ round; or 3″ × 9″ strip | +1″ per inch; can end a move in it | Blocked by 6″ or more of woods | Woods +1 (once, even if both intervening and occupied). No partial cover | 1 (larger = 2) | pp. 9, 15, 17, 19 |
| **Hill** | `hill` | 5″ round; or 3″ × 9″; level 1″ | No cost across the top; level change costs extra per inch up or down; max 2″ of level change per 2″ moved, 3″+ is prohibited | Blocks if more than two-thirds of the target is behind it | Partial cover +1 when one-third to two-thirds is hidden | 1 (larger = 2). A smaller hill on top adds a level | pp. 9, 15, 19 |
| **Water** | `water` | 5″ round; or 2.5″ × 10″ strip; depth 1″ (fixed) | +1″ per inch, plus a level change in and out | Not blocked | 'Mechs standing in it have partial cover +1 | 1 (larger = 2) | pp. 10, 15, 19 |
| **Rough** | `rough` | 4″ round; small 2″ | +1″ per inch | Not blocked | None | 1 (two 2″ = 1) | pp. 11, 15 |
| **Rubble** | `rubble` | as rough | as rough | as rough | as rough | as rough | p. 11 |
| **Small building** (box) | `building` | 1.6″ × 1.6″, 2″ tall, **Medium** | +1″–4″ by class; can't end a move in it; can climb on with ≤ 2″ level change or jump on if jump ≥ height | As hills | Partial cover as hills | 2 small = 1 | pp. 10, 28 |
| **Large building** (box) | `building` | 4.25″ × 3″, 2″ tall, **Heavy** | as above | as above | as above | 1 | pp. 10, 28 |
| **Wall / bridge** | `wall` | 6″ × 0.5″, 1″ tall | Building rules (p. 10) | As hills | As hills | 1 | p. 10 |

Notes:

- **Light and heavy woods are not Quick-Start terrain.** The QSR has one kind of woods (a diagram on p. 17 is labelled "light woods", but no rule differs). The palette offers one Woods piece. Heavy woods would be a Commander's Edition rule; out of scope (§ 1).
- **Level-change cost is [OPEN]:** the Movement Cost Table (p. 15) prints +2″ per 1″ of elevation; the Level Change paragraph on the same page says +1″ per inch. The inspector quotes the table and links the question ([Clash of Steel intake](../../docs/game-modes/alpha-strike/clash-of-steel-rules-intake.md)). Owner decision D27.
- **Buildings** carry a class (Light, Medium, Heavy, Hardened), height 1″–12″ and CF (default by class, p. 28). Box defaults: small = Medium, large = Heavy (p. 10). The app tracks no damage for buildings drawn on a board (the Rules step's buildings are the tracked ones, PM11); the inspector says so.
- **Hills** stack: a hill placed inside another hill's outline gets the next level (p. 9). Each hill shows its level ("Level 2″").
- Every piece can be named ("North ridge"). Pieces from a mapsheet's printed terrain are not added; the sheet is the terrain.
- **Objective tokens** (§ 7.1) are a marker kind (`objectiveToken`) owned by a side. Not terrain; they have no rules effect on the board. **Built (board follow-ups):** the palette and list editor have an **Objective token** tile (`as.board.palette.token`). With Raid in the setup, each side gets 3 tokens named "Raid 1"–"Raid 3" (every side once any side plays Raid, as the scoring does **[HOUSE]**); Hold the Fort gives its side 2, "Hold 1"–"Hold 2". Adding fills the next missing name; extra tokens, or any token with no objective (or from the Boards list), are generic "Token n" for Side A, and the inspector's Owner picker changes the side. A counter ("Raid tokens: A 2 of 3, B 0 of 3", `as.board.tokens.counter`) shows progress. Hints, not blocks (p. 7): a token closer to its side's edge than 21″ (Raid) or 12″ (Hold) or within 18″ of a sibling is flagged. The objective is read when the builder opens, so choose it first (Back from the Objective step, then Edit board). Tokens are not terrain choices and have no zone warning. Names and sides use existing fields; no schema change.

### 9.4 Editing with touch

| Action | Touch | Also |
|---|---|---|
| Add | Drag a piece from the palette onto the canvas; or tap a palette piece to drop it at the centre of the view | List editor **Add** (§ 9.6) |
| Select | Tap. Selected pieces show handles and open the inspector | |
| Move | Drag. Snaps to the grid. Pieces may overlap (woods on a hill is legal, p. 9) | Inspector X / Y fields; nudge buttons (1″ or snap step) |
| Rotate | Two-finger twist, or the round handle. 15° steps with snap on | Inspector rotation field and ±15° buttons |
| Resize | Corner handles. Shows width × depth in inches while dragging | Inspector W / D steppers |
| Duplicate | Context menu (long press) | Inspector **Duplicate** |
| Delete | Context menu, or drag to the trash zone | Inspector **Delete**; list row swipe |
| Undo / redo | Toolbar, and shake per system setting | ⌘Z / ⇧⌘Z on iPad with a keyboard |
| Multi-select | Long press, then tap more pieces; move together | List editor checkboxes |

**Placement hints**, not blocks: a piece inside a deployment zone gets a warning outline ("Inside Side B's zone"); a piece within 4″ of another shows the distance; with **Show placement bands** on, the inspector says which p. 8 band a piece is in. A counter shows **terrain choices** per the p. 8 counting ("14 of 16 choices placed"), with the book's 8 per side for 2 sides and 6 per side for 3–4 (§ 5.4).

**Random board** (later, PM13): fills the table with N choices following the p. 8 bands. Marked "for quick games"; the players can edit the result.

### 9.5 iPhone and iPad layout

| | iPhone portrait | iPhone landscape | iPad |
|---|---|---|---|
| Canvas | Full width, fit to table | Full height, left | Centre |
| Palette | Bottom strip, horizontally scrolling | Right column | Left sidebar, always visible |
| Inspector | Sheet, medium detent, on select | Right column under palette | Right inspector (`.inspector`) |
| List editor | Toolbar button → sheet | same | Toggle in the sidebar |

Liquid Glass toolbar for Undo, Redo, Measure, Snap, List, Save. On iPad, Apple Pencil works as a finger; pointer hover shows a piece's name.

### 9.6 VoiceOver and the list editor

Dragging on a canvas is not accessible enough on its own. Every action has a non-drag path:

- The **list editor** (`as.play.board.pieceList`) shows every piece: kind, name, size, position in inches from the top-left, rotation, level. **Add piece** asks for kind, then fills a form (size, X, Y, rotation). Rows support swipe delete, Duplicate, and **Move up / down / left / right** by the snap step as accessibility actions.
- On the canvas, each piece is an accessibility element: "Woods, 5 by 5 inches, centre 14 inches from the left, 9 from the top. Inside Side A's zone." Custom actions: Move left / right / up / down, Rotate 15°, Bigger, Smaller, Delete. Adjustable trait for rotation.
- The canvas as a whole reads a summary, built like `MissionLayoutView.spoken`: "48 by 48 inch table. 2 woods, 1 hill level 2, 1 water. Zones for 4 sides."
- Hit targets: handles at least 44 pt at every zoom (they don't shrink with zoom).
- Reduce Motion: no snap animation. Increase Contrast: piece outlines thicken; terrain fills use the content tokens, never side colours.
- Terrain colours are not side colours (woods green, hill brown, water blue-grey, rough and rubble grey, buildings slate). Each kind also has a pattern or glyph (tree glyph, contour lines, wave lines, dots, roof outline) so kinds are told apart without colour. Water's blue-grey must not be confused with Side C's cobalt; zones are outlines with the side shape, terrain is filled.

### 9.7 Presets

- **Save** names the board (`as.play.board.save`), max 40 characters. The table size and side counts it supports are shown in the list ("4′ × 4′ · 2–4 sides · 12 pieces").
- **Duplicate**, **Rename**, **Delete** (confirmed; it can't be undone) from the list's context menu and swipe.
- **Starter boards** are built in and read-only (Duplicate to change one):
  - each training mission's layout (Ridge Line … Full Lances) and Meet and Greet, read straight from the mission JSON's `layout` (`MissionLayoutDTO`);
  - "Open 4′ × 4′ for four", "Open 3′ × 4′" (zones only).
- **Linking to a game:** starting a game copies the board into the session (`PlaySetup.battlefield.board`). Later edits to the preset don't change a game in progress or a saved setup; **Last setup** keeps its own copy and notes "Board changed since" with **Use the new version** when the preset is newer.
- A board made on a smaller table can't be used on a bigger one without opening it (the app asks "Stretch to 48 × 48?" or "Keep size, centre it").
- Zones follow the game's side count: the board keeps a 2-, 3- and 4-side zone set; unset ones are generated from § 6.4.

**Share as a file** (owner decision D26): export a board as `.mechboard` (JSON, UTType conforming to `public.json`) through the share sheet, and open one from Files or AirDrop to import it as a new preset. **Built in PM13** for export and import through the Boards list; opening a file straight from Files or AirDrop is still later. Imported files are data only: validated against the schema, sizes clamped, unknown kinds dropped with a notice. No network.

### 9.8 Model changes

`MissionLayoutDTO` stays as the mission JSON contract. Play adds a Domain `BoardLayout` that decodes every mission layout unchanged and adds:

| Addition | Why |
|---|---|
| `id: UUID`, `name`, `createdAt`, `updatedAt`, `isStarter` | Presets |
| `FeatureKind` + `water`, `rough`, `rubble`, `building`, `objectiveToken` | QSR palette (§ 9.3) |
| `Feature.id`, `name`, `shape` (`.rect`, `.ellipse`), `rotation` (degrees) | Editing; round templates |
| `Feature.level` (hills 1″–4″ per piece, buildings 1″–12″) | Levels (p. 9, p. 10) |
| `Feature.buildingClass` (`light`, `medium`, `heavy`, `hardened`), `cf` | p. 28 |
| `Feature.side` (`objectiveToken` only) | Owner of a token |
| `Sheet.rotation` (0, 90, 180, 270) | Sheets turned on the table |
| `Zone.side` accepts "A"–"D"; `zonesBySideCount: [Int: [Zone]]` | 2–4 sides (§ 6.4) |
| `Zone.homeEdge` | Forced Withdrawal and objectives name the edge |
| `schemaVersion` | Board files and stored presets |

Missions keep `MissionLayoutView` read-only; it learns to draw the new kinds so a board preview and a mission map look the same. The editor is a new view (`BoardEditorView`) wrapping the same drawing code with gestures.

**Persistence:** presets in SwiftData `SDBoardPreset` (id, name, updatedAt, payload JSON) in `SchemaV2`, the same lightweight stage as saved forces (§ 12). Whichever of PM9 or PM13 lands first introduces `SchemaV2`. Starter boards are not stored; they are read from bundled JSON. An unsaved board being built lives in the setup draft.

### 9.9 Using the board in the game

- Table setup (§ 8.1) shows the board with a "Set up the table like this" step instead of the free terrain checklist, and highlights the zones while deploying.
- The battle screen's toolbar gets **Board** (`as.battle.board`), a sheet with the board, read-only.
- **Later (not in PM12–PM13):** the shot sheet could use the board to suggest modifiers ("Target is in woods?" pre-ticked when its mini was marked inside a woods piece). The app doesn't know where minis are, so this needs players to tap where each 'Mech stands. Marked **later**; owner decision D28.

### 9.10 Tests

| Kind | Tests |
|---|---|
| Model | Every mission's `layout` decodes as a `BoardLayout` and re-encodes to the same JSON; new fields round-trip; unknown kind fails soft; clamp sizes to the table |
| Rules helpers | Terrain-choice counting per p. 8 (2 trees = 1, large templates = 2, 2 small buildings = 1); hill stacking gives level 2; zone generation for 2/3/4 sides on 36 × 48, 48 × 48, 48 × 72 |
| Geometry | Snap to 1″ / ½″; rotation snap; hit-testing rotated ellipses; inside-zone warning; distance readout |
| Persistence | Save, rename, duplicate, delete; SchemaV1 → V2 open; a game keeps its board copy after the preset changes |
| Import (if D26) | Valid file imports; malformed or oversized file refused with a message; never overwrites a preset |
| UI | Drag a woods from the palette, move, rotate, delete, undo; build the same board in the list editor only; save and pick it in setup; starter board loads Ridge Line's layout |
| Accessibility | VoiceOver custom actions move a piece by 1″; summary string; AX5 inspector; iPad sidebar and inspector; landscape iPhone |

## 10. Card data: the card library

### Problem

Today, card numbers live inside each mission's JSON. 14 faces have checked numbers: the 8 A Game of Armored Combat faces in the missions and 6 Alpha Strike box faces in Meet and Greet. 7 more Alpha Strike box faces are checked in `book-scenarios.md` but not in any JSON. The owner owns 13 Alpha Strike box minis (13 double-sided cards, 26 faces) and the 8 A Game of Armored Combat minis (7 cards: the Awesome and BattleMaster share one; 14 faces).

| Source | Faces | Checked on MUL today | To check |
|---|---|---|---|
| A Game of Armored Combat | 14: LCT-1V/1E, COM-2D/3A, SHD-2H / Durant Carlyle, WVR-6M/6R, CPLT-C1/K2, TDR-5S/5SE, AWS-8Q / BLR-1G | 8 | 6: LCT-1E, COM-3A, SHD-2H (Durant Carlyle face), WVR-6R, CPLT-K2, TDR-5SE |
| Alpha Strike Box Set | 26: WSP-3W/5A, LCT-3M/7V, BJ-3/5, PXH-3K/4M, TR1/TR5, ARC-5R/7C, WHM-6R/8R, AS7-S/S4, Fire Moth D/G, Pouncer Prime/T, Nova Prime/T, Timber Wolf Prime/T, Warhawk C/T | 13 (the book's faces) | 13: WSP-3W, LCT-3M, BJ-3, PXH-3K, TR1, ARC-5R, WHM-6R, AS7-S, Fire Moth D, Pouncer Prime, Nova Prime, Timber Wolf Prime, Warhawk C |
| **Total** | **40** | **21** | **19** |

### Solution: `as-card-library.json`

One bundled file of every face for minis in the boxes `as-box-sets.json` lists with Alpha Strike cards. Read by `ContentCatalogRepository.cardLibrary()`.

```json
{
  "schemaVersion": 1,
  "contentVersion": "1.0.0",
  "sourceNote": "Checked by hand against masterunitlist.battletech.com. No bulk data.",
  "cards": [
    {
      "id": "locust-lct-7v",
      "name": "Locust LCT-7V",
      "chassis": "Locust",
      "printedCard": "as-box-locust",
      "boxes": ["alpha-strike-box"],
      "techBase": "innerSphere",
      "role": "Scout",
      "pv": 25, "sz": 1, "mv": "20\"", "tmm": 4,
      "s": 2, "m": 2, "l": 0, "ov": 0,
      "armor": 2, "structure": 1,
      "abilities": "",
      "checked": { "on": "2026-11-24", "source": "MUL" }
    }
  ]
}
```

- `printedCard` groups the faces of one physical card (the Awesome and BattleMaster share one).
- `s`/`m`/`l` accept `"0*"` (`PrintedDamage`, as in mission JSON).
- `checked` is null for a face not yet checked. An unchecked face still lists name, Size and chassis so the picker can show it, with **Enter numbers from your card**.
- Missions keep their own copies for now. A test (`CardLibraryTests`) asserts every mission unit matches its library face, so they can't drift. Moving missions to read from the library is optional, later.

**Checking rule** (extends GuidedMissionSpec's card rule): Play may use any library face with `checked` set, and any user card. Learn missions still use checked faces only.

### User cards

Cards entered by hand (§ 5.3) are stored on the device (§ 12) with `source: "user"`. They show "Your numbers" everywhere. They are never uploaded.

### Missing card data at play time

| Case | Behaviour |
|---|---|
| Face in the library, checked | Use it |
| Face in the library, not checked | Picker row says "Enter numbers from your card"; card entry opens prefilled with name and Size |
| Owned single with no library match (typed name) | Picker offers "Enter its card" |
| Session saved with a user card later deleted | The session keeps its own snapshot (`MatchUnitState`); nothing breaks |

---

## 11. Saving and resuming

- Autosave after every command, as today. Leaving the cover keeps the game.
- Resume shows on Learn and Play (§ 3). Resume opens at the same turn, phase, active side and sequence position.
- **Setup draft**: `PlaySetupDraft` saved on every change while setting up. Play home shows "Finish setting up" when a draft exists (`as.play.draft`), with **Discard**.
- **Last setup**: the last started setup, kept after the game ends.
- **Play again**: a new session from the same setup; repairs every 'Mech.
- Unreadable saves follow MatchSessionSpec: set aside, not deleted.

---

## 12. Data model changes

Pure Domain first (PM1). Missions must behave the same; every existing test keeps passing.

### Sides

`SideId` stays a `String` raw-value enum so saved games decode. Two cases are added:

```swift
public enum SideId: String, Codable, Sendable, CaseIterable {
    case lanceA, lanceB, lanceC, lanceD     // raw values unchanged for A and B
    public var letter: String               // "A" … "D"
    public var displayName: String          // "Side A" … (default; a session may rename)
}
```

`SideId.other` is removed. Its call sites (about 30 in Domain and Features) move to `session.opponents(of:)`, which returns the other sides still in the game. A 2-side helper (`session.otherSide(of:)`) can keep mission code short and asserts two sides.

About 256 references to `lanceA` / `lanceB` sit in 46 Swift files (19 are tests). Most are fixtures and stay valid. Accessibility ids that contain `lanceA` keep their spelling; new sides use `lanceC` / `lanceD` so the pattern holds.

New per-session sides:

```swift
public struct MatchSide: Codable, Sendable, Equatable, Identifiable {
    public var id: SideId
    public var name: String              // "Side A" or the player's choice
    public var players: [String]         // may be empty
    public var homeEdge: TableEdge?      // .south, .north, .west, .east
    public var isOut: Bool
    public var outOnTurn: Int?
    public var conceded: Bool
}
```

`MatchSession.sides: [MatchSide]`, in seat order. Old saves decode with `[A, B]` and default names.

### Initiative

```swift
public struct InitiativeRolls: Codable, Sendable, Equatable {
    public var rolls: [SideId: DiceRoll2D6]
    public var rerolls: [[SideId: DiceRoll2D6]]   // tie-break rounds (§ 6.1)
    public var order: [SideId]                     // lowest first
}
```

The decoder still reads the old `{ lanceA, lanceB }` shape. `initiativeWinner` stays (= `order.last`). `MatchCommand.setInitiative(rolls:)` takes the dictionary; `agreeInitiative(firstToMove:)` becomes `agreeInitiative(order:)`, keeping the old case as a 2-side convenience.

### Movement

`AlphaStrikePhaseEngine.movementSequence(order: [SideId], units:)` implements § 6.2. The 2-side function becomes a call to it. `nextMovementActiveSide` reads the sequence as today.

### Play setup and scoring

```swift
public struct PlaySetup: Codable, Sendable, Equatable {
    public var sides: [MatchSide]
    public var budget: ForceBudget           // .pointValue(Int) or .count(units: Int, sizeCap: Int?)
    public var allowImprovedSkills: Bool
    public var minimumSkill: Int
    public var pool: UnitPool                // .owned, .anyCard
    public var battlefield: Battlefield      // mapsheets + arrangement, or mat size; derived width/depth;
                                             // board: BoardLayout? (a copy, § 9.7)
    public var objective: ObjectiveId?       // nil = last side standing
    public var turnLimit: Int?
    public var startOnTable: Bool
    public var forces: [SideId: [ForcePick]] // card id or user card id, face, skill, mini, controller
}

public enum ObjectiveId: String, Codable, Sendable, CaseIterable {
    case raid, controlTheField, destroyTheEnemy, holdTheFort, breakthrough, findTheTarget
}
```

On `MatchSession`:

| Field | Type | Old saves |
|---|---|---|
| `sides` | `[MatchSide]` | `[A, B]` |
| `play` | `PlaySetup?` | nil (a mission) |
| `victoryPoints` | `[SideId: Double]` | empty |
| `objectiveState` | `ObjectiveState?` (tokens carried, scored units) | nil |
| `scoredUnits` | `Set<UUID>` (§ 6.6 once-only) | empty |

On `MatchUnitState`: `controller: String?`, `cardId: String?`, `techBase`, and `lastDamagedBy: SideId?` plus `scoredFor: SideId?`. All `decodeIfPresent`.

`ScenarioRuleset.victory` gains `.lastSideStanding` and `.objective(ObjectiveId)`; `maxTurns` keeps its meaning. `VictoryEvaluator` follows § 7.2–7.3.

`MatchOutcome` gains `.tied([SideId])`. Encoded as `{ "type": "tied", "sides": [...] }`. `.draw` stays for missions.

New commands:

```swift
case startPlay(setup: PlaySetup, units: [MatchUnitState])
case setSetupRolls(rolls: [SideId: DiceRoll2D6])   // table setup (§ 8.1)
case concede(side: SideId)
case scoreObjective(side: SideId, entries: [ObjectiveScoreEntry])
```

Sides going out happens inside `resolveEndPhase`.

### Persistence

- **Payload:** `MatchSession.currentSchemaVersion` and `MatchSessionPayloadSchema.current` go from 1 to 2. Every new field decodes with a default, so v1 saves load in the new build.
- An older build that meets a v2 save sets it aside as `unreadable` (existing rule). That only matters if someone downgrades; TestFlight builds go forward.
- **SwiftData:** `SDMatchSession` is unchanged (`activeSideRaw` is a string; `lanceC` fits). No migration stage for it.
- **Saved forces and user cards** (PM9): a new `SchemaV2` adds `SDSavedForce` and `SDUserCard` (id, name, updatedAt, JSON payload), and `SDBoardPreset` for boards (§ 9.8). Whichever of PM9 and PM13 lands first introduces `SchemaV2`; the other adds its model in the same version if not yet released, else in `SchemaV3`. Adding models is a lightweight stage: `MechBuddyMigrationPlan.stages = [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]`. Test the V1 → V2 open with a real V1 store file.
- **Setup draft and last setup:** JSON in `AppPreferences` owned keys (`play.setupDraft`, `play.lastSetup`), like the collection, so `reset()` clears them.

---

## 13. Content and data needs

| Need | File | Milestone |
|---|---|---|
| Card library, 40 faces, 19 to check on MUL | `Resources/Content/AlphaStrike/as-card-library.json` | PM2 |
| Unit role and tech base per face | same | PM2 |
| Objective copy (setup steps, questions, thresholds, page) | `as-objectives.json` | PM8 |
| House rules copy for the info sheet | `as-play-house-rules.json`, or in `as-rules-topics.json` as topic `playHouseRules` | PM7 |
| Rules tab: "More than two sides" topic marked house rules | `as-rules-topics.json` | PM7 |
| Mapsheet size (default 22″ × 17″; per-product overrides if any differ) | `map-catalog.json` gains optional `sheetSize` | PM4 |
| Starter boards: two open tables (mission boards come from mission JSON) | `as-starter-boards.json` (`BoardLayout` array) | PM13 |
| Terrain palette copy (what each piece does, page) | `as-terrain-palette.json` | PM12 |
| Owner: read the 19 unchecked faces off the cards or MUL; confirm SHD-2H "Durant Carlyle" face numbers | — | PM2, **Owner** |

ContentPackSpec's "Free Battle defaults: all true" becomes the Play defaults in § 5.5. The governance rule "New mode / scenario → ContentPackSpec + PRODUCT_SCOPE + inventory" applies at PM4: Play is not a new `GameModeId` (it is Alpha Strike, `alphaStrikePhased`); it is a new way to start a session.

---

## 14. Side colours and accessibility

### Four side styles

Today: Side A coolant teal, circle; Side B ember, diamond ([DesignSystemSpec](../DesignSystemSpec.md)). Play adds two. Every side has a **letter, a shape and a colour**; colour is never the only cue.

| Side | Colour token | Light | Dark | Shape | Name on screen |
|---|---|---|---|---|---|
| A | `side.a` (coolant) | `#1F7F93` | `#4FB0C6` | circle ● | Side A |
| B | `side.b` (ember) | `#D9622B` | `#F07A3E` | diamond ◆ | Side B |
| C | `side.c` (cobalt), proposed | `#2F5FB8` | `#7FA6EE` | triangle ▲ | Side C |
| D | `side.d` (orchid), proposed | `#A3478A` | `#E08CC6` | square ■ | Side D |

C and D are picked from the Okabe–Ito colour-blind-safe family (blue, reddish purple) and kept apart from signal amber (actions) and the damage reds. The values are proposals. Before PM7:

- check text-on-fill contrast ≥ 4.5:1 in light, dark and Increase Contrast, choosing `text.onSide` or `text.onSignal` per side as B does today;
- check fill against the background ≥ 3:1 (non-text);
- check all four under deuteranopia, protanopia and tritanopia simulation. Teal (A) and cobalt (C) are the closest pair under tritanopia; the shapes carry that case;
- armor pips go neutral first (FUTURE-PLAN 1.6).

### Rules

| Area | Rule |
|---|---|
| Badges | `SideBadge` shows shape + letter at every size. Side names may be custom; the letter stays |
| VoiceOver | "Side C, triangle, Sam's Lance" (letter, shape, custom name). Announce active side, pass lines, sides going out, VP changes, and the result |
| Dynamic Type | Setup and battle through AX5. Initiative for 4 sides stacks to one column; side pages in Forces scroll |
| Touch | ≥ 44 × 44 pt. Steppers and face switches included |
| Reduce Motion | No animated reorder in "Players choose the order"; use move buttons as an alternative to drag |
| Drag alternatives | Every reorder offers Move up / Move down actions (`accessibilityAction`) |
| Non-colour | Budget over/under says it in words; VP strip has numbers; out sides say "Out" |

New identifiers follow `{area}.{screen}.{control}` (§ 5, § 8). Add the screen ids to `ScreenCatalog` when each milestone builds its screen.

---

## 15. Teams in detail

A team is one side (p. 13). For the app that means:

- one initiative roll, one budget, one deployment zone, one place in move order;
- any player on the side may move or shoot any of its 'Mechs; the `controller` tag only helps prompts and the force list;
- objective points are the side's;
- the result names the side and lists its players.

Allied sides (each player on a team rolls initiative separately, budgets split) are option B in D3. Not recommended: no Alpha Strike rule covers it, and it would need the § 6 house rules for what is really a two-sided game.

---

## 16. Release surface

`ReleaseFlag.freeBattle` is renamed **`playMode`** (same meaning, new name). One more flag lets two-sided play ship first:

| Flag | Release | Full surface | Gates |
|---|---|---|---|
| `playMode` | off until PM10 | on | Learn \| Play tabs, Play home, setup, Play sessions. Off = today's four tabs |
| `playModeMultiSide` | off until the 3–4 side milestone ships | on | 3- and 4-side presets and "More…" with 3+ sides. Teams (1 v 2, 2 v 2) are under `playMode` |
| `playObjectives` | off until PM8 ships | on | Objective picker; off = last side standing only |
| `playBoards` | off until PM12 ships | on | Build a board, saved boards, Board in battle. Off = mat or mapsheets with generated zones only |

Existing flags still apply inside Play: `physicalOvWithdrawal` does **not** gate Play's rule toggles (a Play game is a full game, like Full Lances). `mulNetworkFetch` stays off; the MUL link is a Safari link.

If a release build loads a saved Play session while `playMode` is off (a downgrade), it shows the resume card and the battle as usual; it just can't start new ones.

Target release: owner decision D17. Recommended: 1.1 = 2 sides (1 v 1, teams), pickup; 1.2 = 3–4 sides and objectives.

---

## 17. Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | `SideId.other` and two-side assumptions are everywhere (≈ 256 `lanceA`/`lanceB` references, 46 files) | PM1 is Domain-only, with golden tests that every mission plays identically. UI moves side by side in later milestones |
| R2 | Four sides on a phone are crowded | Compact battle mode is a prerequisite (§ 8.6). Unit cap 24. Test on the smallest supported iPhone at AX5 |
| R3 | House rules feel wrong at the table | Labelled as house rules everywhere; an owner table test of 1 v 1 v 1 v 1 before `playModeMultiSide` ships |
| R4 | Unchecked or mistyped card numbers | `checked` per face; "Your numbers" badge; library contract tests; owner checks 19 faces |
| R5 | Payload v2 makes saves unreadable on older builds | Only on downgrade. Set aside, never deleted (existing rule) |
| R6 | Game length with 4 × 150 PV is unknown | Time estimate is a guide; collect real times at the owner's table test and tune defaults |
| R7 | Objective questions are slow every End Phase | Only sides with a possible score are asked (e.g. Hold the Fort from Turn 3; Control the Field skips a side with no 'Mechs past mid-table if players say so); "No one" answers in one tap |
| R8 | Colour C/D contrast fails | Shapes and letters carry meaning; adjust values in PM7 |
| R9 | Play scope creeps into Clash of Steel rules | Buildings, support and formations are explicitly PM11 and depend on Clash of Steel |
| R10 | Mini count vs collection (same chassis on two sides) | Stand-in logic already exists; Review lists stand-ins |
| R11 | The board builder is a large, gesture-heavy feature that could stall Play | Behind `playBoards`; Play works without it (mat or mapsheets plus checklist). The list editor ships with the canvas, not after |
| R12 | Canvas gestures fight VoiceOver and scrolling | Every action has a list-editor and custom-action path (§ 9.6); UI tests drive the list editor |
| R13 | Players read the board as rules the app enforces | Copy says "A plan of your table"; placement hints warn, never block |

---

## 18. Owner decisions

Each has a recommended default. "Silent" means the default is built.

**Owner, 2026-11-26: all recommended defaults accepted (D1–D29).** Build them as written.

| # | Question | Options | Recommended default |
|---|---|---|---|
| D1 | How do people pick Learn or Play? | A. Two tabs (Learn, Play), five in all. B. One tab with a Learn \| Play switch at the top | **A, two tabs** |
| D2 | Names | "Learn" / "Play"; retire "Free Battle" and rename its flag `playMode` | **Yes** |
| D3 | Teams (2 v 2, 1 v 2) | A. One side per team: one roll, one budget (QSR p. 13). B. Allied sides, each player separate | **A** |
| D4 | Three and four sides | Accept the § 6 house rules (initiative order, tied sides re-roll among themselves, round-by-round proportional movement, any-enemy home edge, last side standing) | **Accept, labelled [HOUSE]** |
| D5 | Default budget | 250 for 2 sides (QSR p. 7); 200 for 3; 150 for 4 | **As listed**, editable |
| D6 | Budget for uneven teams (1 v 2) | Per side (equal) or per player (the pair gets 500) | **Per side** |
| D7 | Skills | Card skill only; or allow better skills (pay PV, p. 35), min Skill 2; worse than 4 not offered (no QSR rule) | **Allow better skills, min 2**; Clan default 3 with PV paid |
| D8 | Which 'Mechs | Owned only, or any card in the app plus hand-entered cards (Play only) | **Owned by default; Any card one tap away; hand entry allowed** |
| D9 | Size cap | 10 'Mechs per side, 24 per game | **As listed** |
| D10 | Game length | No limit (QSR) with optional 6/8/10/12; at the limit: VP, then PV left, then tie | **No limit by default; tie-break as listed** |
| D11 | Destroy the Enemy with 3–4 sides | Points to the side whose attack destroyed or crippled; once per 'Mech | **Yes** |
| D12 | Clan × 1.5 | Only when an all-Clan side faces an all-Inner-Sphere side; mixed = no multiplier; keep halves | **Yes** |
| D13 | Deployment | On the table within 6″ (app habit, p. 11 option) or enter on Turn 1 (p. 11 default) | **On the table**, toggle to enter |
| D14 | 3–4 side table | Square 4′ × 4′+, one edge per side, zones the middle 3⁄8 of the edge, edges picked in setup-roll order | **Yes** |
| D15 | Active games | One at a time across Learn and Play, or one each | **One at a time** |
| D16 | Optional rules in Play | Overheat, punch and kick, Forced Withdrawal all on | **All on** |
| D17 | Release | 1.1: Play with 2 sides (1 v 1, teams), pickup. 1.2: 3–4 sides and objectives | **As listed** |
| D18 | Side C and D colours | Cobalt ▲ and orchid ■ (proposed values § 14), or others | **Cobalt and orchid**, after contrast checks |
| D19 | Conceding | Allowed; conceded 'Mechs score for nobody | **Yes** |
| D20 | Box scenarios (Meet and Greet, Clash of Steel) | Stay in Learn, or move to Play | **Learn** |
| D21 | Onboarding "I know Alpha Strike" → Play | Add later (OnboardingSpec) | **Later, after PM10** |
| D22 | Objective roll mapping | 1D6 = the six objectives in book order; re-roll 6 until Find the Target exists | **Yes** |
| D23 | Board builder timing | Ship with the first Play release, or after it behind `playBoards` | **After**: PM12–PM13 follow PM4; Play first ships with mat/mapsheets and generated zones |
| D24 | Grid and snap default | 1″ snap, 6″ major lines, 15° rotation; ½″ and off available | **As listed** |
| D25 | Starter boards | Every mission layout (training path and Meet and Greet) plus two open tables, read-only, duplicate to edit | **Yes** |
| D26 | Share boards as files | Export/import `.mechboard` JSON through the share sheet and Files; no network | **Built in PM13** (import through the Boards list; open-from-Files later) |
| D27 | Level-change cost shown in the hill inspector | +2″ per 1″ (Movement Cost Table, p. 15) or +1″ per 1″ (paragraph, p. 15) | **Quote the table (+2″) and flag the conflict**, same answer as the Clash of Steel intake's open item |
| D28 | Shot sheet uses the board (pre-tick woods or cover) | Needs players to tap where each 'Mech stands | **Later**, not in PM12–PM13 |
| D29 | Terrain pieces per side with 3–4 sides | 6 per side (house), or 8 like two sides | **6 per side** |

---

## 19. Milestones

Each is small enough for one branch and leaves `main` shippable with flags off.

| ID | Milestone | Size | Done when |
|---|---|---|---|
| **PM0** | Spec and owner decisions | S | This spec merged; owner answers § 18 (or accepts defaults) |
| **PM1** | N-side Domain | L | `SideId` C/D, `MatchSide`, initiative order and tie re-rolls, § 6.2 movement, elimination, `.tied`, payload v2 with v1 decode. Golden tests: every mission identical; 2-side sequence equals today's for 0–10 per side. No UI change |
| **PM2** | Card library | M | `as-card-library.json` with 40 faces; 19 faces checked (**Owner** help); `CardLibraryTests` (fields, PV, mission units match library, shared Awesome/BattleMaster card); PV page comment fixed |
| **PM3** | Learn \| Play shell | M | Behind `playMode`: five tabs, Learn = today's Play, Play home with empty state and Resume. Flag off = unchanged. UI tests for both |
| **PM4** | 1 v 1 pickup game | L | Setup screens 1–6 for two sides, one player each: budget and PV math, unit picker from collection and library, map or mat with layout, rules toggles, dice. Starts a session; plays to last side standing; result screen with standings; Play again. Setup draft and last setup |
| **PM5** | Compact battle mode | L | FUTURE-PLAN 1.1–1.4 and 1.6, plus group-by-side and filters (§ 8.6). Shared with missions |
| **PM6** | Teams | M | 1 v 2, 2 v 2, 1 v 3: players per side, controller tags, pass lines with names |
| **PM7** | Three and four sides | L | Behind `playModeMultiSide`: side C/D styles (contrast checked), N-side initiative and movement UI, any-enemy targets, home edges and zones for 3–4, sides going out, concede, standings. House rules info sheet and Rules topic. **Owner** table test of 1 v 1 v 1 v 1 |
| **PM8** | Objectives and turn limit | L | Behind `playObjectives`: five objectives (not Find the Target), Score step, VP strip, Destroy the Enemy attribution, Clan × 1.5, turn limit and tie-breaks, roll for objective |
| **PM9** | Saved forces and user cards | M | SchemaV2 (`SDSavedForce`, `SDUserCard`) with a tested V1 → V2 migration; card entry; Force tab "Saved forces"; load a saved force into setup |
| **PM10** | Release | M | Accessibility audit (VoiceOver, AX5, Increase Contrast, landscape, iPad); ScreenCatalog rows; feature inventory; ReleaseSurface defaults on for the chosen release; TestFlight table test |
| **PM11** | Clash of Steel rules in Play (later) | L | After Clash of Steel ships buildings, Battlefield Support and formations: toggles in § 5.5, Find the Target, per-side objective rolls |
| **PM12** | Board builder | L | Behind `playBoards`: `BoardLayout` (decodes every mission layout), canvas with table size, optional mapsheets, 1″ grid and snap, QSR palette (§ 9.3), add / move / rotate / resize / duplicate / delete with undo, inspector, list editor and VoiceOver actions, zones for 2–4 sides, terrain-choice counter, iPhone and iPad layouts. A built board goes into setup and shows at table setup and as **Board** in battle |
| **PM13** | Board presets | M | `SDBoardPreset` (SchemaV2), save / rename / duplicate / delete, starter boards from mission layouts, last-setup board copy, stretch-to-table. Stretch: random board, `.mechboard` share (if D26) |

Order: PM1 → PM2 → PM3 → PM4 is the first playable game. PM5 must land before PM7. PM6, PM8, PM9 and PM12 → PM13 can go in any order after PM4. PM11 waits for Clash of Steel.

---

## 20. Test plan

Follows [TestPlanSpec](../TestPlanSpec.md).

### Domain (unit, Swift Testing)

| Area | Tests |
|---|---|
| Movement | 2 sides: new sequence equals `movementSequence` today for every (a, b) in 0…10. p. 14 example (8 vs 5). 3 sides (4, 2, 2), (3, 3, 1), (5, 0, 2). 4 sides all equal; one side at 0 |
| Initiative | Order lowest first; 3-way tie; two pairs tied; re-roll only orders the tied sides; agreed order |
| Elimination | Side out at End only; out sides skipped in initiative and movement; concede removes at once |
| Victory | Last side standing (2, 3, 4 sides); mutual wipe draw; objective threshold; two sides reach it together; turn limit tie-breaks (VP, then PV, then tie) |
| Destroy the Enemy | Attribution by Structure 0, by crippled line, by crit; scored once; Clan × 1.5 and the 12 threshold; mixed forces |
| PV | p. 35 table bands (7/8, 12/13 … 52/53, 57); Skill 2 on 39 = 55 (book example); Clan default 3 |
| Budget | Under, exact, over; count mode with Size cap |
| Codable | v1 payload (from a fixture file) decodes into v2 with sides A/B; old `InitiativeRolls` shape; `.tied` round trip; old `MatchOutcome` |
| Missions | Every mission golden test unchanged |

### Content

`CardLibraryTests`: unique ids; every face has name, chassis, Size; checked faces have every stat; `0*` parses; each `printedCard` has 1–2 faces; every mission unit equals its library face; every Alpha Strike unit name in `as-box-sets.json` has at least one face.

### Persistence

SchemaV1 store opened by SchemaV2 build (PM9); unreadable v3 payload set aside; setup draft survives relaunch; `reset()` clears draft and last setup.

### UI (XCUITest, `-ui_testing`, `-enable_full_product_surface`)

| Flow | Checks |
|---|---|
| Flag off | Four tabs; Play tab is today's mission path (`play.home`) |
| Flag on | Five tabs; Learn holds the path; Play home empty state |
| 1 v 1 happy path | Setup 1–6 with app dice; play to a wipe; result standings; Play again |
| 2 v 2 | Controller names appear in pass banner |
| 1 v 1 v 1 v 1 | 4-side initiative entry; movement order follows § 6.2; a side goes out; standings order |
| Objective | Control the Field scored over two End Phases to 12 |
| Resume | Kill mid-Movement in a 3-side game; relaunch at same side and sequence step |
| Board builder | See § 9.10 |
| Accessibility | Every new id from § 5, § 8, § 9 present; AX5 layout snapshots of initiative (4 sides) and Forces |

### Owner table tests (manual)

- 1 v 1, 250 PV, Alpha Strike box only, on a mat (PM4).
- 2 v 2 with A Game of Armored Combat plus Alpha Strike box (PM6).
- Build a 4′ × 4′ board in the app, then the same table for real; check it reads true (PM12).
- 1 v 1 v 1 v 1, 150 PV, 4′ × 4′ (PM7). Note time per turn and whether the house rules felt fair. Notes in `ongoing/play-<date>/NOTES.md`.

---

## Acceptance criteria (first playable, PM4)

- Given `playMode` on, When the app opens for a player who cleared Mission 1, Then the tab bar shows Learn and Play, and Learn shows the mission path.
- Given two sides with 250 PV each built from owned minis, When Start game is tapped, Then the battle opens at table setup with both sides' cards and the layout.
- Given a Skill 2 pilot in a 39 PV 'Mech, Then its row shows 55 PV and the side total includes 55.
- Given all of Side B's 'Mechs are destroyed, When the End Phase resolves, Then the result shows Side A first and Side B second.
- Given a Play game at Turn 3 Movement, When the app is killed and reopened, Then Continue opens Turn 3 Movement with the same side up.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.1 (2 sides) / 1.2 (3–4 sides, objectives), per D17 |
| Last verified | 2026-11-26 (spec only) |
| Commit | — |
| Code paths | PM1: `Domain/Models/Identifiers.swift` (`SideId` C/D), `Domain/Models/MatchSide.swift` (`MatchSide`, `TableEdge`, `InitiativeOrder`), `Domain/Models/MatchSession.swift` (`sides`, `initiativeOrder`, `InitiativeRolls` v2, `.tied`, side helpers, payload v2), `Domain/Engines/AlphaStrike/AlphaStrikePhaseEngine.swift` (§ 6.2 `movementSequence(order:units:)`, `markSidesOut`), `Domain/Engines/AlphaStrike/VictoryEvaluator.swift`, `Domain/Commands/MatchReducer.swift` (`agreeInitiativeOrder`, `concede`). Tests: `Tests/Unit/PlayModeDomainTests.swift`, `Tests/Unit/MissionsUnchangedTests.swift`, fixture `Tests/Unit/Fixtures/match-session-v1.json` |
| PM3–PM4 | `App/RootTabView.swift` (Learn and Play tabs), `Data/Play/PlayShell.swift` (`RootTabRule`, `PlaySetupStore`), `Domain/Models/PlaySetup.swift` (`PlaySetup`, `ForceBudget`, `BudgetCheck`, `Battlefield`, `PlayRules`), `Data/Play/PlayForces.swift` (`PlayUnits`, `PlayPicker`, `PlayLayout`), `Domain/Commands/MatchReducer.swift` (`startPlay`), `Domain/Engines/AlphaStrike/VictoryEvaluator.swift` (PV turn-limit tie-break, `standings`), `Features/PlayMode/*`. Tests: `Tests/Unit/PlayModeShellTests.swift`, `Tests/Unit/PlayPickupTests.swift`, `Tests/UI/PlayModeShellUITests.swift`, `Tests/UI/PlayModePickupUITests.swift` |
| PM4 deferred | Card entry by hand and user cards (PM9; unchecked faces show locked in the picker); mini markers in Forces (set in battle instead); controller tags and side names in battle chrome (PM6: battle still says Side A / Side B; names show in setup, Play home and the result); objectives and roll-for-objective (PM8; "last side standing" only); setup roll command `setSetupRolls` (table checklist line instead); `ScenarioRuleset.victory` keeps `.destroyAllEnemies` for last side standing rather than a new `.lastSideStanding` case. Turn limit (owner addition) is built early with the § 7.3 PV tie-break |
