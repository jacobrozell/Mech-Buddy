# Lore content

General BattleTech background for the app's lore section. Lore only: no game rules.

| File | What it is |
|---|---|
| `battletech-lore.schema.json` | The only schema (JSON Schema 2020-12, v1.1.0). |
| `battletech-lore.json` | The data, checked against that schema. |

The data holds two views of history:

- **`data.eras`, `events`, `factions`, `people`, `places`, `technology_concepts`, `lore_concepts`, `publishing_history`**: a condensed paraphrase of Sarna's *History* page (GFDL 1.2), retrieved 2026-11-26. Ids link these collections together; every link resolves.
- **`data.official_eras`**: Catalyst Game Labs' product eras and sub-eras (Star League, Succession Wars, Clan Invasion…, ilClan, and Clan Homeworlds, which runs at the same time). Use these to label a product or a unit's era.

The two era lists have different boundaries. That is expected, because they come from different sources.

**History:** the owner's AI-drafted files were merged on 2026-11-26. The eras file and its schema were folded into this schema as `official_eras`. One fix: the Exodus was dated 2874 and is now 2784 (noted in the event's `source_notes`). The rest has not been checked against the sourcebooks; treat it as a draft before it ships.
