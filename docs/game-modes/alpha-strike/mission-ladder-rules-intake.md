# Mission ladder — rules intake (Missions 3–5)

Missions 3–5 stay "Coming soon" until everything below is confirmed.

**Sources**
- Cards: Master Unit List (§1).
- Rules: *Alpha Strike Box Set Quick-Start Rulebook*, 3rd printing. Page numbers below are the printed page numbers.
- The PDF is the user's copy in `ongoing/` and is not committed to the repo.

**Status:** answered from the rulebook on 2026-11-24. P5 settled by the owner: rear +1 applies to any successful attack, punches and kicks included. Mission 4 is built (§3).

## 1. Cards (Master Unit List, Alpha Strike card)

**Done, checked 2026-11-24.** The Catapult came from the page you saved (`ongoing/Catapult CPLT-C1 · BattleTech.pdf`), which includes the card image. The other three came from each unit's page on masterunitlist.battletech.com (`/units/thunderbolt-tdr-5s`, `/units/awesome-aws-8q`, `/units/battlemaster-blr-1g`).

| Field | Catapult CPLT-C1 | Thunderbolt TDR-5S | Awesome AWS-8Q | BattleMaster BLR-1G |
|---|---|---|---|---|
| PV | 32 | 36 | 39 | 40 |
| SZ | 3 | 3 | 4 | 4 |
| MV | 8″j | 8″ | 6″ | 8″ |
| TMM | 1 | 1 | 1 | 1 |
| S / M / L | 2 / 3 / 2 | 3 / 3 / 1 | 3 / 3 / 3 | 3 / 3 / 1 |
| OV | 1 | 1 | 0 (none listed) | 1 |
| Armor / Structure | 5 / 5 | 7 / 5 | 8 / 6 | 8 / 7 |
| Specials | IF1, LRM1/1/1 | IF1 | ENE | REAR1/1/- |
| Role | Missile Boat | Brawler | Sniper | Brawler |

Skill: the Catapult card prints 4. The other three pages don't list a skill, so 4 is assumed, as on the Ridge Line cards.

The Awesome's card image didn't load in the browser. Its OV 0 is based on the stat chips, which list OV for the other three but not for it.

With these, Mission 3 has enough 'Mechs that can overheat. The Catapult, Thunderbolt and BattleMaster have OV 1, as does the Wolverine.

## 2. Overheat and heat (Mission 3, Running Hot)

| # | Question | Rulebook answer | App today |
|---|---|---|---|
| H1 | Overheat damage bands | Short and Medium; Long only with OVL. Announced before the roll, from 1 up to the card's OV. Overheat can't add to special-ability damage (HT, IF, REAR) or to physical attacks (p. 24) | Bands match. No OV picker on the shot screen yet |
| H2 | Heat gained | 1 heat per OV point used. It goes on in the End Phase, so it affects the *next* turn, not the shot that caused it (p. 24) | Not tracked |
| H3 | To-hit effect | + current heat level to weapon attacks. Doesn't apply to physical attacks (pp. 20, 24) | Done for weapons |
| H4 | Movement effect | MV −2″ per heat level. TMM −1 at heat 2 or more. Neither applies to jumping moves (p. 24) | Not done |
| H5 | Heat 4 | Shutdown. Next turn the 'Mech can't move or attack, and it counts as immobile (−4 to hit it) (p. 24) | Not done |
| H6/H7 | Cooling and restart | End Phase, in this order: (1) add OV used this turn, (2) −1 if standing in water, (3) clear all heat if it made no weapon attack this turn, (4) if it started the End Phase shut down, clear all heat and restart it (p. 24). Heat does **not** tick down by 1 a turn. You cool off by not firing for a turn | Not done |
| H8 | Engine hit | 1 heat in the End Phase of any turn the 'Mech fired, on top of any OV heat. A second engine hit destroys it (p. 23) | Adds the heat right away when it fires, not in the End Phase. Should move to the End Phase |
| H9 | Jumping or sprinting heat | None in these rules | Matches |

## 3. Physical attacks (Mission 4, Close Quarters)

**Status: built.** Standard attacks (punch or kick) are on the shot sheet when the mission allows them. MEL (Size + 1, 2″) is supported for cards that list it. Charge and Death From Above are left out; the copy says they're not in this mission. Rules as the app applies them: GuidedMissionSpec, Physical attacks.

| # | Question | Rulebook answer |
|---|---|---|
| P1 | Reach | **Standard** (punch or kick): within 1″, target in the front arc. **Melee** (only for cards with MEL, which none of the eight box cards have): within 2″, counting any height difference. **Charge and Death From Above:** must end in base-to-base contact, and are declared in the Movement Phase against a 'Mech that has already moved. Weapon attacks aren't allowed in base-to-base contact (pp. 20, 22) |
| P2 | Timing | Combat Phase. Each 'Mech makes **one** attack a turn: weapon *or* physical, never both (pp. 18, 22) |
| P3 | To-hit | Skill + attacker move + target move + terrain or cover. No range modifier. Heat and fire-control modifiers don't apply. Charge and Death From Above are +1 (pp. 20, 22) |
| P4 | Damage | Standard = Size. Melee = Size + 1. Charge = Size + ½ TMM (round down); the attacker takes ½ its own TMM (round down), +1 if the target is Size 3 or more. Death From Above = Charge damage + 1, always gets a critical roll; the attacker takes its own Size, or Size + 1 on a miss. Weapon hits don't lower physical damage, and overheat can't add to it (pp. 22–24) |
| P5 | Rear hits and criticals | Criticals: yes, any hit that damages structure rolls (p. 23). Rear +1: stated in the weapon-damage step ("any successful attack"). **Owner decision: applies to physical attacks too.** Built |
| P6 | Charge and Death From Above in Mission 4? | Left out. They need a Movement-Phase declaration and self-damage. Standard physical attacks only. Built |

## 4. Forced Withdrawal (Mission 5, Full Lances)

| # | Question | Rulebook answer |
|---|---|---|
| W1 | Crippled | Any one of: no armor left and structure down to half its starting value (rounded up); Medium **and** Long damage both 0; immobilized by critical hits (p. 12) |
| W2 | What it must do | Always move toward its home edge (sprinting not required). It may still attack enemies in weapon or physical range (p. 12) |
| W3 | Leaving the table | Any 'Mech that leaves the play area, for any reason, counts as destroyed and can't come back (p. 12) |

## 5. Mission design (my defaults, change anything)

| Mission | Forces | Turns | Rules on |
|---|---|---|---|
| 3 Running Hot | 2 vs 2. Ridge Line cards plus the OV-capable new cards from §1 | 8 | Overheat, heat scale, shutdown |
| 4 Close Quarters | 3 vs 3. Awesome, BattleMaster, Locust vs Thunderbolt, Wolverine, Shadow Hawk (PV 97 vs 98). Built | 8 | + physical attacks (overheat stays on) |
| 5 Full Lances | 4 vs 4. All eight box 'Mechs | 10 | Everything, + Forced Withdrawal |
