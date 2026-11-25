# Mech Buddy — release todo

Status legend: `[ ]` todo · `[x]` done

- [x] **1.0.0 (2) uploaded to TestFlight** (2026-11-24), from `feature/guided-mission-ladder`. It has all five Alpha Strike missions, onboarding with box ownership, the collection with stand-ins and maps, and the rulebook fixes. Archive: `build/archives/MechBuddy-1.0.0-2.xcarchive`.
- [ ] **Merge the PR** for `feature/guided-mission-ladder` so `main` matches TestFlight.
- [ ] **Publish `docs/` on GitHub Pages** (privacy, support, accessibility).
- [ ] **App Store Connect:** age rating, and the "Data Not Collected" privacy label.
- [ ] **Play at the table:** Ridge Line through Full Lances on 1.0.0 (2). Note issues in `ongoing/play-<date>/NOTES.md`.
- [ ] Classic stays Coming soon until Classic Mission 1 ships.

## Uploading a build

1. Bump `CURRENT_PROJECT_VERSION` in `project.yml`, then run `xcodegen generate`.
2. Archive: `xcodebuild -scheme MechBuddy -configuration Release -destination 'generic/platform=iOS' -archivePath build/archives/MechBuddy-<version>-<build>.xcarchive -allowProvisioningUpdates archive`.
3. Upload from Xcode's Organizer: **Distribute App** → **App Store Connect** → **Upload**. `xcodebuild -exportArchive` with `destination: upload` works only when Xcode has an account with App Store Connect access. On 2026-11-24 it failed with "No Accounts with App Store Connect Access", so that build went up through the Organizer.

## Next session: Alpha Strike polish (owner's focus, 2026-11-24)

Done since 1.0.0 (2): Meet and Greet (box scenario), HT heat attacks, PV by skill, REAR rear-firing weapons (BattleMaster, Archer), Rules tab split by game, Classic record sheets and engine start.

**Polish first (existing Alpha Strike features):**
- [ ] Play Ridge Line through Full Lances at the table on a new TestFlight build (bump `CURRENT_PROJECT_VERSION` to 3). Note issues in `ongoing/play-<date>/NOTES.md`.
- [ ] Rear weapons in the shot picker: check on screen in portrait, landscape and the largest text size (Missions 4–5 BattleMaster). Not checked yet.
- [ ] Victory screen: never seen on screen. Finish a short match and check it.
- [ ] Mission 5 withdrawal screens and the Close Quarters punch control in landscape: check on screen.
- [ ] At the largest text size, the status chip on unit cards ("Walked …") is cramped next to SZ.
- [ ] Rules tab: at the largest text size, the Classic note fills the first screen. Consider a shorter note.
- [ ] Shot picker: the ">42″" range option sits alone below the segmented control.
- [ ] Open rules: "0*" minimal damage, water.

**Parked (scoped, not built):**
- Clash of Steel: needs Battlefield Support, formations (Lucky rerolls, Combat Intuition, Command Lance initiative reroll), and buildings. Rules are in `docs/game-modes/alpha-strike/clash-of-steel-rules-intake.md`, and the cards are checked in `docs/game-modes/book-scenarios.md`.
- Classic Mission 1: movement and facing tracking, the Classic turn loop, and screens (`docs/game-modes/classic/mission-path-scope.md`).
