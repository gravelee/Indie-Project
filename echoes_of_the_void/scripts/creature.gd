extends CharacterBody3D

# =============================================================================
# CREATURE — base for all enemy/neutral entities.
# Created programmatically by main.gd via set_script + call("init", ...).
#
# Build:  body.call("init", type, camera_rig, player, aggression, has_home, can_wander)
#
# States:
#   IDLE_NEUTRAL ↔ WANDER                        (passive / wandering loop)
#   IDLE_NEUTRAL / WANDER → NOTICE               (player enters notice range)
#   NOTICE → NEUTRAL_TO_ATTACK                   (player still there)
#   NEUTRAL_TO_ATTACK → CHASE / IDLE_ATTACK      (enter combat)
#   IDLE_ATTACK ↔ CHASE                          (combat loop)
#   IDLE_ATTACK → ATTACK → IDLE_ATTACK           (melee strike)
#   any combat → ATTACK_TO_NEUTRAL → RETURNING   (player fled / leash hit)
#   RETURNING → IDLE_NEUTRAL                     (arrived home)
#   any → DEATH → DEAD                           (HP = 0)
#
# Aggression types: "hostile" | "neutral" | "passive"
#   hostile  — attacks on sight
#   neutral  — ignores player; enters combat only when hit
#   passive  — never attacks (not yet used)
#   void_touched — forces hostile regardless of aggression_type
#
# TODO (stub — replace with ability system):
#   _attack_damage() returns a flat constant.
#   ATTACK state triggers raw stats.take_damage() on player.
#   Remove both once ability.gd is wired.
# =============================================================================

const SPRITE_SIZE        : int    = 96
const SPRITE_PATH        : String = "res://assets/spritesheets/creatures/"
const ANIM_SPEED         : int    = 8
const ATTACK_ANIM_SPEED  : int    = 16
const GRAVITY            : float = -20.0
const PROP_REACT_LAYER   : int   = 4     # matches WorldProp.PROP_REACT_LAYER

# ── AI distances (world units; 32 px = 1 unit) ─────────────────────────────

const NOTICE_DIR_DIST  : float = 10.0   # creature faces player, still won't wander
const NOTICE_DIST      : float = 8.0    # triggers NOTICE state
const CHASE_DIST       : float = 18.0   # leash — beyond this exits combat
const ATTACK_DIST_DEFAULT : float = 1.6  # fallback when no abilities loaded yet
const HOME_MAX_DIST    : float = 25.0   # forced return: applies in ALL states
const HOME_ARRIVE_DIST : float = 0.5    # snap-to-home arrival threshold

# ── Wander timing ──────────────────────────────────────────────────────────

const WANDER_INTERVAL_MIN : float = 0.9
const WANDER_INTERVAL_MAX : float = 1.1
const WANDER_DURATION_MIN : float = 0.5
const WANDER_DURATION_MAX : float = 3.0
const WANDER_CHANCE       : float = 1.0

# ── Combat ─────────────────────────────────────────────────────────────────


const ATTACK_HIT_GRACE   : float = 1.2  # extra melee range at hit frame — creature committed to swing
const CHASE_SPEED_MULT   : float = 1.5   # chase is 50% faster than wander
const RETURN_SPEED_MULT  : float = 2.0   # return is faster than chase
const KNOCKBACK_STRENGTH : float = 8.0
const KNOCKBACK_FRICTION : float = 25.0

# ── State ──────────────────────────────────────────────────────────────────

enum State {
	IDLE_NEUTRAL, WANDER,
	NOTICE, NEUTRAL_TO_ATTACK,
	IDLE_ATTACK, CHASE, ATTACK,
	ATTACK_TO_NEUTRAL, RETURNING,
	DEATH, DEAD
}

const ONE_SHOT_STATES : Dictionary = {
	State.NOTICE: true, State.NEUTRAL_TO_ATTACK: true,
	State.ATTACK_TO_NEUTRAL: true, State.ATTACK: true, State.DEATH: true
}

# ── Public refs ────────────────────────────────────────────────────────────

var sprite      : AnimatedSprite3D
var stats       : Stats
var camera_rig  : Node3D
var player      : CharacterBody3D
var head_height : float = 0.70   # top of capsule — set in _build_collision()

# ── Creature type ──────────────────────────────────────────────────────────

var type           : String = "rat"
var sprite_path    : String = ""
var aggression_type: String = "hostile"   # "hostile" | "neutral" | "passive"
var void_touched   : bool   = false

# ── Behaviour flags ────────────────────────────────────────────────────────

var can_wander    : bool    = true
var has_home      : bool    = false
var home_position : Vector3 = Vector3.ZERO
var temp_home     : bool    = false   # true when immigrant sets combat entry as home

# ── Animation / state ──────────────────────────────────────────────────────

var state     : State = State.IDLE_NEUTRAL
var in_combat : bool  = false   # true while in NEUTRAL_TO_ATTACK / IDLE_ATTACK / CHASE / ATTACK
var is_dead      : bool    = false   # true once DEATH state is entered — used by player target system
var is_targeted  : bool    = false:
	set(value):
		is_targeted = value
		if _target_ring != null:
			_target_ring.visible = value
var facing_right : bool    = false
var facing_back  : bool    = false
var _move_dir    : Vector3 = Vector3.BACK
var _anim_done   : bool    = false
var _fading      : bool    = false
var _target_ring     : MeshInstance3D   = null
var _target_dot      : MeshInstance3D   = null
var _target_ring_mat : StandardMaterial3D = null

# ── Wander ─────────────────────────────────────────────────────────────────

var _wander_timer    : float   = 0.0
var _wander_interval : float   = 1.0
var _wander_elapsed  : float   = 0.0
var _wander_duration : float   = 1.0
var _wander_dir      : Vector3 = Vector3.ZERO
var _force_wander    : bool    = false

# ── Combat ─────────────────────────────────────────────────────────────────

var _knockback_vel      : Vector3        = Vector3.ZERO
var _effects            : Dictionary     = {}                   # effect_id → StatusEffect
var _attack_dist        : float          = ATTACK_DIST_DEFAULT  # max range of ability pool
var _home_max_dist      : bool           = false   # set when leash exceeded during combat
var _chosen_attack      : String         = ""      # locked on ATTACK state entry; stable for full swing
var _active_ability     : Ability        = null    # ability being executed in current ATTACK swing
var _creature_abilities : Array[Ability] = []      # per-instance ability pool with individual cooldowns
var _hit_applied        : bool           = false   # true once hit-frame damage fires this swing
var _pending_death      : bool           = false   # set when lethal hit received; death delayed until knockback settles

# Prop reaction — continuous animation while moving inside, winds down on exit
var _react_overlap  : Array = []   # props whose DetectZone we are currently inside
var _react_driving  : Array = []   # props we have called start_reaction() on


# =============================================================================
# INIT
# =============================================================================

func init(p_type: String, p_stat_id: String, p_camera_rig: Node3D, p_player: CharacterBody3D,
		p_aggression: String, p_has_home: bool, p_can_wander: bool) -> void:
	type           = p_type
	sprite_path    = SPRITE_PATH + type + "/"
	camera_rig     = p_camera_rig
	player         = p_player
	aggression_type = p_aggression
	has_home       = p_has_home
	can_wander     = p_can_wander
	add_to_group("creatures")

	if has_home:
		home_position = global_position   # set after add_child in main.gd

	var stat_key : String = p_stat_id if p_stat_id != "" else p_type
	stats = _load_stats(stat_key)

	_wander_timer    = randf_range(0.0, 1.0)
	_wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)

	_build_collision()
	_build_sprite()
	_build_target_ring()
	_build_reaction_area()
	_load_animations()
	_init_creature_abilities()


func _load_stats(p_type: String) -> Stats:
	var d : Dictionary = AssetLoader.get_creature_stats(p_type)
	if d.is_empty():
		push_warning("creature.gd: no stats found for type '" + p_type + "' — using fallback")
	return Stats.new(
		d.get("str", 1), d.get("agi", 1), d.get("sta", 5),
		d.get("int", 0), d.get("spr", 0), d.get("res", 0), d.get("def", 0),
		d.get("bms", 2), d.get("exp", 10)
	)


func _init_creature_abilities() -> void:
	# Build the ability pool from abilities.gd data, filtered by animations that
	# actually exist in this creature's spritesheet.
	_creature_abilities.clear()
	for id : String in Abilities.get_ids_for_type(type):
		var ab : Ability = Abilities.get_ability(id)
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ab.anim + "_front"):
			_creature_abilities.append(ab)
	# Derive engagement distance from the shortest-range ability in the pool so the
	# creature closes until ALL abilities can reach — wider-range abilities are still
	# in range at this distance and fill in when shorter-range ones are on cooldown.
	var min_r : float = INF
	for ab : Ability in _creature_abilities:
		if ab.range_ < min_r:
			min_r = ab.range_
	_attack_dist = min_r if min_r < INF else ATTACK_DIST_DEFAULT


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius     = 0.30
	shp.height     = 0.70
	col.position.y = shp.height * 0.5
	col.shape      = shp
	head_height    = shp.height
	add_child(col)


func _build_reaction_area() -> void:
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
	sprite.alpha_cut               = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter          = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.sorting_use_aabb_center = false
	sprite.offset.y                = float(SPRITE_SIZE) * 0.5
	add_child(sprite)


func set_target_dot_visible(v: bool) -> void:
	if _target_dot != null:
		_target_dot.visible = v and not is_dead


func _update_ring_color() -> void:
	if _target_ring_mat == null:
		return
	if is_dead:
		_target_ring_mat.albedo_color = Color(0.45, 0.45, 0.45, 0.60)   # gray — dead
		return
	match state:
		State.IDLE_ATTACK, State.CHASE, State.ATTACK:
			_target_ring_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.80)   # red — in combat
		State.NOTICE, State.NEUTRAL_TO_ATTACK, State.ATTACK_TO_NEUTRAL:
			_target_ring_mat.albedo_color = Color(1.0, 0.50, 0.00, 0.80)   # orange — transitioning
		_:
			_target_ring_mat.albedo_color = Color(1.0, 0.85, 0.00, 0.75)   # gold — neutral


func _build_target_ring() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius    = 0.40
	mesh.outer_radius    = 0.55
	mesh.rings           = 6
	mesh.ring_segments   = 24

	_target_ring_mat = StandardMaterial3D.new()
	_target_ring_mat.albedo_color    = Color(1.0, 0.85, 0.0, 0.75)
	_target_ring_mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_ring_mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_ring_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_target_ring_mat.no_depth_test   = true
	mesh.surface_set_material(0, _target_ring_mat)

	_target_ring          = MeshInstance3D.new()
	_target_ring.mesh     = mesh
	_target_ring.position = Vector3(0.0, 0.02, 0.0)
	_target_ring.visible  = false
	add_child(_target_ring)

	# Center dot — same material so it auto-matches the ring color.
	# Only visible when the player has show_attack_range enabled.
	var dot_mesh := CylinderMesh.new()
	dot_mesh.top_radius    = 0.10
	dot_mesh.bottom_radius = 0.10
	dot_mesh.height        = 0.05
	dot_mesh.rings         = 1
	dot_mesh.radial_segments = 12
	dot_mesh.surface_set_material(0, _target_ring_mat)
	_target_dot          = MeshInstance3D.new()
	_target_dot.mesh     = dot_mesh
	_target_dot.position = Vector3(0.0, 0.025, 0.0)
	_target_dot.visible  = false
	add_child(_target_dot)


func _load_animations() -> void:
	var cached : SpriteFrames = AssetLoader.get_frames(sprite_path)
	if cached:
		sprite.sprite_frames = cached
		sprite.animation_finished.connect(_on_anim_finished)
		sprite.play("idle_neutral_front")
		_compute_sprite_offset()
		return

	var frames := SpriteFrames.new()

	# anim_name → loop
	var anims : Dictionary = {
		"idle_neutral_front":       true,  "idle_neutral_back":       true,
		"wander_front":             true,  "wander_back":             true,
		"run_front":                true,  "run_back":                true,
		"idle_attack_front":        true,  "idle_attack_back":        true,
		"notice_front":             false, "notice_back":             false,
		"neutral_to_attack_front":  false, "neutral_to_attack_back":  false,
		"attack_bite_front":        false, "attack_bite_back":        false,
		"attack_slash_front":       false, "attack_slash_back":       false,
		"attack_tail_slam_front":   false, "attack_tail_slam_back":   false,
		"attack_to_neutral_front":  false, "attack_to_neutral_back":  false,
		"death_front":              false, "death_back":              false,
	}

	for anim_name : String in anims:
		var path : String = sprite_path + anim_name + ".png"
		if not ResourceLoader.exists(path):
			continue
		var tex         : Texture2D = load(path)
		var frame_count : int       = tex.get_width() / SPRITE_SIZE
		frames.add_animation(anim_name)
		var spd : float = float(ATTACK_ANIM_SPEED) if anim_name.begins_with("attack_") else float(ANIM_SPEED)
		frames.set_animation_speed(anim_name, spd)
		frames.set_animation_loop(anim_name, anims[anim_name])
		for i : int in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas       = tex
			atlas.region      = Rect2(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
			atlas.filter_clip = true
			frames.add_frame(anim_name, atlas)

	AssetLoader.store_frames(sprite_path, frames)
	sprite.sprite_frames = frames
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("idle_neutral_front")
	_compute_sprite_offset()


func _compute_sprite_offset() -> void:
	var path : String = sprite_path + "idle_neutral_front.png"
	if not ResourceLoader.exists(path):
		return
	var tex          : Texture2D = load(path)
	var img          := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var first_frame  := img.get_region(Rect2i(0, 0, SPRITE_SIZE, SPRITE_SIZE))
	var empty_bottom : int = SPRITE_SIZE - first_frame.get_used_rect().end.y
	sprite.offset.y = float(SPRITE_SIZE) / 2.0 - float(empty_bottom)


# =============================================================================
# PHYSICS LOOP
# =============================================================================

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	# Prop reaction — drive start/stop based on movement state
	var _moving : bool = velocity.length_squared() > 0.01
	if _moving:
		for _rp : Variant in _react_overlap:
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
	for _rp : Variant in _react_driving.duplicate():
		if not is_instance_valid(_rp as Node3D):
			_react_driving.erase(_rp)
	_react_overlap = _react_overlap.filter(func(p : Variant) -> bool: return is_instance_valid(p as Node3D))

	_update_state(delta)

	# Apply and decay knockback impulse
	if _knockback_vel.length_squared() > 0.01:
		velocity.x += _knockback_vel.x
		velocity.z += _knockback_vel.z
		_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, KNOCKBACK_FRICTION * delta)
	else:
		_knockback_vel = Vector3.ZERO
		if _pending_death:
			_pending_death = false
			_enter_death()

	_sync_anim()
	move_and_slide()

	# Wander collision recovery — pick new direction on wall/obstacle hit
	if state == State.WANDER:
		for i : int in get_slide_collision_count():
			if get_slide_collision(i).get_normal().y < 0.5:
				_force_wander = true
				break

	# Notify player to stay in combat while this creature is actively hostile
	const HOSTILE_STATES : Array = [
		State.NEUTRAL_TO_ATTACK,
		State.CHASE, State.IDLE_ATTACK, State.ATTACK,
	]
	if state in HOSTILE_STATES and player != null and player.has_method("_extend_combat_timer"):
		player.call("_extend_combat_timer")

	stats.tick(delta)
	if not is_dead:
		for ab : Ability in _creature_abilities:
			ab.tick(delta)
	# Regen only when out of combat.
	# RETURNING: recover HP/Energy/Flow but preserve Focus — adrenaline lingers mid-flight,
	# only settles when the creature is actually calm (IDLE_NEUTRAL / WANDER).
	if state == State.IDLE_NEUTRAL or state == State.WANDER:
		stats.regen(delta)
	elif state == State.RETURNING:
		stats.regen(delta, false)

	_tick_effects(delta)


func _on_anim_finished() -> void:
	if state in ONE_SHOT_STATES:
		_anim_done = true


# =============================================================================
# STATE MACHINE
# =============================================================================

func _update_state(delta: float) -> void:
	var dist_sq : float = _dist_sq_to_player()

	match state:

		State.IDLE_NEUTRAL:
			velocity.x = 0.0
			velocity.z = 0.0
			# Within notice-direction range: face the player, suppress wander
			if _is_aggressive() and dist_sq < NOTICE_DIR_DIST * NOTICE_DIR_DIST:
				_update_facing_toward(player.global_position)
				# Close enough to actually notice — enter NOTICE state
				if dist_sq < NOTICE_DIST * NOTICE_DIST:
					_set_state(State.NOTICE)
					return
			else:
				# Normal wander tick — only when player is not in notice-direction range
				if can_wander:
					_wander_timer += delta
					if _wander_timer >= _wander_interval:
						_wander_timer    = 0.0
						_wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
						if randf() < WANDER_CHANCE:
							_force_wander = true
							_set_state(State.WANDER)
							return
			# Wandered too far from home — return
			if has_home and _dist_sq_to_home() > HOME_MAX_DIST * HOME_MAX_DIST:
				_set_state(State.RETURNING)

		State.WANDER:
			# Notice check takes priority over wander
			if _is_aggressive() and dist_sq < NOTICE_DIST * NOTICE_DIST:
				_set_state(State.NOTICE)
				return
			# Wandered too far from home
			if has_home and _dist_sq_to_home() > HOME_MAX_DIST * HOME_MAX_DIST:
				_set_state(State.RETURNING)
				return
			# Resolve new direction on flag
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
			_update_facing()
			if _wander_elapsed >= _wander_duration:
				_set_state(State.IDLE_NEUTRAL)

		State.NOTICE:
			velocity.x = 0.0
			velocity.z = 0.0
			# Player rushed into melee range — skip rest of notice anim
			if dist_sq < _attack_dist * _attack_dist:
				_set_state(State.NEUTRAL_TO_ATTACK)
				return
			if _anim_done:
				# Only enter combat if player is still within notice distance —
				# if player stepped back out during the animation, return to idle
				if dist_sq < NOTICE_DIST * NOTICE_DIST:
					_set_state(State.NEUTRAL_TO_ATTACK)
				else:
					_set_state(State.IDLE_NEUTRAL)

		State.NEUTRAL_TO_ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			if _anim_done:
				if dist_sq > CHASE_DIST * CHASE_DIST:
					_set_state(State.ATTACK_TO_NEUTRAL)
				elif dist_sq < _attack_dist * _attack_dist:
					_set_state(State.IDLE_ATTACK)
				else:
					_set_state(State.CHASE)

		State.IDLE_ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			_update_facing_toward(player.global_position)
			# Leash check
			if (has_home or temp_home) and _dist_sq_to_home() > HOME_MAX_DIST * HOME_MAX_DIST:
				_home_max_dist = true
				_set_state(State.ATTACK_TO_NEUTRAL)
				return
			# Energy depleted — disengage and return home to recover
			if stats.energy < 1.0:
				_set_state(State.ATTACK_TO_NEUTRAL)
				return
			# Player moved out of melee range
			if dist_sq >= _attack_dist * _attack_dist:
				if dist_sq < CHASE_DIST * CHASE_DIST:
					_set_state(State.CHASE)
				else:
					_set_state(State.ATTACK_TO_NEUTRAL)
				return
			# Fire as soon as the best available ability is ready
			if _pick_best_ability() != null:
				_set_state(State.ATTACK)

		State.CHASE:
			# Leash check
			if (has_home or temp_home) and _dist_sq_to_home() > HOME_MAX_DIST * HOME_MAX_DIST:
				_home_max_dist = true
				_set_state(State.ATTACK_TO_NEUTRAL)
				return
			# Energy depleted — disengage and return home to recover
			if stats.energy < 1.0:
				_set_state(State.ATTACK_TO_NEUTRAL)
				return
			# Player ran away
			if dist_sq > CHASE_DIST * CHASE_DIST:
				_set_state(State.ATTACK_TO_NEUTRAL)
				return
			# Player within melee range
			if dist_sq < _attack_dist * _attack_dist:
				_update_facing_toward(player.global_position)
				_set_state(State.IDLE_ATTACK)
				return
			_move_toward_target(player.global_position, stats.mspd * CHASE_SPEED_MULT)

		State.ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			_update_facing_toward(player.global_position)
			# Hit fires at the designated frame — not at animation end
			if not _hit_applied and _active_ability != null \
					and sprite.frame >= _active_ability.hit_frame:
				_hit_applied = true
				var hit_range : float = _active_ability.range_ + ATTACK_HIT_GRACE
				if dist_sq < hit_range * hit_range:
					var dir : Vector3 = player.global_position - global_position
					dir.y = 0.0
					if dir.length_squared() > 0.001:
						dir = dir.normalized()
					if player.has_method("receive_hit"):
						var dmg : float = _active_ability.calc_damage(stats)
						player.call("receive_hit", dmg, dir, self)
						stats.gain_focus_on_hit(dmg)
						# Status effect proc — no knockback, flash handled in player.apply_status
						if _active_ability.effect_name != "" \
								and randf() < _active_ability.effect_chance:
							player.call("apply_status",
									_active_ability.effect_name,
									_active_ability.effect_max_stacks)
			# State transition waits for the full animation to finish.
			# Per-ability cooldown already started on state entry — no global timer needed.
			if _anim_done:
				if dist_sq < _attack_dist * _attack_dist:
					_set_state(State.IDLE_ATTACK)
				elif dist_sq < CHASE_DIST * CHASE_DIST:
					_set_state(State.CHASE)
				else:
					_set_state(State.ATTACK_TO_NEUTRAL)

		State.ATTACK_TO_NEUTRAL:
			velocity.x = 0.0
			velocity.z = 0.0
			if _anim_done:
				# Re-engage only if leash was not the cause AND energy is recovered
				if not _home_max_dist and stats.energy >= 1.0 and dist_sq < CHASE_DIST * CHASE_DIST:
					_set_state(State.NEUTRAL_TO_ATTACK)
				else:
					_set_state(State.RETURNING)

		State.RETURNING:
			var dist_home_sq : float = _dist_sq_to_home()
			if dist_home_sq <= HOME_ARRIVE_DIST * HOME_ARRIVE_DIST:
				_snap_to_home()
				_set_state(State.IDLE_NEUTRAL)
				return
			_move_toward_target(home_position, stats.mspd * RETURN_SPEED_MULT)

		State.DEATH:
			velocity.x = 0.0
			velocity.z = 0.0
			if _anim_done:
				_set_state(State.DEAD)

		State.DEAD:
			velocity.x = 0.0
			velocity.z = 0.0


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state     = new_state
	_anim_done = false
	in_combat = (state == State.NEUTRAL_TO_ATTACK or state == State.IDLE_ATTACK
			or state == State.CHASE or state == State.ATTACK)
	is_dead   = (state == State.DEATH or state == State.DEAD)
	_update_ring_color()

	match state:
		State.RETURNING:
			if is_targeted:
				player.call("_clear_target")
		State.NEUTRAL_TO_ATTACK:
			# Immigrants record combat entry position as temp home (combat leash origin)
			if not has_home:
				home_position = global_position
				temp_home     = true
			_update_facing_toward(player.global_position)
		State.NOTICE:
			_update_facing_toward(player.global_position)
		State.IDLE_ATTACK:
			_update_facing_toward(player.global_position)
		State.ATTACK:
			_active_ability = _pick_best_ability()
			if _active_ability == null:
				# Nothing ready (race condition) — fall back and wait
				state = State.IDLE_ATTACK
				return
			_active_ability.spend(stats)
			_chosen_attack = _active_ability.anim
			_hit_applied   = false
			_update_facing_toward(player.global_position)
		State.DEAD:
			_start_death_fade()
			return   # no animation sync needed

	# _sync_anim() will pick the correct animation next frame


# =============================================================================
# MOVEMENT & FACING
# =============================================================================

func _move_toward_target(target: Vector3, speed: float) -> void:
	var diff : Vector3 = target - global_position
	diff.y = 0.0
	if diff.length_squared() < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir : Vector3 = diff.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_move_dir  = dir
	_update_facing()


func _update_facing() -> void:
	if camera_rig == null or _move_dir == Vector3.ZERO:
		return
	var h         : float   = camera_rig.h_angle
	var cam_fwd   : Vector3 = Vector3(-sin(h), 0.0, -cos(h))
	var cam_right : Vector3 = Vector3( cos(h), 0.0, -sin(h))
	# dot > 0 with cam_fwd → moving away from camera → back animation
	facing_back  = _move_dir.dot(cam_fwd)   > 0.0
	# dot > 0 with cam_right → moving right → no flip (sprites drawn facing right)
	facing_right = _move_dir.dot(cam_right) > 0.0


func _update_facing_toward(target: Vector3) -> void:
	var diff : Vector3 = target - global_position
	diff.y = 0.0
	if diff.length_squared() < 0.001:
		return
	_move_dir = diff.normalized()
	_update_facing()


# =============================================================================
# ANIMATION
# =============================================================================

func _sync_anim() -> void:
	if state == State.DEAD:
		return

	# Recompute facing every frame so flip_h stays correct when the camera
	# rotates while the creature is stationary (attack, notice, stance anims).
	if camera_rig != null and _move_dir != Vector3.ZERO:
		_update_facing()

	var base : String
	match state:
		State.IDLE_NEUTRAL:           base = "idle_neutral"
		State.WANDER:                 base = "wander"
		State.NOTICE:                 base = "notice"
		State.NEUTRAL_TO_ATTACK:      base = "neutral_to_attack"
		State.IDLE_ATTACK:            base = "idle_attack"
		State.CHASE, State.RETURNING: base = "run"
		State.ATTACK_TO_NEUTRAL:      base = "attack_to_neutral"
		State.ATTACK:                 base = _chosen_attack
		State.DEATH:                  base = "death"
		_:                            return

	var target : String = base + ("_back" if facing_back else "_front")
	if not sprite.sprite_frames.has_animation(target):
		target = base + "_front"   # fallback — back variant may not exist yet
	if not sprite.sprite_frames.has_animation(target):
		return

	if sprite.animation != target:
		var same_base : bool = sprite.animation.begins_with(base)
		if state in ONE_SHOT_STATES and sprite.is_playing() and same_base:
			# Camera crossed front↔back threshold mid one-shot animation.
			# Switch variant but continue from the same frame so the swing
			# looks seamless rather than restarting from frame 0.
			var cur_frame : int = sprite.frame
			var max_frame : int = sprite.sprite_frames.get_frame_count(target) - 1
			sprite.sprite_frames.set_animation_loop(target, false)
			sprite.play(target)                       # resets to 0 internally
			sprite.frame = mini(cur_frame, max_frame) # override before next tick
		else:
			sprite.sprite_frames.set_animation_loop(target, state not in ONE_SHOT_STATES)
			sprite.stop()
			sprite.frame = 0
			sprite.play(target)

	sprite.flip_h = not facing_right


func _pick_best_ability() -> Ability:
	# Returns the ready ability with the highest damage_mult, or null if none ready.
	var dist : float   = sqrt(_dist_sq_to_player())
	var best : Ability = null
	for ab : Ability in _creature_abilities:
		if not ab.can_use(stats):
			continue
		if dist > ab.range_:
			continue
		if best == null or ab.damage_mult > best.damage_mult:
			best = ab
	return best


# =============================================================================
# COMBAT
# =============================================================================

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
	if is_dead or _effects.is_empty():
		return
	var to_remove : Array[String] = []
	for effect_id : String in _effects:
		var se  : StatusEffect = _effects[effect_id]
		if se.tick(dt):
			var dmg    : float = se.tick_dmg * float(se.stacks)
			var actual : float = stats.take_damage(dmg, se.is_magic)
			if actual > 0.0:
				_start_status_flash(se.color)
			if not stats.is_alive() and not _pending_death:
				_pending_death = true
		se.update(dt)
		if se.expired:
			to_remove.append(effect_id)
	for id : String in to_remove:
		_effects.erase(id)


func _start_status_flash(col: Color) -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", col,         0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func receive_hit(damage: float, knockback_dir: Vector3) -> void:
	if state == State.DEAD or state == State.DEATH:
		return
	var actual : float = stats.take_damage(damage)
	stats.gain_focus_on_receive(actual)
	_start_hit_flash()
	_apply_knockback(knockback_dir)

	# Neutral creatures enter combat when hit
	if aggression_type == "neutral":
		var non_combat : Array = [
			State.IDLE_NEUTRAL, State.WANDER, State.NOTICE,
			State.ATTACK_TO_NEUTRAL, State.RETURNING
		]
		if state in non_combat:
			_update_facing_toward(player.global_position)
			_set_state(State.NEUTRAL_TO_ATTACK)

	if not stats.is_alive():
		_pending_death = true


func _start_hit_flash() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.0, 0.15, 0.15, 1.0), 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE,                  0.10)


func _apply_knockback(dir: Vector3) -> void:
	var flat : Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0:
		_knockback_vel = flat.normalized() * KNOCKBACK_STRENGTH



func _enter_death() -> void:
	state      = State.DEATH
	_anim_done = false
	velocity   = Vector3.ZERO
	_update_facing_toward(player.global_position)
	# _sync_anim() will play death_front / death_back this frame


func _start_death_fade() -> void:
	# Holds corpse (last frame) for 90 seconds, then fades out and frees.
	if _fading:
		return
	_fading = true
	var tw := create_tween()
	tw.tween_interval(90.0)
	tw.tween_property(sprite, "modulate:a", 0.0, 2.5)
	tw.tween_callback(func() -> void: queue_free())


# =============================================================================
# HELPERS
# =============================================================================

func _is_aggressive() -> bool:
	return void_touched or aggression_type == "hostile"


func _dist_sq_to_player() -> float:
	if player == null:
		return INF
	var diff : Vector3 = global_position - player.global_position
	diff.y = 0.0
	return diff.length_squared()


func _dist_sq_to_home() -> float:
	if not has_home and not temp_home:
		return 0.0
	var diff : Vector3 = global_position - home_position
	diff.y = 0.0
	return diff.length_squared()


func _snap_to_home() -> void:
	velocity       = Vector3.ZERO
	_home_max_dist = false
	_wander_timer  = 0.0
	_wander_elapsed = 0.0
	_force_wander  = false
	if temp_home:
		home_position = Vector3.ZERO
		temp_home     = false
