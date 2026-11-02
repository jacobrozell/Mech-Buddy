# iOS 26 Platform Spec — Mech Buddy

**Status:** Authoritative for platform UX and SDK assumptions.  
**Deployment:** iOS **26.0** / iPadOS **26.0** minimum. Xcode **26**. Swift **6**.

No compatibility shims for earlier OS versions. Prefer current APIs; do not carry iOS 17-era workarounds.

---

## Two-layer interface (Liquid Glass)

Apple’s iOS 26 model:

| Layer | Role in Mech Buddy | Brand? |
|-------|-------------------|--------|
| **UI / navigation** | Tab bar, toolbars, sheets, menus, phase dock chrome | Prefer **system Liquid Glass**; monochrome symbols; tint only for meaning |
| **Content** | Battle readouts, roster cards, TN gauge, pip tracks, rules copy | **Brand expression** (signal / coolant / damage) lives here |

Rules:

1. Do **not** paint custom opaque “hull” bars over `TabView` / `NavigationBar` — let system materials adopt Liquid Glass.
2. Put brand color **inside scroll content** so glass samples it.
3. Custom `glassEffect` only for **functional** floating controls (e.g. phase dock buttons) grouped in `GlassEffectContainer`.
4. Glass cannot sample other glass — never stack adjacent custom glass without a shared container.
5. Prefer **Regular** glass; Clear only with dimming and small footprints.
6. Test Reduce Transparency, Reduce Motion, and Increase Contrast — system components adapt; custom glass must too.
7. Do **not** set custom `presentationBackground` on sheets unless there is a documented exception — default sheet glass is correct.

References: [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass), WWDC25 *Meet Liquid Glass* / *Build a SwiftUI app with the new design*, WWDC26 *Communicate your brand identity on iOS*.

---

## Structural APIs (required patterns)

### Root `TabView`

```swift
TabView(selection: $router.selectedTab) {
    Tab("Play", systemImage: "flag.checkered", value: .play) { PlayRoot() }
    Tab("Force", systemImage: "shield.lefthalf.filled", value: .force) { ForceRoot() }
    Tab("Rules", systemImage: "book", value: .rules) { RulesRoot() }
    Tab("Settings", systemImage: "gearshape", value: .settings) { SettingsRoot() }
}
.tabViewStyle(.sidebarAdaptable)          // iPhone tabs ↔ iPad sidebar
.tabBarMinimizeBehavior(.onScrollDown)    // content-first on phone lists
```

Optional later: `Tab(role: .search)` for Rules search — not in 1.0 unless search ships.

### Battle immersion

When a match is active and the user enters battle:

- Present **`fullScreenCover`** (or equivalent immersive stack) for `as.battle` / `classic.battle`
- Phase dock is **content-adjacent chrome** inside that cover: `GlassEffectContainer` + glass buttons — **not** `tabViewBottomAccessory` on the root tab bar (battle leaves the tab context)
- Dismiss returns to Play with **autosave** (see MatchSessionSpec / AppShell — no dirty-discard prompt)
- Do **not** manually hide `UITabBar` via UIKit hacks (Tabletome legacy)

### Sheets & morphing

- Present SATOR / Unit Focus / Crit from glass toolbar or dock buttons
- Prefer system sheet morph / zoom transitions from the control that opened them
- Partial-height sheets OK for Unit Focus; SATOR may need large detent for Dynamic Type

### Toolbars

- Monochrome SF Symbols by default
- `tint` only for primary CTA meaning (e.g. destructive End match)

---

## Concurrency & observation

| Topic | Rule |
|-------|------|
| Language mode | Swift 6; treat warnings as errors in CI when practical |
| ViewModels | `@Observable` `@MainActor` — no `ObservableObject` / `Combine` for new code |
| Domain | `Sendable` value types; pure functions; no actors required for dice math |
| Persistence | Isolate I/O in Data; MainActor VMs call repos via `async` |
| Clocks / RNG | Inject `RandomNumberGenerator` + `Clock` for tests |

---

## Adaptive layout (idiom-first)

| Device | Pattern |
|--------|---------|
| iPhone portrait | Single column; minimize tab bar on scroll |
| iPhone landscape | Battle: unit strip + tool side-by-side when `verticalSizeClass == .compact` **and** idiom phone |
| iPad | `.sidebarAdaptable`; optional `NavigationSplitView` for Rules; battle may split roster \| tool |

Detect phone vs pad with **idiom**, not horizontal size class alone.

---

## Accessibility (iOS 26)

- Dynamic Type through accessibility sizes on TN gauge and dock
- VoiceOver: announce TN after SATOR changes; announce phase changes
- Reduce Motion: disable glass morph flourishes; keep state changes
- Reduce Transparency: verify custom glass fallbacks remain legible
- Hit targets ≥ 44×44 pt

---

## Explicit non-goals

- Back-deploy to iOS 18/17
- Custom tab bar replacement
- Heavy visionOS / macOS targets in v1 (APIs may be used where free via SwiftUI)

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-08-21 |
| Commit | — |
| Code paths | *not implemented* |
