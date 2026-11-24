# Test Plan Spec — Mech Buddy

## Pyramid

| Layer | Covers |
|-------|--------|
| Unit | SATOR/crit/damage/phases/hotseat/victory/release surface; onboarding content and model ([OnboardingSpec](features/OnboardingSpec.md) § Tests) |
| Integration | MatchSession SwiftData round-trip + resume |
| UI smoke | `MechBuddyUITests` target: Play → Ridge Line → victory (`Tests/UI/RidgeLineUITests.swift`) |
| A11y contracts | Phase 6 ID set present |

## CI

GitHub Actions `.github/workflows/ci.yml` runs on every pull request and on pushes to `main`. The `CI / unit` job generates the Xcode project, runs SwiftLint, and runs the `MechBuddyCI` scheme (unit tests) on the newest available iPhone simulator. UI smoke is not in that job. It has its own `MechBuddyUI` scheme and should run nightly rather than on every pull request.

## UI smoke

Run: `xcodegen generate && xcodebuild -scheme MechBuddyUI -destination 'platform=iOS Simulator,id=<udid>' -derivedDataPath build/DerivedData-ui test`. `MechBuddyCI` stays unit-only.

The test launches with `-ui_testing -reset_state -skip_onboarding`, taps `as.modeHome.ridgeLine`, then loops on whichever control is on screen: `as.ridge.tableReady`, the initiative skip menu (`as.initiative.agree` → Side A moves first), `as.battle.primary` (Miniatures placed, Next turn, See result), `as.battle.skipRemaining`, `as.battle.doneShooting`, and the confirm buttons "Start shooting anyway" / "Done shooting anyway". No shots are solved; the turn cap ends the game. It asserts the victory screen appears: `as.victory.screen` or its container `as.victory` (the 1x1 marker is not reliably exposed to XCUITest).

## Domain vectors (required)

Implement cases in [SATORAttackSpec](features/SATORAttackSpec.md) § Golden test vectors (#1–9) plus:

| Test | Expect |
|------|--------|
| Initiative tie | `MatchDomainError.initiativeTied` |
| Winner acts last | After initiative, movement `activeSide == loser` |
| Destroyed pending | Structure 0 → `destroyedPendingEnd`; still `canFire` |
| End removal | `resolveEndPhase` → `removed`; victory if no enemies `canFire`/`active` |
| Turn-6 structure | After End of turn 6 with both sides alive → higher remaining structure wins |
| Sprint attack | `cannotAttack` |
| SchemaV1 save/load | Session equality on reload |

## Launch arguments

| Arg | Effect |
|-----|--------|
| `-skip_onboarding` | Mark onboarding complete so the first-run cover doesn't show (`LaunchArguments.skipOnboarding` → `AppPreferences.hasCompletedOnboarding`, Debug only) |
| `-enable_full_product_surface` | Free Battle, Full Lances, Classic tools, etc. (`ReleaseSurface`) |
| `-enable_mul_fetch` | Network MUL. Not implemented. |
| `-reset_state` | Wipe saved games and settings keys, onboarding answers included (`LaunchArguments.resetState`, Debug only). Pair with `-skip_onboarding` for UI tests that start on Play |
| `-ui_testing` | In-memory match store (`LaunchArguments.inMemoryStore`, Debug only). Does not show the volatile-store banner. |
| `-open_as_battle` | Not implemented (not needed) |
| `-load_ridge_line` | Not implemented (not needed) |

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-11-01 |
| Commit | — |
| Code paths | `.github/workflows/ci.yml`; `Support/Release/LaunchArguments.swift`; `App/AppDependencies.swift`; `Tests/Unit/RidgeLineSimulationTests.swift`; `Tests/UI/RidgeLineUITests.swift`; `project.yml` (`MechBuddyUITests`, `MechBuddyUI`) |
