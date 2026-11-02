# Mode Home Spec — Mech Buddy

## User story

As a player opening Mech Buddy, I land on Play, see resume if needed, and get clear next actions for Alpha Strike guided play (Classic shows Coming soon).

## Screen IDs

| ID | Role |
|----|------|
| `play.home` | Shell: mode rows + resume banner; embeds AS mode home |
| `as.modeHome` | Alpha Strike actions |
| `classic.modeHome` | Coming soon teaser (not playable in 1.0) |

## `as.modeHome` layout (phone)

1. Title: Alpha Strike  
2. **Resume** card if `MatchSession` active for AS — primary  
3. Actions:
   - **Getting Started** → `as.gettingStarted`
   - **How to play Ridge Line** → `as.howToPlay` (app flow: tabs, setup, four steps, win, resume)
   - **Play Ridge Line** → guided mission setup
   - **Scenarios** → `as.scenarios` (Ridge Line only in 1.0; Full Lances gated)
   - **Free battle** → **1.1** (hidden in Release; full surface only)
4. Secondary: Force, Rules  

Also show **Classic — Coming soon** row (teaser).

## Mode switcher / Classic teaser

- Classic is **visible** with Coming soon badge (ReleaseSurface)
- Tap → info sheet; no Classic session
- Force / Rules stay on Alpha Strike until Classic tools ungated
- Settings “Default rules mode” = Alpha Strike only until Classic playable

## Empty / error

| State | UI |
|-------|-----|
| No roster | CTA “Load box roster” |
| Corrupt session | Banner + Reset session |

## Accessibility

- `play.home`, `as.modeHome.resume`, `as.modeHome.gettingStarted`, `as.modeHome.howToPlay`, `as.modeHome.ridgeLine`, `play.classicComingSoon`

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-08-21 |
| Commit | — |
| Code paths | *not implemented* |
