# Mech Buddy — release todo

For all future work in one place, see [../ROADMAP.md](../ROADMAP.md).

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
- [ ] Play Ridge Line through Full Lances at the table on TestFlight 1.0.0 (3) (archived 2026-11-24). Note issues in `ongoing/play-<date>/NOTES.md`.
- [ ] Rear weapons in the shot picker: check on screen in portrait, landscape and the largest text size (Missions 4–5 BattleMaster). Not checked yet.
- [x] Victory screen: seen on screen (portrait) via the Ridge Line UI test, 2026-11-25. A draw also shows "Mission 1 cleared"; decide whether a draw should clear a mission.
- [ ] Mission 5 withdrawal screens and the Close Quarters punch control in landscape: check on screen.
- [x] At the largest text size, the status chip on unit cards ("Walked …") is cramped next to SZ. Fixed: the chip moves to its own line under the name. Not checked on screen.
- [x] Rules tab: at the largest text size, the Classic note fills the first screen. Now "Rules only. Classic isn’t playable yet."
- [x] Shot picker: the ">42″" range option sits alone below the segmented control. Fixed: it is the fourth range option, and the picker becomes a menu at accessibility sizes. Not checked on screen.
- [ ] Open rules: "0*" minimal damage, water. No shipped card uses 0* (rules audit 2026-11-24); build it with Clash of Steel, the first content that needs it.

**UI pass (2026-11-25, `polish/ui-pass`), checked on the iPhone 17 simulator:**
- [x] Mission path: the line from an off-centre stop (Close Quarters) now leaves from under that stop, not mid-screen.
- [x] Victory "Mission cleared" card counts only the section the mission is in ("1 of 5", not "1 of 6" with Meet and Greet).
- [x] MV prints ″ (`10″/6″j`), not straight quotes. PV balance reads "Side B has 3 more PV."
- [x] Settings: "Your game" row no longer tinted gold.
- [x] Mission sheet: forces listed with commas (no line starting "·"). Map diagram labels (map names, Hill, 6″) sit on pills so the seam no longer runs through them.
- [x] Who's who: names wrap instead of truncating ("Thunderbolt TD…"); pip counts stay on the first row when the pips wrap.
- [x] Place the miniatures: shows the mission's own map layout, and no "Side B is up" (both sides place in turns).
- [x] Shot picker: opens scrolled to the targets once a shooter is chosen; no "Moved: Walked" line repeating the chip; Woods / Partial cover / Rear shot are real chips (filled with a check when on); no duplicate >42″ note.
- [x] "Let the app roll" has a dice icon so it reads as a control.
- [x] Largest text size: dock buttons shrink instead of truncating ("Done shooti…"), the step label wraps, and "·" never starts a line.
- [x] Largest text size: the battle header took about a third of the screen. Now "Turn 1 / 8" on one line with the step under it, capped at AX2 (`polish/open-items`).
- [x] Dark mode, landscape and onboarding checked on screen (2026-11-25, `polish/open-items`):
  - Gold buttons (Solve a shot, Continue, Roll, onboarding Continue, on-chips) use the dark `onSignal` label; white on gold was about 2.9:1 light and 1.8:1 dark. Side-coloured buttons go dark-on-colour in dark mode.
  - Shot picker uses two columns in landscape (and on iPad), one at accessibility sizes.
  - Onboarding: Change game opens with the current game selected; feature-row icons share one width so the text lines up; dice copy says "tap", not "type".
  - Settings at the largest text: icons stay in their tiles, and Version stacks instead of breaking as "Ver-sion".

**Parked (scoped, not built):**
- Clash of Steel: needs Battlefield Support, formations (Lucky rerolls, Combat Intuition, Command Lance initiative reroll), and buildings. Rules are in `docs/game-modes/alpha-strike/clash-of-steel-rules-intake.md`, and the cards are checked in `docs/game-modes/book-scenarios.md`.
- Classic Mission 1: movement and facing tracking, the Classic turn loop, and screens (`docs/game-modes/classic/mission-path-scope.md`).
