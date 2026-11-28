# Mech Buddy — future plan checklist

Every piece of known future work, as one checklist. Written 2026-11-25 after three UI polish passes (`polish/alpha-strike-next-session`, `polish/ui-pass`, `polish/open-items`, all merged to `main` at `ea26ede`).

It gathers the open items from [ROADMAP.md](ROADMAP.md), [release/todo.md](release/todo.md), [game-modes/PRODUCT_SCOPE.md](game-modes/PRODUCT_SCOPE.md#long-term-roadmap-owner-2026-11-24), [game-modes/classic/mission-path-scope.md](game-modes/classic/mission-path-scope.md), the Clash of Steel rules intake and the 2026-11-19 playtest triage. Those docs keep the details; this one keeps the list. When an item is done, tick it here and in its source doc.

`[ ]` to do · `[x]` done · **Owner** = needs Jacob (accounts, table time, decisions) · Size: S (an hour or two), M (a session), L (several sessions)

---

## Where the UI stands (assessment, 2026-11-25)

**About 75% of the way to production.** The flows are complete, the rules are checked against the rulebook, large text, dark mode and landscape hold up, and the look is consistent. What's left is mostly **density during a game**. The battle screen is built to teach Mission 1 and never steps back for players who already know the turn.

Screen budget on the Shoot step (iPhone 17, portrait, default text size):

| Part | Share of the screen |
|---|---|
| Nav bar, plus the TURN / "1 / 8" / "Step 3 of 4 · Shoot" header | ~25% |
| Coach title and 3-line paragraph ("Both sides shoot…") | ~15% |
| 'Mech cards (two visible, ~210pt each with the Shoot button row) | ~35% |
| Undo pill and two dock buttons | ~22% |

With eight 'Mechs (Full Lances) you scroll several screens to find who hasn't fired.

**Goal:** a battle screen that is minimal but still useful. A 4 vs 4 fits on one screen with no scrolling, teaching text appears when it's new and steps back after, and every number a player needs mid-turn is one glance away.

---

## 1. Compact battle mode (UI findings)

Do 1.1–1.4 together. Check each on screen with Full Lances (eight 'Mechs) in portrait, landscape, the largest text size and dark mode. Keep the current full layout for Mission 1 if it reads better for first-timers.

- [x] **1.1 Coaching fades after first use.** (M) Show the full coach paragraph the first time each step appears in a mission; after that, show just the title with a "?" that expands it. Add **Settings → Coaching: Full / Brief / Off** (default Full for Mission 1, Brief after). *Frees ~15% of the screen every later turn.* Done 2026-11-26: Settings → Coaching (Automatic / Full / Brief / Off).
- [x] **1.2 One dense row per 'Mech.** (M) Line 1: side badge, name, move chip (Walked…), and a trailing **Shoot** button *inside* the card. Line 2: armor and structure pips together, plus the conditions line (heat, crits) only when there is one. Target about 70pt per 'Mech instead of ~210pt. *A 4 vs 4 fits without scrolling.*
- [x] **1.3 Header folds into the nav bar.** (S) Nav title "Close Quarters · Turn 1/8" and a thin four-segment step strip under it. Drop the TURN eyebrow and the progress ring (it repeats "1 / 8"). Keep `as.battle.activeSide` and the phase accessibility IDs.
- [x] **1.4 Smaller dock.** (S–M) One primary button, the secondary action as a text button beside it. Undo moves to a toast for a few seconds after each change, and stays in the ⋯ menu. *Roughly halves the dock.*
- [x] **1.5 Shot sheet on one screen.** (M–L) Target number at the top; range as the segmented control; one chip row for Target moved (Walked ▾), Woods, Cover, Rear and Overheat; the dice directly under. Explainers ("One attack a turn…", "Push … past safe limits…") move behind info buttons. Today it is a long scroll: Attack, Range, Target moved, Conditions, More…, Overheat, Roll. Done 2026-11-26.
- [x] **1.6 Armor pips stop using Side A's colour.** (S) Armor pips are teal, the same as Side A, so a Side B card shows Side A teal. Make armor a neutral steel/white so side colours only ever mean a side. Re-check contrast in light and dark mode.
- [ ] **1.7 Landscape table view.** (L) Side A | Side B in two columns with the dock on the right, so the whole table is visible at once on a phone or iPad propped up at the table.
- [x] **1.8 Finishing touches.** (S each)
  - [x] Combat list: the per-unit Shoot button floats in its own row with a large gap; covered by 1.2.
  - [x] At accessibility sizes the two stacked dock buttons take ~280pt; consider one button plus a ⋯ for the second.
  - [x] Victory screen: check it on screen in landscape and at the largest text size (portrait checked 2026-11-25). Checked 2026-11-26; the tally and chips now stack at large text.
  - [x] The Play tab's large nav title leaves a tall empty band above "Play"; consider an inline title.

---

## 2. Release and App Store

- [ ] **Owner:** Upload **1.0.0 (3)** from Xcode's Organizer (`build/archives/MechBuddy-1.0.0-3.xcarchive`). Steps: [release/todo.md § Uploading a build](release/todo.md#uploading-a-build).
- [ ] Archive **1.0.0 (4)** from `main` (mission maps, layout diagrams and the three polish passes are not in build 3), then upload it. (S)
- [ ] **Owner:** Play Ridge Line through Full Lances at the table on the newest TestFlight build. Note issues in `ongoing/play-<date>/NOTES.md`, then triage as in `ongoing/play-2026-11-19/TRIAGE.md`.
- [ ] **Owner:** Publish `docs/` on GitHub Pages (privacy, support, accessibility pages).
- [ ] **Owner:** App Store Connect: age rating, and the "Data Not Collected" privacy label.
- [ ] App Store screenshots and description once compact battle mode (section 1) lands. (M)
- [x] Merge `feature/guided-mission-ladder`, `release/1.0.0-build-3` and `feature/mission-maps` into `main`; delete merged branches (2026-11-25).

---

## 3. Alpha Strike: polish still open

- [x] Rear weapons in the shot picker: check on screen in portrait, landscape and the largest text size (Missions 4–5, BattleMaster). (S)
- [x] Mission 5 withdrawal screens ("Withdrawing", "Left the table") and the Close Quarters punch control in landscape: check on screen. (S)
- [x] Playtest triage P1-2: the pass-the-phone banner shifts the list ~50pt, and the first swipe after a tap can be eaten. Make the banner an overlay that doesn't resize the inset; test notes 52 and 78 on a device. (M) Already an overlay; confirmed 2026-11-26.
- [ ] **Owner decision:** should a draw clear a mission? Today any finished match clears it ("played through"), which suits hotseat play.

---

## 4. Alpha Strike: content and rules

**Guided path and box scenarios**
- [x] Training path, Missions 1–5.
- [x] Meet and Greet (box scenario).
- [x] **Clash of Steel** (box scenario). (L) Done 2026-11-26: `as-clash-of-steel.json`, Scenario rules sheet in battle. Needs:
  - [x] Battlefield Support.
  - [x] Formations: Lucky rerolls, Combat Intuition, Command Lance initiative reroll.
  - [x] Buildings.
  - Rules: [alpha-strike/clash-of-steel-rules-intake.md](game-modes/alpha-strike/clash-of-steel-rules-intake.md). Cards: [book-scenarios.md](game-modes/book-scenarios.md).

**Open rules**
- [x] "0*" minimal damage (1D6, 4+ deals 1). No shipped card uses it; add a minimal-damage field to card data and the shot math with Clash of Steel, the first content that needs it. (M) Done 2026-11-26: domain, card data and shot sheet die.
- [x] Water: partial cover and −1 heat. (S–M) Done 2026-11-26: "In water" on the unit sheet; the shot sheet notes it.
- [x] Resolve the **[OPEN]** items in the Clash of Steel intake (owner calls recorded 2026-11-26 for review) (building collapse footnote, weight capacity, level-change cost, support timing, formation reroll conflict, REAR vs one attack). **Owner** for the printing conflicts.

**Open play** (after the guided path; [PRODUCT_SCOPE](game-modes/PRODUCT_SCOPE.md#long-term-roadmap-owner-2026-11-24))
- [ ] 250 PV forces built from the collection. (L)
- [ ] The six objectives (Raid, Control the Field, Destroy the Enemy, Hold the Fort, Breakthrough, Find the Target), rolled or picked. (L)
- [ ] Objective tokens and victory points. (M)
- [ ] Book-scenario rules: starting damage, exit-edge wins, per-'Mech skills, initiative modifiers, damage carried between games. (L)

---

## 5. Maps and collection

- [x] Maps needed and a top-down layout diagram for every mission.
- [x] Experienced players can swap in any map they own (scope O3). (M)
- [ ] Layouts for Classic missions, from the book's scenario maps. (M)
- [x] Map catalog: check the names of the ~20 Sarna entries left out (see `sourceNote` in `Resources/Content/map-catalog.json`). (S) Done 2026-11-26: about 70 confirmed names added; the rest are listed in `sourceNote`.
- [x] Alpha Strike box map names (not listed on Sarna). **Owner** to read them off the box. (S) Done 2026-11-26: the box has no mapsheets (owner, Sarna).
- [x] Mercenaries box: confirm contents and add its unit list (`as-box-sets.json`). Ships with none today. (S) Done 2026-11-26: 8 ’Mechs and 4 vehicles from Sarna and retailer listings.
- [ ] Later: a catalog of every known map, suggested per game. (L)

---

## 6. Classic BattleTech

Ten-mission path: [classic/mission-path-scope.md](game-modes/classic/mission-path-scope.md). Rules checked against the box rulebook (2026-11-24).

- [x] **C0 data:** all 15 record sheets and the weapons table (`Resources/Content/Classic/`), checked by `ClassicSheetsTests`.
- [ ] **C0 phase loop:** the Classic turn (initiative, move, shoot, physical, heat, end). (M)
- [ ] **C0 sheet viewer.** (M)
- [ ] **C1, Missions 1–3:** MP and facing, to-hit sum, range bands, hit locations, damage moving inward (engine started in `Domain/Engines/ClassicTW/`). Screens: move step, to-hit builder, sheet damage. (L)
- [ ] **C2, Missions 4–6:** heat scale, terrain modifiers, partial cover, jumping, piloting rolls, falls. Screens: heat track, piloting prompt. (L)
- [ ] **C3, Missions 7–9:** cluster table, ammo, crits, physical attacks. Screens: cluster helper, crit slot picker, physical picker. (L)
- [ ] **C4, Mission 10 (Final Exam):** crippled rule, exit-the-map losses, 4 vs 4 pacing. (M)
- [ ] Book scenarios: Trial by Fire, Divide and Conquer, and the campaign link to Final Exam. (L)
- [ ] Classic open play: any 'Mechs from the collection with the crippled rule; planetary conditions as switches. (L)
- [ ] Stand-ins and maps for Classic missions (scope O3, O5). (M)
- [ ] Classic leaves "Coming soon" when Mission 1 ships (Rules tab note, onboarding badge, Play card).

---

## 7. Ideas (not committed)

From `FutureIdeas/`. Not on the roadmap until the owner picks them up.

- [ ] Later guided-play plans (`FutureIdeas/guided-play.md`, written 2026-11-01 before the mission path; check what the path already covers).
- [x] **Lore:** read-only BattleTech history (overview, eras, timeline) from `Resources/Content/Lore/`, reached from the Rules tab. Lore text is an unchecked draft; verify against sourcebooks before shipping. (S)
- [ ] Analytics (`FutureIdeas/analytics.md`). Not started; the app ships with telemetry off and the "Data Not Collected" label depends on that.
- [ ] Ridge Line walkthrough page (`FutureIdeas/alpha-strike-walkthrough.html`).

---

## 8. Alpha Strike: Play mode

Owner, 2026-11-26: finish Alpha Strike fully before Classic, so this section comes before section 6 in priority. The app splits into **Learn** (the guided path, box scenarios, How to play) and **Play** (a full game: 2–4 sides, up to 4 players, your forces, your map, an optional objective, a board you build and save). Play mode replaces Free Battle and covers the "Open play" items in section 4. Spec: [specs/features/PlayModeSpec.md](../specs/features/PlayModeSpec.md). Three and four sides use labelled house rules; the Quick-Start only covers two sides (p. 13).

- [x] **Owner:** answer the spec's decisions table (D1–D29), or accept the recommended defaults. (S) All defaults accepted 2026-11-26.
- [x] **PM0** Spec merged. (S)
- [x] **PM1** N-side Domain: sides C and D, initiative order, movement order for 3–4 sides, sides going out, payload schema v2. Every mission plays the same. (L)
- [x] **PM2** Card library: all 40 card faces for the owner's two boxes in one file. (M) Built 2026-11-26: 40 faces, 21 checked.
  - [ ] **Owner:** check the 19 faces not yet checked on the Master Unit List.
- [x] **PM3** Learn | Play tabs behind `playMode`. (M) Built 2026-11-26: five tabs with the flag on, Learn = the mission path (`learn.home`, `play.home` kept), Play home with empty state and resume, landing tab.
- [x] **PM4** First playable: 1 v 1 pickup game, from setup to result. (L) Built 2026-11-26: six setup screens, PV and skill math, picker from minis and the card library (checked faces only), mat or mapsheets with layout, rules and options (turn limit with PV tie-break), standings, Play again, draft and last setup.
- [x] **PM5** Compact battle mode (section 1, items 1.1–1.4 and 1.6), plus group by side. Needed before PM7. (L) Items 1.1–1.6 and 1.8 done 2026-11-26; group by side done 2026-11-26 (`SideGrouping`, coloured side headers `as.battle.side.<sideId>`; filters not built).
- [x] **PM6** Teams: 1 v 2, 2 v 2, 1 v 3 as players per side (a team is one side, D3), controller tags, pass lines with names, custom side names in battle. (M)
- [x] **PM7** Three and four sides (free-for-all) behind `playModeMultiSide`. (L) Built 2026-11-26: Side C cobalt ▲ / D orchid ■ tokens (contrast checked), presets 1 v 1 v 1, 1 v 1 v 2, 1 v 1 v 1 v 1 (`as.play.setup.preset.*`), [HOUSE] note, info sheet (`as.play.setup.houseRules`) and Rules topic `play-house-rules`, N-side initiative with tie re-rolls and "choose the order", home edges and 3/8 zones with an edge menu in placement, concede (`as.battle.concede`), out-side labels and tied results. **Still owed: the owner's table test of a 1 v 1 v 1 v 1** (150 PV, 4′ × 4′); attacker attribution for critical rolls and Destroy the Enemy scoring came with PM8.
  - [ ] **Owner:** table test of 1 v 1 v 1 v 1.
- [x] **PM8** Objectives (five of six), victory points and turn limit, behind `playObjectives`. (L) Built 2026-11-27: Raid, Control the Field, Destroy the Enemy, Hold the Fort, Breakthrough (`as.play.setup.objective.*`, roll for it), tokens on the table checklist, VP strip `as.battle.vp`, End Phase Score step `as.battle.objective.*`, Destroy the Enemy attribution (attacker recorded per damage event, which also fixes the three-side critical prompt), Clan × 1.5 and 12 to win, points then PV at the turn limit, standings by points. Find the Target and per-side rolls came with PM11. Not built: objective copy as `as-objectives.json`.
  - [ ] **Owner:** table-test an objective game (Score step wording, Raid token pickup).
- [x] **PM9** Saved forces and hand-entered cards (SwiftData SchemaV2). (M) Saved forces entry on the Force tab done 2026-11-27 (PM11 follow-up). Still open: Master Unit List card checks.
- [ ] **PM10** Release: accessibility pass, screen catalog, inventory, flags on, TestFlight table test. (M)
- [x] **PM11** Clash of Steel rules in Play: buildings, Battlefield Support, formations, Find the Target, MechWarrior cards, per-side objective rolls. (L) Built 2026-11-27. [HOUSE] calls: Find the Target needs 3 buildings and the app hides 3 of them as targets (picked from the game id), a side searches buildings in the Score step, the first side to score the search finds it, 5 points each, 10 wins; per-side rolls keep each side's own threshold, Raid tokens go out for every side when any side plays Raid, Hold the Fort tokens are `AH1`-style in mixed games; MechWarrior cards are one named pilot per side that replaces the 'Mech's skill (0 to the card skill), with a review warning when the two cards cost different PV (the opponent's matching improvement is a note, not automatic). Also done: dense move order for 3–4 sides. Open: owner table check of Find the Target wording; real MechWarrior card abilities (Lucky and the like) beyond Formations.
- [x] **PM12** Terrain board builder behind `playBoards`: drag terrain onto the table, list editor for VoiceOver, zones for 2–4 sides. (L) Built 2026-11-27 (`Features/PlayMode/Board/`, `as.board.*`). [HOUSE] calls: a woods/hill/water footprint over 30 sq in counts as two choices; 4″ spacing hint for 3–4 sides. Left for PM13: presets, starter list, stretch-to-table, random board, zone-edge dragging, mapsheet move/rotate.
- [x] **Board follow-ups** behind `playBoards`: drag zone inner edges (per zone, snapped, 2–12″, VoiceOver adjustable ±1″, warns when pieces end up inside), select/move/turn mapsheets (edge-to-edge snap, off-table warning, **Fit table to sheets** [HOUSE], list editor path), objective-token placement (count and names from the setup's Raid / Hold the Fort, generic numbered tokens otherwise, p. 7 distance hints). (M) Built 2026-11-27 (Domain `BoardFollowups`, `Features/PlayMode/Board/BoardSheetInspectorView.swift`, `Tests/Unit/BoardFollowupTests.swift`, `Tests/UI/BoardFollowupUITests.swift`). Still later: random board, dragging a zone's ends to change its width, adding or removing mapsheets in the builder.
- [x] **PM13** Board presets: save, rename, duplicate, delete, starter boards (six missions + two open tables), last-setup board copy with "Board changed since", stretch-to-table, `.mechboard` import/export. (M) Built 2026-11-27 (`Features/PlayMode/Board/PlayBoardsView.swift`, `BoardSaveSheet.swift`, Domain `BoardPresets`, `BoardFile`, Data `StarterBoards`, `SDBoardPreset` in SchemaV2). Still later: random board, opening a `.mechboard` from Files/AirDrop directly (document types + `onOpenURL`). (Zone-edge dragging, mapsheet move/rotate and objective-token placement landed in the board follow-ups above.)
