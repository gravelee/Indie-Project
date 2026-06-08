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

const PROP_REACT_LAYER    : int   = 4     # matches WorldProp.PROP_REACT_LAYER
const ATTACK_ARC_DOT      : float = 0.3   # min dot product — ~±73° cone
const SPRINT_SPEED_MULT   : float = 1.2   # sprint is 20% faster than walking
const SPRINT_ENERGY_COST  : float = 1.0   # energy drained per second while sprinting
const RESPAWN_DELAY       : float = 3.0   # seconds after death before respawn

# Push / pull
const PUSH_SPEED          : float = 1.8
const PULL_SPEED          : float = 1.3
const GRAB_REACH          : float = 0.7   # max distance to latch onto a pushable block
const PLAYER_CAPSULE_RADIUS : float = 0.40  # must match _build_collision shp.radius

enum State     { IDLE, WALK, RUN, ATTACK, JUMP, PUSH, GRAB, PULL, SPAWN, DEAD }
enum Facing    { SOUTH, NORTH, EAST, WEST }
enum JumpPhase { WINDUP, RISE, FALL, LAND1, LAND2 }

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

# Attack range visual
var show_attack_range : bool = false:   # toggled from settings — off by default
	set(value):
		show_attack_range = value
		if _target != null:
			_target.call("set_target_dot_visible", value)
		if not value:
			_hide_attack_range()
var _atk_range_node : MeshInstance3D    = null
var _atk_range_mat  : StandardMaterial3D = null

# Abilities
var ability_bar     : Array[Ability] = []   # 10 slots; null = empty
var _slot_requested : int     = -1
var _active_ability : Ability = null

# Combat state
const COMBAT_TIMEOUT      : float = 3.0    # seconds after last creature hit/received — drives idle_attack
const REGEN_PAUSE         : float = 3.0    # seconds after ANY action (attack, roll, etc.) — pauses regen
const COMBAT_DETECT_RANGE : float = 12.0   # tiles — creatures beyond this don't trigger combat idle
const TAB_TARGET_RANGE    : float = 40.0   # max range for Tab targeting (world units)
var _combat_timer : float = 0.0   # set only on creature interaction
var _regen_timer  : float = 0.0   # set on any player action

# Target system
var _target     : Node         = null   # current targeted creature (null = no target)
var _tab_buffer : Array[Node]  = []     # creatures visited this tab session
var _tab_tier   : int          = 0      # 0 = unset, 1 = on-screen, 2 = off-screen fallback

# Knockback
const KNOCKBACK_STRENGTH  : float = 6.0
const KNOCKBACK_FRICTION  : float = 20.0
const KNOCKBACK_AIR_SCALE : float = 0.10   # airborne knockback is weaker — no ground friction to counter it
var _knockback_vel : Vector3 = Vector3.ZERO

# Active status effects
var _effects : Dictionary = {}   # effect_id → StatusEffect

# Sprint energy drain — accumulates run-time across Shift taps to prevent free-running exploit
var _run_energy_accum : float = 0.0

# Camera rotation tracking — rotation counts as movement for prop reactions
var _prev_h_angle : float = 0.0

# Push / pull state
var _grabbed_obj        : CharacterBody3D  = null
var _locked_move_dir    : Vector3          = Vector3.ZERO   # cardinal locked on PUSH/PULL entry
var _grab_approach_dir  : Vector3          = Vector3.ZERO   # cardinal player→block at GRAB entry
var _pull_blocked       : bool             = false          # true when block stuck for 2+ frames
var _pull_block_frames  : int              = 0             # consecutive frames block didn't move

# Spawn / death
var is_dead          : bool             = false   # true during DEAD + SPAWN — creatures ignore player
var _pending_death   : bool             = false   # true when killed mid-air; DEAD deferred until landing
var _collision_shape : CollisionShape3D = null   # stored to disable on death
var _spawn_position  : Vector3          = Vector3.ZERO   # recorded in init(); respawn target
var _initial_hp      : float            = 0.0    # resource snapshot at first spawn
var _initial_energy  : float            = 0.0
var _initial_flow    : float            = 0.0
var _initial_focus   : float            = 0.0
var _dead_timer      : float            = 0.0

# Attack
var _hit_applied : bool = false   # true once damage fires for the current swing

# Jump — real Y velocity; frames driven per JumpPhase, not by AnimationPlayer
# JUMP_VEL = sqrt(2 * |GRAVITY| * peak_h), peak_h = SPRITE_SIZE/2/32 = 1.5 units → ≈7.75
const JUMP_VEL        : float = 7.75
var _jump_phase       : JumpPhase = JumpPhase.WINDUP
var _jump_frame_dur   : float     = 0.0   # 1/fps of jump anim — one frame in seconds, set on entry
var _jump_frame_timer : float     = 0.0   # countdown used in WINDUP, LAND1, LAND2 phases

# Prop reaction — continuous animation while moving inside, winds down on exit
var _react_overlap  : Array = []   # props whose DetectZone we are currently inside
var _react_driving  : Array = []   # props we have called start_reaction() on


# =============================================================================
# INIT
# =============================================================================

func init(p_cam: CameraSettings) -> void:
	cam   = p_cam
	stats = _load_stats("ares")
	_build_collision()
	_build_sprite()
	_build_attack_range_visual()
	_build_reaction_area()
	_load_animations()
	_init_abilities()
	# Record spawn position and initial resources for respawn stub
	_spawn_position = global_position
	_initial_hp     = stats.hp
	_initial_energy = stats.energy
	_initial_flow   = stats.flow
	_initial_focus  = stats.focus
	_set_state(State.SPAWN)


func _load_stats(p_id: String) -> Stats:
	var d : Dictionary = AssetLoader.get_player_stats(p_id)
	if d.is_empty():
		push_warning("player.gd: no stats found for id '" + p_id + "' — using fallback")
	return Stats.new(
		d.get("str", 4), d.get("agi", 4), d.get("sta", 4),
		d.get("int", 2), d.get("spr", 2), d.get("res", 2), d.get("def", 2),
		d.get("bms", 3), d.get("exp", 0)
	)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius     = 0.40
	shp.height     = 0.90
	col.position.y = shp.height * 0.5
	col.shape      = shp
	add_child(col)
	_collision_shape = col


func _build_reaction_area() -> void:
	# Small Area3D that detects damageable props (PROP_REACT_LAYER) on contact.
	# Replaces per-prop Area3D — ~9 total entity zones vs 763 prop zones.
	var area := Area3D.new()
	area.name            = "ReactZone"
	area.collision_layer = 0
	area.collision_mask  = PROP_REACT_LAYER
	var col := CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius     = 0.65
	shp.height     = 1.0
	col.position.y = 0.5
	col.shape      = shp
	area.monitorable = false
	area.monitoring  = true
	area.add_child(col)
	area.area_entered.connect(_on_react_zone_entered)
	area.area_exited.connect(_on_react_zone_exited)
	add_child(area)


func _on_react_zone_entered(area: Area3D) -> void:
	var prop : Node3D = area.get_parent() as Node3D
	if not (is_instance_valid(prop) and prop.is_in_group("react_props")):
		return
	if not _react_overlap.has(prop):
		_react_overlap.append(prop)


func _on_react_zone_exited(area: Area3D) -> void:
	var prop : Node3D = area.get_parent() as Node3D
	_react_overlap.erase(prop)
	if _react_driving.has(prop):
		_react_driving.erase(prop)
		if is_instance_valid(prop):
			prop.call("stop_reaction")


func _build_sprite() -> void:
	sprite            = AnimatedSprite3D.new()
	sprite.name       = "Sprite"
	sprite.billboard  = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 1.0 / 32.0
	sprite.alpha_cut              = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter         = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.sorting_use_aabb_center = false
	sprite.offset.y               = float(SPRITE_SIZE) * 0.5
	add_child(sprite)


func _build_attack_range_visual() -> void:
	_atk_range_mat                  = StandardMaterial3D.new()
	_atk_range_mat.albedo_color     = Color(1.0, 0.65, 0.0, 0.28)
	_atk_range_mat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	_atk_range_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	_atk_range_mat.no_depth_test    = true
	_atk_range_mat.cull_mode        = BaseMaterial3D.CULL_DISABLED
	_atk_range_mat.depth_draw_mode  = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_atk_range_node         = MeshInstance3D.new()
	_atk_range_node.visible = false
	add_child(_atk_range_node)


# Builds (or rebuilds) the attack arc mesh for the given ability and shows it.
# Called at attack start — rebuilds so range matches the active ability.
func _show_attack_range(ab: Ability) -> void:
	if _atk_range_node == null or not show_attack_range:
		return
	var dir      : Vector3 = _facing_to_world_dir()
	var r        : float   = ab.range_
	var half_a   : float   = acos(ATTACK_ARC_DOT)          # ~1.266 rad ≈ 72.5°
	var center_a : float   = atan2(dir.x, dir.z)
	const SEGS   : int     = 24
	const Y      : float   = 0.04                          # slightly above ground

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i : int in range(SEGS):
		var a0 : float   = center_a + lerp(-half_a, half_a, float(i)   / float(SEGS))
		var a1 : float   = center_a + lerp(-half_a, half_a, float(i+1) / float(SEGS))
		var v0 : Vector3 = Vector3(sin(a0) * r, Y, cos(a0) * r)
		var v1 : Vector3 = Vector3(sin(a1) * r, Y, cos(a1) * r)
		mesh.surface_add_vertex(Vector3(0.0, Y, 0.0))
		mesh.surface_add_vertex(v0)
		mesh.surface_add_vertex(v1)
	mesh.surface_end()

	_atk_range_node.mesh = mesh
	_atk_range_node.set_surface_override_material(0, _atk_range_mat)
	_atk_range_node.visible = true


func _hide_attack_range() -> void:
	if _atk_range_node != null:
		_atk_range_node.visible = false


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
	for dir : String in ["south", "north", "east", "west"]:
		_add_strip(frames, "grab_" + dir, 4.0)
	for dir : String in ["south", "north", "east", "west"]:
		_add_strip(frames, "jump_" + dir, 12.0)
	_add_strip(frames, "spawn",     12.0)
	_add_strip(frames, "death",     12.0)
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
	if is_dead or state == State.SPAWN:
		return
	# Left click — target creature or clear target
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)
		return

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
		KEY_SPACE:
			if (state == State.IDLE or state == State.WALK or state == State.RUN) \
					and stats.energy >= 1.0:
				stats.energy  = maxf(0.0, stats.energy - 1.0)
				_regen_timer  = REGEN_PAUSE
				_set_state(State.JUMP)
		KEY_TAB:   _try_tab_target()
		KEY_SHIFT:
			# Grab only from IDLE or WALK — not while already sprinting.
			# If no block is found, normal sprint logic in _handle_movement takes over.
			if state == State.IDLE or state == State.WALK:
				_try_grab()


# =============================================================================
# PHYSICS LOOP
# =============================================================================

func _physics_process(delta: float) -> void:
	# Track camera rotation every frame so there is no angle spike on state transitions.
	var _h_angle_delta : float = 0.0
	if camera_rig != null:
		_h_angle_delta = absf(camera_rig.h_angle - _prev_h_angle)
		if _h_angle_delta > PI:
			_h_angle_delta = TAU - _h_angle_delta   # wrap-around (e.g. 6.27 → 0.01)
		_prev_h_angle = camera_rig.h_angle

	# Z-sort compensation: anchor sprite node at world Y=0 every frame so the sort
	# key is always at ground level, regardless of how high the player is elevated
	# (platform, jump arc). Without this, the camera pitch makes elevated sprites
	# project closer to the camera than ground-anchored tall sprites (trees) and
	# pop in front of them. offset.y is compensated by the same elevation in pixel
	# space so the visual stays at the player's actual world height.
	sprite.position.y = -global_position.y
	sprite.offset.y   = float(SPRITE_SIZE) * 0.5 + global_position.y / sprite.pixel_size

	# Dead — tick timer, respawn when ready; no other processing.
	if state == State.DEAD:
		_dead_timer += delta
		if _dead_timer >= RESPAWN_DELAY:
			_do_respawn()
		return
	# Spawn — gravity + collision only; no input or attack.
	if state == State.SPAWN:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		_sync_anim()
		return

	# Gravity — treat as grounded during LAND phases (player is on floor and just landed).
	# All other JUMP phases and airborne states accumulate gravity normally.
	var _is_grounded : bool = is_on_floor() and (state != State.JUMP or _jump_phase == JumpPhase.LAND1 or _jump_phase == JumpPhase.LAND2)
	if not _is_grounded:
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	# Prop reaction — drive start/stop based on movement OR camera rotation.
	# Rotating in place brushes past nearby props just like walking through them.
	const ROTATE_THRESHOLD : float = 0.008   # ~0.5° per frame — filters float noise
	var _moving : bool = velocity.length_squared() > 0.01 or _h_angle_delta > ROTATE_THRESHOLD or state == State.JUMP
	if _moving:
		for _rp : Variant in _react_overlap.duplicate():
			var _rpn : Node3D = _rp as Node3D
			if is_instance_valid(_rpn) and not _react_driving.has(_rpn):
				_react_driving.append(_rpn)
				_rpn.call("start_reaction")
	else:
		for _rp : Variant in _react_driving.duplicate():
			var _rpn : Node3D = _rp as Node3D
			_react_driving.erase(_rpn)
			if is_instance_valid(_rpn):
				_rpn.call("stop_reaction")
	# Purge stale refs — freed nodes (streamer unload) AND dead-but-valid props (grass
	# never queue_free()s, so is_instance_valid stays true forever after death).
	# Checking alive == false is the backstop when area_exited doesn't fire reliably.
	for _rp : Variant in _react_driving.duplicate():
		var _rpn : Node3D = _rp as Node3D
		if not is_instance_valid(_rpn) or _rpn.get("alive") == false:
			_react_driving.erase(_rpn)
			if is_instance_valid(_rpn):
				_rpn.call("stop_reaction")
	for _rp : Variant in _react_overlap.duplicate():
		var _rpn : Node3D = _rp as Node3D
		if not is_instance_valid(_rpn) or _rpn.get("alive") == false:
			_react_overlap.erase(_rpn)

	_handle_movement(delta)
	if state == State.RUN or state == State.PUSH or state == State.PULL:
		_run_energy_accum += delta
		if _run_energy_accum >= 1.0:
			var ticks : int = int(_run_energy_accum)
			stats.energy      = maxf(0.0, stats.energy - SPRINT_ENERGY_COST * ticks)
			_run_energy_accum -= float(ticks)   # keep remainder — never reset to 0
	_handle_attack(delta)

	if _knockback_vel.length_squared() > 0.01:
		var kb_scale : float = KNOCKBACK_AIR_SCALE if state == State.JUMP else 1.0
		velocity.x += _knockback_vel.x * kb_scale
		velocity.z += _knockback_vel.z * kb_scale
		_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, KNOCKBACK_FRICTION * delta)
	else:
		_knockback_vel = Vector3.ZERO

	_sync_anim()
	move_and_slide()   # player moves first

	# PULL: block follows AFTER player has cleared the path — avoids player-as-obstacle collision.
	# Skipped when out of energy — player and block both freeze in place.
	if state == State.PULL and stats.energy >= 1.0:
		_drive_pulled_block(delta)

	stats.tick(delta)
	_tick_effects(delta)
	_combat_timer = maxf(0.0, _combat_timer - delta)
	_regen_timer  = maxf(0.0, _regen_timer  - delta)
	if _combat_timer <= 0.0 and _regen_timer <= 0.0 \
			and state != State.RUN and state != State.PUSH \
			and state != State.PULL and state != State.GRAB:
		stats.regen(delta)

	# Target: clear if node freed or out of range. Dead creatures stay targeted
	# (inspectable via debug panel) until out of range, Tab, or click elsewhere.
	if _target != null:
		var tgt_ok : bool = is_instance_valid(_target)
		if tgt_ok:
			var tgt_diff : Vector3 = _target.global_position - global_position
			tgt_diff.y = 0.0
			tgt_ok = tgt_diff.length_squared() <= TAB_TARGET_RANGE * TAB_TARGET_RANGE
		if not tgt_ok:
			_clear_target()
	_tab_buffer = _tab_buffer.filter(
		func(n : Node) -> bool: return is_instance_valid(n) and not n.get("is_dead")
	)


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
# TARGET SYSTEM
# =============================================================================

func _set_target(node: Node) -> void:
	if _target != null and _target != node:
		_target.set("is_targeted", false)
		_target.call("set_target_dot_visible", false)
	_target = node
	if node != null:
		node.set("is_targeted", true)
		node.call("set_target_dot_visible", show_attack_range)


func _clear_target() -> void:
	if _target != null:
		_target.set("is_targeted", false)
		_target.call("set_target_dot_visible", false)
	_target = null
	_tab_buffer.clear()


# Left-click: ray cast from camera into world. Targets creature, clears on empty space.
func _handle_click(mouse_pos: Vector2) -> void:
	if camera_rig == null:
		return
	var cam : Camera3D = camera_rig.get("camera") as Camera3D
	if cam == null:
		return
	var space  : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.new()
	params.from    = cam.global_position
	params.to      = cam.global_position + cam.project_ray_normal(mouse_pos) * 200.0
	params.exclude = [self]
	var result : Dictionary = space.intersect_ray(params)
	if result.is_empty():
		_clear_target()
		return
	var hit : Node = result.collider as Node
	if hit != null and hit.is_in_group("creatures"):
		_set_target(hit)
	else:
		_clear_target()


# Tab targeting — two tiers, evaluated fresh on every key press:
#   Tier 1 (on-screen): creatures visible in camera + range + LOS, nearest first.
#   Tier 2 (off-screen fallback): all range + LOS creatures, nearest first.
# If the active tier changes between presses (e.g. a creature enters the screen),
# the buffer resets so cycling restarts from the new pool.
func _try_tab_target() -> void:
	if camera_rig == null:
		return
	var cam      : Camera3D                  = camera_rig.get("camera") as Camera3D
	var space    : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var range_sq : float                     = TAB_TARGET_RANGE * TAB_TARGET_RANGE

	# Full pool: alive, within range, clear LOS.
	var pool : Array[Node] = []
	for node : Node in get_tree().get_nodes_in_group("creatures"):
		if node.get("is_dead"):
			continue
		var diff : Vector3 = node.global_position - global_position
		diff.y = 0.0
		if diff.length_squared() > range_sq:
			continue
		if not _has_los(node, space):
			continue
		pool.append(node)

	if pool.is_empty():
		return

	# Tier 1: on-screen subset.
	var on_screen : Array[Node] = []
	if cam != null:
		for node : Node in pool:
			if cam.is_position_in_frustum(node.global_position):
				on_screen.append(node)

	var new_tier   : int        = 1 if not on_screen.is_empty() else 2
	var candidates : Array[Node] = on_screen if new_tier == 1 else pool.duplicate()

	# Reset buffer if the tier changed since last Tab press.
	if new_tier != _tab_tier:
		_tab_tier = new_tier
		_tab_buffer.clear()

	# Sort nearest first.
	candidates.sort_custom(func(a : Node, b : Node) -> bool:
		return a.global_position.distance_squared_to(global_position) \
			 < b.global_position.distance_squared_to(global_position)
	)

	# Cycle: first unvisited candidate.
	for c : Node in candidates:
		if not _tab_buffer.has(c):
			_set_target(c)
			_tab_buffer.append(c)
			return
	# All visited — wrap.
	_tab_buffer.clear()
	_set_target(candidates[0])
	_tab_buffer.append(candidates[0])


# Returns clockwise angle [0, TAU) from player facing direction to the given node.
func _angle_from_facing(node: Node) -> float:
	var h     : float   = camera_rig.h_angle
	var fwd   : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
	var right : Vector3 = Vector3( cos(h), 0.0, -sin(h))
	var diff  : Vector3 = node.global_position - global_position
	diff.y = 0.0
	if diff.length_squared() < 0.001:
		return 0.0
	diff = diff.normalized()
	var angle : float = atan2(diff.dot(right), diff.dot(fwd))
	if angle < 0.0:
		angle += TAU
	return angle


# Returns true if there is clear line of sight from the player's head to the
# creature's head (top of capsule). Excludes all creatures so only static world
# geometry (walls, terrain) can block the ray. A wall shorter than the player's
# eyes, or a creature taller than the wall, will pass the check correctly.
func _has_los(node: Node, space: PhysicsDirectSpaceState3D) -> bool:
	const PLAYER_HEAD : float = 0.90   # matches shp.height in _build_collision
	var creature_head : float = node.get("head_height") if "head_height" in node else 0.70
	var from_pos : Vector3 = global_position + Vector3(0.0, PLAYER_HEAD, 0.0)
	var to_pos   : Vector3 = node.global_position + Vector3(0.0, creature_head, 0.0)
	var params   := PhysicsRayQueryParameters3D.new()
	params.from  = from_pos
	params.to    = to_pos
	# Exclude the player itself and every creature so only static world blocks the ray
	var excluded : Array[RID] = [self.get_rid()]
	for c : Node in get_tree().get_nodes_in_group("creatures"):
		if c is CollisionObject3D:
			excluded.append((c as CollisionObject3D).get_rid())
	params.exclude = excluded
	return space.intersect_ray(params).is_empty()


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

	if state == State.JUMP:
		# No steering — x/z velocity carries from jump entry unchanged.
		# Gravity and move_and_slide() drive the arc; we only control which frame shows.
		match _jump_phase:
			JumpPhase.WINDUP:
				sprite.frame       = 0
				velocity.y         = 0.0           # hold on ground during crouch frame
				_jump_frame_timer -= delta
				if _jump_frame_timer <= 0.0:
					velocity.y  = JUMP_VEL         # launch at end of crouch
					_jump_phase = JumpPhase.RISE
			JumpPhase.RISE:
				sprite.frame = 1                   # held the whole time body is rising
				if velocity.y <= 0.0:
					_jump_phase = JumpPhase.FALL
			JumpPhase.FALL:
				sprite.frame = 2                   # held (loops naturally) until touchdown
				if is_on_floor():
					_jump_phase       = JumpPhase.LAND1
					_jump_frame_timer = _jump_frame_dur
			JumpPhase.LAND1:
				sprite.frame       = 3
				_jump_frame_timer -= delta
				if _jump_frame_timer <= 0.0:
					_jump_phase       = JumpPhase.LAND2
					_jump_frame_timer = _jump_frame_dur
			JumpPhase.LAND2:
				sprite.frame       = 4
				_jump_frame_timer -= delta
				if _jump_frame_timer <= 0.0:
					if _pending_death:
						_pending_death = false
						velocity       = Vector3.ZERO
						if _collision_shape != null:
							_collision_shape.set_deferred("disabled", true)
						_set_state(State.DEAD)
					else:
						_set_state(State.IDLE)
		return

	var raw : Vector2 = _read_raw_input()

	if raw.length_squared() > 0.0:
		raw = raw.normalized()
		_set_facing_from_input(raw)
		var h         : float   = camera_rig.h_angle
		var fwd       : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
		var right     : Vector3 = Vector3( cos(h), 0.0, -sin(h))
		var sprinting : bool    = Input.is_key_pressed(KEY_SHIFT) and stats.energy >= 1.0
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

	# No energy — hold the PUSH animation but nothing moves
	if stats.energy < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
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

	# No energy — hold the PULL animation but nothing moves.
	# Keep _driven=true so the block doesn't drift under its own physics.
	if stats.energy < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_grabbed_obj.set("_driven", true)
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
	# Entry side effects
	if new_state == State.JUMP:
		var fps : float   = sprite.sprite_frames.get_animation_speed(_anim_key)
		_jump_frame_dur   = 1.0 / fps          # one frame duration in seconds
		_jump_frame_timer = _jump_frame_dur    # WINDUP counts this down before kicking
		_jump_phase       = JumpPhase.WINDUP
		# velocity.y kick fires at end of WINDUP so frame 0 (crouch) plays at ground level
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
		State.JUMP:   _anim_key = "jump_"         + FACING_STR[facing]
		State.PUSH:   _anim_key = "push_"         + FACING_STR[facing]
		State.GRAB:   _anim_key = "grab_" + FACING_STR[facing]
		State.PULL:   _anim_key = "pull_"         + FACING_STR[facing]
		State.SPAWN:  _anim_key = "spawn"
		State.DEAD:   _anim_key = "death"


func _sync_anim() -> void:
	# SPAWN: start once, then transition to IDLE when finished.
	if state == State.SPAWN:
		if sprite.animation != "spawn":
			sprite.sprite_frames.set_animation_loop("spawn", false)
			sprite.play("spawn")
		elif not sprite.is_playing():
			is_dead = false
			_set_state(State.IDLE)
		return
	# DEAD: start death animation once; _dead_timer in _physics_process drives respawn.
	if state == State.DEAD:
		if sprite.animation != "death":
			sprite.sprite_frames.set_animation_loop("death", false)
			sprite.play("death")
		return
	# IDLE anim depends on combat state which changes over time (timer / creature states),
	# not just on state/facing transitions — rebuild every frame so it stays current.
	if state == State.IDLE:
		_rebuild_anim_key()
	if sprite.animation != _anim_key:
		if state == State.JUMP:
			sprite.animation = _anim_key   # set sheet without playing — JUMP handler drives frames
		else:
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
			_hide_attack_range()
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
	_regen_timer     = REGEN_PAUSE
	ab.spend(stats)
	_show_attack_range(ab)
	_set_state(State.ATTACK)


func _extend_combat_timer() -> void:
	# Called by any hostile creature each frame — keeps regen suppressed while being pursued.
	_combat_timer = COMBAT_TIMEOUT


func apply_status(effect_id: String, max_stacks: int) -> void:
	if is_dead:
		return
	if _effects.has(effect_id):
		_effects[effect_id].reapply(max_stacks)
	else:
		var se : StatusEffect = Statuses.get_status(effect_id, max_stacks)
		if se != null:
			_effects[effect_id] = se


func _tick_effects(dt: float) -> void:
	if _effects.is_empty():
		return
	var to_remove : Array[String] = []
	for effect_id : String in _effects:
		var se  : StatusEffect = _effects[effect_id]
		if se.tick(dt):
			var dmg    : float = se.tick_dmg * float(se.stacks)
			var actual : float = stats.take_damage(dmg, se.is_magic)
			if actual > 0.0:
				_start_status_flash(se.color)
		se.update(dt)
		if se.expired:
			to_remove.append(effect_id)
	for id : String in to_remove:
		_effects.erase(id)


func _start_status_flash(col: Color) -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", col,         0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func receive_hit(damage: float, knockback_dir: Vector3, attacker: Node = null) -> void:
	if state == State.DEAD or state == State.SPAWN:
		return
	var actual : float = stats.take_damage(damage)
	stats.gain_focus_on_receive(actual)
	_combat_timer = COMBAT_TIMEOUT
	_regen_timer  = REGEN_PAUSE
	# Auto-target attacker only if player has no current target
	if attacker != null and _target == null:
		_set_target(attacker)
	_start_hit_flash()
	if state == State.GRAB or state == State.PULL or state == State.PUSH:
		_release_grab()
	_apply_knockback(knockback_dir)
	if not stats.is_alive():
		_enter_dead()


func _enter_dead() -> void:
	if is_dead:
		return
	_clear_target()
	if _grabbed_obj != null:
		_release_grab()
	# Stop all driven prop reactions immediately. The DEAD state has an early return
	# in _physics_process so the purge loops never run during the 3-second respawn
	# window — without this, dead grass stays in _react_overlap for the full wait.
	for _rp : Variant in _react_driving.duplicate():
		if is_instance_valid(_rp):
			(_rp as Node3D).call("stop_reaction")
	_react_driving.clear()
	_react_overlap.clear()
	_combat_timer  = 0.0
	_dead_timer    = 0.0
	is_dead        = true
	_effects.clear()
	for c : Node in get_tree().get_nodes_in_group("creatures"):
		if is_instance_valid(c) and c.has_method("on_player_died"):
			c.call("on_player_died")
	# Mid-air death — keep collision + knockback so the hit sends the player flying,
	# gravity lands them on the floor, landing frames play, then DEAD is entered.
	if state == State.JUMP:
		_pending_death = true
		return
	_knockback_vel = Vector3.ZERO
	velocity       = Vector3.ZERO
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	_set_state(State.DEAD)


func _do_respawn() -> void:
	# Restore resources to values recorded at first spawn
	stats.hp     = _initial_hp
	stats.energy = _initial_energy
	stats.flow   = _initial_flow
	stats.focus  = _initial_focus
	# Re-enable collision and teleport
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", false)
	global_position = _spawn_position
	velocity        = Vector3.ZERO
	_knockback_vel  = Vector3.ZERO
	_pending_death  = false
	_dead_timer     = 0.0
	_set_facing(Facing.SOUTH)
	_set_state(State.SPAWN)


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
	var range_sq        : float  = _active_ability.range_ * _active_ability.range_
	var atk_dir         : Vector3 = _facing_to_world_dir()
	var atk_pos         : Vector3 = global_position
	var nearest_dist_sq : float   = INF
	var nearest_node    : Node    = null
	for node : Node in get_tree().get_nodes_in_group("creatures"):
		var c_pos : Vector3 = node.global_position
		var diff  : Vector3 = c_pos - atk_pos
		diff.y = 0.0
		if diff.length_squared() > range_sq:
			continue
		if diff.length_squared() > 0.001 and diff.normalized().dot(atk_dir) < ATTACK_ARC_DOT:
			continue
		var dmg : float = _active_ability.calc_damage(stats) * stats.focus_damage_mult()
		node.call("receive_hit", dmg, diff)
		stats.gain_focus_on_hit(dmg)
		_combat_timer = COMBAT_TIMEOUT   # creature was struck — enter/extend combat idle
		# Status effect proc
		if _active_ability.effect_name != "" \
				and randf() < _active_ability.effect_chance:
			node.call("apply_status",
					_active_ability.effect_name,
					_active_ability.effect_max_stacks)
		if diff.length_squared() < nearest_dist_sq:
			nearest_dist_sq = diff.length_squared()
			nearest_node    = node
	# Auto-target nearest hit creature only if player has no current target
	if nearest_node != null and _target == null:
		_set_target(nearest_node)

	# Hit damageable props (bushes, grass) — same range + arc, one-hit kill, no combat/focus
	for prop : Node in get_tree().get_nodes_in_group("damageable_props"):
		if not prop.get("alive"):
			continue
		var p_pos : Vector3 = prop.global_position
		var diff  : Vector3 = p_pos - atk_pos
		diff.y = 0.0
		if diff.length_squared() > range_sq:
			continue
		if diff.length_squared() > 0.001 and diff.normalized().dot(atk_dir) < ATTACK_ARC_DOT:
			continue
		prop.call("take_hit")


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
