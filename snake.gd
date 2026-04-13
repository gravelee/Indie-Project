extends CharacterBody2D

# =============================================================================
# SNAKE.GD
#
# Responsibilities:
#   - Full state machine: idle_neutral ↔ wander ↔ notice → enter_stance
#                         ↔ idle_attack ↔ chase ↔ exit_stance ↔ returning
#                         → attack_bite / attack_tail_slam → death → dead
#   - Wander randomly when idle, chase and attack when player is near
#   - Return home when player escapes or energy runs out
#
# What this script does NOT do:
#   - Deal actual damage  (abilities not yet implemented)
#   - Use A* pathfinding  (direct movement for now)
#   - Set z_index or rotation  (game.gd handles all camera-dependent rendering)
# =============================================================================


# ── State enum ─────────────────────────────────────────────────────────────────

enum State {
	IDLE_NEUTRAL, WANDER, NOTICE, ENTER_STANCE, IDLE_ATTACK,
	CHASE, EXIT_STANCE, RETURNING, ATTACK_BITE, ATTACK_TAIL_SLAM,
	DEATH, DEAD
}


# ── Sprite ─────────────────────────────────────────────────────────────────────

const SPRITE_SIZE := 96
const SPRITE_PATH := "res://assets/spritesheets/snake/"


# ── AI distances ───────────────────────────────────────────────────────────────

const NOTICE_COOLDOWN  := 3.0
const NOTICE_DIRECTION := 450.0
const NOTICE_DIST      := 400.0
const CHASE_DIST       := 900.0
const ATTACK_DIST      := 60.0
const HOME_MAX_DIST    := 2000.0
const HOME_DIST        := 16.0
const FLEE_SPEED       := 200.0

# Pre-squared — avoids sqrt in distance comparisons every frame.
const NOTICE_DIRECTION_SQ := NOTICE_DIRECTION * NOTICE_DIRECTION
const NOTICE_DIST_SQ      := NOTICE_DIST      * NOTICE_DIST
const CHASE_DIST_SQ       := CHASE_DIST       * CHASE_DIST
const ATTACK_DIST_SQ      := ATTACK_DIST      * ATTACK_DIST
const HOME_MAX_DIST_SQ    := HOME_MAX_DIST    * HOME_MAX_DIST
const HOME_DIST_SQ        := HOME_DIST        * HOME_DIST


# ── Wander settings ────────────────────────────────────────────────────────────

const WANDER_CHANCE        := 0.30
const WANDER_INTERVAL_MIN  := 0.9
const WANDER_INTERVAL_MAX  := 1.1
const WANDER_DURATION_MIN  := 0.5
const WANDER_DURATION_MAX  := 3.0


# ── Base stats ─────────────────────────────────────────────────────────────────

const BASE_STR := 0
const BASE_AGI := 0
const BASE_STA := 0
const BASE_INT := 0
const BASE_SPR := 0
const BASE_RES := 0
const BASE_DEF := 0


# ── Animation mapping ──────────────────────────────────────────────────────────

# Maps State enum → animation name for sprite.play(). Integer keys, O(1).
const STATE_ANIM := {
	State.IDLE_NEUTRAL      : "idle_neutral",
	State.WANDER            : "wander",
	State.NOTICE            : "notice",
	State.ENTER_STANCE      : "enter_stance",
	State.IDLE_ATTACK       : "idle_attack",
	State.CHASE             : "chase",
	State.EXIT_STANCE       : "exit_stance",
	State.RETURNING         : "returning",
	State.ATTACK_BITE       : "attack_bite",
	State.ATTACK_TAIL_SLAM  : "attack_tail slam",
	State.DEATH             : "death",
}

# String keys — only used at startup by _load_animations() to set loop flags.
const ANIM_FILES := {
	"idle_neutral"     : "idle_neutral.png",
	"wander"           : "move.png",
	"notice"           : "notice.png",
	"enter_stance"     : "enter_stance.png",
	"idle_attack"      : "idle_attack.png",
	"chase"            : "move.png",
	"exit_stance"      : "exit_stance.png",
	"returning"        : "move.png",
	"attack_bite"      : "attack_bite.png",
	"attack_tail slam" : "attack_tail slam.png",
	"death"            : "death.png",
}

# String set — used only in _load_animations() to determine loop flag.
const ONE_SHOT_ANIM_NAMES := {
	"notice": true, "enter_stance": true, "exit_stance": true,
	"attack_bite": true, "attack_tail slam": true, "death": true
}


# ── State sets (enum keys — O(1) integer lookup) ───────────────────────────────

const ONE_SHOT_STATES := {
	State.NOTICE: true, State.ENTER_STANCE: true, State.EXIT_STANCE: true,
	State.ATTACK_BITE: true, State.ATTACK_TAIL_SLAM: true, State.DEATH: true
}

const COMBAT_STATES := {
	State.ENTER_STANCE: true, State.IDLE_ATTACK: true, State.CHASE: true,
	State.ATTACK_BITE: true,  State.ATTACK_TAIL_SLAM: true
}

const NON_COMBAT_STATES := {
	State.IDLE_NEUTRAL: true, State.WANDER: true,   State.NOTICE: true,
	State.EXIT_STANCE:  true, State.RETURNING: true, State.DEATH: true
}

const MOVING_STATES := {
	State.WANDER: true, State.CHASE: true, State.RETURNING: true
}


# ── State ──────────────────────────────────────────────────────────────────────

var state        : State = State.IDLE_NEUTRAL
var anim_done    : bool  = false
var facing_right : bool  = false
var alive        : bool  = true
var corpse_alpha : float = 255.0


# ── Wander ─────────────────────────────────────────────────────────────────────

var wander_timer    : float = 0.0
var wander_interval : float = 1.0
var wander_elapsed  : float = 0.0
var wander_duration : float = 0.0
var wander_dx       : float = 0.0
var wander_dy       : float = 0.0
var force_wander    : bool  = false


# ── AI ─────────────────────────────────────────────────────────────────────────

var home_position   : Vector2 = Vector2.ZERO
var has_home        : bool    = false
var temp_home       : bool    = false
var is_returning    : bool    = false
var fleeing         : bool    = false
var home_max_dist   : bool    = false
var notice_cooldown : float   = 0.0
var gcd_timer       : float   = 0.0
var out_of_energy   : bool    = false


# ── References ─────────────────────────────────────────────────────────────────

var sprite  : AnimatedSprite2D   # created in _ready()
var player  : CharacterBody2D    # set by game.gd after spawn
var stats   : Stats              # set by configure()

# Setter caches trig once per rotation and immediately corrects facing_right
# using the last known movement direction, so _move_toward stays cheap.
var camera_angle : float = 0.0:
	set(value):
		camera_angle = value
		var rad := deg_to_rad(value)
		_cos_a       = cos(rad)
		_sin_a       = sin(rad)
		facing_right = (_move_dx * _cos_a - _move_dy * _sin_a) > 0

var _cos_a   : float = 1.0   # cached cos(camera_angle)
var _sin_a   : float = 0.0   # cached sin(camera_angle)
var _move_dx : float = 0.0   # last movement direction — reused by setter on rotation
var _move_dy : float = 1.0


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	wander_timer    = randf_range(0.0, 1.0)
	wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	_create_sprite()


# Called: game._spawn_creature() after add_child.
func configure(cfg: Dictionary, world_pos: Vector2) -> void:

	stats        = Stats.new(cfg["str"], cfg["agi"], cfg["sta"], cfg["int"],
							 cfg["spr"], cfg["res"], cfg["def"], false)
	is_returning = cfg["returning"]
	fleeing      = cfg["fleeing"]
	if cfg["home"]:
		home_position = world_pos
		has_home      = true


# Called: _ready().
func _create_sprite() -> void:

	sprite               = AnimatedSprite2D.new()
	sprite.z_as_relative = false
	add_child(sprite)

	_load_animations()
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play(STATE_ANIM[State.IDLE_NEUTRAL])


# Called: _create_sprite().
func _load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	for anim_name in ANIM_FILES:
		var path    : String    = SPRITE_PATH + ANIM_FILES[anim_name]
		var texture : Texture2D = load(path)
		var loop    : bool      = anim_name not in ONE_SHOT_ANIM_NAMES

		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, 8.0)

		var frame_count := texture.get_width() / SPRITE_SIZE
		for i in range(frame_count):
			var atlas   := AtlasTexture.new()
			atlas.atlas  = texture
			atlas.region = Rect2(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
			frames.add_frame(anim_name, atlas)


# =============================================================================
# ANIMATION
# =============================================================================

# Called: _load_animations() via signal.
func _on_anim_finished() -> void:

	if state in ONE_SHOT_STATES:
		anim_done = true


# Called: _update_state(), _wander().
func _set_state(new_state: State) -> void:

	if state == new_state:
		return
	state     = new_state
	anim_done = false
	if state != State.DEAD:
		sprite.play(STATE_ANIM[state])


# Called: _physics_process().
func _sync_anim() -> void:

	# Keep flip in sync with facing every frame.
	# Z_index and rotation are handled by game.gd.
	sprite.flip_h = facing_right


# =============================================================================
# STATE MACHINE
# =============================================================================

# Called: _physics_process().
func _update_state(delta: float) -> void:

	# Tick cooldowns.
	if notice_cooldown > 0.0:
		notice_cooldown = maxf(0.0, notice_cooldown - delta)
	if gcd_timer > 0.0:
		gcd_timer = maxf(0.0, gcd_timer - delta)

	if not player:
		return

	var player_ok : bool = player.state != player.State.DEATH and player.state != player.State.DEAD

	# dist_sq is computed lazily for idle states after the AABB check.
	# For all active states it is computed once here — no sqrt ever.
	var dist_sq : float = 0.0
	if state != State.IDLE_NEUTRAL and state != State.WANDER:
		dist_sq = position.distance_squared_to(player.position)

	match state:

		State.IDLE_NEUTRAL, State.WANDER:
			# ── AABB broad phase — skip dist entirely when player is clearly out of range ──
			var player_near := false
			if player_ok:
				var dx := absf(player.position.x - position.x)
				var dy := absf(player.position.y - position.y)
				if dx <= NOTICE_DIRECTION and dy <= NOTICE_DIRECTION:
					dist_sq = position.distance_squared_to(player.position)
					if dist_sq < NOTICE_DIRECTION_SQ:
						player_near = true
						_update_facing(player.position.x - position.x,
									   player.position.y - position.y)
						if dist_sq < NOTICE_DIST_SQ and notice_cooldown <= 0.0:
							_set_state(State.NOTICE)
							return
			# ── Wander ────────────────────────────────────────────────────────
			# Player nearby in IDLE_NEUTRAL → stay alert, don't start a new wander.
			# Already wandering → let it finish; can't re-enter after it ends.
			if not (player_near and state == State.IDLE_NEUTRAL):
				var signal_ := _wander(delta)
				if signal_ == "start": _set_state(State.WANDER)
				elif signal_ == "done": _set_state(State.IDLE_NEUTRAL)

		State.NOTICE:
			if dist_sq < ATTACK_DIST_SQ:
				_set_state(State.ENTER_STANCE)
			elif anim_done:
				if dist_sq < NOTICE_DIST_SQ: _set_state(State.ENTER_STANCE)
				else:                         _set_state(State.IDLE_NEUTRAL)

		State.ENTER_STANCE:
			if not has_home:
				home_position = position
				has_home      = true
				temp_home     = true
			if anim_done:
				if dist_sq < ATTACK_DIST_SQ:
					_update_facing(player.position.x - position.x, player.position.y - position.y)
					_set_state(State.IDLE_ATTACK)
				elif dist_sq < NOTICE_DIST_SQ: _set_state(State.CHASE)
				else:                           _set_state(State.EXIT_STANCE)

		State.IDLE_ATTACK:
			if not player_ok or out_of_energy:
				_set_state(State.RETURNING)
			elif dist_sq < ATTACK_DIST_SQ:
				_try_attack()
			elif dist_sq < CHASE_DIST_SQ:
				_set_state(State.CHASE)
			else:
				_set_state(State.EXIT_STANCE)

		State.CHASE:
			var dist_home_sq := position.distance_squared_to(home_position)
			if dist_home_sq > HOME_MAX_DIST_SQ:
				home_max_dist = true
				_set_state(State.RETURNING)
			elif dist_sq < ATTACK_DIST_SQ:
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				_set_state(State.IDLE_ATTACK)
			elif dist_sq > CHASE_DIST_SQ:  _set_state(State.EXIT_STANCE)
			else:
				_move_toward(player.position, stats.mspd, delta)

		State.EXIT_STANCE:
			if anim_done:
				if dist_sq < NOTICE_DIST_SQ: _set_state(State.ENTER_STANCE)
				else:                         _set_state(State.RETURNING)

		State.RETURNING:
			var dist_home_sq := position.distance_squared_to(home_position)
			var forced       := is_returning or home_max_dist or out_of_energy or not player_ok

			if forced or dist_sq > NOTICE_DIST_SQ:
				if dist_home_sq <= HOME_DIST_SQ:
					_snap_to_home()
				else:
					_move_toward(home_position, FLEE_SPEED, delta)
			else:
				_update_facing(player.position.x - position.x,
							   player.position.y - position.y)
				if dist_sq < ATTACK_DIST_SQ:
					_update_facing(player.position.x - position.x, player.position.y - position.y)
					_set_state(State.IDLE_ATTACK)
				else:                         _set_state(State.ENTER_STANCE)

		State.ATTACK_BITE, State.ATTACK_TAIL_SLAM:
			if anim_done:
				_set_state(State.IDLE_ATTACK)

		State.DEATH:
			if anim_done:
				alive = false
				_set_state(State.DEAD)


# =============================================================================
# WANDER
# =============================================================================

# Called: _update_state().
func _wander(delta: float) -> String:

	# Returns "start" to enter wander state, "done" to return to idle, "" to continue.
	if state == State.IDLE_NEUTRAL:
		wander_timer += delta
		if wander_timer >= wander_interval:
			wander_timer    = 0.0
			wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
			if randf() < WANDER_CHANCE:
				force_wander = true   # direction + facing set next frame in wander branch
				return "start"
		return ""

	# Currently wandering — resolve direction first, then apply velocity.
	if force_wander:
		force_wander    = false
		var angle       := randf() * TAU
		wander_dx       = cos(angle)
		wander_dy       = sin(angle)
		wander_elapsed  = 0.0
		wander_duration = randf_range(WANDER_DURATION_MIN, WANDER_DURATION_MAX)
		_update_facing(wander_dx, wander_dy)

	wander_elapsed += delta
	velocity = Vector2(wander_dx, wander_dy) * stats.mspd

	if wander_elapsed >= wander_duration:
		return "done"

	return ""


# =============================================================================
# MOVEMENT
# =============================================================================

# LOOP
func _physics_process(delta: float) -> void:

	if state == State.DEAD:
		corpse_alpha = maxf(0.0, corpse_alpha - 300.0 * delta)
		sprite.modulate = Color(1.0, 1.0, 1.0, corpse_alpha / 255.0)
		if corpse_alpha <= 0.0:
			queue_free()
		return

	_update_state(delta)

	if state not in MOVING_STATES:
		velocity = Vector2.ZERO

	# Skip physics resolution during one-shot animations — the snake is stationary
	# and skipping move_and_slide() prevents the player from pushing the body.
	if state not in ONE_SHOT_STATES:
		if state == State.WANDER and test_move(global_transform, velocity * delta):
			velocity     = Vector2.ZERO
			force_wander = true
		else:
			move_and_slide()

	if state == State.IDLE_NEUTRAL or state == State.WANDER:
		stats.regen(delta)

	_sync_anim()


# Called: _update_state().
func _move_toward(target_pos: Vector2, speed: float, _delta: float) -> void:

	var dir    := target_pos - position
	var len_sq := dir.length_squared()
	if len_sq < 1.0:
		velocity = Vector2.ZERO
		return
	var new_right := (dir.x * _cos_a - dir.y * _sin_a) > 0
	if new_right != facing_right:
		facing_right = new_right
		_move_dx = dir.x
		_move_dy = dir.y
	velocity = dir / sqrt(len_sq) * speed


# Called: _update_state().
func _snap_to_home() -> void:

	position        = home_position
	velocity        = Vector2.ZERO
	home_max_dist   = false
	out_of_energy   = false
	notice_cooldown = NOTICE_COOLDOWN
	wander_timer    = 0.0
	wander_elapsed  = 0.0
	force_wander    = false
	if temp_home:
		home_position = Vector2.ZERO
		has_home      = false
		temp_home     = false
	_set_state(State.IDLE_NEUTRAL)


# =============================================================================
# FACING
# =============================================================================

# Called: _update_state(), _wander().
func _update_facing(world_dx: float, world_dy: float) -> void:

	# Uses cached trig — no cos/sin calls here.
	_move_dx     = world_dx
	_move_dy     = world_dy
	facing_right = (world_dx * _cos_a - world_dy * _sin_a) > 0


# =============================================================================
# COMBAT
# =============================================================================

# Called: _update_state() when in ATTACK_DIST.
func _try_attack() -> void:

	# Picks attack animation. Actual damage wired up when abilities are implemented.
	if gcd_timer > 0.0:
		return
	gcd_timer = Stats.GCD
	_set_state(State.ATTACK_BITE if randf() > 0.5 else State.ATTACK_TAIL_SLAM)


# Called: game.gd or player combat system (future).
func take_damage(amount: float) -> void:

	if not alive or state == State.DEATH or state == State.DEAD:
		return
	stats.take_damage(amount)
	if not stats.is_alive():
		_begin_death()


# Called: take_damage().
func _begin_death() -> void:

	alive = false
	_set_state(State.DEATH)
