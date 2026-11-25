# Rulebook scenarios: what's in the box books and how to adapt them

**Status:** reference, 2026-11-24. Read from the owner's copies in `ongoing/` (never committed). Everything here is a paraphrase. Forces, skills, maps and page numbers are facts from the books; story text is left out.

The books' scenarios are already close to the app's missions: a map or table, two forces, deployment, a win condition and a few special rules. This doc lists each one in that shape, the rules it exercises, and where it could go in the app.

| Book | Scenarios | Pages (printed) |
|---|---|---|
| *A Game of Armored Combat* rulebook (AGOAC), Classic | Final Exam, Trial by Fire, Divide and Conquer, plus additional variations | 45–48 |
| *Alpha Strike Box Set Quick-Start Rulebook*, 3rd printing (AS-QS) | Meet and Greet, Clash of Steel, plus six objective types for open play | 7–8, 26, 31 |
| *BattleTech Quick-Start Rules* (QSR), Classic | one training duel | 11 |
| *Essentials* quick-start booklet (ESS), Classic | a training duel and Breakthrough | 9–10 |

## Classic: A Game of Armored Combat

The book says to play these three in order, each bigger than the last. Players roll 2D6 for sides, and the winner picks attacker or defender. Two of a 'Mech uses its punch-out piece: in the app, that's a stand-in.

**Record sheets:** several variants aren't among the box's eight minis: GRF-1N/1S Griffin, CPLT-K2, TDR-5SE, COM-3A, LCT-1E and WVR-6R. They come from the box's 15-sheet record sheet booklet, which isn't in `ongoing/` yet (scope O1).

### 1. Final Exam (pp. 45–46)
- **Map:** Desert #2 and Grassland #2, long sides together.
- **Forces:** identical lances, everyone Piloting 5 / Gunnery 4:
  - Defender: CPLT-C1 Catapult (commander), LCT-1V Locust, COM-2D Commando, SHD-2H Shadow Hawk.
  - Attacker: the same four.
- **Deploy:** players alternate placing one 'Mech at a time, defender on the west edge, attacker on the east edge.
- **Win:** cripple or destroy every enemy 'Mech first.
  - **Crippled** means a leg destroyed, every weapon destroyed, the gyro destroyed, or two engine crits.
  - A 'Mech that leaves the map is destroyed.
- **Variations:**
  - A second roster: TDR-5SE, WVR-6R, LCT-1V, COM-3A vs TDR-5S, GRF-1N, LCT-1E, COM-2D.
  - Turn the maps around, or put their short sides together.
  - Add die-cut terrain.
- **Exercises:** the full rules at lance scale. Because the sides mirror each other, it's balanced without BV.

### 2. Trial by Fire (pp. 46–47)
- **Map:** Desert #2 and Grassland #3.
- **Forces:**
  - Defender: a lone BLR-1G BattleMaster (P5/G4). It starts damaged: 4 hits of 5 points each, rolled on the front table, with head hits re-rolled and no crits.
  - Attacker: WVR-6M Wolverine (P5/G5), LCT-1V Locust (P6/G5), COM-3A Commando (P6/G5).
- **Deploy:**
  - The attacker sets up first, on clear level-0 hexes within 6 hexes of the east edge, facing any way.
  - The defender then sets up within 3 hexes of the west edge.
- **Win:**
  - The defender wins by leaving off the east edge or destroying all three attackers.
  - The attacker wins by destroying the BattleMaster. The BattleMaster also loses if it leaves by any edge but the east.
- **Special rules:** the defender wins initiative on turn 1. An attacker that leaves the map is destroyed.
- **Variation (chase):** the attackers start off the map. The BattleMaster gets one free turn, and the attackers enter from the west on turn 2.
- **Exercises:**
  - starting with damage already on the sheet;
  - a breakout win instead of a destroy-them-all win;
  - one 'Mech against three;
  - weaker skills (Gunnery 5, Piloting 6).

### 3. Divide and Conquer (pp. 47–48)
- **Map:** Desert #3 and Grassland #3, with die-cut terrain placed as shown in the book.
- **Forces:**
  - Defender command lance: CPLT-K2 Catapult (P3/G2), TDR-5S Thunderbolt (P4/G3), SHD-2H Shadow Hawk (P5/G4).
  - Defender recon lance: LCT-1V Locust (P4/G4), COM-3A Commando (P5/G4), COM-2D Commando (P5/G4).
  - Attacker: AWS-8Q Awesome (P3/G3), TDR-5SE Thunderbolt (P5/G4), WVR-6M Wolverine (P4/G3), GRF-1N Griffin (P4/G3).
- **Deploy:**
  - The command lance sets up on the west edge, within 6 hexes of the north edge. The recon lance sets up on the east edge, within 6 hexes of the south edge.
  - The attacker then picks which lance to hit first and sets up in the hex row numbered 1510–1517 in the corner nearest it.
- **Win:** the same as Final Exam: cripple or destroy everything first, and leaving the map counts as destroyed.
- **Special rules:** the defender takes −2 on every initiative roll.
- **Variations:**
  - A smaller game: drop the defender's SHD-2H and LCT-1V and the attacker's TDR-5SE.
  - Three players: the two defender lances are split between two players, who roll off when they disagree.
- **Exercises:**
  - one side split across the map;
  - mixed skills on the same side;
  - an initiative penalty.

### Additional variations (p. 48), for any of the three
- **MechWarrior cards:** one per side, both of equal cost. A card replaces that 'Mech's skills, and the opponent improves a skill by the same amount.
- **Full Moon Night:**
  - +1 MP per hex.
  - +2 to weapon attacks (not physical attacks), reduced by 1 for every 20 heat on the target.
- **Strong Gale:** +2 to missile attacks, +1 to autocannon and machine-gun attacks, and +1 to piloting rolls.
- **Terrain placement:**
  - Both players place the same number of pieces, alternating.
  - Nothing within 2 hexes of a map edge.
  - At least 3 hexes between pieces.
- **Campaign:** link Scenarios 1 and 3. The winner of Scenario 1 brings its surviving 'Mechs, with their damage, into Scenario 3. They enter from the west edge on turn 5.

## Alpha Strike: the Alpha Strike Box Set

These use the Alpha Strike box's 13 'Mechs, not the A Game of Armored Combat 'Mechs the app's path uses. So they are the natural next missions for players who own the Alpha Strike box.

### Meet and Greet (p. 26, "play this first")
- **Forces:**
  - Defender, Northwind Highlanders: BJ-5 Blackjack (Skill 3), PXH-4M Phoenix Hawk (3), WSP-5A Wasp (4), LCT-7V Locust (4).
  - Attacker, Jade Falcon scouts: Nova T (Skill 2), Pouncer T (3).
- **Table:**
  - Each player picks four single trees. The attacker places first, and players alternate within 24″ of the centre.
  - Three of each player's trees form a woods triangle, within 4″ of each other.
  - No other terrain within 4″ of another piece.
- **Deploy:** at least 20″ from the centre toward your own edge. The defender places two 'Mechs for each one the attacker places.
- **Win:** cripple or destroy all enemy 'Mechs first.
- **Special rules:** Forced Withdrawal is in effect (p. 12).
- **Exercises:** Inner Sphere vs Clan, uneven numbers, mixed skills, and woods built from single trees.

### Clash of Steel (p. 31, "play this second")
- **Forces:**
  - Defender command lance: AS7-S4 Atlas, ARC-7C Archer, WHM-8R Warhammer, BJ-5 Blackjack.
  - Defender recon lance: TR5 Wraith, WSP-5A Wasp, PXH-4M Phoenix Hawk, LCT-7V Locust.
  - Every defender is Skill 3.
  - Attacker, a Jade Falcon Battle Star: Warhawk T (Skill 1), Timber Wolf T (2), Nova T (2), Pouncer T (2), Fire Moth G (2).
- **Table:**
  - Each player picks three trees, three small buildings and three large buildings.
  - Players place two pieces at a time, within 24″ of the centre.
  - Trees within 4″ of each other form woods.
- **Deploy:** at least 24″ from the centre. The attacker places one 'Mech, then the defender places two, alternating.
- **Win:** cripple or destroy all enemy 'Mechs first.
- **Special rules:**
  - 5 points of Battlefield Support each, chosen secretly.
  - Forced Withdrawal.
  - Formations: the Command and Recon Lances, and the Battle Star.
- **Exercises:** buildings, Battlefield Support (artillery and air strikes), formations, and 8 vs 5.

### Open play: six objectives (pp. 7–8)
For any game: 250 PV per side, and pick or roll one objective. Each objective's win threshold is in the table:

| Objective | How you score | Win at |
|---|---|---|
| Raid | Carry your tokens back to your home edge, 2 points each | 10 |
| Control the Field | Score a 'Mech's Size each End Phase it's within 12″ of the enemy edge | 12 |
| Destroy the Enemy | Score Size per enemy 'Mech destroyed or crippled. Clan 'Mechs count ×1.5 | 10, or 12 for the Clan player |
| Hold the Fort | Score 1 per guarded token each End Phase from turn 3 | 10 |
| Breakthrough | Score Size per 'Mech that leaves by the enemy edge | 10 |
| Find the Target | Scan buildings to find a target, then score 5 points per target destroyed | 10 |

## Classic: quick-start duels (QSR p. 11, ESS pp. 9–10)
- **QSR training duel:** on Desert #1, GRF-1N Griffin (within 3 hexes of the south edge) vs WVR-6R Wolverine (north edge). Gunnery 4. Destroy the enemy; leaving the map counts as destroyed.
- **ESS training duel:** on The Patchwork (The Reaches), ignoring the hardpacked gravel, CN9-A Centurion vs RFL-3N Rifleman.
- **ESS Breakthrough:** damaged defenders try to get off the south edge, scored with victory points.
  - Points: 2 for each attacker that exits, 1 for each defender destroyed, 3 for each attacker destroyed.
  - The roster as extracted seems to be missing a 'Mech. The text mentions "both attackers" but lists only one, so it needs checking against the printed booklet.

## How these fit the app

| Idea | Where | Why |
|---|---|---|
| **Final Exam becomes Classic Mission 10** | Classic path | It's the book's own final test, mirrored so no BV balancing is needed. It uses the book's crippled rule, which replaces the draft's forced withdrawal (that isn't in the A Game of Armored Combat book). The second copy of each 'Mech is a stand-in, which the app already suggests |
| **"From the book" stage after Classic Mission 10:** Trial by Fire, then Divide and Conquer, with the campaign link to Final Exam | Classic path, after the trophy | These follow the book's order. They add things the path doesn't teach: starting damage, breakout wins, split forces, mixed skills |
| **Alpha Strike stage 2: Meet and Greet, then Clash of Steel** | Alpha Strike path, after Mission 5, for Alpha Strike box owners | The book's own next steps. Each 'Mech has an exact mini in that box |
| **Skirmish with an objective** | Alpha Strike, after the path | The six objectives plus 250 PV give endless replay without writing more missions |
| **Planetary conditions** (Full Moon Night, Strong Gale) | Classic replay options | A toggle when replaying a cleared mission |

**New rules each one needs:**
- **Trial by Fire:** starting damage and exit-edge victory.
- **Divide and Conquer:** per-side initiative modifiers and per-'Mech skills (the path uses 4/5 for everyone).
- **Campaign link:** carrying damage over between games.
- **Meet and Greet:** Clan unit cards. The app has Forced Withdrawal already.
- **Clash of Steel:**
  - buildings (Move cost, capacity, collapse);
  - Battlefield Support;
  - formations.
- **Objectives:** tokens and victory-point scoring.

**Cards and sheets still needed:**
- Classic: the A Game of Armored Combat record sheet booklet.
- Alpha Strike: the Alpha Strike box's Clan and Inner Sphere cards. The Master Unit List has them; check the variant codes the book uses (LCT-7V, AS7-S4 and so on).
