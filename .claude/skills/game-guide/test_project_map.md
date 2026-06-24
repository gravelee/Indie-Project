---
name: Test Project System Map
description: Live architecture map of test_project — what each file owns, who calls who, and how data flows. Read this at the start of any session to orient quickly. Keep this updated after every session.
type: reference
---

# Test Project — System Map

## Files at a Glance

| File | Owns | Extends |
|------|------|---------|
| `main.gd` | Scene builder — spawns everything, wires references | Node3D |
| `entity.gd` | Shared entity base — PIXEL_SIZE, sprite, stats, hit_half_height, is_dead, flash, receive_hit | CharacterBody3D |
| `player.gd` | Input, movement, jump, sprint, attack, block, regen, fade, respawn | Entity |
| `creature.gd` | Rat collision/sprite setup, receive_hit print, exp_reward | Entity |
| `stats.gd` | All stat math — HP/energy/focus/exp, damage, regen, crit | RefCounted |
| `ability.gd` | One ability instance — cooldown timer, can_use, spend, calc_damage | RefCounted |
| `abilities.gd` | Ability registry — _DATA dictionary, get_ability() factory | RefCounted |
| `camera_rig.gd` | Camera orbit (RMB/Q/E), pitch, zoom, wall clip, presets | Node3D |

---

## Call Flow

```
Godot engine
  ├── _physics_process(delta)  →  player.gd
  │     ├── reads h_angle      →  camera_rig.gd
  │     ├── _update_state()        (movement state from input)
  │     ├── _update_airborne()     (ledge fall detection)
  │     ├── _update_velocity()     (direction, gravity, knockback)
  │     │     └── move_and_slide()
  │     ├── _update_death()        (deferred death trigger)
  │     ├── _update_sprint()       (energy drain accumulator)
  │     ├── _update_focus()        (passive combat tick)
  │     ├── match state → update functions
  │     │     ├── IDLE/WALK/RUN → _anim_apply()
  │     │     ├── ATTACK        → _attack_update()
  │     │     │     └── _attack_check() → creature.receive_hit()
  │     │     │           └── if creature.is_dead → stats.gain_exp(creature.exp_reward)
  │     │     ├── JUMP          → _jump_update()
  │     │     ├── BLOCK         → _block_update(delta)
  │     │     │     └── § released → LOWERING → exits to IDLE or WALK
  │     │     ├── SPAWN         → _spawn_update()
  │     │     └── DEAD          → _dead_update(delta)
  │     │           └── _dead_timer >= RESPAWN_DELAY → _do_respawn()
  │     ├── _fade_update()         (sprite alpha at close zoom)
  │     └── _update_timers()       (regen_timer, combat_timer, cooldowns, ability array regen)
  │
  ├── _input(event)            →  player.gd
  │     ├── KEY_1 → _abilities[0] → ability.can_use() → ability.spend() → ATTACK state
  │     ├── SPACE → jump → JUMP state
  │     └── § (KEY_SECTION) → _has_shield() → BLOCK state (from IDLE/WALK only)
  │
  └── _physics_process(delta)  →  creature.gd  (Stage 9 — not yet implemented)
        └── _extend_combat_timer() → player.gd  (keeps combat window alive)
```

---

## Data Flow

```
Stats (stats.gd)
  ← created by: player.init(), creature.init()
  ← written by: ability.spend(), ability.calc_damage(), take_damage(), regen(), gain_focus(), gain_exp()
  → read by: player.gd (mspd, energy, is_alive, hp_pct, exp), ability.can_use(), hud (future)
  → exp: accumulated via gain_exp() on creature death. No cap yet — leveling system future.

Ability (ability.gd / abilities.gd)
  ← created by: Abilities.get_ability("punch") in player.init(), appended to _abilities array
  → ability.can_use(stats) — checks cooldown + check_resources(stats)
  → ability.spend(stats)   — spend_resources(stats)
  → ability.calc_damage(stats) — calc_ability_damage(stats), returns float + gains focus
  → ability.tick(delta)    — counts down cooldown (called via loop over _abilities in _update_timers)

Entity (entity.gd)
  ← extended by: player.gd, creature.gd
  → receive_hit(damage, dir): take_damage → gain_focus_on_receive → _flash_sprite → is_dead
  → _last_damage: written by receive_hit(), read by child receive_hit() for prints

Player attack → creatures
  player._attack_check() iterates get_tree().get_nodes_in_group("creatures")
  Gates (all must pass): height (absf(diff.y) ≤ hhh + slack) → XZ range → cone (dot > 0.7071)
  On pass: ability.calc_damage(stats) → creature.receive_hit(damage, kb_dir)
  On kill: stats.gain_exp(creature.exp_reward)
```

---

## State Machine (player.gd)

```
SPAWN ──(anim ends)──► IDLE ◄──────────────(_do_respawn enters SPAWN → anim ends)
  │
IDLE ──(input)──► WALK ──(shift+energy)──► RUN
  │                 │                        │
  └─────────────────┴────────────────────────┘
        │ KEY_1 (_abilities[0].can_use)          │ not on floor
        ▼                                         ▼
      ATTACK ──(anim ends)──► IDLE             JUMP
        │                                   (4 phases: WINDUP→RISE→FALL→LAND)
        │ is_dead + grounded + settled
        ▼
       DEAD ──(3s timer)──► _do_respawn() ──► SPAWN

  § from IDLE or WALK (shield equipped, not RUN/JUMP/ATTACK):
        ▼
      BLOCK ──(§ released → LOWERING done)──► IDLE or WALK
        (3 phases: RAISING→HOLDING→LOWERING)
```

---

## Key Constants (quick reference)

| Constant | File | Value | Meaning |
|----------|------|-------|---------|
| PIXEL_SIZE | entity.gd | 3/32 | px→world scale for all sprites |
| BODY_ORIGIN_Y | player.gd | 1.5 | player body Y above ground |
| BODY_ORIGIN_Y | creature.gd | 0.75 | rat body Y above ground |
| hit_half_height | entity.gd | set in init() | ±Y window for receiving hits |
| ATTACK_HEIGHT_SLACK | player.gd | 0.05 | physics margin tolerance on height gate |
| ATTACK_ARC_DOT | player.gd | 0.7071 | cos(45°) — ±45° attack cone |
| KNOCKBACK_AIR_SCALE | player.gd | 0.1 | knockback strength multiplier while airborne |
| GRAVITY | player.gd | -20.0 | world units/s² |
| JUMP_VEL | player.gd | 7.75 | launch velocity, ~1.5 tiles peak |
| COMBAT_TIMEOUT | player.gd | 3.0 | seconds combat window stays open |
| FOCUS_COMBAT_INTERVAL | player.gd | 5.0 | seconds between passive focus ticks |
| RESPAWN_DELAY | player.gd | 3.0 | seconds after death before respawn |
| KNOCKBACK_STRENGTH | player.gd | 8.0 | base knockback magnitude; blocked hits use × 0.5 |
| SHIELD_UP_FRAMES | player.gd | 7 | frames in shield_up animation (raise and lower) |
| block_chance | stats.gd | 0.5 | probability a hit is blocked while in HOLDING |
| block_dir_threshold | stats.gd | 0.5 | dot floor for block arc (±60°); talent reduces to 0.0 (±90°) |
| last_hit_was_crit | stats.gd | false | set by calc_ability_damage(), read by defender receive_hit() |
| exp_reward | creature.gd | 5 | EXP awarded to player on kill |

---

## What Is NOT Implemented Yet (next stages)

- **Stage 7** — terrain height (terrain_generator.gd, HeightMapShape3D)
- **Stage 9** — creature AI (wander → notice → chase → attack FSM)
- **Stage 10** — pathfinding (A* XZ plane)
- **Stage 11** — status effects
- **Stage 12** — HUD (HP/energy/focus bars)
- **Stage 13** — combat feedback (floating numbers)
- **Stage 14** — map loading (CSV terrain + prop/creature spawn)
