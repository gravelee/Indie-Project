extends CharacterBody2D

# =============================================================================
# PLAYER.GD
#
# Responsibilities:
#   - Full state machine: spawn → idle_neutral ↔ idle_attack ↔ walking
#                         forward_slash (attack), death → dead
#   - Read WASD input and move the physics body
#   - Keep movement direction relative to the camera angle
#   - Play the correct animation based on state and facing direction
#
# What this script does NOT do:
#   - Position the visual sprite  (game.gd does that)
#   - Rotate the visual sprite    (game.gd does that)
#   - Set z_index                 (game.gd does that)
# =============================================================================

const SPRITE_SIZE := 96
const TILE_SIZE   := 32


# ── Enums ──────────────────────────────────────────────────────────────────────

enum State  { SPAWN, IDLE_NEUTRAL, IDLE_ATTACK, WALKING, FORWARD_SLASH, DEATH, DEAD }
enum Facing { SOUTH, NORTH, EAST, WEST }


# ── Signals ────────────────────────────────────────────────────────────────────

signal attacked(world_pos: Vector2, facing_dir: Vector2)


# ── Base stats ─────────────────────────────────────────────────────────────────

const BASE_STR := 0
const BASE_AGI := 0
const BASE_STA := 0
const BASE_INT := 0
const BASE_SPR := 0
const BASE_RES := 0
const BASE_DEF := 0


# ── Animation data ─────────────────────────────────────────────────────────────

# Directional animations — loaded as state_facing (e.g. "idle_neutral_south").
const DIRECTIONAL_ANIMS := ["idle_neutral", "idle_attack", "walking", "forward_slash"]
const DIRECTIONS        := ["south", "north", "east", "west"]

# Non-directional animations — loaded as-is.
const NON_DIRECTIONAL_ANIMS := ["spawn", "death"]

# String names for non-directional states used in load_animations() loop check.
const ONE_SHOT_ANIM_NAMES := {"spawn": true, "forward_slash": true, "death": true}

# Maps Facing enum → direction string suffix for animation key lookup.
const FACING_STR := {
	Facing.SOUTH: "south", Facing.NORTH: "north",
	Facing.EAST:  "east",  Facing.WEST:  "west"
}

# Maps State enum → base animation name (directional states need FACING_STR appended).
const STATE_ANIM_BASE := {
	State.IDLE_NEUTRAL  : "idle_neutral",
	State.IDLE_ATTACK   : "idle_attack",
	State.WALKING       : "walking",
	State.FORWARD_SLASH : "forward_slash",
	State.SPAWN         : "spawn",
	State.DEATH         : "death",
}


# ── State sets (O(1) integer lookup) ───────────────────────────────────────────

const ONE_SHOT_STATES := {
	State.SPAWN: true, State.FORWARD_SLASH: true, State.DEATH: true
}

const NON_DIRECTIONAL_STATES := {
	State.SPAWN: true, State.DEATH: true
}


# ── State ──────────────────────────────────────────────────────────────────────

var state     : State  = State.SPAWN
var facing    : Facing = Facing.SOUTH
var in_combat : bool   = false
var anim_done : bool   = false

# Cached animation key — rebuilt only when state or facing changes.
var _anim_key : String = "spawn"


# ── References ─────────────────────────────────────────────────────────────────

var sprite       : AnimatedSprite2D   # assigned by game.gd before load_animations()
var stats        : Stats              # created in _ready()

# Setter caches the rotated radian so _handle_movement avoids deg_to_rad every frame.
var camera_angle : float = 0.0:
	set(value):
		camera_angle = value
		_cam_rad     = deg_to_rad(-value)

var _cam_rad : float = 0.0


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	stats = Stats.new(BASE_STR, BASE_AGI, BASE_STA, BASE_INT,
					  BASE_SPR, BASE_RES, BASE_DEF, true)


# Called: game._build_scene().
func load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	for anim in DIRECTIONAL_ANIMS:
		var loop : bool = anim not in ONE_SHOT_ANIM_NAMES
		for dir in DIRECTIONS:
			var key     : String    = anim + "_" + dir
			var texture : Texture2D = load("res://assets/spritesheets/player/" + key + ".png")
			_add_strip(frames, key, texture, loop)

	for anim in NON_DIRECTIONAL_ANIMS:
		var texture : Texture2D = load("res://assets/spritesheets/player/" + anim + ".png")
		_add_strip(frames, anim, texture, false)

	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("spawn")


# Called: load_animations().
func _add_strip(frames: SpriteFrames, key: String, texture: Texture2D, loop: bool) -> void:

	# Registers one horizontal spritesheet as an animation.
	frames.add_animation(key)
	frames.set_animation_loop(key, loop)
	frames.set_animation_speed(key, 8.0)

	var frame_count := texture.get_width() / SPRITE_SIZE
	for i in range(frame_count):
		var atlas   := AtlasTexture.new()
		atlas.atlas  = texture
		atlas.region = Rect2(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
		frames.add_frame(key, atlas)


# =============================================================================
# ANIMATION
# =============================================================================

# Called: _set_state(), _set_facing().
func _rebuild_anim_key() -> void:

	# Rebuilds the cached animation key when state or facing changes.
	if state in NON_DIRECTIONAL_STATES:
		_anim_key = STATE_ANIM_BASE[state]
	else:
		_anim_key = STATE_ANIM_BASE[state] + "_" + FACING_STR[facing]


# Called: _physics_process().
func _sync_anim() -> void:

	# Skipped for dead so the death sheet stays frozen on its last frame.
	# Uses cached _anim_key — no string built here.
	if state == State.DEAD:
		return
	if sprite.animation != _anim_key:
		sprite.play(_anim_key)


# Called: load_animations() via signal.
func _on_anim_finished() -> void:

	if state in ONE_SHOT_STATES:
		anim_done = true


# Called: _update_state(), _handle_movement().
func _set_state(new_state: State) -> void:

	if state == new_state:
		return
	state     = new_state
	anim_done = false
	if state != State.DEAD:
		_rebuild_anim_key()


# Called: _handle_movement().
func _set_facing(new_facing: Facing) -> void:

	if facing == new_facing:
		return
	facing = new_facing
	_rebuild_anim_key()


# =============================================================================
# STATE MACHINE
# =============================================================================

# Called: _physics_process().
func _update_state() -> void:

	match state:

		State.SPAWN:
			if anim_done:
				_set_state(State.IDLE_NEUTRAL)

		State.IDLE_NEUTRAL:
			if in_combat:
				_set_state(State.IDLE_ATTACK)

		State.IDLE_ATTACK:
			if not in_combat:
				_set_state(State.IDLE_NEUTRAL)

		State.FORWARD_SLASH:
			if anim_done:
				_set_state(State.IDLE_ATTACK)

		State.DEATH:
			if anim_done:
				_set_state(State.DEAD)

		# State.WALKING and State.DEAD transitions handled in _handle_movement().


# =============================================================================
# MOVEMENT
# =============================================================================

# LOOP
func _physics_process(delta: float) -> void:

	_update_state()
	_handle_movement(delta)
	_sync_anim()
	if not in_combat and state != State.DEATH and state != State.DEAD:
		stats.regen(delta)


# Called: _physics_process().
func _handle_movement(_delta: float) -> void:
		
	if state in ONE_SHOT_STATES:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if state == State.DEAD:
		return

	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input.y -= 1
	if Input.is_key_pressed(KEY_S): input.y += 1
	if Input.is_key_pressed(KEY_A): input.x -= 1
	if Input.is_key_pressed(KEY_D): input.x += 1

	if input != Vector2.ZERO:
		input = input.normalized()

		# Facing is based on screen-space intent (before camera rotation)
		# so the animation always matches what the player sees on screen.
		if abs(input.x) >= abs(input.y):
			_set_facing(Facing.EAST if input.x > 0 else Facing.WEST)
		else:
			_set_facing(Facing.SOUTH if input.y > 0 else Facing.NORTH)

		# Rotate input to world space so WASD stays screen-relative.
		input = input.rotated(_cam_rad)

		_set_state(State.WALKING)
		velocity = input * stats.mspd

	else:
		if state == State.WALKING:
			_set_state(State.IDLE_ATTACK if in_combat else State.IDLE_NEUTRAL)
		velocity = Vector2.ZERO

	move_and_slide()


# =============================================================================
# INPUT
# =============================================================================

# LOOP
func _input(event: InputEvent) -> void:

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_try_attack()


# Called: _input().
func _try_attack() -> void:

	if state in ONE_SHOT_STATES or state == State.DEAD:
		return
	_set_state(State.FORWARD_SLASH)
	attacked.emit(position, _facing_world_dir())


# Called: _try_attack().
func _facing_world_dir() -> Vector2:

	# Converts the screen-space facing cardinal into a world-space unit vector,
	# accounting for the current camera rotation.
	var screen_dir : Vector2
	match facing:
		Facing.SOUTH: screen_dir = Vector2( 0,  1)
		Facing.NORTH: screen_dir = Vector2( 0, -1)
		Facing.EAST:  screen_dir = Vector2( 1,  0)
		Facing.WEST:  screen_dir = Vector2(-1,  0)
	return screen_dir.rotated(_cam_rad)
