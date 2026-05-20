---
description: >
  Game production guide for this project — a WoW × Zelda action-adventure RPG in Godot 4.3.
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

The developer is a solo dev and lifelong gamer with deep knowledge of WoW, Zelda series, Naruto,
Genetic Disaster, BOTW, Majora's Mask, DnD, and Four Swords. Always give practical, scoped advice.
Be honest about scope. Flag feature creep immediately. Never decide anything alone — present
options and discuss.

---

## 1. Game Identity & Core Feel

**The pitch**: A top-down action RPG with real-time Zelda-feel combat (active shield, dodge roll,
directional attacks) built on WoW-depth systems (stats, resources, talent chains, gear, dungeons).
No class is chosen — your playstyle and stat investment define what you become. Every dungeon run
has value beyond the story because you're always farming toward the next talent unlock.

**Story**: Linear ending for all players, but branching quest choices affect what happens along
the way. Dungeon order is completely free. Some quests trigger based on your race, others based
on your emergent playstyle. The main quest is a guiding thread, not a forced path.

**Camera**: Top-down, full 360° rotation via RMB drag. WASD is always camera-relative.
Z-sorting is projection-based — already implemented in game.gd.

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

### Tile & Sprite Sizes
- **Tile size**: 32×32 pixels. All measurements scale from this.
- **Entity sprites**: 96×96 pixels (3×3 tiles). Fixed size — do NOT content-fit sprites.
  Z-sort depends on consistent sprite bounds. Transparent bottom rows handled by z_depth_offset
  scan in creature.gd / player.gd.
- **Spritesheets**: Horizontal strips (frames left to right). 8 FPS animation speed.
- **Props**: Size in tile units (1×1, 2×2, etc). Horizontal strip spritesheets.
  Tall sprites (trees) use canvas padding rows for Z-sort correctness.
- **Tilesets**: 32×32 per tile. Multi-tile patterns on 32px grid.
- **Map grid**: 100×100 tiles per level zone. Dungeon rooms can be smaller sub-maps.

### Coordinate Systems
- Tiled editor: top-left anchor. Game code: bottom-left. map.gd handles conversion.
- World coords: Godot 2D (x right, y down). Camera rotation uses sin/cos cached per frame.
- Z-sort formula: `z ∝ pos.x·sin(angle) + pos.y·cos(angle)`. Do not touch unless a specific
  bug is proven. Visual errors are almost always anchor or offset issues, not the formula.

### File Organization
```
godot_project/
  scripts/
    entities/     ← player.gd, creature.gd, stats.gd, ability.gd, abilities.gd,
                     status_effect.gd, statuses.gd
    props/        ← world_prop.gd, damageable_prop.gd, obstacle_prop.gd, terrain_prop.gd
    ui/           ← hud.gd, combat_feedback.gd, stat_panel.gd, debug_overlay.gd
    dungeon/      ← (future) dungeon_room.gd, trap_entity.gd, patrol_ai.gd
    asset_loader.gd
    map.gd
    pathfinder.gd
  assets/
    spritesheets/ ← player/, creatures/, props/, weapons/
    tilemaps/     ← terrain/, sub_terrain/
    maps/         ← level_01/, dungeon_cave/, dungeon_temple/, ...
    data/         ← _mutations.json, _talents.json per class
```

### Rendering
- GL Compatibility renderer (keep — broadest hardware support for indie)
- 1920×1080 fullscreen
- AnimatedSprite2D for all entity sprites

---

## 3. Code Architecture Rules

### Core Principles
1. **Use Godot built-ins first.** AStarGrid2D, Tween, CharacterBody2D, signals, Timer, modulate.
   Write custom code only when built-ins genuinely don't fit the need.
2. **Programmatic scene building.** Entire scene tree built in code (game.gd), not in editor.
   New systems follow this — instantiate and configure in code, not TSCN.
3. **Signal-driven communication.** Systems talk via signals, not direct references.
4. **Static caches for shared resources.** asset_loader.gd caches SpriteFrames. Never load
   the same texture twice per run.
5. **Stats flow through stats.gd.** All stat math lives there. Never hardcode values in
   entity scripts. Resource renames (rage → Focus, mana → Flow) must be updated in stats.gd.
6. **Generic before specific.** New creature → extend creature.gd. New prop → extend
   world_prop.gd. New base class only when the thing is truly different in kind.
7. **No premature abstraction.** Build working first. Three similar functions is fine.
8. **Dirty-check rendering.** Only redraw UI when data actually changes (see hud.gd).

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

## 4. Resource System

Three resources. All characters can have all three — investment in stats determines how much
of each they accumulate. No resource is class-locked.

### Energy
- **Stat base**: AGI
- **Used for**: ALL physical actions — running, rolling, jumping, swimming, pushing objects,
  AND physical abilities. Universal. Both Weaponmaster and Spellcaster spend Energy.
- **Regeneration**: Out of combat only. Creates a natural fight duration limit.
- **Design intent**: Forces real decisions. Sprint everywhere = less for combat.
  A long fight drains everyone regardless of class.

### Flow
- **Was**: Mana (mp in stats.gd — rename throughout)
- **Stat base**: SPR (spirit)
- **Used for**: Magic abilities and spells.
- **Regeneration**: Out of combat only.
- **Design intent**: A Weaponmaster who invests heavily in SPR can accumulate and use Flow.
  A Spellcaster who ignores SPR will run dry quickly. Hybrid builds are valid.

### Focus
- **Was**: Rage (rename throughout stats.gd, ability.gd, hud.gd)
- **Stat base**: STR / combat actions
- **Used for**: Powerful combat abilities that require commitment and rhythm.
- **Regeneration**: Builds DURING combat — increases when landing hits and taking hits
  (adrenaline response: pain sharpens focus, successful hits build rhythm).
  Decays out of combat — fades when danger passes.
- **Design intent**: Focus is adrenaline. The longer you stay in a fight and perform well,
  the more you can spend on decisive actions. It does not exist outside of danger.
  Players who engage aggressively have more Focus to spend. Passive players have none.

### Resource Rename Checklist (code)
When implementing resource renames, update these files:
- `stats.gd` — variable names: `rage` → `focus`, `mp` / `mana` → `flow`
- `ability.gd` — cost fields, damage calculations referencing rage/mana
- `hud.gd` — bar labels, colors
- `abilities.gd` — ability definitions using rage/mana costs
- `creature.gd` — any rage/mana references in AI logic
- `player.gd` — any rage/mana references

---

## 5. Emergent Class System

**There is no class selection screen.** The player selects their race at game start — that is the
only character creation choice. Everything else emerges through play.

### How Classes Emerge
The player spends EXP on stat points. Stat investment shapes which resources grow, which
abilities become available, and which talent trees open. Over time the game reflects back what
the player has become — not what they chose.

- Heavy AGI investment + physical weapon use → Weaponmaster playstyle
- Heavy SPR investment + spell use → Spellcaster playstyle
- High AGI + stealth abilities found → drifts toward Rogue-type
- High INT + summoning scrolls found → drifts toward Summoner-type
- Mixed stats → hybrid identity

The two **fundamental archetypes** are Weaponmaster and Spellcaster. All subclasses
(rogue-type, summoner, pet commander, shapeshifter, etc.) are emergent refinements of these
two directions based on stat choices and abilities acquired.

### Weaponmaster
- Uses any weapon — melee or ranged. Starts with a sword for the tutorial.
  Ranged begins with a bow and expands to thrown weapons later.
- Primary resource: Energy + Focus
- No magic required. Pure body, weapon, and trained technique.
- Talent trees unlock based on weapon type used and AGI/STR thresholds.
- Example subclass directions: heavy melee (high STR/DEF), precision ranged (high AGI),
  dual-weapon fast (high AGI/STR), rogue-type stealth (AGI + specific ability scrolls found).

### Spellcaster
- Chooses spells from an available list as they are found/unlocked.
  Spell selection defines actual playstyle — two Spellcasters with different spell picks
  play completely differently.
- Primary resource: Flow + Energy
- Talent trees unlock based on INT/SPR thresholds and spell types equipped.
- Example subclass directions: ranged burst (high INT, long-range spells), AoE control
  (Frost Nova + ground spells), summoner (specific summon scrolls + INT), close-range
  explosive (short-range AoE spells + higher Energy use).

### Race + Playstyle Quest Branches
Certain quests are triggered by a combination of race AND emergent playstyle.
Example: A Sylviri who has developed Spellcaster tendencies might receive a unique quest
chain about their race's historical connection to Verdant Resonance. A Verak Weaponmaster
might encounter quest lines about an ancient stone-warrior tradition.
These quests are additive — they don't lock other content, they add to it.

---

## 6. EXP & Talent System

EXP is the single currency for all progression. It is also at risk — lost since the last save
on death (see Section 10 on save system).

### EXP Flow
```
Kill creatures / complete quests / clear rooms
         ↓
    EXP accumulated
         ↓
    Player spends EXP
    ↙              ↘
Stat points      Talent points
(STR, AGI,       (spent on talent
STA, etc.)        chains in talent book)
```

No separate currency for talents. EXP is everything. This creates meaningful decisions:
invest in raw stats (more HP, more Energy, etc.) or invest in talent depth.

### Talent Book
- The player has a talent book UI (opened with a key).
- Talents appear in the book only when a talent scroll has been found/dropped.
- Having a talent in the book does NOT mean it is active.
- To activate a talent: the chain prerequisite must be met AND the player must spend
  talent points (bought with EXP) on it.

### Talent Chains
- Talents exist in chains: Tier A → Tier B → Tier C.
- Tier B only becomes available after Tier A is maxed.
- Chain tiers are what gate progression, NOT item rarity.
- Drop chance reflects chain position: Tier A abilities drop more commonly, Tier B less so,
  Tier C are rare drops. This is the only rarity distinction for talents.

### Boss Ability Scroll Drops
- Every dungeon boss has a chance to drop one or more talent ability scrolls.
- Scrolls are class-influenced: a player with Weaponmaster tendencies (high AGI/STR, physical
  weapon use) receives Weaponmaster-relevant drops. A Spellcaster receives magic-type drops.
  The dungeon reads the player's current stat profile to determine drop pool.
- The dropped ability is one the boss itself uses — a signature move.
- Examples: Stone Golem drops "Granite Skin" (defensive passive), Frost Mage drops
  "Ice Lance" (ranged projectile ability), Rat King drops "Frenzy" (speed burst on low HP).
- Scrolls go to the talent book. Player then spends EXP (talent points) to activate if
  the chain prerequisite is already met.
- This is the primary reason to re-run dungeons: farming for a specific talent scroll
  the player didn't get last time, or getting a higher-chain drop they couldn't use yet.

---

## 7. Resonance Lore & World Framework

### World Structure
- **Scale**: Medium world — 8–12 named zones. Dense and handcrafted, not open empty space.
- **Zone transitions**: Zone gates (visual threshold + loading trigger). Seamless transitions
  are a future upgrade — not year 1. Each zone is a complete 100×100 tile map.
- **Starting zone**: Mystic Forest Village — human/elf village deep in a forest.
  Player has a home here. The player belongs to this place before the adventure begins.
- **Zone opening**: After Zone 1, MULTIPLE zones open simultaneously — not a linear chain.
  The world branches. Exploration is the player's choice. Biomes change sporadically across the
  world, but each zone entrance has a deliberate visual shift and introduces 1-2 new mechanics.
  Each zone has its own micro-world (story, NPCs, dungeon, creatures).
- **Zone progression**: No forced order — player can explore zones as they discover connections.
  Soft level gates (creature levels suggest readiness) but never hard locks.
- **Story structure per zone (One Piece formula)**:
  1. Tragic old story — something is wrong here, has been for a long time. Players learn WHY.
  2. The player engages — quests, dungeon, confrontation with what caused the imbalance.
  3. Restoration of order — not always clean. Some quests affect lives of specific people.
     How the player solved it (approach, choices) shapes what the restoration looks like.
  Each zone is a self-contained arc. The zone story and the main quest connect at key beats.

### World Zones (Target: 8–12, Year 1: 2 fully playable)
Planned biomes — names TBD, serve as design anchors:
| Zone | Biome | Water | Notes |
|---|---|---|---|
| 1 | Deep Forest | Rivers, small pools | Starting zone. Mystic Forest Village. |
| 2 | Meadow / Plains | Lakes, wide river | Opens after Zone 1. Other villages near water. |
| 3 | Mountain / Highland | Mountain streams | High altitude, vertical terrain feel. |
| 4 | Swamp / Marsh | Stagnant water, bogs | Dark, overgrown, visibility reduced. |
| 5 | Desert | Rare oasis | Harsh, exposed, heat mechanic potential. |
| 6 | Coastal / Shore | Sea, tidal zones | Near ocean. Sea Bottom dungeon entry point. |
| 7 | Tropical / Jungle | Dense rivers | Hot, lush, ruins buried in growth. |
| 8 | Ice / Snow | Frozen lakes | Cold mechanic potential. Frost Resonance. |
| 9 | Volcanic / Ember | Lava flows | Ember Resonance. Extreme hazard tiles. |
| 10 | Underground Network | Underground rivers | Cave system connecting zones. |
| 11 | Storm Peak / Sky | Clouds, wind | Tempest Resonance. Late game. |
| 12 | Void Sanctum | Absence | Final area. Void Resonance. |

Year 1 scope: Zone 1 (Deep Forest) + Zone 2 (Meadow/Plains). All others: design only.

### Towns & Services
- **Settlement types**: 2 mid-size villages + several smaller settlements/outposts.
  Not every zone has a town — wilderness zones may have only a single NPC camp or shrine.
  Every dungeon has a story but may or may not have a nearby settlement.
- **Standard village services** (what every mid-size village eventually offers):
  Blacksmith (gear repair), Vendor (consumables, basic gear), Inn (manual save, rest buff),
  Quest givers (named NPCs with story), Talent book shop or trainer (spend EXP).
- **Starting village exception**: Mystic Forest Village begins with LESS services.
  Some services unlock as the story progresses (e.g., the blacksmith returns after a quest,
  the inn reopens when an NPC is rescued). Services growing with the story = investment in place.

### Village Shop (Zone 1)
Single shop in Mystic Forest Village. No gold at game start — player must barter creature parts
first. Once barter economy is established, gold flows from bounty quests and can be spent here.

**Stock:**
| Item | Type | Notes |
|---|---|---|
| Small Dagger | Weapon | Requires barter items first to unlock currency |
| Wooden Shield | Equipment | Active blocking item — reduces incoming damage |
| Rations | Consumable | Restores HP + Energy out of combat (see Ration Mechanics below) |
| Rope | Key Item | Used for the broken bridge puzzle in the woods |

**Ration Mechanics:**
- Player uses a ration → sits down animation plays, HP and Energy restore over a few seconds.
- Effect: out of combat only. Eating mid-combat is not possible.
- If combat begins while the player is sitting/eating: effect is immediately cut, player stands
  up and enters combat state. Partial restoration already gained is kept.

### Spellcaster School (Zone 1)
Located in Mystic Forest Village. Entry requires the player to carry a wand or staff of any kind.
Sword-only players cannot enter — this makes stealing the staff (or finding a wand) a meaningful
early decision with real consequences.

**On entry:**
1. The school tests the player for elemental affinity. Affinity is randomly assigned at game
   start — the player does not know it until this test reveals it.
2. A quest is given: discover and test your Flow powers in the surrounding area.
3. Quest completion reward: one random low-level spell from the player's affinity element.

**Creature Aura Investigation Quest** (staff-required):
- Available in the woods — an NPC asks a spellcaster to investigate creature aura anomalies
  caused by the Resonance disruption.
- Reward: a second lesser spell from a random element (may differ from affinity element).

### NPCs
- **Named individuals** with personalities. Not generic types.
- **Schedules**: Key NPCs follow daily routines (Majora's Mask style). They move, sleep, work.
  This is NOT required for every NPC — reserve schedules for significant characters only.
- **Reactive dialogue**: NPCs respond to story progression. The same NPC says different things
  before and after a quest is completed. How the player completed the quest (different choices,
  different approaches) generates different reactions — NPCs are aware of how things were resolved.
- **Exceptional hostility**: In rare cases an NPC can become hostile or be killed. This is the
  exception, not the rule, and always story-driven. Never accidental.

### Zone 1 Quest Structure (Mystic Forest Village)

**Quest log entries available in Zone 1:**

| Quest | Type | Trigger | Notes |
|---|---|---|---|
| Investigate the Cave | Main Quest | Auto on game start / early NPC dialogue | Poisoned water + cave connection. Always in log. |
| Find the Missing Person | Side Quest | Talk to the missing person's relative | Optional. Adds a second objective inside the cave. |
| Return the Sword | Side Quest | The NPC who lost the sword asks you to bring it back | Player chooses: keep sword, OR return it for adventurer's clothing (bonus armor). |
| Borrow the Sword | Repeatable | Same sword NPC | If player returned the sword, they can borrow it temporarily by bringing creature parts as payment. |
| Creature Hides | Side Quest | Village NPC | Skin creatures, collect hides → reward is money (used for rations). |
| Creature Aura Investigation | Side Quest (staff only) | NPC in the woods | Investigate creature aura anomalies with a staff. Reward: second lesser spell (random element). |
| Creature Bounties | Repeatable | Village shop NPC | Bring creature parts (meat, pelts, etc.) for payment. Source of early barter items for dagger/shop access. |

**Progression path**: Village → Woods Area 1 (farming) → Woods Area 2 (bridge) → Cave

**Shop / barter economy note**: The village's only shop cannot accept gold at game start — the
player has no currency. To access the shop (including the dagger and rope), they must first bring
creature parts from bounty hunting. This ties the bridge puzzle and dagger path into the same loop.

### Zone 1 — The Woods (2 Areas)
Both areas are ~100×100 grid maps, same scale as the village. Creatures in the woods must be
avoided at game start — fists alone are not enough to fight safely. Rocks alone are not enough.
The player needs a wooden weapon (sword or staff) before the woods are safely farmable.

**Area 1 — Farming Woods**
- Creatures: Rats (primary), occasional Snake
- Contains the hidden spot where the lost wooden sword can be found
- This is the creature farming zone — player returns here repeatedly for bounty quests and hides
- No combat shortcuts: the sword is a reward for exploring, not handed to the player

**Area 2 — Bridge Road (connects village to cave)**
- Creatures: Snakes (sparse — this is a path, not a farm zone)
- Contains the broken bridge over the poisoned river
- Bridge was destroyed by a storm-felled tree during the Resonance disruption (lightning struck
  a tree, it fell on the bridge, partially collapsing it)
- The river is shallow but the water is poisoned — player cannot swim across
- **The bridge puzzle must be solved to reach the cave** — see Bridge Puzzle below

### Zone 1 — Bridge Puzzle (DESIGN IN PROGRESS — see below)
The fallen tree from the storm is still present at the scene. The bridge has a section of planks
destroyed where the tree fell on it. The river is crossable by height but not by water contact
(poison). The puzzle solution requires an item or action sourced from the village.

**Puzzle solution: TBD** — options presented to developer, decision pending.

---

### Main Quest Arc (10 steps — do not change lightly)
The main quest is a guiding thread, not a forced path. These 10 beats are fixed; everything
between them is player-paced. Race-specific and playstyle-specific quests are additive.

1. **Local disruption**: The Ancient Cave near Mystic Forest Village supplies the village's water.
   Villagers have started getting sick one after another — the water is the source. A person from
   the village has gone missing near the cave. Nobody understands the scope — it looks like a
   local problem: bad water, one missing person. The player investigates.
2. **Into the cave**: Before entering the cave, the player acquires a first weapon from the village
   or its surroundings (multiple paths — see Weapon System / Zone 1 Starting Weapons). They then
   progress from village → woods → cave to find out what is happening.
3. **The global picture**: After clearing the cave, evidence emerges that the disruption is NOT
   local. It's happening across the entire world. Player leaves the starting zone with this weight.
4. **Other peoples**: Player travels far, meets other races and cultures. Forms alliances.
   Some companions join. Each culture has its own relationship with the Resonance disruption.
5. **The consuming race**: Player discovers a race whose existence requires consuming others
   to survive. Not by choice — by nature. Like apex predators. Like humans to the earth.
   They are not evil. They simply ARE what they are.
6. **The antihero villain**: A powerful figure who opposes the player's approach. Not wrong —
   they have valid reasons and genuine truths behind their worldview. They function as a
   mirror: what the player might become if they chose a different path.
7. **The argument**: Player tries to convince the consuming race there is another way to survive.
   This is not a fight — it is a conversation, a philosophical confrontation.
8. **The revelation**: The consuming race did not choose this. They were TRICKED into believing
   this was the only way they could exist. A forbidden alternative lifestyle has been suppressed.
9. **Tracing the deception**: The manipulation traces back to the race's own powerful upper class.
   Those with power exploiting those without — using the powerless as a permanent justification
   for their own authority and survival method.
10. **The resolution**: Not a boss fight to save the day. A confrontation with power structures,
    with inequality, with the cost of choosing to see imbalance and act rather than just doing
    your job and looking away. No clean answers. Inspired by One Piece and Naruto in thematic depth.

**Core themes**: Inequality, power exploitation, the difficulty of seeing imbalance and choosing
to intervene, the cost of having a clear heart/mind/soul in a world that punishes it.

**Villain philosophy (standing rule)**: Any character functioning as antagonist must have a
backstory that explains their worldview, a perspective containing genuine truth, and a reason
they believe their path is better — not just power, not just evil.

### The Resonance Framework
The world is sustained by ancient forces called **Resonances** — not gods, not conscious beings,
just the fundamental energies that everything is made of. Each Resonance sustains a part of the
world: one holds mountains together, another drives water to flow, another makes things grow.
They naturally balance each other like pressure in a closed system.

**When a Resonance is disrupted**, it doesn't die — it goes uncontrolled. The energy that once
held a mountain together now tears it apart. The forest Resonance no longer nurtures growth —
it grows wildly and consumes everything. These disrupted zones become **Resonance Wells** —
what people call dungeons.

Creatures inside Resonance Wells are not evil. They are animals and beings warped by uncontrolled
elemental energy. Their aggression is the Resonance expressing itself without moderation — the
same way electricity arcs when it has no ground. They are not malicious. They are suffering.

**Why dungeons respawn**: Defeating the boss re-anchors the Resonance temporarily, but the
disruption is not permanently healed. The force naturally becomes unstable again over time.
This is the lore justification for dungeon resets — not a game mechanic excuse, an honest
consequence of the world's nature.

### Resonance Types (evolving — add/rename over time)
| Resonance | Sustains | When Disrupted |
|---|---|---|
| **Verdant** | Growth, forests, living things | Wild uncontrolled growth, creature mutation |
| **Ember** | Heat, light, transformation | Uncontrolled burning, volcanic activity |
| **Tide** | Water, cycles, flow | Floods, pressure, deep-sea emergence |
| **Gale** | Wind, sky, movement | Storms, disorienting currents, creatures of air |
| **Stone** | Earth, stability, mass | Collapses, earthquakes, creatures of living rock |
| **Frost** | Cold, stillness, preservation | Frozen spread, re-awakened preserved things |
| **Tempest** | Storm, electricity, violent change | Lightning arcs, electromagnetic distortion |
| **Void** | Silence, absence, space between | Things that shouldn't exist emerging |

### Races & Resonance
Every living thing is composed of Resonances. The number and combination shapes the being.

**Single-Resonance beings**: Driven by one pure force. Not evil — just undivided. No internal
conflict to moderate their nature. A pure Ember creature doesn't choose to burn — burning is
what Ember does. Their aggression (in disrupted zones) is Resonance without balance, not malice.
Single-Resonance beings experience the world with an absolute depth no multi-Resonance being
can match. They are not lesser — they are narrow and perfect within their nature.

**2-3 Resonance beings**: The most stable cultures. Enough internal dialogue to build real
philosophy, focused enough to have clear identity. These are the "wise elder race" archetypes —
not because they are inherently superior, but because balance within creates the capacity for
considered thought.

**All-Resonance beings (Humans)**: The most internally divided. Every force pulls in a different
direction simultaneously. This makes humans volatile, short-lived compared to single-Resonance
races, and prone to extremes — both the greatest acts of good and the worst things in the world's
history have been human. Not because humans are special or chosen — but because they are the only
race capable of going in *any* direction. Their all-Resonance nature is not a gift. It is a burden
that some carry toward wisdom and others toward destruction.

### Planned Races (evolving — expand over time)
- **Humans**: All Resonances in tension. Most adaptable, most volatile. No stat bonus, no
  penalty. The most unpredictable class of beings in the world.
- **Verak**: Stone + Frost. Dense, slow-aging, physically durable. High DEF/STA starting stats.
  Slate-like skin, amber-glow eyes. They don't mine stone — they grow with it over centuries.
- **Sylviri**: Verdant + Tide. Fast healers, poison-resistant. Bark patches, bioluminescent
  markings at night. High SPR/AGI starting stats. Curious and exploratory by nature.
- **Miren**: Tide-primary. Amphibious, iridescent skin, large dark eyes. Fast and agile,
  especially near water. High AGI starting stats. Fully land-capable.
- **Ashkari**: Ember + Gale. Wiry, fast, heat-resistant. Ember-glow veins under skin.
  High STR/AGI starting stats. Reckless and competitive by culture.

Each race has starting stat distributions that naturally nudge toward certain playstyles without
forcing them. Race-specific quests unlock during play based on race + emergent playstyle.

### Villain / Story Depth
No simple antagonist. Any character that functions as an antagonist must have:
- A backstory that explains how they arrived at their worldview
- A perspective that contains genuine truth or valid concern
- A reason they believe their path is better — not just power, not just evil

The most interesting antagonist direction: beings whose *existence* requires consuming others —
not out of malice, but because that is what they are. Like apex predators, like humans to the
earth. The question is not "how do we stop the evil being" — it is "what do we do about a being
that is simply being what it is?" There may be no clean answer. The story should not pretend
there is one. Inspired by Pain, Itachi, and Obito from Naruto Shippuden — characters whose
actions are monstrous and whose reasons are comprehensible.

The story's central mystery: why can't Resonance balance be permanently restored? What disrupted
it in the first place? Who or what keeps it unstable — and do they even know what they're doing?

---

## 8. Weapon System

### Philosophy (Bastion-style distinct feel)
Every weapon type feels mechanically different — not just stat variations. Two players using
different weapons play differently. Speed, range, attack pattern, combo logic, and resource
interaction all differ per weapon type. This is the primary axis of Weaponmaster identity
variance. A wooden sword and a wooden spear are not "both melee" — they are different games.

### Weapon Acquisition
- Player acquires their first weapon in Mystic Forest Village / its surroundings, before entering the cave.
- First weapons are all wooden tier (lowest durability, lowest damage, but full mechanical feel).
- Wooden tier exists to teach the weapon's feel without commitment. Better materials drop later.
- Weapon choice at the start is the player's first expression of emergent class direction.
- **Fist combat**: Player can always attack unarmed. Fists are always available regardless of weapon.

### Zone 1 Starting Weapons (4 Paths)
The player has 4 paths to their first weapon in Zone 1. The wooden weapons are mutually exclusive:
acquiring the sword OR the staff causes the other to disappear permanently. Rocks stack with either.

| # | Weapon | How to Get | Notes |
|---|---|---|---|
| 1 | Wooden Sword | Found in the woods — an NPC in the village mentions losing their sword somewhere out there | Hidden in the overworld. Rewards exploration. |
| 2 | Wooden Staff | In the spellcaster's house in the village — must be stolen from the owner | Theft mechanic. The spellcaster NPC does NOT find out. No reaction. |
| 3 | Rocks | Collected from terrain around the village | Ranged option. Combinable with either wooden weapon. Not mutually exclusive with sword/staff. |
| 4 | Small Dagger | Purchased from the village's only shop | Locked at game start — requires items to barter with first. Items come from creature hunting (bounty quests). Viable only after some progress. |

**Mutual exclusion rule**: Wooden Sword and Wooden Staff are mutually exclusive. The moment one is
picked up, the other becomes permanently inaccessible that run. Rocks + dagger are independent
(rocks can coexist with any weapon; dagger requires barter progression).

**Design intent**: Forces an early commitment that signals playstyle without locking the player in.
The sword/staff choice is the first emergent class signal. Stealing the staff vs. finding the sword
are themselves different character expressions.

### Weapon Tiers (material progression — not Year 1 to implement fully)
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

## 9. Combat System

### Philosophy
Combat must feel responsive and skill-based. Player skill matters more than stats. A skilled
lower-level player should beat content above their level through good execution. Difficulty
does not scale to the player — the world is set, the player rises to meet it.

### Active Mechanics (Zelda-style)
- **Blocking**: Hold a shield button — NOT passive chance. When raised: reduced move speed,
  blocks frontal hits, drains Energy over time. Directional — only blocks from facing direction.
  The `block` stat in stats.gd = maximum block value, but trigger is always explicit input.
- **Dodge roll**: Short invincibility frames, directional, costs Energy. Timing-based.
- **Knockback**: ALL entities (player and creatures) knocked back on damage.
  Velocity impulse away from attacker. Duration: 0.15-0.25s. Force: 200-400 px/s.
  Use Tween to smoothly return control after knockback.
- **Hit flash**: On damage — modulate sprite to Color(2, 2, 2) for 0.08-0.12s, then return.
  Use a Tween. Required on ALL damageable entities: player, creatures, props.
- **Attack cone**: 80px radius, 45° quarter-cone. Keep tight and responsive.
  Hit detection is instant — no lag between input and resolution.

### Resource-Based Combat
- Energy: spending Energy on abilities means less for rolling/fleeing. Every fight has a
  natural endpoint — no infinite sustain.
- Focus: builds during combat (landing hits, taking hits — adrenaline sharpening). Spent on
  powerful decisive actions. Decays out of combat. Players who engage aggressively have more.
- Flow: magic abilities. High-cost spells drain quickly. Out-of-combat regen only.

### Boss Design Principles
- Every boss: 3+ distinct attack patterns.
- Players CAN kill any boss any way. Certain stat builds/talent combinations are
  significantly more efficient (rewards class mastery and appropriate talent investment).
- Visual telegraphing: windup animation + AoE indicator before heavy attacks.
- Enrage on hard content (punishes passive play, rewards aggression).
- Soft level gate: recommended level suggested, not enforced.
- 2 bosses per dungeon: mid-dungeon gate and final boss.
- Final boss has a chance to drop a talent scroll (class-influenced, see Section 6).

### Status Effects
Bleed (DoT, physical), Poison (DoT, nature), Stun (no actions), Slow (reduced mspd),
Freeze (no movement), Burn (DoT, fire). Each has duration + tick interval.

---

## 10. Dungeon System

### Design Rules
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

### Planned Dungeon Themes (Year 1: themes 1-2 only)

**1. Ancient Cave** (starter — tutorial mechanics)
- Resonance: Stone (disrupted)
- Tileset: rough stone, torches, dirt floor
- Creatures: Rat, Bat, Cave Spider (all regular-sized — no "giant" prefix enemies)
- Dungeon AI: spike-line movers (patrol AI), falling stalactites (trap entity)
- Puzzles introduced: pressure plates → doors
- Boss 1 (mid): Cave Spider Queen — spawns smaller spiders as adds, teaches crowd control
- Boss 2 (final): Cave Troll — slow, heavy, teaches blocking and patience. Environment-dependent
  (narrow passages punish it, open rooms let it charge)
- Cave story: The cave is the water source for Mystic Forest Village. A Resonance disruption has
  contaminated the water — villagers are getting sick one by one. A villager has gone missing near
  the cave. The player enters to investigate both the poisoned water and the missing person.
- Talent scroll drops: TBD from Spider Queen, TBD from Cave Troll
- Weapon: player acquires first weapon from village/surroundings BEFORE entering cave (see Zone 1 Starting Weapons)

**2. Old Temple** (intermediate)
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
Do not begin any of these until Ancient Cave + Old Temple are fully polished and playable.

---

## 11. Save System (Not Year 1 Priority — Design Only)

### Death & Respawn (Settled Design)
- **Lore frame**: The player's soul is commanded by a higher purpose. Death is not the end —
  the soul is pulled back. This is not a resurrection mechanic explained as magic. It is the
  world's acknowledgment that the player's mission is unfinished.
- **Respawn location**: Player respawns at their corpse location (the exact spot they died).
  Not at a checkpoint, not at a town. Their body is there — they must return to themselves.
- **Respawn cost**: Durability penalty on all gear (-10%) + all EXP accumulated since last
  autosave is lost. Progress (room clears, puzzle solutions) resets to the last autosave.
- **The design intent**: Fear of loss drives skill-building. Players who take unnecessary risks
  and die repeatedly feel the cost accumulate. Players who learn, adapt, and execute cleanly
  are rewarded by never paying that cost. Skill is the real protection, not a respawn shield.
- **No death screen punishment beyond the above.** The player is returned immediately.
  The grief is in what was lost, not in being lectured at.

### BOTW-Style Autosave at Milestones
The game autosaves when the player achieves a meaningful progression point:
- Puzzle room completed
- Dungeon room cleared of all enemies
- Boss defeated
- Story quest step completed
- Discovered a new zone or dungeon entrance
- Specific overworld events

### Risk Layer
EXP accumulated since the last save is lost on death. The player can continue from their last
autosave or last manual save. This creates tension during long dungeon runs — the further you
push without a milestone save, the more you risk losing.

### Mandatory Challenge Sections
Some dungeon sections require completing without dying for the autosave to trigger. These are
deliberate design choices — not punishment, but a moment where the game demands sustained focus.
These sections should be telegraphed clearly before they begin.

### Manual Save
Available at town inns and specific safe points in the world. Manual save always available at
dungeon entrances (before entering).

### Implementation Note
Save system is NOT a year 1 priority. Core combat, first dungeon, and progression systems
come first. Design it now, build it later.

---

## 12. Indoor Dungeon AI & Trap Entities

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
- Ancient Cave: spike-line movers (LINE_PATROL), falling stalactites (falling object trap)
- Old Temple: wall-following constructs (WALL_FOLLOW), cracked tiles
- Ice Cave: sliding enemies (LINE_PATROL variant — no friction), ice-slide cracked tiles
- Lava Mountain: geyser trap (spike trap variant with fire), lava hazard tiles
- Sea Bottom: current tiles (push player/boxes), pressure dart shooters

---

## 13. Props & Environment Standards

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

## 14. Puzzle Design

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
7. **Environmental trigger**: do something outside to change state inside (see Section 9).
8. **Light/mirror**: reflect beams to targets (late-game dungeons only).

### Procedural Puzzle Configurations
For replayability: block puzzle rooms use randomized configurations from a preset solvable set.
Generate 10-20 solvable configurations per puzzle room (verify solvable with BFS offline).
Pick randomly at dungeon instance creation. Store configurations in JSON alongside room data.

---

## 15. Gear & Durability

### Gear System
Equippable items add flat stat bonuses. Slots: weapon, shield, helmet, chest, legs, boots,
ring ×2, necklace. Items drop from bosses and creatures. Rarity tiers exist for gear ONLY
(not for talent scrolls): Common, Uncommon, Rare, Epic, Legendary.

### Durability (WoW-style)
- Every equipped piece has durability 0-100.
- Degrades on: death (all gear -10%), taking damage (armor -1 per sustained hits), extended
  combat (weapon degrades with heavy use).
- At 0 durability: item provides zero stat bonus. Player warned before reaching 0.
- Repaired at: town blacksmith NPC. Repair cost scales with item level and degradation.
- Design intent: gold sink, reason to return to town, tension during long dungeon runs.
- This is NOT BOTW weapon breaking — gear is precious and should never disappear,
  only degrade and be repaired.

---

## 16. Progression System

### Character Progression Flow
- **EXP** accumulates from: creature kills, quest completions, room clears, puzzles solved.
- **EXP spent on stat points**: STR, AGI, STA, INT, SPR, RES, DEF. No consecutive same-stat
  rule (already in stats.gd).
- **EXP spent on talent points**: talent points spent on chain-unlocked talents in talent book.
- **Level**: derived from base stats average `(STR+AGI+STA+INT+SPR+RES+DEF)/7 + 1`.
- **HP**: `20 + STA×2 + level×2`.
- **Rank**: 14 cosmetic ranks (Unranked → SSS/Kami) based on total EXP accumulated.

### Upgrade Sources
- Dungeon bosses: gear drops (rarity-tiered), talent scrolls (chance-based, class-influenced).
- Overworld exploration: hidden EXP caches, stat-boost shrines.
- Quests: EXP rewards, unique gear, new abilities.
- Vendors: consumables (potions, food buffs), gear repair.

### Economy
- Gold from: creature drops, selling gear, quest rewards.
- Gold sinks: gear repair (durability), consumables, inn rest, vendor services.
- Simple shop UI per town. No auction house.

---

## 17. Multiplayer — Post-Launch DLC Only

Not in scope for the base game. Do not build any networking infrastructure in year 1.

Vision: online co-op for dungeons only (not overworld). WoW LFG-style matchmaking.
Players must have the same main quest progression to enter together. Roles: tank, DPS, healer.
Creature count and levels scale to party size. Multi-player puzzles in the style of
Four Swords Adventures — puzzles requiring coordinated action from multiple players.

---

## 18. Known Issues & Active TODO

### Bugs to Fix First
- Z-sort visual errors (minor) — verify anchor/offset before touching formula.
- A* pathfinding: creature collision shape at feet may cause grid misalignment (status unknown).
- Some creatures push/carry player sprite during return-to-home state.

### Resource Rename (Code Debt)
Rename throughout codebase: `rage` → `focus`, `mp`/`mana` → `flow`.
Files: stats.gd, ability.gd, hud.gd, abilities.gd, creature.gd, player.gd.

### Year 1 Priority Phases

**Phase 1 — Core Feel**
1. Dual-grid tilemap alignment for props
2. Z-sort error investigation and fix
3. Hit flash on damage (Color(2,2,2) Tween, all damageable entities)
4. Knockback on damage (velocity impulse, player + all creatures)
5. Creature left/right back animations
6. SpriteFrames cache per TYPE not per instance

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
30. Old Temple dungeon — complete
31. Spellcaster spell list system + spell variety

### Deferred (Post Year 1)
- Multiplayer (any form)
- Dungeon themes 3-8
- Save system implementation (designed in Section 10, built later)
- Crafting system
- Cross-area environmental effects (more than 1 example)
- Shapeshifter / pet commander full subclass content
- Ranger-type playstyle content

### Creature Roster & Zone Assignment
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
| Cave Spider | hostile | Dungeon (Ancient Cave) specific |
| Wolf | neutral | Attacks if player enters territory or attacks first |
| Bear | neutral | High HP, strong hit, patrols wide area |
| Deer | passive | Ambient wildlife. Flees on approach. |

**Zone 2 — Meadow/Plains (design only, not Year 1)**
TBD — river/lake creatures, plains fauna, first contact with Zone 2 hostile types.

**Dungeon-exclusive creatures**:
- `Cave Spider`: Ancient Cave only.
- `Stone Golem` (boss): Ancient Cave final boss.
- Mid-boss Ancient Cave: TBD (Rat King removed — replacement needed).

**Standing rules**:
- No "giant" prefix creatures in the base roster. Scale through behavior, not size inflation.
- Bosses are distinct creature types from their zone's population — they are the Resonance
  disturbance made manifest, not just a larger version of a common enemy.
- New creature per dungeon is required (Section 9 rule).

### Art TODO (Parallel Track)
- Better player animations (all states)
- Better creature animations (rat, snake)
- New creatures: Cave Spider, Giant Bat, Cultist, Temple Guardian, Vine Crawler
- Effect sprites for abilities and talent activations
- Creature notice/alert popup animation
- Props: turtle tree, bigger trees, rock variants, cut trunk, root cut, thorns
- Dirt terrain tileset
- Ability icons for hotbar
- Weapon sprites (bow for ranged Weaponmaster)
- Indoor props spritesheet (crates, barrels, furniture)

---

## 19. How to Approach Any Feature Request

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

## 20. Solo Developer Scope Management

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
