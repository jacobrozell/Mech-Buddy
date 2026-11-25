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
