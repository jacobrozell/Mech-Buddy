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

## Still open

- **"0*" minimal damage** (1D6, 4+ deals 1). Settled for the shipped cards: masterunitlist.battletech.com prints the Locust LCT-1V as DMG 1/1/0/0, the Commando COM-2D and Wolverine WVR-6M as 2/2/0/0, and the Shadow Hawk SHD-2H as 2/2/1/0. Those are plain 0s, not 0*. The site marks minimal damage as "0*" (the Shadow Hawk's "IF 0*"), so "no shot at that range" is right. A card with 0* damage will need a minimal-damage field when one ships. The same lookup shows the Shadow Hawk's **JMPW 1** on its card, which settles playtest note 13.
- **Rear arc:** the exact definition is in diagrams that didn't extract. The Broken Ground tip says "back half".
- **Not used by any mission yet:** water (partial cover, −1 heat), HT heat, REAR, physical attacks, Forced Withdrawal and crippled. See `mission-ladder-rules-intake.md` before building Missions 4–5.
- **MP hits and jumping:** whether an MP hit halves jump inches. The app halves them, which is the plain reading of "halves its Move".
