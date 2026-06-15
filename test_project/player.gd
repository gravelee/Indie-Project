extends CharacterBody3D


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Seconds regen is held off after the player starts any swing (even against props).
# Prevents the player from recovering energy mid-combo by spam-attacking walls.
const REGEN_PAUSE        : float = 3.0

# Energy drained per second while the player is sprinting.
# Accumulates in _run_energy_accum so tap-sprinting still costs a fair amount.
const SPRINT_ENERGY_COST : float = 1.0

# Speed multiplier applied on top of stats.mspd when the player is running.
const SPRINT_MULT        : float = 1.2

# Seconds the combat state persists after the last hit on a creature.
# Keeps the player in combat idle stance briefly after killing something.
const COMBAT_TIMEOUT     : float = 3.0

# Maps a cardinal direction string to its flat 2D input vector.
# Used by _attack_check() to reconstruct a world-space direction from last_dir.
const DIR_MAP : Dictionary = {
	"north": Vector2( 0.0, -1.0),
	"south": Vector2( 0.0,  1.0),
	"east":  Vector2( 1.0,  0.0),
	"west":  Vector2(-1.0,  0.0)
}


# ---------------------------------------------------------------------------
# Timers
# ---------------------------------------------------------------------------

# Gate: regen is blocked while this is above zero. Reset to REGEN_PAUSE on any swing.
var _regen_timer      : float = 0.0

# Gate: combat idle animations are active while this is above zero.
# Only reset to COMBAT_TIMEOUT when a creature is actually hit — not on prop hits.
var _combat_timer     : float = 0.0


# ---------------------------------------------------------------------------
# Sprint accumulator
# ---------------------------------------------------------------------------

# Accumulates real elapsed time (seconds) while running. Energy is drained
# in whole-second ticks so brief sprints cost proportional energy rather than
# a full second on the first frame touched.
var _run_energy_accum : float = 0.0


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

# Camera slot settings. The player reads cam.use_wasd / cam.use_arrows each frame
# to decide which keys are active for movement. Also the reference the settings UI
# will read and write when the escape menu camera settings panel is built.
var cam        : CameraSettings

# The camera rig node. Queried each frame for h_angle so movement stays camera-relative.
var camera_rig : Node3D

# Current horizontal camera rotation in radians. Updated every frame from camera_rig.
# Used to rotate the input vector so WASD always points in the camera's forward direction.
var h_angle    : float = 0.0


# ---------------------------------------------------------------------------
# Sprite
# ---------------------------------------------------------------------------

# The visual AnimatedSprite3D child. Handles all directional animation playback.
var player_sprite : AnimatedSprite3D

# Last resolved facing direction ("north", "south", "east", "west").
# Persists when the player stops moving so the idle animation faces the right way.
var last_dir      : String = "south"


# ---------------------------------------------------------------------------
# Stats & state
# ---------------------------------------------------------------------------

# All player stat values (HP, energy, patk, pdef, mspd, etc). Set in init().
var stats : Stats

# Current movement/action state. ATTACK is owned by _input/_attack_update
# and must never be overwritten by movement logic.
enum State { IDLE, WALK, RUN, ATTACK }
var state : State = State.IDLE


# ---------------------------------------------------------------------------
# Abilities & combat
# ---------------------------------------------------------------------------

# The punch ability instance. Tracks its own cooldown timer.
var punch : Ability

# The ability currently being executed in the ATTACK state.
# Set in _input() at swing start; read by _attack_update() for hit-frame timing.
var _active_ability : Ability

# Guard flag: true once damage has been applied this swing.
# Prevents the raycast from firing more than once per animation playback.
var _hit_applied : bool = false


# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------

# Main-hand weapon slot identifier ("sword", "pickaxe", etc). Empty = unarmed.
# Drives animation names — "attack_unarmed_*", "attack_sword_*", etc.
var weapon_main : String = ""

# Off-hand weapon slot identifier. Not used for animation routing currently;
# reserved for future shield-block and dagger dual-wield logic.
var weapon_off  : String = ""


# ===========================================================================
# SPRITE LOADING
# ===========================================================================

# Called: init().
func _load_sprite_frames() -> SpriteFrames:

	var frames : SpriteFrames = SpriteFrames.new()
	var base   : String       = "res://assets/player/ares/frames/"

	# Each entry: [animation_name, folder_path, frame_count].
	var anims  : Array = [
		["walking_north",        base + "north/walking/",        6],
		["walking_south",        base + "south/walking/",        6],
		["walking_east",         base + "east/walking/",         6],
		["walking_west",         base + "west/walking/",         6],
		["running_north",        base + "north/running/",        6],
		["running_south",        base + "south/running/",        6],
		["running_east",         base + "east/running/",         6],
		["running_west",         base + "west/running/",         6],
		["idle_neutral_north",   base + "north/idle_neutral/",   10],
		["idle_neutral_south",   base + "south/idle_neutral/",   10],
		["idle_neutral_east",    base + "east/idle_neutral/",    10],
		["idle_neutral_west",    base + "west/idle_neutral/",    10],
		["idle_attack_unarmed_north", base + "north/idle_attack/unarmed/", 6],
		["idle_attack_unarmed_south", base + "south/idle_attack/unarmed/", 6],
		["idle_attack_unarmed_east",  base + "east/idle_attack/unarmed/",  6],
		["idle_attack_unarmed_west",  base + "west/idle_attack/unarmed/",  6],
		["attack_unarmed_north", base + "north/attack/unarmed/", 5],
		["attack_unarmed_south", base + "south/attack/unarmed/", 5],
		["attack_unarmed_east",  base + "east/attack/unarmed/",  5],
		["attack_unarmed_west",  base + "west/attack/unarmed/",  5]]

	for anim : Array in anims:
		var anim_name   : String = anim[0]
		var path        : String = anim[1]
		var frame_count : int    = anim[2]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		for i : int in range(frame_count):
			var tex : Texture2D = load(path + str(i) + ".png")
			frames.add_frame(anim_name, tex)

	# Attack animations must not loop — the ATTACK state exits when playback ends.
	frames.set_animation_loop("attack_unarmed_north", false)
	frames.set_animation_loop("attack_unarmed_south", false)
	frames.set_animation_loop("attack_unarmed_east",  false)
	frames.set_animation_loop("attack_unarmed_west",  false)

	return frames


# ===========================================================================
# HELPERS
# ===========================================================================

# Called: _input(), _anim_apply().
# Returns the weapon style string used to build animation names.
# Falls back to "unarmed" when no main-hand weapon is equipped.
# Off-hand alone is not a valid equipment state, so only weapon_main is checked.
func _weapon_style() -> String:

	return weapon_main if weapon_main != "" else "unarmed"


# Called: _anim_apply().
# Converts a 2D input vector into a cardinal direction string.
# Prefers the axis with the larger magnitude; diagonal inputs snap to the dominant axis.
# Returns last_dir unchanged when the player is not moving, so idle keeps its facing.
func _get_dir(input: Vector2) -> String:

	if input.length() < 0.1:
		return last_dir
	if abs(input.y) >= abs(input.x):
		return "north" if input.y < 0.0 else "south"
	else:
		return "east" if input.x > 0.0 else "west"


# Called: _anim_apply().
# Returns true while the player is in the combat window after hitting a creature.
func _is_in_combat() -> bool:

	return _combat_timer > 0.0


# ===========================================================================
# ANIMATION
# ===========================================================================

# Called: _process().
# Resolves the correct animation name from current state and input, then plays it
# only if it differs from what's already playing (avoids restarting the same clip).
func _anim_apply(input: Vector2) -> void:

	last_dir = _get_dir(input)
	var anim_name : String

	if input.length() >= 0.1:
		# Running and walking share the same direction logic — only the prefix differs.
		anim_name = "running_" + last_dir if state == State.RUN else "walking_" + last_dir
	else:
		# Standing still — show combat-ready idle if in combat, normal idle otherwise.
		if _is_in_combat():
			anim_name = "idle_attack_" + _weapon_style() + "_" + last_dir
		else:
			anim_name = "idle_neutral_" + last_dir

	# Only switch animation when the name actually changes.
	# Calling play() on the active animation would restart it from frame 0.
	if player_sprite.animation != anim_name:
		player_sprite.play(anim_name)


# ===========================================================================
# COMBAT
# ===========================================================================

# Called: _attack_update().
# Fires a short raycast in the player's facing direction. Applies damage if a
# creature or dummy is hit. Sets _combat_timer only when a creature is hit —
# hitting props or walls must not put the player in combat.
func _attack_check() -> void:

	# Map facing direction back to an input vector, then apply the same
	# camera-relative transform used by movement — one formula, never drifts.
	var inp     : Vector2 = DIR_MAP[last_dir]
	# Rotate the 2D input vector by h_angle to get a camera-relative 3D direction.
	var dir_vec : Vector3 = Vector3(
		inp.x * cos(h_angle) + inp.y * sin(h_angle), 0.0,
		inp.x * -sin(h_angle) + inp.y * cos(h_angle))

	var space  : PhysicsDirectSpaceState3D   = get_world_3d().direct_space_state
	# Cast from chest height so the ray clears the ground collision shape.
	var origin : Vector3                     = global_position + Vector3(0.0, 1.0, 0.0)
	var target : Vector3                     = origin + dir_vec * _active_ability.range_
	var params : PhysicsRayQueryParameters3D
	params = PhysicsRayQueryParameters3D.create(origin, target)
	# Exclude the player's own collision shape from the cast.
	params.exclude = [get_rid()]
	var result : Dictionary                  = space.intersect_ray(params)

	if result.is_empty():
		return

	var hit_body : Node  = result["collider"]
	var damage   : float = _active_ability.calc_damage(stats)

	# Creatures own their combat response via receive_hit() — direction is passed
	# so the creature can apply knockback once that system is wired up.
	if hit_body.has_method("receive_hit"):
		hit_body.call("receive_hit", damage, dir_vec)
		# Only enter combat on a creature hit — prop hits must not trigger combat state.
		_combat_timer = COMBAT_TIMEOUT
		return

	# Fallback for test dummies that have stats but no receive_hit method.
	if hit_body.has_meta("stats"):
		var target_stats : Stats = hit_body.get_meta("stats")
		var actual       : float = target_stats.take_damage(damage)
		print("dummy hit for ", actual, " — hp: ", target_stats.hp, "/", target_stats.hp_max)


# Called: _process() while state == ATTACK.
# Polls the animation frame each tick to apply damage exactly at hit_frame,
# then waits for playback to end before releasing the ATTACK state.
func _attack_update() -> void:

	# Animation finished — swing is over, return to normal state.
	if not player_sprite.is_playing():
		state = State.IDLE
		return

	# Apply damage once when the animation reaches the designated hit frame.
	# _hit_applied guards against the raycast firing multiple times if the
	# game runs at a frame rate where the same animation frame is visited twice.
	var frame : int = player_sprite.get_frame()
	if frame >= _active_ability.hit_frame and not _hit_applied:
		_hit_applied = true
		_attack_check()


# ===========================================================================
# INIT
# ===========================================================================

# Called: main._build_player().
# Receives external references from main.gd and finishes building the player.
# Sprite frames are built here (expensive) so they only load once.
func init(p_camera_rig: Node3D, p_player_sprite: AnimatedSprite3D) -> void:

	camera_rig = p_camera_rig
	cam = camera_rig.get("cam")

	player_sprite = p_player_sprite
	player_sprite.sprite_frames = _load_sprite_frames()

	# Lift the sprite so its base sits on the ground.
	# Sprite origin is at its center, so shift up by half the world-unit height.
	player_sprite.position.y = 32.0 * player_sprite.pixel_size * 0.5

	# STR=1 AGI=1 STA=1 DEF=1 BMS=3 — minimal stats for combat testing.
	stats = Stats.new(1, 1, 1, 1, 3)
	punch = Abilities.get_ability("punch")


# ===========================================================================
# INPUT
# ===========================================================================

# Called: Godot engine (InputEvent).
# Handles ability activation on key press. Movement is handled in _process()
# via the continuous Input.get_vector() poll — not here.
func _input(event: InputEvent) -> void:

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			# KEY_1 triggers the punch ability (placeholder — more abilities will expand this).
			if state != State.ATTACK and punch.can_use(stats):
				# Block regen for the full REGEN_PAUSE window from this swing.
				_regen_timer    = REGEN_PAUSE
				# Reset hit guard at swing start so the hit fires exactly once this swing when the
				# hit_frame arives, if arives and the attack didnt stop from a status effect like stun.
				_hit_applied    = false
				_active_ability = punch
				state           = State.ATTACK
				_active_ability.spend(stats)
				player_sprite.play("attack_" + _weapon_style() + "_" + last_dir)


# ===========================================================================
# PROCESS
# ===========================================================================

# Called: Godot engine (every frame).
func _process(delta: float) -> void:

	# Sync h_angle from the rig each frame so movement always matches the current camera orbit.
	h_angle = camera_rig.get("h_angle")

	var input      : Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_moving  : bool    = input.length() >= 0.1
	var is_shift   : bool    = Input.is_key_pressed(KEY_SHIFT)
	var can_sprint : bool    = stats.energy >= 1.0

	# Update movement state.
	# ATTACK state is set and cleared by _input()/_attack_update() — never touch it here.
	if state != State.ATTACK:
		if is_moving and is_shift and can_sprint:
			state = State.RUN
		elif is_moving:
			state = State.WALK
		else:
			state = State.IDLE

	# Rotate the 2D input vector by h_angle into a flat 3D world direction.
	# This keeps WASD camera-relative regardless of which way the camera is orbiting.
	var direction : Vector3 = Vector3(
		input.x * cos(h_angle) + input.y * sin(h_angle), 0.0,
		input.x * -sin(h_angle) + input.y * cos(h_angle))

	# RUN moves faster than WALK by SPRINT_MULT.
	var speed : float = stats.mspd * (SPRINT_MULT if state == State.RUN else 1.0)
	velocity = direction * speed
	move_and_slide()

	# Sprint energy drain — accumulate real time so tap-sprinting still costs energy
	# proportional to how long the key was held, not a flat cost per frame.
	if state == State.RUN:
		_run_energy_accum += delta
		if _run_energy_accum >= 1.0:
			# Drain a whole number of seconds at once to stay frame-rate independent.
			var ticks         : int   = int(_run_energy_accum)
			stats.energy      = maxf(0.0, stats.energy - SPRINT_ENERGY_COST * ticks)
			_run_energy_accum -= float(ticks)

	match state:
		State.IDLE, State.WALK, State.RUN:
			_anim_apply(input)
		State.ATTACK:
			_attack_update()

	# --- Timers and regen ---

	# Advance all stat internal timers (GCD, etc).
	stats.tick(delta)

	# Count down both gates. Must tick before the regen check below so the gate
	# reaches zero and regen fires on the same frame it expires.
	_regen_timer  = maxf(0.0, _regen_timer  - delta)
	_combat_timer = maxf(0.0, _combat_timer - delta)

	# Tick the active ability cooldown so it becomes ready again after each use.
	punch.tick(delta)

	# Regen is blocked while _regen_timer is above zero (recent swing) or while sprinting
	# (energy is draining — regenerating at the same time would cancel the cost).
	if _regen_timer <= 0.0 and state != State.RUN:
		stats.regen(delta)
