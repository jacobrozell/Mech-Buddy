# Ridge Line play session — 2026-11-19

Device: iPhone 17 simulator (`C3CA7CF6-…`). Fresh Debug build from current source (installed build was from 2026-11-01).
Player (Jacob) = Side B: Wolverine WVR-6M + Locust LCT-1V. App drives Side A: Shadow Hawk SHD-2H + Commando COM-2D. Side B goes first by request.

## Running notes (UI/UX, gameplay, polish, confusion)

1. **[UI] Start battle dock still covers checklist steps 3–5 on first view** (`02-after-play.png`). Same as 11/18 note #5 — not fixed yet. Scroll reveals all (`03-briefing-checklist.png`). Suggest bottom content inset = dock height, or put the button inline at the end.
2. **[Copy] Checklist step 5 says you place 'Mechs "after the first dice roll"** but there's no "go first" choice on the briefing — the first roll (initiative) decides who places. If the players want to pick who goes first, there's no affordance.

## Screenshots
- `01-launch.png` — Play home
- `02-after-play.png` — briefing, dock over checklist
- `03-briefing-checklist.png` — scrolled checklist + How you win
3. **[UI] Phase chips still clip on iPhone 17** — "Shoo / t", "Clea / n up" (`05-battle-start.png`). Same as 11/18. Needs `lineLimit(1)` + `minimumScaleFactor`, or icon-only chips for non-active phases.
4. **[UI] "Roll for initiative" title is tucked under the turn/phase header** at first load (`05-battle-start.png`) — scroll position starts slightly too low, or the header overlaps content.
5. **[Gameplay/Confusion] No way to say "Side B goes first."** Initiative copy says "higher total moves last — that's the advantage." A player who wants to go first has to roll low or fudge the dice. Consider a "We agreed who goes first" shortcut for casual/learning games.
6. **[UI] "Let the app roll" link sits under the dock** and is mostly hidden (`05-battle-start.png`).
7. **[Copy/Confusion] Initiative result button reads "Side B wins — start moving"** while the banner above says "Side A moves first" (`09-initiative-entered.png`). Reads like Side B should start moving. Suggest "Side A moves first — start" or "Start moving (Side A first)".
8. **[UI] Initiative: Side B's second-die row starts under the dock** — have to scroll to finish entering dice (`07-initiative-partial.png`).
9. **[UI] Placement diagram is left/right** (A strip left, B strip right) but on a real table the 'Mechs face across the short edges — fine for landscape, but on the 11/19 table the maps run top-to-bottom. Minor; could label "your short edge" instead of implying orientation.
10. **[UI] Move screen: "Skip remaining" dock covers the Move order list** (`11-after-placed.png`, `12-shadowhawk-walked.png`) — can't read who's next without scrolling.
11. **[UX] No undo after tapping a move mode.** Tapping Walk for Shadow Hawk immediately advanced to Wolverine with no confirm/undo toast. A mis-tap on a big tile is easy at the table.
12. **[Data] Shadow Hawk tile shows "6″ jump"; Wolverine shows "10″ walk or jump"** — consistent with cards, good. Sprint "about 15″" is a rounded estimate (10×1.5) — fine.

## Game log
- **Initiative T1:** Side A 1+2 = 3 (simulated), Side B 3+2 = 5 (Jacob). Side B wins → Side A places/moves first.
- **Deployment (`06-table-deployed.jpg`):** Open Terrain #2 (Side A, top) + #3 (Side B, bottom). Shadow Hawk ~0512 by the ridge, Commando ~0404. Wolverine by the lake on #3, Locust lower-left on #3.
- **T1 move — Shadow Hawk:** Walk 10″ down-table toward the heavy woods cluster (~1113/1114 on #2).
13. **[Data ✅] Card check (`13`–`16-card-*.jpg`)** — all four bundled units match the printed cards: PV, MV, TMM, SZ, S/M/L, OV, armor, structure, and Commando SRM1/1. Only quirk (same as 11/18): Shadow Hawk bundle lists `JMPW1` that isn't on the card's Special line; Wolverine card TMM 2/3 is stored as 2 (+1 when jumping = 3, matches).
14. **[Confusion] Physical cards have a blank SKILL line;** the app assumes skill 4 but nowhere on the move screen says so. A small "Skill 4" chip on the unit card (or in the briefing roster) would help players fill in their cards.
15. **[Gameplay — BIG] App forces a fixed unit order within each side.** Jacob asked "Do I have to move my Wolverine, or can I move the other one?" In Alpha Strike the player picks which of their units to activate each alternation. `MovementStep.current` is just `unitsNeedingMove(side:).first` (roster order), and the "Move order this turn" list is read-only except "Change" on finished rows. Fix: make the next-up rows for the active side tappable ("Move this one instead"), or show both of that side's unmoved units as choices.
    - Workaround used this game: tap a placeholder mode on the forced unit, then fix it later with the row's **Change** menu.
- **T1 table (`17-table-after-shadowhawk.jpg`):** Shadow Hawk walked to ~1215 on #2, next to the heavy/light woods at 1114/1213. Commando still at ~0405.
16. **[UX ✅] End-of-move summary is good** (`22-all-moved.png`): every row has **Change**, and nothing advances until "Start shooting". This is what makes the note-15 workaround possible.
17. **[Copy] End-of-move header still says "Side B moves" / "Side B is up"** with "Everyone has moved." under it. Should read "Movement done" and drop the "is up" side badge until shooting starts.
- **T1 move — Locust (Jacob, out of app order):** Walked ~1216 → ~0515 on #3, beside the heavy woods 0415 (`18-table-locust-moved.jpg`).
- **T1 move — Wolverine:** "Walk" entered as a placeholder (app forced it next); fix with Change after it actually moves.
- **T1 move — Commando:** Walk 12″ down-table into the light woods on the #2 ridge (~1107/1206).
- **T1 end of move (`23-table-end-move-t1.jpg`, photo rotated: #3 left, #2 right):** Wolverine walked ~1107 → ~0809 on #3, by the light woods 0808 (placeholder Walk was right). Commando walked to ~1307 on #2 by the ridge woods. Shadow Hawk ~1414 on #2. Locust ~0515 on #3.
18. **[UI — mis-tap] Shoot list shifts up ~50pt right after it appears** (the "Side A's turn — pass the phone" pill goes away). My tap on Shadow Hawk's **Shoot** landed on the Commando card and opened its sheet instead (`25-shot-solver.png` vs `26-shoot-list.png`). Same thing will happen to a fast finger. Keep the pill's space reserved, or don't animate it out.
19. **[UI — Jacob wants this] Solve-a-shot picker: switch the 2-up HStack cards to a VStack list of full-width cards** (Jacob, mid-game: "could be improved a lot"). Today the tiles hyphenate names badly on iPhone: "Shad/ow/Hawk/SHD-/2H", "Com-/man-/do", "Wolve/rine", "Lo-/cust/LCT-1/V", and the moved chip shows "W …" (`27-shot-solver-shadowhawk.png`). Use one column, or drop the variant (SHD-2H) to a second line with `lineLimit(1)`, and use icon-only moved chips.
20. **[UX] Range defaults to Short ≤6″** in the solver (`28-solver-target-locust.png`). A default that happens to give the best number invites skipping the tape measure. Suggest no default (force a pick), or default to Medium.
21. **[UI] Solver sticky "NEED 7+" card covers the Conditions/Range rows while scrolling** (`29-solver-conditions.png`). Hard to see what you're toggling and how the number changes at the same time. A compact sticky header (just "7+ · 58%") once scrolled would fix it.
22. **[UI ✅] "If this hits" preview** (2 dmg → armor 2/2 → 0/2, with the crit note) is clear and useful.
23. **[Data ✅] Unit sheet shows SKL 4** (`25-shot-solver.png`), which partly answers note 14 — it's just not on the move/briefing screens.
- **Correction (`32-table-measure-sh.jpg`):** I had the minis swapped. The orange mini is the **Locust** (now ~0809 on #3, light woods), and the white mini at ~0515 is the **Wolverine** (heavy woods). Both walked, so the app record is unchanged. Measured: Shadow Hawk → Locust 13″, Shadow Hawk → Wolverine ~9″, woods in the way on both.
24. **[Idea] A mini ↔ unit hint would help** with proxies / unpainted minis. My mix-up (white Wolverine, orange Locust) would happen to any newcomer reading the table. Let players set a color/label per unit at setup ("orange base = Locust"), and show it on unit chips.
25. **[UX] Solver "Change" clears the shooter too.** I tapped Change to swap only the target and had to pick Shadow Hawk again (`33-solver-sh-wolverine.png`). Changing the target should keep the shooter.
26. **[UI] First tap on the Range "Medium" segment didn't register;** the second did (`35`/`36`). Might be a scroll-gesture conflict inside the sheet. Worth checking.
27. **[UI ✅] Woods toggle and the live % update are clear** (8+ 42% → 9+ 28%), and the "Apply 2 damage" button label confirms the result. Nice.
- **T1 shot — Shadow Hawk → Wolverine:** medium (~9″), woods, target walked → **9+**. Rolled 5+6 = 11, **HIT**, 2 damage. Wolverine armor 6 → 4 (`40-solver-rolled.png`, `41-after-apply.png`).
- **T1 shot — Commando → Wolverine:** medium (~15″), no woods reported, target walked → **8+**. Rolled 2+3 = 5, **MISS** (`46-commando-miss.png`).
28. **[UI ✅] Result chips on shooter rows** ("Hit Wolverine WVR-6M · 2" green, "Missed Wolverine WV…" red) are a great at-a-glance log, but the miss chip truncates (`47-after-commando.png`).
29. **[Gameplay/Clarity] Shots are simultaneous in Alpha Strike, but the Wolverine already shows 4/6 armor while Side B is lining up to fire back** (`48-side-b-shoots.png`). The rules are fine (damage doesn't stop it firing), but a newcomer may think a damaged unit fires weaker. A small "fires this turn even if destroyed" hint on damaged Side B shooters would help.
- **T1 shot — Wolverine → Shadow Hawk (Jacob):** medium (9″), woods → **9+**. Rolled 4+3 = 7, **MISS**.
- **T1 shot — Locust → Shadow Hawk (Jacob):** medium (14″), no woods → **8+**. Rolled 6+4 = 10, **HIT**, 1 damage. Shadow Hawk armor 5 → 4.
- **End of T1 (`64-cleanup.png`):** Shadow Hawk A4/5 S5/5 · Commando 2/2 2/2 · Wolverine A4/6 S5/5 · Locust 2/2 2/2.
30. **[UI — mis-tap] Solver: tapping "Woods" right after scrolling opened "More…" instead** (layout still settling), so the toggle didn't take (`52-wolverine-first-die.png`). Same family as notes 18/26: controls move under the finger during scroll/animation.
31. **[UI] Solver dice rows hide under the sticky NEED card on short scroll positions.** To enter both dice I had to scroll down, tap die 2, then scroll back up for die 1 (`54`–`57`). Suggest putting the dice (or a compact "Roll: _ _") right under the NEED card, or shrinking the sticky card once scrolled (see 21).
32. **[UX ✅] Clean-up screen is a nice end-of-turn recap:** every unit with its hit/miss chip and current armor/structure in one list (`64-cleanup.png`).
33. **[Copy] Clean up says "Take wrecked 'Mechs off the table."** (`65-cleanup-top.png`) even when nothing was wrecked. When no unit is wrecked, say "Nothing wrecked — tap Next turn" so first-timers don't go looking for something to remove.
- **T2 initiative:** Side A 2+2 = 4, Side B 5+1 = 6. Side B wins again → Side A moves first.
34. **[UI] Turn 2 move screen opens already scrolled down.** The "Side A moves" header and the "Now moving: Shadow Hawk" name are off-screen; only "10″ walk · 6″ jump" shows (`71-turn2-move.png`). The scroll position carried over from the initiative screen. Reset to top on each phase change.
35. **[UI] A swipe on the initiative screen sometimes doesn't scroll** (first try failed, slower second swipe worked, `68`/`69`). Low-confidence: may be the simulator, worth a look on device.
- **T2 move — Shadow Hawk:** Walk 1 hex into the heavy woods at ~1316 on #2 (cover; woods cost double).
- **T2 moves (`73-table-t2-moves.jpg`):** Shadow Hawk walked into the heavy woods ~1316 (#2). Wolverine walked into the heavy woods ~0415 (#3). Commando walked to ~1410/1511 (#2), near the seam. Locust walked into the light woods ~0708 (#3). App order (SH → Wolverine → Commando → Locust) happened to match this turn.
- **T2 shot — Shadow Hawk → Wolverine:** medium (~7″), light woods in the way → **9+**. Rolled 1+2 = 3, **MISS**.
- **T2 shot — Commando → Wolverine:** medium (~7″), open shot → **8+**. Rolled 1+5 = 6, **MISS**.
36. **[UI — BUG, reproducible] Solver: the bottom half of the "Woods" chip toggles "More…" instead.** Tapping Woods at its visual centre (y≈651) opened/closed More… twice in a row; tapping ~10pt higher (y≈640) worked (`80`–`82`). The chips row and the More… disclosure hit areas overlap. Probably the same cause as note 30. Give the chips a 44pt min height and add spacing before More…
37. **[UI] Solver second-die row sits behind the floating Apply dock** at some scroll positions. A tap there hits the dock's blur, not the die (`84-t2-sh-rolled.png`). Needs bottom content inset = dock height.
38. **[UI ✅] New "Shot feed" at the top of the shoot list** ("3 vs 9+ · Shadow Hawk missed Wolverine") is a great running log (`91-t2-after-commando.png`).
39. **[UI] Commando's "Shoot" button was half under the dock** (`87-t2-after-sh.png`). Same inset issue as 37 and 10.
40. **[UX — Jacob, overall] "I don't like a lot of the UI with how cluttered it is."** Hot spots this game: the shot solver (2-up cards, sticky NEED card, chips, More…, dice, preview, and the dock all on one sheet), the move screen (four big tiles plus the order list under a dock), and the battle header (Leave, title, log, ⋯, turn ring, side badge, and four phase chips). Direction: one decision per screen, full-width rows, fewer floating docks.
41. **[Rules/UX] Range bands leave a gap between 6″ and 7″.** The solver shows "Short ≤6″" and "Medium 7–24″". Players say "within 7 inches", and a 6.5″ shot has no obvious band. Label them "Short 0–6″ · Medium over 6–24″ · Long over 24–42″".
- **T2 Side B targets:** both shoot the Commando. Locust → Commando measured ~7″ with a clear angle (`93-table-locust-to-commando.jpg`), so medium range.
- **T2 shot — Wolverine → Commando (Jacob):** medium (~7″), open → **8+**. Rolled 5+3 = 8, **HIT**, 2 damage. Commando armor 2 → 0.
- **T2 shot — Locust → Commando (Jacob):** medium (~7″), open → **8+**. Rolled 5+4 = 9, **HIT**, 1 damage to structure (2 → 1) → crit owed.
- **T2 crit — Commando (me):** rolled 4+2 = 6, **Weapon hit**. Commando damage 2/2/0 → 1/1/0.
- **End of T2 (`107-t2-cleanup.png`):** Shadow Hawk A4/5 S5/5 · Commando A0/2 S1/2, Weapon ×1, dmg 1/1/0 · Wolverine A4/6 S5/5 · Locust 2/2 2/2.
42. **[UX ✅] Crit flow is excellent:** a blocking "Critical hit" card, then a dice sheet with the result in plain words ("Weapon hit. Its damage goes down."), and the unit sheet shows "Weapon ×1" and "DMG 1·1·0 ↓" (`101`–`108`).
43. **[UI] Crit dice sheet opens at medium height with the second-die row under the Apply button.** I had to drag the sheet up to reach it (`102`/`103`). Open it at full height, or put the dice above the fold.
44. **[Copy] Crit prompt says "Roll two dice before anyone else shoots."** In Alpha Strike, fire is simultaneous, so it reads as if the crit changes this turn's remaining shots. It doesn't for damage this turn. Suggest "Roll now so you don't forget."
45. **[UI] Crit results aren't in the Shot feed, and the Clean-up row shows no crit badge.** The Commando's row only shows "Missed Wolverine"; you have to open the sheet to see Weapon ×1 (`107`). Add a small crit chip to unit rows.
46. **[UI] "Locust" Shoot button was fully under the dock**, so I had to go through "Solve a shot" instead (`97-t2-after-wolv.png`). Same inset issue as 10/37/39.
- **T3 initiative:** Side A 3+4 = 7 (entered); waiting on Side B.
- **T3 initiative, first roll:** Side A 3+4 = 7, Side B 4+3 = 7 → **tie, both reroll**. Side A reroll: 4+6 = 10 (entered).
47. **[UX ✅] Ties are handled well:** a "Tie at 7 — both sides roll again" banner with a **Clear dice** button (`115-tie-banner.png`).
48. **[UI] On a tie, the dock still says "Enter all four dice"** (disabled) though all four are entered. It should say "Tie — roll again" so the dock and the banner agree.

## Landscape pass (Jacob asked: screenshot each screen in landscape) — files `L##-*.png`
L1. **[UI — BROKEN] Battle screen in landscape uses a 2-column split with a unit-card rail on the left that's clipped.** A second card peeks in cut off at the column edge, and the cards use the narrow hyphenating layout ("Shad-/ow/Hawk/SHD-/2H", moved chip "W …") (`L01-initiative-tie.png`).
L2. **[UI — BROKEN] Usable height in landscape is ~150pt.** The header (Leave / title / log / ⋯ plus the Turn row) takes the top ~150pt and the floating dock takes the bottom ~100pt, so only one die row is visible at a time, and the dock sits on top of the second-die row (`L02-initiative-scrolled.png`).
L3. **[UI] Rotating resets scroll to the top.** The tie banner I was looking at scrolled out of view, so rotating mid-step loses your place (`L01`).
L4. **[UI] Landscape swaps the phase chips for "Step 1 of 4 · Roll"** — actually cleaner than the clipped portrait chips. Consider the same text in portrait (see note 3).
- **T3 initiative reroll:** Side A 4+6 = 10, Side B 2+1 = 3. **Side A wins → Side B moves first** (`118-t3-initiative-done.png`). This time the dock copy ("Side A wins — start moving") reads fine because Side B's unit is up next, but see note 7.
L5. **[UI — BROKEN] Move screen in landscape: the move tiles (Stood still / Walk / …) sit entirely under the "Skip remaining" dock.** Only the top edges of two tiles peek out, and "10″ walk or jump" is blurred behind the dock (`L03-move.png`). You can't make the main choice of the screen without scrolling.
L6. **[UI] The landscape left rail shows the Shadow Hawk (Side A) while the Wolverine (Side B) is moving.** The rail doesn't follow or highlight the active unit, so it's dead space (`L03`). Either drop the rail on compact-height, or make it the move-order list.
49. **[Confusion — rules] Jacob asked: "Anything bad happen when the Commando goes down? Does it explode an AoE?"** (Answer: no. In standard Alpha Strike a destroyed 'Mech just comes off the table. The app only models an Ammo-hit crit, which destroys that unit itself unless it has CASE/ENE, and nothing spreads to neighbours.) The app has no quick answer to this. The wreck notice / Clean-up card could add one line: "Destroyed 'Mechs don't explode or hurt nearby units — just remove the mini." Or add a "What happens when a 'Mech is destroyed?" Rules topic.
- **T3 moves (`120-table-t3-locust.jpg`):** Wolverine **stood still** in the heavy woods ~0415 (#3). Shadow Hawk **stood still** in the heavy woods ~1316 (#2). Locust walked into the heavy woods ~0110 (#3), about 3″ from the Commando. Commando walks a couple of inches into the light woods ~1410/1510 (#2) to keep TMM 2 plus woods.
L7. **[UI] Landscape move summary: the "Start shooting" dock covers the Commando row and its Change button.** Only Shadow Hawk and Wolverine are partly visible. The rail's moved chip truncates to "St …" for Stood still (`L04-move-summary.png`).
- **T3 Side A shots, rolled up front:** Shadow Hawk → Wolverine (~7″ medium, Wolverine stood still in heavy woods, SH stood still) rolled 4+6 = 10. Commando → Locust (3″ short, open) rolled 3+5 = 8. Waiting to enter them until Side B fires.
50. **[Gameplay] The app makes the side that moved first shoot first, and gates the other side until "Done shooting"** (`126-t3-shoot.png`). Fire is simultaneous in Alpha Strike, so order doesn't matter for the rules, but at the table both players often roll at once. Letting "Solve a shot" pick a shooter from either side would match how people play.
L8. **[UI — BROKEN] Landscape shoot list is empty.** Below "Side B shoots…" there's blank space, and then the Done shooting / Solve a shot dock. No shooter rows or Shoot buttons appear at all (`L05-shoot-list.png`). The content may be off the bottom with no scroll hint.
- **T3 shot — Wolverine → Commando (Jacob):** medium, Wolverine stood still, Commando walked in light woods → **8+**. Rolled 3+2 = 5, **MISS**.
- **T3 shot — Locust → Commando (Jacob):** short (3″), Commando in light woods → **7+**. Rolled 3+1 = 4, **MISS**.
- **T3 shot — Shadow Hawk → Wolverine:** medium, both stood still, Wolverine in heavy woods → **6+**. Rolled 4+6 = 10, **HIT**, 2 damage. Wolverine armor 4 → 2.
- **T3 shot — Commando → Locust:** short (3″), open → **7+**. Rolled 3+5 = 8, **HIT**, 1 damage (post-crit). Locust armor 2 → 1.
- **End of T3:** Shadow Hawk A4/5 S5/5 · Commando A0/2 S1/2 (Weapon ×1) · Wolverine A2/6 S5/5 · Locust A1/2 S2/2.
51. **[Rules ✅] Attacker "stood still" −1 and target "stood still" TMM 0 both apply in the solver** (Shadow Hawk → stationary Wolverine was 5+ before woods, `141-t3-sh-vs-wolv.png`). Correct per Alpha Strike.
52. **[UI] "First swipe after a tap doesn't scroll" is reproducible in the solver sheet.** After toggling Woods, the first drag does nothing and the second works (`134`–`136`, `141`/`142`). Likely a gesture conflict between the sheet's drag-to-dismiss and the inner ScrollView.
L9. **[UI — BROKEN] Landscape clean-up is also empty:** no "Standing" list and no damage recap, just "Take wrecked 'Mechs off the table" and Next turn (`L06-cleanup.png`). Same as L8: the list content of these phases doesn't render (or is pushed off) in the compact-height layout, and the left rail shows only one clipped unit.
53. **[UI] "Next turn" ignored my first tap right after rotating back to portrait** (`151` vs `152`). Low-confidence — may be rotation settling in the simulator.
- **T4 initiative:** Side A 1+4 = 5 (entered); waiting on Side B.
- **T4 initiative:** Side A 1+4 = 5, Side B 6+2 = 8 → Side B wins, Side A moves first.
- **T4 moves:** Shadow Hawk stood still · Wolverine stood still · Commando walked (shuffled inside its light woods) · Locust stood still.
- **T4 shot — Commando → Locust:** short (3″), Locust stood still → **4+**. Rolled 4+1 = 5, **HIT**, 1. Locust armor 1 → 0.
- **T4 shot — Shadow Hawk → Locust:** medium, both stood still, Locust in heavy woods → **6+**. Rolled 6+5 = 11, **HIT**, 2. Locust structure 2 → 0 → **LOCUST DESTROYED** (still fires this turn).
- **Locust crit (forced by app):** rolled 1+3 = 4, Fire control.
54. **[BUG] The app asks for a critical roll on a unit its own damage just destroyed.** Locust went to 0/0, and the app still showed the blocking "Critical hit · Crit owed" card and made us roll, getting "Fire control" (`171`–`174`). A crit on a destroyed unit is meaningless. Skip the crit when structure hits 0, or label it "Destroyed — no crit needed".
55. **[UX ✅] "Wrecked · still fires" chip on the Locust in Side B's shooter list** (`176-t4-side-b-shoots.png`). It nails simultaneous fire and answers note 29's worry. Lovely.
56. **[Rules question] Does the Locust's new Fire-control crit (+2 to-hit) apply to its shot this same turn?** In Alpha Strike, crit effects apply at the end of the phase, so its simultaneous return fire shouldn't be penalized. Check the solver below.
57. **[Copy — Jacob] "Everyone has moved" / "has moved" is misleading when a unit stood still.** Jacob: "has moved is misleading when I didn't actually move." Reword to "Movement locked in", "Everyone's move is set", or "Moves decided". Same idea for the move-order labels ("Now / Next / Later" is fine; the done state could read "Stood still ✓" rather than implying it moved).
- **T4 shot — Wolverine → Commando (Jacob):** medium, Wolverine stood still, Commando walked in light woods → **8+**. Rolled 5+4 = 9, **HIT**, 2 → **COMMANDO DESTROYED**.
- **Commando crit (forced again, bug 54 reproduced):** used "Let the app roll" → 6 = Weapon hit.
- **T4 shot — Locust (wrecked) → Commando (wrecked) (Jacob):** short, stood still, woods → **8+** (includes +2 from the Locust's Fire-control crit). Rolled 6+3 = 9, **HIT**, 1 (overkill). No crit prompt this time.

### Edge cases tested this turn (Jacob: "that's more of what this is about")
58. **[RULES BUG] Fire-control crit taken this turn penalizes the same turn's return fire.** The Locust's solver shows "O +2" (`190-t4-locust-vs-wrecked-commando.png`) for a crit it took from Side A's fire this phase. In Alpha Strike, damage and crits resolve at end of phase, so the wrecked Locust should fire at its pre-crit number (6+ before woods, not 8+). Same risk for Weapon-hit crits lowering damage mid-phase. Fix: snapshot shooter modifiers at the start of the phase (or apply crit effects in Clean up).
59. **[UX] "Let the app roll" is sticky across contexts.** I used it once on the Commando's crit sheet, and the next *shot* solver opened in "The app rolls — Roll" mode instead of dice faces (`191-t4-locust-cond.png`). A player with physical dice could easily tap Roll by habit. Make app-roll per-roll, or show a clear mode switch at the top.
60. **[UX/Fairness] App-rolled crits offer "Roll again"** right next to the result (`187-commando-crit-result.png`). That invites rerolling bad crits. Hide it once the result is shown, or require confirmation and log rerolls in the shot feed.
61. **[UX] Wrecked units can still be picked as targets** (`189`/`190`). That's fine for simultaneous fire, but there's no warning that the shot is overkill. The "If this hits" card for the 0/0 Commando still says "Armor absorbs it. A critical only happens on two 6s." (`192`), which is wrong for a wrecked target. Show "Already wrecked — this shot changes nothing" and dim the target tile.
62. **[✅] Overkill on a wrecked target does not trigger a second crit,** and the shot feed logs it cleanly (`195`). Good, but it contrasts with bug 54: the crit fires when the killing blow lands, not on later hits.
- **End of T4 (`196-t4-cleanup-wrecks.png`):** Shadow Hawk A4/5 S5/5 vs Wolverine A2/6 S5/5. Commando and Locust destroyed. It's now a 1v1.
63. **[UX] Clean-up "Still on the table" / "Picked up" is a state label posing as a button.** Tapping "Still on the table" flips it to "Picked up" (`197`). It reads like a status, not an action, and there's no checkbox affordance. Use a checkbox row: "☐ Picked up the Commando mini".
64. **[Edge] Next turn isn't gated on wrecks being picked up.** I advanced with the Locust still marked "Still on the table" and turn 5 started (`198`). That's fine if intentional, but then the toggle has no purpose. Gate it softly ("1 wreck still on the table — continue?") or drop the toggle.
65. **[Copy] In Clean up, wrecks still wear the "Wrecked · still fires" chip** (`196`). Shooting is over, so it should just say "Wrecked".
- **T5 initiative:** Side A 4+6 = 10 (entered); waiting on Side B.
- **T5 initiative:** Side A 4+6 = 10, Side B 6+4 = 10 → **tie** → reroll A 1+1 = 2, B 2+1 = 3 → Side B wins, Side A moves first.
66. **[UI] Second tie this game: the "Clear dice" button was under the dock** on first view (`201-t5-tie.png`). I had to scroll to reach it. Put "Tie — clear dice and roll again" in the dock itself.
67. **[✅] Wrecked units drop out of the move order** (only Shadow Hawk and Wolverine listed, `205-t5-move-1v1.png`).
- **T5 move — Shadow Hawk:** stood still in the heavy woods (−1 to hit, and Ridge Line tiebreak is Structure, so maximize hits).
- **T5 moves:** both stood still.
- **T5 shot — Shadow Hawk → Wolverine:** medium, both stood still, woods → **6+**. Rolled 3+6 = 9, **HIT**, 2. Wolverine armor 2 → 0.
- **T5 shot — Wolverine → Shadow Hawk (Jacob):** same modifiers → **6+**. Rolled 6+1 = 7, **HIT**, 2. Shadow Hawk armor 4 → 2.
- **End of T5:** Shadow Hawk A2/5 S5/5 vs Wolverine A0/6 S5/5. Structure tied at 5, so the Ridge Line tiebreak ("more Structure left wins") is a draw unless turn 6 lands structure damage.
68. **[UI] The shot feed carries the previous turn's shots into the new turn with no turn label.** At the start of T5 shooting, the feed showed T4's "Commando hit Locust" and "Locust hit Commando" (`208-t5-shoot.png`). Add "Turn 4" / "Turn 5" dividers, or clear the feed each turn behind a "Show earlier shots" link.
69. **[UX] The solver remembers the last target but resets range to Short every time** (`209`, `215`: 3+ / 97% until you pick Medium). With the same two 'Mechs at the same spot, Medium should be remembered too. Defaulting to the most generous range is the risky choice (see note 20).
70. **[UI] "Done shooting" ignored the tap right after "Apply"** (`213` vs `214`). The dock may still be animating after the sheet closes. Same family as 18/30/53.
71. **[UX ✅] Turn 6 shows a "⚠ Last turn" badge under the turn counter** (`222-turn6-initiative.png`). It's clear. It could also say the tiebreak ("Most Structure wins").
72. **[Edge ✅] Wrecks disappear from Clean-up the turn after** (T5 Clean up only lists Shadow Hawk and Wolverine, `221`), even though the Locust was never marked "Picked up" (note 64).
- **T6 initiative:** Side A 3+4 = 7 (entered); waiting on Side B.
- **T6 initiative:** Side A 3+4 = 7, Side B 6+4 = 10 → Side B wins, Side A moves first. **Shadow Hawk stood still.**
- **T6 moves:** both stood still.
- **T6 shot — Shadow Hawk → Wolverine:** medium, both stood still, woods → **6+**. Rolled 3+3 = 6, **HIT**, 2 to structure. Wolverine S 5 → 3 → crit owed (Jacob to roll).
73. **[UI] The T6 shot feed shows T4 shots (Commando↔Locust) and skips T5's** (`229-t6-shoot.png`). The "recent shots" ordering is wrong, not just unlabelled (see 68).
- **T6 mix-up:** Jacob's 5+5 was his Wolverine's *attack*, but I entered it as the Wolverine's crit (Fire control). Fixed with ⋯ → **Undo last change**, which restored "Crit owed" cleanly (`238`–`240`). The real crit roll is still to come; the 5+5 = 10 is the Wolverine's shot.

74. **[Confusion — Jacob] "Sorry confused. I get a second shot?"** The crit prompt for *your own* 'Mech pops up right after the *enemy's* shot, while it's still the enemy side's turn to shoot. Jacob read "Roll two dice" as his attack roll. Fixes: say whose dice ("**Side B rolls** for their Wolverine's crit"), add a "this is not a shot" line, and put the crit at the top of that side's own shooting step instead of mid-way through the other side's.
75. **[UX ✅] ⋯ → Undo last change cleanly reverted a wrongly applied crit** back to "Crit owed" (`239`/`240`). The undo is good but buried in ⋯. A 5-second "Undo" toast after Apply (shots, crits, moves) would catch most mis-entries, and would also cover note 11.
- **T6 Wolverine crit (Jacob, real roll):** 4+3 = 7, **MP hit** → Wolverine MV 10″j → 5″j, TMM 2 → 1 (`244`, `248`).
76. **[BUG] Double-tapping "Apply MP hit" raises a raw error alert: "Couldn't save the critical — No critical owed"** (`245-t6-side-b-shoots.png`). The first tap saved correctly; the second hit a dock button that was still enabled during the sheet dismissal. Disable the Apply button after the first tap, and make the store call idempotent with no alert. The copy is developer-speak either way.
77. **[Copy] The same crit has two names:** the crit sheet says "**MP hit**. It moves half as far", the unit sheet chip says "**Motive**" with "A motive hit halves move…" (`244` vs `248`), and the card prints "MP". Pick one term (the card's "MP").
78. **[UI] Crit sheet sometimes ignores the first drag-up on its grabber** (`241`/`242`). It needed a slower second drag. It's also the only way to reach the second die row, so it matters (see 43).
- **T6 shot — Wolverine → Shadow Hawk (Jacob):** medium, both stood still, woods → **6+** (MP crit correctly adds nothing to to-hit). Rolled 5+5 = 10, **HIT**, 2. Shadow Hawk armor 2 → 0.
- **FINAL (`257-victory.png`):** **Side A wins on structure, 5 vs 3** ("More structure left after turn 6"). Shadow Hawk A0/5 S5/5 · Wolverine A0/6 S3/5 (MP crit) · Commando and Locust wrecked. App stats: Shots 20 · Hits 14 (70%) · Crits 4. That matches my log exactly, and the undone crit wasn't counted.
79. **[UX ✅] Final Clean-up shows "Score if the game ended now: A 5 vs B 3 — Side A would win"** before "See result" (`256-t6-cleanup.png`). Great for the tiebreak turn. Show it from T5 onward so players can plan for it.
80. **[UX ✅] Victory screen is clean:** reason line ("More structure left after turn 6"), per-side final tally, wrecks marked, match stats, Play again / Back to Play / "Undo the last step" (`257`/`258`).
81. **[Polish] "Best shot: Shadow Hawk → Wolverine, 2 damage"** is meaningless when every hit in Ridge Line does 1–2. Better highlights: "Killing blow: Shadow Hawk wrecked the Locust (T4)", "Clutch: Commando hit the Locust on 4+", or each 'Mech's hit rate.
82. **[Polish] The victory screen doesn't show the turn-by-turn shot log.** The shot feed already exists; a "Replay the battle" or "Full log" link would be great for reviewing a game afterwards (what Jacob wanted this session for).
L10. **[UI ✅] Landscape victory works:** single column, no clipped rail (`L07-victory.png`). Proof the compact-height layout is fixable: the battle screens should drop the rail the same way.
