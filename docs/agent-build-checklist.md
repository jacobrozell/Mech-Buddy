# Agent Build Checklist — Mech Buddy

Domain-agnostic process adapted for this app. Full template: `~/Desktop/personal/workspace/agent-build-checklist-template.md`.

**App idea:** Mech Buddy — BattleTech guided matches; Alpha Strike Ridge Line MVP; Classic Coming soon.

**Read first:** [AGENTS.md](../AGENTS.md) · [product-readiness](product-readiness.md) · [phase-6 DoD](development/phase-6-vertical-slice.md)

## Progress log

| Phase | Completed | Commit | Notes |
|-------|-----------|--------|-------|
| 0 | 2026-08-21 | — | XcodeGen, layers, Content JSON in bundle, first build + 21 tests |
| 1 | 2026-08-21 | — | Specs + Domain models + Phase 6 DoD + DI/JSON/vectors |
| 3 | 2026-08-21 | — | SATOR / damage / crit / phase / MatchReducer + unit tests |
| 4 | partial | — | SwiftData SchemaV1 + autosave/resume |
| 5–6 | partial | — | Tab shell + Ridge Line battle flow + Leave autosave |
| 2,4,7–18 | | | |

## Phase 0 — Repo & agent infrastructure

- [x] **0.1–0.11** XcodeGen, folders, gitignore, rules, SwiftLint, first build (`IPHONEOS_DEPLOYMENT_TARGET=26.0`)
- [ ] Git remote + first commit (when owner asks)
- [ ] MCP session defaults / GitHub Pages legal HTML

## Phase 1 — Spec system

- [x] System + feature specs, ScreenCatalog, owner locks, DomainModelSpec, Phase 6 DoD, AGENTS.md

## Phase 3–5

- [x] Domain engines + unit tests (SATOR vectors, crits, phases)
- [x] Content JSON loaders
- [x] SwiftData SchemaV1 persistence + autosave/resume
- [x] App shell TabView + ReleaseSurface + Ridge Line battle shell

## Phase 6 — Ridge Line vertical slice

See **[phase-6-vertical-slice.md](development/phase-6-vertical-slice.md)**.

```
Play → Ridge Line → Battle → Enter initiative → SATOR enter 2D6 → Apply → Crit → End → Victory
```

- [x] Happy path UI wired (manual dice entry)
- [x] Resume after kill app / Leave (SwiftData)
- [ ] Full a11y / polish DoD green
