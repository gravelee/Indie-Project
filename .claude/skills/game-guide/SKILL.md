# Player Design — Ares

This document defines everything the player character can do.
It is the source of truth for player scope. Update it as decisions are locked.
Per-mechanic deep-dives will live in dedicated mechanic_*.md files (mechanic_locomotion.md,
mechanic_combat.md, etc.) linked from here as they are written.
Console portability is a hard constraint on every mechanic — every input must map to both
keyboard+mouse and a standard controller (Xbox/PS/Switch layout).

---

## Player Capabilities (Mechanics)

### Presence

- Idle (out of combat) — idle_neutral; main hand, off hand, and stance weapon
  all sheathed/strapped on belt/back

- Idle (in combat) — idle_attack; per main and off hand weapon style; main and
  off hand weapons held at ready; stance weapon remains sheathed/strapped until
  FSM activated (RAISING)
  NOTE: combat idle per main/off hand weapon style (unarmed, sword, bow,
  pickaxe, dagger, etc.)

- Idle (in water) — floating at surface; buoyancy holds player up passively;
  no energy consumed while idle. Stances active: buoyancy is a passive
  environmental force, not player movement — player counts as still for stance
  purposes.

### Locomotion

- Walk — normal movement speed, camera-relative move keys
  In soft-lock: movement axis switches to target-relative
  (see Movement in Soft-Lock Mode).

- Run / Sprint — faster movement; drains energy while active;
  hold sprint key (Shift / ZR)

- Jump — voluntary (Space / A button); drains energy on voluntary use only;
  auto-triggered by ledge falls and knockback (no energy cost)

  - Water entry: contact with water surface while airborne → enter Swim
    immediately; land animation skipped. Water resistance decelerates downward
    velocity — buoyancy pushes the player toward the surface. If velocity
    reaches zero before the bottom: no damage. If the player still has downward
    velocity on bottom contact: damage is applied based on the remaining
    velocity at impact. Deep water absorbs any fall; shallow water may not.
  
  - Mid-air grab (climb): fires while airborne (any source — voluntary jump,
    ledge fall, knockback, climb jump-off) on contact with a climbable surface,
    if all three conditions are true: (1) contact with climbable surface,
    (2) horizontal movement toward it (XZ ≠ 0), (3) player facing toward the
    surface. No button input required.
  
  - Ledge detection: fires when sprite top reaches ledge height within grab
    distance (→ mechanic_locomotion.md). The angle of approach
    (threshold → mechanic_locomotion.md) determines the outcome and inverts
    across the ledge height boundary (running, knockback, and carrying an
    object always fall freely; roll has its own A-or-B rule — see Roll / Dodge):

    From below (sprite top rising toward ledge height):
      Perpendicular to ledge → grabs (enters Ledge Hang)
      Parallel to ledge → no grab (moving alongside the wall, not seeking
      the ledge)

    From above (sprite top descending toward ledge height):
      Running / sprinting: always falls freely regardless of angle
      Knocked off (knockback): always falls freely regardless of angle
      Carrying an object: always falls freely regardless of angle
      Parallel to ledge → grabs (sliding off edge, hands catch;
      enters Ledge Hang)
      Perpendicular to ledge → falls freely

- Climb — specific climbable surfaces only (ladders, vines, marked walls)

  Camera: left/right rotation tracks player facing — camera always looks from
  behind the player's facing direction so the sprite stays parallel to the
  surface. On curved surfaces facing rotates as the player moves, camera
  follows. Pitch and zoom still available.

  Entry trigger: overlap with a climbable surface + move input toward it.
  Applies from ground approach (WALK / RUN) and from Ledge Hang — in Ledge
  Hang the player faces outward by default, so "move opposite to facing" equals
  "move toward the surface" and resolves to the same check. Climb Down alone
  does not enter Climb; the player must give an explicit move input while
  hanging. No energy regen while climbing.

  Exits:

  - F / B (Roll/Dodge) → drop; release surface, fall freely

  - Space / A (Jump) → jump off perpendicular to surface (outward);
    costs energy; enters JUMP.
    Player facing flips 180° immediately on jump-off (was facing wall, now
    faces outward). Camera auto-orbits to catch up behind the new facing —
    player cannot steer during this. Sprite transition during orbit:
    front (south) → side → back (north), always starting from front because
    the player faces outward the moment they leave the surface. Camera reaches
    its resting position (behind player) by the end of the orbit.

- Swim — surface swim and underwater movement; drains energy while actively
  moving. Idle float (no input, buoyancy holds player) costs no energy.

  Underwater: separate sub-state with an O2 bar; O2 depletes while submerged,
  refills on surfacing. When O2 reaches zero, DOT damage begins until the
  player surfaces or dies.

  Combat underwater: full combat allowed — same attack animations and abilities
  as on land. Stances work normally; buoyancy does not count as movement.

  Knockback underwater: same as on land but 3D — force applies in the full
  hit direction including vertical; buoyancy still acts on top.

  Buoyancy (underwater): a passive upward force always pushes the player
  slowly toward the surface — the same force that decelerates falling velocity
  on water entry. Releasing all inputs = player drifts up naturally.

  Space / A (underwater): hold to descend — actively fights buoyancy to go
  deeper; release = buoyancy resumes. Gives the player an explicit dive input
  without removing the natural float-up behavior.

  Camera (underwater): same three modes apply but with two differences —
  (1) vertical limits are relaxed (player can look further up and down than
  the on-land sprite constraint allows); (2) vertical input (RMB drag Y /
  right stick Y / Shift+- / Shift+=) no longer adjusts camera pitch only —
  it steers the player up or down, the same way horizontal input steers left
  or right. Movement becomes fully 3D: the player swims toward wherever the
  camera points, including vertically.

- Roll / Dodge — directional; invincibility frames during roll;
  ignores enemy collision capsule
  Drains energy on use. Short cooldown. Some frames may be interruptible
  (→ mechanic_locomotion.md).

  - Ledge interaction (roll from above): grabs ledge (enters Ledge Hang) if
    A or B is true; falls if both are false:
  
    A: movement angle is parallel to ledge
    B: roll is past a defined point in its animation (→ mechanic_locomotion.md)
  
    Either outcome: JUMP state entered immediately; roll animation plays to
    completion, then transitions to fall or land animation based on movement
    vector (or directly to idle if already grounded when animation finishes)

- Ledge Hang — shared state entered from Jump detection, Roll ledge
  interaction, or Climb Down:

  Camera: left/right rotation tracks player facing — camera always looks from
  behind the player's facing direction so the sprite stays parallel to the
  surface. On curved surfaces facing rotates as the player moves, camera
  follows. Pitch and zoom still available.

  - Move toward obstacle → pull-up animation → idle on top

  - Move parallel to ledge → sidle along edge

  - Move opposite to facing (= move toward surface) → if climbable surface
    present → enter Climb; else → release, fall → enter Jump

- Camera modes — three modes govern player facing and camera position:

  Free (default): move keys / left stick alone → character faces movement
  direction; camera stays fixed.

  Steering: Q/E tap / RMB drag X / right stick X → camera rotates left/right;
  player facing updates to new camera forward; camera ends up behind player.
  RMB drag Y / right stick Y / Shift+- / Shift+= → camera pitch up/down
  (no facing change). Underwater: steers player up/down instead.

  Soft-lock: camera tracks locked target regardless of input; overrides both
  Free and Steering. Steering inputs (Q/E / RMB / right stick X) revert to
  camera orbit only — player facing stays locked on target. Movement switches
  to target-relative axes (see Movement in Soft-Lock Mode). Cleared on target
  death, out of range, or manual unlock.
  Underwater (Soft-lock): movement axes become fully 3D — W/S along
  player→target vector; A/D perpendicular to it (orbits target). Pitch
  input remains camera orbit only. Buoyancy still acts.

  Underwater (all modes): vertical pitch limits relaxed.

  Free → steering transition: camera stays fixed; player facing snaps to
  current camera forward first, then steering takes over.

  Steering animation: movement not aligned with player facing plays strafe
  animations (same set as soft-lock).

  Exception — Climb / Ledge Hang: all three modes suspend player-driven
  left/right rotation input; camera left/right rotation instead tracks player
  facing automatically. On curved surfaces facing rotates as the player moves,
  camera follows. Pitch and zoom remain available.

### Combat

- Attack — hold-and-combo input system; 3 weapon slots each with 5 abilities:

  Basic attack: press weapon key → release immediately → fires basic strike
  (weapon-specific, always available)

  Combo ability: press weapon key → hold → add a combo key direction →
  release → fires that ability

  Slots: main hand (Y / key 1), off hand (X / key 2),
  stance slot — shield or staff (ZL / §)
  Combo keys give 4 combo abilities per slot. Basic attack = no combo key.
  Two-handed weapon occupies both main and off hand slots.
  Abilities are acquired through gameplay and assigned to slots via the
  weapon ability book.
  Mouse players can click ability icons directly on the visual hotbar.

  AoE attacks: cone or radius defined per ability. Single-target: range + target.
  Cannot interrupt a swing mid-animation — no other action activates while
  an attack animation is playing.

- Shield — defensive weapon; occupies the stance slot (ZL / §)
  Equipping a shield enables the Block mechanic. A player equips either a
  shield or a staff — never both.

- Block — shield (stance slot);
  press = RAISING, hold = HOLDING (Block stance active), release = LOWERING
  Block chance roll against incoming physical attacks;
  directional arc (±60° default); crit-forced drop.
  Half-speed walk allowed in HOLDING. Shield combos fire from HOLDING state,
  return to HOLDING after.

  ZL/§ release during combo animation: deferred — LOWERING starts only after
  combo animation completes.

- Staff — spellcaster's primary weapon; occupies the stance slot (ZL / §)
  Equipping a staff replaces the Block mechanic with Resistance in the
  stance slot.

- Resistance — staff (stance slot);
  press = RAISING, hold = HOLDING (Resistance stance active), release = LOWERING
  Resistance chance roll against incoming magical attacks (same mechanic as
  Block for physical); directional arc (±60° default); crit-forced drop.
  Half-speed walk allowed in HOLDING. Being in HOLDING drains flow (the
  spellcaster resource) continuously.
  Spell combos fire from HOLDING state, return to HOLDING after.
  ZL/§ release during spell animation: deferred — LOWERING starts only after
  spell animation completes.

- Target — two states driven by combat:

  Target selection (out of combat): visual ring; HP bar; camera free.

  Soft-lock (in combat): camera tracks; movement axes target-relative
  (move keys: toward / away / strafe).

  Combat entry: selection auto-upgrades to soft-lock.

  Combat exit: soft-lock degrades to selection (target kept).
  All target keys + LMB click creature work in both states; lock state
  is driven by combat, not by input.
  Auto-target on hit / on receive.

  Two-tier cycling: on-screen nearest first, then off-screen.

  Select (no target): Tab (keyboard) / LMB click creature (mouse) /
  R (controller).

  Switch next (target active): Tab (keyboard) / R (controller).
  Wraps; lock state unchanged.

  Switch prev (target active): Shift+Tab (keyboard) / L (controller).
  Wraps backwards; deselects when alone.

  Deselect: Esc / Shift+Tab when alone (keyboard) / LMB on empty space
  (mouse) / Start / L when alone (controller).

  Auto-deselect: target death / moving out of range.

- Receive damage — knockback, hit flash, stagger state
  (brief interrupt; ability not consumed on stagger)
  Knockback does not instantly interrupt active abilities — stagger state is
  separate and brief.

### World Interaction

- Grab — latch onto a large pushable object
  (Shift / ZR held near object + facing arc);
  no energy cost but stops regen while held

- Push — drive object away from player (input toward object while in GRAB);
  costs energy per second

- Pull — drag object toward player (input away from object while in GRAB);
  costs energy per second; slower than push

- Hold (carry) — pick up a small object;
  same button as Grab (Shift / ZR), context determines small vs large

  Entry: Shift / ZR held near small object + facing arc → CARRY_IDLE
  Shift / ZR held + movement input → CARRY_MOVE (reduced speed while carrying)

  Exit — put down: release Shift / ZR with no movement input →
  place object in front of player

  Exit — throw: release Shift / ZR with movement input →
  throw toward current facing direction
  No regen while in CARRY_IDLE or CARRY_MOVE. Energy cost on throw only.

- Climb Down — manually lower off a ledge edge to hang and sidle
  (Shift / ZR tap near ledge edge)
  Available in IDLE, WALK. Not available while running (sprint hold conflicts
  with tap), carrying, attacking, in a stance, airborne, or knocked back.
  Once hanging, see Ledge Hang.

- Loot — open loot window on corpse (Space / A or RMB tap; proximity only,
  no facing check) → popup inventory list (WoW style for multi-item drops)
  Small single drops (coins, herbs) pop out Zelda-style and
  auto-collect on contact.

- Open — interact with chest/door/container (Space / A; facing + in range) →
  animation + item reveal fanfare

- Talk — approach NPC + interact button (Space / A; facing + in range) →
  dialogue box; player plays talk animation

### Equipment & Inventory

- Equip — weapon_main, weapon_off, weapon_stance (shield or staff),
  armor slots (head, chest, legs, feet, hands), accessories

  Visible layers: weapons fully shown (sprite layers above/below body).

  Armor: color/texture variation on existing body sprite (hood, chest piece,
  trousers, boots, gloves drawn over body).
  Underwear/base layer exists but not separately drawn — weather/environment
  effects use wearable slot logic without requiring new sprite art.

  Shield and staff: stance-based animation layers drawn separately
  (RAISING / HOLDING / LOWERING frames).

  Main and off hand weapons: attack animations baked per weapon type,
  no stance layer.

- Dress — armor and weapon appearance changes through quest rewards;
  not pure cosmetic fluff

- Inventory — slot-based with category pouches (ammo, food, weapons, misc)
  + fixed equipment slots
  Upgradable pouch sizes. Fully navigable without drag-and-drop
  (keyboard, controller, and mouse all supported).
  
  Inspired by: WoW slot logic + BOTW pouch structure + Mina limitations.

- Acquire — item pickup from world; small items auto-collect or play
  pickup animation

### Status & Stats

- Stats — full system (STR, AGI, STA, INT, SPR, RES, DEF, BMS + derived)

- Buffs — temporary positive effects; shown as icons on HUD

- Debuffs — buildup-meter system (Dark Souls style): each effect has a 0–100
  meter that fills on repeated hits, decays slowly when source stops.
  Triggers at 100. Meter resets after trigger.

  Effects: poison (DOT), bleed (instant % HP), stun (brief lock),
  burn (DOT+visual), slow (mspd down), frost.

  Weather debuffs: cold area without warm clothing → slow DOT from environment
  (via wearable slot check, no new sprites needed).

### Lifecycle

- Spawn — enter world at checkpoint; brief invincibility

- Die — death state; lose durability on weapons and stance slot item
  (shield or staff); armor unaffected; collision disabled
  Insta-revive: one-use item with cooldown (Mipha's Grace style).
  Revives on the spot at low HP.
  Checkpoint respawn: appear at last bonfire/checkpoint after delay.
  Ghost realm: [DESIGN ONLY — not Year 1] after death, Ares's ghost can
  briefly walk back to body; used for specific story moments (ghost NPC
  encounters, lore hints before boss rematch).
  Creature respawn: all creatures respawn when Ares dies and respawns at
  checkpoint.

- Respawn — at last activated checkpoint (bonfire-style);
  creatures in the area reset

### Expressive

- Bow — NPC interaction trigger; also player-initiated emote

- Sit down / Stand up — player-initiated; doubles regen rates while seated
  (like eating in WoW)

- Talk animation — triggered during NPC dialogue; body/head turns toward NPC

### Abilities

- Power up — dedicated animation signals entry into a charged/buffed state;
  may be how a buff is cast

- Smokescreen — escape/stealth ability; dedicated smoke_screen animation;
  creatures lose player target

- Others — defined per playstyle and talent tree; each ability defines:
  hit_frame, AoE type, resource cost, animation

---

## Year 1 Scope (locked)

All of the above are Year 1 targets EXCEPT:

- Ghost realm mechanic (design only, not implemented)

---

## Input Modes

Three valid play styles — all fully supported:

- **Keyboard only**: WASD / arrows + Q/E + keys. Default top-down pitch (-40°, full
  zoom out) for a retro/GameBoy feel; pitch and zoom still adjustable.
  Q/E step-rotate camera; player facing updates to new camera forward.

- **Keyboard + Mouse**: WASD / arrows + RMB to steer + scroll to zoom.
  Full 3D third-person.

- **Controller**: left stick + right stick to steer. Full 3D third-person.

## Movement in Soft-Lock Mode

Only applies in soft-lock state (in combat). Target selection (out of combat)
does not affect movement axes.

When soft-locked: player always faces target. Movement axis switches from
camera-relative to target-relative:

- W / up arrow / left stick up             = move toward target
- S / down arrow / left stick down         = move away from target
- A / left arrow / D / right arrow / stick = strafe left / right

Steering inputs (RMB / right stick X / Q/E) revert to camera orbit only
while locked — player facing stays on target.

Transitions (all smooth, no snapping):

- Combat exit (creature retreats, timer expires): soft-lock degrades to
  target selection; camera stops tracking; movement axes return to
  camera-relative. Target ring stays visible.

- Target lost (death, out of range): full deselect; camera stops tracking;
  movement axes return to camera-relative.

- Target cycle (Tab/Shift+Tab or R/L buttons): camera interpolates from old
  target to new; ring fades out/in

- Weapon key held during soft-lock: combo keys fire ability combos, movement
  input ignored until weapon key released

## Named Button Groups

Used throughout this document to describe input intent without tying to a
specific platform.

| Name          | Keyboard                | Controller         | Purpose                    |
|---------------|-------------------------|--------------------|----------------------------|
| Move keys     | WASD / arrows           | Left stick         | Character movement         |
| Weapon keys   | § / 1 / 2               | ZL / Y / X         | Activate slot; hold=ability|
| Combo keys    | Q / W / E / R           | D-pad (wpn held)   | Ability direction          |
| Camera keys   | Q/E / -/= / Shift+-/+=  | Right stick/L3/R3/L| Steer/pitch/zoom/reset     |
| Target keys   | Tab / Shift+Tab         | R / L              | Select, cycle, deselect    |
| Item keys     | Z / X / C / V           | D-pad (no wpn)     | Use consumables            |

Note: combo keys and camera keys share Q/E on keyboard — weapon key held
determines which role applies (see context rules). D-pad on controller is
combo keys when a weapon key is held, item keys otherwise.

R key (keyboard): combo direction (down) when weapon key held (§/1/2);
no function otherwise.

Target keys: selection out of combat; soft-lock in combat (auto-driven by
combat state, not by the key pressed).

L (controller): listed under Target keys but also functions as camera reset
(hold, when not soft-locked) — hence also appears in Camera keys above.

## Console Mapping Reference

KB = keyboard-only. Mouse = mouse-specific only (KB inputs also apply in
KB+mouse mode).

**Move**
  KB: WASD / arrows | Mouse: LMB+RMB held (W key-equivalent) | Controller: Left stick
  Move character — WASD / arrows / left stick follow the camera rig's left/right angle
  on the ground plane.
  Soft-lock: axes follow player→target direction (move keys: toward / away / strafe).

**Steer / Mouse look**
  KB: Q / E (step) | Mouse: RMB drag X (analog) | Controller: Right stick X
  Camera rotates; player facing updates to new camera forward.
  Soft-lock: camera orbit only, no facing update.
  Underwater: sets the horizontal swim direction; vertical component driven by
  pitch input.
  Q/E: weapon key held → ability combo instead.

**Camera pitch**
  KB: Shift+- / Shift+= (step) | Mouse: RMB drag Y | Controller: Right stick Y
  Hard clamp -15° to -40° (sprite constraint).
  Underwater: limits relaxed; input steers player up/down instead.

**Camera zoom**
  KB: - / = (step) | Mouse: Scroll wheel | Controller: L3 out / R3 in (step)

**Camera reset**
  Mouse: Middle mouse hold | Controller: L hold (when not soft-locked)
  KB: no equivalent (Q/E step-steer serves this role).
  Hold: camera interpolates toward behind player facing.
  Release before complete: camera stays at position reached.

**Jump / Descend / Climb exit / Open / Talk / Loot**
  KB: Space | Controller: A
  Priority: (1) near corpse → loot (proximity only; no facing check);
  (2) facing NPC or interactable + in range → talk / open;
  (3) in Climb → jump off perpendicular (costs energy);
  (4) underwater → hold to descend (fights buoyancy); (5) default → jump.

**Loot**
  KB: Space | Mouse: RMB tap near corpse | Controller: A
  Proximity only; no facing check.

**Roll / Dodge**
  KB: F + movement dir | Controller: B + left stick dir
  No movement input = no roll.
  In Climb: B / F alone → drop (no movement required).

**Stance slot**
  KB: § | Controller: ZL
  press = RAISING; hold = Block (shield) or Resistance (staff);
  release = LOWERING.

**Stance combos**
  Requires HOLDING state (§ / ZL held through animation).
  KB: + Q/W/E/R → release = fires |
  Mouse: + LMB click combo icon → release = fires |
  Controller: + D-pad → release = fires
  ZL/§ release deferred if ability/spell in progress.
  All combos shown individually in hotbar.

**Main hand slot**
  KB: 1 | Mouse: LMB click hotbar slot 1 | Controller: Y
  Release = basic attack.

**Main hand combos**
  KB: 1 held + Q/W/E/R → release = fires | Mouse: LMB click combo icon (no hold needed) |
  Controller: Y held + D-pad → release = fires
  Weapon key held = ability mode; all combos shown individually in hotbar.

**Off hand slot**
  KB: 2 | Mouse: LMB click hotbar slot 2 | Controller: X
  Release = basic attack.

**Off hand combos**
  KB: 2 held + Q/W/E/R → release = fires | Mouse: LMB click combo icon (no hold needed) |
  Controller: X held + D-pad → release = fires
  Weapon key held = ability mode; all combos shown individually in hotbar.

**Target / Soft-lock**
  KB: Tab | Mouse: LMB click creature | Controller: R
  Out of combat: selects target (camera free).
  In combat: soft-locks target (camera tracks).

**Switch target next**
  KB: Tab (target active) | Controller: R (target active)
  Wraps; lock state unchanged.

**Switch target prev**
  KB: Shift+Tab (target active) | Controller: L (target active)
  Wraps backwards; deselects when alone.

**Deselect target**
  KB: Esc | Mouse: LMB on empty space | Controller: Start
  Controller: L (when alone — last remaining target only).
  Also auto-deselects: target death / moving out of range.
  Esc / Start with no target active: see Pause / menu.

**Sprint**
  KB: Shift hold (default) | Controller: ZR hold (default)

**Grab / Carry**
  KB: Shift hold (near object) | Controller: ZR hold (near object)
  Large obj in reach + facing arc → grab; small obj → carry.

**Climb Down**
  KB: Shift tap (near ledge edge) | Controller: ZR tap (near ledge edge)
  Valid states: IDLE, WALK.
  Blocked during: run, carry, attack, stance, air, knockback.

**Item quick slots**
  KB: Z X C V | Mouse: LMB click consumable icon | Controller: D-pad (no weapon held)
  Immediately uses the consumable assigned to that slot.
  D-pad: weapon held = ability, else items.

**Pause / menu**
  KB: Esc | Controller: Start
  If target active (selected or locked): clears target only.
  No target: opens menu.

Context rules (in priority order):

Q / W / E / R (keyboard):
  1. Weapon key held (§/1/2) → ability combo direction
     (Q=left, W=up, E=right, R=down)
  2. Default (no weapon key held): Q/E → step-rotate camera and steer player
     (player facing updates to new camera forward); W → forward movement;
     R → no function.
     Soft-locked: Q/E → camera orbit only (facing stays on target).
     Underwater: Q/E sets horizontal swim direction; vertical component
     driven by pitch input.

Shift+- / Shift+= (keyboard) / Right stick Y (controller):
  1. Default → camera pitch up/down
  2. Underwater → steer player up/down instead

§ (keyboard) / ZL (controller):
  1. Press → RAISING
  2. Hold → HOLDING (Block if shield; Resistance if staff)
  3. Release → LOWERING

Tab / R (keyboard / controller):
  1. No target → select nearest (out of combat) / soft-lock nearest (in combat)
  2. Target active → cycle to next (lock state unchanged; wraps)

Shift+Tab (keyboard) / L (controller):
  1. Target active → cycle to prev (lock state unchanged; wraps)
  2. Alone (no other target) → deselect

L (controller):
  1. Target active → cycle to prev (lock state unchanged; wraps)
  2. Alone (no other target) → deselect
  3. Not soft-locked + hold → camera reset

F / B (keyboard / controller):
  1. In Climb → drop (no movement required)
  2. Default + movement direction → roll / dodge

LMB+RMB (mouse):
  1. Both held → move forward (W key-equivalent)

LMB (mouse):
  1. Click creature → select (out of combat) / soft-lock (in combat)
  2. Click empty space (target active) → deselect
  3. Click main/off hand hotbar icon → basic attack (no weapon key hold needed)
  4. Click combo hotbar icon → fires combo (stance combos require § / ZL held)
  5. Click consumable icon → use consumable in that slot

Middle mouse (mouse):
  1. Hold (not soft-locked) → camera reset (interpolates; release = stays)

RMB (mouse):
  1. Near corpse + tap (no drag) → loot
  2. Drag X → steer (player facing + camera follows)
  3. Drag Y → camera pitch. Underwater: steers player up/down instead

Space (keyboard) / A (controller):
  1. Near corpse → loot
  2. Facing NPC or interactable (chest, door) + in range → talk or open
  3. In Climb → jump off perpendicular to surface (costs energy)
  4. Underwater → hold to descend (fights buoyancy)
  5. Default → jump

Shift (keyboard) / ZR (controller):
  1. Near large object + facing arc + hold → grab
  2. Near small object + facing arc + hold → carry
  3. Near ledge edge + valid state + tap → climb down
  4. Default + hold → sprint

D-pad (controller):
  1. Weapon key held (ZL/Y/X) → ability combo direction
  2. Default → use consumable in that slot

Esc (keyboard) / Start (controller):
  1. Target active (selected or locked) → deselect
  2. Default → open menu
