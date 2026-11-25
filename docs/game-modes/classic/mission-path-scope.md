# Classic mission path — scope (10 missions)

**Status:** draft, 2026-11-24. Nothing here is built. The rules were checked against the owner's rulebooks on 2026-11-24 (§5, full table in [rules-check-2026-11-24.md](rules-check-2026-11-24.md)). The owner decisions are in §6. Classic stays Coming soon until Mission 1 ships ([ClassicModeSpec](../../../specs/features/ClassicModeSpec.md)).

**Box:** *BattleTech: A Game of Armored Combat* (AGOAC). Its eight 'Mechs come with Classic record sheets, and the Alpha Strike path already uses them, so a player who bought the box can play both paths with the same minis. The two paper maps in the box are the table.

## 1. Why ten, not five

Alpha Strike puts a 'Mech on one card, with three damage numbers and one armor track. Classic is a different game with much more to learn:

| Classic adds | Alpha Strike has instead |
|---|---|
| Hex map, facing, MP per hex, turning costs | Inches and a tape measure, no facing beyond the rear arc |
| A to-hit sum: gunnery + your movement + target's movement + range + terrain | Skill + range + TMM |
| One roll per weapon, each with its own range and damage | One attack per unit |
| Hit location table (front/side/rear), armor and structure per location, damage moving inward | One armor and structure track |
| Heat from each weapon and movement, heat sinks, a 30-point heat scale | Heat 0–4 |
| Missile cluster hits table | Folded into the damage numbers |
| Crit slots per location (engine, gyro, actuators, ammo) | One crit table |
| Piloting skill rolls, falling | None |
| Punch, kick, charge, death from above | Punch and kick at Size damage |

Each mission adds one or two of these. Ten missions keep each step about as small as an Alpha Strike mission.

## 2. Principles

Same as the Alpha Strike path:
- **The app keeps the books until the mission that teaches them.** For example, Mission 2 teaches to-hit, and the app rolls locations and marks damage. Mission 3 hands the player the record sheet.
- **One new idea per mission, practised in a short game.** Each mission is 3–6 turns and about 20–40 minutes, except the finale.
- **Players move minis on the paper map.** As with inches in Alpha Strike, the app never tracks hex positions. It asks how far each 'Mech moved and how (walk, run, jump), and the to-hit numbers come from that.
- **Skip ahead and replay**, like the Alpha Strike path.
- **Gunnery 4, Piloting 5** for every MechWarrior, the book's default (AGOAC p. 5).

## 3. The missions

Forces are AGOAC 'Mechs. Sides should be checked for balance with Battle Value once the record-sheet data is in (O1). The proposals below are by feel.

### 1. First Steps: hexes and facing
- **Objective:** be first to stand a 'Mech in the far objective hex, facing the enemy edge.
- **Forces:** Locust vs Commando. No shooting.
- **Learn:** walk and run MP, 1 MP per hex in clear terrain, 1 MP per hexside turned, no running backwards, facing arcs.
- **App:** tracks MP left as the player taps moves, and shows the facing arcs as a diagram.
- **Turns:** 4.

### 2. Range Finder: the to-hit roll
- **Objective:** destroy the enemy 'Mech or deal more damage in 5 turns.
- **Forces:** Wolverine vs Shadow Hawk.
- **Learn:**
  - The to-hit sum: gunnery, attacker movement (stood, walked, ran, jumped), target movement modifier (by hexes moved), range bands (short, medium, long, minimum).
  - One roll per weapon.
- **App:** builds the to-hit sum, then rolls hit locations, missile clusters and crits itself and marks the damage. The player sees a simple damage bar.
- **Turns:** 5.

### 3. Paper Armor: hit locations and the record sheet
- **Objective:** destroy the Thunderbolt, or keep it alive, in 6 turns.
- **Forces:** Wolverine + Commando vs Thunderbolt. This is the first fight with two units against one.
- **Learn:**
  - The record sheet: 8 locations, armor then internal structure.
  - Hit location tables for front, side and rear.
  - Damage moving inward (arm → torso, side torso → centre torso).
  - A destroyed location; head and centre torso kills.
- **App:** shows the sheet. The player rolls locations, and the app checks the result and marks it.
- **Turns:** 6.

### 4. Running Hot: heat
- **Objective:** destroy the enemy 'Mech without shutting down.
- **Forces:** Awesome vs Thunderbolt. Both run hot.
- **Learn:**
  - Heat from each weapon and from movement.
  - Heat sinks.
  - Heat scale effects: MP loss, a to-hit penalty, shutdown rolls, ammo explosion rolls.
  - Choosing fewer shots to stay cool.
- **App:** a heat track with the next threshold shown before the player commits to firing.
- **Turns:** 5.

### 5. Broken Ground: terrain and line of sight
- **Objective:** hold the hill hex for 2 turns in a row.
- **Forces:** Wolverine + Shadow Hawk vs Thunderbolt + Commando.
- **Learn:**
  - Light and heavy woods: MP cost and to-hit modifier.
  - Elevation and partial cover (leg hits blocked).
  - Line of sight through woods.
- **App:** adds terrain to the to-hit sum, and a partial-cover note on leg hits.
- **Turns:** 6.

### 6. High Ground: jumping and piloting rolls
- **Objective:** get both jumpers behind the enemy line.
- **Forces:** Wolverine + Shadow Hawk (jump) vs Catapult + Locust.
- **Learn:**
  - Jump MP, with facing chosen freely.
  - Jumping's to-hit modifiers, for the jumper and for shots at it.
  - Piloting skill rolls: 20+ damage in a phase, leg and gyro damage, falling (damage and facing), standing up.
- **App:** prompts for a piloting roll whenever a trigger happens and builds its target number. A fall rolls its damage.
- **Turns:** 5.

### 7. Rain of Missiles: cluster hits and ammo
- **Objective:** destroy the Catapult, or keep it alive, in 6 turns.
- **Forces:** Catapult + Commando vs Shadow Hawk + Wolverine.
- **Learn:**
  - The cluster hits table.
  - LRMs in 5-point groups, SRMs one hit location per missile.
  - LRM minimum range.
  - Ammo bins and running dry.
- **App:** a cluster roll helper and ammo counters on the sheet.
- **Turns:** 6.
- **Indirect fire:** included only if the box rulebook has it (C10).

### 8. Through the Armor: critical hits
- **Objective:** knock out one enemy 'Mech with a critical hit (engine, gyro, ammo or cockpit), or win outright.
- **Forces:** BattleMaster + Locust vs Awesome + Commando.
- **Learn:**
  - Rolling for crits when structure takes damage.
  - Crit slots.
  - Engine hits and heat, gyro hits and piloting, actuators, ammo explosions, and CASE if present.
- **App:** a slot picker for each location. It applies each effect to to-hit, heat or piloting.
- **Turns:** 6.

### 9. Close Quarters: physical attacks
- **Objective:** destroy an enemy 'Mech with a physical attack.
- **Forces:** BattleMaster + Commando vs Thunderbolt + Locust.
- **Learn:**
  - Punch, kick and push (C12).
  - Charge and death from above, with damage to the attacker and piloting rolls.
  - Physical attacks happen after weapon fire, and arms that fired can't punch.
- **App:** a physical-attack picker with damage worked out from tonnage, and the attacker's risk shown.
- **Turns:** 5.

### 10. Final Exam: the book's own test
- **Source:** AGOAC Scenario 1, pp. 45–46. See [book-scenarios.md](../book-scenarios.md#1-final-exam-pp-4546).
- **Objective:** cripple or destroy every enemy 'Mech first.
  - **Crippled** means a leg destroyed, every weapon destroyed, the gyro destroyed, or two engine crits.
  - Leaving the map counts as destroyed.
- **Forces:** identical lances, everyone P5/G4: CPLT-C1 Catapult, LCT-1V Locust, COM-2D Commando, SHD-2H Shadow Hawk on each side.
  - Mirrored sides need no BV balancing.
  - The second copy of each 'Mech is a stand-in. The app suggests one, such as the Thunderbolt for the second Catapult.
- **Map:** Desert #2 and Grassland #2.
- **Learn:** everything together at lance scale, plus the crippled rule. The app turns off every coach note, keeping only lookups.
- **Turns:** no limit in the book. The app suggests stopping at 10 and scoring by damage if time runs out (to confirm at the table).
- **Changed from the draft:** this replaces "Full Lances". Forced withdrawal isn't in the A Game of Armored Combat book (C14), and the book's own exam fits the path better.

### After the trophy: From the book
Trial by Fire, then Divide and Conquer (AGOAC Scenarios 2–3), with the book's campaign link that brings Final Exam survivors in on turn 5. They teach what the path doesn't:
- starting damage;
- breakout wins;
- split forces;
- mixed skills;
- initiative penalties.

Details and the rules each needs are in [book-scenarios.md](../book-scenarios.md).

## 4. What the app needs, by milestone

Classic shares no rules code with Alpha Strike ([ClassicModeSpec § Architecture](../../../specs/features/ClassicModeSpec.md)). The shell it reuses: the mission path, the mission sheet, the phase dock, the battle log, saves, the collection, and onboarding.

| Milestone | Missions | Engine (`Domain/Engines/ClassicTW/`) | Screens |
|---|---|---|---|
| C0 | — | Record-sheet model (locations, armor/IS, weapons, heat sinks, crit slots, ammo), data for the 8 AGOAC 'Mechs, Classic phase loop | Sheet viewer |
| C1 | 1–3 | MP and facing, to-hit sum, range bands, hit location tables, damage moving inward | Move step, to-hit builder, sheet damage |
| C2 | 4–6 | Heat scale, terrain modifiers, partial cover, jumping, piloting rolls, falls | Heat track, piloting roll prompt |
| C3 | 7–9 | Cluster table, ammo, crit determination and effects, physical attacks | Cluster helper, crit slot picker, physical picker |
| C4 | 10 | Crippled rule and exit-the-map losses, 4v4 pacing | Finale polish |

This replaces the spec's "tools before guided" order: each tool is built when the mission that teaches it needs it.

## 5. Rules check (done 2026-11-24)

Checked against the A Game of Armored Combat rulebook (printed page = PDF page − 2), the Quick-Start Rules and the Essentials booklet. The full table with pages is [rules-check-2026-11-24.md](rules-check-2026-11-24.md).

**What the quick-start books cover:** only Missions 1–3. They have three phases: Initiative, Movement and Weapon Attack. They have no Piloting, heat, criticals, physical attacks, falls, water, elevation, side or rear arcs, minimum range or internal structure. They have one hit location table and one target per turn. Missions 4–10 rely on the A Game of Armored Combat rulebook, so each of those missions should say so.

**How the draft held up:**

| Draft assumption | Result |
|---|---|
| Gunnery 4 / Piloting 5 | Confirmed, AGOAC p. 5 |
| Turning costs 1 MP per hexside | Confirmed in all three books |
| Range +0 / +2 / +4 | Confirmed. AGOAC adds a minimum-range penalty of minimum − range + 1 (p. 18) |
| Attacker +1 walk / +2 run / +3 jump | Confirmed. AGOAC adds +2 for firing while prone |
| Push, charge, death from above | In AGOAC only (pp. 25–29). Push does no damage. A death from above also takes the +3 jump modifier |
| Indirect LRM fire | In AGOAC only (p. 21): needs a spotter, +1, and +1 more if the spotter fired too. Mission 7 can include it |
| Forced withdrawal | **Not in any of the books.** It's replaced by the book's crippled rule; see Mission 10 |
| CASE | Not covered in these books. Mission 8 leaves it out, since none of the eight 'Mechs needs it |

## 6. Owner decisions (answered 2026-11-24)

| # | Decision | Answer |
|---|---|---|
| O1 | Where record-sheet numbers come from | From the record sheets in the rulebooks and box downloads at battletech.com/downloads, typed into a bundled JSON. The owner's copies are in `ongoing/` and are never committed (`.gitignore`). **Still needed:** none of the files in `ongoing/` has sheets for the eight A Game of Armored Combat 'Mechs. They're in the box's 15-sheet record sheet booklet, which the book says can be downloaded from bg.battletech.com. That PDF, or photos, goes in `ongoing/` before C0 |
| O2 | Reference rulebook | The owner has the printed *A Game of Armored Combat* rulebook, so every rule cites its page (from `ongoing/cat3500d…rulebook.pdf`). Each rule also notes whether the free **Quick-Start Rules** (battletech.com/downloads) cover it, so a new player knows what's in the short book |
| O3 | Maps | The collection lists maps by name. A player is assumed to have only the maps from boxes they own, and every mission suggests one of those. Experienced players can pick any map, including ones typed in by hand. Later: a catalog of all known maps |
| O4 | Mission count | Ten, keeping Missions 1 and 2 separate |
| O5 | Stand-ins in Classic | Yes, the same pairs as Alpha Strike |
