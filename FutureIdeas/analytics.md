# Analytics — later

**Status:** not started. Do not add Firebase, GA4, or a workflow secret until this work begins.  
**Written:** 2026-11-02.

First TestFlight ships with telemetry off. Privacy copy says this version has no analytics.

When this starts, follow Puzzle Buddy, Dart Buddy, and RPM Buddy: allowlisted events through Firebase Analytics to GA4. The Xcode Cloud workflow gets `GOOGLE_SERVICE_INFO_PLIST_BASE64` for that workflow only. Update `docs/privacy.html` in the same change.

Event rules already live in [TelemetrySpec](../specs/TelemetrySpec.md). Placeholder funnel: `app_open` → `mode_selected` → `mission_started` → `battle_phase_advanced` → `attack_resolved` → `match_completed`.
