# Rules Reference Spec

## User story

As a player, I look up turn sequence, modifiers, and abbreviations without digging through the battle UI.

## Screen: `rules.home`

One list, switched by game. A **game switch** sits at the top of the list: a segmented “Alpha Strike | Classic” picker labelled “Rules for”. At accessibility text sizes it becomes two stacked full-width rows (checkmark on the selected one, 44 pt minimum height) so neither label truncates. It works the same in portrait, landscape, and the iPad split view.

### Which game opens

`RulesGameChoice.initial(lastViewed:onboarding:)` (MechBuddyData):

1. The game last picked on the switch (`AppPreferences.rulesGame`, key `rules.lastGame`), else
2. the game picked in onboarding (`AppPreferences.learningTrack`), else
3. Alpha Strike.

Until the player touches the switch, the tab follows the onboarding game (changing game in Settings changes it too). Settings → Delete all data clears the key.

### Content packs

All three use `RulesTopicsDTO`; each topic carries `game`: `alphaStrike`, `classic`, or `both`. Loaded together by `ContentCatalogRepository.rulesLibrary()` → `RulesLibrary.topics(for:)` (the game’s own topics, then the `both` pages). An untagged topic from an older pack counts as Alpha Strike.

| File | Tag | Notes |
|------|-----|-------|
| `Content/AlphaStrike/as-rules-topics.json` | `alphaStrike` | Quick-Start Rulebook (3rd printing) page refs |
| `Content/Classic/classic-rules-topics.json` | `classic` | *A Game of Armored Combat* printed page refs; Quick-Start refs where named |
| `Content/rules-both-games.json` | `both` | “How the two games differ” |

The list shows the disclaimer of the selected game’s pack. Search is scoped to the selected game (prompt “Search Alpha Strike rules” / “Search Classic rules”).

### Alpha Strike topics (`rules.as.*`)

| Topic ID | Title | Group |
|----------|-------|-------|
| `how-to-play` | If you’ve never played a tabletop wargame | Start here |
| `turn` | One turn, four steps (set-up, proportional moves, one Done shooting ends the phase, Clean up = End Phase) | Start here |
| `movement` | How far can it go? (sprint, JMPW/JMPS, heat MV loss, MP hits, woods) | During a game |
| `combat` | Can I even shoot? (no shot at a 0-damage range or with bases touching, one attack, overheat) | During a game |
| `sator` | How the to-hit number is built | During a game |
| `damage` | Hits, wrecks, and criticals (natural 12, attacker rolls, can’t-apply = 1 damage, CASE / CASE II / ENE) | During a game |
| `heat` | Heat and shutdown (End Phase order, shutdown, engine heat, HT) | During a game |
| `physical` | Punches and kicks | During a game |
| `withdrawal` | Forced Withdrawal | During a game |
| `points` | Point Value and Skill (p. 33 table) | Quick reference |
| `tables` | Quick numbers | Quick reference |
| `abbreviations` | Weird letters on the card | Quick reference |
| `odds` | Dice odds | Quick reference |

### Classic topics (`rules.classic.*`)

Reading only: Classic isn’t playable in the app yet. The list shows a note under the switch (`rules.classicNote`), the first topic says so, and so does the pack disclaimer. Paraphrased; never rulebook text.

| Topic ID | Title | Group |
|----------|-------|-------|
| `classic-about` | Classic in Mech Buddy | Start here |
| `classic-turn` | The Classic turn | Start here |
| `classic-movement` | Movement and facing | During a game |
| `classic-to-hit` | The to-hit number | During a game |
| `classic-damage` | Hit locations and damage | During a game |
| `classic-heat` | Heat | During a game |
| `classic-piloting` | Piloting rolls and falling | During a game |
| `classic-criticals` | Critical hits | During a game |
| `classic-physical` | Physical attacks | During a game |
| `classic-quickstart` | What the Quick-Start leaves out | Quick reference |
| `classic-numbers` | Quick numbers | Quick reference |

### Both games (`rules.both.*`)

| Topic ID | Title | Group |
|----------|-------|-------|
| `differences` | How the two games differ (cards vs record sheets, inches vs hexes, one damage number vs per weapon, heat 0–4 vs 30-point scale, criticals and falling, physical attacks, time, what’s playable) | Start here, in both lists |

Lines in a body that start “Alpha Strike:” or “Classic:” get a bold lead-in on the topic page.

## Topic page

A badge at the top says which game the page belongs to (“Alpha Strike rules”, “Classic BattleTech rules”, “Both games”), so a page reached from search still says so.

## Behavior

- Offline only
- Search scoped to the selected game’s topics
- Switching game on iPad keeps the selected topic if it is in both lists (the comparison page), else selects the first topic
- “Open in battle” deep links: from `tables` → can present SATOR only if match active (not built)

## Accessibility

- `rules.home` — the list
- `rules.gamePicker` — the game switch (segmented, or the stacked container at accessibility sizes, label “Rules for”)
- `rules.game.alphaStrike`, `rules.game.classic` — stacked rows at accessibility sizes (segments are found by their titles)
- `rules.classicNote` — “Classic isn’t playable” note, Classic only
- `rules.{as|classic|both}.{topicId}` — topic rows
- `rules.{as|classic|both}.detail.{topicId}` — topic pages
- `rules.topic.game` — the game badge on a topic page
- Dynamic Type through AX5: the switch stacks; rows and bodies wrap

## Tests

`Tests/Unit/RulesLibraryTests.swift`: every topic tagged, packs match their tag, unique ids across packs, both games have topics, the comparison page shows in both, Classic coverage, page citations and “isn’t playable”, Alpha Strike coverage of the rules the app plays, curly apostrophes, and `RulesGameChoice` defaults.

## Verification

| Field | Value |
|-------|-------|
| Target release | 1.1 (game switch, Classic reading topics) |
| Last verified | 2026-11-24 |
| Commit | feature/rules-by-game |
| Code paths | `Features/Play/RulesHomeView.swift`, `Features/Play/RulesTopicDetailView.swift`, `Data/Content/RulesLibrary.swift`, `App/AppPreferences.swift` |
