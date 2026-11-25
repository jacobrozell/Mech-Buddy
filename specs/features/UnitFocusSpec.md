# Unit Focus Spec — Alpha Strike

## User story

As a player mid-battle, I tap a ’Mech and immediately see its card stats, pips, heat, and actions (resolve attack / set as target) without leaving the table flow.

## Screen: `as.unitFocus` (sheet)

Inspired by Tabletome Unit Focus — **tableside job**, not a buried edit form.

### Content

1. Header — name, side, size, skill, dead/crippled badges
2. Pip tracks — armor / structure + apply damage stepper
3. Stats strip — MV, TMM, S/M/L, OV, PV
4. Movement mode (this turn) — standstill / ground / sprint / jump  
   - **Optional** to set before attacking (defaults to ground in SATOR if unset)  
   - Configurable anytime on the sheet  
   - Forced Withdrawal doesn't force a move mode: a crippled ’Mech picks any mode, but heads for its own edge
5. Heat + crit chips
6. Abilities line
7. Actions:
   - **Resolve attack** (active side) → dismiss + open SATOR with attacker prefills
   - **Set as target** → SATOR target prefill
   - **Roll critical** if owed
   - **Left the table** (Forced Withdrawal missions, any ’Mech still on the table): a **Forced Withdrawal** section with a note ("Crippled: move toward your own edge…" when crippled), a bordered destructive button, then a confirmation. It counts as destroyed; only Undo puts it back. Disabled with a reason line when the reducer would refuse it
   - **Edit stats** → push `force.as.unitEdit` (setup / correction)

### Entry points

| Source | Behavior |
|--------|----------|
| Battle force list | Open focus |
| Phase dock **My Unit** | Last selected ally |
| Force tab row | Open focus (edit-forward) |

## Accessibility

- `as.unitFocus.sheet`
- `as.unitFocus.wounds.{unitId}`
- `as.unitFocus.resolve.{unitId}`
- `as.unitFocus.setTarget.{unitId}`
- `as.unitFocus.leftTable`

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-08-21 |
| Commit | — |
| Code paths | *not implemented* |
