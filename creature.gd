extends CharacterBody2D

const SPRITE_SIZE 		:= 96
const SPRITE_PATH		:= "res://assets/spritesheets/"
const ANIMATION_SPEED 	:= 8

# ── AI distances ───────────────────────────────────────────────────────────────

const NOTICE_COOLDOWN  := 2.5
const NOTICE_DIRECTION := 450.0
const NOTICE_DIST      := 400.0
const CHASE_DIST       := 10000.0#900.0
const ATTACK_DIST      := 60.0
const HOME_MAX_DIST    := 20000.0#2000.0
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

const WANDER_CHANCE        := 1.00
const WANDER_INTERVAL_MIN  := 0.9
const WANDER_INTERVAL_MAX  := 1.1
const WANDER_DURATION_MIN  := 0.5
const WANDER_DURATION_MAX  := 3.0


# ── Pathfinding settings ───────────────────────────────────────────────────────

const TILE_SIZE            := 32
const PATH_INTERVAL_MIN    := 0.8
const PATH_INTERVAL_MAX    := 1.2
const WAYPOINT_REACH_SQ    := (TILE_SIZE * 0.5) * (TILE_SIZE * 0.5)

# ── Stuck detection ────────────────────────────────────────────────────────────
const STUCK_SAMPLE_INTERVAL   := 0.4    # seconds between position samples.
const STUCK_MIN_DIST_SQ       := 64.0   # 8 px²; moved less than this = stuck.
const WAIT_BASE_TIME          := 1.0    # base wait duration (seconds).
const WAIT_TIME_GROWTH        := 0.5    # extra seconds added per wait cycle.
const WAIT_MAX_CYCLES         := 4      # effective wait count before give-up.
const WAIT_PROGRESS_THRESHOLD := 48.0   # pixels moved since first wait; less = no real progress.
const BLOCK_TIMER_DURATION	  := 1.0


# ── Other ──────────────────────────────────────────────────────────────────────

enum Type {
	RAT, SNAKE
}

enum State {
	IDLE_NEUTRAL, WANDER, NOTICE, ENTER_STANCE, IDLE_ATTACK,
	CHASE, EXIT_STANCE, RETURNING, ATTACK, DEATH, DEAD
}

const MAP_TYPE := {
	Type.RAT	: "rat",
	Type.SNAKE	: "snake"
}

const MAP_STRING_TYPE := {
	"rat" 	: Type.RAT,
	"snake" : Type.SNAKE
}

const STATE_ANIM := {
	State.IDLE_NEUTRAL		: ["idle_neutral"],
	State.WANDER       		: ["move"],
	State.NOTICE       		: ["notice"],
	State.ENTER_STANCE 		: ["enter_stance"],
	State.IDLE_ATTACK  		: ["idle_attack"],
	State.CHASE        		: ["move"],
	State.EXIT_STANCE  		: ["exit_stance"],
	State.RETURNING    		: ["move"],
	State.ATTACK  			: ["rat_bite","rat_slash","snake_bite","snake_tail_slam"],
	State.DEATH        		: ["death"]
}

const ONE_SHOT_STATES := {
	State.NOTICE: true, State.ENTER_STANCE: true, State.EXIT_STANCE: true,
	State.ATTACK: true, State.DEATH: true
}

const MOVING_STATES := {
	State.WANDER: true, State.CHASE: true, State.RETURNING: true
}

const COMBAT_STATES := {
	State.ENTER_STANCE: true, State.IDLE_ATTACK: true, State.CHASE: true,
	State.EXIT_STANCE: true, State.ATTACK: true
}


# ── State ──────────────────────────────────────────────────────────────────────

var state        : State = State.IDLE_NEUTRAL
var facing_right : bool  = false
var in_combat    : bool  = false
var anim_done    : bool  = false
var alive        : bool  = true
var corpse_alpha : float = 255.0
var is_inspected : bool  = false   # set stat_panel. Prevents queue_free while panel is open.


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

var pathfinder    : Pathfinder    	# set init().
var path          : Array   = []  	# set _move_smart().
var path_timer    : float   = 0.0 	# set _move_smart().
var path_interval : float   = 0.0 	# set _ready().


# ── Stuck detection ────────────────────────────────────────────────────────────

var _stuck_timer       		: float   = 0.0
var _stuck_pos         		: Vector2 = Vector2.ZERO
var _stuck_detected   		: bool     = false
var wait_damage_threshold	: float# damage units that count as one extra effective wait cycle.
var block_timer				: float = 0.0


# ── Wait cycle ─────────────────────────────────────────────────────────────────

var _wait_anim           : bool    = false
var _wait_timer          : float   = 0.0
var _wait_count          : int     = 0     			# total wait cycles entered this session.
var _wait_on_chase       : bool    = false 			# true = chase wait, false = returning wait.
var _wait_origin_pos     : Vector2 = Vector2.ZERO   # position at first wait entry.
var _wait_damage_acc     : float   = 0.0            # damage taken across wait cycles.
var _saved_is_returning  : bool    = false          # eased during returning wait.
var _saved_home_max_dist : bool    = false          # eased during returning wait.


# ── References ─────────────────────────────────────────────────────────────────

var stats   	: Stats             # set init().
var abilities 	: Array = [] 		# set init().
var player  	: CharacterBody2D   # set init().
var sprite  	: AnimatedSprite2D  # init init().


# ── Creature type ──────────────────────────────────────────────────────────────

var type		: Type
var sprite_path : String
var attack_types: Dictionary


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

# Called: game._spawn_creature().
func init(cfg: Dictionary, player: CharacterBody2D, camera_angle: float, pathfinder: Pathfinder) -> void:
	
	wander_timer    = randf_range(0.0, 1.0)
	wander_interval = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	path_interval   = randf_range(PATH_INTERVAL_MIN,   PATH_INTERVAL_MAX)
	
	type 		 = MAP_STRING_TYPE[cfg["type"]]
	
	stats        = Stats.new(cfg["str"], cfg["agi"], cfg["sta"], 
		cfg["int"], cfg["spr"], cfg["res"], cfg["def"], cfg["bms"], cfg["exp"])
		
	if cfg["home"]:
		home_position = position
		has_home      = true
		
	is_returning = cfg["returning"]
	fleeing      = cfg["fleeing"]
	
	stats.effects     		= StatusEffect.EffectManager.new()
	wait_damage_threshold 	= maxf(1.0, stats.hp_max * 10.0 / 100.0)
	
	
	sprite_path = SPRITE_PATH + MAP_TYPE[type] + "/"
	
	for attack_name in STATE_ANIM[State.ATTACK]:
		if attack_name.split("_")[0] == MAP_TYPE[type]:
			abilities.append(Ability.get_ability(attack_name, stats.level))
	
	self.player = player
	self.camera_angle = camera_angle
	self.pathfinder = pathfinder
	
	# Create and add sprite as child.
	sprite               = AnimatedSprite2D.new()
	sprite.z_as_relative = false
	add_child(sprite)

	_load_animations()


# Called: init().
func _load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	var valid_anim_names : Array = []
	var anim_loop        : Dictionary = {}
	for state_type in STATE_ANIM:
		var anim_name = STATE_ANIM[state_type]
		if state_type != State.ATTACK and state_type != State.DEATH:
			valid_anim_names.append(anim_name[0])
			anim_loop[anim_name[0]] = state_type not in ONE_SHOT_STATES

	for attack_name in STATE_ANIM[State.ATTACK]:
		if attack_name.split("_")[0] == MAP_TYPE[type]:
			valid_anim_names.append(attack_name)
			anim_loop[attack_name] = false

	var death_anim : String = STATE_ANIM[State.DEATH][0]
	valid_anim_names.append(death_anim)
	anim_loop[death_anim] = false

	for anim_name in valid_anim_names:
		# Skip if already loaded (multiple states can share one animation, e.g. "move").
		if frames.has_animation(anim_name):
			continue
		var anim_path: String    	= sprite_path + anim_name + ".png"
		var texture  : Texture2D 	= load(anim_path)
		var loop 	 : bool 		= anim_loop.get(anim_name, true)
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		frames.set_animation_speed(anim_name, ANIMATION_SPEED)
		# Load all frames.
		var frame_count := texture.get_width() / SPRITE_SIZE
		for i in range(frame_count):
			var atlas   := AtlasTexture.new()
			atlas.atlas  = texture
			atlas.region = Rect2(i * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
			frames.add_frame(anim_name, atlas)
						
	# animation_finished signal is connected with _on_anim_finished().
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play(STATE_ANIM[State.IDLE_NEUTRAL][0])


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
	
	# Stuck detection system check.
	if _wait_anim:
		_wait_anim = false
		if not _wait_on_chase:
			is_returning  = _saved_is_returning
			home_max_dist = _saved_home_max_dist

	state     = new_state
	anim_done = false
	in_combat = new_state in COMBAT_STATES
	
	if state != State.DEAD and state != State.ATTACK:
		sprite.play(STATE_ANIM[state][0])
		
	# Seed stuck detection position.
	if state in MOVING_STATES:
		_stuck_pos      		= position
		_stuck_timer    		= 0.0
		_stuck_detected 		= false


# =============================================================================
# STATE MACHINE
# =============================================================================

# Called: _physics_process().
func _update_state(dt: float) -> void:

	var player_ok 	: bool  = player.state != player.State.DEATH and player.state != player.State.DEAD
	var dist_sq 	: float = position.distance_squared_to(player.position)

	match state:

		State.IDLE_NEUTRAL, State.WANDER:
			# If the player is within creatures notice direction distance and the
			# creature is in idle neutral then creature updates facing.
			if player_ok and dist_sq < NOTICE_DIRECTION_SQ:
				if state == State.IDLE_NEUTRAL:
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
			# from home it enters exit stance state.
			if dist_home_sq > HOME_MAX_DIST_SQ:
				home_max_dist = true
				_set_state(State.EXIT_STANCE)
			# If the player is within attack distance then the
			# creature updates its facing and enters idle attack state.
			elif dist_sq < ATTACK_DIST_SQ:
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				_set_state(State.IDLE_ATTACK)
			# If the player is out of chasing distance the
			# creature enters exit stance state.
			elif dist_sq > CHASE_DIST_SQ:
				_set_state(State.EXIT_STANCE)
			# If the player is still within chasing distance the
			# creature move smart towards the player (not stuck).
			elif not _wait_anim:
				_move_smart(player.position, stats.mspd, dt)
				#if _stuck_detected:
					#_enter_wait(true)
			# Waiting out a stuck cycle — play idle_attack animation in place.
			else:
				_wait_timer -= dt
				var effective := _wait_count + int(_wait_damage_acc / wait_damage_threshold)
				if _wait_timer <= 0.0 or effective >= WAIT_MAX_CYCLES:
					_exit_wait()

		State.EXIT_STANCE:
			
			if anim_done:
				# When anim_done if the player is within notice distance and 
				# creature not home_max_dist the creature enters enter stance state.
				if dist_sq < NOTICE_DIST_SQ and not home_max_dist: 
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
				# Normal return movement.
				elif not _wait_anim:
					_move_smart(home_position, FLEE_SPEED, dt)
					#if _stuck_detected:
						#_enter_wait(false)
				# Waiting out a stuck cycle — play idle_neutral animation in place.
				else:
					_wait_timer -= dt
					var effective := _wait_count + int(_wait_damage_acc / wait_damage_threshold)
					if _wait_timer <= 0.0 or effective >= WAIT_MAX_CYCLES:
						_exit_wait()
					
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

		State.ATTACK:
			# If anim_done the creature enters idle attacke or neutral.
			if anim_done:
				if in_combat:
					_set_state(State.IDLE_ATTACK)
				else:
					_set_state(State.IDLE_NEUTRAL)

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

	_update_stuck(dt)
	_update_state(dt)

	_sync_anim()
		
	if state != State.DEATH:

		if notice_cooldown > 0.0:
			notice_cooldown -= dt
		if stats.energy < 1:
			out_of_energy = true
		# Update abilities tick timer.
		for ability in abilities:
			ability.tick(dt)
			
		# Update stats ( hp, energy, rage, mp).
		if not in_combat:
			stats.regen(dt)
		
		# Update effects and take dot damage.
		take_damage(stats.update_effects(dt), true)

	if state not in MOVING_STATES or _wait_anim:
		velocity = Vector2.ZERO
	else:
		move_and_slide()
		_on_collision(dt)


# Called: _update_state() during CHASE and RETURNING.
func _move_smart(target_pos: Vector2, speed: float, dt: float) -> void:

	path_timer += dt
	if path_timer >= path_interval or path.is_empty():
		path_timer = 0.0
		path = pathfinder.find_path(position, target_pos)

	# Only on deadlock terrain.
	if path.is_empty():
		_move_toward(target_pos, speed)
		return

	# Pop waypoints as they are reached.
	if position.distance_squared_to(path[0]) < WAYPOINT_REACH_SQ:
		path.pop_front()
	
	# If no other waypoints — move directly toward target rather than coasting.
	if path.is_empty():
		_move_toward(target_pos, speed)
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
		
	velocity = direction / sqrt(len_sq) * speed


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
func _snap_to_home(new_home_position : Vector2 = home_position) -> void:

	position          = new_home_position
	velocity          = Vector2.ZERO
	home_max_dist     = false
	out_of_energy     = false
	notice_cooldown   = NOTICE_COOLDOWN
	wander_timer      = 0.0
	wander_elapsed    = 0.0
	force_wander      = false
	print("Path cleared!")
	path.clear()
	path_timer = 0.0
	if temp_home:
		home_position = Vector2.ZERO
		temp_home     = false
	_set_state(State.IDLE_NEUTRAL)


# Called: _physics_process() after move_and_slide().
func _on_collision(dt: float) -> void:

	# If no collision return.
	if get_slide_collision_count() == 0:
		return

	# Wandering collisions immediately pick a new wander direction.
	if state == State.WANDER:
		force_wander = true
		return
	
	block_timer += dt
	# In chasing or returning states if the blocker is another creature, 
	# temp-block the next waypoint tile of this creature because it is unreachable.
	if (state == State.CHASE or state == State.RETURNING) and block_timer > BLOCK_TIMER_DURATION:
		block_timer = 0.0
		for i in get_slide_collision_count():
			var col     := get_slide_collision(i)
			var blocker := col.get_collider()
			if blocker is CharacterBody2D and blocker != player:
				if not path.is_empty():
					print("Add temp block!")
					pathfinder.add_temp_block(path[0])
					path.clear()
				break


# =============================================================================
# STUCK DETECTION
# =============================================================================

# Called: _physics_process().
func _update_stuck(dt: float) -> void:

	# Only sample when actively moving and not paused in a wait cycle.
	if state not in MOVING_STATES or _wait_anim:
		_stuck_timer    = 0.0
		_stuck_detected = false
		return

	_stuck_timer += dt
	if _stuck_timer < STUCK_SAMPLE_INTERVAL:
		return

	_stuck_timer    = 0.0
	_stuck_detected = position.distance_squared_to(_stuck_pos) < STUCK_MIN_DIST_SQ
	_stuck_pos = position


# Called: _update_state().
func _enter_wait(on_chase: bool) -> void:

	# Record origin position only on the first wait of a stuck session.
	if _wait_count == 0:
		_wait_origin_pos = position
		_wait_damage_acc = 0.0

	_wait_on_chase    		= on_chase
	_wait_anim           	= true
	_stuck_detected   		= false
	_wait_timer        		= WAIT_BASE_TIME + _wait_count * WAIT_TIME_GROWTH
	_wait_count       		+= 1

	if on_chase:
		# Stand in place using idle_attack animation while waiting.
		sprite.play(STATE_ANIM[State.IDLE_ATTACK][0])
	# On returning.
	else:
		# Ease forced-returning flags so creature can defend itself if player approaches.
		_saved_is_returning  = is_returning
		_saved_home_max_dist = home_max_dist
		is_returning         = false
		home_max_dist        = false
		# Stand in place using idle_neutral animation while waiting.
		sprite.play(STATE_ANIM[State.IDLE_NEUTRAL][0])


# Called: _update_state().
func _exit_wait() -> void:

	_wait_anim           = false

	var effective_waits := _wait_count + int(_wait_damage_acc / wait_damage_threshold)
	var no_progress     := position.distance_to(_wait_origin_pos) < WAIT_PROGRESS_THRESHOLD
	var give_up         := effective_waits >= WAIT_MAX_CYCLES and no_progress

	if _wait_on_chase:
		if give_up:
			_wait_count      = 0
			_wait_damage_acc = 0.0
			_set_state(State.RETURNING)
		else:
			# Made enough progress — reset counters and resume.
			if not no_progress:
				_wait_count      = 0
				_wait_origin_pos = position
			sprite.play(STATE_ANIM[State.CHASE][0])
	# Wait on returning.
	else:
		# Restore eased returning flags.
		is_returning  = _saved_is_returning
		home_max_dist = _saved_home_max_dist

		if give_up:
			_wait_count      = 0
			_wait_damage_acc = 0.0
			if temp_home:
				# Treat current position as the new home and settle here.
				home_position = position
				_snap_to_home()
			else:
				# Teleport back to home.
				var home_tile := Vector2i(int(home_position.x / TILE_SIZE), int(home_position.y / TILE_SIZE)) 
				if pathfinder._grid.is_point_solid(home_tile):
					# If home_position is not free get the nearest free.
					_snap_to_home(pathfinder._nearest_walkable(home_tile))
				else:
					_snap_to_home()
		else:
			if not no_progress:
				_wait_count      = 0
				_wait_origin_pos = position
			sprite.play(STATE_ANIM[State.RETURNING][0])


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
	
	chosen.use(stats, [player], dist)
	_set_state(State.ATTACK)
	sprite.play(chosen.anim)
	

# Called: ability.use().
func take_damage(raw_damage: float, dot: bool = false, is_magic: bool = false, is_crit: bool = false) -> float:

	var damage : float = stats.take_damage(raw_damage, dot, is_magic, is_crit)

	if _wait_anim:
		_wait_damage_acc += damage

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
		if corpse_alpha <= 0.0 and not is_inspected:
			queue_free()
		return true
	return false
