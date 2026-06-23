# player.gd — One-Page Reference

---

## 1. State Machine

```
                    ┌─────────────────────────────────────────────┐
                    │                  SPAWN                      │
                    │         (invincible, no input)              │
                    └──────────────────┬──────────────────────────┘
                                 anim ends
                                       │
          ┌────────────────────────────▼────────────────────────────┐
          │                          IDLE                           │
          │                   (standing still)                      │
          └──────┬───────────────────────┬────────────────────────┬─┘
           has input                has input               KEY_1 punch.can_use
                 │                  + SHIFT + energy               │
                 ▼                        ▼                        ▼
              WALK ──(SHIFT + energy)──► RUN                   ATTACK
                 └────────────────────────┘                        │
                          any state except                    anim ends
                          SPAWN / DEAD / JUMP                      │
                          + not on floor                           ▼
                                 │                              IDLE
                                 ▼
                              JUMP ◄── KEY_SPACE (voluntary)
                    ┌────────────┤◄── ledge fall (involuntary)
                    │     phases │◄── knockback throw (involuntary)
                    │     below  │
                    │            └── land → IDLE
                    │                      or DEAD (if is_dead)
                    ▼
                  DEAD  ◄── any state (grounded + settled + is_dead)
                    │
               3s timer
                    │
              _do_respawn() ──► SPAWN ──(anim ends)──► IDLE
```

---

## 2. Jump Phases (inside JUMP state)

```
  WINDUP (frame 0)          RISE (frame 1)         FALL (frame 2)        LAND (frame 3→4)
  ┌─────────────────┐      ┌──────────────┐       ┌──────────────┐      ┌─────────────────┐
  │ hold prep frame │      │ ascending    │       │ descending   │      │ frame 3: contact│
  │ wait 1 frame    │─────►│ vel.y > 0    │──────►│ vel.y <= 0   │─────►│ frame 4: absorb │
  │ then apply      │      │              │       │ until floor  │      │ wait 2 frames   │
  │ JUMP_VEL        │      │ locked vel   │       │ locked vel   │      │ then → IDLE     │
  └─────────────────┘      └──────────────┘       └──────────────┘      └─────────────────┘
        ▲                                                                        │
        └────────────────────────────────────────────────────────────────────────┘
                                   reset for next jump
```

---

## 3. Per-Frame Call Order (_physics_process)

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  every frame                                                         │
  │                                                                      │
  │  1  h_angle ← camera_rig            (CAMERA reads from rig)         │
  │  2  _read_input()        → input    (CAMERA: use_wasd/use_arrows)   │
  │  3  _update_state(input)            (STATE: sets IDLE/WALK/RUN)     │
  │  4  _update_airborne()              (JUMP: catches ledge falls)      │
  │  5  _update_velocity(input, delta)  (MOVEMENT: gravity + slide)     │
  │  6  _update_death()                 (COMBAT: fires DEAD when settled)│
  │  7  _update_sprint(delta)           (MOVEMENT: drains energy)        │
  │  8  _update_focus(delta)            (COMBAT: passive focus ticks)    │
  │                                                                      │
  │  9  match state:                                                     │
  │       IDLE / WALK / RUN → _anim_apply(input)     (ANIMATION)        │
  │       ATTACK            → _attack_update()        (COMBAT)           │
  │       JUMP              → _jump_update(delta)     (JUMP)             │
  │       SPAWN             → _spawn_update()         (LIFECYCLE)        │
  │       DEAD              → _dead_update(delta)      (LIFECYCLE)        │
  │                                                                      │
  │  10 _fade_update()                  (ANIMATION: sprite alpha)        │
  │  11 _update_timers(delta)           (COMBAT+JUMP: tick + regen)      │
  └──────────────────────────────────────────────────────────────────────┘
```

---

## 4. Timer Gates

```
  _regen_timer         set by: any swing (_input), receive_hit
                       blocks: regen (in _update_timers)

  _combat_timer        set by: creature hit (_attack_check), receive_hit, _extend_combat_timer
                       blocks: regen (in _update_timers)
                       enables: combat idle animations (in _anim_apply via _is_in_combat)

  _jump_cooldown_timer set by: LAND exit (_jump_update)
                       blocks: KEY_SPACE jump (in _input)

  _dead_timer          set by: _do_respawn() (reset to 0), counts up in _dead_update()
                       fires: _do_respawn() when >= RESPAWN_DELAY (3s)

  ┌───────────────────────────────────────────────────────┐
  │ REGEN fires only when ALL of these are true:          │
  │   _regen_timer   == 0                                 │
  │   _combat_timer  == 0                                 │
  │   state != RUN                                        │
  │   state != JUMP                                       │
  │   state != BLOCK                                      │
  └───────────────────────────────────────────────────────┘
```

---

## 5. Section Ownership

```
  SECTION     VARS OWNED                              FUNCTIONS OWNED
  ─────────   ─────────────────────────────────────   ──────────────────────────────────────
  INIT        _col, _sprite_base_y                      init()
  CAMERA      cam, camera_rig, h_angle                —
  ANIMATION   last_dir                                 _load_sprite_frames(), _weapon_style()
                                                       _get_dir(), _is_in_combat()
                                                       _anim_apply(), _fade_update()
  COMBAT      _regen_timer, _combat_timer              _attack_check(), _attack_update()
              _focus_combat_timer, _knockback_vel      receive_hit(), _extend_combat_timer()
              _abilities, _active_ability, _hit_applied
  JUMP        _jump_phase, _jump_launched              _jump_update()
              _jump_frame_timer, _jump_cooldown_timer
              _jump_locked_vel
  LIFECYCLE   _spawn_position, _dead_timer             _spawn_update(), _dead_update(delta)
              _initial_hp, _initial_energy             _do_respawn()
              _initial_focus
  MOVEMENT    _run_energy_accum                        —
  STATE       state                                    —
  EQUIPMENT   weapon_main, weapon_off                  —
  INPUT       —                                        _input()
  PROCESS     —                                        _read_input(), _update_state()
                                                       _update_airborne(), _update_velocity()
                                                       _update_death(), _update_sprint()
                                                       _update_focus(), _update_timers()
                                                       _physics_process()
```

---

## 6. Cross-Section Reads (what each function reaches into)

```
  FUNCTION              READS FROM SECTIONS
  ───────────────────   ──────────────────────────────────────────────────
  _input()              STATE (state), COMBAT (_abilities[0]), EQUIPMENT (weapon_main)
                        JUMP (_jump_cooldown_timer, _jump_phase, _jump_launched)
  _read_input()         CAMERA (cam)
  _update_state()       STATE (state), entity stats.energy
  _update_airborne()    STATE (state), JUMP (_jump_phase, _jump_launched)
  _update_velocity()    STATE (state), MOVEMENT (GRAVITY, SPRINT_MULT, KNOCKBACK_AIR_SCALE)
                        JUMP (_jump_locked_vel), COMBAT (_knockback_vel), entity stats.mspd
  _update_death()       entity (is_dead), STATE (state), COMBAT (_knockback_vel), INIT (_col)
  _update_sprint()      STATE (state), entity stats
  _update_focus()       COMBAT (_combat_timer), entity stats
  _update_timers()      COMBAT (_regen_timer, _combat_timer, _abilities loop)
                        JUMP (_jump_cooldown_timer), STATE (state)
  _anim_apply()         STATE (state), COMBAT (_combat_timer), EQUIPMENT (weapon_main)
                        ANIMATION (last_dir)
  _fade_update()        STATE (state), CAMERA (camera_rig)
  _attack_check()       ANIMATION (last_dir, DIR_MAP), CAMERA (h_angle)
                        COMBAT (_active_ability), entity stats
                        on kill: entity stats.gain_exp(creature.exp_reward)
  _attack_update()      COMBAT (_active_ability, _hit_applied)
  _jump_update()        JUMP (all jump vars), ANIMATION (last_dir), COMBAT (_is_in_combat)
                        EQUIPMENT (weapon_main)
  receive_hit()         STATE (state), COMBAT (timers, _knockback_vel), entity (_last_damage)
  _dead_update()        LIFECYCLE (_dead_timer, RESPAWN_DELAY)
  _do_respawn()         LIFECYCLE (all lifecycle vars), INIT (_col, _spawn_position)
                        entity (is_dead, stats)
```

---

## 7. Quick Lookup — "Where is X?"

```
  h_angle               CAMERA  — updated top of every frame from camera_rig
  last_dir              ANIMATION — persists facing when stopped
  state                 STATE — the 7-value enum driving the whole machine
  is_dead               entity.gd — set in entity.receive_hit when hp hits 0; cleared in _do_respawn
  _knockback_vel        COMBAT — set by receive_hit, decays in _update_velocity
  _jump_locked_vel      JUMP — captured at airborne moment, held for full air time
  _combat_timer         COMBAT — set on hit, drives idle anims + regen gate
  _abilities            COMBAT — Array[Ability], slot 0 = punch. Ticked each frame via loop.
  _abilities[0]         COMBAT — the punch ability (KEY_1)
  _active_ability       COMBAT — what is swinging right now (set in _input)
  _col                  INIT — CollisionShape3D found in init(), disabled on death, re-enabled on respawn
  _spawn_position       LIFECYCLE — global_position recorded at init(), respawn target
  _dead_timer           LIFECYCLE — counts up in DEAD state, triggers respawn at 3s
  weapon_main           EQUIPMENT — drives animation name suffix
  sprite                entity.gd — the AnimatedSprite3D child
  stats                 entity.gd — the Stats resource (includes stats.exp)
```
