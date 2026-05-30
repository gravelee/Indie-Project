---
description: >
  Game production guide for this project — a WoW × Zelda offline action-adventure RPG in Godot 4.3.
  Load this whenever the user asks about: new features, game design decisions, technical
  implementation, sprite/asset conventions, dungeon design, talent system, emergent classes,
  resources (Energy/Flow/Focus), race design, Resonance lore, puzzle design, props, combat,
  progression, save system, durability, indoor AI, or how to approach any part of development.
  This is the primary reference for all design and code decisions. Always check this before
  suggesting anything architectural or design-related. Never make design decisions unilaterally —
  present options and ask the developer first.
---

# Game Production Guide

Single-player action-adventure RPG in Godot 4.3. The game combines WoW-style stat depth, resource
management, talent systems, and dungeon structure with Zelda-style real-time action combat, active
blocking, Link's Awakening-style puzzle design, and free dungeon exploration order. Replayability
is a core design pillar — different races, emergent playstyles, branching quests, free dungeon
order, and talent farming all drive repeat playthroughs.

## TL;DR
- Tile: 32×32px. Entity sprites: 96×96px (AnimatedSprite3D, BILLBOARD_FIXED_Y). Maps: 100×100 tiles.
- Renderer: GL Compatibility. Resolution: 1920×1080 fullscreen.
- Camera: 3D world, 360° rotation via RMB drag. WASD always camera-relative.
- Z-sort: handled by Godot 3D engine — no custom formula needed.
- Programmatic scene building — no TSCN hierarchy. Everything built in code.
- All stat math lives in stats.gd only. No hardcoded values in entity scripts.
- Resource rename pending in code: `rage → focus`, `mp/mana → flow`.
- Blocking costs NO energy while held. Active shield abilities (e.g. Shield Bash) do cost energy.
- Year 1 scope: Zone 1 + Zone 2 fully playable. Everything else: design only.
- Project: `/Users/Grproth/Desktop/Tech Prototype/` is the active 3D game project.
  Old 2D project preserved intact for reference only — never touch it.

---

## 0. Current Development Phase & Daily Workflow

**Read this first at the start of every session.**

### Development Rhythm (do not deviate from this order)
```
Global story outline        → COMPLETE (10 main quest beats locked)
Zone 1 story design         → COMPLETE (NPCs, quests, bridge puzzle, opening sequence)
Zone 1 implementation       → CURRENT GOAL
    └─ Phase 1: Core Feel   → in progress (see Section 18 priority list)
    └─ Phase 2: Playability → next
    └─ Phase 3: Dungeon     → after Phase 2
    └─ Phase 4: Progression → after Phase 3
    └─ Phase 5: World/NPC   → after Phase 4
Zone 1 scope evaluation     → after Zone 1 implementation complete
Zone 2 story design         → after Zone 1 evaluation
Zone 2 implementation       → after Zone 2 story
... repeat per zone
```

### Current Status *(update this whenever a milestone is hit)*
- **Last completed**: Phase 1 Core Feel (code-side). player.gd, stats.gd, asset_loader.gd,
  creature.gd all built and running. Combat confirmed working: hit flash (red tint, GL Compat
  safe), knockback, DEAD fade, player Space attack (arc + distance). Creature directional
  animations confirmed working. Export pipeline built (`tools/export_sprite.py`, rotsprite/
  Scale3x). Rat idle_neutral + move front/back exported and in-game.
- **Active work**: Deciding next step — see options below.
- **Next session target**: TBD.
- **Blocked on**: Nothing.

### What the test map currently has (all hardcoded in main.gd `_ready()`)
- Ground: 25×25 checkerboard PlaneMesh tiles + WorldBoundaryShape3D collision
- Trees (Sprite3D + fade), water tiles, ledge, ramp, cliff, mountain (box obstacles)
- Player at (12, 0, 20). 2 rats + 1 snake hand-placed.
- No CSV loading. No tilemap system. All world content hardcoded.

### Pending (no priority order yet)
- ~~**Rename move → wander**~~ ✓ DONE — art_source folders, export script, game assets, creature.gd all updated.
- **LibreSprite .ase project files** (deferred): Currently working with individual frame pngs only.
  Future improvement: save one `.ase` file per animation alongside the frames folder
  (e.g. `wander_front.ase` next to `wander/front/`). Lets you reopen work with layers,
  palette, and history intact. Not required for export pipeline — adopt whenever ready.
- Rat/snake combat animations — notice, stances, attacks, death. See dungeon_design.md Art TODO
  for full animation standard and current status table.
- Prop calibration — props don't fit 3D world well, need per-prop height/offset tuning
- CSV map loading — entities and props spawned from CSV, not hardcoded in main.gd `_ready()`
- Terrain autogenerator port — old system in `tiled/scripts/map auto gen` (old 2D project).
  Uses CA noise → dual-grid 18-tile tileset → smoothing pass. Not started for 3D.
  Ground mesh already exists (25×25 checkerboard); full tileset approach for 3D TBD.
- Tree/prop idle animations — alive props should animate (sway, ambient movement)

### Key Decisions Locked Since Last Code Session (apply to rewrite from day one)
- Blocking costs NO energy while held — only active shield abilities (e.g. Shield Bash) cost energy
- Hybrid leveling: quests give 1 guaranteed stat point; EXP buys additional stat or talent points
- Faint mechanic: party members faint at 0 HP (no permanent death). Game over only if Ares is
  down with no conscious companion available to help.
- Blasting powder: permanent walls, lit with lantern directly. Weapon master needs powder pouch
  (Lulu post-cave). Spellcaster gets magic blast equivalent later — cannot carry powder pouch.
- Ring/no-ring is a full-game narrative thread — not just Zone 1.

### How Claude Should Approach Each Session
1. Read this section first — understand where we are.
2. Never suggest work outside the current phase unless asked.
3. Story questions → reference zone1_design.md + story_book.md.
4. World/lore questions → reference world_design.md.
5. System questions (resources, talents, combat, save) → reference systems_design.md.
6. Dungeon questions (rooms, bosses, puzzles, creatures) → reference dungeon_design.md.
7. Code questions → reference Sections 2-3 below (technical standards + architecture).
8. New ideas → evaluate against current phase priority. Flag scope creep immediately.
9. After any code change → update SKILL.md if design decisions were made.
10. After any story decision → update the relevant design file + story_book.md.

### Companion Files
- `SKILL.md` (this file) — technical reference: code standards, architecture rules, weapon system,
  known issues, scope management. Hub for all companion file references.
- `zone1_design.md` — Zone 1 full story design: NPCs, opening sequence, weapon chain, quest log,
  spellcaster school, bridge puzzle, pre-cave journey, cave companion system, choice log.
- `world_design.md` — World structure, zones, towns, main quest arc, consuming race, dark figure,
  Resonance framework, resonance types, races, villain design, technology level, narrative philosophy.
- `systems_design.md` — Game systems: resources (Energy/Flow/Focus), emergent class system,
  EXP & talent system, combat mechanics, save system, gear & durability, progression.
- `dungeon_design.md` — Dungeon system rules, Ancient Mine full design, dungeon AI & traps,
  props & environment standards, puzzle design, creature roster, art TODO.
- `story_book.md` — Canonical prose narrative of the game (for printing as a book).
  Chapter 1 complete: game start through bridge crossing.
  Chapter 2 complete: road to mines through waking in Vinemore.

---

The developer is a solo dev and lifelong gamer with deep knowledge of WoW, Zelda series, Naruto,
Genetic Disaster, BOTW, Majora's Mask, DnD. Always give practical, scoped advice. Be honest about scope. Flag feature creep immediately. Never decide anything alone — present options and discuss.

---

## 1. Game Identity & Core Feel

**The pitch**: A top-down action RPG with real-time Zelda-feel combat (active shield, dodge roll,
directional attacks) built on WoW-depth systems (stats, resources, talent chains, gear, dungeons).
No class is chosen — your playstyle and stat investment define what you become. Every dungeon run
has value beyond the story because you're always farming toward the next talent unlock.

**Story**: Linear ending for all players, but branching quest choices affect what happens along
the way. Dungeon order is completely free except the first one. Some quests trigger based on your
race, others based on your emergent playstyle. The main quest is a guiding thread, not a forced path.

**Character selection**: Predefined named characters — not a custom character creator. No sliders,
no hair colors, no body shape tools. Each selectable character is a person with a name, a life,
and a starting situation. The player inherits an identity rather than building one from parts.
Year 1 ships with one character: Ares (human male, Vinemore). The selection screen is built from
the start to accommodate future additions. Next likeliest addition: a human female character
(different name, different starting situation, less production work than a new race). New races
require new stat distributions, resonance efficiency modifiers, and weapon access rules — designed
when the races themselves are well-defined. Each character plays through the same core game with
the same mechanics; their race and starting life shape what they bring to it, not how the systems work.

**Camera**: Top-down, full 360° rotation via RMB drag. WASD is always camera-relative.
3D world — Z-sorting handled by Godot engine. Camera system complete (see Section 2).

**Visual style**: 2D sprites in a 3D-positioned world. Pixel art. Top-down perspective.
Sprites use fixed directional animations — they do not rotate to face camera.

**Key design references**:
- *Link's Awakening*: tight puzzle design, small dense dungeons, memorable bosses
- *A Link to the Past*: item-gated exploration, satisfying overworld, dungeon variety
- *Majora's Mask*: dungeon respawn loop — everything resets but acquisitions persist
- *Genetic Disaster*: boss talent drops, skill-dependent difficulty, farming loop
- *WoW vanilla/TBC*: stat depth, talent chains, class identity, dungeon structure, durability
- *BOTW*: free dungeon order, autosave at milestones (NOT the open-emptiness feel)
- *Naruto Shippuden*: villain depth — antagonists with worldviews built from real experience
- *Four Swords Adventures*: multi-player puzzle design (future DLC only)

---

## 2. Technical Standards

These conventions are established in the codebase. Never suggest changing them without a specific
proven reason.

### Engine & Project
- **Godot version**: 4.3
- **Project name**: Echoes of the Void
- **Project path**: `/Users/Grproth/Desktop/Indie Project/echoes_of_the_void/`
- **Renderer**: GL Compatibility (keep — broadest hardware support for indie)
- **Resolution**: 1920×1080 fullscreen

### Tile & Sprite Sizes
- **Tile size**: 32×32 pixels. 1 tile = 1.0 world unit (`TILE_SIZE = 1.0`).
- **Entity sprites**: 96×96 pixels (3×3 tiles). Fixed size — do NOT content-fit sprites.
  Transparent bottom rows handled by `z_depth_offset` scan (first frame of idle_neutral).
- **Spritesheets**: Horizontal strips (frames left to right). 8 FPS animation speed.
- **Props**: Size in tile units (1×1, 2×2, etc). Horizontal strip spritesheets.
- **Map grid**: 100×100 tiles per level zone. Dungeon rooms can be smaller sub-maps.

### 3D World + 2D Sprite Setup
- **Entity node type**: `CharacterBody3D` (physics) with `AnimatedSprite3D` child (visual).
- **Billboard mode**: `BILLBOARD_FIXED_Y` — sprite always faces camera on Y axis only.
  Never use `BILLBOARD_ENABLED` (full billboard breaks top-down look).
- **pixel_size**: `1.0 / 32.0` — converts pixel coordinates to world units.
  At 96px sprite, world height = `96 * pixel_size = 3.0`.
- **Z-sort**: Handled by Godot 3D engine via world Y position. No custom formula.
  `z_depth_offset` adjusts sprite anchor based on transparent bottom rows of the sprite.
- **Directional animations**: Sprites do NOT rotate with camera. 8-direction animation set
  (or 4 where budget is tight). Direction computed from velocity relative to camera angle.

### Coordinate Systems
- World: Godot 3D (x right, y up, z toward camera). Ground plane is XZ.
- Sprites positioned in XZ; height on Y axis.
- Camera faces down from above at a pitch angle (-30° default), orbits on Y axis.
- No Tiled editor integration yet — map geometry built in code for now.

### File Organization (3D project — current state)
```
Tech Prototype/
  scripts/
    camera_settings.gd   ← CameraSettings Resource (user prefs, saved to disk)
    camera_rig.gd        ← Camera pivot + collision + player fade
    game_ui.gd           ← Pause menu + settings page (two-window, no pause)
    main.gd              ← Glue: world building, player, wires systems together
    (future)
    player.gd            ← CharacterBody3D, FSM, movement, direction, animations
    stats.gd             ← All stat math (STR/AGI/INT/VIT/SPR + Energy/Flow/Focus)
    asset_loader.gd      ← SpriteFrames cache per TYPE (never load same texture twice)
    creature.gd          ← Base creature: FSM, AI, animations, stats
    map.gd               ← Room/map loading stub
  assets/
    spritesheets/        ← player/, creatures/, props/, weapons/
    maps/                ← level_01/, dungeon_cave/, ...
    data/                ← _talents.json, _creature_stats.json, _player_stats.json
```

### Camera System (complete — do not redesign)
- **Files**: `camera_settings.gd`, `camera_rig.gd`, `game_ui.gd`
- **Save path**: `user://camera_settings.tres` (loaded on start, saved on settings close/exit)
- **Zoom**: three-stage — `zoom_step → zoom_target (lerped) → zoom_dist → zoom_effective`
  (zoom_effective is collision-clipped: snaps in immediately, lerps back out)
- **Collision**: two-ray check (pivot→desired, player_top→desired) to handle objects taller than player
- **Player fade**: sprite modulate.a fades when zoom_effective < PLAYER_FADE_START (5.0)
- **Presets**: outdoor (zoom_step=3, pitch=-30°) / indoor (zoom_step=1, pitch=-20°)
  Applied via `apply_active_preset()` which also snaps lerp vars for instant positioning
- **UI**: two-window — pause menu (Resume/Settings/Exit) + flat settings page (half-screen)
  No game pause. Mouse scroll zoom blocked when mouse is over any settings panel rect.

---

## 3. Code Architecture Rules

### Core Principles
1. **Use Godot built-ins first.** AStarGrid2D, Tween, CharacterBody3D, AnimatedSprite3D,
   signals, Timer, modulate. Write custom code only when built-ins genuinely don't fit.
2. **Programmatic scene building.** Entire scene tree built in code (main.gd), not in editor.
   New systems follow this — instantiate and configure in code, not TSCN.
   Pattern: `node.set_script(load("res://scripts/xxx.gd"))` then `node.call("init", ...)`.
3. **Signal-driven communication.** Systems talk via signals, not direct references.
4. **Static caches for shared resources.** asset_loader.gd caches SpriteFrames per type.
   Never load the same texture twice per run.
5. **Stats flow through stats.gd.** All stat math lives there. Never hardcode values in
   entity scripts. Resource names from day one: Focus (not rage), Flow (not mana/mp).
6. **Generic before specific.** New creature → extend creature.gd. New prop → extend
   world_prop.gd. New base class only when the thing is truly different in kind.
7. **No premature abstraction.** Build working first. Three similar functions is fine.
8. **Dirty-check rendering.** Only redraw UI when data actually changes (see hud.gd).
9. **Always annotate types in GDScript.** Every variable, parameter, and return value must have
   an explicit type. Use `:=` for local inference only when the right-hand side makes the type
   unambiguous (e.g. `var x := 0` is fine; `var x := some_func()` is not — annotate explicitly).
   For loop variables and ternary assignments always use explicit annotation:
   `var dir : String = "left" if … else "right"` — never `var dir := "left" if …`.
   This prevents the common GDScript inference errors that occur with Variants, untyped loops,
   and ternary expressions.

### State Machines
Explicit enum state machines in player.gd and creature.gd. When adding states:
- Add to enum
- Handle in `_process` / `_physics_process` switch
- Define valid transitions explicitly
- Entry/exit logic in `_enter_STATE()` / `_exit_STATE()` functions

### Data Files
- Entity spawns: CSV (`_entities.csv`)
- Creature stat presets: JSON (`_creature_stats.json`)
- Player stats: JSON (`_player_stats.json`)
- Talent definitions: JSON (`_talents_weaponmaster.json`, `_talents_spellcaster.json`)
- Ability definitions: `abilities.gd` (acceptable for now)

### Established Godot Patterns (use these — do not reinvent)

**Vector normalization** — always use `.normalized()`, never manual `direction / sqrt(len_sq)`:
```gdscript
velocity = direction.normalized() * speed
```

**Alpha fades** — always use `Tween`, never manual delta accumulation in `_process`:
```gdscript
# Fade out then free the node
var tw := create_tween()
tw.tween_property(sprite, "modulate:a", 0.0, duration)
tw.tween_callback(func(): queue_free())

# Chained sequence: fade out → do something → fade in
tw.tween_property(sprite, "modulate:a", 0.0, duration)
tw.tween_callback(func(): position = target)
tw.tween_property(sprite, "modulate:a", 1.0, duration)
tw.tween_callback(func(): cleanup())
```

**Transparent pixel bounds** — always use `Image.get_used_rect()`, never nested pixel loops.
For a full image (props, single-frame textures):
```gdscript
var img := tex.get_image()
img.convert(Image.FORMAT_RGBA8)
var empty_bottom := tex.get_height() - img.get_used_rect().end.y
```
For first frame of a spritesheet (player, creatures — idle_neutral scan):
```gdscript
var img := tex.get_image()
img.convert(Image.FORMAT_RGBA8)
var first_frame  := img.get_region(Rect2i(0, 0, SPRITE_SIZE, SPRITE_SIZE))
var empty_bottom := SPRITE_SIZE - first_frame.get_used_rect().end.y
```

**Reactive property setters** — use GDScript property setters to trigger side effects when
a variable changes, instead of polling every frame:
```gdscript
var is_inspected : bool = false:
    set(value):
        is_inspected = value
        if not value and state == State.DEAD and not _fading:
            _start_death_fade()
```
Applied in: `creature.gd` (`is_inspected`), `creature.gd` (`camera_angle`), `player.gd` (`camera_angle`).

**Multi-phase Tween actions** — when a sequence requires: do A → wait → do B, use a single
chained Tween with `tween_callback()` between property tweens. No state flags needed.
See `creature._start_teleport()` for the reference implementation.

**Guard flags for one-shot async actions** — when a Tween or async operation must only start
once, use a bool guard checked at entry:
```gdscript
var _fading : bool = false

func _start_death_fade() -> void:
    if _fading:
        return
    _fading = true
    ...
```

---

## 4. Weapon System

### Philosophy (Bastion-style distinct feel)
Every weapon type feels mechanically different — not just stat variations. Two players using
different weapons play differently. Speed, range, attack pattern, combo logic, and resource
interaction all differ per weapon type. This is the primary axis of Weaponmaster identity
variance. A wooden sword and a wooden spear are not "both melee" — they are different games.

### Weapon Acquisition
- Player acquires their first weapon in Vinemore / its surroundings, before entering the cave.
- First weapons are all wooden tier (lowest durability, lowest damage, but full mechanical feel).
- Wooden tier exists to teach the weapon's feel without commitment. Better materials drop later.
- Weapon choice at the start is the player's first expression of emergent class direction.
- **Fist combat**: Player can always attack unarmed. Fists are always available regardless of weapon.

### Zone 1 Starting Weapons (5 Paths)
The player has 5 paths to their first weapon in Zone 1. Sword and staff are mutually exclusive
through a causal world chain — not by items disappearing. Rocks and hand axe stack with anything.

| # | Weapon | How to Get | Notes |
|---|---|---|---|
| 1 | Wooden Sword | Found in the woods — guard mentions the sword owner lost his sword | Hidden in the overworld. Rewards exploration. |
| 2 | Wooden Staff | In the old man's house — must be stolen before any game lock | Theft mechanic. Old man does not find out directly. |
| 3 | Hand Axe (lent) | Go to blacksmith → he gives a creature parts fetch quest first | Guard mentions the blacksmith. Legitimate early path but costs time. |
| 4 | Rocks | Collected from terrain around the village | Ranged. Combinable with any other weapon. Never mutually exclusive. |
| 5 | Small Dagger | Purchased from the village's only shop | Requires trading a magical item (not normal barter). |

### Weapon Tiers (material progression)
Wooden → Iron/Stone → ?? → ?? — exact tier names TBD. Each tier = better stats, same feel.
The weapon's mechanical identity never changes between tiers. Only power scales.

### Planned Weapon Types (feel is the differentiator)
| Weapon | Speed | Range | Pattern | Resource Lean | Feel |
|---|---|---|---|---|---|
| Sword | Medium | Short-med | Single swing, directional | Energy | Balanced, responsive. The default. |
| Spear | Medium | Long | Thrust forward only | Energy | Reach and positioning. Punishes wrong angle. |
| Axe | Slow | Short | Wide slow arc, high damage | Focus | Commitment. Rewards timing, punishes spam. |
| Bow | Medium | Long | Aimed projectile, charge option | Energy | Spatial, requires movement discipline. |
| Staff | Slow | Med-long | Magic projectile or AoE | Flow | Spellcaster entry. Resource heavy. |
| Daggers | Fast | Very short | Multi-hit combo chain | Energy+Focus | High APM, low per-hit. Rewards aggression. |
| Greatsword | Very slow | Med | 3-hit charged swing | Focus | Maximum commitment. Every swing counts. |
| Thrown | Fast | Med | Ricocheting projectile | Energy | Unpredictable angle play. |

Not all weapons available at game start. New weapon types introduced in new zones or as dungeon
rewards. The first choice (in village) is from whatever wooden weapons are available there.

### Weapon Feel Rules (do not violate)
- Speed difference must be perceptible. Axe vs dagger must FEEL different to press.
- Range difference must change player positioning. Spear player hugs range limit. Dagger player
  must close distance entirely.
- Resource lean must be real. A Flow-lean weapon genuinely disadvantages a player with low SPR.
- Never make two weapons feel identical and differ only in numbers.

---

## 5. Known Issues & Active TODO

### Known Issues
- Prop collision calibration — props/entities don't align well to 3D world. Needs a per-prop
  height/offset tuning pass once props are in-scene.
- Hit flash is red tint (GL Compatibility can't do HDR Color(2,2,2) white flash). Upgrade to
  shader-based white flash when visual polish pass comes.

### Creature Attack Tracking (per-type design note)
All creatures currently track the player throughout the attack animation (facing updates every
frame during ATTACK state). This is intentional for small fast creatures (rat, snake).
When slow heavy enemies are added (bear, golem, boss), add a `commits_to_attack : bool` flag
per creature type. When true, skip `_update_facing_toward()` in the ATTACK state so the
creature locks its swing direction on the first frame — the wind-up becomes the telegraph
the player must read to dodge.

### Code Stubs (to replace when the ability system is wired)
- `creature.gd _attack_damage()` — returns flat 5.0. Replace with `ability.use()`.
- `creature.gd State.ATTACK` — calls `player.receive_hit(flat_damage, dir)` directly.
  Replace with ability resolution (resist → dodge → block → damage → crit).
- `player.gd receive_hit(_damage, _knockback_dir)` — empty stub.
  Wire to `stats.take_damage()` + knockback velocity + death in Phase 2.
- A* pathfinding not yet ported — creatures use direct `move_toward` (ignore obstacles).
  Add `pathfinder.gd` port from old project as a separate task.

### Year 1 Priority Phases

**Phase 1 — Core Feel** ✓ COMPLETE (code-side)
- [x] Hit flash on damage (red tint Tween, GL Compat safe)
- [x] Knockback on damage (velocity impulse + friction decay)
- [x] Creature DEAD state + fade + queue_free
- [x] Player Space attack (arc + distance check, creatures group)
- [x] Creature directional animations (front/back + flip_h)
- [x] SpriteFrames cache per type (AssetLoader)
- [x] Sprite export pipeline (tools/export_sprite.py, rotsprite/Scale3x)

**Phase 2 — Playability**
7. Resource rename in code (rage→focus, mana→flow)
8. Hotbar UI (1-0 keys, ability icons, cooldown overlay)
9. Ability / talent book panel UI
10. More Weaponmaster abilities (melee + ranged options)
11. Neutral creature type (aggros only if player attacks first)
12. Creature loot drops + corpse state
13. Player backpack / inventory panel
14. Attack area calculation review

**Phase 3 — First Dungeon Loop**
15. Dungeon room system (room-based maps, door transitions)
16. Indoor props (crates, barrels, basic furniture)
17. Pressure plate puzzle mechanic
18. Block pushing puzzle mechanic (with Z-key undo)
19. Patrol AI script (LINE_PATROL minimum for Ancient Cave)
20. Trap entity script (falling object + spike trap for Ancient Cave)
21. Ancient Cave dungeon — complete (15+ rooms, 2 bosses)
22. Paper-pencil dungeon map UI

**Phase 4 — Progression Systems**
23. Gear system (equip slots, stat bonuses, drop system)
24. Gear durability (WoW-style, repair at NPC)
25. Talent book system (scroll drops, chain unlock, EXP-bought talent points)
26. Boss talent scroll drops (class-influenced)
27. Race selection screen (one-time at game start, permanent)

**Phase 5 — World & Content**
28. NPC shop system
29. Basic quest system (main quest + race-specific + playstyle-specific branches)
30. Old Temple
31. Spellcaster spell list system + spell variety

### Deferred (Post Year 1)
- Multiplayer (any form)
- Dungeon themes 3-8
- Save system implementation (designed in systems_design.md, built later)
- Crafting system
- Cross-area environmental effects (more than 1 example)
- Shapeshifter / pet commander full subclass content
- Ranger-type playstyle content

---

## 6. How to Approach Any Feature Request

**Step 1 — Classify**: Is it a mechanic, entity, UI element, or content? Map to existing systems.

**Step 2 — Check what exists**: Godot built-in? Partial implementation in codebase?
Base class to extend? Read the relevant files before suggesting anything.

**Step 3 — Present options, don't decide**: Give 2-3 concrete approaches with trade-offs.
Ask the developer which direction fits their vision. Never write code or design decisions
unilaterally.

**Step 4 — Implementation plan**: After direction confirmed — data changes → logic → UI → art.
Name specific files to edit. Prefer editing existing over creating new files.

**Step 5 — After implementation**:
- Touch stats.gd? Verify derived stats still correct.
- Affect pathfinding? Check pathfinder.gd obstacle tracking.
- Need new art? List every sprite/tileset requirement explicitly.
- Adding scope? Flag it clearly.

---

## 7. Solo Developer Scope Management

**The biggest risk is scope creep. The second biggest is getting stuck and losing momentum.**

### Evaluating New Ideas
1. Does it improve the core loop? (Enter dungeon → fight → solve puzzles → beat boss →
   get talent scroll → spend EXP → stronger → repeat.)
2. Can it be cut without breaking anything else? If yes → defer it.
3. What art does it require? Art is the real bottleneck for a solo dev. High art-cost features
   should be batched, not scattered between code tasks.
4. One dungeon fully done beats three dungeons half done. Depth over breadth always.

### When Stuck
When stuck on something for more than 2-3 days: switch to a different task from the priority
list. Do NOT abandon the stuck task — leave a detailed comment block in the code explaining
exactly where you stopped and what you were trying to do. Return with fresh eyes.
The skill file and code comments are your memory across sessions.

### When a New Game Idea Comes Up
Extract the core mechanic that makes it fun. Map it to this game's systems. Give a practical
implementation path. State clearly: is this year 1 or post-launch? Don't implement it verbatim
from the source game — adapt it to fit the WoW × Zelda identity.
