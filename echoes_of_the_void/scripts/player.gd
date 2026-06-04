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
# States: IDLE ↔ WALK ↔ RUN  |  ATTACK (combat)  |  PUSH / GRAB / PULL (interaction)
# =============================================================================

const SPRITE_SIZE        : int    = 96
const GRAVITY            : float  = -20.0
const SPRITE_PATH        : String = "res://assets/spritesheets/player/"

# Ares starting stats (STR AGI STA INT SPR RES DEF BMS EXP)
# BMS=3, AGI=4 → mspd = 3 + 4*0.5 = 5.0
const ARES_STATS : Array[int] = [4, 4, 4, 2, 2, 2, 2, 3, 0]

const ATTACK_ARC_DOT      : float = 0.3   # min dot product — ~±73° cone
const SPRINT_SPEED_MULT   : float = 1.2   # sprint is 20% faster than walking
const SPRINT_ENERGY_COST  : float = 1.0   # energy drained per second while sprinting

# Push / pull
const PUSH_SPEED          : float = 1.8
const PULL_SPEED          : float = 1.3
const GRAB_REACH          : float = 0.7   # max distance to latch onto a pushable block
const PLAYER_CAPSULE_RADIUS : float = 0.40  # must match _build_collision shp.radius

enum State  { IDLE, WALK, RUN, ATTACK, PUSH, GRAB, PULL }
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

# Equipped weapon slots — empty string = unarmed.
# Future values: "sword", "staff", "bow", "dagger", "axe", "spear", ...
var weapon_main : String = ""   # main hand
var weapon_off  : String = ""   # off-hand (shield, second weapon, or empty)

# Abilities
var ability_bar     : Array[Ability] = []   # 10 slots; null = empty
var _slot_requested : int     = -1
var _active_ability : Ability = null

# Combat state
const COMBAT_TIMEOUT      : float = 3.0    # seconds after last hit/attack before regen resumes
const COMBAT_DETECT_RANGE : float = 12.0   # tiles — creatures beyond this don't trigger combat idle
var _combat_timer : float = 0.0

# Knockback
const KNOCKBACK_STRENGTH : float = 6.0
const KNOCKBACK_FRICTION : float = 20.0
var _knockback_vel : Vector3 = Vector3.ZERO

# Push / pull state
var _grabbed_obj        : CharacterBody3D  = null
var _locked_move_dir    : Vector3          = Vector3.ZERO   # cardinal locked on PUSH/PULL entry
var _grab_approach_dir  : Vector3          = Vector3.ZERO   # cardinal player→block at GRAB entry
var _pull_blocked       : bool             = false          # true when block stuck for 2+ frames
var _pull_block_frames  : int              = 0             # consecutive frames block didn't move

# Attack
var _hit_applied : bool = false   # true once damage fires for the current swing


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
	_init_abilities()


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
	sprite.alpha_cut      = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
		_add_strip(frames, "idle_attack_unarmed_" + dir, 8.0)
		_add_strip(frames, "walking_" + dir,      8.0)
		_add_strip(frames, "running_" + dir,      9.6)
		_add_strip(frames, "attack_unarmed_" + dir, 12.0)
		_add_strip(frames, "push_" + dir,         8.0)
		_add_strip(frames, "pull_" + dir,         8.0)
	_add_strip(frames, "grab_north", 4.0)
	AssetLoader.store_frames(SPRITE_PATH, frames)
	sprite.sprite_frames = frames
	sprite.play("idle_neutral_south")


func _init_abilities() -> void:
	ability_bar.resize(10)
	ability_bar[0] = Abilities.get_ability("punch")
	ability_bar[1] = Abilities.get_ability("heavy_strike")


func _add_strip(frames: SpriteFrames, anim: String, fps: float,
		base_path: String = SPRITE_PATH) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	var path : String = base_path + "%s.png" % anim
	if ResourceLoader.exists(path):
		var sheet       : Texture2D = load(path)
		var frame_count : int       = sheet.get_width() / SPRITE_SIZE
		for i : int in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas       = sheet
			atlas.region      = Rect2(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
			atlas.filter_clip = true
			frames.add_frame(anim, atlas)
	else:
		frames.add_frame(anim, _make_placeholder(), 0)


# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	# Shift release — drop grab/push/pull; sprint is handled in _handle_movement
	if not event.pressed and event.keycode == KEY_SHIFT:
		if state == State.GRAB or state == State.PULL or state == State.PUSH:
			_release_grab()
		return

	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1:     _slot_requested = 0
		KEY_2:     _slot_requested = 1
		KEY_3:     _slot_requested = 2
		KEY_4:     _slot_requested = 3
		KEY_5:     _slot_requested = 4
		KEY_6:     _slot_requested = 5
		KEY_7:     _slot_requested = 6
		KEY_8:     _slot_requested = 7
		KEY_9:     _slot_requested = 8
		KEY_0:     _slot_requested = 9
		KEY_SPACE: _slot_requested = 0
		KEY_SHIFT:
			# Grab only from IDLE or WALK — not while already sprinting.
			# If no block is found, normal sprint logic in _handle_movement takes over.
			if state == State.IDLE or state == State.WALK:
				_try_grab()


# =============================================================================
# PHYSICS LOOP
# =============================================================================

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	_handle_movement(delta)
	if state == State.RUN:
		stats.energy = maxf(0.0, stats.energy - SPRINT_ENERGY_COST * delta)
	_handle_attack(delta)

	if _knockback_vel.length_squared() > 0.01:
		velocity.x += _knockback_vel.x
		velocity.z += _knockback_vel.z
		_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, KNOCKBACK_FRICTION * delta)
	else:
		_knockback_vel = Vector3.ZERO

	_sync_anim()
	move_and_slide()   # player moves first

	# PULL: block follows AFTER player has cleared the path — avoids player-as-obstacle collision
	if state == State.PULL:
		_drive_pulled_block(delta)

	stats.tick(delta)
	_combat_timer = maxf(0.0, _combat_timer - delta)
	if _combat_timer <= 0.0:
		stats.regen(delta)


# =============================================================================
# COMBAT DETECTION
# =============================================================================

# Returns true if any creature within COMBAT_DETECT_RANGE is in an aggressive state,
# OR if the combat timer is still counting down from a recent hit/attack.
func _is_in_combat() -> bool:
	if _combat_timer > 0.0:
		return true
	var range_sq : float = COMBAT_DETECT_RANGE * COMBAT_DETECT_RANGE
	for node : Node in get_tree().get_nodes_in_group("creatures"):
		var diff : Vector3 = node.global_position - global_position
		diff.y = 0.0
		if diff.length_squared() > range_sq:
			continue
		if node.get("in_combat"):
			return true
	return false


# =============================================================================
# MOVEMENT
# =============================================================================

func _handle_movement(delta: float) -> void:
	if movement_blocked or camera_rig == null:
		velocity.x = 0.0
		velocity.z = 0.0
		if state != State.ATTACK:
			_release_grab()
		return

	if state == State.ATTACK:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	if state == State.PUSH:
		_do_push_movement(delta)
		return

	if state == State.GRAB:
		_do_grab_idle()
		return

	if state == State.PULL:
		_do_pull_movement(delta)
		return

	var raw : Vector2 = _read_raw_input()

	if raw.length_squared() > 0.0:
		raw = raw.normalized()
		_set_facing_from_input(raw)
		var h         : float   = camera_rig.h_angle
		var fwd       : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
		var right     : Vector3 = Vector3( cos(h), 0.0, -sin(h))
		var sprinting : bool    = Input.is_key_pressed(KEY_SHIFT) and stats.energy > 0.0
		var speed     : float   = stats.mspd * (SPRINT_SPEED_MULT if sprinting else 1.0)
		var move      : Vector3 = (fwd * (-raw.y) + right * raw.x) * speed
		velocity.x = move.x
		velocity.z = move.z
		_set_state(State.RUN if sprinting else State.WALK)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_state(State.IDLE)


func _read_raw_input() -> Vector2:
	var raw := Vector2.ZERO
	if (cam.use_wasd   and Input.is_key_pressed(KEY_W)) or (cam.use_arrows and Input.is_key_pressed(KEY_UP)):    raw.y -= 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_S)) or (cam.use_arrows and Input.is_key_pressed(KEY_DOWN)):  raw.y += 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_A)) or (cam.use_arrows and Input.is_key_pressed(KEY_LEFT)):  raw.x -= 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_D)) or (cam.use_arrows and Input.is_key_pressed(KEY_RIGHT)): raw.x += 1.0
	return raw


func _set_facing_from_input(raw: Vector2) -> void:
	var new_facing : Facing
	if absf(raw.y) >= absf(raw.x):
		new_facing = Facing.NORTH if raw.y < 0.0 else Facing.SOUTH
	else:
		new_facing = Facing.WEST if raw.x < 0.0 else Facing.EAST
	_set_facing(new_facing)


func _set_facing_from_world_dir(world_dir: Vector3) -> void:
	if camera_rig == null:
		return
	var h     : float   = camera_rig.h_angle
	var fwd   : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
	var right : Vector3 = Vector3( cos(h), 0.0, -sin(h))
	var raw   := Vector2(world_dir.dot(right), -world_dir.dot(fwd))
	if raw.length_squared() > 0.001:
		_set_facing_from_input(raw.normalized())


# =============================================================================
# PUSH / PULL
# =============================================================================

# Snaps a flat world direction to the nearest cardinal (+X -X +Z -Z).
func _snap_to_cardinal(v: Vector3) -> Vector3:
	if absf(v.x) >= absf(v.z):
		return Vector3(sign(v.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, sign(v.z))


# Snaps a camera-space 2D direction to the nearest cardinal using Y-tiebreaker.
# Matches _set_facing_from_input — so animation direction change and input validity
# change at the exact same camera angle during rotation.
func _snap_cam(v: Vector2) -> Vector2:
	if absf(v.y) >= absf(v.x):
		return Vector2(0.0, signf(v.y))
	return Vector2(signf(v.x), 0.0)


# Returns the snapped cardinal (player→block) if the player is squarely in front
# of one face and within max_face_dist of that face. Returns ZERO otherwise.
# "In front of a face" means lateral offset < block.half_size (not from a corner).
func _get_face_approach(block: Node, max_face_dist: float) -> Vector3:
	var half    : float   = block.get("half_size") if "half_size" in block else 1.0
	var diff    : Vector3 = block.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() < 0.001:
		return Vector3.ZERO
	var cardinal      : Vector3 = _snap_to_cardinal(diff)
	var approach_dist : float   = diff.dot(cardinal)          # depth along approach axis
	var face_dist     : float   = approach_dist - half        # distance from player to face
	# Cross product magnitude = lateral offset from face centre.
	# Two implicit rays at ±D from player centre must both land on the face — this is
	# the grab alignment gate.  D = 0.60 means the player centre must be within 0.40
	# units of the block face centre (on a standard 2-unit-wide block), ensuring both
	# hands visually contact the block.
	# For blocks narrower than 2*D (half < D), require player centre on the face instead
	# so small objects can still be grabbed with careful centering.
	var perp          : float   = absf(diff.x * cardinal.z - diff.z * cardinal.x)
	if face_dist < -0.1 or face_dist > max_face_dist:
		return Vector3.ZERO
	var D             : float   = PLAYER_CAPSULE_RADIUS * 1.5   # 0.60 — strict hand alignment
	var align_limit   : float   = half - D if half > D else half
	if perp >= align_limit:
		return Vector3.ZERO
	return cardinal


func _try_grab() -> void:
	# Find the nearest pushable block whose face the player is squarely in front of.
	# Also collect a snap candidate: a block the player is on-face but not yet aligned with.
	# If no clean grab is found, the player is nudged laterally onto the centre line.
	var best_face_dist  : float           = GRAB_REACH
	var best_block      : CharacterBody3D = null
	var best_cardinal   : Vector3         = Vector3.ZERO

	var snap_block      : CharacterBody3D = null
	var snap_cardinal   : Vector3         = Vector3.ZERO
	var snap_offset     : Vector3         = Vector3.ZERO
	var snap_face_dist  : float           = GRAB_REACH

	for node : Node in get_tree().get_nodes_in_group("pushable"):
		var half     : float   = node.get("half_size") if "half_size" in node else 1.0
		var diff     : Vector3 = node.global_position - global_position
		diff.y = 0.0
		if diff.length_squared() < 0.001:
			continue

		var cardinal : Vector3 = _get_face_approach(node, GRAB_REACH)

		if cardinal != Vector3.ZERO:
			# Clean grab candidate — alignment already passes.
			var face_dist : float = diff.dot(cardinal) - half
			if face_dist < best_face_dist:
				best_face_dist = face_dist
				best_block     = node as CharacterBody3D
				best_cardinal  = cardinal
			continue

		# Alignment failed — check if this is a snap candidate:
		# player must be within reach, on the face (not past a corner), and facing the block.
		var snap_card     : Vector3 = _snap_to_cardinal(diff)
		var approach_dist : float   = diff.dot(snap_card)
		var face_dist     : float   = approach_dist - half
		if face_dist < -0.1 or face_dist > GRAB_REACH:
			continue
		var perp : float = absf(diff.x * snap_card.z - diff.z * snap_card.x)
		if perp >= half:
			continue   # off the corner — player is not in front of this face at all
		if _facing_to_world_dir().dot(snap_card) < 0.5:
			continue
		if face_dist < snap_face_dist:
			snap_face_dist = face_dist
			snap_block     = node as CharacterBody3D
			snap_cardinal  = snap_card
			# Move only the minimum needed to pass the alignment threshold —
			# not all the way to centre.  lateral_vec points from player toward
			# the block's centre line; its magnitude is perp.
			var lateral_vec : Vector3 = diff - diff.dot(snap_card) * snap_card
			var D_s         : float   = PLAYER_CAPSULE_RADIUS * 1.5
			var limit       : float   = half - D_s if half > D_s else half
			var move_dist   : float   = perp - limit + 0.01   # just past the threshold
			snap_offset = lateral_vec.normalized() * move_dist if perp > 0.001 else Vector3.ZERO

	# Prefer a clean grab; fall back to a snapped one.
	if best_block == null:
		if snap_block == null:
			return
		# Slide player onto the block's centre line — imperceptible at play speed.
		global_position.x += snap_offset.x
		global_position.z += snap_offset.z
		best_block    = snap_block
		best_cardinal = snap_cardinal

	if _facing_to_world_dir().dot(best_cardinal) < 0.5:
		return
	_grabbed_obj       = best_block
	_grab_approach_dir = best_cardinal
	_set_facing_from_world_dir(best_cardinal)
	_set_state(State.GRAB)


func _release_grab() -> void:
	if _grabbed_obj != null and is_instance_valid(_grabbed_obj):
		_grabbed_obj.set("_driven", false)
	_grabbed_obj = null
	_set_state(State.IDLE)


func _do_push_movement(delta: float) -> void:
	if _grabbed_obj == null or not is_instance_valid(_grabbed_obj):
		_grabbed_obj = null
		_set_state(State.IDLE)
		return

	# Shift released → drop the block entirely
	if not Input.is_key_pressed(KEY_SHIFT):
		velocity.x = 0.0
		velocity.z = 0.0
		_release_grab()
		return

	# Re-evaluate input against the CURRENT camera angle every frame.
	# If no key is held, or the held key no longer maps to the push direction
	# (camera may have rotated), return to GRAB.
	var raw_p : Vector2 = _read_raw_input()
	if raw_p.length_squared() == 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_state(State.GRAB)
		return
	var h_p     : float   = camera_rig.h_angle
	var fwd_p   : Vector3 = Vector3(-sin(h_p), 0.0, -cos(h_p))
	var right_p : Vector3 = Vector3( cos(h_p), 0.0, -sin(h_p))
	# Camera-space snap with Y-tiebreaker — matches _set_facing_from_input exactly,
	# so the direction validity check fires at the same camera angle as the animation change.
	var cam_lock_p  : Vector2 = Vector2(_locked_move_dir.dot(right_p), -_locked_move_dir.dot(fwd_p))
	var snap_lock_p : Vector2 = _snap_cam(cam_lock_p)
	var snap_in_p   : Vector2 = _snap_cam(raw_p)
	if snap_in_p != snap_lock_p:
		velocity.x = 0.0
		velocity.z = 0.0
		# Opposite key = pull direction — skip GRAB, transition directly.
		if snap_in_p == -snap_lock_p:
			_pull_blocked    = false
			_pull_block_frames = 0
			_locked_move_dir = -_grab_approach_dir
			_grabbed_obj.set("_driven", true)
			velocity.x       = _locked_move_dir.x * PULL_SPEED
			velocity.z       = _locked_move_dir.z * PULL_SPEED
			_set_state(State.PULL)
		else:
			_set_state(State.GRAB)
		return

	# Drive block first so it clears the path for the player
	_grabbed_obj.set("_driven", true)
	if not _grabbed_obj.is_on_floor():
		_grabbed_obj.velocity.y += GRAVITY * delta
	else:
		_grabbed_obj.velocity.y = 0.0
	_grabbed_obj.velocity.x = _locked_move_dir.x * PUSH_SPEED
	_grabbed_obj.velocity.z = _locked_move_dir.z * PUSH_SPEED
	_grabbed_obj.move_and_slide()

	velocity.x = _locked_move_dir.x * PUSH_SPEED
	velocity.z = _locked_move_dir.z * PUSH_SPEED
	_set_facing_from_world_dir(_locked_move_dir)


func _do_grab_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _grabbed_obj == null or not is_instance_valid(_grabbed_obj):
		_release_grab()
		return
	if not Input.is_key_pressed(KEY_SHIFT):
		_release_grab()
		return
	# Keep facing toward the block as camera rotates
	_set_facing_from_world_dir(_grab_approach_dir)

	var raw : Vector2 = _read_raw_input()
	if raw.length_squared() == 0.0:
		return   # no input — stay in GRAB (frozen frame 0)

	# Convert camera-relative input to world cardinal
	var h       : float   = camera_rig.h_angle
	var fwd     : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
	var right   : Vector3 = Vector3( cos(h), 0.0, -sin(h))
	var move    : Vector3 = (fwd * (-raw.y) + right * raw.x).normalized()
	var snapped : Vector3 = _snap_to_cardinal(move)
	var dot     : float   = snapped.dot(_grab_approach_dir)

	if dot > 0.5:
		# Key points toward block → PUSH
		_locked_move_dir = _grab_approach_dir
		_set_state(State.PUSH)
	elif dot < -0.5:
		# Key points away from block → PULL.
		# Set velocity NOW so the player moves this same frame before _drive_pulled_block
		# runs.  Without this, the player stays stationary on the transition frame and
		# the block immediately collides with the player capsule, setting _pull_blocked.
		_pull_blocked    = false
		_pull_block_frames = 0
		_locked_move_dir = -_grab_approach_dir
		_grabbed_obj.set("_driven", true)          # suppress block's own physics at once
		velocity.x       = _locked_move_dir.x * PULL_SPEED
		velocity.z       = _locked_move_dir.z * PULL_SPEED
		_set_state(State.PULL)
	# Perpendicular key → silently ignored, player stays in GRAB


func _do_pull_movement(delta: float) -> void:
	if _grabbed_obj == null or not is_instance_valid(_grabbed_obj):
		_release_grab()
		return

	# Release if Shift lifted
	if not Input.is_key_pressed(KEY_SHIFT):
		_release_grab()
		return

	# Lose grip if block got too far (e.g., hit by something)
	var to_block : Vector3 = _grabbed_obj.global_position - global_position
	to_block.y = 0.0
	if to_block.length_squared() > (GRAB_REACH + 1.5) * (GRAB_REACH + 1.5):
		_release_grab()
		return

	# Re-evaluate input against the CURRENT camera angle every frame.
	# If no key is held, or the held key no longer maps to the pull direction
	# (camera may have rotated), return to GRAB.
	var raw_l : Vector2 = _read_raw_input()
	if raw_l.length_squared() == 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_pull_blocked = false
		_pull_block_frames = 0
		_set_state(State.GRAB)
		return
	var h_l     : float   = camera_rig.h_angle
	var fwd_l   : Vector3 = Vector3(-sin(h_l), 0.0, -cos(h_l))
	var right_l : Vector3 = Vector3( cos(h_l), 0.0, -sin(h_l))
	# Camera-space snap with Y-tiebreaker — matches _set_facing_from_input exactly,
	# so the direction validity check fires at the same camera angle as the animation change.
	var cam_lock_l  : Vector2 = Vector2(_locked_move_dir.dot(right_l), -_locked_move_dir.dot(fwd_l))
	var snap_lock_l : Vector2 = _snap_cam(cam_lock_l)
	var snap_in_l   : Vector2 = _snap_cam(raw_l)
	if snap_in_l != snap_lock_l:
		velocity.x = 0.0
		velocity.z = 0.0
		_pull_blocked = false
		_pull_block_frames = 0
		# Opposite key = push direction — skip GRAB, transition directly.
		if snap_in_l == -snap_lock_l:
			_locked_move_dir = _grab_approach_dir
			_set_state(State.PUSH)
		else:
			_set_state(State.GRAB)
		return

	# Mark block as driven — suppresses its own physics while player controls it.
	# Actual block movement happens in _drive_pulled_block(), called AFTER
	# player.move_and_slide() so the player clears the path first.
	_grabbed_obj.set("_driven", true)

	# If the block was blocked last frame, freeze the player too so they don't
	# drift away from a stuck block.  _drive_pulled_block clears _pull_blocked
	# when the block successfully moves again.
	if _pull_blocked:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		velocity.x = _locked_move_dir.x * PULL_SPEED
		velocity.z = _locked_move_dir.z * PULL_SPEED

	# Face toward the block while pulling
	if to_block.length_squared() > 0.001:
		_set_facing_from_world_dir(to_block.normalized())


# Called from _physics_process AFTER player.move_and_slide() so the player has
# already stepped clear before the block tries to enter that space.
func _drive_pulled_block(delta: float) -> void:
	if _grabbed_obj == null or not is_instance_valid(_grabbed_obj):
		return
	if not _grabbed_obj.is_on_floor():
		_grabbed_obj.velocity.y += GRAVITY * delta
	else:
		_grabbed_obj.velocity.y = 0.0
	_grabbed_obj.velocity.x = _locked_move_dir.x * PULL_SPEED
	_grabbed_obj.velocity.z = _locked_move_dir.z * PULL_SPEED

	var pre_pos : Vector3 = _grabbed_obj.global_position
	_grabbed_obj.move_and_slide()

	# Use position delta (not velocity) to detect a blocked block.
	# Velocity after move_and_slide() can be unreliable — the position never lies.
	var moved : Vector3 = _grabbed_obj.global_position - pre_pos
	var moved_along : float = moved.dot(Vector3(_locked_move_dir.x, 0.0, _locked_move_dir.z))
	# Require 2 consecutive stuck frames before freezing the player.
	# One stuck frame is normal on the first pull frame (zero-gap capsule contact with the
	# block — the player hasn't cleared the path yet).  A real wall stays stuck every frame.
	if moved_along < PULL_SPEED * delta * 0.3:
		_pull_block_frames += 1
	else:
		_pull_block_frames = 0
	_pull_blocked = _pull_block_frames >= 2


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
		State.IDLE:
			if _is_in_combat():
				var style : String = weapon_main if weapon_main != "" else "unarmed"
				_anim_key = "idle_attack_" + style + "_" + FACING_STR[facing]
			else:
				_anim_key = "idle_neutral_" + FACING_STR[facing]
		State.WALK:   _anim_key = "walking_"      + FACING_STR[facing]
		State.RUN:    _anim_key = "running_"      + FACING_STR[facing]
		State.ATTACK:
			var style : String = weapon_main if weapon_main != "" else "unarmed"
			_anim_key = "attack_" + style + "_" + FACING_STR[facing]
		State.PUSH:   _anim_key = "push_"         + FACING_STR[facing]
		State.GRAB:   _anim_key = "grab_north" if facing == Facing.NORTH else "pull_" + FACING_STR[facing]
		State.PULL:   _anim_key = "pull_"         + FACING_STR[facing]


func _sync_anim() -> void:
	# IDLE anim depends on combat state which changes over time (timer / creature states),
	# not just on state/facing transitions — rebuild every frame so it stays current.
	if state == State.IDLE:
		_rebuild_anim_key()
	if sprite.animation != _anim_key:
		var loop : bool = state != State.ATTACK
		sprite.sprite_frames.set_animation_loop(_anim_key, loop)
		sprite.play(_anim_key)
	# GRAB: freeze pull anim at frame 0 (visual latch indicator)
	if state == State.GRAB:
		if sprite.is_playing():
			sprite.pause()
			sprite.frame = 0
		return
	# PULL: GRAB and PULL share the same anim key — if we just left GRAB the
	# sprite is still paused, so explicitly resume it here.
	if state == State.PULL and not sprite.is_playing():
		sprite.play(_anim_key)


# =============================================================================
# COMBAT
# =============================================================================

func _handle_attack(delta: float) -> void:
	for ab : Ability in ability_bar:
		if ab != null:
			ab.tick(delta)

	if state == State.ATTACK:
		# Fire damage at the designated frame — same mechanic as creature.gd
		if not _hit_applied and sprite.frame >= _active_ability.hit_frame:
			_hit_applied = true
			_do_attack()
		if not sprite.is_playing():
			_set_state(State.IDLE)
		return

	if _slot_requested < 0:
		return
	var slot : int = _slot_requested
	_slot_requested = -1

	if movement_blocked or state == State.ATTACK:
		return
	var ab : Ability = ability_bar[slot] if slot < ability_bar.size() else null
	if ab == null or not ab.can_use(stats):
		return

	_hit_applied     = false
	_active_ability  = ab
	_combat_timer    = COMBAT_TIMEOUT
	ab.spend(stats)
	_set_state(State.ATTACK)


func receive_hit(damage: float, knockback_dir: Vector3) -> void:
	stats.take_damage(damage)
	_combat_timer = COMBAT_TIMEOUT
	_start_hit_flash()
	if state == State.GRAB or state == State.PULL or state == State.PUSH:
		_release_grab()
	_apply_knockback(knockback_dir)


func _start_hit_flash() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.0, 0.15, 0.15, 1.0), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE,                  0.10)


func _apply_knockback(dir: Vector3) -> void:
	var flat : Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0:
		_knockback_vel = flat.normalized() * KNOCKBACK_STRENGTH


func _do_attack() -> void:
	if _active_ability == null:
		return
	var range_sq : float   = _active_ability.range_ * _active_ability.range_
	var atk_dir  : Vector3 = _facing_to_world_dir()
	var atk_pos  : Vector3 = global_position
	for node : Node in get_tree().get_nodes_in_group("creatures"):
		var c_pos : Vector3 = node.global_position
		var diff  : Vector3 = c_pos - atk_pos
		diff.y = 0.0
		if diff.length_squared() > range_sq:
			continue
		if diff.length_squared() > 0.001 and diff.normalized().dot(atk_dir) < ATTACK_ARC_DOT:
			continue
		node.call("receive_hit", _active_ability.calc_damage(stats), diff)


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
