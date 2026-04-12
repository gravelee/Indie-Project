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


# ── Settings ───────────────────────────────────────────────────────────────────

const SPEED := 200.0


# ── Animation sets ─────────────────────────────────────────────────────────────

const DIRECTIONS := ["south", "north", "east", "west"]

# These animations exist in 4 directional variants (_south, _north, _east, _west).
const DIRECTIONAL_ANIMS := ["idle_neutral", "idle_attack", "walking", "forward_slash"]

# These animations are a single sheet with no direction suffix.
const NON_DIRECTIONAL_ANIMS := ["spawn", "death"]

# One-shot states: animation plays once and sets anim_done when finished.
const ONE_SHOT_STATES := ["spawn", "forward_slash", "death"]


# ── State ──────────────────────────────────────────────────────────────────────

var state     : String = "spawn"
var facing    : String = "south"
var in_combat : bool   = false   # set externally when combat is implemented
var anim_done : bool   = false   # true for one frame when a one-shot finishes


# ── References ─────────────────────────────────────────────────────────────────

var sprite       : AnimatedSprite2D   # assigned by game.gd before load_animations()
var camera_angle : float = 0.0        # set by game.gd every frame


# =============================================================================
# SETUP
# Called by game.gd after it creates the sprite node and assigns it above.
# =============================================================================

# Called: game._build_scene().
func load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	# Directional: four variants per animation (south/north/east/west).
	for anim in DIRECTIONAL_ANIMS:
		for dir in DIRECTIONS:
			var key  : String = anim + "_" + dir
			var texture : Texture2D = load("res://assets/spritesheets/player/" + key + ".png")
			var loop : bool   = anim not in ONE_SHOT_STATES
			_add_strip(frames, key, texture, loop)

	# Non-directional: one sheet per animation.
	for anim in NON_DIRECTIONAL_ANIMS:
		var texture : Texture2D = load("res://assets/spritesheets/player/" + anim + ".png")
		_add_strip(frames, anim, texture, false)

	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("spawn")


# Called: load_animations().
# Registers one horizontal spritesheet as an animation in frames.
# Every frame is 96 px wide.
func _add_strip(frames: SpriteFrames, key: String, texture: Texture2D, loop: bool) -> void:

	frames.add_animation(key)
	frames.set_animation_loop(key, loop)
	frames.set_animation_speed(key, 8.0)

	var frame_count := texture.get_width() / 96
	for i in range(frame_count):
		var atlas    := AtlasTexture.new()
		atlas.atlas   = texture
		atlas.region  = Rect2(i * 96, 0, 96, 96)
		frames.add_frame(key, atlas)


# =============================================================================
# ANIMATION
# =============================================================================

# Returns the SpriteFrames key for the current state and facing direction.
func _anim_key() -> String:
	if state in NON_DIRECTIONAL_ANIMS:
		return state
	return state + "_" + facing


# Syncs the sprite to the current state + facing — no-op if already correct.
# Not called for "dead" so the death sheet stays frozen on its last frame.
func _sync_anim() -> void:
	if state == "dead":
		return
	var key := _anim_key()
	if sprite.animation != key:
		sprite.play(key)


# Called: load_animations() (via signal).
func _on_anim_finished() -> void:
	if state in ONE_SHOT_STATES:
		anim_done = true


# Sets a new state. Resets anim_done so the next one-shot can fire correctly.
func _set_state(new_state: String) -> void:
	if state == new_state:
		return
	state     = new_state
	anim_done = false


# =============================================================================
# STATE MACHINE
# Runs every physics frame before movement so transitions take effect immediately.
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
# MOVEMENT  -  runs every physics frame
# =============================================================================

# LOOP
func _physics_process(_delta: float) -> void:

	_update_state()
	_handle_movement()
	_sync_anim()


# Called: _physics_process().
func _handle_movement() -> void:

	# Block movement during one-shot animations or when dead.
	if state in ONE_SHOT_STATES or state == "dead":
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
		velocity = input * SPEED

	else:
		# No input — return to the appropriate idle.
		if state == "walking":
			_set_state("idle_attack" if in_combat else "idle_neutral")
		velocity = Vector2.ZERO

	move_and_slide()


# =============================================================================
# INPUT  -  attack trigger
# =============================================================================

# LOOP
func _input(event: InputEvent) -> void:

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_try_attack()


# Called: _input().
func _try_attack() -> void:

	# Cannot attack during one-shot animations or when dead.
	if state in ONE_SHOT_STATES or state == "dead":
		return

	# Trigger the forward slash animation.
	# Damage and hit detection will be wired up when combat is implemented.
	_set_state("forward_slash")
