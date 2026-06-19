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

# Downward acceleration in world units/s² applied each frame when airborne.
# Negative because Y is up — gravity pulls down.
const GRAVITY            : float = -20.0

# Upward velocity in world units/s applied once when the jump launches at JUMP_LAUNCH_FRAME.
# At GRAVITY=-20, this gives ~1.5 tiles of peak height and ~0.775s air time.
const JUMP_VEL           : float = 7.75

# Animation frame index at which jump velocity is applied (player leaves the ground).
# Frame 0 = prep (windup on ground), frame 1 = ascent begins (launch here).
const JUMP_LAUNCH_FRAME  : int   = 1

# Seconds the sprite stays over-bright white after taking a hit before tweening back to normal.
const HIT_FLASH_DURATION : float = 0.1

# Duration of one animation frame in seconds at 8 fps.
# Used by _jump_update() to pace frame 0 (WINDUP) and frames 3-4 (LAND) at the
# correct rate without calling play() — jump frames are driven by physics phase.
const ANIM_FRAME_DUR     : float = 1.0 / 8.0

# Seconds after a full landing (both LAND frames done) before the player can jump again.
# Starts on LAND exit — applies to both voluntary jumps and cliff falls.
const JUMP_COOLDOWN      : float = 0.3

# Seconds between passive focus ticks while in combat. Each tick grants +1 focus.
const FOCUS_COMBAT_INTERVAL : float = 5.0

# Initial speed in world units/s applied to the player when a creature lands a hit.
# Decays to zero each frame via KNOCKBACK_FRICTION — not a duration, a rate.
const KNOCKBACK_STRENGTH : float = 8.0

# World units/s deceleration applied to _knockback_vel each frame via move_toward().
# At 20.0 the player stops in ~0.4s. Higher = snappier, lower = longer slide.
const KNOCKBACK_FRICTION : float = 20.0

# Zoom distance at which the player sprite begins to fade (fully visible at or above this).
const FADE_ZOOM_MAX : float = 5.0

# Zoom distance at which the player sprite is fully transparent (at or below this).
const FADE_ZOOM_MIN : float = 2.0

# Y offset from the player's feet used as the raycast origin for attacks.
# Chest height — keeps the ray clear of the ground collision shape.
const ATTACK_ORIGIN_HEIGHT        : float = 1.0

# Maximum Y difference between player and target for an attack to connect.
# Prevents hitting creatures on ledges directly above or below the player.
const ATTACK_MAX_HEIGHT           : float = 1.5

# Knockback speed below which the deferred death trigger considers the player settled.
# Prevents the death animation from firing mid-slide after a lethal hit.
const KNOCKBACK_SETTLED_THRESHOLD : float = 0.1

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

# Current knockback velocity in world units/s. Set by receive_hit(), decays to
# Vector3.ZERO each frame via move_toward(). Added on top of movement velocity.
var _knockback_vel    : Vector3 = Vector3.ZERO


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

# Current movement/action state.
# IDLE/WALK/RUN: movement states, driven by input each frame.
# ATTACK: owned by _input and _attack_update — movement logic must not overwrite.
# JUMP: owned by _input and _jump_update — covers voluntary jumps, ledge falls, throw-backs.
# SPAWN: invincible, full animation plays, no input accepted.
# DEAD: invincible, full animation plays to last frame then holds, terminal.
enum State { IDLE, WALK, RUN, ATTACK, JUMP, SPAWN, DEAD }
var state : State = State.IDLE

# Tracks which physics sub-phase the player is in during a jump.
# WINDUP: on ground, prep frame playing. RISE: airborne, going up.
# FALL: airborne, going down. LAND: touched ground, absorption frame playing.
enum JumpPhase { WINDUP, RISE, FALL, LAND }
var _jump_phase    : JumpPhase = JumpPhase.WINDUP

# True once JUMP_VEL has been applied this jump. Guards against re-applying on
# repeated frames and tells the gravity block not to snap velocity.y to 0.
var _jump_launched    : bool  = false

# Counts down in WINDUP (holds prep frame) and LAND (paces contact → absorption frames).
# Not used during RISE or FALL — those phases are driven purely by velocity.y and is_on_floor().
var _jump_frame_timer   : float = 0.0

# Counts down after the LAND animation completes. Jump is blocked while above zero.
# Starts on LAND exit for both voluntary jumps and cliff falls.
var _jump_cooldown_timer  : float = 0.0

# Counts down each 5s while in combat. On expiry grants +1 focus and resets.
# Resets to 0 when leaving combat so the tick only fires during active fights.
var _focus_combat_timer   : float = 0.0

# Horizontal velocity (world X, world Z) captured the moment the player goes airborne.
# Held constant during RISE and FALL so there is no mid-air steering — the player commits
# to a direction at launch. Set on voluntary jumps, ledge falls, and creature throw-backs.
var _jump_locked_vel  : Vector2 = Vector2.ZERO

# True once HP reaches zero. Read by creatures to stop chasing a dead player.
var is_dead : bool = false


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
		["attack_unarmed_west",  base + "west/attack/unarmed/",  5],
		# 5-frame jump animation: frame 0=prep, 1=ascend, 2=descend, 3=contact, 4=absorption.
		["jump_north",           base + "north/jump/",           5],
		["jump_south",           base + "south/jump/",           5],
		["jump_east",            base + "east/jump/",            5],
		["jump_west",            base + "west/jump/",            5],
		# Non-directional animations — no direction suffix, same clip for all facing directions.
		["spawn",                base + "spawn/",                29],
		["death",                base + "death/",                29]]

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

	# Jump animations must not loop — _jump_update() waits for is_playing()=false in LAND phase.
	frames.set_animation_loop("jump_north", false)
	frames.set_animation_loop("jump_south", false)
	frames.set_animation_loop("jump_east",  false)
	frames.set_animation_loop("jump_west",  false)

	# Lifecycle animations play once and hold the last frame.
	frames.set_animation_loop("spawn", false)
	frames.set_animation_loop("death", false)

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

# Called: _physics_process().
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


# Called: _physics_process().
# Fades the player sprite out as the camera zooms in close so the player never
# fully blocks the view. SPAWN and DEAD are exempt — always fully visible.
# Uses zoom_effective (the actual clipped distance) so wall-clip pullback
# does not cause the sprite to fade when the camera is forced closer by geometry.
func _fade_update() -> void:

	if state == State.SPAWN or state == State.DEAD:
		player_sprite.modulate.a = 1.0
		return
	player_sprite.modulate.a = clampf(
		inverse_lerp(FADE_ZOOM_MIN, FADE_ZOOM_MAX, camera_rig.get("zoom_effective")),
		0.0, 1.0)


# ===========================================================================
# COMBAT
# ===========================================================================

# Called: _attack_update().
# Iterates all nodes in the "creatures" group and applies damage to every valid target.
# Each creature gets its own independent damage roll — own crit chance, own focus gain.
# Sets _combat_timer on the first hit. No arc cone yet — front hemisphere only (dot > 0).
# Tune to a tight arc cone (ATTACK_ARC_DOT) after combat feel is confirmed in testing.
# NOTE: test dummy no longer supported here — add it to the "creatures" group or give it
# a receive_hit() method at Stage 8 when real creatures land.
func _attack_check() -> void:

	# Reconstruct the world-space facing direction from last_dir + current camera angle.
	# Same formula as movement so attack direction never drifts from the visual facing.
	var inp     : Vector2 = DIR_MAP[last_dir]
	var dir_vec : Vector3 = Vector3(
		inp.x * cos(h_angle) + inp.y * sin(h_angle), 0.0,
		inp.x * -sin(h_angle) + inp.y * cos(h_angle))

	var range_sq : float = _active_ability.range_ * _active_ability.range_

	for node : Node in get_tree().get_nodes_in_group("creatures"):
		var diff : Vector3 = node.global_position - global_position
		# Height gate — rejects targets on ledges too far above or below.
		if absf(diff.y) > ATTACK_MAX_HEIGHT:
			continue
		# XZ distance gate — flat plane only, height already handled above.
		var flat : Vector3 = Vector3(diff.x, 0.0, diff.z)
		if flat.length_squared() > range_sq:
			continue
		# Facing gate — target must be in the front hemisphere (dot > 0 = within 90°).
		# No tight arc cone yet — any target in front within range is valid.
		if flat.length_squared() > 0.001 and flat.normalized().dot(dir_vec) <= 0.0:
			continue
		# Each creature gets its own damage roll — crit is independent per target.
		var damage : float = _active_ability.calc_damage(stats)
		var kb_dir : Vector3 = flat.normalized() if flat.length_squared() > 0.001 else dir_vec
		node.call("receive_hit", damage, kb_dir)
		_combat_timer = COMBAT_TIMEOUT


# Called: _physics_process() while state == ATTACK.
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


# Called: receive_hit().
# Snaps the sprite to a red tint, then tweens it back to normal over HIT_FLASH_DURATION seconds.
# Red tint instead of overbright white because GL Compatibility clamps modulate to [0,1] —
# Color(2,2,2) looks identical to Color(1,1,1) in that renderer so the flash is invisible.
# Alpha is preserved from the current modulate so it does not fight _fade_update().
# Works on any hit — stacks correctly because create_tween() creates a fresh tween each time.
func _flash_sprite() -> void:

	var a : float = player_sprite.modulate.a
	player_sprite.modulate = Color(1.0, 0.15, 0.15, a)
	var tween : Tween = create_tween()
	tween.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, a), HIT_FLASH_DURATION)


# Called: creature._attack_check() when a creature's raycast hits the player.
# damage : raw damage value from the creature's ability.calc_damage().
# _dir   : flat direction from creature to player — unused now, reserved for knockback.
# Getting hit resets both gates: regen pauses and combat window refreshes.
func receive_hit(damage: float, dir: Vector3) -> void:

	if is_dead or state == State.SPAWN:
		return
	var actual : float = stats.take_damage(damage)
	_regen_timer   = REGEN_PAUSE
	_combat_timer  = COMBAT_TIMEOUT
	# Push the player away from the attacker. dir points from creature to player
	# so it's already the correct knockback direction.
	_knockback_vel = dir.normalized() * KNOCKBACK_STRENGTH
	stats.gain_focus_on_receive()
	_flash_sprite()
	print("player hit for ", actual, " — hp: ", stats.hp, "/", stats.hp_max)
	if not stats.is_alive():
		is_dead = true
		print("player died")


# Called: creature._physics_process() every frame while in a hostile state.
# Keeps the combat window open while a creature is actively chasing or attacking —
# without this the combat idle animation would drop 3s after the last hit even if
# a rat is running straight at the player.
func _extend_combat_timer() -> void:

	if not is_dead:
		_combat_timer = COMBAT_TIMEOUT


# ===========================================================================
# JUMP
# ===========================================================================

# Called: _physics_process() while state == JUMP.
# Drives all four jump phases. Frames are set manually — play() is never called
# during a jump because play() advances at fixed 8fps regardless of air time.
# Instead each frame is held for exactly as long as the matching physics state lasts:
#   frame 0 (WINDUP) — held for ANIM_FRAME_DUR, then commit direction and launch
#   frame 1 (RISE)   — locked velocity, held while velocity.y > 0 (full ascent)
#   frame 2 (FALL)   — locked velocity, held while airborne and descending
#   frame 3 (LAND)   — first contact, held for ANIM_FRAME_DUR
#   frame 4 (LAND)   — absorption, held for ANIM_FRAME_DUR then idle
# _jump_locked_vel is set the moment the player goes airborne (voluntary jump, ledge fall,
# or creature throw-back) so horizontal momentum is always deterministic, never steerable.
func _jump_update(delta: float) -> void:

	match _jump_phase:

		JumpPhase.WINDUP:
			# Hold prep frame for one animation frame duration, then apply launch velocity.
			_jump_frame_timer -= delta
			if _jump_frame_timer <= 0.0 and not _jump_launched:
				# Capture the horizontal velocity at the exact moment of launch.
				# This locks direction for the entire air time — no steering in RISE or FALL.
				_jump_locked_vel    = Vector2(velocity.x, velocity.z)
				velocity.y          = JUMP_VEL
				_jump_launched      = true
				_jump_phase         = JumpPhase.RISE
				player_sprite.frame = 1

		JumpPhase.RISE:
			# Hold ascent frame until apex — velocity.y turns zero then negative.
			if velocity.y <= 0.0:
				_jump_phase         = JumpPhase.FALL
				player_sprite.frame = 2

		JumpPhase.FALL:
			# Hold descent frame until grounded. Start the landing timer on contact.
			if is_on_floor():
				velocity.y          = 0.0
				_jump_phase         = JumpPhase.LAND
				player_sprite.frame = 3
				# Reserve time for frame 3 (contact) + frame 4 (absorption).
				_jump_frame_timer   = ANIM_FRAME_DUR * 2.0

		JumpPhase.LAND:
			# Count down through the two landing frames then hand control back.
			_jump_frame_timer -= delta
			if _jump_frame_timer > ANIM_FRAME_DUR:
				player_sprite.frame = 3
			elif _jump_frame_timer > 0.0:
				player_sprite.frame = 4
			else:
				_jump_phase          = JumpPhase.WINDUP
				_jump_launched       = false
				_jump_cooldown_timer = JUMP_COOLDOWN
				# If the player died mid-air, trigger death now that they have landed.
				if is_dead:
					state = State.DEAD
					player_sprite.play("death")
				else:
					state = State.IDLE
					var idle : String = "idle_attack_" + _weapon_style() + "_" + last_dir \
						if _is_in_combat() else "idle_neutral_" + last_dir
					player_sprite.play(idle)


# ===========================================================================
# LIFECYCLE
# ===========================================================================

# Called: _physics_process() while state == SPAWN.
# Waits for the spawn animation to finish then transitions to IDLE.
# The player is invincible during SPAWN — receive_hit() returns early.
func _spawn_update() -> void:

	if not player_sprite.is_playing():
		state = State.IDLE
		player_sprite.play("idle_neutral_" + last_dir)


# Called: _physics_process() while state == DEAD.
# Terminal state — no transitions out. The death animation was started in
# _physics_process() when is_dead was detected. AnimatedSprite3D holds the
# last frame automatically once a non-looping animation finishes.
func _dead_update() -> void:

	pass


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
	# Read the actual texture height from the loaded frames — using a hardcoded value
	# would be wrong whenever the sprite size changes.
	var frame_h : int            = player_sprite.sprite_frames \
		.get_frame_texture("idle_neutral_south", 0).get_height()
	player_sprite.position.y = float(frame_h) * player_sprite.pixel_size * 0.5

	# STR=1 AGI=1 STA=1 DEF=1 BMS=3 — minimal stats for combat testing.
	stats = Stats.new(1, 1, 1, 1, 3)
	punch = Abilities.get_ability("punch")

	# Begin in SPAWN — player is invincible until the animation completes.
	state = State.SPAWN
	player_sprite.play("spawn")


# ===========================================================================
# INPUT
# ===========================================================================

# Called: Godot engine (InputEvent).
# Handles ability activation on key press. Movement is handled in _physics_process()
# via the continuous Input.get_vector() poll — not here.
func _input(event: InputEvent) -> void:

	if is_dead or state == State.SPAWN:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# DEBUG ONLY — remove before release.
		if event.keycode == KEY_K:
			receive_hit(10.0, -global_transform.basis.z)
			return
		if event.keycode == KEY_1:
			# KEY_1 triggers the punch ability (placeholder — more abilities will expand this).
			# JUMP and ATTACK block each other — no attacking mid-air, no jumping mid-swing.
			if state != State.ATTACK and state != State.JUMP and punch.can_use(stats):
				# Block regen for the full REGEN_PAUSE window from this swing.
				_regen_timer    = REGEN_PAUSE
				# Reset hit guard at swing start so the hit fires exactly once this swing when the
				# hit_frame arives, if arives and the attack didnt stop from a status effect like stun.
				_hit_applied    = false
				_active_ability = punch
				state           = State.ATTACK
				_active_ability.spend(stats)
				player_sprite.play("attack_" + _weapon_style() + "_" + last_dir)

		elif event.keycode == KEY_SPACE:
			# Space starts a jump. Must be grounded, not mid-attack or mid-jump, have energy,
			# and the post-landing cooldown must have expired.
			if state != State.ATTACK and state != State.JUMP and is_on_floor() \
					and stats.energy >= 1.0 and _jump_cooldown_timer <= 0.0:
				stats.spend_resources(0, 1, 0)
				# Lock direction immediately at press time — velocity here is from the last
				# move_and_slide() so it reflects actual momentum, not raw input.
				# This also prevents steering during the WINDUP frame.
				_jump_locked_vel  = Vector2(velocity.x, velocity.z)
				state             = State.JUMP
				_jump_phase       = JumpPhase.WINDUP
				_jump_launched    = false
				_jump_frame_timer = ANIM_FRAME_DUR
				# Set animation and hold frame 0 — do NOT call play().
				# _jump_update() drives each frame manually from physics phase so each
				# frame holds as long as the physics state lasts, not just 0.125s each.
				player_sprite.animation = "jump_" + last_dir
				player_sprite.frame     = 0
				player_sprite.pause()


# ===========================================================================
# PROCESS
# ===========================================================================

# Called: Godot engine (every frame).
func _physics_process(delta: float) -> void:

	# Sync h_angle from the rig each frame so movement always matches the current camera orbit.
	h_angle = camera_rig.get("h_angle")

	# Build the input vector manually so cam.use_wasd and cam.use_arrows are respected.
	var input : Vector2 = Vector2.ZERO
	if (cam.use_wasd   and Input.is_key_pressed(KEY_A)) or \
		(cam.use_arrows and Input.is_key_pressed(KEY_LEFT)):  input.x -= 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_D)) or \
		(cam.use_arrows and Input.is_key_pressed(KEY_RIGHT)): input.x += 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_W)) or \
		(cam.use_arrows and Input.is_key_pressed(KEY_UP)):    input.y -= 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_S)) or \
		(cam.use_arrows and Input.is_key_pressed(KEY_DOWN)):  input.y += 1.0
	input = input.normalized() if input.length() > 1.0 else input

	var is_moving  : bool    = input.length() >= 0.1
	var is_shift   : bool    = Input.is_key_pressed(KEY_SHIFT)
	var can_sprint : bool    = stats.energy >= 1.0

	# Update movement state.
	# ATTACK, JUMP, SPAWN, and DEAD are owned by their update functions — never touch them here.
	if state != State.ATTACK and state != State.JUMP \
			and state != State.SPAWN and state != State.DEAD:
		if is_moving and is_shift and can_sprint:
			state = State.RUN
		elif is_moving:
			state = State.WALK
		else:
			state = State.IDLE

	# Detect going airborne without a voluntary jump — ledge fall OR thrown upward by a creature.
	# Check velocity.y to pick the correct starting frame and phase rather than always assuming descent:
	#   velocity.y > 0 → still ascending (thrown back by a big creature hit) → RISE, frame 1
	#   velocity.y <= 0 → descending or neutral (ledge fall, gravity already pulling) → FALL, frame 2
	# No energy cost — involuntary air time is never gated on energy.
	if state != State.JUMP and state != State.SPAWN and state != State.DEAD \
			and not is_on_floor():
		_jump_locked_vel        = Vector2(velocity.x, velocity.z)
		state                   = State.JUMP
		_jump_launched          = true
		player_sprite.animation = "jump_" + last_dir
		player_sprite.pause()
		if velocity.y > 0.0:
			_jump_phase         = JumpPhase.RISE
			player_sprite.frame = 1
		else:
			_jump_phase         = JumpPhase.FALL
			player_sprite.frame = 2

	# Rotate the 2D input vector by h_angle into a flat 3D world direction.
	# This keeps WASD camera-relative regardless of which way the camera is orbiting.
	var direction : Vector3 = Vector3(
		input.x * cos(h_angle) + input.y * sin(h_angle), 0.0,
		input.x * -sin(h_angle) + input.y * cos(h_angle))

	# RUN moves faster than WALK by SPRINT_MULT.
	var speed : float = stats.mspd * (SPRINT_MULT if state == State.RUN else 1.0)
	# Apply gravity when airborne. Reset Y when on floor so it doesn't accumulate.
	# Skip the reset in JUMP when _jump_launched is true — the launch velocity was set in
	# _jump_update() last frame (after move_and_slide) and must survive to this frame's
	# move_and_slide() call, otherwise it gets zeroed before the player actually lifts off.
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif not (state == State.JUMP and _jump_launched):
		velocity.y = 0.0

	# All JUMP phases (including WINDUP on the ground) lock horizontal movement to the
	# velocity committed at Space press — no steering from any phase onward.
	# SPAWN and DEAD: zero horizontal velocity — player must not move during either state.
	if state == State.SPAWN or state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
	elif state == State.JUMP:
		velocity.x = _jump_locked_vel.x + _knockback_vel.x
		velocity.z = _jump_locked_vel.y + _knockback_vel.z
	else:
		velocity.x = direction.x * speed + _knockback_vel.x
		velocity.z = direction.z * speed + _knockback_vel.z
	move_and_slide()
	# Decay knockback each frame. move_toward() reaches exactly zero — no float drift.
	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, KNOCKBACK_FRICTION * delta)

	# Deferred death transition — covers dying during IDLE, WALK, RUN, ATTACK.
	# JUMP handles its own landing → DEAD transition in _jump_update().
	# Wait until grounded and knockback settled so the throw-back arc or slide
	# resolves naturally before the death animation plays.
	if is_dead and state != State.DEAD and state != State.JUMP:
		if is_on_floor() and _knockback_vel.length() < KNOCKBACK_SETTLED_THRESHOLD:
			state = State.DEAD
			player_sprite.play("death")

	# Sprint energy drain — accumulate real time so tap-sprinting still costs energy
	# proportional to how long the key was held, not a flat cost per frame.
	if state == State.RUN:
		_run_energy_accum += delta
		if _run_energy_accum >= 1.0:
			# Drain a whole number of seconds at once to stay frame-rate independent.
			var ticks : int = int(_run_energy_accum)
			var cost  : int = int(SPRINT_ENERGY_COST * ticks)
			if stats.check_resources(0, cost, 0):
				stats.spend_resources(0, cost, 0)
			_run_energy_accum -= float(ticks)

	# Passive focus tick — +1 focus every 5s while in combat.
	# Timer resets to 0 when leaving combat so partial ticks don't carry over.
	if _combat_timer > 0.0:
		_focus_combat_timer += delta
		if _focus_combat_timer >= FOCUS_COMBAT_INTERVAL:
			stats.gain_focus(1)
			_focus_combat_timer -= FOCUS_COMBAT_INTERVAL
			print("focus +1 (combat tick) — focus: ", int(stats.focus), "/", stats.focus_max)
	else:
		_focus_combat_timer = 0.0

	match state:
		State.IDLE, State.WALK, State.RUN:
			_anim_apply(input)
		State.ATTACK:
			_attack_update()
		State.JUMP:
			_jump_update(delta)
		State.SPAWN:
			_spawn_update()
		State.DEAD:
			_dead_update()

	_fade_update()

	# --- Timers and regen ---

	# Advance all stat internal timers (GCD, etc).
	stats.tick(delta)

	# Count down all gates. Must tick before the regen check below so the gate
	# reaches zero and regen fires on the same frame it expires.
	_regen_timer         = maxf(0.0, _regen_timer         - delta)
	_combat_timer        = maxf(0.0, _combat_timer        - delta)
	_jump_cooldown_timer = maxf(0.0, _jump_cooldown_timer - delta)

	# Tick the active ability cooldown so it becomes ready again after each use.
	punch.tick(delta)

	# Regen is blocked while:
	#   _regen_timer > 0  — recent swing (even against props)
	#   _combat_timer > 0 — creature still chasing (_extend_combat_timer keeps this alive even
	#                       after _regen_timer expires, so this check is not redundant)
	#   state == RUN      — sprinting drains energy; regen at the same time would cancel the cost
	#   state == JUMP     — brief exertion; regen mid-air would feel unearned
	if _regen_timer <= 0.0 and _combat_timer <= 0.0 \
			and state != State.RUN and state != State.JUMP:
		stats.regen(delta)
