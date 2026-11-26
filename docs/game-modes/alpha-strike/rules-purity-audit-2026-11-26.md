# Alpha Strike rules purity audit — 2026-11-26

**Question (owner):** are all the rules the app applies to Alpha Strike really Alpha Strike rules, with nothing from Classic BattleTech (Total Warfare / A Game of Armored Combat)?

**Source:** Alpha Strike Box Set Quick-Start Rulebook, 3rd printing (`ongoing/`, git-ignored). Page numbers are printed pages.

## Verdict

No Classic contamination. The Alpha Strike engine, battle copy and content use no hexes, MP/hex movement, hit locations, piloting rolls or falls, heat sinks or 0–30 heat scale, cluster hits, ammo tracking, torso twist, or separate gunnery/piloting skills. Every rule the engine applies traces to a Quick-Start page. `Domain/Engines/ClassicTW` is not referenced from any Alpha Strike path. No Commander's Edition rule is applied; the abilities the Quick-Start defers to Commander's Edition (AC, ECM, Omni, LRM, IF, SRM) are listed but have no effect, as the book says.

"Punch or kick", "MP hit" and "hex side" are the Quick-Start's own words (pp. 21–23), not Classic leaks.

The 'Mechs in Missions 1–5 (Shadow Hawk, Commando, Wolverine, Thunderbolt, Catapult, Awesome, BattleMaster…) come from the Classic *A Game of Armored Combat* box, played with their Alpha Strike cards from the Master Unit List. The rules are Alpha Strike.

## Fixed (2026-11-26)

- [x] **Victory under Forced Withdrawal** counted only destroyed 'Mechs. The book wins by crippling *or* destroying every enemy (pp. 26, 31). A crippled 'Mech is now out when the scenario uses Forced Withdrawal (Meet and Greet, Full Lances); Full Lances' summary says so. `VictoryEvaluator.countsAsLiving`, tested in `ForcedWithdrawalTests`.
- [x] **REAR shot then punch** was allowed. A REAR shot is a weapon attack, and a 'Mech can't make a physical attack in a turn it made one (p. 22). The reducer now refuses it; `MatchUnitState.canMakePhysicalAttack` is for the UI. Tested in `RearFiringTests`.
- [x] **Skill PV table cite** said p. 33; it is p. 35 (code comment and Rules tab).

## Still to do

- [x] Shot sheet: offer "Punch or kick" only when `canMakePhysicalAttack` (after the one-screen shot sheet branch merges).
- [x] Copy: Crit sheet's engine hit says "later shots are harder"; it should say it adds 1 heat whenever the 'Mech fires (p. 23).
- [x] Copy: Clean up's "Wrecks don't explode or hurt anything nearby" has no Quick-Start source; drop it or say the book has no such rule.
- [x] Copy: describe the rear as "the attack enters through the rear of its base" (p. 21 diagram), not "its back half" (Broken Ground tip), and REAR targets as "more than half the target's base is outside the front arc" (p. 18).
- [x] Rules tab: note that the book has the lower roll fire first (p. 13); the app lets both sides roll together because damage lands at the end of the phase, so the result is the same (owner decision, playtest note 50).
- [x] Label app rules as app rules where the victory summary shows: mission turn limits and "more Structure left wins" are not in the book (it has no turn limit).
- [ ] Note the small setup deviation: the book's default is that 'Mechs enter from the table edge on turn 1 (p. 11); the app always uses on-table placement within 6″, which the book allows by agreement.
- [ ] Optional wording: "Physical attack" instead of "Punch or kick", "Ground move" instead of "Walked", "Destroyed" instead of "Wrecked" — closer to the book, not wrong today.

## Not built yet (Alpha Strike box rules, not contamination)

Charge and Death From Above, AMS, buildings, Battlefield Support, formations, MechWarrior (pilot) cards and their abilities (Lucky, Combat Intuition, Maneuvering Ace…). These are needed for Clash of Steel and open play; see [FUTURE-PLAN.md](../../FUTURE-PLAN.md) §4.

## Book inconsistencies noted

- Home edge: p. 8 says the long side; p. 7 and the scenarios deploy on the short sides 4′ apart. The app follows p. 7.
- Minimal damage and a natural 12: p. 21 Q1 and the minimal-damage sentence disagree on whether a failed minimal roll still owes a crit. The app follows the minimal-damage rule (no crit).
