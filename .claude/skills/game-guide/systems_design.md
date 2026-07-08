---
name: Systems Design Reference
description: >
  Game systems design — resources (Energy/Flow/Focus), emergent class system,
  EXP & talent system, combat mechanics, save system, gear & durability,
  progression, multiplayer scope. Load this when working on any game system,
  stat design, or progression-related decisions.
type: reference
---

# Systems Design Reference

**See also**: SKILL.md (technical/code standards), world_design.md (lore/world),
  zone1_design.md (Zone 1 content), dungeon_design.md (dungeon rooms/bosses/puzzles)

## TL;DR
- **Energy**: depletes from running, rolling, jumping, swimming, pushing/throwing,
  weapon attacks, spells, active shield abilities. Does NOT deplete from passively
  holding shield. Regens out of combat only.
- **Flow** (was mana/mp): used for magic abilities. Regens out of combat only.
- **Focus** (was rage): builds IN combat from landing hits and taking hits. Decays
  out of combat. Spent on powerful decisive actions.
- **Hybrid leveling**: every quest completed = 1 guaranteed stat point (no EXP
  cost). EXP from combat/exploration buys additional stat points OR talent points
  — player's choice each time.
- No class selection screen. Class identity emerges from stat investment + tools found.
- **Faint mechanic**: party members faint at 0 HP — no permanent death. Game over
  ONLY if Ares himself is down with no conscious companion to help.
- EXP accumulated since last autosave is lost on Ares's faint. Gear durability -10% on faint.
- Autosave at: puzzle room cleared, dungeon room cleared, boss defeated, quest
  step complete, new zone/dungeon discovered.
- Gear: equip slots (weapon, shield, helmet, chest, legs, boots, ring×2, necklace).
  WoW-style durability — degrades, repaired at blacksmith, never disappears.
- Talent scrolls: boss drops, class-influenced by current stat profile. Go to
  talent book. Must spend EXP (talent points) to activate.

## Table of Contents
1. [Resource System](#resource-system)
2. [Emergent Class System](#emergent-class-system)
3. [EXP & Talent System](#exp-talent-system)
4. [Combat System](#combat-system)
5. [Save System](#save-system)
6. [Gear & Durability](#gear-durability)
7. [Progression System](#progression-system)
8. [Multiplayer — Post-Launch DLC Only](#multiplayer)

---

## 1. Resource System {#resource-system}

Three resources. All characters can have all three — investment in stats determines how much
of each they accumulate. No resource is class-locked.

### Energy
- **Stat base**: AGI
- **Used for**: Running, rolling, jumping, swimming, pushing/throwing objects, weapon attacks,
  spells, and active shield abilities (e.g. Shield Bash). Universal — both Weaponmaster and
  Spellcaster spend Energy.
- **NOT used for**: Passively holding the shield. Blocking is free while held.
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

## 2. Emergent Class System {#emergent-class-system}

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
- Talent notes (pending full talent tree design):
  Casting resilience — talent chain giving a chance to not lose casting bar
  progress when hit mid-cast.
  Channeling resilience — talent chain giving a chance to not lose channel bar
  progress when hit mid-channel; chance higher than casting resilience because
  channeling spells are a smaller subset of the spell pool.

### Race + Playstyle Quest Branches
Certain quests are triggered by a combination of race AND emergent playstyle.
Example: A Sylviri who has developed Spellcaster tendencies might receive a unique quest
chain about their race's historical connection to Verdant Resonance. A Verak Weaponmaster
might encounter quest lines about an ancient stone-warrior tradition.
These quests are additive — they don't lock other content, they add to it.

---

## 3. EXP & Talent System {#exp-talent-system}

EXP is the single currency for all progression. It is also at risk — lost since the last save
on faint (see Save System section).

### Hybrid Leveling (Settled Design)
Two parallel progression tracks feed into the same stat growth:

**Track 1 — Quest stat point** (guaranteed):
- Every completed quest awards 1 stat point directly. No EXP spend required.
- Reliable floor: a player who does quests always grows, even if they avoid combat.
- Zone 1 has ~14-21 quests total (main + side) → lands the player at roughly level 2-3
  by the time the cave is complete. That math is intentional.

**Track 2 — EXP-bought stat or talent points** (player choice):
- EXP from creature kills, room clears, exploration, and puzzle solves accumulates as normal.
- Player spends this EXP on additional stat points OR talent points — their choice each time.
- Two clear tracks: more raw power (stats) vs. more depth (talents).

These are additive. Quest rewards give guaranteed growth. EXP rewards let the player
decide where to invest extra.

### EXP Flow
```
Kill creatures / clear rooms / explore / puzzles
         ↓
    EXP accumulated
         ↓
    Player spends EXP
    ↙              ↘
Stat points      Talent points
(STR, AGI,       (spent on talent
STA, etc.)        chains in talent book)

PLUS: every completed quest → +1 stat point (guaranteed, no EXP cost)
```

No separate currency for talents. EXP is everything (beyond quest rewards). This creates
meaningful decisions: invest in raw stats (more HP, more Energy, etc.) or invest in talent depth.

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

### Talent Tree Design Notes — Mobility

**Philosophy**: Mobility talents are where WoW's RPG depth meets Zelda's action feel.
In a stat-RPG, mobility is a number. In a Zelda game, mobility is a *feel*. These talents
bridge the gap: each one is a concrete stat or code change that produces a viscerally different
movement experience. A player who goes deep into the mobility tree should feel like a completely
different entity to control than one who ignored it.

All mobility talents are in a single tree accessible to any build (no class gate). They cost
talent points like any other chain. Tier A unlocks Tier B, Tier B unlocks Tier C.

**Jump cooldown reduction** *(code: `JUMP_COOLDOWN` in player.gd)*
- Tier A: reduce post-land cooldown from 0.3s → 0.2s
- Tier B: reduce to 0.1s
- Tier C: remove cooldown entirely — instant re-jump on landing
- Design note: at Tier C the player can effectively bunny-hop for movement. This is intentional
  and rewards investment. Tier C should require significant talent point spend.

**Snap landing** *(code: LAND phase second frame in `_jump_update()`)*
- Single tier talent: remove the second LAND frame (frame 4 absorption) — player regains
  full control immediately on first contact (frame 3 only, then idle).
- Effect: snappier, more aggressive feel. Pairs naturally with jump cooldown reduction.
- Implementation: in LAND phase, check for this talent flag and skip frame 4 entirely.

**Jump height / jump length** *(code: `JUMP_VEL` in player.gd)*
- Tier A: JUMP_VEL 7.75 → 9.0 (peak height ~2.0 tiles, air time ~0.9s)
- Tier B: JUMP_VEL → 10.5 (peak height ~2.75 tiles, air time ~1.05s)
- Tier C: JUMP_VEL → 12.0 (peak height ~3.6 tiles, air time ~1.2s)
- Design note: jump length scales with jump height because `_jump_locked_vel` carries
  horizontal momentum through the longer arc. A sprinting Tier C jump covers serious ground.
  This also opens up platforming sections in dungeons gated behind this talent.

**Sprint speed bonus** *(code: `SPRINT_MULT` in player.gd)*
- Tier A: SPRINT_MULT 1.2 → 1.35
- Tier B: SPRINT_MULT → 1.5
- Tier C: SPRINT_MULT → 1.7
- Design note: stacks with bms stat investment. A high-bms, Tier C sprint character covers
  the map fast. This is the intended reward for a fully mobility-focused build.

**Knockback resistance** *(code: `KNOCKBACK_STRENGTH` in player.gd — apply as a divisor)*
- Tier A: incoming knockback reduced 25% (multiply received strength by 0.75)
- Tier B: reduced 50%
- Tier C: reduced 75% — nearly rooted on hits
- Design note: knockback from creatures interrupts movement and feels terrible against fast
  enemies. Resistance here dramatically changes how the player survives sustained combat.
  High tier = tank-style presence. Implement as a multiplier on the received dir vector in
  `receive_hit()`.

**Object movement speed + cost reduction** *(push/pull system — not yet implemented)*
- Affects the speed at which the player pushes or pulls moveable objects (puzzle blocks,
  heavy props, crates). Also reduces energy cost per world unit moved.
- Tier A: movement speed +30%, energy cost -20%
- Tier B: speed +60%, cost -40%
- Tier C: speed +100% (2× default), cost -60%
- Design note: puzzle blocks that feel sluggish to a fresh player become fluid at Tier C.
  Also opens time-pressure puzzle designs (hit a switch, then push the block before it resets)
  that aren't feasible without at least Tier A investment. The energy cost reduction matters
  in longer puzzle sequences where energy is being drained by multiple push attempts.
  Implementation note: when push/pull is built, add `push_speed_mult` and `push_energy_mult`
  to the player's stat modifier layer.

### Talent Tree Design Notes — Defence

**Philosophy**: Defence talents deepen the shield system. Each talent rewards a more active,
committed blocker — reducing disruption, shortening lock windows, and eventually letting
a skilled player punish attackers for hitting the shield at all.

All defence talents are in a single tree. No class gate — any build with a shield can invest.
Tier A unlocks Tier B, Tier B unlocks Tier C (where chains have multiple tiers).

**Blocked knockback reduction** *(code: `KNOCKBACK_STRENGTH * 0.5` in `receive_hit()` block path)*
- A successful block currently applies `KNOCKBACK_STRENGTH * 0.5` — half the normal knockback.
- This talent further reduces that blocked knockback. Never reaches 0 — some pushback always
  remains to give feedback that the hit landed.
- Tier A: blocked knockback × 0.5 → × 0.35 (65% reduction from full)
- Tier B: blocked knockback × 0.35 → × 0.2 (80% reduction from full)
- Tier C: blocked knockback × 0.2 → × 0.1 (90% reduction from full — barely moves on block)
- Implementation: add `block_kb_mult : float = 0.5` to Stats. Talent tiers lower this value.
  In `receive_hit()` block path:
  `_knockback_vel = dir.normalized() * KNOCKBACK_STRENGTH * stats.block_kb_mult`
- Design note: a Tier C blocker against a fast-attacking enemy is nearly immovable. The 0.1
  floor is intentional — zero knockback would remove all combat weight from blocked hits.

**Early block — last 2 frames of raise**
*(code: block check in `receive_hit()`, currently gated on `BlockPhase.HOLDING`)*
- Normally block chance only activates when the shield is fully raised (BlockPhase.HOLDING).
  During RAISING the player takes full damage.
- This talent (single tier) extends block chance to the last 2 frames of the shield_up
  animation (frames 5–6 of the 7-frame raise).
- Implementation: when this talent is active, the block check condition becomes:
  `_block_phase == BlockPhase.HOLDING or`
  `(_block_phase == BlockPhase.RAISING and sprite.frame >= SHIELD_UP_FRAMES - 2)`
- Design note: rewards players who time their raise to meet an incoming hit. Pairs well
  with Early block — full raise (below) as a prerequisite chain.

**Early block — full raise** *(code: same block check, requires Early block — last 2 frames)*
- Extends block chance to the entire RAISING phase (all 7 frames of shield_up).
- Implementation: when this talent is active, the block check condition becomes:
  `_block_phase == BlockPhase.HOLDING or _block_phase == BlockPhase.RAISING`
- Design note: the natural upgrade of the previous talent. A player with both talents
  can start a raise and already be protected. Combined with blocked knockback reduction
  Tier C, raising the shield into a hit barely staggers the player.

**Counter-knockback on perfect block** *(new: enemy knockback from player block)*
- If a hit is blocked in the first 2 frames of entering shield_stance (HOLDING), the player
  knocks the enemy back in the direction they came from.
- The "first 2 frames" window is tracked by a frame counter that resets each time
  BlockPhase transitions from RAISING → HOLDING.
- Tier A: enemy knocked back at 25% of KNOCKBACK_STRENGTH
- Tier B: 50%
- Tier C: 75%
- Tier D: 100% — full knockback returned to attacker
- Implementation: in `receive_hit()` block path, if the talent is active and the
  "perfect block" window is open, call `creature.receive_knockback(dir * -1.0, strength)`
  (knockback direction is reversed — push attacker away from player).
- Design note: Tier D effectively stuns melee attackers who hit a perfect block. Punishes
  aggressive enemies and rewards patient, timed defensive play. The 2-frame window is tight
  enough that it cannot be spammed — it requires reading the enemy's attack timing.

**Quicken shield** *(code: `SHIELD_UP_FRAMES` and frame accumulator speed in `_block_update()`)*
- The shield_up animation locks the player for 7 frames. This talent reduces the lock window
  by removing frames from both the raise and lower animations. Currently undecided on tiers —
  needs playtesting to know how many frames feel right to cut.
- Design note: this talent is about reducing the commitment cost of blocking. A player who
  never invests feels slow to raise; a player who invests deeply can snap the shield up and
  down quickly, weaving it between actions more fluidly.
- Implementation placeholder: add a `shield_raise_frame_skip : int = 0` to Stats. Increase
  per tier. In `_block_update()`, advance `_block_frame_progress` faster when this is set,
  or skip frames entirely (jump directly to frame `shield_raise_frame_skip` on raise start).
- Tiers: TBD after combat testing.

**Shield arc** *(code: `stats.block_dir_threshold` in `receive_hit()` directional gate)*
- By default the block arc is ±60° (dot > 0.5). Attacks outside this arc bypass block entirely —
  full damage and full knockback regardless of block state.
- This talent widens the arc toward ±90° (dot > 0.0 — full frontal hemisphere).
- 6 talent points total. Each point reduces `block_dir_threshold` by ~0.083 (0.5 / 6).
  Point 1: 0.417 / Point 2: 0.333 / Point 3: 0.25 / Point 4: 0.167 / Point 5: 0.083 / Point 6: 0.0
- Implementation: talent system writes to `stats.block_dir_threshold` directly.
- Design note: at 6 points the player blocks any frontal hit regardless of exact angle.
  This matters most against fast creatures that circle-strafe — at max investment the player
  just has to face roughly toward the attacker. Without investment, precise facing is required.

**Crit block drop resistance** *(code: crit drop logic in `receive_hit()` — not yet implemented)*
- A critical hit while blocking ALWAYS drops the block state (forced BlockPhase transition
  to LOWERING). This cannot be avoided by default.
- This talent gives a percentage chance to resist the crit-forced drop and stay in HOLDING.
- Tier A: 20% chance to resist
- Tier B: 40%
- Tier C: 60%
- Tier D: 80% — a Tier D player will hold their block through most crits
- Design note: intentionally does not reach 100% — a crit should always have a chance to
  break through. The 20% floor per tier means a Tier D player still drops on 1 in 5 crits.
- Implementation: in `receive_hit()` crit-drop path (when the hit is a crit and block is
  active and block check fails), roll `randf() < stats.block_crit_resist` — on success,
  stay in HOLDING instead of entering LOWERING. Add `block_crit_resist : float = 0.0` to Stats.

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

## 4. Combat System {#combat-system}

### Philosophy
Combat must feel responsive and skill-based. Player skill matters more than stats. A skilled
lower-level player should beat content above their level through good execution. Difficulty
does not scale to the player — the world is set, the player rises to meet it.

### Active Mechanics (Zelda-style)
- **Blocking**: Hold a shield button — NOT passive chance. When raised: reduced move speed,
  blocks frontal hits. **Does NOT drain Energy while held** — passive blocking is free.
  Directional — only blocks from facing direction.
  The `block` stat in stats.gd = maximum block value, but trigger is always explicit input.
  **Shield abilities** (e.g. Shield Bash) are active moves that DO cost Energy — passive hold
  and active abilities are distinct.
- **Dodge roll**: Short invincibility frames, directional, costs Energy. Timing-based.
- **Knockback**: ALL entities (player and creatures) knocked back on damage.
  Velocity impulse away from attacker. Duration: 0.15-0.25s. Force: 200-400 px/s.
  Use Tween to smoothly return control after knockback.
- **Hit flash**: On damage — modulate sprite to Color(2, 2, 2, 1) instantly, then Tween back
  to Color(1, 1, 1, 1) over HIT_FLASH_DURATION (0.1s). Use create_tween() — creates a fresh
  Tween each hit so rapid hits restart cleanly without getting stuck.
  ✓ Implemented on player (player.gd _flash_sprite()). Required on ALL damageable entities:
  player, creatures, props — wire in at Stage 8 (creatures) and when props take damage.
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
- Final boss has a chance to drop a talent scroll (class-influenced).

### Status Effects
Bleed (DoT, physical), Poison (DoT, nature), Stun (no actions), Slow (reduced mspd),
Freeze (no movement), Burn (DoT, fire). Each has duration + tick interval.

---

## 5. Save System {#save-system}

**NOT a Year 1 Priority — Design Only.**

### Faint Mechanic (Party Members — Settled Design)
- **Party members** (Mike, Felan, Vinie, etc.) cannot be permanently defeated. At 0 HP they
  **faint** — they fall unconscious and must be treated (carried, stabilized) before they can
  move again. A fainted companion becomes a burden. If you are escorting multiple people, a
  fainted one forces a hard choice.
- **Game over condition for party members**: There is none. They always recover after the
  encounter ends (or if Ares treats them).
- **Game over for Ares**: Only if Ares reaches 0 HP in a situation where NO conscious
  companion can help him — i.e., he is alone or all companions are also fainted. If any
  conscious ally is present, Ares is treated and survives.
- **Design intent**: Permadeath is removed for party members. Tension comes from management:
  keeping companions alive is harder, costs attention, and a fainted companion cannot help.
  The escort sequences remain genuinely tense without being punishing.

### Faint & Recover — Ares Only (Settled Design)
- **Lore frame**: The player's soul is commanded by a higher purpose. Faint is not the end —
  the soul is pulled back. This is not a resurrection mechanic explained as magic. It is the
  world's acknowledgment that the player's mission is unfinished.
- **Recover location**: Player recovers at their body location (the exact spot they fainted).
  Not at a checkpoint, not at a town. Their body is there — they must return to themselves.
- **Recover cost**: Durability penalty on all gear (-10%) + all EXP accumulated since last
  autosave is lost. Progress (room clears, puzzle solutions) resets to the last autosave.
- **Design intent**: Fear of loss drives skill-building. Players who take unnecessary risks
  and faint repeatedly feel the cost accumulate. Players who learn, adapt, and execute cleanly
  are rewarded by never paying that cost. Skill is the real protection, not a recover shield.
- **No faint screen punishment beyond the above.** The player is returned immediately.
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
EXP accumulated since the last save is lost on faint. The player can continue from their last
autosave or last manual save. This creates tension during long dungeon runs — the further you
push without a milestone save, the more you risk losing.

### Mandatory Challenge Sections
Some dungeon sections require completing without fainting for the autosave to trigger. These are
deliberate design choices — not punishment, but a moment where the game demands sustained focus.
These sections should be telegraphed clearly before they begin.

### Manual Save
Available at town inns and specific safe points in the world. Manual save always available at
dungeon entrances (before entering).

---

## 6. Gear & Durability {#gear-durability}

### Gear System
Equippable items add flat stat bonuses. Slots: weapon, shield, helmet, chest, legs, boots,
ring ×2, necklace. Items drop from bosses and creatures. Rarity tiers exist for gear ONLY
(not for talent scrolls): Common, Uncommon, Rare, Epic, Legendary.

### Durability (WoW-style)
- Every equipped piece has durability 0-100.
- Degrades on: faint (all gear -10%), taking damage (armor -1 per sustained hits), extended
  combat (weapon degrades with heavy use).
- At 0 durability: item provides zero stat bonus. Player warned before reaching 0.
- Repaired at: town blacksmith NPC. Repair cost scales with item level and degradation.
- Design intent: gold sink, reason to return to town, tension during long dungeon runs.
- This is NOT BOTW weapon breaking — gear is precious and should never disappear,
  only degrade and be repaired.

---

## 7. Progression System {#progression-system}

### Character Progression Flow
- **EXP** accumulates from: creature kills, quest completions, room clears, puzzles solved.
- **EXP spent on stat points**: STR, AGI, STA, INT, SPR, RES, DEF. No consecutive same-stat
  rule (already in stats.gd).
- **EXP spent on talent points**: talent points spent on chain-unlocked talents in talent book.
- **Level**: derived from base stats average `(STR+AGI+STA+INT+SPR+RES+DEF)/7 + 1`.
- **Level cap: 30.** To reach level 30: average stat ~29 across all 7 = ~203 total stat points.
  Full game (~8 zones × ~20 quests = ~160 quest points) + EXP-bought points covers this naturally.
  DLC expansions add horizontal depth (new talent chains, weapon types, ability tiers) — NOT a
  higher level cap. Cap stays at 30 for the base game lifetime.
- **HP**: `20 + STA×2 + level×2`.
- **Rank**: 14 cosmetic ranks (Unranked → SSS/Kami) based on total EXP accumulated.

### Starting From Nothing
- Player begins with zero abilities beyond unarmed fists. No stat bonuses beyond base values.
- First stat points come from Zone 1 quests — the player feels growth tied to story actions.
- First real ability scroll: found in Zone 1 overworld (hidden), tied to the weapon the player chose.
- First dungeon boss: drops a class-influenced scroll matching current stat profile.
- The game never announces a class identity. The player discovers what they are through play.
- By end of Zone 1: ~1-2 active abilities, a weapon, level 2-3. Identity is forming, not declared.

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

## 8. Multiplayer — Post-Launch DLC Only {#multiplayer}

Not in scope for the base game. Do not build any networking infrastructure in year 1.

Vision: online co-op for dungeons only (not overworld). WoW LFG-style matchmaking.
Players must have the same main quest progression to enter together. Roles: tank, DPS, healer.
Creature count and levels scale to party size. Multi-player puzzles in the style of
Four Swords Adventures — puzzles requiring coordinated action from multiple players.
