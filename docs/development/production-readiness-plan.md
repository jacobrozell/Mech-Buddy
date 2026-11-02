# Production readiness plan — Mech Buddy 0.2.0 → 1.0.0

**Status:** Working plan (not a spec). Where a task changes behavior, the matching spec changes in the same PR per [SpecGovernance](../../specs/SpecGovernance.md).
**Written:** 2026-11-01 against `main` @ `cbabf2d` (0.2.0 build 1).
**Audience:** an implementing agent that has not seen this codebase before, and the owner (Jacob), who has to make a few decisions.
**Goal:** get Ridge Line onto a real table on TestFlight fast, then ship 1.0.0 to the App Store, without growing scope.

---

## Contents

0. [Read this first: how to run this plan](#0-read-this-first-how-to-run-this-plan)
1. [Where the app is today](#1-where-the-app-is-today)
2. [Readiness scorecard](#2-readiness-scorecard)
3. [What to do first (ranked)](#3-what-to-do-first-ranked)
4. [Milestones](#4-milestones)
5. [Workstream A: safety net (CI, tests, launch args)](#5-workstream-a--safety-net)
6. [Workstream B: correctness bugs found in review](#6-workstream-b--correctness-bugs)
7. [Workstream C: rules and content verification (owner-gated)](#7-workstream-c--rules-and-content-verification-owner-gated)
8. [Workstream D: tableside robustness](#8-workstream-d--tableside-robustness)
9. [Workstream E: TestFlight and the first real-table playtest](#9-workstream-e--testflight-and-the-first-real-table-playtest)
10. [Workstream F: App Store 1.0 submission](#10-workstream-f--app-store-10-submission)
11. [Workstream G: docs and spec hygiene](#11-workstream-g--docs-and-spec-hygiene)
12. [Owner decisions needed](#12-owner-decisions-needed)
13. [Explicitly out of scope for 1.0](#13-explicitly-out-of-scope-for-10)
14. [Appendix: review notes with file references](#14-appendix-review-notes-with-file-references)

---

## 0. Read this first: how to run this plan

### 0.1 Ground rules (from [AGENTS.md](../../AGENTS.md); restated so you can't miss them)

- Specs in `specs/` win. `FutureIdeas/` and `docs/brainstorm.md` do not.
- iOS **26** minimum, Swift **6** with `SWIFT_STRICT_CONCURRENCY: complete`, SwiftData with `SchemaV1`. Don't add `#available` fallbacks.
- `Domain/` must not import SwiftUI or UIKit. Combat math lives in `Domain/Engines/AlphaStrike/`. Views render `BattleCoach` output. They don't re-decide game rules.
- Log through `AppLogging` (`Support/Logging/AppLogging.swift`) only. No `print`.
- Feature gates go through `ReleaseSurface` (`Support/Release/ReleaseSurface.swift`) only.
- Physical dice are primary. One device, hotseat. Free Battle is 1.1. Classic stays "Coming soon" only.
- **Never rename or remove an accessibility identifier.** Add new ones next to old ones. The list is in [AccessibilitySpec](../../specs/AccessibilitySpec.md).
- Don't hand-edit `MechBuddy.xcodeproj`. Edit `project.yml`, then run `xcodegen generate`. The `.xcodeproj` is git-ignored.

### 0.2 Environment you need

- **macOS with Xcode 26+**, plus `brew install xcodegen swiftlint`.
- A Linux cloud container **cannot build or test this app**. It has no Swift toolchain, and the app needs the iOS SDK anyway. If you are in one, you can only edit files and docs. Say so in your PR description, and make sure the task has a CI run (Task A1) before you call anything verified.
- Build and test:

```bash
xcodegen generate
```

```bash
xcodebuild -scheme MechBuddyCI -destination 'platform=iOS Simulator,name=iPhone 17' test
```

If `iPhone 17` isn't installed, list what is with `xcrun simctl list devices available` and use the newest iPhone.

### 0.3 Workflow for every task

1. Read the task's **Why**, **Files**, **Steps** and **Done when** sections all the way through before you write code.
2. Write the failing test first when the task says "Test first".
3. Make the smallest change that meets **Done when**. Don't refactor neighboring code "while you're there".
4. Run the full unit suite. Run the UI smoke test too once it exists (Task A4).
5. Update the specs and docs the task lists, in the same commit.
6. Use one commit per task, in the existing style: a sentence in the imperative with a period, such as `Skip unreadable saved games instead of blocking Play.`
7. If a task says **Owner-gated**, don't change behavior until the decision is recorded in [product-readiness.md](../product-readiness.md) § Owner decision log.

### 0.4 Priority legend

| Tag | Meaning |
|-----|---------|
| **P0** | Blocks the first real-table TestFlight. Do these first, in the listed order. |
| **P1** | Fix before App Store 1.0. Most of these come out of the playtest. |
| **P2** | Nice for 1.0, fine to slip to 1.0.x. |

Sizes: **S** is under 2 hours, **M** is half a day, **L** is 1 to 2 days.

---

## 1. Where the app is today

Facts checked in code at `cbabf2d`:

| Area | State |
|------|-------|
| Version | `MARKETING_VERSION 0.2.0`, `CURRENT_PROJECT_VERSION 1` (`project.yml`) |
| Size | About 13.8k lines of Swift across App, Domain, Data, Persistence, Features, DesignSystem, Support and Tests |
| Targets | `MechBuddy` (app), `MechBuddyDomain` (framework), `MechBuddyData` (framework, which includes Persistence), `MechBuddyTests` (unit tests, **not app-hosted**, so they can only see Domain and Data) |
| Domain | `MatchReducer` (commands → new session), `BattleCoach` (the step and primary action for the UI), `MatchRecovery` (Back and Undo), engines for SATOR, damage, crits, phases and victory. Clean and well factored. |
| Persistence | One `SDMatchSession` row per match: a JSON payload plus indexed columns. `recoverySnapshots` (the undo stack, up to 12 entries) is inside the payload. |
| UI | The 0.2.0 tableside overhaul shipped: design tokens, components, battle stage with header, dock and step views, sheets, plus Play, Force, Rules and Settings. iPad and landscape layouts exist (`BattleStageLayout`). |
| Tests | 75 Swift Testing cases: SATOR vectors, reducer, coach, damage and crits, victory, persistence, content, printed move. **No UI tests and no tests of `MatchStore`.** |
| CI | **None.** There is no `.github/` directory. Nothing runs tests on a PR. |
| Launch arguments | Only `-enable_full_product_surface` is implemented. `-reset_state`, `-skip_onboarding`, `-load_ridge_line` and `-open_as_battle` are listed in [TestPlanSpec](../../specs/TestPlanSpec.md) but not implemented. |
| Release assets | App icon (1024 px single-size) and `PrivacyInfo.xcprivacy` (UserDefaults CA92.1, no tracking) exist. Legal pages are in `docs/*.html`, but GitHub Pages **isn't published yet** ([release todo](../release/todo.md)). |
| Telemetry | Off. No crash SDK. This is good for the privacy label ("Data Not Collected"). |
| Localization | English only. Strings are hard-coded in Swift and JSON. There is no String Catalog. |

**Bottom line:** the game logic and UI are in better shape than the release machinery around them. The risk now isn't "the app is missing features". It's "nothing catches a regression, and a few edge cases can strand a player mid-game." Fix the safety net and those edge cases, then get it on a table.

---

## 2. Readiness scorecard

| Area | Grade | Main gap | Tasks |
|------|-------|----------|-------|
| Domain rules engine | B+ | The shot preview and the applied shot can disagree (stealth / OVL). Several rules questions are unverified. | B2, C1–C4 |
| Persistence and recovery | C | A corrupt or future-version save blocks starting a new game. A failed store silently falls back to memory. | B1, B3 |
| Test coverage | C+ | No full-game test, no `MatchStore` tests, no UI smoke test | A2, A3, A4 |
| CI and release automation | F | No CI at all | A1, E2 |
| UI and polish | B+ | 0.2.0 overhaul landed. It needs a real-device and real-table pass. | E3, D-series |
| Accessibility | B (unverified) | IDs exist. Nobody has recorded a full VoiceOver game or AX5 pass. | D5 |
| App Store readiness | D | Pages not live, no metadata or screenshots, version still 0.2.0, IP wording not reviewed | E1, F1–F5 |
| Docs | B− | Inventory and checklist are stale (they say there's no icon; verification rows are undated) | G1 |

---

## 3. What to do first (ranked)

This is the order to work in. The reasoning is short so you can push back on it.

1. **A1 CI on every PR.** Nothing else is safe to change until a robot runs the 75 tests. Size S–M.
2. **B1 Unreadable saved game blocks new games.** A real way to strand a player, and the only escape is a buried Settings button. Size M.
3. **B2 Shot preview and applied result can disagree.** The app can say "Hit" and then record a miss. That's the worst kind of bug for a rules aid. Size S.
4. **A2 Full Ridge Line simulation test.** A cheap, very effective regression net for the reducer. Size M.
5. **C1–C4 Rules and stats verification with the owner.** Wrong card numbers or rules break trust at the table. The agent prepares the list and the owner decides. Size S for the agent.
6. **B3 Silent in-memory fallback.** A player could finish a game that was never saved. Size S.
7. **A3 Launch arguments, then A4 UI smoke test.** These make the Phase 6 DoD automatic. Size M + L.
8. **E1–E3 Pages, TestFlight, real-table playtest.** This is the actual goal of the first milestone.
9. **D-series fixes** from the playtest, then **F-series** App Store work.

---

## 4. Milestones

| Milestone | Contains | Exit criteria |
|-----------|----------|---------------|
| **M1 Table-ready TestFlight** | A1, B1, B2, B3, A2, C1–C4 (decisions recorded), A3, A4, E1, E2 | CI green on `main`. A TestFlight build is installed on the owner's phone. The Phase 6 happy path passes as a UI test **without** `-enable_full_product_surface`. |
| **M2 Playtest hardening** | E3, plus the D-series items the playtest confirms, A5, D5 | Two full Ridge Line games played on a real table with no blocking issue. Every playtest finding is triaged in the log (E3). |
| **M3 App Store 1.0.0** | F1–F5, G1 | Version 1.0.0 is submitted. Pages are live. Screenshots and metadata are done. Spec Verification blocks are dated. |

---

## 5. Workstream A — Safety net

### A1 · P0 · S–M — GitHub Actions CI

**Why.** There's no `.github/`. The README's test command only runs when someone remembers to run it.

**Files.** Add `.github/workflows/ci.yml`. Update [TestPlanSpec](../../specs/TestPlanSpec.md) § CI and the README build section.

**Steps.**

1. Create `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  unit:
    runs-on: macos-26          # if this label is unavailable, use macos-15 and select Xcode 26 below
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode 26
        run: |
          ls -d /Applications/Xcode*.app
          sudo xcode-select -s "$(ls -d /Applications/Xcode_26*.app | sort -V | tail -1)"
          xcodebuild -version
      - name: Tools
        run: brew install xcodegen swiftlint
      - name: Generate project
        run: xcodegen generate
      - name: Lint
        run: swiftlint lint --config .swiftlint.yml --reporter github-actions-logging
      - name: Pick simulator
        id: sim
        run: |
          NAME=$(xcrun simctl list devices available | grep -oE 'iPhone 1[0-9]( Pro)?( Max)?' | sort -V | tail -1)
          echo "name=$NAME" >> "$GITHUB_OUTPUT"
      - name: Unit tests
        run: |
          set -o pipefail
          xcodebuild -scheme MechBuddyCI \
            -destination "platform=iOS Simulator,name=${{ steps.sim.outputs.name }}" \
            -resultBundlePath TestResults.xcresult \
            CODE_SIGNING_ALLOWED=NO \
            test
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: TestResults
          path: TestResults.xcresult
```

2. Push a branch and confirm the job goes green. If lint reports warnings, fix them in a separate commit. Don't widen `disabled_rules` to make them go away.
3. Once lint has no warnings, change the lint step to `swiftlint lint --strict …`. Leave the Xcode build-phase SwiftLint script lenient (`|| true`) so local builds don't break.
4. Owner action: in GitHub, open **Settings → Branches** and add a protection rule on `main` that requires the `CI / unit` check.

**Done when.** A PR shows a green `CI / unit` check. A deliberately broken test makes it go red (try it on a scratch branch, then delete the branch).

---

### A2 · P0 · M — Full Ridge Line simulation test

**Why.** Each reducer test checks one transition. Nothing plays a whole game from start to victory, which is exactly what players do.

**Files.** Add `Tests/Unit/RidgeLineSimulationTests.swift`. Reuse the `BundleToken` and catalog pattern from `Tests/Unit/ContentCatalogTests.swift`.

**Steps (Test first: this test is the deliverable).**

1. Build the session from the **bundled JSON**: `RidgeLineFactory.makeUnits(from: catalog.ridgeLineScenario())` and `mapRuleset(...)`, then `.startMission`, then `.markTableReady`.
2. Write a small driver, `func play(_ s: inout MatchSession, _ c: MatchCommand)`, that calls `MatchReducer.reduce` and then checks the invariants below after **every** command:
   - For every unit: `0 ≤ armorDamage ≤ armorCap`, `0 ≤ structureDamage ≤ structureCap`, and `criticalsOwed ≥ 0`.
   - `heat` is between 0 and 4.
   - A unit with `combatStatus == .removed` never has `hasAttackedThisTurn` flip to true later.
   - `turn` never goes down. `phase` only moves through initiative → movement → combat → end → initiative.
   - `BattleCoach(session:)` never has `primary == nil` while `step` is one of `.initiative, .combat, .end`.
3. Scenario 1, **wipe win.** Side A wins initiative every turn (A rolls 6+6, B rolls 1+1). Movement: alternate `.setMovementMode(.standstill)` + `.markMoved` until `movementComplete`, then `.advancePhase`. Combat: each side shoots its first living enemy at short range with a 6+5 roll. Apply every owed crit with a roll of 5+4 (total 9, which is "No critical"), then `.finishCombatSide` twice and `.resolveEndPhase`. Loop until `status == .completed`. Assert the outcome is `.winner` and the game ends on or before turn 6.
4. Scenario 2, **turn-6 structure tiebreak.** Every shot misses (TN ≥ 3, roll 1+1). Expect `.completed` after the turn-6 `resolveEndPhase`, with outcome `.draw` (everyone keeps full structure).
5. Scenario 3, **codec round-trip mid-game.** In the middle of scenario 1, encode the session with `JSONEncoder`, decode it, and assert the result equals the original (`==`).
6. Keep each scenario under about 80 lines with small helpers. No randomness: every die is fixed.

**Done when.** All three scenarios pass in CI. Breaking any reducer guard by hand (for example, deleting the `hasAttackedThisTurn` check) makes at least one of them fail.

---

### A3 · P0 · M — Implement the spec'd launch arguments

**Why.** UI tests need a clean, deterministic start. [TestPlanSpec](../../specs/TestPlanSpec.md) already names the arguments.

**Files.** Add `Support/Release/LaunchArguments.swift`, `App/AppDependencies.swift`, `App/MechBuddyApp.swift`. Update TestPlanSpec § Verification.

**Steps.**

1. Add the type:

```swift
import Foundation

/// Debug-only switches for UI tests. Spec: TestPlanSpec § Launch arguments.
enum LaunchArguments {
    static var all: [String] { ProcessInfo.processInfo.arguments }
    static var resetState: Bool { contains("-reset_state") }
    static var skipOnboarding: Bool { contains("-skip_onboarding") }
    static var inMemoryStore: Bool { contains("-ui_testing") }

    private static func contains(_ flag: String) -> Bool {
        #if DEBUG
        return all.contains(flag)
        #else
        return false
        #endif
    }
}
```

2. In `AppDependencies.init`: if `LaunchArguments.inMemoryStore`, call `PersistenceController.makeContainer(inMemory: true)`. If `resetState`, call `try? stored.deleteAll()` and then wipe the `settings.*` UserDefaults keys. Add a `func reset()` to `AppPreferences` that removes every key it owns and reloads the defaults. If `skipOnboarding`, set `preferences.hasSeenIntro = true`.
3. Implement `-load_ridge_line` and `-open_as_battle` **only if A4 needs them**. Otherwise mark them "not implemented (not needed)" in TestPlanSpec, so the spec stops claiming something that doesn't exist.
4. `-ui_testing` is a new argument. Add it to the TestPlanSpec table.

**Done when.** Launching with `-ui_testing -reset_state -skip_onboarding` shows a fresh Play tab with no Resume card. A Release build ignores all of these arguments: check by building the Release config and reading `LaunchArguments`.

---

### A4 · P0 · L — XCUITest for the Phase 6 happy path

**Why.** This is the [Phase 6 DoD](phase-6-vertical-slice.md). Right now it's only checked by hand.

**Files.** Edit `project.yml` (new target and scheme). Add `Tests/UI/RidgeLineHappyPathUITests.swift`. You may need small identifier additions in `DesignSystem/Components/DieFacePicker.swift`.

**Steps.**

1. Add the target in `project.yml`:

```yaml
  MechBuddyUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: Tests/UI
    dependencies:
      - target: MechBuddy
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jacobrozell.mechbuddy.uitests
        GENERATE_INFOPLIST_FILE: YES
        TEST_TARGET_NAME: MechBuddy
```

   Add a scheme `MechBuddyUI` whose test action runs `MechBuddyUITests`. Keep `MechBuddyCI` unit-only so PR CI stays fast.
2. **Identifiers.** Individual die faces have no identifiers today; only the picker does (`{prefix}.die1`). Add a per-face id **on each face button**, `"\(accessibilityIdentifier).\(face)"` (for example `as.crit.die1.6`), and leave the existing picker id where it is. Find the initiative pickers' `diePrefix` in `Features/Battle/Steps/InitiativeStep.swift` and record the resulting ids in AccessibilitySpec.
3. Write the test with arguments `["-reset_state", "-skip_onboarding"]`. Don't pass `-ui_testing` here: the resume check below needs the on-disk store.
   - Tap `as.modeHome.ridgeLine`. Wait for `as.ridge.tablePrep`. Tap `as.ridge.tableReady`.
   - Initiative: tap Side A 6+6 and Side B 1+1. Tap `as.battle.primary`.
   - Placement: tap `as.battle.primary` ("Miniatures placed").
   - Movement: for each unit, tap its card and choose `as.battle.move.standstill`, or tap the secondary "Skip remaining" (`as.battle.skipRemaining`) and confirm. Then tap `as.battle.primary` ("Start shooting").
   - Combat: tap `as.battle.primary` ("Solve a shot"), pick an attacker and a target (`as.sator.pick.attacker.*`, `as.sator.pick.target.*`), enter 6+6 on the die faces, tap `as.sator.resolve`. If a crit is owed, tap `as.battle.primary`, enter 5+4 in `as.crit`, tap `as.crit.confirm`.
   - Tap `as.battle.doneShooting` (confirm if asked) for both sides. Then tap `as.battle.primary` ("Next turn").
   - **Resume check:** call `app.terminate()`, relaunch with only `-skip_onboarding` (no `-reset_state`), and assert `as.modeHome.resume` exists. Tap it and assert `as.battle.screen` comes back on the same turn.
   - Victory: it's fine to reach victory through `-load_ridge_line` with a near-finished fixture if the full loop is too slow or flaky. Assert `as.victory.screen`, then tap Done.
4. Add a nightly or `workflow_dispatch` job to CI that runs `MechBuddyUI`. Per TestPlanSpec, UI smoke runs nightly, not on every PR.

**Done when.** `MechBuddyUI` passes three times in a row locally and once in CI. No `sleep` calls: use `waitForExistence(timeout:)`.

---

### A5 · P1 · M — App-hosted tests for `MatchStore`

**Why.** `Features/Battle/MatchStore.swift` (430 lines) owns undo, Back, persistence, abandon and rematch, and has no tests, because `MechBuddyTests` isn't hosted by the app.

**Options (pick 1; recommended first):**

1. **Add `MechBuddyAppTests`** (`bundle.unit-test`, `TEST_HOST` set to the app, `@testable import MechBuddy`) under `Tests/App/`. Test `MatchStore` with `InMemoryMatchSessionRepository`.
2. Move `MatchStore` and `ScenarioPresentation` into `MechBuddyData`. That's more churn, and it puts `@Observable` UI state in the data layer. Not recommended.

**Cases to cover.** Start → undo returns to the previous session. The undo stack caps at 12. `back()` hands movement back without losing moves. `backNeedsConfirm` is true after a shot. `abandon()` deletes the row. `rematch` deletes the completed game and starts fresh. `startRidgeLine(replaceActive: false)` with an active save sets `lastError`. `persist()` writes `recoverySnapshots` with each nested snapshot's own `recoverySnapshots` empty.

**Done when.** At least 10 cases pass in CI, and the new target runs in the `MechBuddyCI` scheme.

---

## 6. Workstream B — Correctness bugs

### B1 · P0 · M — An unreadable saved game blocks starting any new game

**Why (traced in code).**

1. `SwiftDataMatchSessionRepository.loadActive` (`Persistence/SwiftDataMatchSessionRepository.swift`) **throws** when the newest active row fails to decode or has a future `schemaVersion`.
2. `PlayMatchCoordinator.refresh` catches the error, logs it, and sets `resumeSession = nil`, so the Resume card disappears.
3. The player taps Play Ridge Line. `startNew` calls `MatchStore.startRidgeLine`, which calls `loadActive` again, which **throws again**. The player sees "Couldn't start the mission" every time.
4. The only way out is Settings → Delete saved games, and nothing points the player there.

Triggers include a decode change in a future build, a downgrade from a TestFlight build with a newer schema, or a truncated write.

**Files.** `Persistence/SwiftDataMatchSessionRepository.swift`, `Persistence/MatchSessionRepository.swift`, `App/AppDependencies.swift` (`SessionRevisionRepository`), `Features/Play/PlayMatchCoordinator.swift`, `Tests/Unit/MatchPersistenceTests.swift`. Update [MatchSessionSpec](../../specs/features/MatchSessionSpec.md) and [DataSchemaSpec](../../specs/DataSchemaSpec.md).

**Steps (Test first).**

1. Test: insert an `SDMatchSession` straight into a `ModelContext` with `statusRaw = "active"` and `payload = Data("garbage".utf8)`. Expect `loadActive` to return `nil` **without throwing**, and a later `save` of a new session to work. Add a second test with a payload whose `schemaVersion` is `MatchSession.currentSchemaVersion + 1`.
2. In `loadActive`, fetch **all** active rows for the mode, newest first. For each row, try to decode it. On failure, set `row.statusRaw = "unreadable"` (a plain string column, not a `MatchStatus` case, so no schema change is needed), save, record the id, and try the next row. Return the first row that decodes, or nil. **Don't delete** unreadable rows: a later build may be able to read them. `deleteAll()` still removes them, because it fetches every row.
3. Add `var unreadableSessionIDs: [UUID] { get }` to `MatchSessionRepository` (empty for `InMemoryMatchSessionRepository`) and forward it in `SessionRevisionRepository`.
4. In `PlayMatchCoordinator.refresh`, if that list isn't empty and no notice has been shown, set a one-time notice: *"A saved game couldn't be opened, so it was set aside. You can start a new game."* Show it with the existing `ErrorBanner` on Play home or the existing alert. Log through `dependencies.logger.error(…, category: "persistence")` with the id only, never the payload.
5. Add the "unreadable" state to MatchSessionSpec.

**Done when.** Both new tests pass. By hand: corrupt the row (a debug-only menu item or a unit test is enough), launch, see the notice once, and start Ridge Line normally.

---

### B2 · P0 · S — Shot preview and applied result can disagree

**Why (traced in code).** The solver sheet previews the target number with `CombatSolver.solve` (`Domain/Engines/AlphaStrike/CombatSolver.swift`). Applying the shot calls `MatchReducer.applySATOR` (`Domain/Commands/MatchReducer.swift`), which **builds its own `SATORInput`** and misses two inputs:

| Input | `CombatSolver` (preview) | `MatchReducer.applySATOR` (applied) |
|-------|--------------------------|-------------------------------------|
| Target stealth `targetHasSTL: defender.hasStealth` | passed | **missing**, so the applied TN is 1–2 lower at medium/long range |
| `ovlAllowsLong` (OVL ability) | passed | **missing** (only matters once overheat is on) |

Ridge Line's four units don't have STL or OVL, so today's mission isn't affected. Any future scenario or Free Battle unit would show "Hit" and record "Miss", or the other way round.

**Files.** `Domain/Commands/MatchReducer.swift`, `Domain/Engines/AlphaStrike/CombatSolver.swift`, `Domain/Models/MatchUnitState.swift`, `Tests/Unit/CombatSolverTests.swift`.

**Steps (Test first).**

1. Test: attacker skill 4, defender with `abilities: "STL"`, medium range. Get `CombatSolver.solve(...).targetNumber!.value`, then apply the same shot through `MatchReducer.reduce(.resolveSATOR)` and read `units[attacker].turnShot!.targetNumber`. Assert they're equal. Add the same kind of test for damage delivered with `OVL` and overheat allowed.
2. Put the shared parts in one place. Add `public var hasOVL: Bool { abilities.uppercased().contains("OVL") }` to `MatchUnitState`, and add an internal helper in `CombatSolver`:

```swift
static func satorInput(
    attacker: MatchUnitState, defender: MatchUnitState, attackerMove: MovementMode,
    targetMove: TargetMoveModifier, woods: Bool, partialCover: Bool,
    rangeInches: Double?, bracket: RangeBracket
) -> SATORInput
```

   Use it from **both** `CombatSolver.solve` and `MatchReducer.applySATOR`. Do the same for a `damageInput(...)` helper.
3. Don't change any numbers. This is a parity fix only.

**Done when.** The parity tests pass, and the five SATOR golden vectors still pass.

---

### B3 · P0 · S — The store silently falls back to memory

**Why.** `AppDependencies.init` catches a SwiftData failure and uses an in-memory container. It logs the failure, but the player gets no sign that nothing will be saved.

**Steps.** Add `private(set) var isUsingVolatileStore: Bool` to `AppDependencies`. When it's true, show a non-dismissible `ErrorBanner` on Play home: *"Games can't be saved on this device right now. Restart the app. If this keeps happening, contact support."* Link it to `AppLinks.support`. Don't show it when `LaunchArguments.inMemoryStore` is on (A3).

**Done when.** Forcing the fallback in a debug build shows the banner, and normal launches don't.

---

### B4 · P1 · S — The reducer accepts gameplay commands on a finished game

**Why.** `MatchReducer.reduce` doesn't check `status`. The UI hides the controls, so nothing reaches this today, but a bad Undo or Back sequence could, and the reducer should be the gate.

**Steps.** At the top of `reduce`, for every command except `.startMission`, `.abandonMatch` and `.setDiceMode`, throw `MatchDomainError.illegalPhaseTransition("This game is over")` when `session.status != .active`. Add one test per command family.

---

### B5 · P1 · S — The crit table is defined in three places

**Why.** The crit table lives in `AlphaStrikeCriticals.resultId` (Domain), in `as-crit-table.json` (content; `ContentCatalogTests` checks that it matches Domain), and in a **third, hard-coded copy** inside `Features/Battle/CritSheet.swift`. That copy calls 7 "Motive", while Domain says "MP hit".

**Steps.** Build the sheet's reference table from `AlphaStrikeCriticals.resultId(forTotal:)` and `title(for:)` for totals 2 through 12, and delete the static array. Pick one name for 7 and use it everywhere: "Motive" reads better for beginners, so change `title(for: .mp)` and the JSON `title` to match, and update the rules topic text if it says "MP". The JSON-equality test keeps the copies honest.

---

## 7. Workstream C — Rules and content verification (owner-gated)

These are **questions, not confirmed bugs**. The agent's job: (1) put each one in front of the owner with the exact code location, (2) once the owner rules, implement the answer with a test, and (3) record the decision in [product-readiness.md](../product-readiness.md). **Don't change rules logic on your own judgment.**

Check against the official free Alpha Strike Quick-Start rules (linked in-app via `AppLinks.quickStartDownloads`) and the physical cards in the box.

### C1 · P0 — Ridge Line unit stats against the printed cards

**Decided 2026-11-01.** All four units match their pages on [masterunitlist.battletech.com](https://masterunitlist.battletech.com/). No JSON change. Locust LCT-1V TMM 3 is correct: 13"–18" is +3, and +4 starts at 19". Recorded in [product-readiness.md](../product-readiness.md).

Army building is not this task. When that work starts, use the same site as the card lookup. 1.0 stays Ridge Line only. Do not bulk-download the catalog.

### C2 · P0 — Does heat cool down in the End phase?

Today heat only goes up: an engine crit adds +1 each time the unit fires (`MatchReducer.applySATOR`). Nothing lowers it, and `resetTurnFlags` doesn't touch `heat`. So a 'Mech with one engine hit gets +1 to every shot for the rest of the game, then +2, and so on up to +4. Check what the rules say about heat at End phase, and whether heat 4 means shutdown rather than "+4 to hit". If heat should cool, add it to `AlphaStrikePhaseEngine.resetTurnFlags` or `removeDestroyedAtEnd`, with a test.

### C3 · P1 — Second motive (MP) hit

`AlphaStrikeCriticals.apply` makes a second MP hit set `mv = "0\""` and `tmm = 0`, which means immobile. Check whether the rules instead halve movement again (and become immobile only when it reaches 0). This matters for the Locust and Commando.

### C4 · P1 — Owed criticals on a 'Mech that is already wrecked

When a shot takes a 'Mech's structure to 0, `AlphaStrikeDamage.apply` still adds a critical owed. The players then **have to** roll a critical for a 'Mech that's already wrecked before the next shot (`applySATOR` blocks while any crit is owed). At the table this is pure friction. **Recommendation:** when a unit is `destroyedPendingEnd` (or `isStructurallyDestroyed`), clear its `criticalsOwed` and log "No critical needed — already wrecked." Write it as a Domain change in `AlphaStrikeDamage.apply`, plus a test, plus a line in [SATORAttackSpec](../../specs/features/SATORAttackSpec.md).

---

## 8. Workstream D — Tableside robustness

Most of these should be confirmed or re-prioritized by the playtest (E3). Don't polish ahead of real feedback.

### D1 · P1 · S — Keep the screen awake in battle according to the setting

`BattleFlowView.openMatch()` sets `UIApplication.shared.isIdleTimerDisabled = true` without checking the setting, and `onDisappear` sets it to `false`. So in battle the Settings toggle does nothing, which is surprising if the player turned it off to save battery. **Owner decision (O4).** Recommended: honor the setting, which defaults to on. Change `openMatch` to call `dependencies.preferences.applyKeepScreenAwake()`.

### D2 · P1 · S — iPad multiple windows

`WindowGroup` on iPad allows two windows. Each `RootTabView` has its own `PlayMatchCoordinator`, so two `MatchStore`s could open the same saved game and overwrite each other. First check whether the generated Info.plist enables multiple scenes (look at the built app's `Info.plist`). If it does, add `INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES` and set `UIApplicationSupportsMultipleScenes` to `NO` through `App/Info.plist`. One-device hotseat doesn't need two windows.

### D3 · P1 · S — Log command failures

`MatchStore.mutate` shows alerts but never logs. Add `logger.error("command failed: \(command)", category: "match")` with no unit names or PII, so TestFlight sysdiagnoses can show what went wrong. `MatchStore` will need a logger injected next to the repository.

### D4 · P2 · M — Typed `MatchEvent.kind`

This is item 9.3.2 in the [UI overhaul plan](ui-overhaul-plan.md) and is still not done (`MatchEvent` has no `kind`). Make it an optional field so old saves still decode. Only do it if the playtest says the event log is hard to scan.

### D5 · P1 · M — Accessibility verification pass

Play one full game with VoiceOver on, then repeat at Dynamic Type **AX5**, with Increase Contrast and with Reduce Motion. Record the results in the [AccessibilitySpec](../../specs/AccessibilitySpec.md) Verification block. Fix only what blocks completing the game (focus traps, unlabeled controls, clipped primary buttons). Put cosmetic findings in the playtest log.

### D6 · P2 · S — Show reducer error text to players

Messages such as `"Not in movement"`, `"Use finishCombatSide"` and `"Movement incomplete"` (`MatchReducer.swift`, `AlphaStrikePhaseEngine.swift`) can reach the player through `lastError`. Rewrite them in the app's plain voice (see the copy rules in the UI overhaul plan, §8), or map them in `MatchStore` before display.

---

## 9. Workstream E — TestFlight and the first real-table playtest

### E1 · P0 · S — Publish GitHub Pages (owner plus agent)

1. Agent: check that `docs/index.html`, `privacy.html`, `support.html` and `accessibility.html` render and link to each other, and that `support.html` has a real way to get in touch (an email address or GitHub Issues link). The owner must supply the address.
2. Owner: in GitHub, open **Settings → Pages**, choose **Deploy from branch**, `main`, folder `/docs`.
3. Agent: `curl -sI` all three URLs in `Support/Navigation/AppLinks.swift` and confirm each returns 200. Tick the box in [release/todo.md](../release/todo.md).

> Note: `docs/` also holds Markdown planning docs (like this one). With Pages from `/docs`, they're public. That's fine for a public repo. If the repo is private, ask the owner before publishing.

### E2 · P0 · S — TestFlight build

1. Bump `CURRENT_PROJECT_VERSION` for every upload. Keep `MARKETING_VERSION 0.2.0` (or `0.3.0` once the B fixes land) until M3.
2. Archive using the README command. Upload with Xcode Organizer, or with `xcrun altool` / `notarytool` if the owner sets up an App Store Connect API key. **Never commit keys.**
3. In App Store Connect, add the "What to test" text: *"Play one Ridge Line game start to finish with real dice. Note anything confusing in the playtest log."*
4. Optional later: a `release.yml` workflow that archives on a tag. It needs signing secrets the owner must add, so leave it out of M1.

### E3 · P0 · M — Real-table playtest protocol

1. Agent: create `docs/release/playtest-log.md` with this template, one section per session:

```markdown
## Session N — YYYY-MM-DD — build X (N)
Device: iPhone __ / iPad __ · Players: __ (rules familiarity: none / some / veteran) · Dice: real / app
Duration: __ min · Finished: yes/no · Result: __

| # | Turn/phase | What happened | Severity (blocker/major/minor/idea) | Screenshot |
|---|-----------|---------------|------------------------------------|------------|
```

2. Owner: run **two** sessions. In at least one, someone who has never played Alpha Strike runs the phone.
3. Agent: turn every blocker and major into a task in this plan (D-series) or a GitHub issue, then fix the blockers before M2 closes.

Watch for these during the playtest (the questions this review couldn't answer from code):

- Can two people pass one phone without confusion about whose turn it is (the side banner and side colors)?
- Is entering 2D6 by tapping faces faster than "Let the app roll"?
- Is the shot solver too many taps for a 2v2 game? (Count the taps per shot.)
- Does the screen stay on, and is it readable at arm's length?
- Do Back and Undo do what players expect after a wrong tap?

---

## 10. Workstream F — App Store 1.0 submission

### F1 · P1 · S — Version 1.0.0

Set `MARKETING_VERSION: "1.0.0"` in `project.yml`, and update README and [feature-inventory](../feature-inventory.md). Tag `1.0.0` after the build is approved.

### F2 · P1 · M — Store metadata (agent drafts, owner approves)

Draft in `docs/release/app-store-metadata.md`:

- **Name and subtitle.** Owner decision O1 below. Avoid trademarks in the **name**. Something like "Mech Buddy — Tabletop Mech Companion" is safer than putting "BattleTech" in the title.
- **Description.** It must say plainly that this is an unofficial fan aid, it needs the physical game, and it's offline. Reuse the disclaimer from `as-rules-topics.json` and Settings.
- **Keywords**, **category** (Games → Board, or Utilities), **age rating** questionnaire (expect 4+ or 9+ for "infrequent cartoon or fantasy violence").
- **Privacy nutrition label:** Data Not Collected. This must match `PrivacyInfo.xcprivacy` and `docs/privacy.html`.
- **Support URL and Privacy URL:** the live Pages URLs from E1.
- **Review notes:** "No login. Tap Play → Ridge Line → Start battle. Physical dice are optional: open the dice link and choose 'Let the app roll'."

### F3 · P1 · M — Screenshots

Capture from the polished build: iPhone 6.9" and iPad 13", in light and dark. Cover Play home, the battle in movement, the shot solver with a TN shown, a crit, and Victory. Use the simulator with `-ui_testing -reset_state` plus a seeded mid-game fixture, so every capture is reproducible. Save the source PNGs under `docs/release/screenshots/` only if the owner wants them in git.

### F4 · P1 · S — IP and trademark review (owner)

The app uses BattleTech and Alpha Strike names, unit names, and stats reproduced from cards. Guideline 5.2 (intellectual property) is the most likely rejection reason. The owner should read the current Catalyst Game Labs fan-content policy and decide whether the bundled stats and unit names are acceptable. Then record the decision in [product-readiness.md](../product-readiness.md) (it's open item 22–24). The agent must not change copy for this without that decision.

### F5 · P2 · M — String Catalog (English only)

Move user-facing strings into `Localizable.xcstrings`. This isn't required for 1.0, but it makes 1.x localization cheap. Do it only after the copy is final (after E3) to avoid churn. Follow [LocalizationSpec](../../specs/LocalizationSpec.md).

---

## 11. Workstream G — Docs and spec hygiene

### G1 · P1 · S — Bring the docs up to date with the code

| Doc | Fix |
|-----|-----|
| [feature-inventory.md](../feature-inventory.md) | The "App icon image" row says planned. It shipped in `cbabf2d`. Add rows for CI, UI tests and launch arguments as they land. |
| [agent-build-checklist.md](../agent-build-checklist.md) | Phases 0–6 rows have commit "—". Fill in real commits. Tick "Git remote + first commit" (the repo has had a remote for a while). Link this plan. |
| [TestPlanSpec](../../specs/TestPlanSpec.md) | The Verification block says "not implemented". Fill in code paths and today's date after A1 to A4. |
| [release/todo.md](../release/todo.md) | Expand it into the M1, M2 and M3 checklists from §4 of this plan. |
| [docs/development/README.md](README.md) | Link this plan. |
| [product-readiness.md](../product-readiness.md) | Record each O-decision from §12 as it's made. |

Rule of thumb: every PR that changes behavior also changes the spec's **Verification** block (date, commit, code paths).

---

## 12. Owner decisions needed

| # | Decision | Recommendation | Blocks |
|---|----------|----------------|--------|
| O1 | App Store name and subtitle; whether "BattleTech" appears in them | Name "Mech Buddy". Mention BattleTech only in the description, with the disclaimer. | F2 |
| O2 | Are bundled card stats and unit names acceptable under the fan policy? | Read the policy. If unsure, keep the stats; the app is useless without them. | F4, store submission |
| O3 | Rules rulings C1–C4 | C4: waive crits on wrecked 'Mechs. C1–C3: follow the printed rules. | C-series |
| O4 | In-battle screen awake: honor the setting or always on? | Honor the setting (default on). | D1 |
| O5 | Support channel for `support.html` (email or GitHub Issues) | A dedicated email alias | E1, F2 |
| O6 | CI runner cost (macOS minutes) | Unit tests on every PR. UI test nightly and on demand only. | A1, A4 |

---

## 13. Explicitly out of scope for 1.0

Don't start these, even if they look easy. They're gated by the owner locks in AGENTS.md and the [Phase 6 DoD](phase-6-vertical-slice.md):

- Free Battle (1.1), Full Lances playable, roster editing, MUL network fetch or paste.
- Classic play tools (Classic stays a Coming soon sheet).
- Physical attacks, overheat and Forced Withdrawal UI (the resolver flags exist; Ridge Line keeps them off).
- Match history, write-back of survivors, tip jar, telemetry SDKs, accounts or sync.
- Non-English localization.

If a playtest finding seems to need one of these, write it in the playtest log as an "idea" and move on.

---

## 14. Appendix: review notes with file references

These are what the review found beyond the tasks above. They're low priority; act on them only when you're already in the file.

- `Support/Logging/AppLogging.swift`: OSLog redacts interpolated strings as `<private>` in release logs, so the category tag is unreadable too. Consider logging the category through `Logger(subsystem:category:)` instead of putting it in the message string.
- `Domain/Models/MatchUnitState.swift` `hasAmmoImmunity`: substring matching on `"ENE"` and `"CASE"` (and `hasStealth` on `"STL"`). Fine for the bundled cards. When rosters get editable (1.1), parse comma-separated ability tokens instead.
- `Domain/Models/MatchSession.swift` `DiceRoll2D6.init` uses `precondition`, which crashes on bad input. All UI paths call `validated(...)` first, and synthesized decoding doesn't call `init`, so it's safe today. Keep it that way.
- `Features/Battle/BattleFlowView.swift` (715 lines) and `CombatSolverSheet.swift` (966 lines) are the largest files. Don't split them for 1.0 unless a task needs it. The UI overhaul plan §9.1 has the split recipe.
- `project.yml`: `ENABLE_USER_SCRIPT_SANDBOXING: NO` exists only so the SwiftLint build phase can run. Leave it.
- `Persistence/SchemaV1/SchemaV1.swift`: `MechBuddyMigrationPlan` has no stages. That's right for now. The first change to `SDMatchSession`'s columns must add `SchemaV2` and a lightweight stage. Payload-only changes (new optional fields in `MatchSession`) don't need a SwiftData migration, only `decodeIfPresent` defaults, as `deploymentAcknowledged` already does.
- `MatchStore.persist()` writes up to 12 full-session snapshots into every save. Ridge Line sessions are small, so this is fine. Revisit if Full Lances (8 units, longer logs) lands.
