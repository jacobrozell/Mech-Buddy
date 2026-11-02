# SATOR Attack Spec — Alpha Strike

Types: [DomainModelSpec](../DomainModelSpec.md).

## User story

Mid-Combat, pick attacker/target, build TN with SATOR, **enter physical 2D6**, apply damage, roll crit if owed.

### Damage resolver

After attacker, target, and table insights are set, the sheet **previews before dice**:

- Target number and hit odds  
- Damage at this range (S/M/L of the attacker, plus rear if marked)  
- Armor → leftover, Structure → leftover  
- Whether a critical is owed / whether the target is wrecked this turn  

Enter 2D6. The dock title becomes **Apply {n} damage**, **Apply hit** when damage is zero, or **Apply miss**. Natural 12 that hits always previews a critical (through armor).

## Screen: `as.sator` (sheet)

Title **Solve a shot**. Large detent only, drag indicator visible. Presented from the battle dock or after Unit Focus dismisses.

### Layout

1. Pair picker when the attacker or target is still open (`as.sator.attacker`, `as.sator.target`). One legal shooter or one remaining target is preselected.
2. Sticky header: “{attacker} → {target}” and `TNGauge`.
3. **Summary** chips from `TargetNumber.breakdown` (`S 4`, `A +0`, …). Tapping a chip shows that letter’s explanation and an equation line.
4. Range control and **Target moved**.
5. **Conditions** chips.
6. `DiceTray`, then `OutcomeBanner` once both faces are set.
7. Damage preview card when the shot can hit. Before the dice, a wreck or critical is worded as what a hit would do. After a hit, the card states that result, including a critical on two 6s through armor. After a miss, the pips stay hypothetical and the card does not say a critical is owed or that the target is wrecked.
8. Glass apply bar.

`TNGauge` (`as.sator.tnPreview`, also `as.sator.tn`) shows a large “N+”, “P% to hit”, and a 2d6 histogram on `surface.readout`. Above 12 it reads **Can’t hit**. A blocked shot reads **Can’t shoot** plus the reason. Compact height places the gauge beside the dice.

### Who can shoot

Attacker: `canAttackThisTurn` (not removed, not already shot, not sprint). Target: any non-`removed` enemy, including `destroyedPendingEnd`. Skill and the attacker’s move come from the unit. The sheet has no skill stepper and no attacker-move picker.

### Conditions

Chips, off until tapped: **Woods**, **Partial cover**, **Rear shot**.

**More…** reveals two more chips, both **off by default** (`canSeeTarget` and `targetInFrontArc` start true):

| Chip | When on |
|------|---------|
| Can’t see the target | Blocks the shot (no line of sight) |
| Behind the shooter | Blocks the shot (outside the front arc) |

The helper line under More says to leave them off for a normal shot. Charge/DFA and overheat stay at the resolver defaults (off / 0) on this sheet. Heat, stealth, and fire-control hits are read from the units and show up in the summary chips when they change the TN.

### Range and target move

Range is a segmented control **Short ≤6″ / Medium 7–24″ / Long 25–42″** (`as.sator.range`) plus a **>42″** toggle. While the toggle is on, the band picker is hidden (`as.sator.range` stays on the explanation) so it cannot show a band that is not in use. Turning it off returns to Long. Target moved is a **Change** menu (`as.sator.tgtMove`): Walked, Sprinted, Stood still, Jumped, Can’t move. It starts from the defender’s recorded move. Walk and sprint share the ground TMM; sprint only changes the word on the T chip.

### SATOR modifiers (numeric)

| Letter | Control | Δ TN |
|--------|---------|------|
| **S** | Attacker’s card skill (Ridge Line is 4). No stepper on the sheet | base = skill |
| **A** | From the attacker’s recorded move. Unset counts as ground | |
| | standstill | −1 |
| | ground / unset | +0 |
| | jump | +2 |
| | sprint | **illegal** → `cannotAttack` |
| **T** | immobile | −4 |
| | standstill | +0 |
| | groundUsesTMM | +targetTMM |
| | jumpedUsesTMMPlus1 | +targetTMM+1 |
| **O** | woods | +1 |
| | partialCover | +1 |
| | chargeOrDFA | +1 |
| | targetHasSTL | +1 if medium, +2 if long, +0 if short |
| | each fireControlHits | +2 |
| | attackerHeat | +heat (0…4) |
| **R** | short | +0 |
| | medium | +2 |
| | long | +4 |
| | outOfRange | no shot |

### Range from inches

| Inches `d` | Bracket |
|------------|---------|
| `d ≤ 6` | short |
| `6 < d ≤ 24` | medium |
| `24 < d ≤ 42` | long |
| `d > 42` | outOfRange |

### TN & odds

```
tn = S + A + T + O + R
autoMiss = tn > 12
```

2D6 ways totaling ≥ tn (36 faces): use map  
`WAYS_AT_LEAST = [2:36,3:35,4:33,5:30,6:26,7:21,8:15,9:10,10:6,11:3,12:1]`  
`odds% = tn<=2 ? 100 : (tn>12 ? 0 : round(WAYS_AT_LEAST[tn]/36*100))`

Natural 12 is **not** auto-hit. If the entered roll is 12 **and** it hits (12 ≥ tn), critical is owed **even if no structure was marked** (through armor).

### Enter 2D6 (primary)

`DiceTray` with identifier prefix `as.sator`:

- Real dice: two `DieFacePicker`s, `as.sator.die1` and `as.sator.die2`
- **Let the app roll** (`as.sator.diceMode`) switches the session mode. **Roll** is `as.sator.autoRoll`
- Settings → Dice is the default for a new game. Physical dice are the primary path
- Apply bar: `as.sator.resolve` on the button, `as.sator.apply` on a sibling. Titles: **Apply {n} damage**, **Apply hit**, **Apply miss**, or **Can’t apply** / **Apply** while the roll is incomplete

Hit if `total >= tn && !autoMiss`. An auto-miss can be applied without faces (the reducer records 1 and 1).

### Damage

```
base = damage for active bracket (S/M/L field)
delivered = base + (rearHit ? 1 : 0) + overheatUsed
```

`overheatUsed` only if `ruleset.overheatAllowed` and bracket is short/medium, or long when card has OVL (`ovlAllowsLong`). Ridge Line: always 0 UI.

### Apply damage

1. Subtract from armor until 0, remainder to structure  
2. `needsCritical` if any structure increased **or** (hit && natural12)  
3. If structure full → `combatStatus = .destroyedPendingEnd`  
4. Mark attacker `hasAttackedThisTurn = true`  
5. If `needsCritical`, dismiss this sheet. The battle step becomes the critical-pending coach, and **Roll critical** presents `as.critRoll`. Closing the crit sheet leaves the crit owed

---

## Critical table (`as.critRoll`)

Enter physical 2D6 (same control pattern). The result name and the reference rows use `AlphaStrikeCriticals.title` (roll 7 is “MP hit”), which is also the event-log name. Apply to **target**:

| Roll | Result | Effect |
|------|--------|--------|
| 2 | Ammo hit | Destroyed (`destroyedByCrit`) unless abilities contain `ENE`, `CASE`, or `CASEII` (CASE/CASEII: survive; optional +1 structure dmg later — v1: survive, no extra) |
| 3 | Engine | `engineHits += 1`; if ≥2 → `destroyedByCrit` |
| 4 | Fire control | `fireControlHits += 1` |
| 5 | No critical | — |
| 6 | Weapon | `weaponHits += 1`; reduce s,m,l by 1 (floor 0) |
| 7 | MP | `mpHit = true`; halve printed TMM (floor); MV display note |
| 8 | Weapon | same as 6 |
| 9 | No critical | — |
| 10 | Fire control | same as 4 |
| 11 | Engine | same as 3 |
| 12 | Destroyed | `destroyedByCrit = true` |

---

## Golden test vectors (must pass)

| # | Input summary | Expected TN | Odds% | Notes |
|---|---------------|-------------|-------|-------|
| 1 | skill4, ground, tgt ground TMM2, no other, short | 6 | 72 | 4+0+2+0+0 |
| 2 | skill4, standstill, tgt standstill, short | 3 | 97 | 4−1+0 |
| 3 | skill4, jump, tgt jump TMM2, med | 11 | 8 | 4+2+(2+1)+0+2 |
| 4 | skill4, ground, TMM2, woods+FC1, long | 13 | 0 | 4+0+2+1+2+4 autoMiss |
| 5 | skill5, ground, TMM3, heat2, short | 10 | 17 | 5+0+3+2 |
| 6 | tn computed 13 | autoMiss | 0 | |
| 7 | Damage: armor5/0, struct5/0, dmg3 | armor2 left | needsCrit false | |
| 8 | armor0, struct5/0, dmg2 | struct 2 dmg | needsCrit true | |
| 9 | Hit natural 12, armor only | needsCrit true | through armor | |

More vectors welcome; these are the CI floor.

---

## Accessibility

- `as.sator.sheet`, `.attacker`, `.target`, `.range`, `.tgtMove`
- `as.sator.tnPreview`, `.tn`, `.outcome`
- `as.sator.die1`, `.die2`, `.diceMode`, `.autoRoll`, `.resolve`, `.apply`
- Pair cards: `as.sator.pick.attacker.{uuid}`, `as.sator.pick.target.{uuid}`
- `as.crit.sheet`, `.die1`, `.die2`, `.diceMode`, `.autoRoll`, `.confirm`

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-11-01 |
| Commit | — |
| Code paths | `Features/Battle/CombatSolverSheet.swift`, `Features/Battle/CritSheet.swift`, `DesignSystem/Components/TNGauge.swift`, `DiceTray.swift`, `OutcomeBanner.swift`, `Domain/Engines/AlphaStrike/CombatSolver.swift`, `SATORResolver.swift`, `AlphaStrikeCriticals.swift` |
