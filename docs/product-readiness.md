# Pre-build product readiness — TableMech

**Audience:** owner + agents before Phase 0/3.  
**Last updated:** 2026-11-01

---

## Owner decision log

| Date | Decision | Chosen |
|------|----------|--------|
| 2026-08-21 | Min iOS | **26.0** |
| 2026-08-21 | MVP mode | Alpha Strike Ridge Line guided match |
| 2026-08-21 | Display name | **TableMech** |
| 2026-08-21 | Positioning | BattleTech **guided matches** (tableside companion) |
| 2026-08-21 | Bundle ID | `com.jacobrozell.tablemech` |
| 2026-08-21 | Classic visibility | **Visible “Coming soon”** (not fully hidden) |
| 2026-08-21 | Hotseat | **One phone/iPad** shared — [HotseatSpec](../specs/features/HotseatSpec.md) |
| 2026-08-21 | Dice | **Physical primary** — app **enters results** (in-app roll secondary/hidden or advanced) |
| 2026-08-21 | Bundled stats | **Yes** — Ridge Line + box/other fixtures — [bundled-fixtures](game-modes/alpha-strike/bundled-fixtures.md) |
| 2026-08-21 | Persistence | **SwiftData**, versioned schema from day one (`SchemaV1`…) |
| 2026-08-21 | Movement mode | Configurable; **not required** to attack unless rules force that unit to move |
| 2026-08-21 | Write survivors back to Force library on victory | **No** (1.0) |
| 2026-08-21 | iPad | **Supported** (sidebar-adaptable; not phone-only) |
| 2026-08-21 | Tip jar | **None** (`AppLinks.tipJar = nil`) |
| 2026-08-21 | Free Battle | **1.1** (gated off in 1.0 Release) |
| 2026-11-01 | Playable forces in 1.0 | **Ridge Line only.** Army building, Free Battle, and other rosters stay later. |
| 2026-11-01 | Card lookup for army building | When that work starts, look up Alpha Strike cards on [masterunitlist.battletech.com](https://masterunitlist.battletech.com/). Do not bulk-download or ship the catalog. |
| 2026-11-01 | C1 Ridge Line stats | Checked the four units against their MUL pages. Numbers already match, including Locust LCT-1V TMM 3 (13"–18" is +3). No JSON change. |

---

## Still open (non-blocking for Phase 0)

| # | Question | Default if silent |
|---|----------|-------------------|
| 7 | Rules tab depth | Dense AS essentials (tables + turn) |
| 22–24 | Final disclaimer / privacy HTML / support channel | Placeholder Pages before TestFlight |
| 28–31 | TestFlight telemetry & success metric | Telemetry off |

---

## Specs updated for locked decisions

- HotseatSpec, BattleTableSpec, SATORAttackSpec, UnitFocus (movement), MatchSessionSpec  
- ReleaseSurfaceSpec + ClassicModeSpec (coming soon)  
- DataSchemaSpec + TechStackSpec (SwiftData + SchemaV*)  
- SettingsSpec (no tip jar), README / branding → TableMech  
