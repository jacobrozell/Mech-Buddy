# Onboarding Spec — Mech Buddy

Replaces the Getting Started checklist (`as.gettingStarted`, removed) and the Play “New here?” nudge.

## User story

As a new player, I answer a few one-question screens, pick which BattleTech I want to learn based on how much time, rules, and gear I want to commit, say which boxes and ’Mechs I own, and land on Play with my first mission up next.

## The two games (copy source)

Both use the same miniatures.

| | Alpha Strike | Classic BattleTech (Total Warfare) |
|---|---|---|
| Time | About an hour for 4 vs 4 | A few hours a game |
| Rules | One card per ’Mech, one to-hit roll per ’Mech, 0–4 heat via overheat | Record sheet per ’Mech, hit locations, weapon-by-weapon attacks, full heat scale, piloting rolls |
| Gear | Any table, inches, tape measure. Cards free on the Master Unit List | Hex maps, record sheets |
| In the app | Playable: the Mission path on Play | **Coming soon** (`ReleaseFlag.classicComingSoonEntry`) |

Alpha Strike teaches the shared core (2D6 vs target number, movement modifiers, terrain, heat, crits) but not Classic’s bookkeeping. The app says so plainly and routes Classic players to Alpha Strike for now.

## Presentation

- `RootTabView` presents `OnboardingFlowView` as a `fullScreenCover` on first appear when `AppPreferences.hasCompletedOnboarding` is false. No slide-up on launch (animations disabled for that one presentation).
- Reopened with `OpenOnboardingAction` (`@Environment(\.openOnboarding)`) from **Settings → Your game** and **Play → Classic card → Change game**. Entry `.changeTrack`.
- Finishing or skipping a first run switches the root tab to Play.

## Chrome (every screen)

| Element | Behavior | ID |
|---------|----------|----|
| Back | Chevron, hidden on the first screen | `onboarding.back` |
| Progress | Capsule bar, “Step N of M” for VoiceOver | `onboarding.progress` |
| Skip / Close | First run: **Skip** marks onboarding complete (keeps any pick) and goes to Play. Change game: **Close** saves nothing. Hidden on the last screen | `onboarding.skip` |
| Continue | One primary button pinned to the bottom. Disabled on the track screen until a game is picked, and on the box screen until a box or None yet is picked | `onboarding.continue` |

Screens change with a horizontal push; Reduce Motion uses a cross-fade. VoiceOver focus moves to each screen’s title.

## Screens

Order comes from `OnboardingStep.steps(for:classicAvailable:)`:

| Entry | Classic entry on | Classic entry off |
|-------|------------------|-------------------|
| First run | Welcome → Track → Boxes → ’Mechs → Kit → First mission | Welcome → Boxes → ’Mechs → Kit → First mission |
| Change game | Track → Boxes → ’Mechs → Kit → First mission | Welcome → Boxes → ’Mechs → Kit → First mission |

### 1. Welcome (`onboarding.step.welcome`)

Hero symbol, “Learn BattleTech at your table”, one line on what the app does (you move the minis; it tracks turns, math, damage), and a numbered roadmap of the screens that follow. Button: **Get started**.

### 2. Track (`onboarding.step.track`)

“Which BattleTech do you want to learn?” Two `ChoiceTile`s (single choice), each with a badge and three commitment rows (time, rules, gear) from `LearningTrack.commitments`:

- `onboarding.track.alphaStrike` — Alpha Strike, “Quick and card-based”, badge **Play now**
- `onboarding.track.classic` — Classic BattleTech, “The full-detail game”, badge **Coming soon**

Picking Classic shows a note (`onboarding.track.classicNote`): Classic isn’t in the app yet; start with Alpha Strike, which teaches the core; Classic adds record sheets and hex maps. Tiles sit side by side on iPad and iPhone landscape, stacked otherwise and at accessibility sizes. Change game preselects the saved track.

### 3. Boxes (`onboarding.step.boxes`)

“Which boxes do you own?” Multi-select `ChoiceTile`s, one per box in `as-box-sets.json` (`onboarding.box.<id>`): title, subtitle, game badge (Alpha Strike / Classic / Classic + Alpha Strike), and “N minis”. Last tile: **None yet** (`onboarding.box.none`), “Coins or any minis work for your first game.” None yet clears the box picks; picking a box clears None yet. Continue is disabled until one is picked (VoiceOver hint “Pick a box or None yet”). Two columns on iPad / iPhone landscape, one otherwise and at accessibility sizes. An unconfirmed box (Mercenaries) has the hint that its list isn’t confirmed and you can add its ’Mechs by hand.

### 4. Your ’Mechs (`onboarding.step.mechs`)

A short review. For each picked box: its title and every unit, pre-ticked (`onboarding.mechs.unit.<boxId>.<name>`, value “Have it” / “Missing”). Unticking marks it missing. An unconfirmed box shows “We haven’t confirmed what’s in this box yet. Add its ’Mechs by hand.” (`onboarding.mechs.unconfirmed.<boxId>`). Then **Add a ’Mech**: a text field (`onboarding.mechs.addField`) and Add (`onboarding.mechs.addButton`) for singles, free text, no stats; each single has a remove button (`onboarding.mechs.single.remove.<name>`). Rows are at least 44 pt; the field and Add stack at accessibility sizes.

Leaving either box screen with anything owned ticks the kit’s **Miniatures** (`OnboardingCollection.kitChecks`).

### 5. Kit (`onboarding.step.kit`)

“What do you have?” Multi-select `ChoiceTile`s from `as-getting-started.json` (items without `linkURL`), ids `minis`, `dice`, `tape`, `maps` (`onboarding.kit.{id}`). Ticks persist in `AppPreferences.gettingStartedChecks`. Below: “Unit cards are built in” (`onboarding.kit.cards`) and link items (`dl_qs`, Quick-Start PDF, `onboarding.kit.link.{id}`, “Opens in Safari”). Two columns on iPad / iPhone landscape, one otherwise. Continue never blocks.

### 6. First mission (`onboarding.step.firstMission`)

Eyebrow “Start with Alpha Strike” for Classic, else “Alpha Strike”. “Your first mission” (or “Your next mission” once any is cleared). A card (`onboarding.firstMission.card`) with the path node, mission number, title, “2 vs 2 · about 40 min · 6 turns”, and **You’ll learn** chips. The mission is `OnboardingMissions.nextMissionID` over the catalog ladder and `completedMissions`. Then either “You have everything you need” or a **Before you sit down, grab** list of unticked kit. Classic adds a line that Classic is coming and the skills carry over. Button: **Go to my mission path** — saves and closes onto Play, where the same mission is Up next.

## Persistence

`AppPreferences` (keys owned, so `reset()` / `-reset_state` clears them), through `OnboardingStore`:

| Key | Value |
|-----|-------|
| `onboarding.track` | `alphaStrike` / `classic`; absent = no pick (Play treats it as Alpha Strike) |
| `onboarding.completed` | Bool |
| `settings.hasSeenIntro` | Legacy, read only. If set and `onboarding.completed` is absent, load as complete with Alpha Strike |
| `settings.gettingStartedChecks` | Kit ticks (ids) |
| `collection.owned` | JSON `OwnedCollection` through `CollectionStore`: boxes (id → copies), missing (box id → unit → copies), singles (name → copies). Absent = not answered. None yet = empty collection |

The box answers are held in the flow and saved on finish, or on first-run Skip once a box or None yet was picked (`AppPreferences.recordCollection`). Change game’s Close saves nothing. Change game preloads the saved collection.

Without the Classic entry, finishing always saves `alphaStrike`. `-skip_onboarding` sets `hasCompletedOnboarding`.

## Play by track

`PlayTrackLayout.make(track:classicEntryEnabled:)`:

| Track | Classic entry on | Play shows |
|-------|------------------|------------|
| Classic | yes | **Classic spotlight** card above the path (`play.classicSpotlight`): “Your game”, Coming soon badge, not playable yet, start with the Alpha Strike missions below. Links: **What’s coming** (`play.classicComingSoon`, opens the sheet) and **Change game** (`play.changeGame`). No bottom Classic row |
| Alpha Strike / none | yes | Mission path, then the small **More modes** Classic row (`play.classicComingSoon`) |
| any | no | Mission path only |

## Logging

`AppLogging` category `onboarding`: finished (entry, track), skipped (step), collection (box ids, singles count), and content load errors.

## Tests

`Tests/Unit/OnboardingContentTests.swift` (kit JSON contract). `Tests/Unit/OnboardingModelTests.swift` (steps incl. box placement, progress, persistence incl. legacy key and reset, track → Play layout, still-needed, next mission). `Tests/Unit/CollectionTests.swift` (box content, collection, chassis matching, persistence and reset, Miniatures auto-tick). Model code lives in `Data/Onboarding/OnboardingModel.swift` and `Data/Collection/CollectionModel.swift` (MechBuddyData).

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.0.0 |
| Last verified | 2026-11-24 |
| Commit | — (uncommitted) |
| Code paths | `Data/Onboarding/OnboardingModel.swift`, `Data/Collection/CollectionModel.swift`, `Features/Onboarding/OnboardingFlowView.swift`, `OnboardingSteps.swift`, `OnboardingCollectionSteps.swift`, `OpenOnboardingAction.swift`, `DesignSystem/Components/ChoiceTile.swift`, `App/RootTabView.swift`, `App/AppPreferences.swift`, `App/AppDependencies.swift`, `Features/Play/PlayHomeView.swift`, `Features/Play/SettingsHomeView.swift`, `Resources/Content/AlphaStrike/as-getting-started.json`, `as-box-sets.json` |
