# BattleTech Classic rules check (mission-path scope doc)

Read-only research. All rules are paraphrased. Page references:

- **AGOAC** = *A Game of Armored Combat* rulebook. Printed page = PDF index − 2. This was checked against the table of contents and page footers.
- **QSR** = *Quick-Start Rules*. Printed page = PDF index − 1.
- **ESS** = the *Essentials* box QSR booklet. Printed page = PDF index.
- **RS-AS** = Alpha Strike box set record sheets.
- **RS-FP** = Battlefield Support Force Pack record sheets.

Overall, QSR and ESS have the same rules text. ESS is the 2023 reprint, with a Centurion/Rifleman example, a smaller cluster table and a different map. Both books leave out everything after the Weapon Attack Phase: Piloting, heat, criticals, physical attacks, falls, water, elevation and multiple arcs. ESS p. 11 ("Beyond the Quick-Start Rules") says outright that these are AGOAC-only.

## C1 Skills

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C1 | The average Inner Sphere MechWarrior has **Gunnery 4, Piloting 5**. These are the defaults unless a scenario says otherwise. Lower is better. Gunnery is the base to-hit number for weapons. Piloting is the base for PSRs and for physical attacks. | AGOAC p. 5 | QSR p. 6: the base to-hit is Gunnery **4 for Inner Sphere and 3 for Clan**, and it is printed on the sheet. QSR has **no Piloting**: card Piloting values do nothing until AGOAC (QSR p. 12, ESS p. 10). ESS p. 5 uses Gunnery 4. Scenarios vary skills. AGOAC S2 rookies are G5/P6, and S3 goes as low as G2/P3. ESS Breakthrough uses G5. |

## C2 Movement

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C2a | **Modes:** Choose exactly one mode per 'Mech: stand still, walk, run or jump. Unspent MP is lost, and the mode stays fixed however few MP are spent. Standing still allows no MP at all, not even to turn. | AGOAC p. 8–9; QSR p. 2; ESS p. 2–3 | Same. |
| C2b | **MP per hex:** Entering any hex costs 1 MP plus the terrain cost. See C8. | AGOAC p. 9–10 (Movement Costs Table); QSR p. 3; ESS p. 4 | Same for woods. QSR/ESS have no other terrain. |
| C2c | **Facing:** Turning costs **1 MP per hexside**, so a 180° turn costs 3 MP. A 'Mech can move only into the hex directly ahead or directly behind. If a 'Mech is not clearly aligned at the end of movement, the opponent realigns it to one of the two nearest hexsides. | AGOAC p. 9; QSR p. 2–3; ESS p. 3 | Same. The realign clause is AGOAC-only. |
| C2d | **Backward:** Only allowed with Walking MP. A walking 'Mech may go forward and backward in the same turn. A 'Mech moving backward may not change levels. | AGOAC p. 9; QSR p. 2; ESS p. 3 | Same. The level clause is AGOAC-only. |
| C2e | **Running:** Running MP = Walking × 1.5, rounded up, and is recalculated whenever Walking MP drops. **No backward movement while running.** A running 'Mech cannot enter Depth 1+ water, but may turn inside water or leave it. Running with a damaged gyro or hip forces a PSR. A one-legged 'Mech can only walk. | AGOAC p. 8, 12 | QSR p. 2 and ESS p. 3 have only the no-backward rule. |
| C2f | **Jumping:** Moves 1 hex per Jumping MP, ignoring terrain and 'Mechs in the hexes passed over. Jumping into your own hex costs 1 MP. The jump must follow a shortest path. The 'Mech can face any direction on landing. It must start the turn standing, and a prone 'Mech cannot jump. It cannot land in an occupied hex, except as a DFA. It cannot enter a hex higher than Jumping MP plus its starting level. It cannot jump into Depth 1+ water; ending the jump over water forces a PSR. Each jump-jet crit costs 1 Jumping MP. Heat-based MP loss does not reduce Jumping MP. | AGOAC p. 8, 11–12, 38 | QSR p. 4 and ESS p. 3 cover 1 hex/MP, ignoring terrain, the own-hex jump for 1 MP, no landing on a 'Mech, and free facing. Nothing else. |
| C2g | **Other movement:** Minimum Movement lets a 'Mech that runs, with at least 1 MP, always enter the hex directly ahead; this must be its only MP spent. Dropping prone costs 1 MP. Standing up costs 2 MP per attempt. A level change costs 1 MP per level, with at most 2 levels per hex. 'Mechs may pass through friendly 'Mechs but never enemies, except in a charge. Two 'Mechs may never end in the same hex. Entering a partial hex or going off the map counts as destroyed. | AGOAC p. 9–12 | QSR p. 4 and ESS p. 4 have the stacking rule only. |

## C3 To-hit movement modifiers

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C3a | **Attacker modifier, by mode not distance:** stood +0, **walked +1, ran +2, jumped +3**. Firing while prone adds +2 more. | AGOAC p. 16, 19 | QSR p. 6, 8 and ESS p. 7 give the same values but have no prone modifier. |
| C3b | **Target movement modifier (TMM), counted in hexes moved, not MP:** 0–2 hexes 0; 3–4 +1; 5–6 +2; 7–9 +3; 10–17 +4; 18–24 +5; 25+ +6. A jump adds a further **+1**. If the target moved both ways, count only from its last reversal. Prone target: −2 from an adjacent hex, +1 from anywhere else. Immobile target: −4. | AGOAC p. 16, 19 | QSR p. 8 and ESS p. 7 **stop at "10+ = +4"**. They have no prone or immobile modifiers. The jump +1 and reversal rule are the same. |
| C3c | **Other attack modifiers (AGOAC only):** Secondary target +1 in the forward arc, +2 in a side or rear arc. Partial cover +1. Heat (C7). Damage: sensors +2; shoulder +4 to weapons in that arm; upper or lower arm actuator +1 each. Pulse lasers get −2, but that rule is **QSR-only**, not AGOAC. | AGOAC p. 17, 19–20; QSR p. 7 | **QSR/ESS allow only one target per turn** and have only a forward arc (QSR p. 11; ESS p. 5, 9). |

## C4 Range

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C4a | **Range bands:** Count the shortest hex path, including the target hex. **Short +0, medium +2, long +4.** Nothing beyond long range can be hit. Level differences are ignored. | AGOAC p. 18, 20; QSR p. 7–8; ESS p. 7 | Same. |
| C4b | **Minimum range penalty:** For targets inside a weapon's minimum range, the modifier is **min − range + 1**. Example from the book: a PPC (min 3) gets +1 at 3 hexes, +2 at 2 and +3 at 1. Minimums in AGOAC: PPC 3, AC/2 4, AC/5 3, all LRMs 6. | AGOAC p. 18–19, 55 | **Absent from QSR and ESS.** The simplified sheets have no Min column. |
| C4c | **To-hit limits:** A modified target number above 12 is an automatic miss. The attacker may cancel the shot but cannot pick a new target. A target number of 2 or less is an automatic hit. | AGOAC p. 15; QSR p. 6; ESS p. 5 | Same. |

## C5 Hit location

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C5a | **Attack direction:** Draw a line from attacker hex center to target hex center. The hexside it crosses on the target, judged by the target's feet (torso twist is ignored), gives the Front, Left, Right or Rear zone. On an exact corner, the target chooses. A prone target uses the direction its head points. | AGOAC p. 22 | **QSR and ESS have one table and no attack direction.** ESS p. 11 confirms that all hits are resolved the same way and there is no rear armor. |
| C5b | **2D6 Hit Location Table (AGOAC):** see the table below. Rear hits use the Front/Rear column but are applied to the **rear torso armor**. | AGOAC p. 23 | QSR p. 6, 15 and ESS p. 12 use only the Front column, with **no crit on a 2**. |
| C5c | **Through-armor critical (TAC):** A hit-location roll of 2 that deals at least 1 damage also triggers a crit check on the torso it hit. This is in addition to any check for internal-structure damage, and it applies even if the location still has armor. A TAC on a destroyed side torso moves to the CT. | AGOAC p. 22, 31 | Absent. |
| C5d | **Partial cover:** If the hit roll gives a leg, the shot hits the cover and does nothing. | AGOAC p. 17, 22 | Absent. |
| C5e | **Kick table (1D6):** Front/Rear: 1–3 RL, 4–6 LL. Left side: always LL. Right side: always RL. | AGOAC p. 28 | Absent. |
| C5f | **Punch table (1D6):** Front/Rear: LA, LT, CT, RT, RA, Head. Left side: LT, LT, CT, LA, LA, Head. Right side: RT, RT, CT, RA, RA, Head. | AGOAC p. 28 | Absent. |

**AGOAC Hit Location Table (2D6):**

| 2D6 | Left Side | Front/Rear | Right Side |
|---|---|---|---|
| 2* | LT (crit chance) | CT (crit chance) | RT (crit chance) |
| 3 | LL | RA | RL |
| 4 | LA | RA | RA |
| 5 | LA | RL | RA |
| 6 | LL | RT | RL |
| 7 | LT | CT | RT |
| 8 | CT | LT | CT |
| 9 | RT | LL | LT |
| 10 | RA | LA | LA |
| 11 | RL | LA | LL |
| 12 | Head | Head | Head |

## C6 Damage transfer and destruction

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C6a | **Damage order and transfer:** Damage goes to armor, then internal structure. Each point of internal-structure damage that does not destroy the location triggers a crit check. Once a location is destroyed, extra and later damage moves inward: arm or leg → same-side torso → CT. Damage to the head or CT never transfers. Transferred rear damage goes to the rear armor of the receiving torso. Ammo-explosion damage skips armor and goes straight to internal structure. Each hit, including each missile, is fully resolved, crits included, before the next. | AGOAC p. 30, 34–35 | QSR p. 9–10 and ESS p. 8 use the same transfer arrows, but there is **no internal structure**. A location is destroyed when its armor circles run out. |
| C6b | **Side torso loss:** Destroying LT or RT blows off the arm on that side. Damage aimed at that arm or torso later in the phase goes to the CT. The leg on that side is unaffected. | AGOAC p. 34 | QSR p. 10 and ESS p. 8 are the same, but the trigger is "all armor gone". |
| C6c | **Leg loss:** A standing 'Mech falls and stops moving. All PSRs get +5, replacing other leg modifiers. It may try to stand once per turn; this always counts as running. If it stands, it has Walking 1 and cannot run, and each landing from a jump needs a +5 PSR. With both legs lost it falls and has 0 MP. | AGOAC p. 34 | QSR p. 10: a 'Mech with any leg gone **cannot move or turn** for the rest of the game but can still fire. |
| C6d | **'Mech destroyed:** The head is destroyed. The **CT is destroyed**. The cockpit takes a crit. The head is blown off (a 12 on the head crit roll). **Three engine crits**, counting engine slots in the side torsos. The pilot takes **6 wounds**. The pilot dies if the head or cockpit is destroyed or an ammo explosion destroys the CT. Destroyed 'Mechs are removed at the end of the phase. A destroyed gyro, both legs lost or every weapon gone do **not** destroy the 'Mech. | AGOAC p. 32–35 | QSR p. 10 and ESS p. 8: only the **head or CT** being destroyed kills the 'Mech. |
| C6e | **Damage timing:** All declared attacks in a phase are made. Damage is recorded as hits are rolled but takes effect only at the end of the phase. Displacement and falls take effect immediately. | AGOAC p. 6, 30; QSR p. 1; ESS p. 2 | Same. QSR has no displacement. |

## C7 Heat

All heat rules are **AGOAC-only**. QSR and ESS have no heat. The QSR Fire Moth sample sheet prints a heat scale, but no rule uses it.

| # | Rule | Source |
|---|---|---|
| C7a | **Heat from movement:** Walking +1 per turn. Running +2 per turn. Jumping +1 per hex, minimum 3. Each attempt to stand +1. Weapons add the heat listed on the sheet. Engine crits add +5 per turn after the first and +10 total after the second. | AGOAC p. 8, 37 |
| C7b | **Dissipation:** Each working heat sink removes 1 heat per turn. Submerged heat sinks remove double, up to +6 extra. In Depth 1 only the leg heat sinks count as submerged. Heat cannot go below 0. Heat above 30 goes into the Overflow box. Heat is settled in the Heat Phase, after physical attacks. | AGOAC p. 7, 37 |
| C7c | **MP loss** (not cumulative; uses the current threshold only): −1 at 5, −2 at 10, −3 at 15, −4 at 20, −5 at 25. Running MP is recalculated. Jumping MP is unaffected. | AGOAC p. 38 |
| C7d | **To-hit, weapons only:** +1 at 8, +2 at 13, +3 at 17, +4 at 24. | AGOAC p. 20, 38 |
| C7e | **Shutdown:** Roll 2D6 once against the highest threshold reached. 14 needs 4+, 18 needs 6+, 22 needs 8+, 26 needs 10+; at 30 shutdown is automatic. A shut-down 'Mech makes an immediate PSR at +3 and becomes immobile (−4 to hit it, aimed shots allowed). The player tries to restart in later Heat Phases against the same threshold. It restarts automatically below 14. Voluntary shutdown happens in the End Phase. | AGOAC p. 38 |
| C7f | **Ammo explosion:** At 19 or more heat, avoid on 19 = 4+, 23 = 6+, 28 = 8+. If it fails, the bin with the highest damage per shot explodes, ties going to the bin with the most shots. | AGOAC p. 38–39 |
| C7g | **Pilot damage:** Happens **only after a life-support crit**: 1 wound per Heat Phase at heat 15–25, 2 wounds at 26+. Heat never hurts the pilot directly otherwise. | AGOAC p. 33, 39, 44 |

## C8 Terrain

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C8a | **Woods:** Light woods cost +1 MP and heavy woods +2 MP. A target in light woods is +1 to hit, heavy woods +2. Each intervening light woods hex adds +1 and each heavy hex +2. Three or more woods points along the line of fire block LOS (light = 1 point, heavy = 2), so intervening woods add at most +2. The target's own hex never blocks. Woods rise 2 levels and **give no partial cover**. | AGOAC p. 10, 13–14, 17; QSR p. 3–4, 7; ESS p. 4, 6 | Same, except QSR/ESS have no woods height. |
| C8b | **Water:** Depth 1 costs +1 MP and Depth 2+ costs +3 MP, plus the level change. Entering any depth forces a PSR: Depth 1 at −1, Depth 2 at 0, Depth 3+ at +1. A running 'Mech cannot enter. Water gives **no to-hit modifier**. A standing 'Mech in Depth 1 has **partial cover**, even against attackers above it. Standing in Depth 2+, or prone in Depth 1+, means fully submerged: LOS is blocked and the 'Mech can only fight other submerged units. Underwater physical attacks do half damage. Falls in water do half damage. Leg jump jets do not work in Depth 1. Intervening water blocks LOS. | AGOAC p. 10, 12, 14, 17, 25, 43 | **Absent from QSR/ESS.** |
| C8c | **Elevation:** +1 MP per level, at most 2 levels per hex. A standing 'Mech is 2 levels tall and a prone one 1. Intervening hills block LOS, using the intervening rules on p. 13. Range ignores levels. There is **no to-hit modifier for height** other than partial cover. Being forced down 2 or more levels means an automatic fall. | AGOAC p. 9, 13–14, 18 | **Absent from QSR/ESS.** |
| C8d | **Partial cover:** A standing target qualifies when it is adjacent to a hex 1 level higher on the LOS, such as a hill or a building but not a bridge. It gives +1 to hit, and **leg hits strike the cover and are ignored**. An attacker at a higher LOS level cancels it, except for water. Prone 'Mechs cannot have partial cover; behind a Level 1 hex the LOS is simply blocked. Indirect fire ignores cover. Leg weapons cannot fire through the firer's own cover. | AGOAC p. 14–15, 17, 21 | **Absent from QSR/ESS.** |
| C8e | **Other terrain:** Rough +1 MP. Rubble +1 MP with a PSR at +0. Paved, bridge and road +0. | AGOAC p. 10 | Absent. |

## C9 Piloting Skill Rolls (PSRs), falls and standing

All **AGOAC-only**. QSR and ESS have no PSRs, falls or prone 'Mechs.

| # | Rule | Source |
|---|---|---|
| C9a | **Mechanics:** Roll 2D6 against Piloting plus all modifiers. Failing means a fall. If several PSRs are due at once, roll them one by one with all modifiers stacked; the first failure cancels the rest. Immobile 'Mechs, or 'Mechs with an unconscious pilot, fail automatically while standing. A prone 'Mech skips fall PSRs except when standing up. **Timing:** movement PSRs are rolled immediately. PSRs caused by attacks are rolled at the end of that attack phase. | AGOAC p. 40 |
| C9b | **Triggers and modifiers:** see the trigger list below. | AGOAC p. 41, 26–29, 32–34, 38 |
| C9c | **Falling damage:** ceil(tons/10) × (levels fallen + 1), split into 5-point groups. Most falls are 0-level falls. The hit side comes from the **Facing After Fall Table (1D6)**: 1 same facing, Front; 2 one hexside right, Right; 3 two hexsides right, Right; 4 reversed, Rear; 5 two hexsides left, Left; 6 one hexside left, Left. The 'Mech ends prone and face down. It falls in the hex it was entering, or in its own hex for falls caused by combat. | AGOAC p. 42–43 |
| C9d | **Pilot damage from a fall:** A second PSR uses the same modifiers plus +1 per level above 1. Failing it costs 1 wound. The wound is automatic if the 'Mech was immobile or the target number is above 12. | AGOAC p. 43–44 |
| C9e | **Standing up:** Costs 2 MP per attempt, with a PSR at +0 plus any damage modifiers and +1 heat. A prone 'Mech declares walk or run first and may not jump. On success it picks any facing for free and may keep moving. On failure it falls again, using its prone facing as the start for the facing roll. It cannot stand with both legs gone, or with one leg and both arms gone. | AGOAC p. 12 |
| C9f | **Wounds and consciousness:** A pilot takes 1 wound per head hit, 1 per failed fall roll, 2 per ammo explosion, and heat wounds after a life-support crit. Each wound forces a consciousness roll; the numbers on the sheet are 3/5/7/10/11 for wounds 1–5. Six wounds kill the pilot. An unconscious pilot makes the 'Mech immobile. It can wake in the End Phase. | AGOAC p. 7, 44 |

**PSR triggers and modifiers (C9b):**

- **Damage:** 20 or more damage in one phase +1. Leg or foot actuator lost +1. Hip +2. Gyro hit +3. Gyro destroyed means an automatic fall. Leg destroyed means an automatic fall. Reactor shutdown +3.
- **Physical attacks:** Being kicked +0. Being pushed +0. A successful charge +2 for both 'Mechs. A successful DFA: target +2, attacker +4. A missed kick: the kicker rolls at +0. A missed DFA is an automatic fall.
- **Terrain:** Entering water: Depth 1 −1, Depth 2 0, Depth 3+ +1. Entering rubble +0. Standing up +0.
- **Running or jumping with damage:** Running with a damaged gyro or hip forces a roll. Jumping with a damaged gyro, leg, foot or hip forces a roll on landing.
- **Preexisting damage:** +1 per leg or foot actuator, +2 per hip, +3 per gyro hit, +5 for a lost leg.
- **Other:** An unintentional charge +3.

## C10 Missiles and the Cluster Hits Table

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C10a | **Cluster Hits Table:** Rows are the 2D6 roll (2–12). **Columns are launcher sizes 2, 4, 5, 6, 10, 15, 20.** Values are listed below. | AGOAC p. 23–24; QSR p. 8, 15 | QSR has the same columns; its "2" column is also used for Ultra AC double-fire. **ESS has only columns 2, 5, 6, 10, 15** (ESS p. 7, 12). |
| C10b | **SRMs:** 2 damage per missile. Each missile that hits gets its own hit-location roll. | AGOAC p. 24; QSR p. 9; ESS p. 7 | Same. |
| C10c | **LRMs:** 1 damage per missile. Hits are grouped into **5-point clusters**, with the leftover as one smaller cluster. Each cluster gets one hit-location roll. Example: 12 hits = 5 + 5 + 2. | AGOAC p. 24; QSR p. 9; ESS p. 7 | Same. QSR also covers Streak missiles (all hit on a successful roll; no ammo used on a miss) and Ultra AC, marked as **not in AGOAC**. |
| C10d | **Indirect LRM fire:** **Present in AGOAC.** It is allowed only when the attacker has no LOS. A friendly spotter with LOS is needed; it must not have charged or DFA'd that turn, and it spots one target per turn. Modifiers: attacker and target movement, plus the spotter's movement. Terrain and cover are taken from the spotter's LOS. Add **+1 for indirect fire**. Range and minimum range are from the attacker. If the spotter also fired, its own attacks get +1 and the indirect attack gets +1 more. Aimed shots are not allowed. Indirect hits ignore partial cover, except water. | AGOAC p. 13, 15, 20–21 | **Absent from QSR/ESS.** |

**Cluster Hits Table values** (QSR p. 15, AGOAC p. 23):

| 2D6 | 2 | 4 | 5 | 6 | 10 | 15 | 20 |
|---|---|---|---|---|---|---|---|
| 2 | 1 | 1 | 1 | 2 | 3 | 5 | 6 |
| 3 | 1 | 2 | 2 | 2 | 3 | 5 | 6 |
| 4 | 1 | 2 | 2 | 3 | 4 | 6 | 9 |
| 5 | 1 | 2 | 3 | 3 | 6 | 9 | 12 |
| 6 | 1 | 2 | 3 | 4 | 6 | 9 | 12 |
| 7 | 1 | 3 | 3 | 4 | 6 | 9 | 12 |
| 8 | 2 | 3 | 3 | 4 | 6 | 9 | 12 |
| 9 | 2 | 3 | 4 | 5 | 8 | 12 | 16 |
| 10 | 2 | 3 | 4 | 5 | 8 | 12 | 16 |
| 11 | 2 | 4 | 5 | 6 | 10 | 15 | 20 |
| 12 | 2 | 4 | 5 | 6 | 10 | 15 | 20 |

## C11 Critical hits

All **AGOAC-only**. QSR and ESS have no criticals, although the QSR Fire Moth sample sheet prints a crit table.

| # | Rule | Source |
|---|---|---|
| C11a | **Determining crits:** Roll 2D6 when a location takes internal-structure damage but is not destroyed, or on a TAC. **2–7: no crit. 8–9: 1 crit. 10–11: 2 crits. 12: head or limb blown off, or 3 crits if the location is a torso.** A destroyed location only checks for crits if it holds ammo, and only crits on ammo slots count. | AGOAC p. 30–31 |
| C11b | **Picking the slot:** Head and legs (6 slots): roll 1D6. Arms and torsos (12 slots): roll 1D6 for the block (1–3 upper six, 4–6 lower six), then 1D6 for the slot. If the slot is empty ("Roll Again") or already hit, reroll both dice. If one block is all inapplicable, roll 1D6 only. If every slot was hit in earlier phases, the crit moves to the next inward location; head and CT crits never transfer. Excess crits in the same phase are lost. One crit disables a multi-slot item; its other slots can still absorb hits. | AGOAC p. 31–32 |
| C11c | **Engine:** 3 shielding points. Hit 1 adds +5 heat per turn, hit 2 brings it to +10 per turn, and **hit 3 destroys the 'Mech**. | AGOAC p. 32 |
| C11d | **Gyro:** Hit 1 gives +3 to all PSRs, forces an immediate PSR, and forces a PSR whenever the 'Mech runs or jumps. Hit 2 destroys the gyro: the 'Mech falls automatically and can never stand. The fall's pilot roll is at +6. It fires as if prone, may turn 1 hexside per turn, and is not immobile. | AGOAC p. 32 |
| C11e | **Arm actuators:** Shoulder: +4 to that arm's weapons, which overrides the other arm-actuator modifiers; no punch, club or physical weapon with that arm; +2 to push. Upper or lower arm: +1 to that arm's weapons, +2 to punch and physical-weapon attacks, punch damage halved each, +2 to club. Hand: +1 to punch; no club or physical weapon with that arm. 'Mechs built without lower arm or hand actuators skip the weapon penalty but keep the physical-attack penalties. | AGOAC p. 32–33 |
| C11f | **Leg actuators:** Hip: Walking MP halved, rounded down; +2 PSR, replacing earlier crit modifiers on that leg; a PSR on every run or jump; no kicks. A second hip crit means 0 MP. Upper or lower leg: −1 Walking MP, +1 PSR, a PSR on every jump, +2 to kick, kick damage halved each. Foot: −1 Walking MP, +1 PSR, a PSR on every jump, +1 to kick. Every leg crit forces a PSR at the end of the phase. | AGOAC p. 32–34 |
| C11g | **Head components:** Sensors: +2 to weapon attacks after the first hit; after the second hit the 'Mech cannot fire weapons. Physical attacks are unaffected. **Cockpit:** the pilot dies and the 'Mech is destroyed. Life support: heat wounds (C7g), and 1 wound per End Phase while submerged. | AGOAC p. 32–33 |
| C11h | **Ammo explosion:** A crit on an ammo slot explodes that slot. Damage = shots left × damage per shot (missiles × damage per missile). It goes straight to internal structure and moves inward skipping armor. It forces a crit check, and the pilot takes **2 wounds**. An empty bin absorbs the hit with no effect. Ammo in a limb blown off by a crit does not explode. | AGOAC p. 32, 35 |
| C11i | **Other components:** A heat sink crit removes 1 point of dissipation. A jump jet crit costs 1 Jumping MP. A weapon crit makes it useless. A limb blown off by a crit leaves a club in the hex. | AGOAC p. 32–34 |
| C11j | **CASE:** **Not covered in AGOAC, QSR or ESS.** It appears only on record sheets: the RS-AS sheets and the QSR Fire Moth sample. Its rules are in the BattleMech Manual. | — |

## C12 Physical attacks

All **AGOAC-only**. QSR and ESS have no physical attacks; ESS p. 11 lists them as AGOAC content.

| # | Rule | Source |
|---|---|---|
| C12a | **General:** Resolved in their own phase after weapon fire. The base to-hit is **Piloting** plus all normal modifiers **except heat and sensors**. The target must be adjacent and in the correct arc. One type of physical attack per 'Mech per turn. A 'Mech can be the target of only one charge, push or DFA per turn. Prone 'Mechs cannot make physical attacks. The underlying hexes may differ by at most 1 level; the Different Levels table switches between the Punch and Kick tables. | AGOAC p. 24–25 |
| C12b | **Punch:** +0. Not allowed with an arm that **fired weapons this turn**. Each arm rolls separately. The target must be in the forward arc or that arm's side arc. Damage is **ceil(tons/10)** per arm, halved for each damaged or missing upper or lower arm actuator (rounded down, minimum 1). Location uses the 1D6 Punch table. Two punches may go at two targets with no secondary-target penalty. | AGOAC p. 28 |
| C12c | **Kick:** −2. Not allowed with a leg that fired weapons, and both hips must be intact. The target must be in the forward arc by the feet. Damage is **tons/5**, halved per damaged leg actuator. Location uses the 1D6 Kick table. The target always makes a PSR; a kicker who misses makes a PSR. | AGOAC p. 28 |
| C12d | **Push:** −1. Only against a standing target in the hex **directly ahead** at the same level. No arm weapons may fire that turn. **No damage.** The target is moved one hex away and must make a PSR. The attacker moves into the vacated hex. +2 per damaged shoulder. If both push each other and both hit, neither moves and both make PSRs. | AGOAC p. 29 |
| C12e | **Charge:** +0 plus (attacker Piloting − target Piloting). Declared in the Movement Phase; the attacker stops 1 hex short and needs MP to enter the target's hex. It must not have jumped, and **cannot fire weapons that turn**. Damage to the target = ceil(tons/10) × hexes moved. Damage to the attacker = ceil(target tons/10). Both are applied in 5-point groups. On a hit, the attacker takes the hex and the target is moved away. **Both make PSRs at +2.** On a miss, the attacker slides to a front-side hex. | AGOAC p. 25–26 |
| C12f | **Death from above (DFA):** +0 plus the Piloting difference plus the **mandatory +3 for jumping**. Terrain is ignored. Declared during jump movement, and the 'Mech needs enough Jumping MP to clear the target's level + 2. No weapon fire that turn. Damage to the target = ceil(tons/10) × 3, in 5-point groups on the **Punch table**; a prone target uses the Rear column. Damage to the attacker = tons/5, in groups on the Kick table, Front column. **On a hit:** the target is moved away and makes a PSR at +2; the attacker makes a PSR at +4. **On a miss:** the attacker falls automatically, with 2-level fall damage to its rear, and the target steps aside. | AGOAC p. 26–28 |
| C12g | **Club or hatchet:** Club −1, damage tons/5. Needs both hands and shoulders working and no arm weapons fired. Clubs can be a tree in woods or a lost limb. Hatchet −1, damage tons/5, in the forward arc or the side arc of the hatchet's arm. | AGOAC p. 26, 28 |

## C13 Initiative and move order

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C13a | **Initiative:** Each side rolls 2D6 and ties are rerolled. **The loser moves first.** Sides alternate one 'Mech at a time in both movement and fire declaration. Standing still or not firing still uses up a selection. Fire is resolved with the initiative loser first. Turn order: Initiative, Movement, Weapon Attack, **Physical Attack, Heat, End**. | AGOAC p. 6–7 | QSR p. 1, 11 and ESS p. 2, 9 have the same alternation but only 3 phases: Initiative, Movement, Weapon Attack. |
| C13b | **Unequal numbers:** Before each pair of selections, if a side has **2× or more** units left to act, it moves 2 per selection; at 3× it moves 3, and so on. The book gives worked tables (10 vs 18 and 5 vs 14). | AGOAC p. 7 | **No unequal-numbers rule in QSR or ESS.** They only say to alternate. |

## C14 End and victory conditions

| # | Rule | Source | QSR/ESS vs AGOAC |
|---|---|---|---|
| C14a | **Default victory:** The last side with surviving 'Mechs wins. A simultaneous wipe-out is a draw, and so is a game where neither side's last 'Mechs can move or hurt each other. Players may agree on other conditions, and scenarios may set their own. | AGOAC p. 7 | QSR p. 1 and ESS p. 2 are the same, without the draw by stalemate. |
| C14b | **"Crippled" (scenario rule):** In S1 and S3, a 'Mech counts as defeated if a leg is destroyed, all its weapons are destroyed, its gyro is destroyed, or it has 2 engine crits. Leaving the map counts as destroyed. | AGOAC p. 46, 48 | QSR p. 11: leaving the map counts as destroyed. |
| C14c | **Forced withdrawal:** **Not present in any of these files.** The closest rules are the crippled rule above, AGOAC S2's exit-the-east-edge win, and ESS Breakthrough victory points (2 per attacker that exits, 1 per defender killed, 3 per attacker killed; ESS p. 10). | — | — |

## M1 Map names (exact)

| Map | Product | Source |
|---|---|---|
| **Desert #1** | QSR / Beginner Box. Printed in the QSR PDF, with the labels "Beginner Box Maps" and "Map Name: Desert #1". | QSR p. 11, PDF p. 17–18 |
| **The Patchwork (The Reaches)** | BattleTech Essentials box mapsheet | ESS p. 9 |
| **Steiner Stadium (Solaris City)** | Unlocked by the Essentials *Solaris VII Arena Map Rules* sheet, which is not in these files | ESS p. 10 |
| **Desert #2**, **Grassland #2**, **Grassland #3**, **Desert #3** | A Game of Armored Combat box. The box has two double-sided 18″×22″ paper maps, so these are presumably its four map faces. | AGOAC p. 3, 45–47 |

RS-AS and RS-FP name no maps.

## M2 Record sheets

| File | Classic sheets present |
|---|---|
| **RS-AS** | Full Classic sheets for 26 units. Inner Sphere: Locust LCT-3M and LCT-7V; Wasp WSP-3W and WSP-5A; Blackjack BJ-3 and BJ-5; Phoenix Hawk PXH-3K and PXH-4M; Wraith TR1 and TR5; Archer ARC-5R and ARC-7C; Warhammer WHM-6R and WHM-8R; Atlas AS7-S and AS7-S4. Clan OmniMechs: Fire Moth D and G; Pouncer Prime and T; Nova Prime and T; Timber Wolf Prime and T; Warhawk C and T. |
| **RS-FP** | **No 'Mechs.** Vehicles only: tracked, wheeled, hover and VTOL (for example Bulldog, Manticore, Demolisher, Schrek, Patton, LRM and SRM Carriers, Pegasus, J. Edgar, Warrior helicopter, Long Tom), plus Union and Overlord DropShips. |
| **QSR** | QSR-format simplified sheets: GRF-1N Griffin and WVR-6R Wolverine (PDF p. 15). Partial illustrations of a Fire Moth Prime and a Thor (Summoner) Prime. |
| **ESS** | QSR-format data blocks shown as illustrations: LCT-1V Locust, RFL-3N Rifleman, TDR-5S Thunderbolt (ESS p. 5–6). The box's own laminated sheets (CN9-A, RFL-3N, TDR-5S, WVR-6R) are not in the file. |
| **AGOAC** | The 15-sheet booklet is a **separate** file that was not supplied. Scenario rosters list exactly 15 variants: CPLT-C1, CPLT-K2, LCT-1V, LCT-1E, COM-2D, COM-3A, SHD-2H, BLR-1G, WVR-6M, WVR-6R, AWS-8Q, TDR-5S, TDR-5SE, GRF-1N, GRF-1S. The rulebook only has fragments, such as the CPLT-C1 construction example and a GHR-5J Grasshopper example. |

**The eight target 'Mechs:**

- **None has a full Classic sheet in the five files supplied.**
- **All eight** (AWS-8Q, BLR-1G, CPLT-C1, COM-2D, LCT-1V, SHD-2H, TDR-5S, WVR-6M) are in the AGOAC scenarios, so they are in the AGOAC record sheet booklet. That booklet has to be obtained separately; AGOAC p. 45 says the PDF is at bg.battletech.com.
- **Partial coverage only:**
  - LCT-1V and TDR-5S appear in ESS as QSR-format stat blocks only.
  - CPLT-C1 appears as a partial construction example on AGOAC p. 54.
  - RS-AS has Locust variants LCT-3M and LCT-7V, but not LCT-1V.

## M3 Introductory scenarios

| Book | # / Name | Map | Forces | What it teaches |
|---|---|---|---|---|
| QSR p. 11 | Training scenario (no name) | Desert #1 | Defender GRF-1N Griffin, within 3 hexes of the south edge. Attacker WVR-6R Wolverine, on the north edge. Gunnery 4. | 1v1 basics. Win by destroying the enemy. Leaving the map = destroyed. Variants: Clan Salvage Box 'Mechs, multiple 'Mechs, MechWarrior cards. |
| ESS p. 9 | Training scenario (no name) | The Patchwork (The Reaches); hardpacked gravel ignored | Defender CN9-A Centurion, within 2 hexes of south. Attacker RFL-3N Rifleman, north edge. | 1v1 basics. Variants: terrain placement, and adding TDR-5S + WVR-6R and CN9-A + RFL-3N. |
| ESS p. 10 | "Breakthrough" | Same | Defender CN9-A + RFL-3N, Gunnery 5, both pre-damaged. Attacker TDR-5S, Gunnery 5. The text says "both attackers", so the extraction may have dropped a second 'Mech. | Escape off the south edge, scored with victory points. |
| AGOAC p. 45–46 | **1: Final Exam** | Desert #2 + Grassland #2 | Mirror lances of CPLT-C1, LCT-1V, COM-2D and SHD-2H, all P5/G4. Placed alternately on the west and east edges. | Lance-on-lance battle with the full rules. Win by crippling or destroying all enemies. Alternate roster: TDR-5SE, WVR-6R, LCT-1V, COM-3A vs TDR-5S, GRF-1N, LCT-1E, COM-2D. |
| AGOAC p. 46–47 | **2: Trial by Fire** | Desert #2 + Grassland #3 | Defender: a lone BLR-1G (P5/G4), pre-damaged with 4×5 points on the front. Attackers: WVR-6M (P5/G5), LCT-1V (P6/G5), COM-3A (P6/G5). | Break through and exit the east edge, starting damaged, against greener pilots. The defender wins initiative on turn 1. Variant: a chase. |
| AGOAC p. 47–48 | **3: Divide and Conquer** | Desert #3 + Grassland #3 + die-cut terrain | Defender command lance: CPLT-K2 (printed "CPL-K2", P3/G2), TDR-5S (P4/G3), SHD-2H (P5/G4). Defender recon lance: LCT-1V (P4/G4), COM-3A, COM-2D (P5/G4). Attacker: AWS-8Q (P3/G3), TDR-5SE (P5/G4), WVR-6M (P4/G3), GRF-1N (P4/G3). | Defeating a split force one part at a time. Mixed skill levels. The defender takes −2 on initiative. Crippled/destroyed victory. |
| AGOAC p. 48 | Additional variations | — | — | MechWarrior cards. Planetary conditions: Full Moon Night (+1 MP per hex, +2 to hit) and Strong Gale (+2 for missiles, +1 for AC/MG, +1 PSR). Terrain placement. **Campaign play:** surviving S1 'Mechs can enter S3 from the west edge on turn 5. |

The book says the three AGOAC scenarios are meant to be played in order, each larger and more complex than the last.
