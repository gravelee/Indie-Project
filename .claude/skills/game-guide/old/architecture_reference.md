---
name: Old Project Architecture Reference
description: Snapshot of the original Godot 4.3 prototype (~6k lines). What was built, how it worked, what patterns to keep, and what to change in the rewrite. Load this when making technical architecture decisions for the new project.
type: reference
---

# Original Project Architecture Reference

## TL;DR [NEEDS REVIEW]
- Old project: ~6k lines, 14 scripts, one flat level. No NPCs, quests, or save system. Keep for reference — never modify.
- **Keep verbatim**: z-sort formula, prop hierarchy (WorldProp→Damageable→Obstacle/Terrain), 3-layer pathfinding, static asset loader cache, stats formula pattern, ability resolution order (resist→dodge→block→damage→crit→effect).
- **Rewrite**: game.gd (too large — split into camera/z-sort/scene builder), creature wander (simplify), map spawning (switch → data-driven), effect management (move out of stats.gd), UI (polling → signal-driven).
- **Rewrite start order**: game.gd → stats.gd (with renames) → player.gd → creature.gd → props → pathfinder → UI → new systems (room system, NPC, dialogue, quest, inventory).
- Resource renames apply from day one of rewrite: `rage → focus`, `mp/mana → flow`.

This is a frozen snapshot of the prototype built before the full design guide existed.
~6,000 lines of GDScript across 14 scripts. One playable level. No NPCs, no quests, no save system.
The rewrite starts fresh using this as a reference — not a base to build on.

**Keep the old project folder intact. Never delete it. It is the reference.**

---

## What Was Built

A working top-down action prototype with:
- Rotatable camera (360° RMB drag), WASD camera-relative movement
- Z-sort depth rendering for sprites and props
- Player: movement, attack cone, basic abilities, resource system
- Creatures: FSM AI (notice → chase → attack → return home), A* pathfinding
- Props: destructible bushes and grass, static trees, collision-aware
- HUD: HP/energy/rage/MP bars, floating damage text, creature stat panel, debug overlay
- Stats system: 8 base stats → 12 derived stats, status effects (DoT, flags, modifiers)
- Ability system: cooldown, resource cost, dodge/block/crit resolution
- Asset loader: SpriteFrames cache shared across instances

---

## Directory Structure

```
godot_project/
├── assets/
│   ├── _player_stats.json
│   ├── maps/level_01/
│   │   ├── _creature_stats.json    (8 creature instances)
│   │   ├── _entities.csv           (spawn layout grid)
│   │   ├── _dark_dirt.csv / _dark_grass.csv / _rock_path.csv / _flora.csv
│   ├── tilemaps/terrain/ + sub_terrain/
│   ├── spritesheets/player/ (44 PNGs), creatures/rat+snake (9 each), props/, weapons/
│   └── sprites/                    (prop variants + height extensions)
├── scripts/
│   ├── game.gd                     (scene root, camera, z-sort, sprite updates)
│   ├── map.gd                      (level loader, entity spawner, attack resolution)
│   ├── pathfinder.gd               (AStarGrid2D wrapper)
│   ├── asset_loader.gd             (SpriteFrames static cache)
│   ├── entities/
│   │   ├── player.gd               (input, FSM, movement, attack signal)
│   │   ├── creature.gd             (AI FSM, pathfinding client, wander, combat)
│   │   ├── stats.gd                (stat formulas, resources, effect application)
│   │   ├── ability.gd              (ability instance: use, cooldown, resolution)
│   │   ├── abilities.gd            (all ability definitions as a dictionary)
│   │   ├── status_effect.gd        (DoT / flag / modifier objects)
│   │   └── statuses.gd             (status definitions lookup)
│   ├── props/
│   │   ├── world_prop.gd           (base: visual only, no collision)
│   │   ├── damageable_prop.gd      (adds Area2D + health)
│   │   ├── obstacle_prop.gd        (collision + bump animation)
│   │   └── terrain_prop.gd         (no collision + pass animation + idle_dead state)
│   └── ui/
│       ├── hud.gd
│       ├── combat_feedback.gd      (floating damage text)
│       ├── stat_panel.gd           (creature/player panel, L-click or P key)
│       └── debug_overlay.gd        (world-space debug drawing)
└── game.tscn                       (single scene, game.gd attached)
```

---

## Key Patterns — What to Keep

### Z-Sort Formula
```gdscript
z_index = (pos.x * sin_a + pos.y * cos_a) / Z_DEPTH_SCALE
```
Add `z_depth_offset` per entity for sprite height (scanned from idle_neutral first frame using `Image.get_used_rect()`). This formula is correct for 360° rotatable top-down. Do not change without a proven reason.

**Camera rotation:** world_angle var → `camera.rotation_degrees = -world_angle`. Trig cached as `cached_sin_a`, `cached_cos_a`, recomputed only when `_angle_dirty = true`.

### Prop Hierarchy
```
WorldProp (base — visual only)
└── DamageableProp (adds Area2D + health)
    ├── ObstacleProp (collision + bump anim)
    └── TerrainProp (no collision + pass anim + idle_dead state)
```
Very flexible. `cols/rows` (tile footprint), `variant_count`, `height_ext`, `sprite_type/sprite_name` all drive asset loading cleanly. Keep this hierarchy in the rewrite.

**Asset path formula:**
```
"res://assets/sprites/{sprite_type}/{sprite_name}/{state}/{variant}/{cols}x{rows}{_h_suffix}.png"
```

### Pathfinder — Three-Layer Blocking
1. **Permanent** (`set_tile_solid`): props with collision. Ref-counted so multi-tile props block correctly. Tiles dilated 3×3 for creature radius.
2. **Dynamic** (`set_dynamic_blockers`): creature center tiles. Updated every 0.15s. Added/removed per search — not permanent.
3. **Temporary** (`add_temp_block`): creature collision event tiles. Timer resets on re-collision. Max 10 stacks, duration capped at 32s.

Keep this pattern. The three-layer approach handles crowded corridors cleanly.

### Asset Loader — Static Cache
```gdscript
static var _frames : Dictionary = {}  # path → SpriteFrames
```
One SpriteFrames object per unique animation, shared across all instances of the same type. Critical for performance. Keep this pattern exactly.

### Stats System — Derived Formula Pattern
8 base stats (STR, AGI, STA, INT, SPR, RES, DEF, BMS) → 12 derived stats via formulas in stats.gd. No derived stat is ever stored in a data file — only bases. All stat math lives in one place.

**Current resource names (to rename in rewrite):**
- `rage` → `focus`
- `mp` / `mana` → `flow`

### Status Effects — Three Types
- **DoT**: ticks every `tick_rate` seconds, stackable to `max_stacks`
- **Flag** (stun/silence/freeze): boolean set; longest duration wins
- **Modifier** (slow/weaken): strongest multiplier wins

This type system is sound. Keep it. Consider moving effect management out of stats.gd into its own effect_manager.gd in the rewrite.

### Ability Resolution Order
1. Resource check (cooldown, cost)
2. Magic resist roll (magic only)
3. Dodge roll
4. Block roll (physical only)
5. Damage = base × mult − defense (min 1-2)
6. Crit roll → ×2 + focus gain
7. Status effect roll

This order is correct for the game's feel. Keep it.

### Performance Patterns
- **Dirty-check all UI:** HUD and combat feedback only redraw on value change
- **Throttled timers:** pathfinding updates (0.4-0.6s), dynamic blockers (0.15s), stuck detection (0.2s)
- **Lazy trig:** recompute sin/cos only on camera move
- **Broad-to-narrow attack:** scan 7×7 tile grid → cone check → damage

---

## What to Change in the Rewrite

### game.gd Does Too Much
Scene building, camera, z-sort, and per-frame sprite updates are all in one file. Split:
- `camera_controller.gd` — rotation, trig cache, WASD relative input
- `z_sort_manager.gd` — entity z-sort, depth formula
- `scene_builder.gd` or handle via map.gd — scene tree construction

### Creature AI — Simplify Wander
The wander system (random direction + duration + bump detection) works but is verbose. Consider a simple weighted random direction + timer without the bump avoidance complexity — the A* pathfinder handles avoidance already.

### Map Spawning — Data-Driven
`_load_entities()` in map.gd uses a large switch/match on tile IDs. Replace with a data-driven approach: entity type registry (JSON or GDScript dict) maps tile ID → spawn config. Less hardcoding, easier to extend for dungeon rooms.

### Effect Management — Separate from Stats
`stats.gd` currently owns all effect application and stacking logic. This couples stat formulas with effect behavior. Move to `effect_manager.gd` that stats.gd delegates to.

### Asset Paths — Enum-Based Registry
String concatenation for asset paths is fragile (typos fail silently at runtime). Consider an `asset_registry.gd` with typed enums for prop types, creature types, animation states. asset_loader.gd uses the registry to build paths.

### Signal-Driven UI
HUD and stat_panel currently poll every frame for changes. Rewrite: entity states emit signals (`hp_changed`, `state_changed`, `effect_applied`) → UI subscribes. Cleaner and more performant.

### Single Level → Room System
Current architecture: one flat 100×100 map, all entities spawned at load. Rewrite needs:
- Room-based dungeon maps (see dungeon_design.md for room system spec)
- Door transitions (scene change or dynamic load)
- Indoor sub-maps alongside overworld map
This is the biggest structural difference from the prototype.

---

## Data Formats (Keep These)

### Player Stats JSON
```json
{ "player": [{ "str": 1, "agi": 1, "sta": 180, ... "exp": 0 }] }
```

### Creature Stats JSON (per map)
```json
{ "type": "rat", "str": ..., "agi": ..., "home": true, ... }
```

### Entity Spawn CSV
Row-major grid. IDs:
- `1`: Player spawn
- `2-3`: Creature types
- `101+`: Prop IDs (101=bush, 125=tree h0, etc.)
- `-1`: Empty

### Tilemap CSVs
Tile index into tileset PNG atlas. One CSV per layer (`_dark_dirt.csv`, `_dark_grass.csv`, etc.).

Keep these formats. They are clean and tool-friendly.

---

## What Was Not Implemented (Rewrite Must Add)
- Dialogue system / NPC interaction
- Quest system (main quest + side quests)
- Inventory and equipment UI
- Multiple maps / dungeon room system
- Save / load game state
- Sound and music
- Dungeon-specific AI (patrol, trap entities)
- Talent book system
- Shop / barter economy
- Fainting mechanic for companions

---

## Rewrite Starting Point Recommendation

1. Scaffold: game.gd (camera + z-sort) + map.gd (room system stub) + asset_loader.gd (keep as-is)
2. Port: stats.gd, ability.gd, abilities.gd (rename rage→focus, mp→flow)
3. Port and split: status_effect.gd + new effect_manager.gd
4. Rewrite: player.gd (same FSM structure, cleaner camera input split)
5. Rewrite: creature.gd (same FSM, simpler wander, signal-driven state changes)
6. Port hierarchy: world_prop.gd → damageable_prop.gd → obstacle/terrain (keep as-is)
7. Rewrite: pathfinder.gd (same three-layer logic, cleaner API)
8. Rewrite: all UI (signal-driven instead of polled)
9. New: room_system.gd, npc.gd, dialogue.gd, quest.gd, inventory.gd

Do not attempt to add new systems to the old project. Start fresh.
