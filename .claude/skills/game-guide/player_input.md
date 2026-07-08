---
name: Player Input Reference
description: Control scheme — bindings, shared key priority, mechanic map
type: reference
---

# Player Input — Ares

**See also**: player_mechanic.md (mechanic behavior), SKILL.md (hub)

* Shared key — same physical key fires different mechanics depending on player
state. Conflict resolution order listed in Shared Key Priority. Context-only
variation (toggles, modified behavior) does not require a priority entry.
** Same physical button reused across non-overlapping screens or modes.

---

## Contents

**Generic Names** — platform-independent action names; use in all design documents
**Controller Button Equivalents** — maps role names to Switch / Xbox / PlayStation buttons
**Input Modes** — keyboard-only, keyboard+mouse, and controller behavior descriptions
**Control Scheme** — full binding table: action × input mode
**Shared Key Priority** — conflict resolution order for keys marked *
**Mechanic Map** — every mechanic cross-referenced to its input action and trigger condition

---

## Generic Names

Platform-independent names used throughout all design documents to describe
inputs. Any document referencing player input must use these names — never
raw key names — so a rebind only requires updating this file.

| Generic Name      | Keyboard          | Mouse                    | Controller               |
|-------------------|-------------------|--------------------------|--------------------------|
| **Movement**      |                   |                          |                          |
| move keys         | WASD / arrows     | LMB+RMB held             | Left stick               |
| sprint key *      | Shift             | —                        | Right trigger            |
| sit key           | Ctrl              | —                        | Bottom face btn          |
| crouch key        | Ctrl hold         | —                        | Bottom face btn hold     |
| **Camera**        |                   |                          |                          |
| steer input *     | Q / E             | RMB drag X               | Right stick X            |
| pitch input       | Shift+- / Shift+= | RMB drag Y               | Right stick Y            |
| zoom input        | - / =             | Scroll                   | Left / Right stick click |
| reset key *       | F hold            | Middle mouse hold        | Left bumper hold         |
| **World Interaction** |               |                          |                          |
| interact key *    | Space             | RMB tap interactable     | Right face btn           |
| cancel key *      | F                 | —                        | Bottom face btn          |
| **Combat**        |                   |                          |                          |
| stance key        | §                 | —                        | Left trigger             |
| main hand key     | 1                 | LMB click main hand slot | Left face btn            |
| off hand key      | 2                 | LMB click off hand slot  | Top face btn             |
| combo keys **     | Q / W / E / R     | LMB click combo slot     | D-pad                    |
| weapon key        | 1 / 2 / §         | —                        | Left/Top face, L-trigger |
| **Targeting**     |                   |                          |                          |
| target key *      | Tab               | LMB click entity         | Right bumper             |
| prev target key * | Shift+Tab         | —                        | Left bumper              |
| **UI**            |                   |                          |                          |
| item keys **      | Z / X / C / V     | LMB click item slot      | D-pad                    |
| inventory key     | I                 | —                        | Select btn               |
| menu key *        | Esc               | —                        | Menu/pause               |

---

## Controller Button Equivalents

Maps each role name used in the Generic Names table to its
platform-specific button name:

| Role              | Switch      | Xbox        | PlayStation  |
|-------------------|-------------|-------------|--------------|
| **Face Buttons**  |             |             |              |
| Bottom face btn   | B           | A           | Cross ✕      |
| Right face btn    | A           | B           | Circle ○     |
| Top face btn      | X           | Y           | Triangle △   |
| Left face btn     | Y           | X           | Square □     |
| **Triggers**      |             |             |              |
| Left trigger      | ZL          | LT          | L2           |
| Right trigger     | ZR          | RT          | R2           |
| **Bumpers**       |             |             |              |
| Left bumper       | L           | LB          | L1           |
| Right bumper      | R           | RB          | R1           |
| **Sticks**        |             |             |              |
| Left stick        | Left stick  | Left stick  | Left stick   |
| Right stick       | Right stick | Right stick | Right stick  |
| Left stick click  | L3          | L3          | L3           |
| Right stick click | R3          | R3          | R3           |
| **Other**         |             |             |              |
| Menu/pause        | Start (+)   | Menu        | Options      |
| Select btn        | — (Minus)   | View        | Create/Share |
| D-pad             | D-pad       | D-pad       | D-pad        |

<!-- TODO: controller layout diagram — Switch, Xbox, PS — with action
     labels on each button. Place images in assets/ subfolder and
     reference here. -->

<!-- TODO: keyboard layout diagram — QWERTY with key roles highlighted
     (move zone, camera zone, weapon zone, etc.). -->

---

## Input Modes

These modes are proposals, not exclusive configurations. The game accepts all
inputs simultaneously based on available hardware — a player with a mouse and
keyboard uses both at once. A/D are always strafe (camera-relative) in all
modes; player rotation is not supported by design.

Keyboard only: WASD / arrows to move, Q/E to rotate camera — player movement
direction follows. Shift+-/= to pitch, =/- to zoom. Default pitch leans
top-down for a retro feel — camera is fully adjustable.

Keyboard + Mouse: WASD / arrows or LMB+RMB held to move, RMB drag left/right
to rotate camera — player movement direction follows, RMB drag up/down to
pitch, scroll to zoom. Full 3D third-person with fluid mouse camera.

Controller: Left stick to move, right stick left/right to rotate camera —
player movement direction follows, right stick up/down to pitch.
Full 3D third-person.

---

## Control Scheme

Full binding table — one row per player action, one column per input mode.
Keys marked * in Generic Names appear across multiple rows because the same
physical key resolves to different actions based on player state and conditions.
See Shared Key Priority below for explicit resolution order.

| Action              | Keyboard             | Mouse                    | Controller               |
|---------------------|----------------------|--------------------------|--------------------------|
| **Movement**        |                      |                          |                          |
| Move                | WASD / arrows        | LMB+RMB held             | Left stick               |
| Sprint              | Shift hold           | —                        | Right trigger hold       |
| Jump                | Space                | —                        | Right face btn           |
| Dodge               | F + Move dir         | —                        | Bottom face + Stick dir  |
| Climb Down          | Shift tap            | —                        | Right trigger tap        |
| Climb: Drop         | F                    | —                        | Bottom face btn          |
| Climb: Jump Off     | Space                | —                        | Right face btn           |
| Swim: Descend       | Space hold           | —                        | Right face btn hold      |
| Sit / Stand Up      | Ctrl                 | —                        | Bottom face btn          |
| Crouch / Stand Up   | Ctrl hold            | —                        | Bottom face btn hold     |
| Hang: Sidle         | Move (parallel)      | —                        | Left stick (parallel)    |
| Hang: Pull Up       | Move (toward)        | —                        | Left stick (toward)      |
| Hang: Climb/Drop    | Move (to wall)       | —                        | Left stick (to wall)     |
| **Camera**          |                      |                          |                          |
| Steer               | Q / E                | RMB drag X               | Right stick X            |
| Pitch               | Shift+- / Shift+=    | RMB drag Y               | Right stick Y            |
| Zoom                | - / =                | Scroll                   | Left / Right stick click |
| Reset               | F hold               | Middle mouse hold        | Left bumper hold         |
| **Combat**          |                      |                          |                          |
| Stance slot         | §                    | —                        | Left trigger             |
| Stance combos       | § held + Q/W/E/R     | LMB click combo icon     | Left trigger held+D-pad  |
| Main hand           | 1                    | LMB click main hand slot | Left face btn            |
| Main hand combos    | 1 held + Q/W/E/R     | LMB click combo icon     | Left face btn held+D-pad |
| Off hand            | 2                    | LMB click off hand slot  | Top face btn             |
| Off hand combos     | 2 held + Q/W/E/R     | LMB click combo icon     | Top face btn held+D-pad  |
| **Targeting**       |                      |                          |                          |
| Target / Next       | Tab                  | LMB click entity         | Right bumper             |
| Prev target         | Shift+Tab            | —                        | Left bumper              |
| Deselect            | Esc / Shift+Tab      | LMB on empty space       | Menu / Left bumper       |
| **W. Interaction**  |                      |                          |                          |
| Grab                | Shift hold           | —                        | Right trigger hold       |
| Push                | Move toward          | —                        | Left stick toward        |
| Pull                | Move away            | —                        | Left stick away          |
| Put Down            | Shift release        | —                        | Right trigger release    |
| Throw               | Shift release + Move | —                        | Release trigger + Stick  |
| Loot                | Space                | RMB tap                  | Right face btn           |
| Acquire (interact)  | Space                | RMB tap                  | Right face btn           |
| Open / Cross / Talk | Space                | RMB tap                  | Right face btn           |
| **Equipment**       |                      |                          |                          |
| Inventory           | I                    | —                        | Select btn               |
| **UI**              |                      |                          |                          |
| Item slots          | Z / X / C / V        | LMB click item slot      | D-pad                    |
| Menu/pause          | Esc                  | —                        | Menu/pause               |

---

## Shared Key Priority

When a generic key marked * resolves to more than one action, the first
matching condition wins. Evaluated top to bottom on every input event before
dispatching.

### sprint key  (Shift — keyboard / Right trigger — controller)

1. Tap + at ledge edge, stationary or walking    → Climb Down
2. Hold + near object, facing                    → Grab
3. Hold (default)                                → Sprint

### interact key  (Space — keyboard / Right face btn — controller)

1. On climbable surface                          → Climb: Jump Off
2. Hold + underwater                             → Swim: Descend
3. Near body                                     → Loot
4. Near chest or container, facing               → Open
5. Near door or passage, facing                  → Cross
6. Near NPC, facing                              → Talk
7. Near item, no higher priority                 → Acquire (interact)
8. Grounded (default)                            → Jump

### cancel / reset key  (F — keyboard)

On keyboard F is shared between three roles. On controller these are separate
physical buttons (Bottom face btn = cancel; Left bumper = reset) so no
priority needed there — the game resolves them naturally.

1. On climbable surface                          → Climb: Drop
2. + move direction                              → Dodge
3. Hold, not soft-locked (default)               → Reset camera

### steer / combo keys  (Q / E — steer; Q / W / E / R — combos)

1. Weapon key held                               → Combo direction (all 4 keys active)
2. Default                                       → Steer camera (Q = left, E = right only)

### target / prev target / menu key

1. target key, no target                         → Target (nearest)
2. target key, target active                     → Next target
3. prev target key, pool > 1                     → Prev target
4. prev target key, alone in pool                → Deselect
5. menu key, target active                       → Deselect
6. menu key, no target                           → Menu / pause

---

## Mechanic Map

Maps each mechanic (player_mechanic.md) to the input action that triggers it.
[auto] entries have no dedicated input — condition listed in Active when column.

| Mechanic                   | Input action                | Active when                           |
|----------------------------|-----------------------------|---------------------------------------|
| **Presence**               |                             |                                       |
| Idle (out of combat)       | — [auto]                    | no combat timer, grounded             |
| Idle (in combat)           | — [auto]                    | combat timer active                   |
| Idle (in water)            | — [auto]                    | in water, no move input               |
| **Movement**               |                             |                                       |
| Walk                       | Move                        | grounded, no sprint key               |
| Sprint                     | Move + Sprint               | grounded, sprint held                 |
| Jump                       | Jump                        | grounded                              |
| Jump (ledge fall)          | — [auto]                    | ledge edge reached                    |
| Jump (knockback)           | — [auto]                    | hit with vertical force               |
| Water entry (airborne)     | — [auto]                    | airborne + water contact              |
| Mid-air grab (climb)       | — [auto]                    | airborne + climbable; facing toward   |
| Ledge detection            | — [auto]                    | at ledge height within grab distance  |
| Dodge                      | Dodge                       | grounded + move dir, not in water     |
| Ledge interaction (dodge)  | — [auto]                    | mid-dodge, at ledge edge from above   |
| Climb Down                 | Climb Down                  | stationary or walking, at ledge edge  |
| Ledge Hang (from jump)     | — [auto]                    | airborne + grab conditions met        |
| Ledge Hang (from dodge)    | — [auto]                    | dodge + ledge conditions met          |
| Ledge Hang (from swim)     | — [auto]                    | swimming at surface, ledge grab met   |
| Climb                      | Move (toward climbable)     | grounded or hanging, climbable surface|
| Climb: Drop                | Climb: Drop                 | on climbable surface                  |
| Climb: Jump Off            | Climb: Jump Off             | on climbable surface                  |
| Swim                       | Move                        | in water                              |
| Buoyancy                   | — [auto]                    | in water                              |
| Breath                     | — [auto]                    | submerged                             |
| Drowning                   | — [auto]                    | submerged, O2 empty                   |
| Swim: Descend              | Swim: Descend               | swimming                              |
| Water entry (walking)      | — [auto]                    | grounded, move keys into water        |
| Water exit (swimming)      | — [auto]                    | swimming, ground contact made         |
| Sit                        | Sit / Stand Up              | idle                                  |
| Stand Up (from sit)        | Sit / Stand Up              | sitting                               |
| Crouch                     | Crouch / Stand Up           | idle or walking                       |
| Stand Up (from crouch)     | Crouch / Stand Up (release) | crouching                             |
| Hang: Sidle                | Move (parallel)             | hanging                               |
| Hang: Pull Up              | Move (toward)               | hanging                               |
| Hang: Climb/Drop           | Move (to wall)              | hanging                               |
| **Camera**                 |                             |                                       |
| Steer                      | Steer                       | not in Traverse mode                  |
| Pitch                      | Pitch                       | —                                     |
| Zoom                       | Zoom                        | —                                     |
| Reset                      | Reset                       | not soft-locked                       |
| **Combat**                 |                             |                                       |
| Attack (basic)             | Main hand / Off hand        | press + release                       |
| Attack (auto-select)       | — [auto]                    | attack with no target                 |
| Attack (combo)             | Main / Off / Stance combos  | hold + combo key                      |
| Parry                      | — [auto]                    | both melee attacks connect same frame |
| Block                      | Stance slot                 | shield equipped; hold                 |
| Resistance                 | Stance slot                 | staff equipped; hold                  |
| Soft-lock                  | — [auto]                    | target enters tier 1 engagement       |
| Target snap                | — [auto]                    | hit entity with no target selected    |
| Target                     | Target / next               | no target                             |
| Next target                | Target / next               | target active                         |
| Prev target                | prev target key             | target active                         |
| Deselect (menu key)        | menu key                    | target active                         |
| Deselect (prev target)     | prev target key             | alone in pool                         |
| Auto-deselect              | — [auto]                    | target fainted or out of range        |
| Receive damage             | — [auto]                    | hit by attack                         |
| **Abilities — Mobility**   |                             |                                       |
| Draw                       | weapon key + combo key      | target selected, line of sight        |
| Rush                       | weapon key + combo key      | target selected, line of sight        |
| Step                       | weapon key + combo key      | —                                     |
| **Abilities — Damage**     |                             |                                       |
| Burst                      | weapon key + combo key      | —                                     |
| Resonance                  | weapon key + combo key      | target selected, line of sight        |
| Surge                      | weapon key + combo key      | target selected, line of sight        |
| **Abilities — Control**    |                             |                                       |
| Disorient                  | weapon key + combo key      | target selected, line of sight        |
| Immobilize                 | weapon key + combo key      | target selected, line of sight        |
| Inflict                    | weapon key + combo key      | target selected, line of sight        |
| Interrupt                  | weapon key + combo key      | target selected, line of sight        |
| Knockback                  | weapon key + combo key      | scope defined per ability             |
| Silence                    | weapon key + combo key      | target selected, line of sight        |
| Slow                       | weapon key + combo key      | target selected, line of sight        |
| **Abilities — Defensive**  |                             |                                       |
| Barrier                    | weapon key + combo key      | —                                     |
| Endure                     | weapon key + combo key      | —                                     |
| Reflect                    | weapon key + combo key      | —                                     |
| **Abilities — Recovery**   |                             |                                       |
| Cleanse                    | weapon key + combo key      | ally targeted or self                 |
| Empower                    | weapon key + combo key      | ally targeted or self                 |
| Heal                       | weapon key + combo key      | ally targeted or self                 |
| **Abilities — Utility**    |                             |                                       |
| Detect                     | weapon key + combo key      | —                                     |
| Field                      | weapon key + combo key      | placement confirmed                   |
| Reveal                     | weapon key + combo key      | target selected, line of sight        |
| Trap                       | weapon key + combo key      | placement confirmed                   |
| Vanish                     | weapon key + combo key      | —                                     |
| **World Interaction**      |                             |                                       |
| Grab                       | Grab                        | near object, facing                   |
| Push                       | Push                        | grab active                           |
| Pull                       | Pull                        | grab active                           |
| Hold (carry)               | — [auto]                    | pull on small object while grabbing   |
| Put Down                   | Put Down                    | carrying, no move input               |
| Throw                      | Throw                       | carrying, move input active           |
| Loot                       | Loot                        | near body                             |
| Acquire (interact)         | interact key                | near item                             |
| Acquire (auto)             | — [auto]                    | player contacts item                  |
| Boost item                 | — [auto]                    | player contacts boost item            |
| Open                       | interact key                | near chest or container, facing       |
| Cross                      | interact key                | near door or passage, facing          |
| Talk                       | interact key                | near NPC, facing                      |
| **Equipment**              |                             |                                       |
| Inventory (toggle)         | inventory key               | —                                     |
| Equip                      | (TBD)                       | inventory open                        |
| **Status Effects**         |                             |                                       |
| Buff                       | — [auto]                    | ability or item applied               |
| Debuff                     | — [auto]                    | hit by enemy ability                  |
| Weather debuff             | — [auto]                    | in hazardous environment, lacking gear|
| **Lifecycle**              |                             |                                       |
| Spawn (silent)             | — [auto]                    | world transition                      |
| Spawn (arrival)            | — [auto]                    | game start / load / teleport / recover|
| Faint                      | — [auto]                    | HP reaches zero                       |
| Recover                    | — [auto]                    | player fainted, recover triggered     |
| **Expressive**             |                             |                                       |
| Bow                        | — [auto]                    | quest completed                       |
