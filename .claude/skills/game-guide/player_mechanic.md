---
name: Player Mechanics
description: >
  All mechanics Ares can do, grouped by category.
  Source of truth for player behavior.
type: reference
---

# Player Mechanics — Ares

**See also**: SKILL.md (hub), player_input.md (input mapping),
systems_design.md (resource costs)

Console portability is a hard constraint on every mechanic — every input must map to all
input modes (keyboard only, keyboard+mouse, controller). See player_input.md.

[input] — player-input action; requires a dedicated button press or combination.
Bindings in player_input.md; context and sequence rules defined here.
[auto] — auto-triggered action; no dedicated input for this mechanic. Fires when
game conditions are met — player movement or combat may be a prerequisite, but
no specific button press triggers it directly.

Entry format:
  [input]: **Name** [input] — input; condition; behavior; details.
  [auto]:  **Name** [auto] — condition; behavior; details.

---

## Contents

**Presence** — base idle states: out-of-combat, in-combat, in-water
**Resources** — HP, energy, focus, flow
**Movement** — walk, sprint, jump, dodge, climb down, climb, swim, sit, crouch, ledge hang
**Camera** — free, steering, reset, soft-lock modes; pitch, zoom, underwater behavior
**Combat** — attack combos, parry, stance slot (block/resistance), targeting, receive damage
**Abilities** — ability framework; categories: mobility, damage,
control, defensive, recovery, utility
**World Interaction** — grab, push, pull, hold (carry), loot, acquire,
  boost item, open, cross, talk
**Equipment** — weapon slots, armor, inventory
**Status Effects** — buffs, debuffs
**Lifecycle** — spawn, faint, recover
**Expressive** — bow

---

## Presence

- **Idle (out of combat)** [auto] — player stationary, grounded, no combat timer;
  main hand, off hand, and stance weapon all sheathed/strapped on belt/back.

- **Idle (in combat)** [auto] — player stationary, grounded, combat timer active;
  main and off hand weapons held at ready; style varies per weapon type
  (unarmed, sword, bow, pickaxe, dagger, etc.); stance weapon remains
  sheathed/strapped until the player activates it.

- **Idle (in water)** [auto] — player stationary, in water; buoyancy passively
  pushes player toward surface; no energy consumed.

---

## Resources

Amounts and rates defined in systems_design.md.

- **HP** [auto] — depleted by incoming damage; restored by regen and healing;
  zero triggers Faint. Regen requires out-of-combat and no recent damage.

- **Energy** [auto] — depleted by sprint, jump, and energy-costing abilities;
  restored by regen; zero prevents further energy use. Regen blocked while
  sprinting, jumping, in a stance, in combat, or grabbing.

- **Focus** [auto] — gained on landing a hit, crit, or receiving damage;
  passive gain while in combat; decays while out of combat.

- **Flow** [auto] — depleted by Resistance and flow-costing abilities;
  restored by regen; zero prevents further flow use.

---

## Movement

- **Walk** [input] — move keys; grounded; normal movement speed, camera-relative;
  soft-lock: target-relative.

  - **Water entry (walking)** [auto] — grounded, in water, ground contact lost to
    buoyancy; player begins swimming.

- **Sprint** [input] — move keys + sprint key; grounded; faster movement;
  drains energy while active.

- **Jump** [input] — interact key; grounded; launches player airborne; drains energy on use.

  - **Jump (ledge fall)** [auto] — player at ledge edge; falls freely; no energy cost.
    Five paths: walking perpendicular to ledge (from above), sprinting (any angle),
    carrying object (any angle), dodge, horizontal knockback (any angle).
    All governed by Ledge detection.

  - **Jump (knockback)** [auto] — hit with vertical force; launches player airborne;
    no energy cost.

  - **Water entry (airborne)** [auto] — airborne, water surface contact;
    movement switches from gravity-driven to water-driven;
    water resistance decelerates fall, buoyancy pushes toward surface,
    damage based on remaining velocity at bottom contact (deep water absorbs
    any fall, shallow water may not).

  - **Mid-air grab (climb)** [auto] — airborne, climbable surface contact,
    moving toward it, facing it; player latches onto surface; valid from any
    airborne source (jump, ledge fall, knockback, climb jump-off).

  - **Ledge detection** [auto] — player at ledge height within grab distance;
    grab or fall determined by approach angle and direction; sprinting, knockback,
    and carrying always fall freely regardless of angle (dodge: own rules apply).

    From below:
      Perpendicular to ledge → grabs
      Parallel to ledge → no grab

    From above:
      Parallel to ledge → grabs
      Perpendicular to ledge → falls freely

- **Dodge** [input] — cancel key + move direction; grounded, not in water;
  directional dodge, invincibility frames, ignores enemy collision;
  drains energy, short cooldown, some frames interruptible.

  - **Ledge interaction (dodge)** [auto] — player at ledge edge from above, mid-dodge;
    grabs or falls freely; grabs if movement parallel to ledge or dodge past midpoint.

- **Climb** [input] — move keys toward climbable surface; on climbable surface
  (ladders, vines, marked walls), grounded or hanging; player moves along surface;
  no energy regen while climbing. Traverse camera mode active.

  - **Climb: Drop** [input] — cancel key; on climbable surface; player releases
    and falls freely.

  - **Climb: Jump Off** [input] — interact key; on climbable surface; player
    jumps off perpendicular to surface outward; drains energy. Camera auto-orbits
    behind new facing direction; player cannot steer during orbit.

### Ledge Hang

Player hangs from a ledge edge by hands. Entry paths: Climb Down, jump, dodge, swim.
Traverse camera mode active.

  - **Climb Down** [input] — sprint key tap; player stationary or walking, at
    ledge edge; player lowers off ledge to hang.

  - **Ledge Hang (from jump)** [auto] — airborne, ledge grab conditions met
    (see Ledge detection); player latches onto ledge edge.

  - **Ledge Hang (from dodge)** [auto] — player at ledge edge mid-dodge, dodge
    ledge conditions met (see Ledge interaction (dodge)); player latches onto
    ledge edge.

  - **Ledge Hang (from swim)** [auto] — swimming at surface, ledge grab
    conditions met (see Ledge detection); player latches onto ledge edge.

  - **Hang: Sidle** [input] — move keys parallel to ledge; hanging; player
    slides along ledge edge.

  - **Hang: Pull Up** [input] — move keys toward ledge above; hanging; player
    pulls up onto ledge surface.

  - **Hang: Climb/Drop** [input] — move keys toward surface (opposite to facing);
    hanging; player climbs if climbable surface present, else releases and falls.

- **Swim** [input] — move keys; in water; player swims;
  drains energy while moving, free while stationary.

  - **Buoyancy** [auto] — in water; passive upward force always active;
    drifts toward surface when interact and move keys released.

  - **Breath** [auto] — submerged; O2 bar depletes; refills on surfacing.

  - **Drowning** [auto] — submerged, O2 empty; DOT damage until player
    surfaces or faints.

  - **Swim: Descend** [input] — interact key hold; swimming; player actively
    fights buoyancy to go deeper; buoyancy resumes on release.

  - **Water exit (swimming)** [auto] — swimming, in water, ground contact made;
    player resumes walking.

- **Sit** [input] — sit key tap; player stationary; player sits.

- **Stand Up (from sit)** [input] — sit key tap; player sitting; player stands.

- **Crouch** [input] — crouch key hold; player stationary or walking;
  reduced hitbox for narrow passages, slower movement, reduced creature
  detection range.

- **Stand Up (from crouch)** [input] — crouch key release; player crouching;
  player stands.

---

## Camera

Four **modes** govern player facing and camera position:

  **Free** (default): move keys alone; character faces movement direction;
  camera stays fixed.

  **Steering**: steer or pitch input active; player facing follows camera;
  movement not aligned with facing produces lateral movement. Transition
  from Free: player facing snaps to camera forward first.

  **Soft-lock**: overrides Free and Steering; see Targeting: Soft-lock.

  **Traverse**: player-driven left/right rotation suspended; camera tracks
  player facing automatically. On curved surfaces camera follows as
  facing rotates. Pitch and zoom remain available.

- **Steer** [input] — steer input; all camera modes; camera orbits player left/right.
  Free: player facing unchanged. Steering: player facing follows camera,
  underwater controls player up/down instead.
  Soft-lock: camera orbits target, player facing stays locked on target.

- **Pitch** [input] — pitch input; all camera modes; camera pitches up/down,
  no facing change. Underwater: pitch range relaxed.

- **Zoom** [input] — zoom input; all camera modes; camera zooms in/out.

- **Reset** [input] — reset input hold; not soft-locked; camera interpolates
  toward behind-player facing; release early: camera stays at position reached.

---

## Combat

### Attack

Two regular weapon slots and one stance slot:
  **Main hand slot** (main hand key) — primary weapon
  **Off hand slot** (off hand key) — secondary weapon or off-hand item
  **Stance slot** (stance key) — shield or staff; see Stance slot

Combo directions: left, up, right, down — mapped to combo keys, or
combo icons clicked directly on the hotbar.

- **Attack (basic)** [input] — weapon key press and release; main hand or
  off hand equipped; fires the basic strike for that slot.

- **Attack (auto-select)** [auto] — attack with no target; auto-selects
  nearest entity within attack range and facing direction and fires.

- **Attack (combo)** [input] — weapon key hold, combo key, release; main
  hand, off hand, or stance slot while held; fires the ability assigned
  to that combo key. Mouse: click combo icon directly — no hold required.

- **Parry** [auto] — player and creature melee attacks connect on the same
  frame; both attacks cancel; no damage taken or dealt by either side.

### Stance slot

Holds either a shield or a staff — never both. Equipping one replaces
the other and determines which defensive mechanic is active.
Entered from idle or walking only. Raising and lowering take time —
no protection until fully raised, movement locked during both phases,
knockback still applies. Directional — attacks outside the player's
facing arc bypass the stance entirely (full damage and knockback apply).
Successful defense halves knockback. While held: bonuses active, combos
available, half-speed walk allowed, regen blocked. Crit instantly breaks
the stance — full control returns immediately. Release deferred until
current action completes.

  - **Block** [input] — stance key; shield equipped; blocks incoming
    physical attacks while held; block chance roll, no energy cost —
    only active shield abilities cost energy.

  - **Resistance** [input] — stance key; staff equipped; resists incoming
    magical attacks while held; resistance chance roll, drains flow
    continuously.

### Targeting

**Target pool** — single unified list, always active. Threat state is the
primary sort; entity type (creature before NPC) is the tiebreak:
  Tier 1 — Hostile engaged    (creatures first, then NPCs)
  Tier 2 — Hostile unaware    (creatures first, then NPCs)
  Tier 3 — Neutral creatures
  Tier 4 — Neutral / friendly NPCs
Any neutral entity hit turns hostile, promoted to hostile engaged (tier 1) before
selection resolves. LMB click selects any entity directly, bypassing
cycle order. Lock state follows the current target's tier.
Tab cycling requires line of sight through world geometry; on-screen
targets are preferred first — falls back to full pool if none visible.

  - **Soft-lock** [auto] — target hostile and actively engaged (tier 1);
    camera tracks target, player faces target, movement becomes
    target-relative:

      Forward / stick up   = toward target
      Back / stick down    = away from target
      Left / right / stick = strafe around target

    Underwater: axes fully 3D — toward/away along player-to-target vector,
    left/right orbits target.

    Steering input: camera orbit only, player facing stays on target.

    Upgrade: if current target turns hostile and engages, auto-upgrades
    to soft-lock.

    Degrade: target exits tier 1, or player switches to tier 2/3/4 target;
    camera stops tracking, movement returns to camera-relative; target ring
    stays visible.

  - **Target snap** [auto] — player hits entity with no target selected;
    snaps to that entity.

  - **Target** [input] — target key; no target; selects nearest by priority.

  - **Next target** [input] — target key; target active; cycles forward, wraps.

  - **Prev target** [input] — prev target key; target active; cycles back, wraps.

  - **Deselect (menu key)** [input] — menu key; target active; full deselect;
    soft-lock drops, camera stops tracking, movement returns to camera-relative.

  - **Deselect (prev target)** [input] — prev target key; alone in pool;
    full deselect; soft-lock drops, camera stops tracking, movement returns
    to camera-relative.

  - **Auto-deselect** [auto] — target fainted or out of range; full deselect.

- **Receive damage** [auto] — hit by attack; checks in order: dodge i-frames
  (miss, DoT still ticks), passive resist (magical), active Resistance
  (magical), passive block (physical), active Block (physical), damage,
  crit, status effect; knockback and brief stagger on hit, ability not
  consumed on stagger.
  Horizontal knockback: force in hit direction, decays over time.
  Vertical knockback: upward force launches player airborne; no energy cost.

---

## Abilities

**Ability scope:**

  Single-target: fires at current target; caster must face target with
  clear line of sight; applies to all ability types. Player bears full
  responsibility for what they are targeting.

  AoE — Cone: fires in caster's facing direction; arc and range defined
  per ability.

  AoE — Radius (player-centered): fires centered on caster; no facing or
  line of sight required.

  AoE — Radius (chosen-center): player enters placement mode on ability
  activation; area indicator follows camera input; confirm fires, cancel
  aborts; center locked on confirm. Applies to all ability types — instant
  fires on confirm, castable begins casting bar after confirm, channeling
  begins channel after confirm.

**Ability types:**

  Instant: fires immediately; cannot be interrupted after firing.

  Castable: casting bar fills over time; cancel key, movement, or stun
  interrupts; knockback movement does not count; incoming damage reduces
  casting progress.

  Channeling: fires instantly then sustains over a fixed duration; some
  abilities require the player to be stationary, others allow movement;
  knockback does not count in either case; cancel key or stun interrupts;
  incoming damage reduces remaining channel duration.

### Mobility

- **Draw** [input] — weapon key + combo key; single-target, line of sight
  required; draws target toward player fast; physical or magical;
  range and secondary effects defined per ability.

- **Rush** [input] — weapon key + combo key; single-target, line of sight
  required; player rushes toward target closing distance rapidly; physical
  or magical; secondary effects defined per ability.

- **Step** [input] — weapon key + combo key; player moves instantly to a
  position; physical or magical; target position and direction defined per
  ability.

### Damage

- **Burst** [input] — weapon key + combo key; AoE radius (player-centered);
  deals damage to all entities in range; damage type and radius defined per
  ability.

- **Resonance** [input] — weapon key + combo key; single-target, line of
  sight required; delivers a Resonance-typed hit; physical or magical;
  element, damage, and secondary effect defined per ability.

- **Surge** [input] — weapon key + combo key; single-target, line of sight
  required; deals amplified damage with no secondary effect; physical or
  magical; damage multiplier defined per ability.

### Control

- **Disorient** [input] — weapon key + combo key; single-target, line of
  sight required; forces target into uncontrolled behavior; physical or
  magical; some variants break on damage; duration defined per ability.

- **Immobilize** [input] — weapon key + combo key; single-target, line of
  sight required; restricts target movement; physical or magical;
  duration defined per ability.
  Some variants break on incoming damage; whether target can still act
  while immobilized defined per ability.

- **Inflict** [input] — weapon key + combo key; single-target, line of sight
  required; applies a status effect to target; guaranteed or chance-based;
  effect type, application chance, and duration defined per ability.

- **Interrupt** [input] — weapon key + combo key; single-target, line of
  sight required; forces target to stop current action; physical or magical;
  may deal damage; interrupt window and damage defined per ability.

- **Knockback** [input] — weapon key + combo key; single-target or AoE
  (player-centered); deals damage and applies amplified knockback; larger
  force than a normal attack; force, damage, and scope defined per ability.

- **Silence** [input] — weapon key + combo key; single-target, line of sight
  required; prevents target from using abilities for a duration; physical
  or magical; duration defined per ability.

- **Slow** [input] — weapon key + combo key; single-target, line of sight
  required; reduces target movement speed; physical or magical; magnitude
  and duration defined per ability.

### Defensive

- **Barrier** [input] — weapon key + combo key; absorbs incoming damage up
  to a capacity; physical or magical; capacity and duration defined per
  ability.

- **Endure** [input] — weapon key + combo key; player takes near-zero
  damage for a brief window; duration defined per ability.

- **Reflect** [input] — weapon key + combo key; next hit aimed at player
  is returned to the attacker; physical or magical; reflect window defined
  per ability.

### Recovery

- **Cleanse** [input] — weapon key + combo key; self or single-target ally;
  ally requires line of sight; removes status effects; physical or magical;
  number of effects removed defined per ability.

- **Empower** [input] — weapon key + combo key; self or single-target ally;
  ally requires line of sight; temporarily increases a stat or grants a
  combat bonus; physical or magical; bonus type and duration defined per
  ability.

- **Heal** [input] — weapon key + combo key; self or single-target ally;
  ally requires line of sight; restores HP; amount defined per ability.

### Utility

- **Detect** [input] — weapon key + combo key; AoE radius (player-centered);
  reveals hidden enemies, traps, or items in range; physical or magical;
  radius and duration defined per ability.

- **Field** [input] — weapon key + combo key; AoE radius (chosen-center);
  places a persistent zone at the chosen location; physical or magical;
  zone effect, radius, and duration defined per ability.

- **Reveal** [input] — weapon key + combo key; single-target, line of sight
  required; removes stealth or invisibility from target; physical or
  magical; duration of prevent-restealth defined per ability.

- **Trap** [input] — weapon key + combo key; AoE radius (chosen-center);
  places a triggered mechanism at the chosen location; physical or magical;
  trigger condition, effect, and duration defined per ability.

- **Vanish** [input] — weapon key + combo key; player becomes invisible
  for a fixed duration; creatures lose player as a target.

---

## World Interaction

- **Grab** [input] — sprint key held; near object, facing arc met;
  player grabs object; no energy cost, regen stops while held;
  any incoming hit releases grab immediately.

  - **Push** [input] — move keys toward object; grab active; drives
    object away; object collision stops movement — energy drain continues
    while input held; small object: no energy cost; large object: costs
    energy per second — energy depleted reverts to grab idle.

  - **Pull** [input] — move keys away from object; grab active; drags
    object toward player; player collision behind stops movement — energy
    drain continues while input held; large object: costs energy per
    second — energy depleted reverts to grab idle; small object: player
    lifts and carries object.

  - **Hold (carry)** [auto] — small object grabbed, pull input; player
    carries object; reduced movement speed, regen stopped while carrying.

    - **Put Down** [input] — sprint key release; carrying, no movement
      input; player places object in front.

    - **Throw** [input] — sprint key release; carrying, movement input
      active; player throws object in facing direction; costs energy.

- **Loot** [input] — interact key; near body, no facing check required;
  opens loot window; multi-item drops show as list. Small single drops
  auto-collect on contact — see Acquire (auto).

- **Acquire (interact)** [input] — interact key; close proximity to item;
  player picks up item; item shown above head briefly.

- **Acquire (auto)** [auto] — player contacts item; item auto-collected;
  item shown above head briefly while player continues moving.

- **Boost item** [auto] — player contacts boost item; temporary stat boost
  applied; duration defined per item.

- **Open** [input] — interact key; near chest or container, facing
  required; object opens, contents revealed.

- **Cross** [input] — interact key; near door or passage, facing
  required; door opens, player passes through.

- **Talk** [input] — interact key; near NPC, facing required; opens dialogue;
  player turns toward NPC, input locked for duration.
  Camera repositions behind the NPC so the player is seen facing forward.
  No directional talk art needed. Camera moves smoothly into position.

---

## Equipment

Live overlay — semi-transparent, non-pausing; game continues while open.
Slot-to-slot navigation.

- **Inventory (toggle)** [input] — inventory key; opens or closes equipment
  overlay. Slot-based with category pouches (ammo, food, weapons, misc)
  and fixed equipment slots; pouch sizes upgradable.

- **Equip** [input] — navigate to item slot; equip or use depending on
  item type. Slots: main hand, off hand, stance (shield or staff),
  armor (head, chest, legs, feet, hands), accessories.

  Weapons fully visible on body. Armor shown as color and texture variation
  on existing body art — hood, chest piece, trousers, boots, gloves drawn
  over body. Underwear base layer present for wearable slot logic; not
  drawn separately. Appearance reflects equipped gear.

---

## Status Effects

- **Buff** [auto] — player or ally receives a temporary positive effect;
  shown as icon on HUD; duration defined per effect.

- **Debuff** [auto] — player receives a status effect from an enemy ability;
  guaranteed or chance-based depending on source; subject to resistance;
  duration defined per effect.

  - **Weather debuff** [auto] — player exposed to environmental hazard without
    appropriate gear; DOT applied by environment.

---

## Lifecycle

- **Spawn (silent)** [auto] — world transition (entering or exiting houses, dungeons,
  or area boundaries); player appears at destination without interruption.

- **Spawn (arrival)** [auto] — game start, load, teleport, or recover;
  brief invincibility period on arrival.

- **Faint** [auto] — HP reaches zero; durability lost; screen goes blank.

- **Recover** [auto] — player fainted, recover triggered; appears at last activated
  checkpoint; creatures in the area reset.

---

## Expressive

- **Bow** [auto] — quest completed; player bows briefly; control returns after.
