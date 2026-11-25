# Classic mission path — scope (10 missions)

**Status:** draft for the owner to review, 2026-11-24. Nothing here is built. Rules are from general BattleTech knowledge and **not yet checked** against a rulebook: every rule line has a check in §5. Classic stays Coming soon until Mission 1 ships ([ClassicModeSpec](../../../specs/features/ClassicModeSpec.md)).

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
- **Gunnery 4, Piloting 5** for every MechWarrior, the usual starting skills (check C1).

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

### 10. Full Lances: the full game
- **Objective:** destroy or cripple the enemy lance in 10 turns.
- **Forces:** all eight. Awesome + Thunderbolt + Shadow Hawk + Commando vs BattleMaster + Catapult + Wolverine + Locust, the same sides as Alpha Strike Mission 5.
- **Learn:** everything together, plus initiative across four units and forced withdrawal if the box has it (C14).
- **App:** turns off every coach note, keeping only lookups.
- **Turns:** 10, about 2–3 hours.

## 4. What the app needs, by milestone

Classic shares no rules code with Alpha Strike ([ClassicModeSpec § Architecture](../../../specs/features/ClassicModeSpec.md)). The shell it reuses: the mission path, the mission sheet, the phase dock, the battle log, saves, the collection, and onboarding.

| Milestone | Missions | Engine (`Domain/Engines/ClassicTW/`) | Screens |
|---|---|---|---|
| C0 | — | Record-sheet model (locations, armor/IS, weapons, heat sinks, crit slots, ammo), data for the 8 AGOAC 'Mechs, Classic phase loop | Sheet viewer |
| C1 | 1–3 | MP and facing, to-hit sum, range bands, hit location tables, damage moving inward | Move step, to-hit builder, sheet damage |
| C2 | 4–6 | Heat scale, terrain modifiers, partial cover, jumping, piloting rolls, falls | Heat track, piloting roll prompt |
| C3 | 7–9 | Cluster table, ammo, crit determination and effects, physical attacks | Cluster helper, crit slot picker, physical picker |
| C4 | 10 | Victory and withdrawal, 4v4 pacing | Finale polish |

This replaces the spec's "tools before guided" order: each tool is built when the mission that teaches it needs it.

## 5. Rules to check against the AGOAC rulebook

Each needs the rule and a page number, as in the [Alpha Strike intake](../alpha-strike/mission-ladder-rules-intake.md).

| # | Question |
|---|---|
| C1 | Default Gunnery/Piloting for the box's MechWarriors (4/5?) |
| C2 | Turning cost, backward walking, running restrictions |
| C3 | Attacker movement modifiers (0/+1/+2/+3 jump) and the target movement table |
| C4 | Range modifiers (+0/+2/+4) and minimum-range penalty |
| C5 | Hit location tables (front, left, right, rear) and which attack directions use each |
| C6 | Damage transfer order; what destroying a side torso takes with it |
| C7 | Heat scale thresholds the box uses (movement, to-hit, shutdown, ammo) and heat from movement |
| C8 | Woods, water and elevation costs and modifiers; partial cover |
| C9 | Piloting roll triggers and modifiers; fall damage and facing |
| C10 | Cluster hits table; whether indirect LRM fire is in the box rules |
| C11 | Crit determination roll, slot rolls, and each component's effect |
| C12 | Physical attacks in the box: punch, kick, push, charge, DFA, and their damage formulas |
| C13 | Initiative and unequal-unit movement order |
| C14 | Forced withdrawal or another end condition in the box rules |

## 6. Owner decisions

| # | Decision | Recommendation |
|---|---|---|
| O1 | Where record-sheet numbers come from. The spec prefers "user-entered", but no scans | Type the eight AGOAC 'Mechs' numbers from your record sheet booklet into a bundled JSON, as with the Alpha Strike cards from the MUL. Check each against the MUL's Classic page where it has one |
| O2 | Reference rulebook | The AGOAC rulebook. Drop a PDF or photos into `ongoing/` (not committed) |
| O3 | Which box map each mission uses | Choose at the table during the Mission 1–3 playtest |
| O4 | Ten missions as above, or merge 1 and 2 | Keep ten. Mission 1 is short, and movement is where most new players get stuck |
| O5 | Does Classic need the same box-ownership stand-ins? | Yes, the same pairs. In Classic too the record sheet sets everything and the mini only marks the hex |
