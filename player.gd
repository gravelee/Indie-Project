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


# ── Signals ────────────────────────────────────────────────────────────────────

signal attacked(world_pos: Vector2, facing_dir: Vector2)   # emitted when forward_slash starts


# ── Base stats ─────────────────────────────────────────────────────────────────

const BASE_STR := 0
const BASE_AGI := 0
const BASE_STA := 0
const BASE_INT := 0
const BASE_SPR := 0
const BASE_RES := 0
const BASE_DEF := 0


# ── Animation sets ─────────────────────────────────────────────────────────────

const DIRECTIONS         	:= ["south", "north", "east", "west"]
const DIRECTIONAL_ANIMS  	:= ["idle_neutral", "idle_attack", "walking", "forward_slash"]
const NON_DIRECTIONAL_ANIMS := ["spawn", "death"]
const ONE_SHOT_STATES    	:= ["spawn", "forward_slash", "death"]


# ── State ──────────────────────────────────────────────────────────────────────

var state     : String = "spawn"
var facing    : String = "south"
var in_combat : bool   = false
var anim_done : bool   = false


# ── References ─────────────────────────────────────────────────────────────────

var sprite       : AnimatedSprite2D   # assigned by game.gd before load_animations()
var camera_angle : float = 0.0        # set by game.gd every frame
var stats        : Stats              # created in _ready()


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
		for dir in DIRECTIONS:
			var key  : String = anim + "_" + dir
			var texture : Texture2D = load("res://assets/spritesheets/player/" + key + ".png")
			var loop : bool   = anim not in ONE_SHOT_STATES
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

# Called: _sync_anim().
func _anim_key() -> String:

	# Returns the SpriteFrames key for the current state and facing direction.
	if state in NON_DIRECTIONAL_ANIMS:
		return state
	return state + "_" + facing


# Called: _physics_process().
func _sync_anim() -> void:

	# Syncs the sprite to the current state + facing.
	# Skipped for "dead" so the death sheet stays frozen on its last frame.
	if state == "dead":
		return
	var key := _anim_key()
	if sprite.animation != key:
		sprite.play(key)


# Called: load_animations() via signal.
func _on_anim_finished() -> void:

	if state in ONE_SHOT_STATES:
		anim_done = true


# Called: _update_state(), _handle_movement().
func _set_state(new_state: String) -> void:

	# Resets anim_done so the next one-shot can fire correctly.
	if state == new_state:
		return
	state     = new_state
	anim_done = false


# =============================================================================
# STATE MACHINE
# =============================================================================

# Called: _physics_process().
func _update_state() -> void:

	match state:

		"spawn":
			if anim_done:
				_set_state("idle_neutral")

		"idle_neutral":
			if in_combat:
				_set_state("idle_attack")

		"idle_attack":
			if not in_combat:
				_set_state("idle_neutral")

		"forward_slash":
			if anim_done:
				_set_state("idle_attack")

		"death":
			if anim_done:
				_set_state("dead")

		# "walking" and "dead" transitions are handled in _handle_movement().


# =============================================================================
# MOVEMENT
# =============================================================================

# LOOP
func _physics_process(delta: float) -> void:

	_update_state()
	_handle_movement(delta)
	_sync_anim()
	if not in_combat and state not in ["death", "dead"]:
		stats.regen(delta)


# Called: _physics_process().
func _handle_movement(_delta: float) -> void:

	if state in ONE_SHOT_STATES or state in ["death", "dead"]:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input.y -= 1
	if Input.is_key_pressed(KEY_S): input.y += 1
	if Input.is_key_pressed(KEY_A): input.x -= 1
	if Input.is_key_pressed(KEY_D): input.x += 1

	if input.length() > 0:
		input = input.normalized()

		# Facing is based on screen-space intent (before camera rotation)
		# so the animation always matches what the player sees on screen.
		if abs(input.x) >= abs(input.y):
			facing = "east" if input.x > 0 else "west"
		else:
			facing = "south" if input.y > 0 else "north"

		# Rotate input to world space so WASD stays screen-relative.
		input = input.rotated(deg_to_rad(-camera_angle))

		_set_state("walking")
		velocity = input * stats.mspd

	else:
		# No input — return to the appropriate idle.
		if state == "walking":
			_set_state("idle_attack" if in_combat else "idle_neutral")
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

	if state in ONE_SHOT_STATES or state in ["death", "dead"]:
		return
	_set_state("forward_slash")
	attacked.emit(position, _facing_world_dir())


# Called: _try_attack().
func _facing_world_dir() -> Vector2:

	# Converts the screen-space facing cardinal into a world-space unit vector,
	# accounting for the current camera rotation.
	var screen_dir : Vector2
	match facing:
		"south": screen_dir = Vector2( 0,  1)
		"north": screen_dir = Vector2( 0, -1)
		"east":  screen_dir = Vector2( 1,  0)
		"west":  screen_dir = Vector2(-1,  0)
		_:       screen_dir = Vector2( 0,  1)
	return screen_dir.rotated(deg_to_rad(-camera_angle))
