---
name: Dungeon Design Reference
description: General dungeon rules, AI & trap systems, props standards, puzzle design philosophy, creature roster, planned themes, art TODO. Load this when working on any dungeon mechanic, trap, puzzle type, or creature. For Old Mine specific design see dungeon_oldmine.md.
type: reference
---

# Dungeon Design Reference

**See also**: SKILL.md (technical/code standards), dungeon_oldmine.md (Old Mine full design), zone1_design.md (Zone 1 story/NPCs), systems_design.md (talent drops, boss design philosophy)

## TL;DR [NEEDS REVIEW]
- Dungeons: 15-25 rooms. Mid-boss + final boss. Locked doors via key items or puzzle solutions.
- Respawn on re-entry: creatures + boss reset, story events do NOT repeat. Farm-run mode.
- Creature levels scale per repeat run (capped at player level +5).
- Dungeon map: paper & pencil style — hand-sketched CanvasLayer, fills in as player explores. Player can annotate.
- Patrol AI (patrol_ai.gd) and Trap entities (trap_entity.gd) are NEW scripts — separate from creature.gd.
- Patrol types: LINE_PATROL, WALL_FOLLOW, AREA_WANDER, ROOM_CHASE.
- Trap types: spike trap, falling object, cracked tile, dart shooter, hazard tiles (lava/water/ice via tilemap metadata).
- Old Mine traps: LINE_PATROL spike movers + falling stalactites.
- Puzzle types: pressure plates, block push (Z=undo required), switches, sequence, ice slide, enemy-required, environmental trigger, light/mirror (late game only).
- Zone 1 creatures: rat (hostile), snake (hostile), bat (hostile/cave), cave spider (dungeon only), wolf (neutral), bear (neutral), deer (passive).
- Bosses are NOT large versions of common enemies — they are Resonance disturbance made manifest.
- ⚠ Old Mine mid-boss: UNCONFIRMED. "Stone Golem" noted as final boss candidate but needs decision.
- Year 1: Old Mine + Verdant Temple themes only. Do not start themes 3-8.

## Table of Contents
1. [Dungeon System Rules](#dungeon-system)
2. [Planned Dungeon Themes](#dungeon-themes)
3. [Indoor Dungeon AI & Trap Entities](#dungeon-ai)
4. [Props & Environment Standards](#props)
5. [Puzzle Design](#puzzle-design)
6. [Creature Roster & Zone Assignment](#creature-roster)
7. [Art TODO](#art-todo)

---

## 1. Dungeon System Rules {#dungeon-system}

- 15-25 rooms per dungeon. Entrance, mid-boss, final boss rooms.
- Locked doors require key items or puzzle solutions.
- Linear critical path + optional side rooms (talents, loot, lore).
- Each dungeon introduces 1-2 new puzzle or trap mechanics.
- Each dungeon has at least 1 exclusive new creature type.
- Dungeon order: completely free. Difficulty suggested by creature levels, never enforced.

### Dungeon Respawn System
Every dungeon tracks two independent flags:
- `story_cleared` (permanent): set when final boss first defeated. Unlocks overworld story
  progression. Never resets.
- `instance_cleared` (temporary): set after boss kill. Resets when player re-enters dungeon.

On re-entry after `story_cleared`:
- All creatures respawn. Boss respawns. Doors relock. Puzzles reset.
- Story-specific events (rescued NPCs, one-time dialogue) do NOT repeat.
  The dungeon's "mode" shifts — it is now a farm run, not a story run. Atmosphere can
  reflect this slightly (the dungeon feels different without the story tension).
- Creature levels scale: base dungeon level + escalating bonus per repeat run (capped at
  player level + 5 to keep it farmable, not punishing).

Farming incentive loop:
1. Clear dungeon → story essence + some EXP + maybe talent scroll.
2. Spend EXP on stats and talent points. Unlock talents. Get stronger.
3. Return → harder creatures but stronger player. Farm for the scroll not yet dropped.
4. Scroll unlocks a powerful talent → opens new playstyle possibilities.

### Dungeon Map — Paper & Pencil
Player opens a blank paper (key press). As they explore, rooms fill in as simple hand-sketched
outlines only for visited areas. Unvisited rooms stay blank. Implemented as a CanvasLayer overlay
tracking visited tile regions. The drawn style should look hand-sketched (slightly imprecise,
pencil texture). Player can mark rooms with icons (boss, chest, puzzle). This replaces the
traditional map + compass. Unique and fits the lone-explorer identity.

### Environmental Cross-Area Effects (Zelda OoT-style)
Year 1 target: implement ONE clear example — do something in the overworld to change dungeon
state (e.g., activate a mechanism outside to drain a flooded room inside). One well-designed
instance proves the mechanic. Expand later. The connection must be discoverable by observation,
not trial-and-error.

---

## 2. Planned Dungeon Themes {#dungeon-themes}

**Year 1: themes 1-2 only. Do not begin 3-8 until 1-2 are fully polished and playable.**

**1. Old Mine + River Cave** — see `dungeon_oldmine.md` for full design.

**2. Verdant Temple** (intermediate)
- Resonance: Verdant (disrupted, overgrown with wild uncontrolled growth)
- Tileset: overgrown stone, vines, cracked tiles, ancient glyphs
- Creatures: Cultist (humanoid), Temple Guardian (construct), Vine Crawler
- Dungeon AI: wall-following spiked constructs, cracked tiles (break after ~2s standing)
- Puzzles introduced: glyph sequence activation (wrong order = reset)
- Boss 1 (mid): High Cultist — teleports, summons ritual adds
- Boss 2 (final): Awakened Idol — phases, immune to damage types per phase
- Talent scroll drops: "Dark Ritual" from High Cultist, "Phase Echo" from Awakened Idol

**3-8. Future dungeons**: Jungle Ruins (Verdant+Tide), Ice Cave (Frost), Lava Mountain (Ember),
Sea Bottom (Tide), Storm Peak (Tempest), Void Sanctum (Void — final area).

---

## 3. Indoor Dungeon AI & Trap Entities {#dungeon-ai}

Two AI models for dungeon interiors. The existing creature.gd (overworld AI) is the outdoor
model. Dungeon interiors use a lighter separate system.

### Patrol AI (`patrol_ai.gd` — new script)
Simple state machine for dungeon-specific movement patterns. Set via export vars on spawn.
- **LINE_PATROL**: moves back and forth on a fixed axis. On contact: damage + knockback.
  Used for: spike creatures, rolling boulders, moving blade hazards.
- **WALL_FOLLOW**: follows room wall clockwise or counterclockwise.
  Used for: crawling enemies that hug surfaces.
- **AREA_WANDER**: random wander within bounded room. Simpler than overworld wander.
- **ROOM_CHASE**: chases player but cannot leave room bounds.

### Trap Entities (`trap_entity.gd` — new script)
Not creatures — static or semi-static hazards. No HP, no AI state machine. Damage on contact
or triggered by timer/proximity.
- **Spike trap**: rises on timer with visible telegraph (floor discoloration before spike appears).
  1-hit or heavy damage on contact.
- **Falling object**: triggered when player enters a tile column. Falls after 1s telegraph
  (shadow on floor). Used for: stalactites, ceiling boulders.
- **Cracked tile**: implemented as a tilemap tile type + small listener Node2D. If player
  stands on it for > 2 seconds (configurable), it breaks — animation plays, becomes void/hole.
  Used for: fragile floors, rotten wood.
- **Dart shooter**: fires projectile on a fixed timer in a fixed direction.
- **Hazard tiles** (lava, water, ice): handled in tilemap metadata, not as entities.
  Query tile properties in player.gd physics step.

### Per-Dungeon AI Introduction Plan
Introduce 1-2 new dungeon AI types per dungeon:
- Old Mine: spike-line movers (LINE_PATROL), falling stalactites (falling object trap)
- Old Temple: wall-following constructs (WALL_FOLLOW), cracked tiles
- Ice Cave: sliding enemies (LINE_PATROL variant — no friction), ice-slide cracked tiles
- Lava Mountain: geyser trap (spike trap variant with fire), lava hazard tiles
- Sea Bottom: current tiles (push player/boxes), pressure dart shooters

---

## 4. Props & Environment Standards {#props}

### Prop Classification Checklist
Define these before implementing any new prop:
1. **Size** (tiles): 1×1, 2×1, 2×2, 3×2, etc.
2. **Collision**: none / circle / rect. Circle radius = 11px × min(cols, rows).
3. **Type**: destructible → damageable_prop.gd, solid → obstacle_prop.gd,
   decorative → terrain_prop.gd, interactive (chest/door/NPC) → define signal.
4. **States**: idle_alive always required. bump + death if destructible.
5. **Variants**: 3-5 for natural objects, 1-2 for furniture, 1 for mechanical props.
6. **Z-sort**: canvas padding needed only for tall sprites (trees, tall pillars).

### Indoor Props (Not Yet Built — Phase 3 Priority)
Needed for dungeon rooms and town interiors.
Furniture: tables (2×1), chairs (1×1), bookshelves (1×2), crates (1×1), barrels (1×1),
beds (2×1), fireplaces (1×1), candles (decorative), rugs (decorative 2×2).
Tilesets needed: wooden floor, stone floor, stone wall interior, wood panel wall.
Interior rooms: separate map instances, transitions via door prop with scene-change signal.

### Dungeon Theme Prop Needs (Per Theme)
- 1-2 floor tilesets (with dual-grid variants)
- 1-2 wall tilesets (with corner/edge variants)
- 3-5 theme props (obstacles, decorations, hazards)
- 1-2 hazard tile types (tilemap metadata)
- Door prop with locked / unlocked / open states

---

## 5. Puzzle Design {#puzzle-design}

### Philosophy (Link's Awakening style)
Solvable through observation and logic. Solution is visible in the room. No hidden information.
Mechanics are taught simply, then used in increasingly complex combinations later in the same
dungeon.

### Puzzle Types
1. **Pressure plates**: step on → door opens. Multi-plate = must hold all simultaneously.
2. **Block pushing**: move blocks to targets. Must include undo (Z key).
3. **Switch activation**: hit switch → state changes (door, hazard, bridge).
4. **Sequence**: activate in correct order. Wrong order = reset.
5. **Ice sliding**: player/blocks slide until hitting wall.
6. **Enemy-required**: kill all creatures → door opens.
7. **Environmental trigger**: do something outside to change state inside.
8. **Light/mirror**: reflect beams to targets (late-game dungeons only).

### Procedural Puzzle Configurations
For replayability: block puzzle rooms use randomized configurations from a preset solvable set.
Generate 10-20 solvable configurations per puzzle room (verify solvable with BFS offline).
Pick randomly at dungeon instance creation. Store configurations in JSON alongside room data.

---

## 6. Creature Roster & Zone Assignment {#creature-roster}

Creatures are zone-specific — each biome has its own population. Some creatures span adjacent
zones. Neutral creatures are common — they aggro only if attacked first.

**Aggression types**:
- `hostile`: attacks player on sight within detection range.
- `neutral`: ignores player; attacks back if hit. These are animals, not enemies by nature.
- `passive`: never attacks. Environmental/ambient only.

**Zone 1 — Deep Forest (Year 1)**
| Creature | Type | Notes |
|---|---|---|
| Rat | hostile | Small, fast, swarm behavior |
| Snake | hostile | Ambush from tall grass |
| Bat | hostile | Cave subzone; erratic flight path |
| Cave Spider | hostile | Dungeon (Old Mine) specific |
| Wolf | neutral | Attacks if player enters territory or attacks first |
| Bear | neutral | High HP, strong hit, patrols wide area |
| Deer | passive | Ambient wildlife. Flees on approach. |

**Zone 2 — Meadow/Plains (design only, not Year 1)**
TBD — river/lake creatures, plains fauna, first contact with Zone 2 hostile types.

**Dungeon-exclusive creatures**:
- `Cave Spider`: Old Mine only.
- `Stone Golem` (boss): Old Mine final boss — TBD confirmation.
- Mid-boss Old Mine: TBD (replacement needed — confirm with user before finalizing).

**Standing rules**:
- No "giant" prefix creatures in the base roster. Scale through behavior, not size inflation.
- Bosses are distinct creature types from their zone's population — they are the Resonance
  disturbance made manifest, not just a larger version of a common enemy.
- New creature per dungeon is required.

---

## 7. Art TODO {#art-todo}

Parallel track — work these alongside code when possible. Art is the real bottleneck.

### Creature Animation Standard

Every creature needs the following animations, each in front/back variant (flip_h handles left/right):

| Animation | Loop | Notes |
|---|---|---|
| `idle_neutral` | loop | Standing still, no threat awareness |
| `wander` | loop | Casual slow movement. **NOTE: current "move" files must be renamed to "wander"** |
| `run` | loop | Fast movement — combat chase, fleeing, returning home |
| `notice` | once | Alert moment (sees player). Transitions to `neutral_to_attack` |
| `neutral_to_attack` | once | Entering combat stance |
| `idle_attack` | loop | Combat idle — in stance, ready to act |
| `attack_bite` | once | Attack type 1 (all creatures that bite) |
| `attack_slash` | once | Attack type 2 (creatures with claws/tail) |
| `attack_to_neutral` | once | Exiting combat stance (fleeing or player left range) |
| `death` | once → hold | Plays once, holds last frame = corpse sprite |

**Corpse mechanic** (decided): WoW-style. Death animation plays → creature holds last frame
as a lying-down corpse for ~90 seconds → then fades out. Corpse is lootable.
Art must be clean — no blood, no exposed bones. A rat lying on its side is fine for kids.
Stardew Valley, Zelda, and Pokémon all do this in E/E10+ rated games. The mechanic is fine;
the art style is what makes it appropriate. Never add gore.

**Current status per creature**:

| Creature | idle_neutral | wander | run | notice | stances | attacks | death |
|---|---|---|---|---|---|---|---|
| Rat | front ✓ back ✓ | front ✓ back ✓ (named move — rename pending) | — | — | — | — | — |
| Snake | front ✓ back: copy only | — | — | — | — | — | — |

**Immediate art task**: Rename rat `move_front` / `move_back` → `wander_front` / `wander_back`
in LibreSprite, art_source folders, export script, and game asset files.
Then do snake `wander` front/back (snake currently has no move animation drawn).

---

**Player**:
- Better player animations (all states — idle, walk, run, roll, attack types, death)

**New Creatures (future)**:
- Cave Spider, Bat, Wolf, Bear, Deer — full animation set per standard above
- Bosses: Stone Golem (Old Mine) — unique animation set, not standard template

**Effects**:
- Ability and talent activation sprites
- Creature notice popup (! exclamation, plays above creature head on notice)

**Props & Environment**:
- Props: turtle tree, bigger trees, rock variants, cut trunk, root cut, thorns
- Tree/alive-prop idle animations (sway, ambient movement — makes world feel alive)
- Dirt terrain tileset
- Indoor props spritesheet (crates, barrels, furniture)

**UI**:
- Ability icons for hotbar

**Weapons**:
- Weapon sprites (bow for ranged Weaponmaster)
