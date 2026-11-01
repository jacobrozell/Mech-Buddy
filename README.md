# TableMech

BattleTech tableside companion for iPhone and iPad (iOS 26). **0.2.0** on `main` is the Ridge Line tableside UI: design tokens, battle layout, sheets, and rebuilt Play, Force, Rules, and Settings screens. **0.1.0** was the first playable slice (stock lists, auto and manual shot rolls). Classic stays Coming soon.

Plan: [docs/development/ui-overhaul-plan.md](docs/development/ui-overhaul-plan.md). 1.0 readiness: [docs/development/production-readiness-plan.md](docs/development/production-readiness-plan.md). Specs: [specs/](specs/).

## Build

```bash
xcodegen generate
xcodebuild -scheme TableMechCI -destination 'platform=iOS Simulator,name=iPhone 17' test
```

The same unit suite runs on every pull request and on `main` (`.github/workflows/ci.yml`).

Open `TableMech.xcodeproj` in Xcode 26+.

## Layout

| Path | Role |
|------|------|
| `App/` | `@main`, tabs, DI |
| `Domain/` | Match math (no SwiftUI) |
| `Data/` + `Persistence/` | Content JSON loaders; SwiftData SchemaV1+ |
| `Features/` | Play / Force / Rules / Settings / Battle |
| `Resources/Content/` | Bundled Alpha Strike JSON |
| `specs/` | Authoritative product specs |

## Docs

Start at [AGENTS.md](AGENTS.md). Owner decisions: [docs/product-readiness.md](docs/product-readiness.md).

Team `7JT2JB89AV` · Bundle `com.jacobrozell.tablemech` · Version **0.2.0 (1)**

Legal pages live in [`docs/`](docs/) and are linked from Settings. After they are on `main`, publish GitHub Pages from the `/docs` folder so these URLs resolve:

- https://jacobrozell.github.io/TableMech/privacy.html
- https://jacobrozell.github.io/TableMech/support.html
- https://jacobrozell.github.io/TableMech/accessibility.html

Archive for TestFlight (automatic signing, team `7JT2JB89AV`):

```bash
xcodebuild -scheme TableMech -destination 'generic/platform=iOS' \
  -archivePath build/TableMech.xcarchive archive -allowProvisioningUpdates
```
