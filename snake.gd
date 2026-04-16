extends CharacterBody2D

# =============================================================================
# SNAKE.GD
#
# Responsibilities:
#   - Full state machine: idle_neutral ↔ wander ↔ notice → enter_stance
#                         ↔ idle_attack ↔ chase ↔ exit_stance ↔ returning
#                         → attack_bite / attack_tail_slam → death → dead
#   - Wander randomly when idle, chase and attack when player is near
#   - Return home when player escapes or energy runs out
#
# What this script does NOT do:
#   - Deal actual damage  		(ability does that).
#   - Set z_index or rotation  	(game.gd does that).
# =============================================================================

const SPRITE_SIZE := 96
const SPRITE_PATH := "res://assets/spritesheets/snake/"


# ── AI distances ───────────────────────────────────────────────────────────────

const NOTICE_COOLDOWN  := 3.0
const NOTICE_DIRECTION := 450.0
const NOTICE_DIST      := 400.0
const CHASE_DIST       := 900.0
const ATTACK_DIST      := 60.0
const HOME_MAX_DIST    := 2000.0
const HOME_DIST        := 16.0
const FLEE_SPEED       := 240.0

# Pre-squared — avoids sqrt in distance comparisons every frame.
const NOTICE_DIRECTION_SQ := NOTICE_DIRECTION * NOTICE_DIRECTION
const NOTICE_DIST_SQ      := NOTICE_DIST      * NOTICE_DIST
const CHASE_DIST_SQ       := CHASE_DIST       * CHASE_DIST
const ATTACK_DIST_SQ      := ATTACK_DIST      * ATTACK_DIST
const HOME_MAX_DIST_SQ    := HOME_MAX_DIST    * HOME_MAX_DIST
const HOME_DIST_SQ        := HOME_DIST        * HOME_DIST


# ── Wander settings ────────────────────────────────────────────────────────────

const WANDER_CHANCE        := 0.30
const WANDER_INTERVAL_MIN  := 0.9
const WANDER_INTERVAL_MAX  := 1.1
const WANDER_DURATION_MIN  := 0.5
const WANDER_DURATION_MAX  := 3.0


# ── Pathfinding settings ───────────────────────────────────────────────────────

const TILE_SIZE            := 32
const PATH_INTERVAL_MIN    := 0.8
const PATH_INTERVAL_MAX    := 1.2
const LOS_INTERVAL_MIN     := 1.8
const LOS_INTERVAL_MAX     := 2.2
const LOS_CLEAR_INTERVAL   := 0.4   # recheck interval when LOS is clear (shorter than blocked interval).
const WAYPOINT_REACH_SQ    := (TILE_SIZE * 0.5) * (TILE_SIZE * 0.5)
const STUCK_TIME           := 0.3   # sample interval; if not enough progress in this window → idle_attack.


# ── Debug ──────────────────────────────────────────────────────────────────────

const DEBUG_PATH := true   # draws A* waypoints; set false to disable


# ── Other ──────────────────────────────────────────────────────────────────────

enum State {
	IDLE_NEUTRAL, WANDER, NOTICE, ENTER_STANCE, IDLE_ATTACK,
	CHASE, EXIT_STANCE, RETURNING, ATTACK_BITE, ATTACK_TAIL_SLAM,
	DEATH, DEAD
}

const ONE_SHOT_STATES := {
	State.NOTICE: true, State.ENTER_STANCE: true, State.EXIT_STANCE: true,
	State.ATTACK_BITE: true, State.ATTACK_TAIL_SLAM: true, State.DEATH: true
}

const MOVING_STATES := {
	State.WANDER: true, State.CHASE: true, State.RETURNING: true
}

const COMBAT_STATES := {
	State.ENTER_STANCE: true, State.IDLE_ATTACK: true, State.CHASE: true,
	State.EXIT_STANCE: true, State.ATTACK_BITE: true, State.ATTACK_TAIL_SLAM: true
}

const STATE_ANIM := {
	State.IDLE_NEUTRAL		: "idle_neutral",
	State.WANDER       		: "move",
	State.NOTICE       		: "notice",
	State.ENTER_STANCE 		: "enter_stance",
	State.IDLE_ATTACK  		: "idle_attack",
	State.CHASE        		: "move",
	State.EXIT_STANCE  		: "exit_stance",
	State.RETURNING    		: "move",
	State.ATTACK_BITE  		: "attack_bite",
	State.ATTACK_TAIL_SLAM 	: "attack_tail slam",
	State.DEATH        		: "death",
}


# ── State ──────────────────────────────────────────────────────────────────────

var state        : State = State.IDLE_NEUTRAL
var facing_right : bool  = false
var in_combat    : bool  = false
var anim_done    : bool  = false
var alive        : bool  = true
var corpse_alpha : float = 255.0


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
var has_home        : bool    = false
var temp_home       : bool    = false
var is_returning    : bool    = false
var fleeing         : bool    = false
var home_max_dist   : bool    = false
var notice_cooldown : float   = 0.0
var out_of_energy   : bool    = false


# ── Pathfinding ────────────────────────────────────────────────────────────────

var pathfinder        : Pathfinder   	# set game._spawn_creature().
var path              : Array   = []  	# set _move_smart().
var path_timer        : float   = 0.0 	# set _move_smart().
var path_interval     : float   = 0.0 	# set _ready().
var has_los           : bool    = false # set _move_smart().
var los_lock_timer    : float   = 0.0   # set _move_smart().
var los_lock_interval : float   = 0.0   # set _ready().


# ── References ─────────────────────────────────────────────────────────────────

var sprite  	: AnimatedSprite2D  # init _create_sprite().
var player  	: CharacterBody2D   # set game._spawn_creature().
var stats   	: Stats             # set configure().
var abilities 	: Array = [] 		# Array[Ability]. init configure().

# ── Combat feedback buffers ────────────────────────────────────────────────────

# Set in _physics_process(), read and cleared by combat_feedback._read_creatures().
var _cf_dot     : float         = 0.0
var _cf_expired : Array[String] = []

# Setter caches trig and corrects facing_right on rotation so _move_toward stays cheap.
var camera_angle : float = 0.0:
	set(value):
		camera_angle = value
		var rad := deg_to_rad(value)
		_cos_a       = cos(rad)
		_sin_a       = sin(rad)
		facing_right = (_move_dx * _cos_a - _move_dy * _sin_a) > 0

var _cos_a   : float = 1.0   # set camera_angle setter.
var _sin_a   : float = 0.0   # set camera_angle setter.
var _move_dx : float = 0.0   # set _update_facing(), _move_toward().
var _move_dy : float = 1.0   # set _update_facing(), _move_toward().


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	wander_timer      = randf_range(0.0, 1.0)
	wander_interval   = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	path_interval     = randf_range(PATH_INTERVAL_MIN,   PATH_INTERVAL_MAX)
	los_lock_interval = randf_range(LOS_INTERVAL_MIN,    LOS_INTERVAL_MAX)
	_create_sprite()


# Called: _ready().
func _create_sprite() -> void:

	sprite               = AnimatedSprite2D.new()
	sprite.z_as_relative = false
	add_child(sprite)

	_load_animations()


# Called: _create_sprite().
func _load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	for s in STATE_ANIM:
		var anim_name : String = STATE_ANIM[s]
		# Skip if already loaded (multiple states can share one animation, e.g. "move").
		if frames.has_animation(anim_name):
			continue
		var anim_path : String    = SPRITE_PATH + anim_name + ".png"
		var texture   : Texture2D = load(anim_path)
		var loop      : bool      = s not in ONE_SHOT_STATES

		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, 8.0)

		var frame_count := texture.get_width() / SPRITE_SIZE
		for i in range(frame_count):
			var atlas   := AtlasTexture.new()
			atlas.atlas  = texture
			atlas.region = Rect2(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
			frames.add_frame(anim_name, atlas)

	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play(STATE_ANIM[State.IDLE_NEUTRAL])


# Called: game._spawn_creature().
func configure(cfg: Dictionary, world_pos: Vector2) -> void:

	stats        = Stats.new(cfg["str"], cfg["agi"], cfg["sta"], 
		cfg["int"], cfg["spr"], cfg["res"], cfg["def"], cfg["bms"], cfg["exp"])
	is_returning = cfg["returning"]
	fleeing      = cfg["fleeing"]
	if cfg["home"]:
		home_position = world_pos
		has_home      = true
	
	stats.effects     = StatusEffect.EffectManager.new()
	
	abilities   = [
		Ability.get_ability("snake_bite",      stats.level),
		Ability.get_ability("snake_tail_slam",  stats.level),
	]


# =============================================================================
# ANIMATION
# =============================================================================

# Called: _physics_process().
func _sync_anim() -> void:

	sprite.flip_h = facing_right


# Called: sprite.animation_finished signal.
func _on_anim_finished() -> void:

	if state in ONE_SHOT_STATES:
		anim_done = true


# Called: _update_state(), _wander(), _snap_to_home(), _begin_death().
func _set_state(new_state: State) -> void:

	if state == new_state:
		return
	state     = new_state
	anim_done = false
	in_combat = new_state in COMBAT_STATES
	if state != State.DEAD:
		sprite.play(STATE_ANIM[state])


# =============================================================================
# STATE MACHINE
# =============================================================================

# Called: _physics_process().
func _update_state(dt: float) -> void:

	var player_ok 	: bool  = player.state != player.State.DEATH and player.state != player.State.DEAD
	var dist_sq 	: float = position.distance_squared_to(player.position)

	match state:

		State.IDLE_NEUTRAL, State.WANDER:
			# If the player is within creatures notice direction 
			# distance then creature updates facing.
			if player_ok and dist_sq < NOTICE_DIRECTION_SQ:
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				# If the player is within creatures notice distance and 
				# notice cooldown is up then creature enters notice state.
				if dist_sq < NOTICE_DIST_SQ and notice_cooldown <= 0.0:
					_set_state(State.NOTICE)
					return
			# Creature can wander while in wander state or player not ok or in idle neutral state 
			# but only if the players distance is bigger than notice direction distance.
			if state == State.WANDER or not player_ok or dist_sq  > NOTICE_DIRECTION_SQ:
				var signal_ := _wander(dt)
				if signal_ == "start": _set_state(State.WANDER)
				elif signal_ == "done": _set_state(State.IDLE_NEUTRAL)

		State.NOTICE:
			# If the player is within attack distance creature 
			# bypasses notice anim_done and enters enter stance state.
			if dist_sq < ATTACK_DIST_SQ:
				_set_state(State.ENTER_STANCE)
			elif anim_done:
				# If the player is still within notice distance after 
				# anim_done the creature enters enter stance state.
				if dist_sq < NOTICE_DIST_SQ:
					_set_state(State.ENTER_STANCE)
				# If the player has left notice distance while anim_done
				# then the creature enters idle neutral state.
				else:
					_set_state(State.IDLE_NEUTRAL)

		State.ENTER_STANCE:
			# If creatures has no initial home it sets one here.
			if not has_home:
				home_position = position
				temp_home     = true
			if anim_done:
				# When ani_done the creature updates its facing.
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				# If the player is within attack distance after anim_done the
				# creature enters idle attack state.
				if dist_sq < ATTACK_DIST_SQ:
					_set_state(State.IDLE_ATTACK)
				# If the player is within notice distance after anim_done the
				# creature enters chase state.
				elif dist_sq < NOTICE_DIST_SQ: 
					_set_state(State.CHASE)
				# If the player is out of notice distance after anim_done the
				# creature enters exit stance state.
				else:                           
					_set_state(State.EXIT_STANCE)

		State.IDLE_ATTACK:
			# If the player is not okay or the creature is 
			# out of energy it enters returning state.
			if not player_ok or out_of_energy:
				_set_state(State.RETURNING)
			# If the player is within attack distance then the
			# creatures tries to attack.
			elif dist_sq < ATTACK_DIST_SQ:
				_try_attack()
			# If the player is within chasing distance 
			# the creature enters chase state.
			elif dist_sq < CHASE_DIST_SQ:
				_set_state(State.CHASE)
			# If the player is out of chasing distance
			# the creatures enters exit stance state.
			else:
				_set_state(State.EXIT_STANCE)

		State.CHASE:
			# Calculates the distance to home position.
			var dist_home_sq := position.distance_squared_to(home_position)
			# If the creature has reached the maximum distance 
			# from home it enters returning state.
			if dist_home_sq > HOME_MAX_DIST_SQ:
				home_max_dist = true
				_set_state(State.RETURNING)
			# If the player is within attack distance then the
			# creature updates its facing and enters idle attack state.
			elif dist_sq < ATTACK_DIST_SQ:
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				_set_state(State.IDLE_ATTACK)
			# If the player is out of chasing distance the
			# creature enters exit stance state.
			elif dist_sq > CHASE_DIST_SQ:  _set_state(State.EXIT_STANCE)
			# If the player is still within chasing distance the
			# creature move smart towards the player.
			else:
				_move_smart(player.position, stats.mspd, dt)

		State.EXIT_STANCE:
			
			if anim_done:
				# When anim_done if the player is within notice distance
				# the creature enters enter stance state.
				if dist_sq < NOTICE_DIST_SQ: 
					_set_state(State.ENTER_STANCE)
				# When anim_done if the player is out of notice distance
				# the creature enters returning state.
				else:                         
					_set_state(State.RETURNING)

		State.RETURNING:
			# Calculates the distance to home position and forced.
			var dist_home_sq := position.distance_squared_to(home_position)
			var forced       := is_returning or home_max_dist or out_of_energy or not player_ok
			# If the player is out of notice distance or the creature is
			# forced to return home if it is next to home snaps to it otherwise
			# it moves towards its home (original or temporary) position.
			if forced or dist_sq > NOTICE_DIST_SQ:
				if dist_home_sq <= HOME_DIST_SQ:
					_snap_to_home()
				else:
					_move_smart(home_position, FLEE_SPEED, dt)
			# If player is within notice distance and the creature is not forced
			# the creature updates its facing.
			else:
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				# If player is within attack distance the creature enters idle attack state.
				if dist_sq < ATTACK_DIST_SQ:
					_set_state(State.IDLE_ATTACK)
				# Otherwise the creature enters enter stance state.
				else:                         
					_set_state(State.ENTER_STANCE)

		State.ATTACK_BITE, State.ATTACK_TAIL_SLAM:
			# If anim_done then the creature enters idle attack state.
			if anim_done:
				_set_state(State.IDLE_ATTACK)

		State.DEATH:
			# If anim_done then the creature enters dead state.
			if anim_done:
				_set_state(State.DEAD)


# =============================================================================
# MOVEMENT
# =============================================================================

# LOOP
func _physics_process(dt: float) -> void:

	if is_dead(dt):
		return
		
	_update_state(dt)
	
	_sync_anim()
	
	if state not in MOVING_STATES:
		velocity = Vector2.ZERO
		
	if state != State.DEATH:
		
		if los_lock_timer > 0.0:
			los_lock_timer -= dt
			
		if notice_cooldown > 0.0:
			notice_cooldown -= dt
			
		# Update out_of_energy status.
		if stats.energy <= 0:
			out_of_energy = true
			
		# Update abilities tick timer.
		for ability in abilities:
			ability.tick(dt)
			
		# Update stats ( hp, energy, rage, mp).
		if not in_combat:
			stats.regen(dt)
			
		# Update effects, buffer dot/expired for combat_feedback, then apply.
		var _dot := stats.update_effects(dt)
		_cf_dot     = _dot
		_cf_expired = stats.effects.expired_names.duplicate()
		take_damage(_dot, true)

	if velocity != Vector2.ZERO:
		move_and_slide()
		
	# Prints creatures path.
	queue_redraw()


# Called: _update_state() during CHASE and RETURNING.
func _move_smart(target_pos: Vector2, speed: float, dt: float) -> void:
	
	# If time for LOS check.
	if los_lock_timer <= 0.0:
		has_los        = pathfinder.line_of_sight(position, target_pos)
		los_lock_timer = LOS_CLEAR_INTERVAL if has_los else los_lock_interval

	# If clear LOS.
	if has_los:
		path.clear()
		_move_toward(target_pos, speed)
		return

	path_timer += dt
	# If time for path finding.
	if path_timer >= path_interval or path.is_empty():
		path_timer = 0.0
		path = pathfinder.find_path(position, target_pos)

	# A* couldnt find a path.
	if path.is_empty():
		_move_toward(target_pos, speed)
		return

	# Pop waypoints as they are reached.
	if position.distance_squared_to(path[0]) < WAYPOINT_REACH_SQ:
		path.pop_front()
	
	# If no other waypoints.
	if path.is_empty():
		return
	
	# Move towards the next waypoint.
	_move_toward(path[0], speed)
	
	
# Called: _move_smart().
func _move_toward(target_pos: Vector2, speed: float) -> void:

	var direction	:= target_pos - position
	var len_sq 		:= direction.length_squared()
	if len_sq < 1.0:
		velocity = Vector2.ZERO
		return
	
	var new_right := (direction.x * _cos_a - direction.y * _sin_a) > 0
	if new_right != facing_right:
		facing_right = new_right
		_move_dx = direction.x
		_move_dy = direction.y
		
	velocity = direction / sqrt(len_sq) * speed	# normalization.
	
	
# Called: _update_state().
func _wander(dt: float) -> String:

	# Returns "start" to enter wander state, "done" to return to idle, "" to continue.
	if state == State.IDLE_NEUTRAL:
		wander_timer += dt
		if wander_timer >= wander_interval:
			wander_timer    = 0.0
			wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
			if randf() < WANDER_CHANCE:
				force_wander = true
				return "start"
		return ""

	# Currently wandering — resolve direction first, then apply velocity.
	if force_wander:
		force_wander    = false
		var angle       := randf() * TAU
		wander_dx       = cos(angle)
		wander_dy       = sin(angle)
		wander_elapsed  = 0.0
		wander_duration = randf_range(WANDER_DURATION_MIN, WANDER_DURATION_MAX)
		_update_facing(wander_dx, wander_dy)

	wander_elapsed += dt
	velocity = Vector2(wander_dx, wander_dy) * stats.mspd

	if wander_elapsed >= wander_duration:
		return "done"

	return ""


# Called: _update_state().
func _snap_to_home() -> void:

	position          = home_position
	velocity          = Vector2.ZERO
	home_max_dist     = false
	out_of_energy     = false
	notice_cooldown   = NOTICE_COOLDOWN
	wander_timer      = 0.0
	wander_elapsed    = 0.0
	force_wander      = false
	path.clear()
	path_timer        = 0.0
	has_los           = false
	los_lock_timer    = 0.0
	if temp_home:
		home_position = Vector2.ZERO
		temp_home     = false
	_set_state(State.IDLE_NEUTRAL)


# =============================================================================
# FACING
# =============================================================================

# Called: _update_state(), _wander().
func _update_facing(world_dx: float, world_dy: float) -> void:

	# Uses cached trig — no cos/sin calls here.
	_move_dx     = world_dx
	_move_dy     = world_dy
	facing_right = (world_dx * _cos_a - world_dy * _sin_a) > 0


# =============================================================================
# COMBAT
# =============================================================================

# Called: _update_state().
func _try_attack() -> void:

	# Find any ability that is ready and in range.
	var dist := position.distance_to(player.position)
	var chosen : Ability = null
	for ability in abilities:
		if ability.check_resources(stats, dist):
			# Prefer higher damage_multiplier abilities.
			if chosen == null or ability.damage_mult > chosen.damage_mult:
				chosen = ability
	
	# If nothing is ready.
	if not chosen:
		return
	if not chosen.check_resources(stats, dist):
		return
	
	chosen.use(stats, [player], dist)
		
	if chosen.anim == "attack_bite":
		_set_state(State.ATTACK_BITE)
	else:
		_set_state(State.ATTACK_TAIL_SLAM)


# Called: ability.use().
func take_damage(raw_damage: float, dot: bool = false, is_magic: bool = false, is_crit: bool = false) -> float:

	var damage : float = stats.take_damage(raw_damage, dot, is_magic, is_crit)
	
	if not stats.is_alive():
		alive = false
		_begin_death()

	return damage


# Called: take_damage().
func _begin_death() -> void:

	stats.cleanse_all_effects()
	_set_state(State.DEATH)
	
	
# Called: _physics_process().
func is_dead(dt: float) -> bool:
	
	if state == State.DEAD:
		corpse_alpha = maxf(0.0, corpse_alpha - 300.0 * dt)
		sprite.modulate = Color(1.0, 1.0, 1.0, corpse_alpha / 255.0)
		if corpse_alpha <= 0.0:
			queue_free()
		return true
	return false


# =============================================================================
# DEBUG
# =============================================================================

# Called: _physics_process() triggered by queue_redraw().
func _draw() -> void:

	if not DEBUG_PATH or path.is_empty():
		return
	_draw_path()


# Called: _draw().
func _draw_path() -> void:

	# Waypoints are in world space; _draw() uses local space, so subtract position.
	var prev := Vector2.ZERO   # local origin = creature's own position
	for i in range(path.size()):
		var wp : Vector2 = path[i] - position
		draw_circle(wp, 4.0, Color(1.0, 0.85, 0.0, 0.9))
		draw_line(prev, wp, Color(0.0, 0.75, 1.0, 0.6), 1.5)
		prev = wp
