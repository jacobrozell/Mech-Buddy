# Tech Stack Spec — Mech Buddy

| Choice | Value |
|--------|-------|
| Xcode | 26+ |
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI (iOS 26 Liquid Glass system components) |
| Min iOS / iPadOS | **26.0** |
| Observation | `@Observable` ViewModels |
| Persistence | **SwiftData only** — versioned `SchemaV1`, `SchemaV2`, … from day one |
| Project codegen | XcodeGen `project.yml` |
| DI | Manual `AppDependencies` composition root |
| Analytics / Crash | None until Phase 14; `AppLog` facade ready |
| Lint | SwiftLint |
| CI | GitHub Actions — unit + a11y contracts first |
| Apple team | `7JT2JB89AV` |
| Bundle ID | `com.jacobrozell.mechbuddy` |

## Persistence (locked)

- Do **not** introduce GRDB or parallel stores without a new owner decision  
- Every model lands in an explicit schema version  
- Migration tests required for `N−1 → N` before shipping a schema bump  
- See [DataSchemaSpec](DataSchemaSpec.md)

## Explicitly rejected

| Idea | Why |
|------|-----|
| Min iOS 17/18 with `#available` | iOS 26-only |
| UIKit tab-bar hacks | Liquid Glass TabView |
| Unversioned SwiftData models | Owner: versioning from get-go |

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-08-21 |
| Commit | — |
| Code paths | *not implemented* |
