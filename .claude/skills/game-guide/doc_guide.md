---
name: GDD Documentation Guide
description: >
  Every design file that must exist before coding. Phases, build order,
  content standards per file type, and reference sources.
type: project
---

# GDD Documentation Guide — Echoes of the Void

What needs to exist on paper before a line of game code is written.
Order to work through it, what goes inside each file, where to mine content.

---

## Current Position

Phase 1 in progress. Anchor docs complete.

| File                  | Status      | Notes                               |
|-----------------------|-------------|-------------------------------------|
| `game_overview.md`    | done        | Anchor doc — write all others after |
| `player_mechanic.md`  | done        | New implementation, correct         |
| `player_input.md`     | done        | New implementation, correct         |
| All other P1 files    | not started | See Phase 1 below                   |

**reference/** holds old project files. Mine them for content — do not
treat them as correct for the new implementation. Rewrite, don't copy.

---

## Phase 1 — Design Documents

Pure design. No technical knowledge required. Write in any order within
the group, but follow the dependency notes.

---

### `world_design.md` — Narrative

Mine: `reference/world_design.md`

Required sections (industry standard for a world bible):

1. **World Summary** — name, scale, tone, technology level, magic role
2. **Zone Table** — zone, biome, water, Year 1 status, main problem
3. **Settlements** — types, standard services, how services unlock
4. **Main Quest Arc** — the 10 beats. Fixed. Do not change lightly.
5. **The Consuming Race** — who they are, what they do, why (beats 5-9)
6. **The Dark Figure** — his nature, his limitations, his Zone 1 role
7. **Resonance Framework** — what Resonances are, disruption wells,
   `void_touched` behavior, dungeon respawn lore justification
8. **Resonance Types** — table: type, sustains, when disrupted
9. **Races** — Resonance composition, planned races + stat nudges
10. **Playable Character Rules** — predefined not custom; future char rules;
    ring/no-ring narrative thread overview
11. **Villain Philosophy** — the standing rule for all antagonists
12. **Narrative Philosophy** — the moral design principles; no moralizing
    in NPC dialogue; consequences are natural not punitive

---

### `zone1_story.md` — Narrative

Mine: `reference/zone1_design.md`

Required sections:

1. **Zone Summary** — biome, scale, main problem, story arc shape
2. **TL;DR** — key decisions locked, rules that cannot be changed
3. **Named Characters** — full roster with name, role, personality,
   fragility, and relationship to other characters
4. **World Names** — Vinemore, Roteltree, Aethion (canon names)
5. **Village Context** — state of world at game start; the night before
6. **Opening Sequence** — full walkthrough of Main Quest Step 1
7. **Quest Log** — all quests: trigger, objective, reward, progression path
8. **World Areas** — farming woods, bridge road, mine entrance;
   creatures per area, key props, navigation constraints
9. **Bridge Puzzle** — step-by-step; helper count by weapon path
10. **Weapon Chain** — each weapon: unlock conditions, NPC chain,
    bridge helper eligibility, post-cave gift
11. **Spellcaster School** — entry requirements, tests, commitment warning
12. **Bridge Helper Matrix** — table: helper, available when, notes
13. **Dark Figure** — when/why he appears; what the ring is; Zone 1 exits
14. **Weapon State at Cave Entry** — full matrix of every possible loadout
15. **Player Choice Log** — Branch Log (hard forks B-01 through B-09) +
    Affinity Profile (Void axis, Honesty, Boldness, Curiosity, Empathy,
    Resilience) + design use notes
16. **Cave Companion System** — Mike's arrival by ring state;
    Felan/Mike roles by class path; what Ares finds in each wing
17. **Chapter 3 Post-Cave Beats** — full day: Peter's visit, graveyard
    (ring path), Ms. Kathy fetch (no-ring), twins/Lesen, patients,
    weapon returns, shield unlock

---

### `story_book.md` — Narrative

Mine: `reference/story_book.md` (prose is mostly correct — add front matter
and review for consistency with zone1_story.md locked decisions)

Required sections:

1. **YAML front matter** (missing in old file — add it)
2. **Chapter 1** — Ares's morning, Mark's knock, patient visits, guard
3. **Chapter 2** — weapon chain, bridge, doctor arrival, water conclusion
4. **Chapter 3** — cave journey, dungeon, Chapter 3 post-cave
5. Each chapter: consistent with zone1_story.md branch log and
   companion matrix. Prose is branching — mark variations clearly.

---

### `character_sheet.md` — Characters

Mine: scattered across `reference/world_design.md` (Ares background,
ring/no-ring thread, race design, future char rules)

Required sections (industry standard for a character bible):

1. **Playable Character Format** — template used for all playable chars
2. **Ares**
   - Identity: name, race (Human), origin (Vinemore), age range
   - Physical description (TBD — define here)
   - Personality: what the player inherits; how NPCs describe him
   - Background: what is known about his father, his place in Vinemore
   - Starting stats and loadout
   - Arc: ring path arc vs. no-ring arc across the full game
   - Key relationships: Mark, Ms. Kathy, Mike, Felan/Vinie
3. **Future Character Rules** — the standing rule: NPCs first, then
   playable. What a future character entry requires before being added.
4. **Race Design Framework** — Resonance efficiency model, weapon access
   rules, why non-human chars require more upfront design work

---

### `npc_roster.md` — Characters

Mine: `reference/zone1_design.md` NPCs section (Section 2, full roster)

Required sections:

1. **NPC Design Principles** — schedules (Majora's Mask concept),
   reactive dialogue rules, exceptional hostility rules
2. **Zone 1 Roster** — for each NPC:
   - Name, role, location, daily schedule
   - Personality and dialogue tone
   - Story involvement (what they contribute to which quest)
   - Reactive dialogue triggers (what they say after key story events)
   - Relationship to other NPCs
3. **Naming Convention** — Greek names = thematic weight;
   English names = everyday fabric. The distinction is meaningful.

---

### `enemy_roster.md` — Characters

Mine: `reference/dungeon_design.md` creature roster section

Required sections:

1. **Design Principles** — creatures are not evil; `void_touched` boolean
   overrides natural disposition; aggression = Resonance without balance
2. **AI State Machine** (general template for all creatures):
   - States: Idle, Patrol, Alert, Chase, Attack, Retreat, Dead
   - Transition conditions per state
   - Detection radius (normal vs. void_touched variant)
3. **Zone 1 Creatures** — for each type:
   - Name, zone, spawn locations
   - Stats (HP, damage, move speed, aggression range)
   - Behavior (patrol pattern, attack moves, retreat conditions)
   - void_touched variant (aggression overridden, detection range)
   - Loot table (creature parts, EXP)
4. **Dungeon Creatures** — for each type found in Old Mine / River Cave:
   - Same format as above + dungeon-specific behaviors
5. **Boss Entries** — for each boss:
   - Phase 1, Phase 2, Phase 3 (minimum 3 attack patterns)
   - Visual telegraphing per attack
   - Enrage conditions
   - Drop table (gear rarity, talent scroll chance, class influence)
6. **Future Creature Rules** — how to add new creature entries

---

### `systems_design.md` — Systems

Mine: `reference/systems_design.md`

Required sections:

1. **Resource System** — Energy (AGI), Flow (SPR), Focus (STR);
   how each depletes and regens; design intent per resource
2. **Emergent Class System** — no class selection; how classes emerge
   from stat investment + tools; Weaponmaster + Spellcaster archetypes;
   race + playstyle quest branches
3. **EXP & Talent System** — hybrid leveling (quest stat points +
   EXP-bought points); talent book; talent chains (Tier A/B/C);
   boss ability scroll drops; mobility talent tree; defence talent tree
4. **Combat System** — philosophy (skill over stats); blocking; dodge
   roll; knockback; hit flash; attack cone; resource-based combat;
   boss design principles; status effects
5. **Save System** — faint mechanic (party vs. Ares); recover location +
   cost; BOTW-style autosave triggers; manual save locations; risk layer
6. **Gear & Durability** — equip slots; durability (0-100, WoW-style);
   degrade conditions; repair; rarity tiers (gear only, not scrolls)
7. **Progression System** — EXP flow; stat investment (STR/AGI/STA/INT/
   SPR/RES/DEF); level formula; level cap 30; HP formula; rank system;
   economy (gold sources + gold sinks)
8. **Multiplayer** — post-launch DLC only. Do not build in Year 1.

---

### `ui_design.md` — UI/UX

Mine: none (no reference equivalent — new design)
Depends on: `player_mechanic.md`, `systems_design.md`

Required sections:

1. **Design Principles** — what the HUD should never do; information
   hierarchy; console vs. keyboard UX differences
2. **HUD** — resource bars (Energy, Flow, Focus); HP bar; hotbar
   (abilities + items); target frame; minimap (if any); status icons
3. **Inventory Screen** — equip slots layout; item tooltip format;
   gear comparison; consumable slots
4. **Talent Book Screen** — how scrolls appear; chain visualization;
   EXP cost display; activation confirmation
5. **Quest Log Screen** — active quests; completed quests; objective
   tracking; branch-awareness (what the player sees if a branch closes)
6. **Dialogue Box** — speaker name; dialogue text; choice presentation;
   branch confirmation (for irreversible choices)
7. **Save / Load Screen** — autosave slot display; manual save UI;
   EXP at risk display (show what will be lost on faint)
8. **Main Menu** — new game, continue, settings, character select
9. **Character Select** — Year 1: Ares only; future slot format
10. **Tab Targeting Visual** — lock-on indicator; target health bar;
    how targeting integrates with camera lock state
11. **Dungeon Map** — discovered rooms only; current position; exits

---

### `dungeon_design.md` — Level Design

Mine: `reference/dungeon_design.md` + `reference/dungeon_oldmine.md`

Required sections:

1. **Dungeon Philosophy** — dungeons are Resonance Wells; lore basis;
   why they respawn; design intent (not monster closets)
2. **General Rules** — room progression; safe rooms; darkness/lighting;
   save points (entrance only, before boss); key item design
3. **Room Design Standards** — room types (combat, puzzle, safe,
   treasure, boss); prop standards; enemy encounter rules
4. **AI Behavior in Dungeons** — patrol paths; aggro radius; leash
   range; group aggro conditions; creature communication rules
5. **Trap System** — trap types; visual telegraphing; damage types;
   reset conditions; puzzle-trap combinations
6. **Puzzle Design** — Zone 1 puzzle types; push/pull block rules;
   switch timing; environmental hazard puzzles; light puzzles
7. **Boss Design Rules** — 3+ phases; telegraph standard; enrage rule;
   drop table structure; boss-to-scroll relationship
8. **Zone 1 Dungeon — Old Mine + River Cave**
   - Overview: two entrances, two wings, internal junction
   - Mine wing: rooms M-01+, water source, disruption well room
   - River Cave wing: rooms R-01+, safe room, Spider Queen lair,
     wall crack (blastable, post-cave content)
   - Evidence of the fight (twins + dark figure vs. consuming race)
   - What Ares can find: abandoned camp, foreign markings, one dead
9. **Art TODO** — placeholder for art direction notes per dungeon type

---

## Phase 2 — Data Specifications

Translate design decisions into implementable data formats. Each file
answers: given that the design says X, here is exactly how it works —
data structure, flow, edge cases.

Depends on: all Phase 1 files stable.

| File               | Depends on                          | Covers                            |
|--------------------|-------------------------------------|-----------------------------------|
| `dialogue_spec.md` | zone1_story.md, npc_roster.md       | Tree structure, branch log format |
| `quest_spec.md`    | zone1_story.md, dialogue_spec.md    | Quest data, triggers, save link   |
| `talent_spec.md`   | systems_design.md                   | Talent tree layout, data format   |
| `map_spec.md`      | dungeon_design.md, world_design.md  | Zone/room structure, spawn format |
| `save_spec.md`     | quest_spec.md, map_spec.md, systems | Serialized state, autosave flow   |

---

## Phase 3 — Technical Architecture

Written last in pre-production. Requires all design + spec decisions stable.

| File              | Depends on         | Covers                                      |
|-------------------|--------------------|---------------------------------------------|
| `architecture.md` | all P1 + P2 files  | Scripts, signals, data load, code standards |
| `asset_spec.md`   | dungeon_design.md  | Naming, folders, Godot import settings      |

---

## Phase 4 — Level Layouts

Grid-level layouts per zone. Written after map_spec.md defines the format.

| File                    | Depends on                  | Covers                         |
|-------------------------|-----------------------------|--------------------------------|
| `levels/zone1/vinemore.md`   | zone1_story.md         | Village grid, NPC positions    |
| `levels/zone1/woods.md`      | zone1_story.md         | Farming + bridge road areas    |
| `levels/zone1/mine_cave.md`  | dungeon_design.md,     | Room-by-room layouts for both  |
|                              | map_spec.md            | mine wings                     |

---

## Phase 1 Build Order

Work within Phase 1 in this order (dependencies flow top to bottom):

```
game_overview.md          anchor — DONE
      |
world_design.md           world context needed by all narrative files
      |
      +--- zone1_story.md          needs world context
      +--- character_sheet.md      needs world context for Ares's arc
      |
systems_design.md         independent — can run parallel with narrative
      |
      +--- enemy_roster.md         needs systems for AI + combat stats
      +--- npc_roster.md           needs zone1_story.md NPCs section
      +--- dungeon_design.md       needs systems + enemy_roster.md
      |
      +--- ui_design.md            needs player_mechanic + systems
      |
story_book.md             last — prose reflects all locked decisions
```

---

## Reference Sources

| reference/ file          | Mine it for                                      |
|--------------------------|--------------------------------------------------|
| `world_design.md`        | world_design.md, character_sheet.md, narrative  |
| `zone1_design.md`        | zone1_story.md, npc_roster.md, story_book.md    |
| `story_book.md`          | story_book.md (prose — review for consistency)  |
| `systems_design.md`      | systems_design.md (full rewrite to standard)    |
| `dungeon_design.md`      | dungeon_design.md, enemy_roster.md              |
| `dungeon_oldmine.md`     | dungeon_design.md Zone 1 section, mine_cave.md  |
| `roadmap.md`             | historical context only — superseded by doc_guide |
