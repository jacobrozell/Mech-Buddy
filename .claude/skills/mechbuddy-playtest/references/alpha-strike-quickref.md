# Alpha Strike quick reference (as used in Ridge Line)

Enough rules to play and to spot when the app gets them wrong. When the app and this sheet
disagree, note it as a `[RULES BUG]` candidate and say which you followed.

## Turn sequence
1. **Initiative** — each side rolls 2d6. Higher total wins and moves/acts *last*. Ties reroll.
2. **Movement** — loser of initiative moves a unit first, then sides alternate. The owning
   player chooses which of their units to activate each time.
3. **Combat** — all units fire; damage and crit *effects* resolve at the end of the phase, so
   every unit fires even if it is destroyed this phase, and crits taken this phase don't change
   this phase's shots.
4. **End phase** — remove destroyed units.

## Movement modes
| Mode | Distance | Effect on own shots | Unit's TMM when targeted |
|---|---|---|---|
| Stood still | < 1″ | −1 | 0 |
| Walk | up to MV | 0 | card TMM |
| Sprint | ~1.5× MV | can't shoot | card TMM + 1 |
| Jump | jump MV | +2 | card TMM + 1 |

Woods: moving through costs extra inches.

## To-hit number (2d6, need ≥)
`Skill (4) + attacker movement + target TMM + range + other`

- Range: Short 0–6″ (+0) · Medium >6–24″ (+2) · Long >24–42″ (+4) · beyond 42″ no shot.
- Woods in the line of fire / target in woods: +1 (the app's *Woods* condition).
- Fire-control crit: +2 per crit (from the *next* phase on).

## Damage
Card shows S/M/L damage. A hit deals the value for the range band. Armor goes first, then
structure. **Any structure damage → roll a crit (2d6)** for the damaged unit.

## Critical hits (2d6)
| Roll | Result |
|---|---|
| 2 | Ammo hit (destroyed unless CASE/ENE) |
| 3 | Engine hit |
| 4 | Fire control (+2 to-hit) |
| 5 | No crit |
| 6 | Weapon hit (−1 damage at all ranges) |
| 7 | MP hit (half move, TMM drops) |
| 8 | Weapon hit |
| 9 | No crit |
| 10 | Fire control |
| 11 | MP hit |
| 12 | Unit destroyed |

A unit already at 0 structure is destroyed — no crit is needed.

## Ridge Line units (match the printed cards; skill 4)
| Unit | PV | MV | TMM | S/M/L | A/S | Special |
|---|---|---|---|---|---|---|
| Shadow Hawk SHD-2H | 30 | 10″/6″j | 2 | 2/2/1 | 5/5 | IF0* (bundle also lists JMPW1) |
| Commando COM-2D | 17 | 12″ | 2 | 2/2/0 | 2/2 | SRM1/1 |
| Wolverine WVR-6M | 32 | 10″j | 2 (3 jumping) | 2/2/0 | 6/5 | OV1 |
| Locust LCT-1V | 18 | 16″ | 3 | 1/1/0 | 2/2 | — |

## Victory (Ridge Line)
Destroy both enemy 'Mechs, or after turn 6 the side with more total Structure left wins;
equal Structure is a draw. Destroyed 'Mechs don't explode or harm neighbours.
