extends CharacterBody2D

# =============================================================================
# PLAYER.GD
#
# Responsibilities:
#   - Full state machine: spawn → idle_neutral ↔ idle_attack ↔ walking
#                         forward_slash (attack), death → dead
#   - Read WASD input and move the physics body.
#   - Keep movement direction relative to the camera angle.
#   - Play the correct animation based on state and facing direction.
#
# What this script does NOT do:
#   - Position the visual sprite  (game.gd does that).
#   - Rotate the visual sprite    (game.gd does that).
#   - Set z_index                 (game.gd does that).
# =============================================================================

const SPRITE_SIZE       := 96
const TILE_SIZE         := 32
const SPRITE_PATH       := "res://assets/spritesheets/player/"
const WEAPON_SPRITE_PATH:= "res://assets/spritesheets/weapons/wooden_sword/"
const WEAPON_SPRITES	: Array = ["wooden_sword_attack", "wooden_sword_attack_opposite"]

enum State  { SPAWN, IDLE_NEUTRAL, IDLE_ATTACK, WALKING, FORWARD_SLASH, DEATH, DEAD }
enum Facing { SOUTH, NORTH, EAST, WEST }

const DIRECTIONAL_STATES := {State.IDLE_NEUTRAL: true, 
	State.IDLE_ATTACK: true, State.WALKING: true, State.FORWARD_SLASH: true}
const NON_DIRECTIONAL_STATES := {State.SPAWN: true, State.DEATH: true, State.DEAD: true}
const ONE_SHOT_STATES := {State.SPAWN: true, State.FORWARD_SLASH: true, State.DEATH: true}

# Maps enum State → base animation name (directional states need FACING_STR appended).
const STATE_ANIM_BASE := {
	State.SPAWN         : "spawn",
	State.IDLE_NEUTRAL  : "idle_neutral",
	State.WALKING       : "walking",
	State.IDLE_ATTACK   : "idle_attack",
	State.FORWARD_SLASH : "forward_slash",
	State.DEATH         : "death"
}

# Maps enum Facing → direction string suffix for animation key lookup.
const FACING_STR := {
	Facing.SOUTH: "south", Facing.NORTH: "north",
	Facing.EAST:  "east",  Facing.WEST:  "west"
}

# Rotation offset applied to the sword node so its 90° square sector aligns with the
# attack cone. Derived from the pivot being at the lower-right corner of the 96x96 sprite:
# at 0° the sector spans −90°→−180° (bisector −135°). Required offset = facing_angle + 135°.
const FACING_SWORD_DEG := {
	Facing.SOUTH: -135.0,
	Facing.WEST:   -45.0,
	Facing.NORTH:   45.0,
	Facing.EAST:   135.0,
}


# ── State ──────────────────────────────────────────────────────────────────────

var state     : State  = State.SPAWN
var facing    : Facing = Facing.SOUTH
var in_combat : bool   = false
var anim_done : bool   = false
var alive     : bool   = true
var moving    : bool   = false

# Cached animation key to rebuilt only when state or facing changes.
var _anim_key 		: String = "spawn"

# Cached rotated radian so _handle_movement avoids deg_to_rad every frame.
var _cam_rad 		: float = 0.0
var camera_angle 	: float = 0.0:
	set(value):
		camera_angle = value
		_cam_rad     = deg_to_rad(-value)


# ── References ─────────────────────────────────────────────────────────────────

var sprite       : AnimatedSprite2D		# init game._build_scene().
var weapon_sprite: AnimatedSprite2D		# init game._build_scene().
var stats        : Stats           		# set game._load_json().
var abilities 	 : Array[Ability] = []	# init load_animations().

var sword_facing_deg : float = -135.0	# current sword rotation offset; updated in _set_facing().

# ── Signals ────────────────────────────────────────────────────────────────────

# This signal is connected in game._build_scene() with _on_player_attack().
signal attack(world_pos: Vector2, facing_direction: Vector2)


# =============================================================================
# SETUP
# =============================================================================

# Called: game._ready().
func init(player_sprite: AnimatedSprite2D, weapon_sprite: AnimatedSprite2D) -> void:

	sprite              = player_sprite
	self.weapon_sprite  = weapon_sprite
	stats.effects       = StatusEffect.EffectManager.new()
	abilities.append(Ability.get_ability("player_slash", stats.level))
	
	load_animations()


# Called: init().
func load_animations() -> void:

	var body_cached   := AssetLoader.get_frames(SPRITE_PATH)
	var weapon_cached := AssetLoader.get_frames(WEAPON_SPRITE_PATH)
	if body_cached and weapon_cached:
		sprite.sprite_frames        = body_cached
		weapon_sprite.sprite_frames = weapon_cached
		sprite.animation_finished.connect(_on_anim_finished)
		sprite.play("spawn")
		weapon_sprite.offset  = Vector2(-48.0, -48.0)
		weapon_sprite.visible = false
		weapon_sprite.animation_finished.connect(func(): weapon_sprite.visible = false)
		return

	# Player body sprites.
	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	for state in DIRECTIONAL_STATES:
		var loop : bool = state not in ONE_SHOT_STATES
		for direction in Facing.values():
			var key     : String    = STATE_ANIM_BASE[state] + "_" + FACING_STR[direction]
			var texture : Texture2D = load(SPRITE_PATH + key + ".png")
			_add_strip(frames, key, texture, loop)

	for state in NON_DIRECTIONAL_STATES:
		if not STATE_ANIM_BASE.has(state):	# Guard for State.DEAD does not have animation.
			continue
		var texture : Texture2D = load(SPRITE_PATH + STATE_ANIM_BASE[state] + ".png")
		_add_strip(frames, STATE_ANIM_BASE[state], texture, false)

	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("spawn")
	AssetLoader.store_frames(SPRITE_PATH, frames)

	# Player weapon sprites.
	var weapon_frames := SpriteFrames.new()
	weapon_sprite.sprite_frames = weapon_frames

	for key in WEAPON_SPRITES:
		var texture : Texture2D = load(WEAPON_SPRITE_PATH + key + ".png")
		_add_strip(weapon_frames, key, texture, false)

	weapon_sprite.offset  = Vector2(-48.0, -48.0)
	weapon_sprite.visible = false
	weapon_sprite.animation_finished.connect(func(): weapon_sprite.visible = false)
	AssetLoader.store_frames(WEAPON_SPRITE_PATH, weapon_frames)


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

# Called: _physics_process().
func _sync_anim() -> void:

	if sprite.animation != _anim_key:
		sprite.play(_anim_key)


# Called: sprite.animation_finished signal.
func _on_anim_finished() -> void:

	if state in ONE_SHOT_STATES:
		anim_done = true


# Called: _update_state(), _handle_movement(), resolve_attack(), take_damage().
func _set_state(new_state: State) -> void:

	if state == new_state:
		return
	state     = new_state
	anim_done = false
	if state != State.DEAD:
		_rebuild_anim_key()
		
	if state == State.FORWARD_SLASH:
		weapon_sprite.visible = true
		if facing == Facing.NORTH or facing == Facing.EAST:
			weapon_sprite.play(WEAPON_SPRITES[0])
		else:
			weapon_sprite.play(WEAPON_SPRITES[1])


# Called: _handle_movement().
func _set_facing(new_facing: Facing) -> void:

	if facing == new_facing:
		return
	facing           = new_facing
	sword_facing_deg = FACING_SWORD_DEG[facing]
	_rebuild_anim_key()


# Called: _set_state(), _set_facing().
func _rebuild_anim_key() -> void:

	# Rebuilds the cached animation key when state or facing changes.
	if state in NON_DIRECTIONAL_STATES:
		_anim_key = STATE_ANIM_BASE[state]
	else:
		_anim_key = STATE_ANIM_BASE[state] + "_" + FACING_STR[facing]


# =============================================================================
# STATE MACHINE
# =============================================================================

# Called: _physics_process().
func _update_state() -> void:

	match state:

		# State.WALKING transitions handled in _handle_movement().
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


# =============================================================================
# MOVEMENT
# =============================================================================

# LOOP
func _physics_process(dt: float) -> void:

	# This is before DEAD check because player can be resurected.
	_update_state()

	if state == State.DEAD:
		
		return

	# DEATH state is handled by guarding against ONE_SHOT_STATES.
	_handle_movement()
	# _anim_key is updated by _set_state() and _set_facing()..
	# ..and those are called by _update_state() and _handle_movement().
	_sync_anim()
	
	if state != State.DEATH:
		
		# Update abilities tick timer.
		for ability in abilities:
			ability.tick(dt)
		
		# Update stats ( hp, energy, rage, mp).
		if not in_combat:
			stats.regen(dt)
	
		# Update effects and take dot damage.
		take_damage(stats.update_effects(dt), true)


# Called: _physics_process().
func _handle_movement() -> void:
		
	if state in ONE_SHOT_STATES:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input.y -= 1
	if Input.is_key_pressed(KEY_S): input.y += 1
	if Input.is_key_pressed(KEY_A): input.x -= 1
	if Input.is_key_pressed(KEY_D): input.x += 1

	if input != Vector2.ZERO:
		input = input.normalized()

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
	
	_update_moving()
	move_and_slide()


# Called: _handle_movement().
func _update_moving() -> void:
	
	if velocity != Vector2.ZERO:
		moving = true
	else:
		moving = false


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
	if not abilities[0].check_resources(stats, 0):
		return
	# Signal attack is emmited. So it calls map._on_player_attack().
	attack.emit(position, _facing_world_direction())
	
	
# Called: _try_attack().
func _facing_world_direction() -> Vector2:

	# Converts the screen-space facing cardinal into a world-space unit vector,
	# accounting for the current camera rotation.
	var screen_dir : Vector2
	match facing:
		Facing.SOUTH: screen_dir = Vector2( 0,  1)
		Facing.NORTH: screen_dir = Vector2( 0, -1)
		Facing.EAST:  screen_dir = Vector2( 1,  0)
		Facing.WEST:  screen_dir = Vector2(-1,  0)
	return screen_dir.rotated(_cam_rad)
	
	
# Called: game._on_player_attacked().
func resolve_attack(targets: Array) -> void:

	abilities[0].use(stats, targets, 0.0)
	_set_state(State.FORWARD_SLASH)

	
# Called: ability.use().
func take_damage(raw_damage: float, dot: bool = false, is_magic: bool = false, is_crit: bool = false) -> float:

	var damage : float = stats.take_damage(raw_damage, dot, is_magic, is_crit)
	
	if not stats.is_alive():
		alive = false
		_set_state(State.DEATH)
	
	return damage
