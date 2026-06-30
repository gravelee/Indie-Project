---
name: Assets Required
description: Every non-code asset needed for the game — spritesheets, tilesets, props, UI, maps, audio, data files. Updated alongside design changes. Status reflects current state.
type: reference
---

# Assets Required

**Status key**:
- `EXISTS` — in old project, usable as-is or with minor cleanup
- `NEEDED` — design confirmed, asset not yet made
- `TBD` — design not finalized, cannot produce yet
- `⚠ PENDING` — depends on an unresolved design decision

**Spec conventions**:
- All entity sprites: 96×96px, horizontal strip, 8 FPS
- All tiles: 32×32px
- Props: horizontal strip, size in tiles noted
- UI: resolution-relative, designed for 1920×1080

---

## 1. Player Spritesheets

All player animations: 96×96px per frame, horizontal strip.

| Animation | Directions | Frames (est.) | Status |
|---|---|---|---|
| idle_neutral | N, S, E, W | 4-6 each | EXISTS (needs quality review) |
| idle_attack | N, S, E, W | 4-6 each | EXISTS (needs quality review) |
| walking | N, S, E, W | 6-8 each | EXISTS (needs quality review) |
| forward_slash (sword/axe) | N, S, E, W | 4-6 each | EXISTS (needs quality review) |
| roll / dodge | N, S, E, W | 6-8 each | NEEDED |
| push (block pushing puzzles) | N, S, E, W | 4 each | NEEDED |
| block stance (shield raised) | N, S, E, W | 2 each | NEEDED |
| faint / collapse | none | 4-6 | NEEDED |
| spawn | none | 6-8 | EXISTS |
| death | none | 8-10 | EXISTS |

---

## 2. Weapon Sprites

Weapon attack overlays, positioned relative to player sprite.

| Weapon | Sprite | Spec | Status |
|---|---|---|---|
| Wooden sword | attack (2 directions) | 96×96, 4-6 frames | EXISTS |
| Hand axe | attack (4 directions) | 96×96, 4-6 frames | NEEDED |
| Wooden staff | attack / cast (4 directions) | 96×96, 4-6 frames | NEEDED |
| Small dagger | attack (4 directions) | 96×96, 4-8 frames (fast combo) | NEEDED |
| Rocks | throw arc | 32×32 projectile | NEEDED |
| Wand | cast (4 directions) | 96×96, 4-6 frames | NEEDED |
| Wooden shield | equipped visual overlay | 96×96 | NEEDED |

---

## 3. Creature Spritesheets

All creature animations: 96×96px per frame, horizontal strip.

### Zone 1 — Overworld

| Creature | Aggression | States Needed | Status |
|---|---|---|---|
| Rat | hostile | idle_neutral, idle_attack, enter_stance, exit_stance, move, notice, death, rat_bite, rat_slash | EXISTS (needs quality review) |
| Snake | hostile | idle_neutral, idle_attack, enter_stance, exit_stance, move, notice, death, snake_bite, snake_tail_slam | EXISTS (needs quality review) |
| Wolf | neutral | idle_neutral, move, notice, enter_stance, attack, death | NEEDED |
| Bear | neutral | idle_neutral, move, notice, enter_stance, attack (swipe), death | NEEDED |
| Deer | passive | idle, move (flee) | NEEDED |

### Zone 1 — Dungeon (Old Mine + River Cave)

| Creature | Notes | States Needed | Status |
|---|---|---|---|
| Bat | Cave subzone, erratic movement | idle (hanging), fly_idle, fly_move, attack, death | NEEDED |
| Cave Spider | Old Mine specific | idle, move, attack (bite), death | NEEDED |
| Spider Queen | Boss — encounter 1: retreats. Encounter 2: full kill | idle, move, attack_lunge, attack_web, hit, retreat, death | NEEDED |
| Consuming Race Member | Boss — retreats in Zone 1. Intelligent, humanoid-ish | idle, move, attack_physical, attack_void, phase_transition, retreat | TBD (visual design not locked) |

### Disrupted Creatures (spawned by well)

| Creature | Notes | Status |
|---|---|---|
| Stone-type disrupted creature | Wrong, aggressive, spawned by the well in deep mine | TBD (design not locked) |

---

## 4. NPC Sprites

NPCs need at minimum: idle facing south (default), idle facing player direction.
Full 4-direction idle recommended for interactive NPCs. No combat animations needed unless specified.

| NPC | Role | Sprite Needed | Status |
|---|---|---|---|
| Mark | Ares's neighbor | 4-dir idle | NEEDED |
| Peter | Village doctor | 4-dir idle | NEEDED |
| Ms. Kathy | Patient 1, old woman | 4-dir idle, sitting variant | NEEDED |
| Derol | Patient 2, river man | 4-dir idle, bed variant | NEEDED |
| Mr. Gragi | Derol's father | 4-dir idle | NEEDED |
| Fredy | Derol's young son | 4-dir idle (child scale) | NEEDED |
| Vincent | Witness in square | 4-dir idle | NEEDED |
| Miria | Patient 3, pregnant | 4-dir idle, bed variant | NEEDED |
| Dario | Miria's husband | 4-dir idle | NEEDED |
| Leman | Patient 4, chronic health | 4-dir idle, bed variant | NEEDED |
| Daedalos | East gate guard, spear | 4-dir idle + spear | NEEDED |
| Pontos | Sword owner | 4-dir idle | NEEDED |
| Mr. Kardino | Old man, staff owner | 4-dir idle + staff | NEEDED |
| Mr. Lulu | Shop owner | 4-dir idle | NEEDED |
| Nathan | Blacksmith | 4-dir idle + forge pose | NEEDED |
| Kadmios | Carpenter | 4-dir idle | NEEDED |
| Mike | Cave companion | 4-dir idle, injured variant | NEEDED |
| Lesen | Mother of twins | 4-dir idle | NEEDED |
| Felan | Twin boy, spellcaster | 4-dir idle, drained variant | NEEDED |
| Vinie | Twin girl, spellcaster | 4-dir idle, web-wrapped variant, weakened variant | NEEDED |
| Shadow Figure | Void wanderer, no name | 4-dir idle (cloaked, obscured) | NEEDED |
| Mitri | Son of Asotos | 4-dir idle | NEEDED |

---

## 5. Terrain Tilesets

All tiles: 32×32px. Dual-grid variants (16 tiles minimum per tileset for smooth edges).

### Outdoor — Zone 1 (Deep Forest)

| Tileset | Notes | Status |
|---|---|---|
| Dark dirt | Base ground layer | EXISTS |
| Dark grass | Ground layer variant | EXISTS |
| Rock path | Sub-terrain, paths | EXISTS |
| Flora | Sub-terrain, decorative plants | EXISTS |
| Graveyard ground | Dirt + stone path, south of village | NEEDED |
| River bank | Wet dirt, muddy edge near water | NEEDED |
| Water / river | Animated water tiles (3-4 frames) | NEEDED |

### Dungeon — Old Mine

| Tileset | Notes | Status |
|---|---|---|
| Mine stone floor | Base floor, carved stone | NEEDED |
| Mine stone wall | Solid wall, uncut rock face | NEEDED |
| Mine dirt floor | Earthen sections, deeper galleries | NEEDED |
| Drainage channel | Floor tile variant with groove | NEEDED |
| Cart track | Floor tile variant with iron rail | NEEDED |

### Dungeon — River Cave

| Tileset | Notes | Status |
|---|---|---|
| Wet cave stone floor | Smooth water-carved floor | NEEDED |
| Cave stone wall | Natural rock wall, not cut | NEEDED |
| Cave water channel | Flowing river tiles (animated) | NEEDED |
| Cave pool | Still water tiles | NEEDED |

### Interior — Village Buildings

| Tileset | Notes | Status |
|---|---|---|
| Wooden floor | Interior floor, planks | NEEDED |
| Stone floor interior | For stone-floored buildings | NEEDED |
| Wood panel wall | Interior wall surface | NEEDED |

---

## 6. Props

All props: horizontal strip spritesheets. Size in tiles noted. Variants noted.

### Outdoor — Zone 1

| Prop | Size | Variants | States | Status |
|---|---|---|---|---|
| Bush (classic) | 1×1 | 5 | idle_alive, bump, death | EXISTS |
| Grass | 1×1 | 2 | idle_alive, pass, idle_dead | EXISTS |
| Tree (mystic) | 1×1 | 1 | idle_alive (h0, h1, h2 height ext.) | EXISTS |
| Rock (small) | 1×1 | 3 | idle_alive | NEEDED |
| Rock (large / blast wall) | 2×1 | 1 | idle_alive, destroyed | NEEDED |
| Cut trunk | 1×1 | 1 | idle_alive | NEEDED |
| Tree roots | 1×1 | 2 | idle_alive | NEEDED |
| Thorns | 1×1 | 2 | idle_alive | NEEDED |
| Bridge plank sections | 2×1 | 1 | intact, broken | NEEDED |
| Gravestone | 1×1 | 3 | idle | NEEDED |
| Statue (Asotos) | 1×2 | 1 | idle | NEEDED |
| Well (village) | 1×1 | 1 | idle | NEEDED |
| Fence section | 2×1 | 1 | intact, broken | NEEDED |

### Indoor — Village Buildings

| Prop | Size | Variants | States | Status |
|---|---|---|---|---|
| Table | 2×1 | 1 | idle | NEEDED |
| Chair | 1×1 | 2 | idle | NEEDED |
| Bed | 2×1 | 2 | idle, occupied | NEEDED |
| Bookshelf | 1×2 | 1 | idle | NEEDED |
| Fireplace | 1×1 | 1 | idle (animated fire) | NEEDED |
| Candle | 1×1 | 1 | idle (animated flame) | NEEDED |
| Chest (Kardino's) | 1×1 | 1 | closed, open | NEEDED |
| Stove / cooking area | 1×1 | 1 | idle | NEEDED |

### Dungeon — Old Mine

| Prop | Size | Variants | States | Status |
|---|---|---|---|---|
| Mine cart | 2×1 | 1 | idle | NEEDED |
| Support timber frame | 1×2 | 2 | intact, cracked | NEEDED |
| Barrel | 1×1 | 2 | intact, broken | NEEDED |
| Crate (wooden) | 1×1 | 2 | intact, broken | NEEDED |
| Wall lantern (oil) | 1×1 | 1 | lit (animated), unlit | NEEDED |
| Tool niche (pickaxe, mallet) | 1×1 | 1 | idle | NEEDED |
| Ore deposit (vein, decorative) | 1×1 | 2 | idle | NEEDED |
| Blasting powder cylinder | 1×1 | 1 | idle | NEEDED |
| Door (mine-style, wood/iron) | 1×2 | 1 | locked, unlocked, open | NEEDED |
| Pressure plate | 1×1 | 1 | up, down | NEEDED |
| Pushable block | 1×1 | 1 | idle | NEEDED |
| Rubble / cave-in pile | 2×1 | 1 | intact, cleared | NEEDED |

### Dungeon — River Cave

| Prop | Size | Variants | States | Status |
|---|---|---|---|---|
| Stalactite (hanging) | 1×1 | 3 | idle, falling, shattered | NEEDED |
| Stalagmite (floor) | 1×1 | 3 | idle | NEEDED |
| Spider web (decorative) | 1×1 | 3 | idle | NEEDED |
| Spider web cocoon (Vinie) | 1×2 | 1 | intact, cut | NEEDED |
| Cave pool edge | 1×1 | 1 | idle | NEEDED |
| Cracked wall (blast target) | 2×1 | 1 | intact, destroyed | NEEDED |
| Hidden wall crack (passage) | 1×2 | 1 | hidden, revealed | NEEDED |

---

## 7. UI Assets

| Asset | Notes | Status |
|---|---|---|
| HP bar (fill + background) | Bottom HUD, player | EXISTS (functional, not final art) |
| Energy bar | Bottom HUD | EXISTS (functional, not final art) |
| Flow bar (mana) | Bottom HUD | EXISTS (functional, not final art) |
| Focus bar (rage) | Bottom HUD | EXISTS (functional, not final art) |
| Creature HP bar | Above creature | EXISTS (functional, not final art) |
| Hotbar background | 10 slots (1-0 keys) | NEEDED |
| Ability icon frame | Per slot | NEEDED |
| Ability icons | Per ability, class-specific | TBD (abilities not all defined) |
| Cooldown overlay | Darkened + timer on slot | NEEDED |
| Inventory panel | Grid layout, equip slots | NEEDED |
| Equipment slot icons | Per slot type | NEEDED |
| Talent book UI | Scroll/book visual, chain layout | NEEDED |
| Talent chain node (locked/unlocked/maxed) | Per talent tier | NEEDED |
| Dungeon map (blank paper) | Hand-sketched texture, pencil look | NEEDED |
| Dungeon map room fill | Per visited room type | NEEDED |
| Dungeon map annotation icons | Boss, chest, puzzle, etc. | NEEDED |
| Quest log panel | Scrollable list | NEEDED |
| Dialogue box | Background + name plate | NEEDED |
| Main menu background | Full 1920×1080 | NEEDED |
| Character select screen | One slot Year 1, expandable | NEEDED |
| Save/load panel | Slot list | NEEDED |
| Stat panel (creature/player) | Left side panel | EXISTS (functional, not final art) |
| Debug overlay | World-space drawing | EXISTS (dev tool, not shipped) |
| Void axis bar | Unlabeled spectrum bar, Void-path only | NEEDED |

---

## 8. Effect / VFX Sprites

| Effect | Notes | Status |
|---|---|---|
| Physical hit flash | Color(2,2,2) Tween — code-driven, no sprite | EXISTS (in code) |
| Floating damage text | White/red/yellow/gray/purple variants | EXISTS (in code) |
| Creature notice bubble (!) | Small pop above creature | NEEDED |
| Blasting powder explosion | Small, cave-appropriate | NEEDED |
| Bleed DoT indicator | Small drip / tick on entity | NEEDED |
| Poison DoT indicator | Small cloud / tick | NEEDED |
| Burn DoT indicator | Flame flicker | NEEDED |
| Stun indicator | Stars / spiral above head | NEEDED |
| Freeze indicator | Ice crystal visual | NEEDED |
| Void energy rising (well) | Atmospheric, rising particles | NEEDED |
| Spell cast effects | Per Resonance type (Verdant/Ember/Stone) | TBD (spells not designed yet) |
| Lesser Light spell glow | Lantern-equivalent radius light | NEEDED |

---

## 9. Map Layouts (CSV + Tilemap Data)

Map files drive entity spawns, terrain, and prop placement.

| Map | Size | Status |
|---|---|---|
| Level 01 (prototype overworld) | 100×100 | EXISTS (old project) |
| Vinemore village | 100×100 | NEEDED |
| Farming woods (north) | 100×100 | NEEDED |
| Bridge road (east from village) | 100×100 | NEEDED |
| Road to mines (after bridge) | 100×100 | NEEDED |
| Mine entrance area | 100×100 or smaller | NEEDED |
| Graveyard (south of village) | Small sub-map TBD | NEEDED |
| Old Mine — room maps (15-25 rooms) | Sub-maps per room | NEEDED |
| River Cave — room maps (15-25 rooms) | Sub-maps per room | NEEDED |
| Building interiors (per key building) | Small sub-maps | NEEDED |

---

## 10. Data Files (JSON / CSV)

| File | Purpose | Status |
|---|---|---|
| `_player_stats.json` | Player base stats | EXISTS (needs rename: rage→focus, mp→flow) |
| `_creature_stats.json` (level_01) | 8 prototype creature instances | EXISTS |
| `_creature_stats.json` (per zone/dungeon) | Stats for all new creatures | NEEDED |
| `_entities.csv` (per map) | Entity spawn layout per map | EXISTS (prototype only) |
| Tilemap CSVs (per map, per layer) | Terrain tile placement | EXISTS (prototype only) |
| `_talents_weaponmaster.json` | Talent chain definitions, weapon master | NEEDED |
| `_talents_spellcaster.json` | Talent chain definitions, spellcaster | NEEDED |
| `_abilities.json` or stays in `abilities.gd` | Ability definitions | EXISTS in code (TBD: move to JSON?) |
| Quest data structure | Quest IDs, steps, rewards | TBD (system not designed) |
| NPC dialogue data | Dialogue trees per NPC | TBD (system not designed) |
| Shop inventory data | Per-shop item lists | TBD (system not designed) |
| Puzzle configurations JSON | 10-20 solvable configs per puzzle room | NEEDED |

---

## 11. Audio (Placeholder — Not Year 1 Priority)

No audio code implemented. This section tracks what will be needed. Do not produce until Year 1 content is playable.

| Audio | Notes | Status |
|---|---|---|
| Village ambient | Day/night variants, forest sounds | TBD |
| Dungeon ambient (mine) | Echo, drip, distant rumble | TBD |
| Dungeon ambient (cave) | Water, wind, deep cave | TBD |
| Combat music | Per zone / dungeon | TBD |
| Boss music (Spider Queen) | Two phases | TBD |
| Boss music (consuming race member) | Two phases | TBD |
| Attack SFX (per weapon type) | Sword, axe, staff, dagger, rocks | TBD |
| Hit SFX | Physical, magic, critical | TBD |
| Footstep SFX | Per surface type | TBD |
| UI SFX | Menu select, quest complete, level up | TBD |
| Blasting powder SFX | Ignite + explosion | TBD |

---

## 12. Open Asset Questions

These assets cannot be created until design decisions are made:

- **Old Mine mid-boss**: identity unconfirmed → cannot design creature sprite
- **Consuming race member appearance**: visual design not locked → cannot design NPC/creature sprite
- **Disrupted creatures (from well)**: "Stone-type, wrong" — specific look TBD
- **Spellcaster blast spell**: what it looks like visually — TBD
- **Void axis bar**: visual design for the unlabeled spectrum bar — TBD
- **Graveyard blast rock secret**: what's behind it — TBD (affects prop/item needed)
- **Spell effects per Resonance type**: spells not designed → no effect sprites yet
