# Mech Buddy — where we are (handoff for agents)

**Read this after [AGENTS.md](../AGENTS.md) and before starting work.** It says what is built, where it lives, what the owner has decided, and what comes next. Last updated 2026-11-26 at `main` `62a2c9d` (pushed). Update it whenever you finish a milestone.

## 1. Owner priorities

1. **Finish Alpha Strike first.** Classic BattleTech waits until Alpha Strike is done (owner, 2026-11-26).
2. **Alpha Strike rules only** in Alpha Strike code and copy. A full audit on 2026-11-26 found no Classic rules: [rules-purity-audit-2026-11-26.md](game-modes/alpha-strike/rules-purity-audit-2026-11-26.md). Keep it that way; cite the Quick-Start page for every rule.
3. **Learn vs Play.** Learn is the campaign (training missions, box scenarios, rules). Play is a full Alpha Strike game with every rule the app supports. Spec: [PlayModeSpec.md](../specs/features/PlayModeSpec.md), **accepted 2026-11-26 with every recommended default (D1–D29)**. Build it as written.
4. **Compact, minimal battle screens** that stay useful: a 4 vs 4 fits on one portrait screen.

## 2. What is built (on `main`)

| Area | State | Where |
|---|---|---|
| Training path, Missions 1–5 (Ridge Line → Full Lances) | Built | `Resources/Content/AlphaStrike/as-*.json`, `Features/Play/MissionPath.swift` |
| Box scenarios: Meet and Greet (p. 26), Clash of Steel (p. 31) | Built | `as-meet-and-greet.json`, `as-clash-of-steel.json`; both are in the Alpha Strike Quick-Start, not Classic |
| Clash of Steel rules: buildings (p. 28), Battlefield Support (pp. 29–30), formations (pp. 32, 37–38) | Built; in-battle screens covered by tests only | `Domain/Engines/AlphaStrike/{Buildings,BattlefieldSupport,Formations}.swift`, `Domain/Commands/BoxRulesReducer.swift`, `Features/Battle/BoxRulesSheet.swift` (shield button in battle) |
| Core rules: SATOR, heat, crits, REAR, HT, physical, Forced Withdrawal, Skill PV, minimal damage 0*, water | Built and audited | `Domain/Engines/AlphaStrike/`, `Domain/Commands/MatchReducer.swift` |
| Compact battle mode: coaching fades, one row per 'Mech, header in nav bar, one-row dock, slate armor pips | Built | `Features/Battle/`, `DesignSystem/Components/UnitCard.swift` (`UnitRowCard`), Settings → Coaching |
| One-screen shot sheet | Built | `Features/Battle/CombatSolverSheet.swift` |
| Map swap, map catalog, box contents (A Game of Armored Combat, Alpha Strike Box Set, Mercenaries) | Built | `Resources/Content/map-catalog.json`, `as-box-sets.json`, `Data/Collection/` |
| Card library: 40 faces from the owner's two boxes, 21 checked | Built (PM2) | `as-card-library.json`, `Data/Content/CardLibraryDTO.swift` |
| Lore (read-only BattleTech history: overview, era detail, timeline) | Built; a "History" row at the bottom of the Rules tab (`as.lore.*` ids) | `Features/Lore/LoreViews.swift`, `Data/Content/LoreDTO.swift`, `Resources/Content/Lore/` |
| Up to four sides in the domain (house rules labelled [HOUSE]) | Built (PM1), not on screen | `Domain/Models/MatchSide.swift`, `AlphaStrikePhaseEngine`, `VictoryEvaluator` |
| Learn / Play tabs | Built (PM3) behind `playMode` | `App/RootTabView.swift`, `Features/Play/` |
| Play: 1 v 1 pickup game, six setup screens, standings, draft and last setup | Built (PM4) behind `playMode`; Battlefield Support option built (PM11 slice 1: `PlayRules.battlefieldSupport`, `as.play.setup.support`, `startPlay` makes `boxRules`) | `Features/Play/` (setup flow), `MatchSession.play` (`PlaySetup`) |

**Release flag:** `playMode` (`Support/Release/ReleaseSurface.swift`) is off in Release and on with the `-enable_full_product_surface` launch argument. With it off the app shows four tabs and the old mission path, exactly as TestFlight 1.0.0 (3).

## 3. Next work, in order

From [FUTURE-PLAN.md](FUTURE-PLAN.md) §8 and §1. Check the spec's § 19 for each milestone's definition.

1. **PM11** — Battlefield Support, buildings and formations done in Play setup (`PlayRules.buildings`, `PlayRules.formation`); MechWarrior cards remain a placeholder.
2. ~~**PM5**~~ — done: battle roster groups by side with a colour/name header (`SideGrouping`, `as.battle.side.<sideId>`); shared with Learn missions. Filters not built.
3. **PM6** — teams (1 v 2, 2 v 2, 1 v 3); custom side names reach the battle screens.
4. **PM7** — three and four sides behind `playModeMultiSide` (needs Side C/D colours; owner table test).
5. **PM8** — objectives (five of six) and victory points behind `playObjectives` (turn limit already built in PM4).
6. **PM9** — saved forces and hand-entered cards (SwiftData SchemaV2).
7. **PM12 → PM13** — terrain board builder and board presets behind `playBoards`.
8. **PM10** — release pass and TestFlight table test.
9. **1.7** — landscape table view (two columns).

## 4. Open items that need the owner

- Check the **19 unchecked card faces** against the physical cards or the Master Unit List (the site blocks automated reading). Listed in `as-card-library.json` (`checked` = null); unchecked faces can't be played.
- Review the **Clash of Steel owner calls** in [clash-of-steel-rules-intake.md](game-modes/alpha-strike/clash-of-steel-rules-intake.md) ("Owner calls (2026-11-26)").
- TestFlight upload of build 4, GitHub Pages, App Store Connect: [release/todo.md](release/todo.md).
- Small confirmations from agents (not blocking): the Coaching "Automatic" wording; whether "Coaching: Off" should still show key facts; the "about N minutes" estimate (~60 PV per minute); whether a draw should clear a mission.

## 5. Known gaps (built but not finished)

- In-battle Clash of Steel flows (calling support, "Attack now", initiative reroll, Lucky) are tested in the domain but not checked on screen.
- Light-building collapse has no die entry (no scenario uses Light buildings yet); 'Mechs inside or on buildings aren't tracked; no physical attacks on buildings.
- Play: battle roster headers use the session's side names (custom names arrive with PM6); mini markers are set in battle, not on the Forces screen; hand card entry waits for PM9.
- No shipped card uses 0* damage, so the minimal-damage die has not been seen on screen.

## 6. How to work in this repo

- **Project file:** `MechBuddy.xcodeproj` is generated and untracked. Run `xcodegen generate` after adding files or after merging a branch that adds files.
- **Tests:** `xcodebuild -scheme MechBuddyCI -destination 'platform=iOS Simulator,name=iPhone 17' test` (unit, 390 on 2026-11-26) and `-scheme MechBuddyUI` (5 UI tests: Ridge Line, Clash of Steel, Play shell ×2, Play pickup game). Use your own `-derivedDataPath` when several agents build at once. **Run the UI suite on an iPhone 17-size simulator or larger**: on the iPhone 17e the Clash of Steel and Play pickup UI tests fail because controls sit off-screen.
- **Parallel agents:** each works in its own git worktree (`git worktree add ../MechBuddy-wt-<name> -b <branch> main`), its own simulator and its own derived data, with a list of files it must not touch. Commit often ("WIP …:" prefixes) so usage limits don't lose work. The coordinator reviews, merges with `--no-ff`, re-runs both suites on `main`, then removes the worktree.
- **Debug launch arguments:** `-ui_testing` (in-memory store), `-reset_state`, `-skip_onboarding`, `-open_rules`, `-enable_full_product_surface`, DEBUG `-open_mission <id>` and `-debug_damage`.
- **Never** rename or remove an accessibility identifier; add new ones beside old ones (UI tests depend on them).
- **Rulebooks** are the owner's copies in `ongoing/` (git-ignored). Printed page = PDF page − 1 in the Alpha Strike Quick-Start.
- **Pushing:** the owner approves each push to `jacobrozell/Mech-Buddy` (`git@github.com-personal:…`).

## 7. Key documents

- [ROADMAP.md](ROADMAP.md) — starting point; [FUTURE-PLAN.md](FUTURE-PLAN.md) — every known item as a checklist.
- [PlayModeSpec.md](../specs/features/PlayModeSpec.md) — Play mode, house rules, board builder, milestones PM0–PM13.
- [game-modes/alpha-strike/](game-modes/alpha-strike/) — rules intakes, audits, owner calls.
- [missions/alpha-strike-missions.md](missions/alpha-strike-missions.md) — player's guide (regenerate with `python3 scripts/generate_mission_guide.py`).
- [release/todo.md](release/todo.md) — builds, uploads, polish history.
- [game-modes/alpha-strike/multi-side-lessons-from-dartbuddy.md](game-modes/alpha-strike/multi-side-lessons-from-dartbuddy.md) — reading for PM6 (teams) and PM7 (three and four sides).
