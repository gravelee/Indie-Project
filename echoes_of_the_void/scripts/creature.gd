extends CharacterBody3D

# =============================================================================
# CREATURE — base for all enemy/neutral entities.
# Created programmatically by main.gd via set_script + call("init", ...).
#
# Phase 1: IDLE_NEUTRAL ↔ WANDER only.
# Combat states (NOTICE, CHASE, ATTACK, DEATH…) added with combat system.
#
# Facing — 4 cases from 2 sprites + flip_h:
#   wander_front.png  (drawn: front-right) flip_h=false → front-right
#                                          flip_h=true  → front-left
#   wander_back.png   (drawn: back-right)  flip_h=false → back-right
#                                          flip_h=true  → back-left
#
# front/back determined by: _move_dir.dot(cam_forward) > 0 → moving away = back
# left/right  determined by: _move_dir.dot(cam_right)  > 0 → moving right → flip_h=false (no flip)
# =============================================================================

const SPRITE_SIZE : int    = 96
const SPRITE_PATH : String = "res://assets/spritesheets/creatures/"
const ANIM_SPEED  : int    = 8
const GRAVITY     : float  = -20.0

# Wander timing (seconds)
const WANDER_INTERVAL_MIN : float = 0.9
const WANDER_INTERVAL_MAX : float = 1.1
const WANDER_DURATION_MIN : float = 0.5
const WANDER_DURATION_MAX : float = 3.0
const WANDER_CHANCE       : float = 1.0   # probability of starting a wander on interval tick

const KNOCKBACK_STRENGTH : float = 8.0   # initial knockback velocity (world units/s)
const KNOCKBACK_FRICTION : float = 25.0  # deceleration per second

enum State { IDLE_NEUTRAL, WANDER, DEAD }

# ---------------------------------------------------------------------------
# Public refs — set by init()
# ---------------------------------------------------------------------------
var sprite     : AnimatedSprite3D
var stats      : Stats
var camera_rig : Node3D

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var type        : String = "rat"
var sprite_path : String = ""

var state        : State   = State.IDLE_NEUTRAL
var facing_right : bool    = false
var facing_back  : bool    = false
var _move_dir    : Vector3 = Vector3.BACK   # last known move direction

# Wander
var _wander_timer    : float   = 0.0
var _wander_interval : float   = 1.0
var _wander_elapsed  : float   = 0.0
var _wander_duration : float   = 1.0
var _wander_dir      : Vector3 = Vector3.ZERO
var _force_wander    : bool    = false

# Combat
var _knockback_vel : Vector3 = Vector3.ZERO
var _fading        : bool    = false


# =============================================================================
# INIT
# =============================================================================

func init(p_type: String, p_camera_rig: Node3D) -> void:
	type        = p_type
	sprite_path = SPRITE_PATH + type + "/"
	camera_rig  = p_camera_rig
	add_to_group("creatures")

	var s : Array = _stat_preset(type)
	stats = Stats.new(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8])

	# Stagger wander start times so creatures don't all move at once
	_wander_timer    = randf_range(0.0, 1.0)
	_wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)

	_build_collision()
	_build_sprite()
	_load_animations()


func _stat_preset(p_type: String) -> Array:
	# [STR, AGI, STA, INT, SPR, RES, DEF, BMS, EXP]
	# mspd = BMS + AGI * 0.5
	match p_type:
		"rat":   return [1, 1, 5, 0, 0, 0, 0, 2, 10]   # mspd = 2.5
		"snake": return [2, 2, 3, 0, 0, 0, 0, 2, 15]   # mspd = 3.0
		_:       return [1, 1, 5, 0, 0, 0, 0, 2, 10]


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius     = 0.30
	shp.height     = 0.70
	col.position.y = shp.height * 0.5
	col.shape      = shp
	add_child(col)


func _build_sprite() -> void:
	sprite            = AnimatedSprite3D.new()
	sprite.name       = "Sprite"
	sprite.billboard  = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 1.0 / 32.0
	sprite.alpha_cut  = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.position.y = float(SPRITE_SIZE) * sprite.pixel_size * 0.5   # adjusted after load
	add_child(sprite)


func _load_animations() -> void:
	var cached : SpriteFrames = AssetLoader.get_frames(sprite_path)
	if cached:
		sprite.sprite_frames = cached
		sprite.play("idle_neutral_front")
		_compute_sprite_offset()
		return

	var frames := SpriteFrames.new()
	# wander_back is optional — loaded when the file exists, skipped otherwise
	for anim : String in ["idle_neutral_front", "idle_neutral_back", "wander_front", "wander_back"]:
		var path : String = sprite_path + anim + ".png"
		if not ResourceLoader.exists(path):
			continue
		var tex         : Texture2D = load(path)
		var frame_count : int       = tex.get_width() / SPRITE_SIZE
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(ANIM_SPEED))
		frames.set_animation_loop(anim, true)
		for i : int in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas  = tex
			atlas.region = Rect2(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
			frames.add_frame(anim, atlas)

	AssetLoader.store_frames(sprite_path, frames)
	sprite.sprite_frames = frames
	sprite.play("idle_neutral_front")
	_compute_sprite_offset()


func _compute_sprite_offset() -> void:
	# Scans idle_neutral first frame for transparent bottom rows and adjusts
	# sprite.position.y so the bottom of the painted area sits at y=0 (feet).
	var path : String = sprite_path + "idle_neutral_front.png"
	if not ResourceLoader.exists(path):
		return
	var tex          : Texture2D = load(path)
	var img          := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var first_frame  := img.get_region(Rect2i(0, 0, SPRITE_SIZE, SPRITE_SIZE))
	var empty_bottom : int = SPRITE_SIZE - first_frame.get_used_rect().end.y
	sprite.position.y = (float(SPRITE_SIZE) / 2.0 - float(empty_bottom)) * sprite.pixel_size


# =============================================================================
# PHYSICS LOOP
# =============================================================================

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	_update_state(delta)

	# Apply and decay knockback impulse
	if _knockback_vel.length_squared() > 0.01:
		velocity.x += _knockback_vel.x
		velocity.z += _knockback_vel.z
		_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, KNOCKBACK_FRICTION * delta)
	else:
		_knockback_vel = Vector3.ZERO

	_update_facing()
	_sync_anim()
	move_and_slide()

	# Wander collision recovery — only on wall/obstacle hits, not floor contact
	if state == State.WANDER:
		for i : int in get_slide_collision_count():
			if get_slide_collision(i).get_normal().y < 0.5:
				_force_wander = true
				break

	stats.tick(delta)
	stats.regen(delta)


# =============================================================================
# STATE MACHINE
# =============================================================================

func _update_state(delta: float) -> void:
	match state:
		State.DEAD:
			velocity.x = 0.0
			velocity.z = 0.0
			return

		State.IDLE_NEUTRAL:
			velocity.x = 0.0
			velocity.z = 0.0
			_wander_timer += delta
			if _wander_timer >= _wander_interval:
				_wander_timer    = 0.0
				_wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
				if randf() < WANDER_CHANCE:
					_force_wander = true
					_set_state(State.WANDER)

		State.WANDER:
			if _force_wander:
				_force_wander    = false
				var angle        : float   = randf() * TAU
				_wander_dir      = Vector3(sin(angle), 0.0, cos(angle))
				_wander_elapsed  = 0.0
				_wander_duration = randf_range(WANDER_DURATION_MIN, WANDER_DURATION_MAX)

			_wander_elapsed += delta
			velocity.x = _wander_dir.x * stats.mspd
			velocity.z = _wander_dir.z * stats.mspd
			_move_dir  = _wander_dir

			if _wander_elapsed >= _wander_duration:
				_set_state(State.IDLE_NEUTRAL)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state


# =============================================================================
# FACING + ANIMATION
# =============================================================================

func _update_facing() -> void:
	if state == State.DEAD or camera_rig == null or _move_dir == Vector3.ZERO:
		return
	var h           : float   = camera_rig.h_angle
	var cam_right   : Vector3 = Vector3( cos(h), 0.0, -sin(h))
	var cam_forward : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
	facing_right  = _move_dir.dot(cam_right)   > 0.0   # left/right → flip_h
	facing_back   = _move_dir.dot(cam_forward) > 0.0   # away from camera → back anim
	sprite.flip_h = !facing_right  # sprites drawn facing right — flip when moving left


func _sync_anim() -> void:
	if state == State.DEAD:
		return
	var target : String
	if state == State.WANDER:
		if facing_back and sprite.sprite_frames.has_animation("wander_back"):
			target = "wander_back"
		else:
			target = "wander_front"
	else:
		if facing_back and sprite.sprite_frames.has_animation("idle_neutral_back"):
			target = "idle_neutral_back"
		else:
			target = "idle_neutral_front"
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(target):
		if sprite.animation != target:
			sprite.play(target)


# =============================================================================
# COMBAT
# =============================================================================

func receive_hit(damage: float, knockback_dir: Vector3) -> void:
	if state == State.DEAD:
		return
	stats.take_damage(damage)
	_start_hit_flash()
	_apply_knockback(knockback_dir)
	if not stats.is_alive():
		_enter_dead()


func _start_hit_flash() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.0, 0.15, 0.15, 1.0), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE,                  0.10)


func _apply_knockback(dir: Vector3) -> void:
	var flat : Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0:
		_knockback_vel = flat.normalized() * KNOCKBACK_STRENGTH


func _enter_dead() -> void:
	state      = State.DEAD
	velocity   = Vector3.ZERO
	_knockback_vel = Vector3.ZERO
	_start_death_fade()


func _start_death_fade() -> void:
	if _fading:
		return
	_fading = true
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: queue_free())
