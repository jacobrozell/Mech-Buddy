# Several sides: lessons from DartBuddy

Notes for **PM5 (group by side), PM6 (teams) and PM7 (three and four sides)**. Source: the owner's DartBuddy app (`../DartBuddy`), which supports up to 8 players and specs team play. Read these before building those milestones.

## What DartBuddy does

| Topic | DartBuddy | Source |
|---|---|---|
| Player limit | Each mode declares `minimumPlayers` / `maximumPlayers` (default 8); setup checks against them | `Features/Modes/GameModeCatalog.swift` |
| Battle screen | One shared shell with four bands: header, **active band** (current player pinned), **scoreboard** (everyone else, scrolls), input pad | `DesignSystem/Components/MatchScoringBody.swift`, `docs/gameplay-layout-modes.md` |
| Layout choice | One helper decides layout from device idiom, orientation, AX text size and **player count**. 3+ players on iPad switches to a side-by-side layout; the threshold is a named constant (`sideBySidePlayerCountThreshold = 3`). The helper has unit tests | `DesignSystem/Components/GameplayLayout.swift`, `Tests/Unit/GameplayLayoutTests.swift` |
| Teams | Two teams only in v1. `teamSideRaw` is stored on each participant and **frozen at match start**. Engines read that snapshot; they don't build their own team maps | `specs/TeamPlaySpec.md` §5 |
| Team setup | Two columns (Team A / Team B) under the roster, a **Balance teams** button that alternates players, validation keys (unassigned, uneven, below minimum), and Start disabled until the teams are valid | `TeamPlaySpec.md` §6 |
| Turn order | Named policies: `interleaved` (A1, B1, A2, B2…) or `rosterOrder` | `TeamPlaySpec.md` §7 |
| Side colour | A team takes the colour of its first member; the scoreboard shows it as an **accent bar**, and players keep their own chips | `TeamPlaySpec.md` §5.3 |
| Results | Win credit goes to everyone on the winning team; per-player stats stay with the player | `TeamPlaySpec.md` §3 |

## What to reuse in Mech Buddy

1. **Put the layout decision in one place.** Write a `BattleLayout` helper (side count, unit count, idiom, orientation, AX) with a unit test, instead of `if` checks spread through the views. The 4 vs 4 one-screen rule and 1.7 landscape (two columns) both belong there.
2. **Side header with a colour accent bar.** Group rows under each side's header (PM5), with the side colour as a thin bar, and keep the per-'Mech marker colour.
3. **Pin the side that is acting.** In the Movement and Combat phases, the side whose turn it is (from `InitiativeOrder`) stays at the top, and the other sides collapse or scroll. This keeps a 4-sided game usable on one phone.
4. **Freeze the side map at battle start.** `MatchSide` on each unit is already a snapshot; keep it so. Teams (PM6) should be one `teamId` per side, frozen too, and `opponents(of:)` should read it.
5. **Team setup.** Copy the two-column assignment, **Balance** and the validation-keys pattern for PM6 (1 v 2, 2 v 2, 1 v 3).
6. **Declare the limits.** Box scenarios declare their side count. Play allows 2–4 sides, with 3–4 marked [HOUSE] (Quick-Start p. 13 supports only 2 teams).

## What not to copy

- DartBuddy turns are per player. Alpha Strike alternates units by initiative and side (p. 13), so use `InitiativeOrder`, not `interleaved`.
- DartBuddy keeps teams even ("odd teams rejected"). Alpha Strike balances on PV, so 1 v 2 is fine when the PV matches.
