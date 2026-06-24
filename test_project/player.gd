extends Entity


# ===========================================================================
# INIT
# ===========================================================================

# Y height of the body origin above the ground plane.
# Body origin sits at fist/chest height so global_position.y reflects strike height.
# Capsule offset and sprite position in main.gd and init() are derived from this value.
const BODY_ORIGIN_Y : float = 1.5

# Reference to the physics collision shape. Disabled on death so the corpse
# does not block creature pathfinding or obstruct other physics interactions.
var _col : CollisionShape3D


# Called: main._build_player().
# Receives external references from main.gd and finishes building the player.
# Sprite frames are built here (expensive) so they only load once.
func init(p_camera_rig: Node3D, p_sprite: AnimatedSprite3D) -> void:

	camera_rig = p_camera_rig
	cam = camera_rig.get("cam")

	sprite = p_sprite
	sprite.sprite_frames = _load_sprite_frames()

	# Body origin is at 1.5u above ground (fist height). Sprite anchor is at its frame
	# center, so shift by half the frame world height minus the body offset so the
	# sprite base stays on the ground: (frame_h * pixel_size * 0.5) - 1.5.
	var frame_h : int = sprite.sprite_frames \
		.get_frame_texture("idle_neutral_south", 0).get_height()
	sprite.position.y = float(frame_h) * sprite.pixel_size * 0.5 - BODY_ORIGIN_Y

	# hit_half_height = BODY_ORIGIN_Y — player drawn sprite is 3u tall, center at 1.5u.
	# Body origin is at center so hit_half_height equals the origin height above ground.
	hit_half_height = BODY_ORIGIN_Y

	# TEST — set weapon_off here until the equipment system is built.
	weapon_off = "wooden_shield"
	if weapon_off != "":
		_build_shield_sprites()

	for child : Node in get_children():
		if child is CollisionShape3D:
			_col = child
			break

	# STR=1 AGI=1 STA=1 DEF=1 BMS=3 — minimal stats for combat testing.
	stats = Stats.new(1, 1, 1, 1, 3)
	_abilities.append(Abilities.get_ability("punch"))

	# Snapshot resources and position for respawn — taken after stats are built
	# so hp_max and energy_max are already set when we read hp and energy.
	_spawn_position = global_position
	_initial_hp     = stats.hp
	_initial_energy = stats.energy
	_initial_focus  = stats.focus

	# Begin in SPAWN — player is invincible until the animation completes.
	_set_state(State.SPAWN)


# ===========================================================================
# CAMERA
# ===========================================================================

# Camera slot settings. The player reads cam.use_wasd / cam.use_arrows each frame
# to decide which keys are active for movement. Also the reference the settings UI
# will read and write when the escape menu camera settings panel is built.
var cam        : CameraSettings

# The camera rig node. Queried each frame for h_angle so movement stays camera-relative.
var camera_rig : Node3D

# Current horizontal camera rotation in radians. Updated every frame from camera_rig.
# Used to rotate the input vector so WASD always points in the camera's forward direction.
var h_angle    : float = 0.0


# ===========================================================================
# ANIMATION
# ===========================================================================

# Zoom distance at which the player sprite begins to fade (fully visible at or above this).
const FADE_ZOOM_MAX : float = 5.0

# Zoom distance at which the player sprite is fully transparent (at or below this).
const FADE_ZOOM_MIN : float = 2.0

# Maps a cardinal direction string to its flat 2D input vector.
# Used by any system that needs to convert a facing direction to a world vector.
const DIR_MAP : Dictionary = {
	"north": Vector2( 0.0, -1.0),
	"south": Vector2( 0.0,  1.0),
	"east":  Vector2( 1.0,  0.0),
	"west":  Vector2(-1.0,  0.0)
}

# Last resolved facing direction ("north", "south", "east", "west").
# Persists when the player stops moving so the idle animation faces the right way.
var last_dir : String = "south"


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
		# Block animations — shield_up plays once on raise/lower, shield_stance loops while held.
		["shield_up_north",      base + "north/shield_up/",      7],
		["shield_up_south",      base + "south/shield_up/",      7],
		["shield_up_east",       base + "east/shield_up/",       7],
		["shield_up_west",       base + "west/shield_up/",       7],
		["shield_stance_north",  base + "north/shield_stance/",  5],
		["shield_stance_south",  base + "south/shield_stance/",  5],
		["shield_stance_east",   base + "east/shield_stance/",   5],
		["shield_stance_west",   base + "west/shield_stance/",   5],
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

	# Shield raise plays once — _block_update() waits for it to finish before entering stance.
	# shield_stance is left looping (default) — it runs until the key is released.
	frames.set_animation_loop("shield_up_north", false)
	frames.set_animation_loop("shield_up_south", false)
	frames.set_animation_loop("shield_up_east",  false)
	frames.set_animation_loop("shield_up_west",  false)

	# Lifecycle animations play once and hold the last frame.
	frames.set_animation_loop("spawn", false)
	frames.set_animation_loop("death", false)

	return frames


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
	if sprite.animation != anim_name:
		sprite.play(anim_name)
		_shield_set_flip(last_dir)
		_shield_set_z_order(last_dir)
		_shield_play(anim_name)


# Called: _physics_process().
# Fades the player sprite out as the camera zooms in close so the player never
# fully blocks the view. SPAWN and DEAD are exempt — always fully visible.
# Uses zoom_effective (the actual clipped distance) so wall-clip pullback
# does not cause the sprite to fade when the camera is forced closer by geometry.
func _fade_update() -> void:

	if state == State.SPAWN or state == State.DEAD:
		sprite.modulate.a = 1.0
		if _has_shield():
			_shield_front.modulate.a  = 1.0
			_shield_behind.modulate.a = 1.0
		return
	var alpha : float = clampf(
		inverse_lerp(FADE_ZOOM_MIN, FADE_ZOOM_MAX, camera_rig.get("zoom_effective")),
		0.0, 1.0)
	sprite.modulate.a = alpha
	if _has_shield():
		_shield_front.modulate.a  = alpha
		_shield_behind.modulate.a = alpha


# Called: all shield helper functions.
# Returns false when no shield is equipped — callers skip silently.
# Asserts when weapon_off is set but nodes were not built — that is always a bug.
func _has_shield() -> bool:

	if weapon_off == "":
		return false
	assert(_shield_front != null, "weapon_off is set but _build_shield_sprites() was not called")
	return true


# Called: any function that changes last_dir.
# Sets flip_h on both shield nodes — west loads east frames and mirrors them horizontally.
func _shield_set_flip(dir: String) -> void:

	if not _has_shield():
		return
	var flip : bool        = (dir == "west")
	_shield_front.flip_h  = flip
	_shield_behind.flip_h = flip


# Called: any function that changes the body animation via play().
# Mirrors the animation name on both shield nodes without restarting if already playing.
func _shield_play(anim_name: String) -> void:

	if not _has_shield():
		return
	if _shield_front.animation != anim_name:
		_shield_front.play(anim_name)
		_shield_behind.play(anim_name)


# Called: _jump_update(), _update_airborne(), _input() jump setup.
# Sets animation name, frame, and pauses — mirrors manual jump frame control on body sprite.
func _shield_set_anim_frame(anim_name: String, frame: int) -> void:

	if not _has_shield():
		return
	_shield_front.animation  = anim_name
	_shield_front.frame      = frame
	_shield_front.pause()
	_shield_behind.animation = anim_name
	_shield_behind.frame     = frame
	_shield_behind.pause()


# Called: _jump_update() when advancing jump phases.
# Sets frame index only — animation name is already correct from _shield_set_anim_frame().
func _shield_set_frame(frame: int) -> void:

	if not _has_shield():
		return
	_shield_front.frame  = frame
	_shield_behind.frame = frame


# Called: any function that resolves last_dir (static mode),
# and per-frame during the BLOCK state shield_up animation (frame mode).
# Static mode  (frame == -1, block_mode == false): regular animations — shield front only when north.
# Static mode  (frame == -1, block_mode == true):  shield_stance — shield front when south or west.
# Frame mode   (frame >= 0): shield_up per-frame — south 0-3 behind/4-6 front, north opposite,
#                             east always behind, west always front.
func _shield_set_z_order(dir: String, frame: int = -1, block_mode: bool = false) -> void:

	if not _has_shield():
		return
	var want_front : bool
	if frame >= 0:
		match dir:
			"south": want_front = frame >= 4
			"north": want_front = frame <  4
			"east":  want_front = false
			"west":  want_front = true
			_:       want_front = false
	elif block_mode:
		# Shield_stance: player holds shield out — visible in front when facing camera (south or west).
		want_front = (dir == "south" or dir == "west")
	else:
		# All other animations: shield only peeks in front when facing north (back to camera).
		want_front = (dir == "north")
	_shield_front.visible  = want_front
	_shield_behind.visible = not want_front



# ===========================================================================
# COMBAT
# ===========================================================================

# Seconds regen is held off after the player starts any swing (even against props).
# Prevents the player from recovering energy mid-combo by spam-attacking walls.
const REGEN_PAUSE        : float = 3.0

# Seconds the combat state persists after the last hit on a creature.
# Keeps the player in combat idle stance briefly after killing something.
const COMBAT_TIMEOUT     : float = 3.0

# Seconds between passive focus ticks while in combat. Each tick grants +1 focus.
const FOCUS_COMBAT_INTERVAL : float = 5.0

# Initial speed in world units/s applied to the player when a creature lands a hit.
# Decays to zero each frame via KNOCKBACK_FRICTION — not a duration, a rate.
const KNOCKBACK_STRENGTH : float = 8.0

# World units/s deceleration applied to _knockback_vel each frame via move_toward().
# At 20.0 the player stops in ~0.4s. Higher = snappier, lower = longer slide.
const KNOCKBACK_FRICTION : float = 20.0

# Knockback speed below which the deferred death trigger considers the player settled.
# Prevents the death animation from firing mid-slide after a lethal hit.
const KNOCKBACK_SETTLED_THRESHOLD : float = 0.1

# Fraction of knockback applied while airborne. Full knockback mid-air feels uncontrollable
# because there is no ground friction to stop it — 0.1x keeps the push visible but contained.
const KNOCKBACK_AIR_SCALE : float = 0.1

# Flat tolerance added to hit_half_height comparisons to absorb physics safe-margin drift.
# Godot's CharacterBody3D rests ~0.001u above the exact floor surface — without this slack
# the height gate rejects attacks on same-level targets by a fraction of a unit.
const ATTACK_HEIGHT_SLACK : float = 0.05

# Minimum dot product between facing direction and player→target vector for a hit to land.
# dot = cos(angle) — so 0.7071 = cos(45°) = ±45° cone (90° total arc).
# Lower = wider cone: 0.5 = ±60°, 0.0 = ±90° (hemisphere), -1.0 = full circle.
const ATTACK_ARC_DOT : float = 0.7071

# Gate: regen is blocked while this is above zero. Reset to REGEN_PAUSE on any swing.
var _regen_timer    : float = 0.0

# Gate: combat idle animations are active while this is above zero.
# Only reset to COMBAT_TIMEOUT when a creature is actually hit — not on prop hits.
var _combat_timer   : float = 0.0

# Counts down each FOCUS_COMBAT_INTERVAL while in combat. On expiry grants +1 focus and resets.
# Resets to 0 when leaving combat so the tick only fires during active fights.
var _focus_combat_timer : float = 0.0

# Current knockback velocity in world units/s. Set by receive_hit(), decays to
# Vector3.ZERO each frame via move_toward(). Added on top of movement velocity.
var _knockback_vel  : Vector3 = Vector3.ZERO

# All equipped abilities in slot order (slot 0 = KEY_1, slot 1 = KEY_2, etc.).
# Ticked every frame in _update_timers() so cooldowns count down for all slots at once.
var _abilities      : Array[Ability] = []

# The ability currently being executed in the ATTACK state.
# Set in _input() at swing start; read by _attack_update() for hit-frame timing.
var _active_ability : Ability

# Guard flag: true once damage has been applied this swing.
# Prevents hit from firing more than once per animation playback.
var _hit_applied : bool = false


# Called: _attack_update().
# Iterates all nodes in the "creatures" group and applies damage to every valid target.
# Height gate uses each target's hit_half_height — attack connects when the player's
# global_position.y (fist height) falls within the target's hittable Y range.
# Each target gets its own independent damage roll — own crit chance, own focus gain.
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
		# Height gate — player origin must fall within the target's hittable Y range.
		# ATTACK_HEIGHT_SLACK absorbs physics safe-margin drift (~0.001u) so same-level
		# targets are never rejected by a rounding-error fraction.
		if absf(diff.y) > node.get("hit_half_height") + ATTACK_HEIGHT_SLACK:
			continue
		# XZ distance gate — flat plane only, height already handled above.
		var flat : Vector3 = Vector3(diff.x, 0.0, diff.z)
		if flat.length_squared() > range_sq:
			continue
		# Facing gate — target must be within the attack cone.
		# ATTACK_ARC_DOT = cos(45°) = 0.7071 → ±45° from facing direction (90° total arc).
		if flat.length_squared() > 0.001 and flat.normalized().dot(dir_vec) < ATTACK_ARC_DOT:
			continue
		# Each creature gets its own damage roll — crit is independent per target.
		var damage  : float = _active_ability.calc_damage(stats)
		var kb_dir  : Vector3 = flat.normalized() if flat.length_squared() > 0.001 else dir_vec
		node.call("receive_hit", damage, kb_dir, stats.last_hit_was_crit)
		_combat_timer = COMBAT_TIMEOUT
		# Award EXP if this hit killed the creature.
		if node.get("is_dead"):
			stats.gain_exp(float(node.get("exp_reward")))


# Called: _physics_process() while state == ATTACK.
# Polls the animation frame each tick to apply damage exactly at hit_frame,
# then waits for playback to end before releasing the ATTACK state.
func _attack_update() -> void:

	# Animation finished — swing is over, return to normal state.
	if not sprite.is_playing():
		_set_state(State.IDLE)
		return

	# Apply damage once when the animation reaches the designated hit frame.
	# _hit_applied guards against the raycast firing multiple times if the
	# game runs at a frame rate where the same animation frame is visited twice.
	var frame : int = sprite.get_frame()
	if frame >= _active_ability.hit_frame and not _hit_applied:
		_hit_applied = true
		_attack_check()


# Called: creature._attack_check() when a creature's attack reaches the player.
# damage : raw damage value from the creature's ability.calc_damage().
# dir     : flat direction from creature to player — used for knockback direction.
# is_crit : true if the incoming hit was a critical strike — forces block drop on HOLDING.
# Gets hit resets both gates: regen pauses and combat window refreshes.
func receive_hit(damage: float, dir: Vector3, is_crit: bool = false) -> void:

	if state == State.SPAWN:
		return

	# Block check runs before damage is applied — a successful block absorbs the hit entirely.
	# RAISING and LOWERING do not block, only HOLDING (shield stance) does.
	# Directional gate: attack must come from within the block arc (facing dot incoming > threshold).
	# Arc is ±60° by default (dot > 0.5). Talent reduces threshold toward 0.0 (±90°).
	# Attacks outside the arc bypass block entirely — full damage + full knockback.
	# Crit-forced drop: a crit always forces LOWERING. Block cannot absorb a critical hit.
	# After LOWERING completes the player must re-press § to raise the shield again (Option A).
	if state == State.BLOCK and _block_phase == BlockPhase.HOLDING:
		if is_crit:
			_enter_block_lowering()
			print("block DROPPED — crit forced shield down")
		else:
			var inp     : Vector2 = DIR_MAP[last_dir]
			var facing  : Vector3 = Vector3(
				inp.x * cos(h_angle) + inp.y * sin(h_angle), 0.0,
				-inp.x * sin(h_angle) + inp.y * cos(h_angle)).normalized()
			var in_arc  : bool = facing.dot(dir.normalized()) > stats.block_dir_threshold
			if in_arc and randf() < stats.block_chance:
				_regen_timer   = REGEN_PAUSE
				_combat_timer  = COMBAT_TIMEOUT
				_knockback_vel = dir.normalized() * KNOCKBACK_STRENGTH * 0.5
				stats.gain_focus_on_receive()
				_flash_sprite()
				print("hit BLOCKED — no damage (block_chance: ", stats.block_chance, ")")
				return
			elif not in_arc:
				print("block BYPASSED — attack outside shield arc")
			else:
				print("block FAILED (block_chance: ", stats.block_chance, ")")

	# Unblocked hit — super handles take_damage, gain_focus_on_receive, flash, death flag.
	super.receive_hit(damage, dir, is_crit)
	if _last_damage == 0.0:
		return  # super returned early (was already dead)
	print("player hit for ", _last_damage, " — hp: ", stats.hp, "/", stats.hp_max)
	_regen_timer   = REGEN_PAUSE
	_combat_timer  = COMBAT_TIMEOUT
	# Push the player away from the attacker. dir points from creature to player
	# so it's already the correct knockback direction.
	_knockback_vel = dir.normalized() * KNOCKBACK_STRENGTH
	if is_dead:
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

# Upward velocity in world units/s applied once at launch.
# At GRAVITY=-20, this gives ~1.5 tiles of peak height and ~0.775s air time.
const JUMP_VEL     : float = 7.75

# Duration of one animation frame in seconds at 8 fps.
# Used to pace WINDUP and LAND frames — jump frames are driven by physics phase, not play().
const ANIM_FRAME_DUR : float = 1.0 / 8.0

# Seconds after landing before the player can jump again.
# Starts on LAND exit — applies to both voluntary jumps and cliff falls.
const JUMP_COOLDOWN  : float = 0.3

# Jump animation frame indices. Frames are set manually — play() is never called during a jump.
const JUMP_FRAME_WINDUP  : int = 0  # prep on ground
const JUMP_FRAME_RISE    : int = 1  # ascending
const JUMP_FRAME_FALL    : int = 2  # descending
const JUMP_FRAME_CONTACT : int = 3  # first landing contact
const JUMP_FRAME_LAND    : int = 4  # absorption

# Tracks which physics sub-phase the player is in during a jump.
# WINDUP: on ground, prep frame playing. RISE: airborne, going up.
# FALL: airborne, going down. LAND: touched ground, absorption frame playing.
enum JumpPhase { WINDUP, RISE, FALL, LAND }
var _jump_phase : JumpPhase = JumpPhase.WINDUP

# True once JUMP_VEL has been applied this jump. Guards against re-applying on
# repeated frames and tells the gravity block not to snap velocity.y to 0.
var _jump_launched : bool = false

# Counts down in WINDUP (holds prep frame) and LAND (paces contact → absorption frames).
# Not used during RISE or FALL — those phases are driven purely by velocity.y and is_on_floor().
var _jump_frame_timer : float = 0.0

# Counts down after the LAND animation completes. Jump is blocked while above zero.
var _jump_cooldown_timer : float = 0.0

# Horizontal velocity (world X, world Z) captured the moment the player goes airborne.
# Held constant during RISE and FALL — no mid-air steering.
var _jump_locked_vel : Vector2 = Vector2.ZERO


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
				sprite.frame        = JUMP_FRAME_RISE
				_shield_set_frame(JUMP_FRAME_RISE)

		JumpPhase.RISE:
			# Hold ascent frame until apex — velocity.y turns zero then negative.
			if velocity.y <= 0.0:
				_jump_phase  = JumpPhase.FALL
				sprite.frame = JUMP_FRAME_FALL
				_shield_set_frame(JUMP_FRAME_FALL)

		JumpPhase.FALL:
			# Hold descent frame until grounded. Start the landing timer on contact.
			if is_on_floor():
				velocity.y          = 0.0
				_jump_phase         = JumpPhase.LAND
				sprite.frame        = JUMP_FRAME_CONTACT
				_shield_set_frame(JUMP_FRAME_CONTACT)
				# Reserve time for CONTACT + LAND frames.
				_jump_frame_timer   = ANIM_FRAME_DUR * 2.0

		JumpPhase.LAND:
			# Count down through the two landing frames then hand control back.
			_jump_frame_timer -= delta
			if _jump_frame_timer > ANIM_FRAME_DUR:
				sprite.frame = JUMP_FRAME_CONTACT
				_shield_set_frame(JUMP_FRAME_CONTACT)
			elif _jump_frame_timer > 0.0:
				sprite.frame = JUMP_FRAME_LAND
				_shield_set_frame(JUMP_FRAME_LAND)
			else:
				_jump_phase          = JumpPhase.WINDUP
				_jump_launched       = false
				_jump_cooldown_timer = JUMP_COOLDOWN
				# If the player died mid-air, next frame will trigger death.
				# For now we transition to Idle state.
				_set_state(State.IDLE)


# ===========================================================================
# BLOCK
# ===========================================================================

# Tracks which sub-phase the player is in during a block.
# RAISING : advancing through shield_up frames — player locked, cannot move.
# HOLDING : shield_stance looping — player can move at half speed, blocks incoming hits.
# LOWERING: stepping back through shield_up frames — player locked, cannot move.
enum BlockPhase { RAISING, HOLDING, LOWERING }
var _block_phase : BlockPhase = BlockPhase.RAISING

# Frame count for the shield_up animation. Must match _load_sprite_frames() and _load_shield_frames().
const SHIELD_UP_FRAMES : int = 7

# Fractional frame position within shield_up (0.0 = first frame, SHIELD_UP_FRAMES-1 = last frame).
# Driven by delta in RAISING (counts up) and LOWERING (counts down).
# Preserved across direction changes so transitions always start from the current position.
var _block_frame_progress : float = 0.0

# True when LOWERING was forced by a crit hit — blocks the § re-raise shortcut.
# Cleared when LOWERING completes. Voluntary LOWERING (§ released) never sets this.
var _block_crit_forced : bool = false


# Called: _physics_process(delta) while state == BLOCK.
# Drives all three block phases. All animation is manual — play() is never called in RAISING or
# LOWERING so transitions always start from the current frame, not from the ends.
# Transitions:
#   RAISING  → HOLDING  : progress reaches last frame AND key still held
#   RAISING  → LOWERING : key released mid-raise — reverses from current frame
#   HOLDING  → LOWERING : key released (polled each frame)
#   LOWERING → RAISING  : key re-pressed mid-lower — reverses from current frame
#   LOWERING → IDLE     : progress reaches frame 0
func _block_update(delta: float, input: Vector2) -> void:

	match _block_phase:

		BlockPhase.RAISING:
			_block_frame_progress  = minf(_block_frame_progress + 8.0 * delta, float(SHIELD_UP_FRAMES - 1))
			var frame : int        = int(_block_frame_progress)
			sprite.animation       = "shield_up_" + last_dir
			sprite.frame           = frame
			sprite.pause()
			_shield_set_anim_frame("shield_up_" + last_dir, frame)
			_shield_set_z_order(last_dir, frame)
			if not Input.is_key_pressed(KEY_SECTION):
				_block_phase = BlockPhase.LOWERING
			elif _block_frame_progress >= float(SHIELD_UP_FRAMES - 1):
				_block_phase      = BlockPhase.HOLDING
				var anim : String = "shield_stance_" + last_dir
				sprite.play(anim)
				_shield_set_z_order(last_dir, -1, true)
				_shield_play(anim)

		BlockPhase.HOLDING:
			# Update facing direction from movement input.
			# Suppressed while RMB is held — camera orbit should not change block direction.
			var new_dir : String = _get_dir(input)
			if new_dir != last_dir and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				last_dir          = new_dir
				var anim : String = "shield_stance_" + last_dir
				sprite.play(anim)
				_shield_set_flip(last_dir)
				_shield_set_z_order(last_dir, -1, true)
				_shield_play(anim)
			if not Input.is_key_pressed(KEY_SECTION):
				_block_frame_progress = float(SHIELD_UP_FRAMES - 1)
				_block_phase          = BlockPhase.LOWERING
				var frame : int       = SHIELD_UP_FRAMES - 1
				sprite.animation      = "shield_up_" + last_dir
				sprite.frame          = frame
				sprite.pause()
				_shield_set_anim_frame("shield_up_" + last_dir, frame)
				_shield_set_z_order(last_dir, frame)

		BlockPhase.LOWERING:
			_block_frame_progress  = maxf(_block_frame_progress - 8.0 * delta, 0.0)
			var frame : int        = int(_block_frame_progress)
			sprite.animation       = "shield_up_" + last_dir
			sprite.frame           = frame
			sprite.pause()
			_shield_set_anim_frame("shield_up_" + last_dir, frame)
			_shield_set_z_order(last_dir, frame)
			if Input.is_key_pressed(KEY_SECTION) and not _block_crit_forced:
				# Re-pressed during voluntary lower — reverse back to raising from current frame.
				_block_phase = BlockPhase.RAISING
			elif _block_frame_progress <= 0.0:
				_block_crit_forced = false
				_set_state(State.IDLE)


# Called: receive_hit() on crit-forced block drop.
# Drops directly into LOWERING from whatever frame the shield is currently at.
# Sets _block_crit_forced so the § re-raise shortcut is disabled for this lowering cycle.
func _enter_block_lowering() -> void:

	_block_phase       = BlockPhase.LOWERING
	_block_crit_forced = true


# ===========================================================================
# LIFECYCLE
# ===========================================================================

# Seconds after entering DEAD before the player respawns.
const RESPAWN_DELAY : float = 3.0

# World position recorded at init(). Respawn always returns to this point.
var _spawn_position : Vector3 = Vector3.ZERO

# Counts up while in DEAD state. Respawn fires when it reaches RESPAWN_DELAY.
var _dead_timer     : float   = 0.0

# Resource snapshot taken at init(). Restored on every respawn so the player
# always comes back at full strength regardless of what state they died in.
var _initial_hp     : float   = 0.0
var _initial_energy : float   = 0.0
var _initial_focus  : float   = 0.0


# Called: _physics_process() while state == SPAWN.
# Waits for the spawn animation to finish then transitions to IDLE.
func _spawn_update() -> void:

	if not sprite.is_playing():
		_set_state(State.IDLE)


# Called: _physics_process() while state == DEAD.
# Counts down the respawn timer. All other processing is skipped while dead.
func _dead_update(delta: float) -> void:

	_dead_timer += delta
	if _dead_timer >= RESPAWN_DELAY:
		_do_respawn()


# Called: _dead_update() when _dead_timer reaches RESPAWN_DELAY.
# Restores resources to their initial values, re-enables collision,
# snaps the player back to spawn position, and enters the SPAWN state.
func _do_respawn() -> void:

	is_dead      = false
	stats.hp     = _initial_hp
	stats.energy = _initial_energy
	stats.focus  = _initial_focus
	_col.set_deferred("disabled", false)
	global_position = _spawn_position
	velocity        = Vector3.ZERO
	_knockback_vel  = Vector3.ZERO
	_dead_timer     = 0.0
	_set_state(State.SPAWN)


# ===========================================================================
# MOVEMENT
# ===========================================================================

# Downward acceleration in world units/s² applied each frame when airborne.
# Negative because Y is up — gravity pulls down.
const GRAVITY        : float = -20.0

# Speed multiplier applied on top of stats.mspd when the player is running.
const SPRINT_MULT    : float = 1.2

# Energy drained per second while the player is sprinting.
# Accumulates in _run_energy_accum so tap-sprinting costs proportional energy.
const SPRINT_ENERGY_COST : float = 1.0

# Accumulates real elapsed time (seconds) while running. Energy is drained
# in whole-second ticks so brief sprints cost proportional energy rather than
# a full second on the first frame touched.
var _run_energy_accum : float = 0.0


# ===========================================================================
# STATE
# ===========================================================================

# Current movement/action state.
# IDLE/WALK/RUN: movement states, driven by input each frame.
# ATTACK: owned by _input and _attack_update — movement logic must not overwrite.
# JUMP: owned by _input and _jump_update — covers voluntary jumps, ledge falls, throw-backs.
# SPAWN: invincible, full animation plays, no input accepted.
# DEAD: invincible, full animation plays to last frame then holds, terminal.
enum State { IDLE, WALK, RUN, ATTACK, JUMP, SPAWN, DEAD, BLOCK, GRAB, PUSH, PULL }
var state : State = State.IDLE


# Called: any code path that changes the current player state.
# Sets state, resolves the correct animation name, and plays it on both sprite layers.
# Returns without playing when state is manually managed (JUMP/BLOCK/ATTACK return "").
# Guard prevents restarting a clip that is already playing — avoids frame-zero flash.
func _set_state(new_state: State) -> void:

	state = new_state
	var anim : String = _state_anim()
	if anim == "":
		return
	if sprite.animation != anim:
		sprite.play(anim)
	_shield_set_flip(last_dir)
	_shield_set_z_order(last_dir)
	_shield_play(anim)


# Called: _set_state().
# Returns the animation name owned by the given state.
# Returns "" for states that drive their own animation manually (ATTACK, JUMP, BLOCK,
# GRAB, PUSH, PULL) — _set_state() skips play() when it receives an empty string.
func _state_anim() -> String:

	match state:
		State.IDLE:
			if _is_in_combat():
				return "idle_attack_" + _weapon_style() + "_" + last_dir
			return "idle_neutral_" + last_dir
		State.WALK:  return "walking_" + last_dir
		State.RUN:   return "running_" + last_dir
		State.SPAWN: return "spawn"
		State.DEAD:  return "death"
	return ""  # ATTACK, JUMP, BLOCK, GRAB, PUSH, PULL — manually managed


# ===========================================================================
# EQUIPMENT
# ===========================================================================

# Main-hand weapon slot identifier ("sword", "pickaxe", etc). Empty = unarmed.
# Drives animation names — "attack_unarmed_*", "attack_sword_*", etc.
var weapon_main : String = ""

# Off-hand weapon slot identifier. Drives shield layer loading and block logic.
var weapon_off  : String = ""

# Shield layer sprite nodes — created by _build_shield_sprites() when weapon_off is set.
# _shield_front  renders in front of the player body (sorting_offset > body sprite).
# _shield_behind renders behind the player body (sorting_offset < body sprite).
# Exactly one is visible at a time — _shield_set_z_order() picks the correct node per direction.
var _shield_front  : AnimatedSprite3D
var _shield_behind : AnimatedSprite3D


# Called: init() when weapon_off != "".
# Creates the two shield layer AnimatedSprite3D nodes and loads their frames.
# sorting_offset controls render order for transparent sprites at the same position:
# a greater value sorts in front. Body sprite sorting_offset defaults to 0.
func _build_shield_sprites() -> void:

	var shield_frames : SpriteFrames = _load_shield_frames()

	_shield_front                  = AnimatedSprite3D.new()
	_shield_front.pixel_size       = PIXEL_SIZE
	_shield_front.billboard        = BaseMaterial3D.BILLBOARD_FIXED_Y
	_shield_front.alpha_cut        = SpriteBase3D.ALPHA_CUT_DISABLED
	_shield_front.texture_filter   = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_shield_front.position.y       = sprite.position.y
	_shield_front.sorting_offset   = 0.01
	_shield_front.sprite_frames    = shield_frames
	add_child(_shield_front)

	_shield_behind                 = AnimatedSprite3D.new()
	_shield_behind.pixel_size      = PIXEL_SIZE
	_shield_behind.billboard       = BaseMaterial3D.BILLBOARD_FIXED_Y
	_shield_behind.alpha_cut       = SpriteBase3D.ALPHA_CUT_DISABLED
	_shield_behind.texture_filter  = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_shield_behind.position.y      = sprite.position.y
	_shield_behind.sorting_offset  = -0.01
	_shield_behind.sprite_frames   = shield_frames
	add_child(_shield_behind)


# Called: _build_shield_sprites().
# Loads all shield layer animations from the weapon_off asset folder.
# West direction loads east frames — flip_h is applied at runtime by _shield_set_flip().
func _load_shield_frames() -> SpriteFrames:

	var frames : SpriteFrames = SpriteFrames.new()
	var base   : String       = "res://assets/player/ares/weapon/off/" + weapon_off + "/"

	var anims : Array = [
		["walking_south",             base + "south/walking/",             6],
		["walking_north",             base + "north/walking/",             6],
		["walking_east",              base + "east/walking/",              6],
		["walking_west",              base + "east/walking/",              6],
		["running_south",             base + "south/running/",             6],
		["running_north",             base + "north/running/",             6],
		["running_east",              base + "east/running/",              6],
		["running_west",              base + "east/running/",              6],
		["idle_neutral_south",        base + "south/idle_neutral/",        10],
		["idle_neutral_north",        base + "north/idle_neutral/",        10],
		["idle_neutral_east",         base + "east/idle_neutral/",         10],
		["idle_neutral_west",         base + "east/idle_neutral/",         10],
		["idle_attack_unarmed_south", base + "south/idle_attack/unarmed/", 6],
		["idle_attack_unarmed_north", base + "north/idle_attack/unarmed/", 6],
		["idle_attack_unarmed_east",  base + "east/idle_attack/unarmed/",  6],
		["idle_attack_unarmed_west",  base + "east/idle_attack/unarmed/",  6],
		["attack_unarmed_south",      base + "south/attack/unarmed/",      5],
		["attack_unarmed_north",      base + "north/attack/unarmed/",      5],
		["attack_unarmed_east",       base + "east/attack/unarmed/",       5],
		["attack_unarmed_west",       base + "east/attack/unarmed/",       5],
		["jump_south",                base + "south/jump/",                5],
		["jump_north",                base + "north/jump/",                5],
		["jump_east",                 base + "east/jump/",                 5],
		["jump_west",                 base + "east/jump/",                 5],
		["shield_up_south",           base + "south/shield_up/",           7],
		["shield_up_north",           base + "north/shield_up/",           7],
		["shield_up_east",            base + "east/shield_up/",            7],
		["shield_up_west",            base + "east/shield_up/",            7],
		["shield_stance_south",       base + "south/shield_stance/",       5],
		["shield_stance_north",       base + "north/shield_stance/",       5],
		["shield_stance_east",        base + "east/shield_stance/",        5],
		["shield_stance_west",        base + "east/shield_stance/",        5],
		["spawn",                     base + "spawn/",                     29],
		["death",                     base + "death/",                     29]]

	for anim : Array in anims:
		var anim_name   : String = anim[0]
		var path        : String = anim[1]
		var frame_count : int    = anim[2]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		for i : int in range(frame_count):
			var tex : Texture2D = load(path + str(i) + ".png")
			frames.add_frame(anim_name, tex)

	# Must match the body sprite loop settings exactly.
	for suffix : String in ["south", "north", "east", "west"]:
		frames.set_animation_loop("attack_unarmed_" + suffix, false)
		frames.set_animation_loop("jump_"           + suffix, false)
		frames.set_animation_loop("shield_up_"      + suffix, false)
	frames.set_animation_loop("spawn",  false)
	frames.set_animation_loop("death",  false)

	return frames


# ===========================================================================
# INPUT
# ===========================================================================

# Called: Godot engine (InputEvent).
# Handles ability activation on key press. Movement is handled in _physics_process()
# via the continuous Input.get_vector() poll — not here.
func _input(event: InputEvent) -> void:

	if is_dead or state == State.SPAWN or state == State.BLOCK:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# DEBUG ONLY — remove before release.
		if event.keycode == KEY_K:
			receive_hit(10.0, -global_transform.basis.z)
			return
		if event.keycode == KEY_1:
			# KEY_1 triggers the punch ability (placeholder — more abilities will expand this).
			# JUMP and ATTACK block each other — no attacking mid-air, no jumping mid-swing.
			if state != State.ATTACK and state != State.JUMP and _abilities[0].can_use(stats):
				# Block regen for the full REGEN_PAUSE window from this swing.
				_regen_timer    = REGEN_PAUSE
				# Reset hit guard at swing start so the hit fires exactly once this swing when the
				# hit_frame arives, if arives and the attack didnt stop from a status effect like stun.
				_hit_applied    = false
				_active_ability = _abilities[0]
				state           = State.ATTACK
				_active_ability.spend(stats)
				sprite.play("attack_" + _weapon_style() + "_" + last_dir)
				_shield_play("attack_" + _weapon_style() + "_" + last_dir)

		elif event.keycode == KEY_SECTION:
			# § holds the shield up. Must have a shield equipped and not be mid-action.
			# ATTACK, JUMP, and RUN block entry — must be standing or walking to raise shield.
			if _has_shield() and state != State.ATTACK and state != State.JUMP \
					and state != State.RUN and state != State.BLOCK:
				state                 = State.BLOCK
				_block_phase          = BlockPhase.RAISING
				_block_frame_progress = 0.0
				sprite.animation      = "shield_up_" + last_dir
				sprite.frame          = 0
				sprite.pause()
				_shield_set_flip(last_dir)
				_shield_set_z_order(last_dir, 0)
				_shield_set_anim_frame("shield_up_" + last_dir, 0)

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
				sprite.animation = "jump_" + last_dir
				sprite.frame     = JUMP_FRAME_WINDUP
				sprite.pause()
				_shield_set_flip(last_dir)
				_shield_set_z_order(last_dir)
				_shield_set_anim_frame("jump_" + last_dir, JUMP_FRAME_WINDUP)


# ===========================================================================
# PROCESS
# ===========================================================================

# Called: _physics_process().
# Reads directional keys respecting cam.use_wasd and cam.use_arrows flags.
# Returns a normalized Vector2 for diagonal input, raw for cardinal.
func _read_input() -> Vector2:

	var input : Vector2 = Vector2.ZERO
	if (cam.use_wasd   and Input.is_key_pressed(KEY_A)) or \
		(cam.use_arrows and Input.is_key_pressed(KEY_LEFT)):  input.x -= 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_D)) or \
		(cam.use_arrows and Input.is_key_pressed(KEY_RIGHT)): input.x += 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_W)) or \
		(cam.use_arrows and Input.is_key_pressed(KEY_UP)):    input.y -= 1.0
	if (cam.use_wasd   and Input.is_key_pressed(KEY_S)) or \
		(cam.use_arrows and Input.is_key_pressed(KEY_DOWN)):  input.y += 1.0
	return input.normalized() if input.length() > 1.0 else input


# Called: _physics_process().
# Resolves IDLE/WALK/RUN from input and shift key.
# ATTACK, JUMP, SPAWN, DEAD, BLOCK, GRAB, PUSH, and PULL are owned by their update
# functions — movement state must never overwrite them.
func _update_state(input: Vector2) -> void:

	if state == State.ATTACK or state == State.JUMP \
			or state == State.SPAWN or state == State.DEAD \
			or state == State.BLOCK or state == State.GRAB \
			or state == State.PUSH or state == State.PULL:
		return
	var is_moving  : bool = input.length() >= 0.1
	var can_sprint : bool = stats.energy >= 1.0
	if is_moving and Input.is_key_pressed(KEY_SHIFT) and can_sprint:
		state = State.RUN
	elif is_moving:
		state = State.WALK
	else:
		state = State.IDLE


# Called: _physics_process().
# Detects going airborne without a voluntary jump — ledge fall or creature throw-back.
# velocity.y > 0 → thrown upward → RISE. velocity.y <= 0 → falling → FALL.
# No energy cost — involuntary air time is never gated on resources.
# GRAB/PUSH/PULL are skipped — grab releases when the player is hit, not when airborne.
func _update_airborne() -> void:

	if state == State.JUMP or state == State.SPAWN or state == State.DEAD \
			or state == State.GRAB or state == State.PUSH or state == State.PULL:
		return
	if is_on_floor():
		return
	_jump_locked_vel = Vector2(velocity.x, velocity.z)
	state            = State.JUMP
	_jump_launched   = true
	sprite.animation = "jump_" + last_dir
	sprite.pause()
	_shield_set_flip(last_dir)
	_shield_set_z_order(last_dir)
	if velocity.y > 0.0:
		_jump_phase  = JumpPhase.RISE
		sprite.frame = JUMP_FRAME_RISE
		_shield_set_anim_frame("jump_" + last_dir, JUMP_FRAME_RISE)
	else:
		_jump_phase  = JumpPhase.FALL
		sprite.frame = JUMP_FRAME_FALL
		_shield_set_anim_frame("jump_" + last_dir, JUMP_FRAME_FALL)


# Called: _physics_process().
# Applies gravity, sets horizontal velocity by state, runs move_and_slide, decays knockback.
# SPAWN/DEAD: no horizontal movement. JUMP: locked velocity + knockback. else: input-driven.
func _update_velocity(input: Vector2, delta: float) -> void:

	# DEAD: collision shape is disabled so is_on_floor() always returns false and gravity
	# would accumulate into velocity.y every frame, pulling the corpse through the floor.
	# No physics is needed while dead — zero everything and return before any gravity or slide.
	if state == State.DEAD:
		velocity = Vector3.ZERO
		return

	var direction : Vector3 = Vector3(
		input.x * cos(h_angle) + input.y * sin(h_angle), 0.0,
		input.x * -sin(h_angle) + input.y * cos(h_angle))
	var speed : float = stats.mspd * (SPRINT_MULT if state == State.RUN else 1.0)

	# Gravity — accumulates while airborne. Reset on floor unless jump launch is pending.
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif not (state == State.JUMP and _jump_launched):
		velocity.y = 0.0

	if state == State.SPAWN:
		velocity.x = 0.0
		velocity.z = 0.0
	elif state == State.ATTACK:
		velocity.x = _knockback_vel.x
		velocity.z = _knockback_vel.z
	elif state == State.BLOCK:
		if _block_phase == BlockPhase.HOLDING:
			# Shield stance — player can move at half speed. Knockback still stacks.
			velocity.x = direction.x * speed * 0.5 + _knockback_vel.x
			velocity.z = direction.z * speed * 0.5 + _knockback_vel.z
		else:
			# RAISING or LOWERING — no voluntary movement. Knockback still applies.
			velocity.x = _knockback_vel.x
			velocity.z = _knockback_vel.z
	elif state == State.JUMP:
		# Knockback is scaled down while airborne — no ground friction to stop it mid-air.
		velocity.x = _jump_locked_vel.x + _knockback_vel.x * KNOCKBACK_AIR_SCALE
		velocity.z = _jump_locked_vel.y + _knockback_vel.z * KNOCKBACK_AIR_SCALE
	else:
		velocity.x = direction.x * speed + _knockback_vel.x
		velocity.z = direction.z * speed + _knockback_vel.z
	move_and_slide()
	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, KNOCKBACK_FRICTION * delta)


# Called: _physics_process().
# Triggers the DEAD state once the player is grounded and knockback has settled.
# JUMP handles its own death transition at LAND exit — only non-jump states handled here.
func _update_death() -> void:

	if not is_dead or state == State.DEAD or state == State.JUMP:
		return
	if is_on_floor() and _knockback_vel.length() < KNOCKBACK_SETTLED_THRESHOLD:
		_set_state(State.DEAD)
		_col.set_deferred("disabled", true)


# Called: _physics_process().
# Drains energy while sprinting via an accumulator so tap-sprinting costs proportional energy.
# check_resources guards spend so energy never goes negative.
func _update_sprint(delta: float) -> void:

	if state != State.RUN:
		return
	_run_energy_accum += delta
	if _run_energy_accum >= 1.0:
		var ticks : int = int(_run_energy_accum)
		var cost  : int = int(SPRINT_ENERGY_COST * ticks)
		if stats.check_resources(0, cost, 0):
			stats.spend_resources(0, cost, 0)
		_run_energy_accum -= float(ticks)


# Called: _physics_process().
# Awards +1 focus every FOCUS_COMBAT_INTERVAL seconds while in combat.
# Timer resets when leaving combat so partial ticks do not carry over.
func _update_focus(delta: float) -> void:

	if _combat_timer <= 0.0:
		_focus_combat_timer = 0.0
		return
	_focus_combat_timer += delta
	if _focus_combat_timer >= FOCUS_COMBAT_INTERVAL:
		stats.gain_focus(1)
		_focus_combat_timer -= FOCUS_COMBAT_INTERVAL
		print("focus +1 (combat tick) — focus: ", int(stats.focus), "/", stats.focus_max)


# Called: _physics_process().
# Counts down all timers and ability cooldowns, then runs regen if all gates are clear.
# Timers must tick before the regen check so a gate expiring this frame allows regen immediately.
func _update_timers(delta: float) -> void:

	stats.tick(delta)
	_regen_timer         = maxf(0.0, _regen_timer         - delta)
	_combat_timer        = maxf(0.0, _combat_timer        - delta)
	_jump_cooldown_timer = maxf(0.0, _jump_cooldown_timer - delta)
	for ability : Ability in _abilities:
		ability.tick(delta)

	# Regen blocked by: recent swing, active combat, sprinting, jumping.
	# _combat_timer check is not redundant — _extend_combat_timer() keeps it alive
	# past _regen_timer so a chasing creature blocks regen even between swings.
	if _regen_timer <= 0.0 and _combat_timer <= 0.0 \
			and state != State.RUN and state != State.JUMP and state != State.BLOCK:
		stats.regen(delta)


# Called: Godot engine (every frame).
# Orchestrates the full per-frame update. Each sub-function owns one concern.
func _physics_process(delta: float) -> void:

	h_angle       = camera_rig.get("h_angle")
	var input     : Vector2 = _read_input()
	_update_state(input)
	_update_airborne()
	_update_velocity(input, delta)
	_update_death()
	_update_sprint(delta)
	_update_focus(delta)

	match state:
		State.IDLE, State.WALK, State.RUN: _anim_apply(input)
		State.ATTACK:                      _attack_update()
		State.JUMP:                        _jump_update(delta)
		State.BLOCK:                       _block_update(delta, input)
		State.SPAWN:                       _spawn_update()
		State.DEAD:                        _dead_update(delta)

	_fade_update()
	_update_timers(delta)
