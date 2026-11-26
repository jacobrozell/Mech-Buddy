# App Shell Spec — Mech Buddy

Companion: [IOS26PlatformSpec](IOS26PlatformSpec.md) · [MatchSessionSpec](features/MatchSessionSpec.md).

## Root information architecture

> **See [PlayModeSpec](features/PlayModeSpec.md) § 3 (draft, not built).** With `playMode` on, the shell has five tabs: Learn (today's Play content), Play (Play mode), Force, Rules, Settings. Resume shows on Learn and Play. With the flag off, the four tabs below stand.

Four tabs (phone + iPad via `.sidebarAdaptable`):

| Tab | SF Symbol | Entry ID | Notes |
|-----|-----------|----------|-------|
| Play | `flag.checkered` | `play.home` | AS home + Classic Coming soon |
| Force | `shield.lefthalf.filled` | `force.as.list` | Ridge Line roster (or the match in progress) |
| Rules | `book` | `rules.home` | AS topics |
| Settings | `gearshape` | `settings.home` | Always |

### Tab behavior (iOS 26)

- `.tabBarMinimizeBehavior(.onScrollDown)` on the root `TabView`
- `.tabViewStyle(.sidebarAdaptable)`
- No UIKit tab appearance proxies
- No search tab in 1.0  

## Play routing

```
play.home
  ├─ Resume (if active MatchSession) → fullScreenCover as.battle
  ├─ Play Ridge Line → fullScreenCover as.battle
  ├─ How to play → push (as.howToPlay)
  ├─ Mission node / info → sheet (as.modeHome.missionSheet)
  ├─ Classic spotlight → Change game → fullScreenCover (onboarding)
  └─ Classic BattleTech → sheet (classic.modeHome)
```

How to play is a `navigationDestination` push from Play, so the tab bar stays. Settings repeats it as a `NavigationLink` push. Classic is `ClassicComingSoonSheet` at a medium detent, identifier `classic.modeHome`, with `classic.comingSoon.playAS` starting Ridge Line after the sheet closes. The Play row is `play.classicComingSoon`.

Free Battle hidden in Release (1.1). First launch shows the onboarding flow over the tabs ([OnboardingSpec](features/OnboardingSpec.md)).

Appearance follows the system. Settings → Theme overrides it (`AppPreferences.theme`, applied in `MechBuddyApp`).

## Battle immersion

| Rule | Detail |
|------|--------|
| Presentation | `fullScreenCover` from Play |
| Phase dock | Glass inside cover |
| Dismiss to Play | **Leave** keeps the active session. No discard prompt |
| Abandon | **Discard this game** in More, with a confirm |

## Sheet stack rules

| Sheet | Detent | Stacking |
|-------|--------|----------|
| `as.unitFocus` | medium, large | From a unit card. Shoot or Roll critical runs after this sheet dismisses |
| `as.sator` | large | From **Solve a shot** or from Unit Focus. Apply dismisses it |
| `as.critRoll` | medium, large | After the solver is gone. The battle step shows `CriticalPendingStep`; the dock **Roll critical** presents this sheet. Closing it leaves the crit owed |
| `as.battle.log` | medium, large | Toolbar **What just happened** |
| Classic coming soon | medium | From Play. Identifier `classic.modeHome` |

Apply dismisses the solver first. The battle step then shows the critical, and the dock opens the crit sheet. Initiative and movement are steps on the battle screen.

## Deep links

No custom URL scheme is registered. Play, Force, Rules, and Settings are the four tabs.

## Onboarding

One entry for new players: `OnboardingFlowView`, a `fullScreenCover` on `RootTabView` (a separate cover from the battle one).

| Flow | When | Persist |
|------|------|---------|
| First run | `!AppPreferences.hasCompletedOnboarding` on first appear | `onboarding.track`, `onboarding.completed` |
| Change game | Settings → Your game, or Play’s Classic card → Change game (`@Environment(\.openOnboarding)`) | Same keys; Close saves nothing |

Skippable from every screen but the last. Finishing or skipping lands on Play. The old Getting Started checklist and the “New here?” nudge are gone; its card-reading lesson lives in How to play.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-10-28 |
| Commit | `b9acebb` (tag `0.2.0`) |
| Code paths | `App/RootTabView.swift`, `App/MechBuddyApp.swift`, `App/AppPreferences.swift`, `Features/Onboarding/`, `Features/Play/PlayHomeView.swift`, `ClassicComingSoonSheet.swift`, `Features/Battle/BattleFlowView.swift`, `Steps/CriticalPendingStep.swift`, `CritSheet.swift` |
