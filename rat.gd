extends CharacterBody2D

# =============================================================================
# RAT.GD
#
# Responsibilities:
#   - Full state machine: idle_neutral ↔ wander ↔ notice → enter_stance
#                         ↔ idle_attack ↔ chase ↔ exit_stance ↔ returning
#                         → attack_bite / attack_slash → dying → dead
#   - Wander randomly when idle, chase and attack when player is near
#   - Return home when player escapes or energy runs out
#
# What this script does NOT do:
#   - Deal actual damage  (abilities not yet implemented)
#   - Use A* pathfinding  (direct movement for now)
#   - Set z_index or rotation  (game.gd handles all camera-dependent rendering)
# =============================================================================


# ── Sprite ─────────────────────────────────────────────────────────────────────

const SPRITE_SIZE := 96


# ── AI distances ───────────────────────────────────────────────────────────────

const NOTICE_COOLDOWN  := 3.0
const NOTICE_DIRECTION := 450.0
const NOTICE_DIST      := 400.0
const CHASE_DIST       := 900.0
const ATTACK_DIST      := 60.0
const HOME_MAX_DIST    := 2000.0
const HOME_DIST        := 16.0
const FLEE_SPEED       := 200.0


# ── Wander settings ────────────────────────────────────────────────────────────

const WANDER_CHANCE        := 0.40
const WANDER_INTERVAL_MIN  := 0.9
const WANDER_INTERVAL_MAX  := 1.1
const WANDER_DURATION_MIN  := 0.5
const WANDER_DURATION_MAX  := 3.0


# ── Base stats ─────────────────────────────────────────────────────────────────

const BASE_STR := 2
const BASE_AGI := 3
const BASE_STA := 2
const BASE_INT := 0
const BASE_SPR := 0
const BASE_RES := 0
const BASE_DEF := 1


# ── Animation files ────────────────────────────────────────────────────────────

const ANIM_FILES := {
	"idle_neutral" : "idle_neutral.png",
	"wander"       : "move.png",
	"notice"       : "notice.png",
	"enter_stance" : "enter_stance.png",
	"idle_attack"  : "idle_attack.png",
	"chase"        : "move.png",
	"exit_stance"  : "exit_stance.png",
	"returning"    : "move.png",
	"attack_bite"  : "attack_bite.png",
	"attack_slash" : "attack_slash.png",
	"dying"        : "death.png",
}

const ONE_SHOT_STATES := ["notice", "enter_stance", "exit_stance",
						  "attack_bite", "attack_slash", "dying"]


# ── State ──────────────────────────────────────────────────────────────────────

var state        : String = "idle_neutral"
var anim_done    : bool   = false
var facing_right : bool   = false
var alive        : bool   = true
var corpse_alpha : float  = 255.0


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
var home_max_dist   : bool    = false
var notice_cooldown : float   = 0.0
var gcd_timer       : float   = 0.0
var out_of_energy   : bool    = false


# ── References ─────────────────────────────────────────────────────────────────

var sprite       : AnimatedSprite2D   # created in _ready()
var player       : CharacterBody2D    # set by game.gd after spawn
var stats        : Stats              # created in _ready()
var camera_angle : float = 0.0       # set by game.gd on rotation


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	stats         = Stats.new(BASE_STR, BASE_AGI, BASE_STA, BASE_INT,
							  BASE_SPR, BASE_RES, BASE_DEF, false)
	home_position = position
	wander_timer  = randf_range(0.0, 1.0)
	wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)

	_create_sprite()


# Called: _ready().
func _create_sprite() -> void:

	sprite               = AnimatedSprite2D.new()
	sprite.z_as_relative = false
	add_child(sprite)

	_load_animations()
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("idle_neutral")


# Called: _create_sprite().
func _load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	for anim_name in ANIM_FILES:
		var path    : String   = "res://assets/spritesheets/rat/" + ANIM_FILES[anim_name]
		var texture : Texture2D = load(path)
		var loop    : bool     = anim_name not in ONE_SHOT_STATES

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

# Called: load_animations() via signal.
func _on_anim_finished() -> void:

	if state in ONE_SHOT_STATES:
		anim_done = true


# Called: _update_state(), _wander().
func _set_state(new_state: String) -> void:

	if state == new_state:
		return
	state     = new_state
	anim_done = false
	if state != "dead":
		sprite.play(state)


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

	var dist      : float = position.distance_to(player.position)
	var player_ok : bool  = player.state not in ["death", "dead"]

	match state:

		"idle_neutral", "wander":
			# ── Face player if nearby ──────────────────────────────────────────
			if player_ok and dist < NOTICE_DIRECTION:
				_update_facing(player.position.x - position.x,
							   player.position.y - position.y)
				if dist < NOTICE_DIST and notice_cooldown <= 0.0:
					_set_state("notice")
					return
			# ── Wander ────────────────────────────────────────────────────────
			var signal_ := _wander(delta)
			if signal_ == "start": _set_state("wander")
			elif signal_ == "done": _set_state("idle_neutral")

		"notice":
			if dist < ATTACK_DIST:
				_set_state("enter_stance")
			elif anim_done:
				if dist < NOTICE_DIST: _set_state("enter_stance")
				else:                  _set_state("idle_neutral")

		"enter_stance":
			# Record home on first engagement.
			if anim_done:
				if dist < ATTACK_DIST:      _set_state("idle_attack")
				elif dist < NOTICE_DIST:    _set_state("chase")
				else:                        _set_state("exit_stance")

		"idle_attack":
			if not player_ok or out_of_energy:
				_set_state("returning")
			elif dist < ATTACK_DIST:
				_try_attack()
			elif dist < CHASE_DIST:
				_set_state("chase")
			else:
				_set_state("exit_stance")

		"chase":
			var dist_home := position.distance_to(home_position)
			if dist_home > HOME_MAX_DIST:
				home_max_dist = true
				_set_state("returning")
			elif dist < ATTACK_DIST: _set_state("idle_attack")
			elif dist > CHASE_DIST:  _set_state("exit_stance")
			else:
				_move_toward(player.position, stats.mspd, delta)

		"exit_stance":
			if anim_done:
				if dist < NOTICE_DIST: _set_state("enter_stance")
				else:                  _set_state("returning")

		"returning":
			var dist_home := position.distance_to(home_position)
			var forced    := home_max_dist or out_of_energy or not player_ok

			if forced or dist > NOTICE_DIST:
				if dist_home <= HOME_DIST:
					_snap_to_home()
				else:
					_move_toward(home_position, FLEE_SPEED, delta)
			else:
				_update_facing(player.position.x - position.x,
							   player.position.y - position.y)
				if dist < ATTACK_DIST: _set_state("idle_attack")
				else:                  _set_state("enter_stance")

		"attack_bite", "attack_slash":
			if anim_done:
				_set_state("idle_attack")

		"dying":
			if anim_done:
				alive = false
				_set_state("dead")

		"dead":
			corpse_alpha = maxf(0.0, corpse_alpha - 300.0 * delta)
			sprite.modulate = Color(1.0, 1.0, 1.0, corpse_alpha / 255.0)
			if corpse_alpha <= 0.0:
				queue_free()


# =============================================================================
# WANDER
# =============================================================================

# Called: _update_state().
func _wander(delta: float) -> String:

	# Returns "start" to enter wander state, "done" to return to idle, "" to continue.
	if state == "idle_neutral":
		wander_timer += delta
		if wander_timer >= wander_interval:
			wander_timer    = 0.0
			wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)

			if randf() < WANDER_CHANCE or force_wander:
				force_wander     = false
				var angle        := randf() * TAU
				wander_dx        = cos(angle)
				wander_dy        = sin(angle)
				wander_elapsed   = 0.0
				wander_duration  = randf_range(WANDER_DURATION_MIN, WANDER_DURATION_MAX)
				_update_facing(wander_dx, wander_dy)
				return "start"
		return ""

	# Currently wandering.
	wander_elapsed += delta
	velocity = Vector2(wander_dx, wander_dy) * stats.mspd

	if force_wander:
		force_wander = false
		var angle    := randf() * TAU
		wander_dx    = cos(angle)
		wander_dy    = sin(angle)
		wander_elapsed  = 0.0
		wander_duration = randf_range(WANDER_DURATION_MIN, WANDER_DURATION_MAX)
		_update_facing(wander_dx, wander_dy)

	if wander_elapsed >= wander_duration:
		return "done"

	return ""


# =============================================================================
# MOVEMENT
# =============================================================================

# LOOP
func _physics_process(delta: float) -> void:

	if state in ["dead", "dying"]:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_state(delta)
		_sync_anim()
		return

	# Reset velocity — wander and _move_toward set it; idle states leave it zero.
	if state not in ["wander", "chase", "returning"]:
		velocity = Vector2.ZERO

	_update_state(delta)

	# Skip physics resolution during one-shot animations — the rat is stationary
	# and skipping move_and_slide() prevents the player from pushing the body.
	if state not in ONE_SHOT_STATES:
		move_and_slide()
		if is_on_wall() and state == "wander":
			force_wander = true

	if state not in ONE_SHOT_STATES and state != "dead":
		stats.regen(delta)

	_sync_anim()


# Called: _update_state().
func _move_toward(target_pos: Vector2, speed: float, _delta: float) -> void:

	var dir := (target_pos - position)
	if dir.length() < 1.0:
		velocity = Vector2.ZERO
		return
	_update_facing(dir.x, dir.y)
	velocity = dir.normalized() * speed


# Called: _update_state().
func _snap_to_home() -> void:

	position      = home_position
	velocity      = Vector2.ZERO
	home_max_dist = false
	out_of_energy = false
	notice_cooldown = NOTICE_COOLDOWN
	wander_timer  = 0.0
	wander_elapsed = 0.0
	force_wander  = false
	_set_state("idle_neutral")


# =============================================================================
# FACING
# =============================================================================

# Called: _update_state(), _wander(), _move_toward().
func _update_facing(world_dx: float, world_dy: float) -> void:

	# Converts world-space movement to screen-space to determine left/right flip.
	var rad   := deg_to_rad(camera_angle)
	var cos_a := cos(rad)
	var sin_a := sin(rad)
	facing_right = (world_dx * cos_a - world_dy * sin_a) > 0


# =============================================================================
# COMBAT
# =============================================================================

# Called: _update_state() when in ATTACK_DIST.
func _try_attack() -> void:

	# Picks attack animation. Actual damage wired up when abilities are implemented.
	if gcd_timer > 0.0:
		return
	gcd_timer = Stats.GCD
	_set_state("attack_bite" if randf() > 0.5 else "attack_slash")


# Called: game.gd or player combat system (future).
func take_damage(amount: float) -> void:

	if not alive or state in ["dying", "dead"]:
		return
	stats.take_damage(amount)
	if not stats.is_alive():
		_begin_death()


# Called: take_damage().
func _begin_death() -> void:

	alive         = false
	out_of_energy = true
	_set_state("dying")
