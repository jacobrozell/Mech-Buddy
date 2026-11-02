# Spec consistency audit — 2026-08-21

Audit of Mech Buddy Phase 1 specs before coding. Resolutions applied in the same change set.

## Findings (severity → resolution)

| Sev | Issue | Resolution |
|-----|-------|------------|
| **High** | Min iOS listed as **17.0** while product target is **iOS 26** | Locked `IPHONEOS_DEPLOYMENT_TARGET = 26.0` everywhere; no `#available(iOS 26)` fallbacks |
| **High** | Design system pushed custom “hull chrome” onto navigation — fights Liquid Glass | Split **UI layer** (system glass) vs **content layer** (brand); see DesignSystem + IOS26Platform |
| **High** | Architecture named engines/capabilities but no **PlayEngine protocol**, commands, or “add a mode” path | Expanded ArchitectureSpec + ContentPackSpec |
| **Med** | `play.home` vs `as.modeHome` / `classic.modeHome` ambiguous | `play.home` = router shell; mode homes are content |
| **Med** | `force.roster` vs `force.as.list` duplicate roots | `force.roster` hosts mode-specific list |
| **Med** | `as.damageApply` vs SATOR “Apply to target” overlap | Damage apply lives in SATOR; crit is separate sheet |
| **Med** | Battle “hide tab bar” copies Tabletome; iOS 26 prefers content-first glass + accessories | AppShell: battle = fullScreenCover; phase dock = glass accessory inside battle — root TabView not manually hidden mid-scroll hacks |
| **Med** | Ridge Line win text: Mission “destroy” vs First games “destroy or cripple” | Guided mission locks **destroy both**; turn-6 structure tiebreak; catalog copy aligned |
| **Med** | Heat on roster always vs Ridge Line “heat off” | `ScenarioRuleset` flags gate OV/physical/withdrawal **prompts**; roster may still store heat for Free Battle |
| **Low** | Architecture Verification undated | Updated |
| **Low** | Swift 5.10 vs iOS 26 / Xcode 26 | Swift **6**, strict concurrency |
| **Low** | Missing MatchSession, telemetry stub, governance, platform spec | Added |

## Still open (owner)

| Item | Notes |
|------|-------|
| App display name vs Mech Buddy | Confirm before App Store metadata |
| Tip jar URL | Remains `nil` |
| Classic tools slice tag | post-1.0; no date |

## Specs added/updated this pass

- `specs/IOS26PlatformSpec.md` (new)
- `specs/ContentPackSpec.md` (new)
- `specs/SpecGovernance.md` (new)
- `specs/TelemetrySpec.md` (new)
- `specs/features/MatchSessionSpec.md` (new)
- Expanded: Architecture, DesignSystem, AppShell, TechStack, ScreenCatalog, Accessibility, BattleTable, GuidedMission, ModeHome, README, brainstorm, inventory, checklist
