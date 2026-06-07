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
- **Last completed**: Two fixes + music this session:
  1. **Startup music** — `caketown_loop.ogg` wired into `main.gd _start_music()`.
     WAV processed (trim silence, bake 2.5s fade-in, bake 3.5s crossfade loop), converted to OGG
     via ffmpeg native vorbis (~137 kbps, 2.7 MB). `AudioStreamOggVorbis`, `loop=true`,
     `loop_offset=2.5` to skip intro fade on repeat. WAV deleted.
  2. **Despawn use-after-free crash** — `map_loader.gd _start_despawn_prop/creature()`: assigning
     a freed node to a typed `Node` variable crashes before `is_instance_valid()` runs. Fixed by
     using `Variant` for the dict get, validating, then casting. Both prop and creature despawn patched.
  3. *(Previous session)* Player attack hits props, export_sprite auto-size, prop freeze bug fixed.
- **Active work**: Phase 1 Core Feel — evaluating next priority.
- **Next session target**: TBD — subclass ability design or next Phase 1 item.
- **Blocked on**: Design questions — (1) Does pet have HP and can it die? (2) Is stealth a button
  or ability-only? (3) Level cap final decision (leaning 30). (4) Player starting stats: all 1s or
  preset minimum?

### What the map currently has (loaded from CSV via map_loader.gd)
- Full terrain from CSV tilemap (dirt, grass layers composited into one PlaneMesh texture)
- Mystic trees (1×1, 1×1_h1 NEW, 1×1_h2, 2×2, 2×2_h1, 2×2_h2, 3×2, 3×2_h1, 3×2_h2), streamed
- Bushes (small/mid/large, classic 5 variants + leafy + spiky, with and without collision), streamed
- Grass (1×1, 2×1, 3×1, no collision), streamed
- Player spawn from entities CSV
- 4 test creatures: rat hostile+home+wander, rat hostile+home+no-wander, snake hostile+no-home+wander,
  rat neutral+no-home+no-wander
- Test geometry in main.gd: ledge, ramp, cliff, mountain, small walls, pushable block

### Pending (no priority order yet)
- ~~**Rename move → wander**~~ ✓ DONE
- ~~**Player attack hitting props**~~ ✓ DONE — `_do_attack()` hits damageable_props group; one-hit kill via `take_hit()`.
- ~~**export_sprite.py auto-size generation**~~ ✓ DONE — SCALABLE_PROPS config, only 1x1 source needed, all sizes auto-generated via rotsprite.
- ~~**Startup music**~~ ✓ DONE — `caketown_loop.ogg` playing with crossfade loop and fade-in baked in.
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
- **Required sprite settings** (ALL sprites — entity, prop, tree, anything):
  ```gdscript
  sprite.alpha_cut      = SpriteBase3D.ALPHA_CUT_DISABLED
  sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
  ```
  `TEXTURE_FILTER_NEAREST`: the real fix for fringe artifacts. Prevents bilinear UV bleed at
  atlas frame boundaries and GL triangle seams on large billboards (corpse fringe, tree center-line).
  `ALPHA_CUT_DISABLED`: required so overlapping sprites don't occlude each other. OPAQUE_PREPASS
  writes depth from sprite A, cutting holes in sprite B — do NOT use it. Modulate fades work
  correctly with DISABLED since no depth writing occurs for transparent geometry.
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

**Idle sprite startup — never use `play()` for static frames** — `sprite.play(states[0])` in
`_ready()` calls `set_process_internal(true)`, registering the node for per-frame processing.
With 1000+ props this costs multiple ms per frame. Use direct assignment instead:
```gdscript
sprite.animation = states[0]
sprite.frame     = 0
```
Only call `sprite.play()` for animations that actually advance frames (reactions, death). This
applies to any node type that shows a static first frame on startup.

**All 3D mesh materials must be SHADING_MODE_UNSHADED** — there are no lights in the scene.
Default `StandardMaterial3D` responds to lighting; with zero ambient it renders near-black.
```gdscript
mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
```
Apply to every `MeshInstance3D` material: terrain plane, collision boxes, ledges, water, walls.
`AnimatedSprite3D` is unaffected — it renders at full brightness regardless.

**Canvas-padded animation sheets** — when a prop has `_idle_blit_y >= 0` (TerrainProp/grass),
the idle texture is canvas-padded (extra rows added so the sprite sits on the ground). Animation
sheets (pass/death) must receive the **same padding** in `_load_anim_sheet()`, or `frame_h`
exceeds the sheet height, the atlas samples out of bounds, and the animation shifts/wraps visually.
The fix: if `_idle_blit_y >= 0`, blit the raw sheet into a taller image at `_idle_blit_y` offset
before slicing frames, same as `_load_prop_tex()` does for idle.

**Push / pull / grab mechanic** — `pushable_block.gd` (`CharacterBody3D`, group "pushable",
`_driven : bool` suppresses its own physics while player controls it).
Player states: GRAB (latched, frozen frame 0) → PUSH (block ahead) ↔ PULL (block behind).
Key rules:
- `_grab_approach_dir`: cardinal player→block locked at GRAB entry. Never changes mid-interaction.
- `_locked_move_dir`: current movement direction (= approach for push, = -approach for pull).
- Direct PUSH↔PULL transitions on opposite-key press — no GRAB intermediate frame.
- `_drive_pulled_block()` called AFTER `player.move_and_slide()` so player clears the path first.
- `_pull_block_frames >= 2` required before freezing player (prevents false positive on first frame).
- Camera-sync fix: `_snap_cam(v: Vector2)` uses Y-tiebreaker (matches `_set_facing_from_input`)
  so direction validity and animation change fire at the exact same camera rotation angle.
- Grab alignment: `D = PLAYER_CAPSULE_RADIUS * 1.5` (0.60). Player center must be within
  `half - D` of block face center. Snap-to-grab: if on-face but misaligned, player nudges the
  minimum distance needed to pass the threshold (not a full centering snap).
  Applies to all 4 approach directions.
- `PUSH_SPEED = 2.5`, `PULL_SPEED = 1.8` (pull is noticeably slower).

**Two-timer system (combat idle vs regen)** — player.gd uses two independent timers:
- `_combat_timer` (`COMBAT_TIMEOUT = 3.0s`): set by (a) player landing a hit on a creature in
  `_do_attack`, (b) player receiving a hit in `receive_hit`, OR (c) any hostile creature calling
  `player._extend_combat_timer()` each frame while in NOTICE/NEUTRAL_TO_ATTACK/CHASE/IDLE_ATTACK/
  ATTACK states. Drives `_is_in_combat()` and the `idle_attack` animation.
  Attacking into air does NOT set this — it only sets `_regen_timer`.
- `_regen_timer` (`REGEN_PAUSE = 3.0s`): set on ANY player action (attack start, receive_hit).
  Pauses stat regen regardless of what was hit. Tunable independently of COMBAT_TIMEOUT.

Regen runs only when both timers are zero:
```gdscript
if _combat_timer <= 0.0 and _regen_timer <= 0.0:
    stats.regen(delta)
```

Creature ping (creature.gd `_physics_process`, after `_update_state`):
```gdscript
const HOSTILE_STATES : Array = [
    State.NEUTRAL_TO_ATTACK,
    State.CHASE, State.IDLE_ATTACK, State.ATTACK,
]
if state in HOSTILE_STATES and player != null and player.has_method("_extend_combat_timer"):
    player.call("_extend_combat_timer")
```
NOTICE is NOT in HOSTILE_STATES — it's pre-combat awareness, not aggression. The creature
noticed the player but has not committed to attack yet. Neither side enters combat during NOTICE.
This means regen is suppressed the entire time a creature is actively chasing/attacking, not just
when damage is exchanged. As soon as all hostile creatures leave HOSTILE_STATES (die, return home,
go neutral), `_combat_timer` starts counting down and regen resumes after 3 seconds.

`_is_in_combat()` returns true if `_combat_timer > 0`. `creature.gd` exposes `in_combat : bool`
updated in `_set_state` for states NEUTRAL_TO_ATTACK / IDLE_ATTACK / CHASE / ATTACK.
IDLE state anim key rebuilt every frame in `_sync_anim` so the switch back to `idle_neutral`
happens automatically when combat ends.

**Weapon-style animation routing** — player has `weapon_main : String` and `weapon_off : String`
(empty = unarmed). All weapon-dependent anim keys are built as:
```gdscript
var style : String = weapon_main if weapon_main != "" else "unarmed"
_anim_key = "attack_" + style + "_" + FACING_STR[facing]       # ATTACK state
_anim_key = "idle_attack_" + style + "_" + FACING_STR[facing]  # IDLE combat
```
Export script source paths follow `{dir}/{anim_type}/{style}/` (e.g. `south/attack/unarmed/`).
Output PNGs: `attack_unarmed_south.png`, `idle_attack_unarmed_south.png`, etc.
Adding a new weapon = new export block + new `_add_strip` block + set `weapon_main`.

**Target system** — WoW-style single target. Lives in `player.gd` and `creature.gd`.

- `_target : Node` — current target (null = none). Set via `_set_target(node)` / `_clear_target()`.
- `_set_target` toggles `is_targeted` on old and new creature — property setter shows/hides the ring.
- Target drops automatically when: creature dies, creature enters RETURNING state, creature walks
  beyond `TAB_TARGET_RANGE` (40 units). Persists through walls (LOS loss does not clear it).
- Auto-target: `_do_attack()` targets nearest struck creature if no current target.
  `receive_hit()` targets the attacker if no current target.

Tab cycling — `_try_tab_target()`:
- Full pool: alive + within 40 units + clear LOS (`_has_los()` ray from player head to creature head,
  excludes all creatures so only world geometry blocks it).
- Tier 1 (on-screen): creatures visible in camera frustum, sorted nearest first.
- Tier 2 fallback: nothing on screen → all pool creatures, nearest first.
- `_tab_tier` tracks active tier; buffer resets on tier switch so cycling restarts cleanly.
- `_tab_buffer` tracks visited creatures per session; wraps when all visited.

Target ring (creature.gd):
- Hollow `TorusMesh` at ground level under creature. Built in `_build_target_ring()`, hidden by default.
- `is_targeted : bool` property setter shows/hides the ring.
- Color driven by `_update_ring_color()` called on every `_set_state()` transition:
  - Gold: `IDLE_NEUTRAL`, `WANDER`, `RETURNING` (and all other neutral states)
  - Orange: `NOTICE`, `NEUTRAL_TO_ATTACK`, `ATTACK_TO_NEUTRAL`
  - Red: `IDLE_ATTACK`, `CHASE`, `ATTACK`
- `head_height : float` on creature = top of capsule (set in `_build_collision`). Used by LOS ray.

**Debug panel** (`debug_panel.gd`) — replaces old target frame. `Node2D` on a `CanvasLayer`
(layer=2), `PROCESS_MODE_ALWAYS` (works while paused).
- Creature panel: top-left, shown when `_player._target != null`. Always visible: name + resource
  bars (HP/Energy/Focus/Flow) with integer current/max. Collapsible: STATS / STATE / AI sections.
  AI section shows per-ability cooldown timers.
- Player panel: top-right, P key toggles + pauses game. Same bar + section structure.
- Dead creature: gray ring, no attack-range dot. Panel stays open until out of range / Tab / click.
- Creature selection: left-click within 52px of screen-projected `global_position` (ignores dead
  if game is live; allows dead when inspecting via panel). `set_input_as_handled()` after every
  handled click/Tab prevents `player._unhandled_input` from double-processing.
- Click outside panel: clears target via `_clear_target()`.
- Tab while paused: calls `_player._try_tab_target()` directly (panel has PROCESS_MODE_ALWAYS).
- `_had_target : bool` ensures one final `queue_redraw()` when target is cleared so panel erases.
- Integer bars: pct = `float(int(value)) / float(max)` — bar moves only on whole-number change.

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

**Ability system** — `ability.gd` (RefCounted, owns cooldown timer), `abilities.gd` (static factory).
Caller flow: `can_use(stats)` → `spend(stats)` → `calc_damage(stats)` → `target.receive_hit(dmg, dir)`.
Each entity holds its own Ability instances so cooldown timers are independent.
Player hotbar: `Array[Ability]` (10 slots, null = empty), `_slot_requested : int = -1` set by
key input, resolved in `_handle_attack`. Keys 1-9 → slots 0-8, Key 0 → slot 9, Space → slot 0.

Hit-frame mechanic (player, same as creature): damage does NOT fire on attack start.
`_hit_applied : bool` resets on each new swing. `_handle_attack` checks
`sprite.frame >= _active_ability.hit_frame` every frame and fires `_do_attack()` exactly once.
```gdscript
# In _handle_attack, ATTACK branch:
if not _hit_applied and sprite.frame >= _active_ability.hit_frame:
    _hit_applied = true
    _do_attack()
if not sprite.is_playing():
    _set_state(State.IDLE)
# On new attack start:
_hit_applied = false
_active_ability = ab
ab.spend(stats)
_set_state(State.ATTACK)
```
New abilities: add entry to `_DATA` dict in `abilities.gd`, then `Abilities.get_ability("id")`.

**Creature ability system** — creatures own per-instance `Array[Ability]` with individual timers.

- `_creature_abilities` populated in `_init_creature_abilities()` (called after `_load_animations()`).
  Uses `Abilities.get_ids_for_type(type)` to auto-discover all `type_*` entries, then filters by
  whether the animation (`ab.anim + "_front"`) exists in the creature's spritesheet.
- `_attack_dist` derived from the **minimum** ability range in the pool — creature closes until
  ALL its abilities can reach. Wider-range abilities are still in range at this distance.
- `_pick_best_ability()`: iterates pool, filters by `can_use(stats)` (cooldown + resources) and
  `dist <= ab.range_`, returns highest `damage_mult`. Returns null if nothing ready.
- IDLE_ATTACK fires immediately when `_pick_best_ability() != null` — no fixed cooldown timer.
- On ATTACK state entry: pick + `spend(stats)` (starts per-ability cooldown). `_chosen_attack`
  set from `_active_ability.anim`. Hit frame from `_active_ability.hit_frame`.
- Ability tick gated: `if not is_dead: for ab in _creature_abilities: ab.tick(delta)`.
- Focus gain mirrors player: `gain_focus_on_hit(dmg)` on landing, `gain_focus_on_receive(actual)`
  in `receive_hit()`. Heavy abilities (rat_slash, snake_tail_slam) cost 10 focus.
- To add a new creature ability: add entry to `abilities.gd _DATA` with key `type_name`, set
  `anim` to the animation prefix, add energy/focus costs. No changes to creature.gd needed.

**HP / resource integer contract** — resources accumulate as floats internally (regen uses delta),
but the integer value is authoritative for all gameplay decisions:
- `stats.is_alive()` → `hp >= 1.0` (not `> 0.0`). Fractional hp below 1 = dead.
- `take_damage()` snaps hp to 0 if result < 1.0 after applying damage.
- Sprint gate: `stats.energy >= 1.0` (not `> 0.0`) prevents re-entering RUN on fractional regen.
- UI bars use `float(int(value)) / float(max)` — moves only on whole-number changes.

**Knockback impulse** — never add knockback directly to `velocity`. `_handle_movement()` runs
next frame and overwrites `velocity.x/z`, killing the impulse in one tick (invisible). Instead,
use a separate decaying `_knockback_vel` applied AFTER movement each frame:
```gdscript
const KNOCKBACK_STRENGTH : float = 6.0
const KNOCKBACK_FRICTION : float = 20.0
var _knockback_vel : Vector3 = Vector3.ZERO

# In _physics_process, after _handle_movement():
if _knockback_vel.length_squared() > 0.01:
    velocity.x += _knockback_vel.x
    velocity.z += _knockback_vel.z
    _knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, KNOCKBACK_FRICTION * delta)
else:
    _knockback_vel = Vector3.ZERO

# In receive_hit / _apply_knockback:
func _apply_knockback(dir: Vector3) -> void:
    var flat : Vector3 = Vector3(dir.x, 0.0, dir.z)
    if flat.length_squared() > 0.0:
        _knockback_vel = flat.normalized() * KNOCKBACK_STRENGTH
```
Applied in: `player.gd`, `creature.gd`. Tune: STRENGTH = force of push, FRICTION = decay speed
(higher = shorter slide). At 6.0 / 20.0 the slide lasts ~0.3s.

**Knockback-before-death** — creature must play out its knockback before entering DEATH state.
Never call `_enter_death()` immediately on lethal damage. Use `_pending_death : bool`:
```gdscript
# In receive_hit(), on lethal damage:
_pending_death = true   # do NOT call _enter_death() here

# In _physics_process, in the knockback else-branch (velocity settled):
else:
    _knockback_vel = Vector3.ZERO
    if _pending_death:
        _pending_death = false
        _enter_death()

# _enter_death() does NOT zero _knockback_vel (already settled by the time it runs).
```
This ensures the corpse slides visibly before the death animation begins.
Also guard `receive_hit()` against double-death: check `state == State.DEATH` at entry.

**Sprint/exertion energy drain** — accumulate active-time across state transitions to prevent
tap-exploit. Applies to RUN, PUSH, and PULL equally (all cost 1 energy/second):
```gdscript
var _run_energy_accum : float = 0.0   # persists; shared across RUN/PUSH/PULL

# In _physics_process, after _handle_movement():
if state == State.RUN or state == State.PUSH or state == State.PULL:
    _run_energy_accum += delta
    if _run_energy_accum >= 1.0:
        var ticks : int = int(_run_energy_accum)
        stats.energy      = maxf(0.0, stats.energy - SPRINT_ENERGY_COST * ticks)
        _run_energy_accum -= float(ticks)   # keep remainder — never reset to 0
```
Accumulator persists between exertion bursts — tap-running and tap-pushing both accumulate.

Regen is blocked while in any exertion state (RUN, PUSH, PULL, GRAB):
```gdscript
if _combat_timer <= 0.0 and _regen_timer <= 0.0 \
        and state != State.RUN and state != State.PUSH \
        and state != State.PULL and state != State.GRAB:
    stats.regen(delta)
```

**Sprite rendering — required on every new SpriteBase3D node:**
```gdscript
sprite.alpha_cut      = SpriteBase3D.ALPHA_CUT_DISABLED
sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
```
- `TEXTURE_FILTER_NEAREST` prevents bilinear bleed at atlas frame edges and GL triangle seams
  on large billboards. Without it: horizontal fringe on corpses, vertical line on tall trees.
- `ALPHA_CUT_DISABLED` is mandatory for overlapping sprites. `ALPHA_CUT_OPAQUE_PREPASS` was
  tried and caused sprite A's depth prepass to cut holes in sprite B when they overlap — do NOT
  use it. `DISABLED` skips depth writes so sprites alpha-blend correctly over each other.
  Modulate fades (tween modulate:a) still work correctly with DISABLED.

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

### Map / Prop Performance System (implemented)
- **Streaming window**: 75×75 tiles centered on player. Re-evaluated every 5 tiles of movement.
  Props outside window fade out and free; props entering window fade in. Terrain mesh always full.
- **Tree collision batching**: all non-destructible props (trees, 547 nodes) share ONE
  `StaticBody3D` (`TreeCollision`). Each tree adds a `CylinderShape3D` to this shared body instead
  of owning its own body. Drops BVH broadphase from 547 entries to 1 for trees.
  `_tree_shapes : Dictionary` (Vector2i → CollisionShape3D) manages per-tree shape lifetime.
  On despawn: shape is `queue_free()`'d from the shared body.
- **Entity-side prop reaction**: each entity (player + every creature) has a small `Area3D`
  (`ReactZone`, radius=0.65, monitoring=true, mask=`PROP_REACT_LAYER=4`). Each `DamageableProp`
  owns a `DetectZone` Area3D (monitorable=true, layer=PROP_REACT_LAYER). Entity zones fire
  `area_entered` / `area_exited` on contact with DetectZones.
  Reaction is a **start/stop loop model** — not one-shot:
  - Entity tracks `_react_overlap` (inside) and `_react_driving` (called start_reaction on).
  - Each physics frame: if moving → call `start_reaction()` on any undriven overlap props;
    if stopped → call `stop_reaction()` on all driven props.
  - `area_exited` → stop_reaction + remove from both lists.
  - Prop `_react_count` tracks how many entities are driving it. `_on_animation_finished`
    restarts the reaction anim if `_react_count > 0`; otherwise snaps to idle (natural wind-down).
  - No cooldown. No timer. Animation loops while entity moves inside; finishes naturally on exit.
- **Future tree animation**: trees stay as individual visual nodes (AnimatedSprite3D) so per-tree
  idle animations (sway, distance-based oscillation) can be added without architecture changes.
  Collision stays batched regardless of animation.

### Creature Attack Tracking (per-type design note)
All creatures currently track the player throughout the attack animation (facing updates every
frame during ATTACK state). This is intentional for small fast creatures (rat, snake).
When slow heavy enemies are added (bear, golem, boss), add a `commits_to_attack : bool` flag
per creature type. When true, skip `_update_facing_toward()` in the ATTACK state so the
creature locks its swing direction on the first frame — the wind-up becomes the telegraph
the player must read to dodge.

### Code Stubs (to replace in later phases)
- `creature.gd _attack_damage()` — currently returns `stats.patk` (real value, no multiplier).
  Replace with `Abilities.get_ability(id)` + `ab.calc_damage(stats)` to apply `damage_mult`,
  crit, resist, and block resolution properly.
- `creature.gd State.ATTACK` — calls `player.receive_hit(patk, dir)` directly.
  Replace with full ability resolution (resist → dodge → block → damage → crit).
- A* pathfinding not yet ported — creatures use direct `move_toward` (ignore obstacles).
  Add `pathfinder.gd` port from old project as a separate task.

### Year 1 Priority Phases

**Phase 1 — Core Feel** ✓ COMPLETE
- [x] Hit flash on damage (red tint Tween, GL Compat safe)
- [x] Knockback on damage (velocity impulse + friction decay)
- [x] Creature DEAD state + fade + queue_free
- [x] Player attack (arc + distance check, hit-frame timing, creatures group)
- [x] Creature directional animations (front/back + flip_h)
- [x] SpriteFrames cache per type (AssetLoader)
- [x] Sprite export pipeline (tools/export_sprite.py, rotsprite/Scale3x)
- [x] Push / pull / grab mechanic (PUSH, GRAB, PULL states, camera-sync, snap-to-grab)
- [x] Combat idle system (idle_attack_unarmed vs idle_neutral, creature in_combat flag)
- [x] Weapon slot stubs (weapon_main / weapon_off), style-based anim key routing
- [x] Hit-frame mechanic for player (sprite.frame >= ability.hit_frame before damage fires)

**Phase 2 — Playability**
1. ~~Hotbar UI~~ ✓ DONE
2. ~~Target system~~ ✓ DONE — see target system pattern below
3. ~~Creature stats from JSON~~ ✓ DONE — `assets/data/_creature_stats.json`, loaded via AssetLoader
4. Ability / talent book panel UI
5. More Weaponmaster abilities (melee + ranged options)
6. ~~Neutral creature type~~ ✓ DONE
7. Creature loot drops + corpse looting
8. Player backpack / inventory panel
9. Attack area review (unarmed range/arc tested, weapon variants will differ)

**Phase 3 — First Dungeon Loop**
1. Dungeon room system (room-based maps, door transitions)
2. Indoor props (crates, barrels, basic furniture)
3. Pressure plate puzzle mechanic
4. ~~Block pushing~~ ✓ DONE — push/pull/grab fully implemented. Z-key undo still pending.
5. Patrol AI script (LINE_PATROL minimum for Ancient Cave)
6. Trap entity script (falling object + spike trap for Ancient Cave)
7. Ancient Cave dungeon — complete (15+ rooms, 2 bosses)
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
