# Clash of Steel — rules intake (Alpha Strike Box Set Quick-Start Rules, 3rd printing)

Read-only research for building Scenario Second, "Clash of Steel" (printed p. 31). All rules
below are paraphrased from the Quick-Start Rulebook (QSR). Page numbers are **printed** page
numbers (the PDF index is printed + 1). Number tables are reproduced as data.

Status legend for app impact: **[COMPUTE]** = changes a number the app computes (to-hit,
damage, heat, movement); **[TABLE]** = bookkeeping/checklist; **[OPEN]** = ambiguity or
printing conflict that needs a product decision.

---

## 1. Buildings (p. 10 summary, p. 28 full rules)

### Types and CF
Four categories: Light, Medium, Heavy, Hardened. Each has a construction factor (CF), the
damage it can absorb before becoming rubble. Players may set any CF inside the range; the
default is in parentheses. In the box, the nine small buildings (~1.6" square) are **Medium**
and the six large ones (~4.25" x 3") are **Heavy** (p. 10, p. 28). Two small or one large
building counts as one terrain choice (p. 10). Buildings are 1"–12" tall, most 1"–3" (p. 10).
Bridges, walls and similar structures use the building rules (p. 10).

**Alpha Strike Buildings Table (p. 28)**

| Type     | Move cost per inch | CF range (default) | Weight capacity (sum of Size) | Collapse damage |
|----------|-------------------:|--------------------|------------------------------:|----------------:|
| Light    | +1" | 1–5 (3)   | 2 | 0* |
| Medium   | +2" | 2–8 (4)   | 4 | 1  |
| Heavy    | +3" | 6–18 (12) | 6 | 2  |
| Hardened | +4" | 10–40 (20)| 8 | 4  |

(The prose on p. 28 gives max CF Light 5, Medium 8, Heavy 18, Hardened 40 and the same
defaults. The Movement Cost Table on p. 15 lists Building as +1–4".)

- **[OPEN]** The `*` on Light collapse damage has no footnote text in the extracted page.
  Treat as 0 damage unless the physical book shows a footnote.
- **[OPEN]** Weight-capacity conflict: the worked example on p. 28 gives a Medium building a
  capacity of 2 (two Size 1 'Mechs), but the table lists Medium = 4. Recommend using the table
  (4) and flagging it in a coach note.

### Movement effects (p. 28, p. 10) [COMPUTE for move cost; TABLE for the rest]
- Moving **through** a building costs the extra inches per inch in the table (on top of the
  base 1"/inch).
- A 'Mech may **not end its move inside** a building (QSR restriction).
- Moving through deals **1 point of damage to the building's CF per inch** travelled inside it.
  (The text hints at exceptions later on, but none are given.)
- **Climbing / rooftops:** a 'Mech can climb the outside face like a hill level change, max 2"
  of level change (same as hills; 3"+ within 2" horizontal is prohibited). A jump-capable 'Mech
  may jump onto a roof if its jump Move covers the building's level. Moving across the top is
  allowed (p. 10, p. 28).
- **[OPEN]** Level-change cost: the Movement Cost Table (p. 15) prints +2" per 1" elevation, but
  the Level Change paragraph on the same page says one extra inch per inch. Pick one and note it.

### Weight capacity (p. 28) [TABLE]
Capacity is the max **total Size** of all 'Mechs standing on the building. If exceeded, the whole
building collapses. If this happens during a move, the moving 'Mech's move ends as soon as it
exits the building, then the collapse is resolved.

### Collapse (p. 28) [TABLE, damage could be a helper]
- Collapses when CF reaches 0, or when weight capacity is exceeded.
- 'Mechs moving through it or standing on it take **collapse damage x floor(height in inches / 4),
  minimum multiplier 1**. 'Mechs on the roof take **+1** more.
  - Example: Heavy (2), 3" tall: 2 x 1 = 2 damage; on the roof 3.
- Remove the building immediately; its footprint becomes **rubble** (rough terrain: +1"/inch,
  no LOS effect, no attack modifier; p. 11).

### Attacking buildings (p. 28, p. 19) [COMPUTE]
- Attacked like any other unit, resolved as an **immobile target: –4 to-hit** (p. 19 lists
  buildings as a typical immobile target; the immobile TMM is a flat –4, p. 18).
- Damage goes to CF. The building's **type never changes** as CF drops (still a Heavy for move
  cost, capacity and collapse damage even at 3 CF).
- **No occupant damage rule** from attacks: 'Mechs can't end a move inside a building, so there
  are no occupants in the QSR. 'Mechs are hurt only via collapse.
- No physical-attack-vs-building rule is given.

### Cover / LOS (p. 10, p. 9, p. 19) [COMPUTE: partial cover]
Buildings block LOS and give partial cover by the **hill rules**: LOS is blocked if more than
two-thirds of the target is hidden; between one-third and two-thirds hidden = **partial cover,
+1 to-hit**. Battlefield Support ignores buildings (p. 29).

---

## 2. Battlefield Support (p. 12 optional rule; pp. 29–30 full rules)

### Budget and selection (p. 12, p. 29)
- Budgets: 0, **5 (Extraction Raid Support)** or **12 (Objective Raid Support)** BSP per player,
  or roll 1D6 (1–2: 0, 3–4: 5, 5–6: 12) when the scenario doesn't set it.
- **Clash of Steel sets 5 BSP each, chosen secretly** (p. 31).
- Before play, each player **secretly writes down** the support types bought.
- **One-time use:** each purchase is used once whether or not it does damage. Buying the same
  type twice gives two uses.

### Declaring and resolving (p. 29)
- Declared **in the Combat Phase** of the turn it is used. The player reveals the type being used
  but not the rest of their picks.
- The player names a target 'Mech or a Point of Impact (POI).
- **Target numbers are flat: roll 2D6 vs the TN, no modifiers at all.**
- Terrain, hills and buildings have **no effect** on support damage in the QSR.

**Alpha Strike Battlefield Support Table (p. 30)**

| Support type | Category | Target | TN (no mods) | Damage | BSP cost | AoE template | Scatters on miss |
|---|---|---|---:|---:|---:|---|---|
| Light Strike   | Aerospace strike  | 'Mech | 5 | 1 | 2 | No  | No (miss = nothing) |
| Light Bombing  | Aerospace bombing | 'Mech or POI | 5 | 1 | 3 | Yes | Yes |
| Heavy Strike   | Aerospace strike  | 'Mech | 6 | 2 | 3 | No  | No (miss = nothing) |
| Heavy Bombing  | Aerospace bombing | 'Mech or POI | 7 | 2 | 4 | Yes | Yes |
| Thumper        | Artillery         | POI only | 7 | 1 | 2 | Yes | Yes |
| Sniper         | Artillery         | POI only | 8 | 2 | 3 | Yes | Yes |

(The extracted table prints Thumper/Sniper damage as "12"/"22": that's damage 1 and 2 with
footnote 2 (area of effect). Bombing has footnote 1 (scatters on a miss). The bombing text on p. 29 and
the Light Bombing card (damage type AE) confirm bombing also uses the AoE template.)

**Legal 5-BSP loadouts for Clash of Steel:** Light Strike + Light Bombing (2+3); Light Strike +
Heavy Strike (2+3); Light Strike + Sniper (2+3); Thumper + Light Bombing / Heavy Strike / Sniper
(2+3); Light Strike x2 (4); Thumper x2 (4); Light Strike + Thumper (4); Heavy Bombing (4);
or any single 2- or 3-cost item (anything left over is wasted).

### Hit / miss resolution (pp. 29–30)
- **Strikes:** a hit applies the damage to the target 'Mech; a miss does nothing.
- **Bombing / artillery hit:** center the AoE template on the target or POI; **every 'Mech base
  the template touches** takes the damage (friend or foe: the text doesn't exempt friendlies).
- **Bombing / artillery miss = scatter:** the template's "1" points to the map's north. Roll 1D6
  for one of six directions, then 1D6 x 2 for the distance in inches from the original
  target/POI. The landing point becomes the new center and everything under the template takes
  the damage.
- Template size isn't given in the text (it's a physical template in the box).

**[OPEN]** Not specified: (a) where support goes in the Combat Phase order (presumably during
the declaring player's combat activations); (b) whether support damage counts as front/rear
(no rear +1 is mentioned, so assume front/no bonus); (c) whether support damage effects wait
for the End Phase like weapon damage (p. 13 general rule suggests yes).

---

## 3. Formations (scenario summary p. 32; Force Building pp. 33–39, Formations pp. 37–39)

### General requirements (pp. 34, 37)
- A Formation needs **at least 3 'Mechs** to get any bonus, and must meet its Type's
  requirements. Percentages round up (a 50% requirement is 2 of 4 or 3 of 5).
- **Ideal role:** if every 'Mech has the Type's ideal role, requirements count as met.
- Types don't stack; each Formation is designated as one Type.
- A 'Mech keeps its bonus **as long as three of its Formation's 'Mechs are not destroyed** (p. 37).
  Clash of Steel's scenario box doesn't restate this, but the general rule applies.

### Command Lance (Defender) — scenario text p. 32; general p. 38
Requirements (p. 38): one designated Command 'Mech; 50% must be Sniper, Missile Boat,
Skirmisher or Juggernaut; one more must be Brawler, Striker or Scout. Ideal role: none.

Bonuses as given in **Clash of Steel** (p. 32):
1. **Initiative reroll:** while the **Atlas** is not destroyed, the player may reroll their
   Initiative roll **once per turn**; the second roll stands even if worse. [TABLE]
2. **Combat Intuition** on **two 'Mechs chosen at scenario start, not the Atlas** (from Archer,
   Warhammer, Blackjack). If that side **wins Initiative**, a Combat Intuition 'Mech may move
   **and resolve all its attacks during the Movement Phase**, with damage effects applied
   **immediately** (before the target can act). **Once per 'Mech every 3 turns.**
   [COMPUTE/TABLE: see below]

**[OPEN] Conflict with the general rule (p. 38):** the Formations chapter says the reroll is
**once every two turns** (tied to the Command 'Mech), and the assignment can't change once play
starts. The scenario box says once per turn. The scenario text should win for Clash of Steel,
but the app should show the source.

Combat Intuition notes for the app:
- It's an exception to the normal flow: attack resolution moves into the Movement Phase and
  damage effects apply at once instead of in the End Phase (the target may be destroyed before
  it moves or fires).
- p. 18: if an attack happens in the Movement Phase against a jump-capable target that hasn't
  moved yet, treat the target as having used ground movement. Not stated for a target that
  hasn't moved at all: likely its listed TMM (ground move) by the same logic. **[OPEN]**
- Needs a per-'Mech cooldown: used on turn N, available again on turn N+3.

### Recon Lance (Defender) — p. 32; general p. 39
Requirements (p. 39): every 'Mech Move ≥ 10"; at least two Scout or Striker. Ideal role: Scout.
Bonus: **every member gets Maneuvering Ace**: woods (and jungle, p. 38) movement costs
**1" less per inch**, so woods' +1" drops to +0". [COMPUTE: movement cost]
(The scenario text calls the Highlander lance a Star, which is a typo.)

### Battle Star (Attacker) — p. 32; general pp. 37–38
Requirements (p. 37): 50% Size 3+ (3 of 5 in a Star); at least three Brawler, Sniper and/or
Skirmisher. Ideal role: Brawler.
Bonus: **Lucky, 7 uses in Clash of Steel** (general formula p. 38: 2 + starting number of
'Mechs = 2 + 5). Each use lets a 'Mech in the Formation **reroll one Attack Roll**; the second
result stands. Lucky can't be used on other rolls (critical hits, Initiative, Battlefield
Support TNs aren't attack rolls by 'Mechs). Under the optional Multiple Attack Rolls rule, one
use rerolls all of that attack's rolls together. [TABLE: shared counter; the reroll itself is a
dice event]

---

## 4. Clash of Steel specifics (p. 31)
- **Forces:** Defender = two Northwind Highlander lances, all Skill 3.
  Command Lance: Atlas AS7-S4, Archer ARC-7C, Warhammer WHM-8R, Blackjack BJ-5.
  Recon Lance: Wraith TR5, Wasp WSP-5A, Phoenix Hawk PXH-4M, Locust LCT-7V.
  Attacker = Jade Falcon Battle Star: Warhawk T (Skill 1), Timber Wolf T, Nova T, Pouncer T,
  Fire Moth G (Skill 2 each).
- **Terrain:** each player picks 3 trees, 3 small buildings, 3 large buildings. The Attacker
  places first. Players alternate **two pieces at a time**, all within **24" of center**. Any
  trees within 4" of another tree (whoever placed them) join into a woods template.
- **Deployment:** the Attacker places one 'Mech at least 24" from center toward their home edge,
  then the Defender places two, alternating like this until all are down.
- **Victory:** the first force to cripple or destroy all opposing 'Mechs wins.
- **Special rules:** Battlefield Support (**5 BSP each, secret**), **Forced Withdrawal** on
  (p. 12: crippled 'Mechs retreat toward the home edge, may still fire at enemies in range;
  crippled = no armor and at or under half starting structure (round up), or 0 damage at both M
  and L, or immobilized by crits; leaving the map = destroyed), **Formations** as above.
- **Unequal sides (8 v 5):** use the proportional alternation rule (p. 14). Its worked example is
  exactly 8 v 5 (1:1, 1:1, then 2:1 once the larger side has twice as many left to move).
- Box buildings default to Medium (small) and Heavy (large) unless the players change them.

---

## 5. Indirect Fire (IF#) and Rear-Firing (REAR#/#/#)

### IF# — no effect in the Quick-Start
- The QSR doesn't define IF at all: it isn't in the Special Abilities list (p. 25), and the
  list covers only abilities usable at QSR level. Anything not listed has no effect in the QSR.
- The AMS entry (p. 25) confirms that IF and LRM have no effect in the QSR. AMS still cuts 1
  damage (min 1) from attacks by a 'Mech **with** IF or LRM coming through the front arc.
- p. 24: damage from special abilities (HT, IF, REAR) can't be boosted by Overheat. The Timber
  Wolf example repeats that IF/LRM aren't improved by OV.
- **No spotters, no indirect to-hit modifiers, no IF range rules in the QSR.** Those are in
  *Commander's Edition*. Units with IF (e.g. Archer, Timber Wolf T) attack normally with their
  S/M/L damage and need direct LOS.

### REAR#/#/# — p. 25 [COMPUTE] — **built 2026-11-24** (`AttackKind.rearFiring`: before the forward shot, +1, REAR damage, no overheat; the forward shot loses the REAR value; `RearFiringTests`)
- The 'Mech may attack a target **outside its (front) firing arc** using the REAR damage values
  for the range bracket, with **+1 to-hit**.
- It may still make its normal forward attack the same turn, but **its forward damage that turn
  is reduced by the amount of REAR damage it can inflict** (point for point). This reduction
  comes **before** any Overheat bonus is added. (Read this as the full REAR value at the bracket
  used, whether or not the REAR attack hits.)
- Normal rules still apply: the rear-arc +1 damage if the shot enters the target's rear hex side
  (p. 21), range modifiers, and so on. REAR damage can't be boosted by Overheat (p. 24).
- **[OPEN]** The base rule is one attack per 'Mech per Combat Phase (p. 13). REAR is the
  exception that allows a second (rear) attack. Whether the two forward and rear rolls are
  separate (yes, by the text) and whether forward damage can go below 0 (clamp at 0) are
  implementation calls.
- Check the box cards for which 'Mechs actually have REAR before building UI for it.

---

## 6. ECM and Stealth (STL)

- **ECM: no effect in the Quick-Start** (named on p. 25 among this box's specials that don't work
  at QSR level, along with AC2/2/–, Omni, LRM1/1/1 and LRM1/1/2).
- **STL (p. 25; modifier table p. 20):** attacks against an STL target take **+0 at Short, +1 at
  Medium, +2 at Long** on top of the normal range modifier. [COMPUTE]

---

## Related to-hit references (pp. 18–20)
Range: Short ≤6" +0, Medium >6–24" +2, Long >24–42" +4. Attacker: standstill/immobile –1,
jumping +2. Target: TMM; jumped +1 more; standstill +0; immobile –4. Woods +1 (intervening >2"
from the attacker, or target in woods; woods never give partial cover). Partial cover +1.
Attacker heat +heat level. Fire-control hit +2 each. Rear hit = +1 damage.

---

## What the app should track vs. leave to the table

| Rule | Impact | Implementation |
|---|---|---|
| Building move cost (+1/+2/+3/+4 per inch) | Movement | **Implement**: movement-cost helper / terrain picker |
| No ending move in a building | Movement legality | Coach note (app doesn't track position) |
| Building damage from moving through (1/inch) | Building CF | Optional building CF tracker; otherwise table |
| Climbing / jumping onto roofs (≤2" level change, jump ≥ height) | Movement | Coach note; level-change cost goes in the movement helper |
| Weight capacity in Size | Collapse trigger | Table bookkeeping (a helper could sum Sizes) |
| Collapse damage (value x floor(height/4), min 1; +1 on roof) | **Damage** to 'Mechs | **Implement** a small calculator that applies damage to affected units |
| Attacking a building (immobile –4) | **To-hit** | **Implement**: "target is a building/immobile" option; damage goes to a CF counter |
| Building partial cover (+1) / LOS block | **To-hit** | **Implement**: existing partial-cover toggle (no new math) |
| BSP budget (5 each), secret picks, one-time use | None | **Track** a per-player hidden inventory with used checkboxes; enforce the 5-point cap |
| BSP TN (flat 2D6 vs 5/6/7/8, no mods) | To-hit (own) | **Implement** a separate flat-TN resolver that applies none of the normal modifiers |
| BSP damage (1 or 2) / AoE / scatter (1D6 direction, 1D6 x 2 inches) | **Damage** | **Implement**: apply damage to chosen units; scatter roll helper; AoE contact is a table call |
| BSP timing (Combat Phase) | Phase flow | Coach note in the Combat Phase |
| Command Lance Initiative reroll (once/turn while Atlas alive) | Initiative | Track an availability flag tied to Atlas status; note the p. 38 conflict |
| Combat Intuition (2 'Mechs, not Atlas; once per 3 turns; attack in Movement Phase, immediate effects) | Phase order + **damage timing** | **Implement**: designation at setup, per-'Mech cooldown, and an "attack now" flow that applies damage immediately |
| Formation bonus lost below 3 surviving 'Mechs | Gating | **Implement**: auto-disable bonuses when fewer than 3 'Mechs survive |
| Recon Lance Maneuvering Ace (woods –1"/inch) | **Movement** | **Implement** in the movement-cost helper for those 4 'Mechs |
| Battle Star Lucky (7 uses, attack rolls only) | Dice reroll | Track a shared counter; reroll button on attack results |
| IF# | None in QSR | Show as "no effect in Quick-Start"; still counts for AMS |
| AMS vs IF/LRM attackers (–1 dmg, min 1, front arc) | **Damage** | **Implement** if not already |
| REAR (+1 to-hit; forward damage minus REAR damage, before OV) | **To-hit + damage** | **Implement**: rear-attack mode and forward-damage reduction |
| ECM | None in QSR | Show as "no effect in Quick-Start" |
| STL (+1 M / +2 L) | **To-hit** | **Implement** automatically from the target's specials |
| Forced Withdrawal / crippled check | State | **Implement** a crippled flag (armor 0 and structure ≤ half, or M and L = 0, or immobile) plus a retreat reminder |
| Unequal alternation (8 v 5) | Move order | **Implement** if the app sequences activations; otherwise coach note |
| Deployment / terrain picks / victory | None | Checklist / coach notes |
