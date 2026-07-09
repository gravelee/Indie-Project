---
name: Pre-Production Documentation Roadmap
description: Every design and spec file needed before coding, with phases and order.
type: project
---

# Pre-Production Documentation Roadmap

Everything that needs to exist on paper before a single line of game code is written.
What already exists, what needs to be created, and the order to work through it.

---

## Existing Files (active, maintained)

| File                    | Covers                                                  |
|-------------------------|---------------------------------------------------------|
| `SKILL.md`              | Hub index — points to all active files                  |
| `player_mechanic.md`   | Every player mechanic by category                       |
| `player_input.md`       | Input mapping, console layout, context rules            |
| `systems_design.md`     | Resources, class system, EXP/talent, combat, save, gear |
| `world_design.md`       | Lore, zones, main quest, resonance, races, narrative    |
| `zone1_design.md`       | Zone 1 story — NPCs, weapon chain, quests, choice log   |
| `dungeon_design.md`     | Dungeon rules, AI/traps, puzzles, creature roster       |
| `dungeon_oldmine.md`    | Old Mine + River Cave: rooms, bosses, powder, post-cave |
| `story_book.md`         | Canonical prose narrative (Chapters 1–3)                |

---

## Phase 1 — Complete the Design

Remaining GDD gaps. Pure design decisions — no technical knowledge required.
All three can be worked in the same kind of sessions (narrative/design thinking).

**`creature_design.md`** *(needs: dungeon_design.md creature roster)*
AI state machine per creature type; detection radius and aggression defaults;
state transition conditions; patrol behavior; dungeon vs overworld variants;
`void_touched` behavior effect per type; boss behavior notes.

**`npc_system.md`** *(needs: zone1_design.md choice log + NPC section)*
How NPC daily schedules work (Majora's Mask concept); reactive dialogue concept;
how branch log and affinity profile feed into NPC behavior;
escort companion behavior rules.

**`ui_design.md`** *(needs: player_mechanic.md, systems_design.md)*
HUD layout (resource bars, hotbar, target frame); all screen descriptions
(inventory, talent book, dungeon map, quest log, dialogue box, save/load,
main menu, character select); tab targeting visual; stat panel;
dungeon map annotation UI.

---

## Phase 2 — Feature Specifications

Translate design decisions into structured, implementable specs. Each file
answers: given that the design says X, here is exactly how it works —
data format, flow, edge cases.

**`dialogue_spec.md`** *(needs: npc_system.md, zone1_design.md choice log)*
Dialogue tree data structure; how choices are stored and branch; how branch
log flags gate or modify lines; how affinity profile thresholds unlock optional
lines; NPC reactive condition syntax; data format decision (JSON vs GDScript).

**`quest_spec.md`** *(needs: zone1_design.md quest log, dialogue_spec.md)*
Quest data structure; step trigger conditions; how branch log entries are
written and read; how quest state connects to save data; all Zone 1 quests
fully mapped from design to spec.

**`talent_spec.md`** *(needs: systems_design.md talent section)*
Full talent tree layout for all designed chains; talent data structure; how
scrolls are stored in the talent book; talent activation conditions (chain
prereqs + point cost); talent book UI data flow; all systems_design.md talents
mapped to final spec.

**`map_spec.md`** *(needs: dungeon_design.md, world_design.md zones)*
Zone structure and gate transitions; room system (how rooms connect, door
types); indoor sub-map system; how creature and prop spawns are defined per
room; CSV or JSON room data format; dungeon instance flags.

**`save_spec.md`** *(needs: quest_spec.md, map_spec.md, systems_design.md)*
What data is serialized (player state, quest state, branch log, affinity
profile, dungeon instance state, gear durability, EXP); autosave trigger
sequence in code; manual save point locations; EXP loss and gear penalty
on faint; load flow.

---

## Phase 3 — Technical Architecture

Written last in pre-production — requires all design and spec decisions settled.

**`architecture.md`** *(needs: all Phase 1 + Phase 2 files)*
Every script that will exist and what it owns; signal map between scripts;
how data files (quests, dialogue, maps) are loaded and cached; resource
manager design; code conventions for this project (GDScript standards,
type annotations, error handling policy); implementation build order.

**`asset_spec.md`** *(needs: dungeon_design.md art section, player_mechanic.md)*
Sprite naming conventions; full folder structure for all asset types;
animation naming standards; Godot import settings per asset type;
SpriteFrames loading strategy; asset path formula for all entity types.

---

## Phase 4 — Level Design (Layouts)

Grid-level layouts for every map. Written after map_spec so the format is
defined. Room/zone outlines with spawn positions, trigger zones, prop placements.

**`levels/village.md`** *(needs: zone1_design.md)*
Vinemore full layout; NPC starting positions and daily route zones;
service building locations; quest trigger zones; key prop placements.

**`levels/woods_farming.md`** *(needs: zone1_design.md)*
North farming woods; creature patrol areas; sword spawn location;
barter farming zones; boundary with village.

**`levels/bridge_road.md`** *(needs: zone1_design.md)*
East road from village to bridge; Kadmios position; river bank;
bridge puzzle area; east gate.

**`levels/road_to_mines.md`** *(needs: zone1_design.md, dungeon_oldmine.md)*
Post-bridge road; Verdant Temple location; mine entrance area;
graveyard south of village.

**`levels/mine_rooms.md`** *(needs: dungeon_oldmine.md, map_spec.md)*
Room-by-room layout for mine side (M-01 through M-XX): dimensions,
doors, creature spawns, prop placements, puzzle elements, blocker,
well chamber.

**`levels/river_cave_rooms.md`** *(needs: dungeon_oldmine.md, map_spec.md)*
Room-by-room layout for river cave side (R-01 through R-XX): dimensions,
passages, safe room, Spider Queen lair, wall crack position.

---

## Parallelism Notes (solo dev)

"Parallel" here means: same mental mode, same working session.

| Group              | Files                                    | Mode                                |
|--------------------|------------------------------------------|-------------------------------------|
| Phase 1 together   | creature_design + npc_system + ui_design | Design/narrative                    |
| Data + flow pair   | dialogue_spec + quest_spec               | Structured data + logic             |
| Systems pair       | talent_spec + save_spec                  | Systems + state                     |
| Spatial pair       | map_spec + levels/*                      | Layout + structural                 |
| Solo focus         | architecture.md                          | Full technical synthesis            |
| Any time           | asset_spec                               | Once Phase 1 art direction is clear |

---

## Current Position

End of Phase 0 / entering Phase 1. Story, player, systems, and Zone 1 dungeon
are complete or nearly complete.

**Next**: Pick a Phase 1 file — `creature_design.md`, `npc_system.md`,
or `ui_design.md`.
