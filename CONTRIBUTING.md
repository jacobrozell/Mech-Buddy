# Contributing — Mech Buddy

1. Read [AGENTS.md](AGENTS.md) and [docs/product-readiness.md](docs/product-readiness.md).
2. Specs in `specs/` are authoritative.
3. Regenerate Xcode project: `xcodegen generate`
4. Build: `xcodebuild -scheme MechBuddyCI -destination 'platform=iOS Simulator,name=iPhone 17' test`
5. Domain has no SwiftUI. Features never call Analytics directly.
6. Team ID `7JT2JB89AV`. Bundle `com.jacobrozell.mechbuddy`.
