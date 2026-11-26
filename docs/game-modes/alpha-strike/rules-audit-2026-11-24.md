# Rules audit — 2026-11-24

**Source:** *Alpha Strike Box Set Quick-Start Rulebook*, 3rd printing. Page numbers are the printed numbers. The PDF is the owner's copy and is not in the repo.

**Method:** a read-only pass compared the engine (`Domain/Engines/AlphaStrike`, `MatchReducer`, `MatchUnitState`), the mission packs and the player-facing copy with the rulebook. Each finding was then checked against the rulebook text before it was fixed.

## Fixed

| Rule | Page | Was | Now |
|---|---|---|---|
| Weak and strong jump jets (JMPW#, JMPS#) | 18, 20 | Ignored. A jumping Shadow Hawk was +3 | The jumping TMM adds JMPS# or subtracts JMPW#; each MP hit lowers JMPS (`MatchUnitState.jumpTMMAdjustment`). The Shadow Hawk is now +2, matching its card |
| Uneven numbers move in proportion | 14 | Sides always alternated one 'Mech at a time | Before each pair of moves, a side with at least twice as many 'Mechs left moves that multiple (`AlphaStrikePhaseEngine.movementSequence`). The move-order list shows the same order |
| Repeated MP hits | 23 | A second MP hit made the 'Mech immobile | Each hit halves MV and TMM again, cutting at least 2″ and 1 TMM; the 'Mech is immobile only at 0″ (`CritFlags.mpHits`, `MPHitMath`). The card values are no longer overwritten, so mid-phase shots keep reading the phase-start snapshot |
| Natural 12 | 21–22 | One crit roll at most | The natural 12 owes one roll, and damage reaching structure owes another. A 'Mech the hit destroys owes none |
| Crit effect that can't apply | 23 | Nothing happened | 1 damage instead, with no further crit roll (weapon hit with all damage at 0; MP hit on a 'Mech already at 0″) |
| CASE | 23, 25 | Treated like ENE | CASE takes 1 extra damage, rolling again if that reaches structure. CASE II and ENE ignore the hit |
| Bases touching | 20 | Shots allowed; the rules text said to shoot at short range | More… → **Bases touching** blocks the shot. The rules topic is corrected |
| No damage at a range | 20 | A 0-damage shot was allowed; a rear hit turned it into 1 damage | No shot at a range where the card does no damage (`CombatSolver.noDamageReason`; also enforced in the reducer) |
| Attacker rolls the critical | 23 | The damaged side was told to roll | The side that hit it rolls |
| Deployment | 11 | "Side X places first" (the initiative loser) | The initiative winner picks who places first, then sides alternate one 'Mech at a time |
| Range-band labels | 19 | 0–6″ / 6–24″ / 24–42″ overlapped | ≤6″ / >6–24″ / >24–42″. The engine was already right |
| Woods | 17, 19 | "A little harder" | +1 if the target is in woods, or if intervening woods are more than 2″ from the shooter. 6″ or more of woods blocks the shot |
| Heat at 2+ costs 1 TMM | 24 | Missing from the overheat explainer | Added |
| Running Hot shutdown timing | 24 | "shut down on turn 4" | Reaches S at the end of turn 4 and sits out turn 5 |
| Broken Ground hills | 9, 15 | Free climbing, unlabelled | Labelled as a house rule for the mission |

## Verified correct (no change)

- **Initiative:** 2D6, ties re-roll, winner moves last.
- **Movement:** stood still means under 1″. Sprint is ×1.5 rounded up and blocks firing.
- **SATOR modifiers:** attacker move −1 / 0 / +2. Target standstill 0, ground and sprint +TMM, jump +TMM+1, immobile −4. Woods +1, partial cover +1, fire control +2 each, heat +level, stealth +1/+2.
- **Range and damage:** range brackets and over 42″. A target number of 13 or more always misses. Damage by bracket, minus weapon hits. Rear +1.
- **Overheat:** S/M only, L with OVL, capped at OV, heat on hit or miss.
- **Crit table and effects:** the table, fire control, engine heat, and the second engine hit destroying the 'Mech.
- **Heat:** End Phase cooling order and shutdown.
- **End of turn:** wreck removal timing and the mission victory rules.
- **Abilities with no effect yet:** IF, LRM and SRM correctly do nothing at this level.

**Simultaneous fire** (owner decision, playtest note 50): with the fixes above, the order shots are entered in can't change the result. Damage and crit effects land at the end of the phase. The one order-dependent effect, the second-MP-hit rewrite, is gone.

## Update 2026-11-25: 0* minimal damage and water (domain done, UI wiring pending)

Page numbers are the printed ones in the Quick-Start Rulebook, 3rd printing (PDF page minus 1).

- **0\* minimal damage (p. 4, p. 21).** A card prints "0\*" at a range where it can still use Minimal Damage; a dash means no shot. Rule text, paraphrased: every successful attack at a "0\*" band makes its player roll 1D6. On 4 or higher it delivers a single point of standard damage. Otherwise it still hits but delivers none, and a minimal attack that delivers no damage may not resolve any Critical Hit checks.
  - Data: `MatchUnitState.minimalDamage` (`MinimalDamageBands`, per band). The card Int stays 0 at that band. `ScenarioUnitDTO` and `BoxCardDTO` accept `"0*"` as a string for `s`/`m`/`l`; plain numbers decode as before. Saved matches decode without the new keys (the payload JSON is not a SwiftData column, so `SchemaV1` is unchanged).
  - Solver: a 0\* band allows the shot. `CombatSolve.needsMinimalRoll` says the hit owes a die. `SATORAttackCommand.minimalDie` carries it; a hit without a valid die is refused. 4+ applies 1 damage (a natural 12 still owes its crit). 1 to 3 is a hit that deals 0 and rolls no crit, including on a natural 12.
  - Owner-level calls where the book is silent: a Weapon Hit (p. 23, "reduced by 1, to a minimum of 0") leaves a printed 0\* at 0\*, while a printed 1 reduced to 0 is a plain 0 with no shot. Overheat points are ordinary damage, so a shot that overheats at a 0\* band is not minimal. A rear hit does not add to minimal damage, because the rule says "a single point". HT heat still lands on any hit. No shipped card has 0\* yet.
- **Water (pp. 10, 17, 19-20, 24).** A 'Mech standing in depth 1" water has partial cover (+1 to hit), even against a higher attacker. The rulebook example (p. 20) adds that +1 for a target in water. Cooling Down step 2 subtracts 1 heat level if the 'Mech is in water.
  - Data: `MatchUnitState.inWater`, set by `MatchReducer` command `.setInWater`, cleared by `resetTurnFlags` each turn. Water cover is the same +1 as other partial cover and never stacks with it.
  - Heat: `AlphaStrikeHeat.endPhase` subtracts 1 after adding overheat and before the no-attack clear, floored at 0. External HT heat is added after.
  - Movement cost of water is not tracked (players measure it on the table).

## Still open

- **"0*" minimal damage** (now implemented, see the update above). Settled for the shipped cards: masterunitlist.battletech.com prints the Locust LCT-1V as DMG 1/1/0/0, the Commando COM-2D and Wolverine WVR-6M as 2/2/0/0, and the Shadow Hawk SHD-2H as 2/2/1/0. Those are plain 0s, not 0*. The site marks minimal damage as "0*" (the Shadow Hawk's "IF 0*"), so "no shot at that range" is right. A card with 0* damage will need a minimal-damage field when one ships. The same lookup shows the Shadow Hawk's **JMPW 1** on its card, which settles playtest note 13.
- **Rear arc:** the exact definition is in diagrams that didn't extract. The Broken Ground tip says "back half".
- **Not used by any mission yet:** HT heat, REAR, physical attacks, Forced Withdrawal and crippled. See `mission-ladder-rules-intake.md` before building Missions 4–5.
- **MP hits and jumping:** whether an MP hit halves jump inches. The app halves them, which is the plain reading of "halves its Move".
