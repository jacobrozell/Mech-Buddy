---
name: mechbuddy-playtest
description: Run a live tabletop Alpha Strike playtest of the Mech Buddy iOS app with the user — Claude drives the app in the iOS Simulator and plays the opposing side (rolling its own dice), the user plays their side on a real table and reports moves, measurements and physical dice rolls, and Claude screenshots every screen and keeps running notes on bugs, rules errors, UI/UX friction, confusion and landscape breakage. Use this whenever the user wants to "play a game", "playtest", "play through Ridge Line", "do a play session", "test the app at the table", or play BattleTech/Alpha Strike "together" with Mech Buddy, even if they don't say "playtest" or name the skill.
---

# Mech Buddy playtest

A playtest is two things at once: a real game of Alpha Strike between the user and you, and a
structured review of the app. The user is at a physical table with miniatures, cards, a tape
measure and dice. You drive the app in the simulator, play the other side honestly, and capture
evidence (screenshots + notes) so the session can be reviewed and turned into fixes afterwards.

The game matters: play to win with sensible tactics, and roll your dice fairly. But the
deliverable is the evidence — so never skip a screenshot or a note to keep the game moving.

## Defaults (same conditions as the first session, 2026-11-19)

Ask only if the user hasn't said; otherwise assume:

- **Mission:** Ridge Line (Play tab → *Play Ridge Line*). 2v2, 6 turns, structure tiebreak.
- **Sides:** user takes the side with the **Locust** (Side B: Wolverine WVR-6M + Locust LCT-1V).
  You run Side A (Shadow Hawk SHD-2H + Commando COM-2D).
- **Device:** iPhone 17 simulator, portrait, with a **landscape screenshot of each new screen**.
- **Dice:** the user rolls physical dice for their side and tells you the faces. You roll for your
  side with `$RANDOM` in the shell (`echo $(( RANDOM % 6 + 1 )) $(( RANDOM % 6 + 1 ))`) and
  report the result before entering it. Never pick favourable numbers.
- **Table:** Open Terrain #2 and #3 maps (or whatever the user's photo shows). Only woods count.
- **Focus:** the user cares most about **edge cases** — find them on purpose (see below).

## Setup

1. Find the project: `~/Desktop/personal/apps/MechBuddy` (read `AGENTS.md`). Check whether the
   installed simulator build is older than the source; if so rebuild:
   ```bash
   xcodebuild -project MechBuddy.xcodeproj -scheme MechBuddy -configuration Debug \
     -destination 'id=<SIM_UDID>' -derivedDataPath <scratchpad>/dd build | tail -3
   ```
2. `mcp__Claude_Code_iOS_Simulator__control` → `attach` first (so the user can watch), then
   `launch` with the built `.app`. Bundle id `com.jacobrozell.tablemech`.
3. Create the session folder `ongoing/play-<YYYY-MM-DD>/` and a `NOTES.md` with a header
   (device, build, who plays which side). Read the previous session's `NOTES.md` and `TRIAGE.md`
   in `ongoing/play-*/` so you can check whether earlier findings are fixed (and say so).
4. Install the screenshot helper (see `scripts/shot.sh`) — copy it to the scratchpad and set the
   two paths at the top. `shot.sh 07-initiative` saves a full-res PNG into the session folder and
   a ~900px copy you then `Read` to see the screen. Number files in play order (`01-`, `02-` …,
   landscape as `L01-` …). Save every table photo the user sends into the folder too.

## Turn loop

Each turn: **Roll → Move → Shoot → Clean up**. Alpha Strike rules you'll need are in
`references/alpha-strike-quickref.md` — read it once at the start.

- **Initiative:** enter both sides' dice. Higher total *wins* and moves/shoots *last*; the loser
  moves first. Ties reroll.
- **Movement:** sides alternate unit by unit, loser first. Tell the user exactly where to put your
  'Mech in table terms they can find (hex numbers on the map, "into the heavy woods by 1316",
  inches). Ask the user how each of their 'Mechs moved: stood still / walk / sprint / jump.
- **Shooting:** before rolling, ask the user to **measure** range for each of your shots and say
  whether woods are in the way — don't guess distances from photos (photo estimates were off by
  ~4″ last time). Choose targets to maximise expected value and explain the odds in one line.
- **Crits:** when structure is damaged the app demands a crit roll for *that unit's owner*. If
  the unit is the user's, ask them explicitly for a **separate crit roll** — last time the user's
  attack roll got entered as a crit by mistake. Use ⋯ → *Undo last change* if anything is mis-entered.
- **Clean up:** check wrecks, the score preview, then *Next turn*.

Write the game log into NOTES.md as you go (per shot: shooter → target, range, modifiers,
target number, roll, result, damage, new armor/structure).

## Driving the simulator reliably

These cost real time last session — plan around them rather than rediscovering them:

- Tap coordinates are in device points (402×874 on iPhone 17). **Always take a screenshot
  before tapping** after anything that changes layout; lists shift (banners collapse, sheets
  animate) and taps land on the wrong control.
- The **floating bottom dock** (~y 775–855) covers content. Scroll so the target is above ~y 760
  before tapping. Dice rows, Shoot buttons and tie banners hide under it.
- **The first swipe after a tap often doesn't scroll** (especially inside the shot sheet). Use
  slow swipes (`duration` 0.7) and expect to send two.
- Tap **upper half** of small chips (the Woods chip's lower half toggles *More…*).
- Wait ~1.5s after *Apply* before tapping the dock again — a fast second tap double-applies or
  hits a stale button.
- Sheets open at medium height; drag the grabber up slowly to expand before entering the
  second die.
- The shot solver **defaults range to Short** and remembers the last target — always set range
  and conditions explicitly.
- The app forces a fixed unit order within a side. If the user wants to move a different 'Mech,
  enter a placeholder for the forced one and fix it later with the row's **Change** button.

## Notes: what to capture

Number every finding (`1.`, `2.` …; landscape ones `L1.` …) with a tag and evidence:

`N. **[Tag] One-line finding.** What happened, why it matters, suggested fix (\`NN-file.png\`).`

Tags: `[BUG]`, `[RULES BUG]`, `[UI]`, `[UX]`, `[Copy]`, `[Data]`, `[Gameplay]`, `[Confusion]`,
`[Edge]`, `[Polish]`, `[✅]` for things that work well (record these — they protect good design
from being "fixed"). When the user says something about the app, quote them and tag it with
their name — their own words carry the most weight.

Listen for confusion: any question like "do I have to…?", "wait, I get a second shot?" or
"what happens when…?" is a finding, even if you answer it.

## Edge cases to hunt deliberately

Don't wait for these to happen by chance — steer the game or the app toward them:

- Unit destroyed mid-phase that still fires back; shooting at an already-wrecked target.
- Crit on a unit that just hit 0 structure; crit effects applied to same-phase return fire.
- Initiative ties (and double ties); "let the app roll" vs real dice switching.
- Undo after a move, a shot, a crit; *Change* on a recorded move.
- Moving a unit out of the app's forced order; skipping remaining moves.
- Standing still (attacker −1, target TMM 0), jump, sprint (can't shoot).
- Leaving wrecks "still on the table" and advancing; the last-turn and victory/draw screens.
- Rotate to landscape on every new screen type (initiative, move, move summary, shoot list,
  shot solver, crit sheet, clean up, victory), screenshot, rotate back.

## Talking to the user

They're often on their phone at the table (Remote Control). Keep each message short and
table-ready: your move instruction first, then results, then the one thing you need from them
(their move, a measurement, or dice). Send key screenshots (e.g. the victory screen) with
`SendUserFile`. Mention new findings in a short bullet list each turn so they can react.

## Wrap-up

1. Final screenshots: clean up score preview, victory screen (portrait + landscape).
2. Append the final result and app stats to NOTES.md; cross-check app stats against your log.
3. Spawn a background subagent to triage NOTES.md against the code and write `TRIAGE.md`
   (P0 rules/correctness, P1 table-blocking UX, P2 copy/polish, landscape, positives — grouping
   duplicate root causes, with file pointers and S/M/L sizes). Relay its summary when it lands.
4. Summarise for the user: result, top findings, where everything is saved.
