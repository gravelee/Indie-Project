extends CharacterBody3D

# =============================================================================
# PLAYER — physics body, animation, state machine.
# Created programmatically by main.gd via set_script + call("init", ...).
#
# Build order (main.gd):
#   1. player_body.call("init", cam)         — builds collision + sprite
#   2. camera_rig.call("init", ..., player_body, player_sprite)
#   3. player_body.set("camera_rig", rig)    — wire back after rig exists
#
# States: IDLE ↔ WALK  (ATTACK / DEATH added with combat system later)
# =============================================================================

const SPRITE_SIZE        : int    = 96
const GRAVITY            : float  = -20.0
const SPRITE_PATH        : String = "res://assets/spritesheets/player/"

# Ares starting stats (STR AGI STA INT SPR RES DEF BMS EXP)
# BMS=3, AGI=4 → mspd = 3 + 4*0.5 = 5.0
const ARES_STATS : Array[int] = [4, 4, 4, 2, 2, 2, 2, 3, 0]

# Basic melee attack
const ATTACK_RANGE    : float = 1.5   # world units
const ATTACK_DAMAGE   : float = 10.0
const ATTACK_COOLDOWN : float = 0.5   # seconds between attacks
const ATTACK_ARC_DOT  : float = 0.3   # min dot product — ~±73° cone

enum State  { IDLE, WALK, ATTACK }
enum Facing { SOUTH, NORTH, EAST, WEST }

const FACING_STR : Dictionary = {
	Facing.SOUTH: "south",
	Facing.NORTH: "north",
	Facing.EAST:  "east",
	Facing.WEST:  "west",
}

# ---------------------------------------------------------------------------
# Public — wired by main.gd after construction
# ---------------------------------------------------------------------------

var sprite        : AnimatedSprite3D  # built in init(), read by main.gd for camera_rig
var cam           : CameraSettings    # set in init()
var camera_rig    : Node3D            # set by main.gd after camera_rig is built
var stats         : Stats             # built in init()

# Set by main.gd each frame to block movement when UI is open
var movement_blocked : bool = false

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var state     : State  = State.IDLE
var facing    : Facing = Facing.SOUTH
var _anim_key : String = "idle_neutral_south"

# Attack
var _attack_timer     : float = 0.0
var _attack_requested : bool  = false


# =============================================================================
# INIT
# =============================================================================

func init(p_cam: CameraSettings) -> void:
	cam   = p_cam
	stats = Stats.new(
		ARES_STATS[0], ARES_STATS[1], ARES_STATS[2], ARES_STATS[3],
		ARES_STATS[4], ARES_STATS[5], ARES_STATS[6], ARES_STATS[7], ARES_STATS[8]
	)
	_build_collision()
	_build_sprite()
	_load_animations()


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius     = 0.40
	shp.height     = 0.90
	col.position.y = shp.height * 0.5
	col.shape      = shp
	add_child(col)


func _build_sprite() -> void:
	sprite            = AnimatedSprite3D.new()
	sprite.name       = "Sprite"
	sprite.billboard  = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 1.0 / 32.0
	sprite.alpha_cut  = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.position.y = SPRITE_SIZE * sprite.pixel_size * 0.5
	add_child(sprite)


func _load_animations() -> void:
	var cached : SpriteFrames = AssetLoader.get_frames(SPRITE_PATH)
	if cached:
		sprite.sprite_frames = cached
		sprite.play("idle_neutral_south")
		return
	var frames := SpriteFrames.new()
	for dir : String in ["south", "north", "east", "west"]:
		_add_strip(frames, "idle_neutral_" + dir, 4.0)
		_add_strip(frames, "walking_" + dir,      8.0)
		_add_strip(frames, "attack_" + dir,       12.0)
	AssetLoader.store_frames(SPRITE_PATH, frames)
	sprite.sprite_frames = frames
	sprite.play("idle_neutral_south")


func _add_strip(frames: SpriteFrames, anim: String, fps: float,
		base_path: String = SPRITE_PATH) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	var path : String = base_path + "%s.png" % anim
	if ResourceLoader.exists(path):
		var sheet      : Texture2D = load(path)
		var frame_count : int      = sheet.get_width() / SPRITE_SIZE
		for i : int in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas  = sheet
			atlas.region = Rect2(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
			frames.add_frame(anim, atlas)
	else:
		frames.add_frame(anim, _make_placeholder(), 0)


# =============================================================================
# PHYSICS LOOP
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_attack_requested = true


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	_handle_movement()
	_handle_attack(delta)
	_sync_anim()
	move_and_slide()

	stats.tick(delta)
	stats.regen(delta)   # always out-of-combat for now; replace with in_combat check later


# =============================================================================
# MOVEMENT
# =============================================================================

func _handle_movement() -> void:
	if movement_blocked or camera_rig == null or state == State.ATTACK:
		velocity.x = 0.0
		velocity.z = 0.0
		if state != State.ATTACK:
			_set_state(State.IDLE)
		return

	var raw := Vector2.ZERO
	if (cam.use_wasd   and Input.is_key_pressed(KEY_W)) or (cam.use_arrows and Input.is_key_pressed(KEY_UP)):    raw.y -= 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_S)) or (cam.use_arrows and Input.is_key_pressed(KEY_DOWN)):  raw.y += 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_A)) or (cam.use_arrows and Input.is_key_pressed(KEY_LEFT)):  raw.x -= 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_D)) or (cam.use_arrows and Input.is_key_pressed(KEY_RIGHT)): raw.x += 1.0

	if raw.length_squared() > 0.0:
		raw = raw.normalized()
		_set_facing_from_input(raw)
		var h     : float   = camera_rig.h_angle
		var fwd   : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
		var right : Vector3 = Vector3( cos(h), 0.0, -sin(h))
		var move  : Vector3 = (fwd * (-raw.y) + right * raw.x) * stats.mspd
		velocity.x = move.x
		velocity.z = move.z
		_set_state(State.WALK)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_state(State.IDLE)


func _set_facing_from_input(raw: Vector2) -> void:
	var new_facing : Facing
	if absf(raw.y) >= absf(raw.x):
		new_facing = Facing.NORTH if raw.y < 0.0 else Facing.SOUTH
	else:
		new_facing = Facing.WEST if raw.x < 0.0 else Facing.EAST
	_set_facing(new_facing)


# =============================================================================
# STATE MACHINE
# =============================================================================

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_rebuild_anim_key()
	_sync_anim()


func _set_facing(new_facing: Facing) -> void:
	if facing == new_facing:
		return
	facing = new_facing
	_rebuild_anim_key()


func _rebuild_anim_key() -> void:
	match state:
		State.IDLE:   _anim_key = "idle_neutral_" + FACING_STR[facing]
		State.WALK:   _anim_key = "walking_"      + FACING_STR[facing]
		State.ATTACK: _anim_key = "attack_"       + FACING_STR[facing]


func _sync_anim() -> void:
	if sprite.animation != _anim_key:
		var loop : bool = state != State.ATTACK
		sprite.sprite_frames.set_animation_loop(_anim_key, loop)
		sprite.play(_anim_key)


# =============================================================================
# COMBAT
# =============================================================================

func _handle_attack(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)

	# Finish attack state when body animation completes
	if state == State.ATTACK and not sprite.is_playing():
		_set_state(State.IDLE)
		return

	if not _attack_requested:
		return
	_attack_requested = false
	if movement_blocked or _attack_timer > 0.0 or state == State.ATTACK:
		return

	_attack_timer = ATTACK_COOLDOWN
	_set_state(State.ATTACK)
	_do_attack()


func _do_attack() -> void:
	var atk_dir : Vector3 = _facing_to_world_dir()
	var atk_pos : Vector3 = global_position
	for node : Node in get_tree().get_nodes_in_group("creatures"):
		var c_pos : Vector3 = node.global_position
		var diff  : Vector3 = c_pos - atk_pos
		diff.y = 0.0
		if diff.length_squared() > ATTACK_RANGE * ATTACK_RANGE:
			continue
		if diff.length_squared() > 0.001 and diff.normalized().dot(atk_dir) < ATTACK_ARC_DOT:
			continue
		node.call("receive_hit", ATTACK_DAMAGE, diff)


func _facing_to_world_dir() -> Vector3:
	if camera_rig == null:
		return Vector3.FORWARD
	var h     : float   = camera_rig.h_angle
	var fwd   : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
	var right : Vector3 = Vector3( cos(h), 0.0, -sin(h))
	match facing:
		Facing.NORTH: return fwd
		Facing.SOUTH: return -fwd
		Facing.EAST:  return right
		Facing.WEST:  return -right
	return fwd


# =============================================================================
# PLACEHOLDER TEXTURE
# =============================================================================

func _make_placeholder() -> ImageTexture:
	var img        := Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	var body_color := Color(0.20, 0.55, 1.0, 1.0)
	var head_color := Color(0.90, 0.72, 0.55, 1.0)
	var s          : int = SPRITE_SIZE
	for y : int in range(s / 3, s):
		for x : int in range(s / 3, s * 2 / 3):
			img.set_pixel(x, y, body_color)
	for y : int in range(s / 8, s / 3):
		for x : int in range(s * 3 / 8, s * 5 / 8):
			img.set_pixel(x, y, head_color)
	return ImageTexture.create_from_image(img)
