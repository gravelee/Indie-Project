class_name Creature
extends CharacterBody2D

const SPRITE_SIZE 		:= 96
const SPRITE_PATH		:= "res://assets/spritesheets/creatures/"
const ANIMATION_SPEED 	:= 8

# ── AI distances ───────────────────────────────────────────────────────────────

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

const WANDER_CHANCE           := 1.0
const WANDER_INTERVAL_MIN     := 0.9
const WANDER_INTERVAL_MAX     := 1.1
const WANDER_DURATION_MIN     := 0.5
const WANDER_DURATION_MAX     := 3.0
const WANDER_BUMP_RADIUS_SQ   := 1024.0   # 32 px — props within one tile bump on direction change.


# ── Pathfinding settings ───────────────────────────────────────────────────────

const TILE_SIZE            := 32
const PATH_INTERVAL_MIN    := 0.4
const PATH_INTERVAL_MAX    := 0.6
const WAYPOINT_REACH_SQ    := (TILE_SIZE * 0.5) * (TILE_SIZE * 0.5)

# ── Stuck / Collision detection ────────────────────────────────────────────────

const STUCK_SAMPLE_INTERVAL   	:= 0.2    # seconds between position samples.
const STUCK_MIN_DIST_SQ       	:= 64.0   # 8 px²; moved less than this = stuck.
const WAIT_INTERVAL_INCREASE	:= 0.5
const WAIT_MAX_COUNTER			:= 10
const WAIT_INTERVAL_START		:= 0.5
const COLLISION_INTERVAL_MIN    := 0.15
const COLLISION_INTERVAL_MAX    := 0.25


# ── Other ──────────────────────────────────────────────────────────────────────

enum Type {
	RAT, SNAKE
}

enum State {
	IDLE_NEUTRAL, WANDER, NOTICE, ENTER_STANCE, IDLE_ATTACK,
	CHASE, EXIT_STANCE, RETURNING, ATTACK, DEATH, DEAD
}

const TILE_TYPE_MAP := {
	2: "rat", 
	3: "snake"
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

signal died

var state        : State = State.IDLE_NEUTRAL
var facing_right : bool  = false
var in_combat    : bool  = false
var anim_done    : bool  = false
var alive        : bool  = true
var is_inspected : bool  = false   # set stat_panel. Prevents queue_free while panel is open.
var sprite_alpha : float = 255.0
var moving       : bool  = false


# ── Wander ─────────────────────────────────────────────────────────────────────

var wander_timer    : float = 0.0
var wander_interval : float
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
var give_up			: bool    = false
var home_max_dist   : bool    = false
var out_of_energy   : bool    = false


# ── Pathfinding ────────────────────────────────────────────────────────────────

var pathfinder    		: Pathfinder    	# set init().
var path          		: Array   	= []  	# set _move_smart().
var path_timer    		: float   	= PATH_INTERVAL_MAX # set _move_smart().
var path_interval 		: float   	= 0.0 	# set _ready().
var interval_expansion	: float 	= 0.0 # set _move_smart()
var waypoint_blocked	: bool 		= false


# ── Stuck / Collision system ───────────────────────────────────────────────────

var _stuck_timer       		: float   = 0.0
var _stuck_pos         		: Vector2 = Vector2.ZERO
var _wait                	: bool    = false
var _wait_counter			: int	  = 0
var _wait_timer				: float   = 0.0
var _wait_interval			: float   = WAIT_INTERVAL_START
var _wait_damage_acc     	: float   = 0.0            # damage taken across wait cycles.
var _wait_damage_threshold	: float		# damage units that count as one extra effective wait cycle.
var _wait_entry_state		: State
var _collision_timer		: float	  = 0.0
var _collision_interval 	: float
var _teleport				: bool	  = false
var _teleported				: bool    = false


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
func init(stats: Dictionary, player: CharacterBody2D, camera_angle: float, pathfinder: Pathfinder) -> void:
	
	wander_timer    	= randf_range(0.0, 1.0)
	wander_interval 	= randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	path_interval   	= randf_range(PATH_INTERVAL_MIN,   PATH_INTERVAL_MAX)
	_collision_interval = randf_range(COLLISION_INTERVAL_MIN,   COLLISION_INTERVAL_MAX)
	
	# Position is set by map.gd before init() is called (CSV scan order).
	type = MAP_STRING_TYPE[stats["type"]]
	
	self.stats = Stats.new(stats["str"], stats["agi"], stats["sta"], stats["int"], 
		stats["spr"], stats["res"], stats["def"], stats["bms"], stats["exp"])
		
	if stats["home"]:
		home_position = position
		has_home      = true
		
	is_returning = stats["returning"]
	fleeing      = stats["fleeing"]
	
	self.stats.effects     	= StatusEffect.EffectManager.new()
	_wait_damage_threshold 	= maxf(1.0, self.stats.hp_max * 3.0 / 100.0)
	
	
	sprite_path = SPRITE_PATH + MAP_TYPE[type] + "/"
	
	for attack_name in STATE_ANIM[State.ATTACK]:
		if attack_name.split("_")[0] == MAP_TYPE[type]:
			abilities.append(Ability.get_ability(attack_name, self.stats.level))
	
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
	
	# Sync creature facing direction.
	sprite.flip_h = facing_right

	# CHASE and RETURNING animate based on actual movement 
	# so creatures blocked by obstacles show idle animation.
	var target_anim : String
	if state == State.CHASE:
		target_anim = STATE_ANIM[State.IDLE_ATTACK][0] if _wait else STATE_ANIM[State.CHASE][0]
	elif state == State.RETURNING:
		target_anim = STATE_ANIM[State.IDLE_NEUTRAL][0] if _wait else STATE_ANIM[State.RETURNING][0]
	else:
		return
	if sprite.animation != target_anim:
		sprite.play(target_anim)


# Called: sprite.animation_finished signal.
func _on_anim_finished() -> void:
	if state in ONE_SHOT_STATES:
		anim_done = true


# Called: _update_state(), _try_attack(), take_damage().
func _set_state(new_state: State) -> void:

	if state == new_state:
		return
	
	state     = new_state
	in_combat = state in COMBAT_STATES
	
	anim_done = false
	if state != State.DEAD and state != State.ATTACK:
		sprite.play(STATE_ANIM[state][0])


# =============================================================================
# STATE MACHINE - CREATURE STATUS
# =============================================================================

# Called: _physics_process().
func _update_state(dt: float) -> void:

	var dist_sq 	: float = position.distance_squared_to(player.position)

	match state:

		State.IDLE_NEUTRAL, State.WANDER:

			# Creature updates facing direction towards the player if:
			# 1) Player is alive AND
			# 2) Creature is within notice direction distance AND 
			# 3) Creature is in IDLE_NEUTRAL state.
			if player.alive and dist_sq < NOTICE_DIRECTION_SQ:
				if state == State.IDLE_NEUTRAL:
					_update_facing(player.position.x - position.x, player.position.y - position.y)
				# Creature also enters NOTICE state if:
				# 1) Creature is within notice distance.
				if dist_sq < NOTICE_DIST_SQ:
					_set_state(State.NOTICE)
					return
			# Creature can always start wandering while in WANDER state.
			# Creature can start wandering while in IDLE_NEUTRAL state only if:
			# 1) Player is dead (no other conditions) OR
			# 2) Player is alive but players distance is bigger than notice direction distance.
			if state == State.WANDER or not player.alive or (player.alive and dist_sq  > NOTICE_DIRECTION_SQ):
				var signal_ := _wander(dt)
				if signal_ == "start": _set_state(State.WANDER)
				elif signal_ == "done": _set_state(State.IDLE_NEUTRAL)

		# PROBABLY
		# 1) Player is alive AND
		# 2) Creature is within notice direction distance AND
		# 3) Creature is within notice distance.
		State.NOTICE:

			# Creature immediately enters ENTER_STANCE state if:
			# 1) Player is alive AND
			# 2) Creature is within attack range.
			if player.alive and dist_sq < ATTACK_DIST_SQ:
				_set_state(State.ENTER_STANCE)
			# Otherwise creature is waiting for NOTICE animation to complete.
			elif anim_done:
				# Creature enters ENTER_STANCE state if:
				# 1) Player is alive AND
				# 2) Player is within notice distance.
				if player.alive and dist_sq < NOTICE_DIST_SQ:
					_set_state(State.ENTER_STANCE)
				# 1) Player is dead OR
				# 2) Player is out of notice disance.
				# Then the creature enters IDLE_NEUTRAL state.
				else:
					_set_state(State.IDLE_NEUTRAL)

		# PROBABLY
		# 1) Player is alive AND creature is within attack range OR
		# 2) Player is alive AND creature is within notice range OR
		#    [3+4+5+6+7] OR
		# 3) Player is alive AND
		# 4) Creature has energy AND
		# 5) Creature does not give up ( 27.5 sec passed or 30% damage recieved while waiting) AND
		# 6) Creature has not reached max distance to home AND
		# 7) Creature is within notice distance.
		# 	[8+9+10+11+12+13].
		# 8) Creature has energy AND
		# 9) Creature does not give up ( 27.5 sec passed or 30% damage recieved while waiting) AND
		# 10) Creature is not returning AND
		# 11) Creature has not reached max distance to home AND
		# 12) Creature is within notice distance AND
		# 13) Creature is out of attack range.
		State.ENTER_STANCE:

			# Creatures sets temporary home if it has no home position.
			if not has_home:
				# Set home current creature position.
				home_position = position
				temp_home     = true
			# Creature is waiting for ENTER_STANCE animation to complete.
			if anim_done:
				# Creature updates its facing direction towards the player.
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				# Creature enters EXIT_STANCE state if:
				# 1) Player is dead.
				if not player.alive:
					_set_state(State.EXIT_STANCE)
				# 1) Player is alive.
				# Creature enters IDLE_ATTACK state if:
				# 1) Creature is within attack range.
				elif dist_sq < ATTACK_DIST_SQ:
					_set_state(State.IDLE_ATTACK)
				# 1) Player is alive AND
				# 2) Player is out of attack distance.
				# Creature enters CHASE state if:
				# 1) Player is within notice distance.
				elif dist_sq < NOTICE_DIST_SQ: 
					_set_state(State.CHASE)
				# 1) Player is alive AND
				# 2) Player is out of notice distance.
				# Then creature enters EXIT_STANCE state.
				else:                           
					_set_state(State.EXIT_STANCE)

		State.IDLE_ATTACK:

			# Creature calculates the distance to home position.
			var dist_home_sq := position.distance_squared_to(home_position)
			# Creature enters EXIT_STANCE state if:
			# 1) Player is dead OR
			# 2) Creature is out of energy OR
			# 3) Creature has reached max distance to home.
			# "3*" In IDLE_ATTACK state creature does not move itself but
			# 	   it may be moved by the player (knockback) or by the terrain.
			if not player.alive or out_of_energy or dist_home_sq > HOME_MAX_DIST_SQ:
				if dist_home_sq > HOME_MAX_DIST_SQ:
					home_max_dist = true
				_set_state(State.EXIT_STANCE)
			# 1) Player is alive AND
			# 2) Creature has energy AND
			# 3) Creature has not reached max distance to home AND
			# 4) Creature is out of attack range.
			# Creature enters CHASE state if:
			# 1) Player is within chase distance.
			elif dist_sq >= ATTACK_DIST_SQ:
				if dist_sq < CHASE_DIST_SQ:
					_set_state(State.CHASE)
				# 1) Player is alive AND
				# 2) Creature has energy AND
				# 3) Creature has not reached max distance to home AND
				# 4) Creature is out of chase range.
				# Then creature enters EXIT_STANCE state.
				else:
					_set_state(State.EXIT_STANCE)
			# 1) Player is alive AND
			# 2) Creature has energy AND
			# 3) Creature has not reached max distance to home AND
			# 4) Creature is within attack range.
			else:
				_update_facing(player.position.x - position.x, player.position.y - position.y)

		State.CHASE:
	
			# Creature calculates the distance to home position.
			var dist_home_sq := position.distance_squared_to(home_position)
			# Creature enters EXIT_STANCE state if:
			# 1) Player is dead OR
			# 2) Creature is out of energy OR
			# 3) Creature gives up ( 27.5 sec passed or 30% damage recieved while waiting) OR
			# 4) Creature has reached max distance to home OR
			# 5) Creature is out of chase distance.
			# "2*" In CHASE state creature does not use energy itself but
			# 	   it may be depleted by a players ability.
			if not player.alive or out_of_energy or give_up or dist_home_sq > HOME_MAX_DIST_SQ or dist_sq > CHASE_DIST_SQ:
				if dist_home_sq > HOME_MAX_DIST_SQ:
					home_max_dist = true
				_set_state(State.EXIT_STANCE)
			# 1) Player is alive AND
			# 2) Creature has energy AND
			# 3) Creature does not give up ( 27.5 sec passed or 30% damage recieved while waiting) AND
			# 4) Creature has not reached max distance to home AND
			# 5) Creature is within chase distance.
			# Creature updates facing direction towards the player AND enters IDLE_ATTACK state if:
			# 1) Creature is within attack range.
			elif dist_sq < ATTACK_DIST_SQ:
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				_set_state(State.IDLE_ATTACK)

		# PROBABLY
		# 1) Player is dead OR
		# 2) Player is alive AND creature is out of notice distance OR
		#	 [3+4+5] OR
		# 3) Player is dead OR
		# 4) Creature is out of energy OR
		# 5) Creature has reached max distance to home.
		#	 [6+7+8+9] OR
		# 6) Player is alive AND
		# 7) Creature has energy AND
		# 8) Creature has not reached max distance to home AND
		# 9) Creature is out of chase range.
		#	 [10+11+12+13+14] OR
		# 10) Player is dead OR
		# 11) Creature is out of energy OR
		# 12) Creature gives up ( 27.5 sec passed or 30% damage recieved while waiting) OR
		# 13) Creature has reached max distance to home OR
		# 14) Creature is out of chase distance.
		State.EXIT_STANCE:
			
			# Creature is waiting for EXIT_STANCE animation to complete.
			if anim_done:
				# Creature enters ENTER_STANCE state if:
				# 1) Player is alive AND
				# 2) Creature has energy AND
				# 3) Creature does not give up ( 27.5 sec passed or 30% damage recieved while waiting) AND
				# 4) Creature has not reached max distance to home AND
				# 5) Creature is within notice distance.
				if player.alive and not out_of_energy and not give_up and not home_max_dist and dist_sq < NOTICE_DIST_SQ: 
					_set_state(State.ENTER_STANCE)
				# 1) Player is dead OR
				# 2) Creature is out of energy OR
				# 3) Creature gives up ( 27.5 sec passed or 30% damage recieved while waiting) OR
				# 4) Creature has reached max distance to home OR
				# 5) Creature is out of notice distance.
				# Then creature enters RETURNING state.
				else:                         
					_set_state(State.RETURNING)

		State.RETURNING:

			# Creature calculates the distance to home position.
			var dist_home_sq := position.distance_squared_to(home_position)
			# Creature snaps to home and enters IDLE_NEUTRAL state if:
			# 1) Player is dead OR
			# 2) Creature is out of energy OR
			# 3) Creature gives up ( 27.5 sec passed or 30% damage recieved while waiting) OR
			# 4) Creature is returning OR
			# 5) Creature has reached max distance to home OR
			# 6) Creature is out of notice distance AND
			# 7) Creature has reached home.
			if not player.alive or out_of_energy or give_up or is_returning or home_max_dist or dist_sq > NOTICE_DIST_SQ:
				if dist_home_sq <= HOME_DIST_SQ:
					_snap_to_home()
					_set_state(State.IDLE_NEUTRAL)
			# 1) Player is alive AND
			# 2) Creature has energy AND
			# 3) Creature does not give up ( 27.5 sec passed or 30% damage recieved while waiting) AND
			# 4) Creature is not returning AND
			# 5) Creature has not reached max distance to home AND
			# 6) Creature is within notice distance.
			# Then creature updates facing direction towards the player.
			else:
				_update_facing(player.position.x - position.x, player.position.y - position.y)
				# Creature also enters IDLE_ATTACK state if:
				# 1) Creatures is within attack range.
				if dist_sq < ATTACK_DIST_SQ:
					_set_state(State.IDLE_ATTACK)
				# 1) Creature is out of attack range.
				# Then creature enters ENTER_STANCE state.
				else:
					_set_state(State.ENTER_STANCE)

		State.ATTACK:

			# Creature is waiting for ATTACK animation to complete.
			if anim_done:
				# Creature enters IDLE_ATTACK state if:
				# 1) Creature is in combat.
				if in_combat:
					_set_state(State.IDLE_ATTACK)
				# 1) Creature is out of combat.
				# Then creature enters IDLE_NEUTRAL state.
				else:
					_set_state(State.IDLE_NEUTRAL)

		State.DEATH:

			# Creature is waiting for DEATH animation to complete.
			if anim_done:
				# Then creature enters DEAD state.
				_set_state(State.DEAD)

		State.DEAD:

			# Creatures corpse fades out if:
			# 1) Creatures corpse is not inspected.
			if not is_inspected:
				if _change_alpha(dt):
					died.emit()
					queue_free()


# Called: _physics_process().
func _execute_state(dt: float) -> void:
	
	match state:
		
		State.IDLE_ATTACK:

			# 1) Player is alive AND
			# 2) Creature has energy AND
			# 3) Creature has not reached max distance to home AND
			# 4) Creature is within attack range.
			_try_attack()
				
		State.CHASE:
			
			# 1) Player is alive AND
			# 2) Creature has energy AND
			# 3) Creature does not give up ( 27.5 sec passed or 30% damage recieved while waiting) AND
			# 4) Creature has not reached max distance to home AND
			# 5) Creature is within chase distance AND
			# 6) Creature is out of attack range.
			# Then creature moves smart towards the player.
			_move_smart(player.position, stats.mspd, dt)
			
		State.RETURNING:
			
			# 1) Player is dead OR
			# 2) Creature is out of energy OR
			# 3) Creature gives up ( 27.5 sec passed or 30% damage recieved while waiting) OR
			# 4) Creature is returning OR
			# 5) Creature has reached max distance to home OR
			# 6) Creature is out of notice distance AND
			# 7) Creature has not reached home yet.
			# Then creature moves smart towards home.
			_move_smart(home_position, FLEE_SPEED, dt)


# Called: _physics_process().
func _update_status(dt: float) -> void:
	
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


# =============================================================================
# MOVEMENT
# =============================================================================

# LOOP
func _physics_process(dt: float) -> void:

	_update_state(dt)
	
	if alive:
		_execute_state(dt)
		_update_status(dt)
		_update_movement(dt)
		_sync_anim()
		_check_wait(dt)
		_check_teleport(dt)
		_check_collisions(dt)


# Called: _physics_process().
func _update_movement(dt: float) -> void:

	# If not in a moving state.
	if state not in MOVING_STATES:
		_stuck_timer    = 0.0
		velocity = Vector2.ZERO
		return

	# Wander has its own collision recovery (force_wander). Skip stuck detection.
	if not state == State.WANDER:
		
		# CHASE and RETURNING: sample position to detect stuck.
		_stuck_timer += dt
		if _stuck_timer >= STUCK_SAMPLE_INTERVAL:
			_stuck_timer    = 0.0
			# Check if position has minimum changed since last sample. If not..
			if position.distance_squared_to(_stuck_pos) < STUCK_MIN_DIST_SQ:
				# If not waiting already.
				if not _wait:
					# Position not changed. Stuck.
					_wait             = true
					_wait_entry_state = state
			# Minimum movement exists.
			else:
				# If waiting.
				if _wait:
					# Exit waiting.
					_wait            = false
					_wait_counter    = 0
					_wait_damage_acc = 0.0
					_wait_interval   = WAIT_INTERVAL_START
			# Update stuck position.
			_stuck_pos = position

	_update_moving()
	move_and_slide()


# Called: _update_movement().
func _update_moving() -> void:
	
	if velocity != Vector2.ZERO:
		moving = true
	else:
		moving = false


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
		_bump_nearby_props()

	wander_elapsed += dt
	velocity = Vector2(wander_dx, wander_dy) * stats.mspd

	if wander_elapsed >= wander_duration:
		return "done"
	return ""


# Called: _wander() on direction change.
func _bump_nearby_props() -> void:

	for prop in get_tree().get_nodes_in_group("react_props"):
		if (prop.position - position).length_squared() < WANDER_BUMP_RADIUS_SQ:
			prop.trigger_reaction()


# Called: _update_state().
func _move_smart(target_pos: Vector2, speed: float, dt: float) -> void:

	# If path_timer is up or a waypoint is blocked find new path.
	var path_check = false
	path_timer += dt
	if (path_timer >= path_interval + interval_expansion or waypoint_blocked):
		path_timer = 0.0
		path_check = true
		waypoint_blocked = false
		path = pathfinder.find_path(position, target_pos)

	# If deadlock (or too far away) increase path_timer interval and just _move_towards the target.
	if path.is_empty() and path_check:
		interval_expansion += 0.5
		_move_toward(target_pos, speed)
		return
	# No deadlock (or too far away), reset the path timer interval expansion.
	if interval_expansion > 0.0:
		interval_expansion = 0.0

	# If path exists.
	if not path.is_empty():
		# Pop waypoint if reached.
		if position.distance_squared_to(path[0]) < WAYPOINT_REACH_SQ:
			path.pop_front()
		# If path still not empty.
		if not path.is_empty():
			# Move towards the next waypoint.
			_move_toward(path[0], speed)
			return
	# If no path is found or last waypoint has been reached.
	_move_toward(target_pos, speed)


# Called: _move_smart().
func _move_toward(target_pos: Vector2, speed: float) -> void:

	var direction	:= target_pos - position
	var len_sq 		:= direction.length_squared()
	if len_sq < 1.0:
		velocity = Vector2.ZERO
		return
	_update_facing(direction.x, direction.y)
	velocity = direction / sqrt(len_sq) * speed


# Called: _update_state().
func _snap_to_home() -> void:

	velocity          = Vector2.ZERO
	out_of_energy     = false
	give_up			  = false
	home_max_dist     = false
	wander_timer      = 0.0
	wander_elapsed    = 0.0
	force_wander      = false
	path.clear()
	path_timer 		  = 0.0
	interval_expansion= 0.0
	if temp_home:
		home_position = Vector2.ZERO
		temp_home     = false


# =============================================================================
# STUCK HANDLE
# =============================================================================


# Called: _physics_process()
func _check_wait(dt: float) -> void:
	
	if not _wait:
		return
	
	_wait_timer += dt
	if _wait_timer >= _wait_interval:
		_wait_timer = 0.0
		_wait_counter += 1
		_wait_interval += WAIT_INTERVAL_INCREASE
		
		# If creature is stuck for more than 27.5 seconds or takes 30% total damage while in wait.
		var damage_effectiveness = int (_wait_damage_acc / _wait_damage_threshold)
		if damage_effectiveness >= WAIT_MAX_COUNTER or _wait_counter >= WAIT_MAX_COUNTER:
			give_up 		 = true
			_wait            = false
			_wait_counter    = 0
			_wait_damage_acc = 0.0
			_wait_interval   = WAIT_INTERVAL_START
			
			# If creature was in returning state while it got stuck.
			if _wait_entry_state == State.RETURNING:
				_teleport 	  = true
				# If home_position is not free set new home position the nearest free.
				var home_tile := Vector2i(int(home_position.x / TILE_SIZE), int(home_position.y / TILE_SIZE)) 
				if pathfinder._grid.is_point_solid(home_tile):
					var new_home_grid = pathfinder._nearest_walkable(home_tile)
					home_position = Vector2(new_home_grid.x * TILE_SIZE + TILE_SIZE / 2, 
						new_home_grid.y * TILE_SIZE + TILE_SIZE / 2)


# Called: _physics_process().
func _check_teleport(dt:float):

	if not _teleport:
		return

	if not _teleported:
		# If alpha = 0.0
		if _change_alpha(dt):
			# Teleport back to home.
			_teleported = true
			position    = home_position
			stats.cleanse_all_effects()
			path.clear()
	# Teleported.
	else:
		# If alpha = 255.0
		if _change_alpha(dt, true):
			_teleport = false
			_teleported = false


# Called: _physics_process().
func _check_collisions(dt: float) -> void:

	# If no collision return.
	if get_slide_collision_count() == 0:
		return

	# Wandering collisions immediately pick a new wander direction.
	if state == State.WANDER:
		force_wander = true
		return

	_collision_timer += dt
	# If the creature is in chasing or returning state, wating and collision timer is up and creature has a path.
	if (_collision_timer >= _collision_interval) and _wait and (state == State.CHASE or state == State.RETURNING) and not path.is_empty():
		_collision_timer = 0.0
		for i in get_slide_collision_count():
			var col     := get_slide_collision(i)
			var blocker := col.get_collider()
			# If player is alive and the blocker is another creature then 
			# temp-block "this" creatures next waypoint tile because it is unreachable.
			if player.alive and blocker is CharacterBody2D and blocker != player:
				pathfinder.add_temp_block(path[0])
				waypoint_blocked = true
				path.clear()
				break
			# If player is dead and the blocker is the player himself then
			# temp-block "this" creatures next waypoint tile because it is unreachable.
			elif not player.alive and blocker is CharacterBody2D and blocker == player:
				pathfinder.add_temp_block(path[0])
				waypoint_blocked = true
				path.clear()
				break


# Called: _update_state(), _check_teleport().
func _change_alpha(dt:float = 0.0, increase:bool = false) -> bool:
	
	if increase:
		sprite_alpha = minf(255.0, sprite_alpha + 300.0 * dt)
		sprite.modulate = Color(1.0, 1.0, 1.0, sprite_alpha / 255.0)
		return sprite_alpha >= 255.0
	else:
		sprite_alpha = maxf(0.0, sprite_alpha - 300.0 * dt)
		sprite.modulate = Color(1.0, 1.0, 1.0, sprite_alpha / 255.0)
		return sprite_alpha <= 0.0


# =============================================================================
# FACING
# =============================================================================

# Called: _update_state(), _move_towards(), _wander().
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
	
	_set_state(State.ATTACK)
	# Sometimes when the creature enters attack range its path keeps a couple of waypoints. 
	# We clear them.
	path.clear()	
	sprite.play(chosen.anim)
	chosen.use(stats, [player], dist)


# Called: _update_status(), ability.use() (_try_attack()).
func take_damage(raw_damage: float, dot: bool = false, is_magic: bool = false, is_crit: bool = false) -> float:

	var damage : float = stats.take_damage(raw_damage, dot, is_magic, is_crit)

	if _wait:
		_wait_damage_acc += damage

	if not stats.is_alive():
		alive = false
		_set_state(State.DEATH)

	return damage
