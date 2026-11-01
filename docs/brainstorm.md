# Brainstorm — TableMech (non-authoritative)

> Ideas and product direction. Promote to `specs/` when behavior is locked.  
> Source walkthrough: [`../FutureIdeas/alpha-strike-walkthrough.html`](../FutureIdeas/alpha-strike-walkthrough.html)

## Vision

An **offline-first** iOS tableside companion for BattleTech players who own a boxed set (or print-and-play maps) and need:

1. Guided first games (Alpha Strike Ridge Line → Full Lances)
2. Live **roster + damage** tracking without dry-erase cards
3. Fast **target-number** building (Alpha Strike SATOR) and later Classic hit/location tools
4. Quick-reference tables without flipping PDFs mid-turn

**Not** a digital rules substitute for Catalyst books — summaries + helpers that link to free official downloads.

Later shape (rosters, starter boxes, then Classic): [FutureIdeas/guided-play.md](../FutureIdeas/guided-play.md). Not 1.0.

## Modes

| Mode | Player shorthand | Play engine | v1 intent |
|------|------------------|-------------|-----------|
| **Alpha Strike** | “The simple card game” | Phased turn (Init → Move → Combat → End) | **MVP guided play** |
| **Classic** | “Normal BattleTech” / hex record sheets | Classic TW phase model + hit locations | **Screen map + stubs**; tools-first slice later |

Architecture must treat modes as **play engines + capabilities**, not `if alphaStrike` sprinkled through Views (Tabletome lesson).

## Target users

| Persona | Need |
|---------|------|
| New box owner | Ridge Line mission walkthrough + checklist |
| Returning AS player | SATOR stack + roster bubbles mid-game |
| Classic player | Record-sheet damage, heat, hit location (later) |
| Accessibility user | VoiceOver-first tableside controls, large Dynamic Type |

## What the HTML already proves

The walkthrough is a **web prototype** of tableside jobs:

| HTML tab | Tableside job |
|----------|----------------|
| Mission | Guided scenario (load forces → table → phase coach) |
| Set up | Pre-game checklist + card literacy |
| The turn / Move / Shoot / Damage | Rules coaching + interactive calculators |
| First games | Scenario catalog |
| Roster | Force state (PV, armor/structure, heat, crits) |
| Tables | Quick reference |

Mobile IA should **not** copy nine top-level tabs. Organize by **jobs** (Play / Force / Rules / Settings) and open tools as sheets from the battle table.

## Legal / content

- Summaries in our own words; link `battletech.com/downloads` for free Quick-Start
- Unit stats: prefer **user-entered** card values + optional MUL paste/import; do not ship copyrighted card art or full MUL dumps without policy check
- Trademarks: Topps / Catalyst — unofficial fan aid disclaimer in Settings + App Store

## MVP lean ship (proposed)

**In (Alpha Strike):**

- Mode home + Getting Started checklist
- Ridge Line guided mission
- Battle table with phase dock
- SATOR attack resolver → apply damage to roster
- Box roster (8 cards) + PV balance
- Rules quick-reference (AS tables)
- Settings / legal links

**Out / gated:**

- Classic full guided match
- Network MUL auto-fetch in Release (paste import OK; live fetch behind flag)
- Cloud sync, accounts
- Full Alpha Strike Companion ruleset beyond Quick-Start scope

## Owner decisions (defaults)

| Decision | Choice |
|----------|--------|
| App name / bundle | **TableMech** / `com.jacobrozell.tablemech` |
| Positioning | BattleTech guided matches |
| Min iOS | **26.0** |
| Classic in v1 | **Visible Coming soon** (not playable) |
| Hotseat | One device |
| Dice | **Physical primary** — enter results |
| Bundled stats | Ridge Line + box fixtures |
| Persistence | **SwiftData** + SchemaV1… |
| Tip jar | None |
| iPad | Supported |
