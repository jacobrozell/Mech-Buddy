# Architecture Spec — Mech Buddy

## Goal vs Tabletome

Tabletome works, but multi-mode growth produced `switch gameSystemId` sprawl. Mech Buddy adopts a **play-engine + content-pack registry** from day one:

- Features never branch on raw mode strings for combat/turn behavior
- Capabilities and engines come from Domain registry + manifest JSON
- Adding a mode follows [ContentPackSpec](ContentPackSpec.md) — not feature forks
- Platform UX follows [IOS26PlatformSpec](IOS26PlatformSpec.md) (Liquid Glass two-layer model)

## Layers

```
Features (SwiftUI + @Observable ViewModels)
    ↓ protocols / commands
Data (Repositories, JSON loaders)
    ↓
Persistence (SwiftData schema, migrations)
    ↓ types
Domain (Models, Commands, PlayEngines, pure math) — Foundation only
```

`App/` composition root. `DesignSystem/` = content-layer components. `Support/` = logging, release surface, deep links.

## Folder map (Phase 0)

| Folder | Contents |
|--------|----------|
| `App/` | Entry, `AppDependencies`, root `TabView` |
| `Features/` | SwiftUI + MVVM per flow (no cross-feature imports) |
| `Domain/` | Models, commands, engines, registries |
| `Domain/Engines/AlphaStrike/` | Phases, SATOR, AS damage/crits |
| `Domain/Engines/ClassicTW/` | Classic phases, hit location (later) |
| `Data/` | Repository protocols + implementations |
| `Persistence/` | SchemaV*, migrations, container factory |
| `DesignSystem/` | Semantic tokens, pip/TN/dice components |
| `Support/` | AppLog, ReleaseSurface, AppRouter, AppLinks |
| `Resources/` | Assets, string catalog, content JSON |
| `Tests/` | `Unit/`, `Accessibility/`, `UI/` |

## Module map (XcodeGen)

| Target | Contents |
|--------|----------|
| Mech Buddy | App, Features, DesignSystem, Support |
| MechBuddyDomain | Domain |
| MechBuddyData | Data + Persistence |
| MechBuddyTests | Unit + a11y contracts |

## Dependency rules

1. Domain: Foundation only (no SwiftUI, UIKit, SwiftData).
2. Data imports Domain; Persistence is an implementation detail of Data.
3. Features import Domain + DesignSystem; repos via `AppDependencies`.
4. No feature-to-feature imports.
5. Logging via `AppLog` only.
6. Release gates via `ReleaseSurface` only — no scattered `#if` / magic booleans in Views.

## Core Domain types

See also [ContentPackSpec](ContentPackSpec.md) and [MatchSessionSpec](features/MatchSessionSpec.md).

```swift
public struct GameModeId: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
}

public enum PlayEngineId: String, Codable, Sendable {
    case alphaStrikePhased
    case classicTWPhased
}

public struct PlayCapabilities: Sendable, Equatable, Codable {
    public var showsGuidedMission: Bool
    public var showsSATOR: Bool
    public var showsArmorStructurePips: Bool
    public var showsHitLocations: Bool
    public var showsHeatScale: Bool
    public var showsPVBalance: Bool
    public var showsPhysicalAttacks: Bool
    public var allowsMULPasteImport: Bool
}

public protocol PlayEngine: Sendable {
    var id: PlayEngineId { get }
    var phaseOrder: [PhaseId] { get }
    func advance(from: PhaseId) -> PhaseId?
    func prompt(for: PhaseContext) -> PhasePrompt
}

public protocol GameModeRegistry: Sendable {
    func descriptor(for: GameModeId) -> GameModeDescriptor?
    func engine(for: GameModeId) -> (any PlayEngine)?
    var reachableModes: [GameModeDescriptor] { get } // respects ReleaseSurface input
}
```

Combat math is **not** on `PlayEngine`. Use mode-specific resolvers (`SATORResolver`, later `ClassicWeaponResolver`) selected by capabilities / engine id in the composition root — still not in Views.

## Command pattern

User-intent commands (`StartMission`, `AdvancePhase`, `ResolveSATORAttack`, …) keep Domain reusable for widgets / App Intents later. ViewModels translate controls → commands → reduce `MatchSession` → persist.

## Navigation

- Root: iOS 26 `TabView` + `.sidebarAdaptable` + minimize-on-scroll — [IOS26PlatformSpec](IOS26PlatformSpec.md), [AppShellSpec](AppShellSpec.md)
- `AppRouter`: selected tab, Play path, presented sheets, active `MatchSession.id`
- Battle: `fullScreenCover` + in-cover glass phase dock
- Deep links soft-fail when gated

## DI

`AppDependencies` at launch; `@Observable` graph or environment injection. Test doubles for all repos + `RandomNumberGenerator`.

### Required protocols (Phase 0–6)

```swift
protocol MatchSessionRepository: Sendable {
    func loadActive(mode: GameModeId) async throws -> MatchSession?
    func save(_ session: MatchSession) async throws
}

protocol ForceRosterRepository: Sendable {
    func loadAll() async throws -> [ASUnitRecordDTO]
    func upsert(_ unit: ASUnitRecordDTO) async throws
    func resetToBoxRoster() async throws
}

protocol ContentCatalogRepository: Sendable {
    func gameModesManifest() throws -> GameModesManifest
    func ridgeLineScenario() throws -> RidgeLineScenarioDTO
    func boxRoster() throws -> [BoxCardDTO]
    func critTable() throws -> CritTableDTO
    func rulesTopics() throws -> RulesTopicsDTO
}

protocol ChecklistStore: Sendable {
    func load() async -> ChecklistState
    func save(_ state: ChecklistState) async throws
}

protocol PreferencesStore: Sendable {
    func load() async -> UserPreferences
    func save(_ prefs: UserPreferences) async throws
}

protocol GameModeRegistry: Sendable { /* see earlier */ }

protocol ReleaseSurfaceProviding: Sendable {
    var isFullProductSurface: Bool { get }
    func isEnabled(_ flag: ReleaseFlag) -> Bool
}

struct AppDependencies {
    var matchSessions: any MatchSessionRepository
    var forceRoster: any ForceRosterRepository
    var content: any ContentCatalogRepository
    var checklist: any ChecklistStore
    var preferences: any PreferencesStore
    var modes: any GameModeRegistry
    var releaseSurface: any ReleaseSurfaceProviding
    var logger: any AppLogging
    var rng: any RandomNumberGenerator  // for optional in-app dice only
}
```

Domain reducers are pure functions — **not** on `AppDependencies`. ViewModels call `MatchCommand` reducer then `matchSessions.save`.

## Scalability risks (pre-mitigated)

| Risk | Mitigation |
|------|------------|
| Mode `switch` sprawl | Registry + capabilities + ContentPack checklist |
| God ViewModels | Commands + per-sheet VMs; battle VM coordinates only |
| Force vs match mutation bugs | Match snapshot vs library — MatchSessionSpec |
| UIKit tab hacks | Banned; use SwiftUI Tab/cover APIs |
| Analytics PII | TelemetrySpec allowlist when enabled |

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-08-21 |
| Commit | — |
| Code paths | *not implemented* |
