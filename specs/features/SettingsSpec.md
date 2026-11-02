# Settings Spec

## Screen: `settings.home`

A `Form`. Appearance follows the system until Theme is changed. There is no default MechWarrior skill row and no default-rules-mode row. Ridge Line units stay at skill 4 from the scenario file. `AppLinks.tipJar` stays `nil`; the screen has no tip row.

### Gameplay

| Row | Behavior |
|-----|----------|
| Dice | **Real dice** (default) or **Let the app roll**. New games copy `AppPreferences.defaultDiceMode`. In a battle, the same choice is the **Let the app roll** / **Use real dice** link on the dice tray |
| Haptics | On / Off. Default on. `TMHaptics` reads this for dice, hits, misses, crits, phase changes, and victory |
| Keep screen awake | On / Off. Default on. Sets `isIdleTimerDisabled` for the tabs. While the battle cover is open the screen stays awake; closing the cover applies this toggle again |

### Appearance

| Row | Behavior |
|-----|----------|
| Theme | **System** (default) / **Light** / **Dark**. Applied with `preferredColorScheme` in `MechBuddyApp` |

### About

| Row | Behavior |
|-----|----------|
| How to play Ridge Line | Push |
| New here checklist | Push |
| Version | Bundle short version and build. This build is **0.2.0 (1)** |

### Support & legal

| Row | Behavior |
|-----|----------|
| Support | `AppLinks.support`. Hint: Opens in Safari |
| Privacy Policy | `AppLinks.privacy` |
| Accessibility | `AppLinks.accessibility` |

Footer: unofficial fan-aid disclaimer.

### Data

Last section. **Delete saved games** (`settings.deleteAll`) confirms, then deletes match sessions and clears the Getting Started checks. Theme, haptics, dice default, and keep-awake stay.

## AppLinks pattern

```swift
enum AppLinks {
    static let privacy = URL(string: "https://jacobrozell.github.io/Mech-Buddy/privacy.html")!
    static let support = URL(string: "https://jacobrozell.github.io/Mech-Buddy/support.html")!
    static let accessibility = URL(string: "https://jacobrozell.github.io/Mech-Buddy/accessibility.html")!
    static let tipJar: URL? = nil  // locked: no tip jar
}
```

Live code: `Support/Navigation/AppLinks.swift` (URLs built with `makeURL`).

## Accessibility

- `settings.home`, `settings.deleteAll`

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-10-28 |
| Commit | `b9acebb` (tag `0.2.0`) |
| Code paths | `Features/Play/SettingsHomeView.swift`, `App/AppPreferences.swift`, `App/MechBuddyApp.swift`, `Support/Navigation/AppLinks.swift`, `project.yml` (`MARKETING_VERSION` 0.2.0, `CURRENT_PROJECT_VERSION` 1) |
