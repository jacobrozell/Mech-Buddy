# Test Plan Spec — TableMech

## Pyramid

| Layer | Covers |
|-------|--------|
| Unit | SATOR/crit/damage/phases/hotseat/victory/release surface |
| Integration | MatchSession SwiftData round-trip + resume |
| UI smoke | Phase 6 happy path (after UI exists) |
| A11y contracts | Phase 6 ID set present |

## CI

GitHub Actions `.github/workflows/ci.yml` runs on every pull request and on pushes to `main`. The `CI / unit` job generates the Xcode project, runs SwiftLint, and runs the `TableMechCI` scheme (unit tests) on the newest available iPhone simulator. UI smoke stays out of that job until it exists, then runs nightly rather than on every pull request.

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
| `-skip_onboarding` | Skip intro (`LaunchArguments.skipOnboarding`, Debug only) |
| `-enable_full_product_surface` | Free Battle, Full Lances, Classic tools, etc. (`ReleaseSurface`) |
| `-enable_mul_fetch` | Network MUL. Not implemented. |
| `-reset_state` | Wipe saved games and settings keys (`LaunchArguments.resetState`, Debug only) |
| `-ui_testing` | In-memory match store (`LaunchArguments.inMemoryStore`, Debug only). Does not show the volatile-store banner. |
| `-open_as_battle` | Not implemented (not needed) |
| `-load_ridge_line` | Not implemented (not needed) |

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-11-01 |
| Commit | — |
| Code paths | `.github/workflows/ci.yml`; `Support/Release/LaunchArguments.swift`; `App/AppDependencies.swift`; `Tests/Unit/RidgeLineSimulationTests.swift` |
