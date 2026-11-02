# AGENTS.md — Mech Buddy

You are building **Mech Buddy**, an iOS 26 BattleTech tableside companion. Specs are authoritative; brainstorm/HTML is not.

## Read first (in order)

1. [docs/product-readiness.md](docs/product-readiness.md) — owner locks  
2. [specs/README.md](specs/README.md) — index + governance  
3. [specs/ArchitectureSpec.md](specs/ArchitectureSpec.md) + [DomainModelSpec.md](specs/DomainModelSpec.md)  
4. [specs/IOS26PlatformSpec.md](specs/IOS26PlatformSpec.md)  
5. [docs/development/phase-6-vertical-slice.md](docs/development/phase-6-vertical-slice.md) — MVP DoD  
6. Feature specs for the screen you touch  
7. [Resources/README.md](Resources/README.md) — bundled JSON paths  

## Non-negotiables

- Min iOS **26**; Swift **6**; SwiftData with **SchemaV1+**  
- No feature `switch` on raw mode strings for combat math — use engines/capabilities  
- No UIKit tab-bar hacks; Liquid Glass system chrome  
- Logging via `AppLog` only  
- Release gates via `ReleaseSurface` only  
- Physical dice primary (enter results)  
- One-device hotseat  
- Free Battle **1.1**; Classic = Coming soon teaser only in 1.0  

## Vertical slice (Phase 6)

```
Play → Load Ridge Line → Table ready → Battle → Enter initiative →
Move modes (optional) → SATOR enter 2D6 → Apply damage → Crit if owed →
End phase → Victory
```

Do not build Free Battle, Full Lances playables, or Classic tools for 1.0 Release.

## Push

Personal GitHub **jacobrozell** via `git@github.com-personal:…` (see workspace git rule). Team `7JT2JB89AV`.
