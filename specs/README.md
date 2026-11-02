# Specs Index — Mech Buddy

Authoritative behavior contracts. Brainstorm (`docs/brainstorm.md`) is **not** authoritative.

**Latest audit:** [docs/audits/2026-08-21-spec-consistency.md](../docs/audits/2026-08-21-spec-consistency.md)

## Governance

See [SpecGovernance.md](SpecGovernance.md). On conflict: Architecture + IOS26Platform → system specs → feature/screen specs → inventory → brainstorm.

## System specs

| Spec | Scope |
|------|-------|
| [ArchitectureSpec.md](ArchitectureSpec.md) | Layers, engines, **DI protocols**, commands |
| [DomainModelSpec.md](DomainModelSpec.md) | **Concrete Domain types** |
| [IOS26PlatformSpec.md](IOS26PlatformSpec.md) | Liquid Glass, TabView, Observation |
| [ContentPackSpec.md](ContentPackSpec.md) | Modes, packs, add-a-mode checklist |
| [TechStackSpec.md](TechStackSpec.md) | Xcode 26, Swift 6, iOS 26 |
| [DesignSystemSpec.md](DesignSystemSpec.md) | UI vs content layers |
| [UXVisualPolishSpec.md](UXVisualPolishSpec.md) | MVP / 1.x polish |
| [DataSchemaSpec.md](DataSchemaSpec.md) | **JSON shapes** + SwiftData SchemaV1 |
| [AccessibilitySpec.md](AccessibilitySpec.md) | WCAG + **Phase 6 ID set** |
| [LocalizationSpec.md](LocalizationSpec.md) | String policy |
| [TestPlanSpec.md](TestPlanSpec.md) | CI + **golden vectors** |
| [ReleaseSurfaceSpec.md](ReleaseSurfaceSpec.md) | Gates + **Swift API** + Coming soon copy |
| [AppShellSpec.md](AppShellSpec.md) | Tabs, **sheet stack**, deep links |
| [TelemetrySpec.md](TelemetrySpec.md) | Stub |
| [SpecGovernance.md](SpecGovernance.md) | Conflict rules |

**Agent entry:** [AGENTS.md](../AGENTS.md) · **Phase 6 DoD:** [phase-6-vertical-slice.md](../docs/development/phase-6-vertical-slice.md)

## Screen inventory

| Spec | Scope |
|------|-------|
| [screens/ScreenCatalog.md](screens/ScreenCatalog.md) | Master list of every mobile screen |

## Feature specs

| Spec | Mode | Status |
|------|------|--------|
| [features/HotseatSpec.md](features/HotseatSpec.md) | Both | draft — algorithm |
| [features/MatchSessionSpec.md](features/MatchSessionSpec.md) | Both | draft — state machine |
| [features/ModeHomeSpec.md](features/ModeHomeSpec.md) | Both | draft |
| [features/GettingStartedSpec.md](features/GettingStartedSpec.md) | AS | draft |
| [features/GuidedMissionSpec.md](features/GuidedMissionSpec.md) | AS | draft — AC + DoD link |
| [features/BattleTableSpec.md](features/BattleTableSpec.md) | AS | draft |
| [features/SATORAttackSpec.md](features/SATORAttackSpec.md) | AS | draft |
| [features/RosterSpec.md](features/RosterSpec.md) | AS | draft |
| [features/UnitFocusSpec.md](features/UnitFocusSpec.md) | AS | draft |
| [features/RulesReferenceSpec.md](features/RulesReferenceSpec.md) | Both | draft |
| [features/SettingsSpec.md](features/SettingsSpec.md) | Both | draft |
| [features/ClassicModeSpec.md](features/ClassicModeSpec.md) | Classic | planned |

## Game mode docs

- [docs/game-modes/PRODUCT_SCOPE.md](../docs/game-modes/PRODUCT_SCOPE.md)
