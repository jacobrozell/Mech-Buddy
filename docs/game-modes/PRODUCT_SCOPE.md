# TableMech — game mode product scope

**Last updated:** 2026-08-21

| Mode | ID | Engine | Rules basis | Release intent |
|------|-----|--------|-------------|----------------|
| **Alpha Strike** | `alpha-strike` | `alphaStrikePhased` | Free Quick-Start + box cards | **1.0 MVP** |
| **Classic** | `classic-tw` | `classicTWPhased` | Total Warfare–style tools | Gated; tools before guided |

## Player routing

```mermaid
flowchart TD
    Q[What are you playing tonight?]
    Q -->|AS cards / Quick-Start| AS[Alpha Strike]
    Q -->|Hex record sheets| CL[Classic]
    AS --> RL[Ridge Line guided]
    AS -.->|1.1| FR[Free battle + roster]
    CL --> RS[Record sheet tools]
```

## Explicitly out of v1

- Full Alpha Strike Companion / tournament rules beyond Quick-Start scope
- Networked multiplayer / shared match sync
- Official MUL bulk redistribution
- Classic full campaign / BV list building
- Army building and Free Battle (1.1). When that work starts, look up cards on [masterunitlist.battletech.com](https://masterunitlist.battletech.com/). 1.0 playable content is Ridge Line only.

## Related

- [ScreenCatalog](../../specs/screens/ScreenCatalog.md)
- [ClassicModeSpec](../../specs/features/ClassicModeSpec.md)
- [ReleaseSurfaceSpec](../../specs/ReleaseSurfaceSpec.md)
