# Bundled Alpha Strike fixtures (owner-locked)

**Source:** the four Ridge Line cards were checked against [masterunitlist.battletech.com](https://masterunitlist.battletech.com/) unit pages on 2026-11-01. They already matched.  
**Policy (2026-08-21):** Ship **bundled** Ridge Line + box roster metadata in the app. User may edit; MUL paste remains optional.  
**Later:** army building and any new roster use that same site as the card lookup. 1.0 stays Ridge Line only. Do not bulk-download the catalog.

Skill default: **4** for all unless edited.

## Ridge Line forces

| Side | Unit | PV | MV | TMM | SZ | S | M | L | OV | A | S(truct) | Abilities |
|------|------|----|----|-----|----|---|---|---|----|----|----------|-----------|
| Lance A | Shadow Hawk SHD-2H | 30 | 10"/6"j | 2 | 2 | 2 | 2 | 1 | 0 | 5 | 5 | IF0*,JMPW1 |
| Lance A | Commando COM-2D | 17 | 12" | 2 | 1 | 2 | 2 | 0 | 0 | 2 | 2 | SRM1/1 |
| Lance B | Wolverine WVR-6M | 32 | 10"j | 2 | 2 | 2 | 2 | 0 | 1 | 6 | 5 | — |
| Lance B | Locust LCT-1V | 18 | 16" | 3 | 1 | 1 | 1 | 0 | 0 | 2 | 2 | — |

## Box roster seed (names / sides / size)

| Name (front) | Back variant | SZ | Default side |
|--------------|--------------|----|--------------|
| Locust LCT-1V | Locust LCT-1E | 1 | B |
| Commando COM-2D | Commando COM-3A | 1 | A |
| Shadow Hawk SHD-2H | Shadow Hawk, Durant Carlyle | 2 | A |
| Wolverine WVR-6M | Wolverine WVR-6R | 2 | B |
| Catapult CPLT-C1 | Catapult CPLT-K2 | 3 | B |
| Thunderbolt TDR-5S | Thunderbolt TDR-5SE | 3 | A |
| Awesome AWS-8Q | BattleMaster BLR-1G | 4 | A |
| BattleMaster BLR-1G | Awesome AWS-8Q | 4 | B |

Full numeric cards for non–Ridge Line units: **name/size seeds** in `Resources/Content/AlphaStrike/as-box-roster.json` (stats `null` until authored). Ridge Line four are filled and match `as-ridge-line.json` (golden fixtures).
