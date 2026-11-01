# Guided play — later plans

**Status:** not a spec. `specs/` win. Do not build this for 1.0.  
**Written:** 2026-11-01.  
**1.0 stays:** Ridge Line only. See [product-readiness](../docs/product-readiness.md) and the [readiness plan](../docs/development/production-readiness-plan.md).

## Vision

TableMech becomes the guided-play app for BattleTech. Start small. Each step is a complete way to play at the table, on one shared phone.

The app guides the turn. The player brings the physical cards. [masterunitlist.battletech.com](https://masterunitlist.battletech.com/) is the lookup when a card is ported. Do not bulk-download or ship the catalog.

## Order

Do these in order. Classic does not start in parallel with the army list.

| Step | What “done” means | Rough size |
|------|-------------------|------------|
| 1. Alpha Strike army list | Pick two rosters and play a pickup game with typed cards | 1–2 focused weeks |
| 2. Starter boxes | Those cards can be chosen instead of typed | about a week after the editor exists |
| 3. Classic, basic | One intro-tech ’Mech game, guided through a turn, on a sheet the player filled in | 6–10 focused weeks once it starts |
| 4. Same boxes on Classic sheets | Prefill after the sheet model works | a couple of weeks |

Both basics, army list first, are about three months of focused work. Force packs still in print are a later data pass of a few weeks, not part of step 2.

## Army list

Alpha Strike first. The match engine already runs a two-side fight that is not Ridge Line.

People live on the one device, the way DartBuddy keeps local players.

- A permanent **me** profile (the person who owns the app). It is not deleted.
- Opponents are other profiles on that phone. No accounts.
- Each person can have several rosters (armies).
- At the start of a game, pick yours and theirs, or make a new roster.
- Until a unit is ported, every card field is editable: move, TMM, damage, overheat, armor, structure, skill, abilities.
- After a unit is ported, the player selects it instead of typing it.
- Ridge Line stays a ready-made mission beside this.

Port starter boxes you can buy today, then backfill other units. First boxes: Beginner Box, A Game of Armored Combat, the Alpha Strike box, and Clan Invasion. Look each card up on the Master Unit List. Check the numbers in as data. Do not scrape the site into the app.

## Classic

A second engine. Record sheets, hit locations, weapon-by-weapon fire, and heat. No shared unit type with Alpha Strike. Spec sketch: [ClassicModeSpec](../specs/features/ClassicModeSpec.md). Nothing is built.

“Working” for the first slice is an intro-tech ’Mech only. Piloting rolls, vehicles, infantry, and a full rulebook come after that. Prefill the same starter boxes onto Classic sheets only after a player can already fight on a sheet they typed.
