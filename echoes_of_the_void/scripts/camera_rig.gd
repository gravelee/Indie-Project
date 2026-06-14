extends Node3D

# ---------------------------------------------------------------------------
# CameraRig — owns all camera state and input.
# Attach to a Node3D that acts as the pivot (camera orbits around it).
# Call init() once after adding to the scene tree.
#
# Four independent systems, each with its own input + apply:
#   ORBIT  — horizontal rotation around player (h_angle)
#   PITCH  — vertical tilt of the camera (v_angle → pitch_target)
#   ZOOM   — camera distance from player (zoom_target → zoom_dist → zoom_effective)
#   FADE   — player sprite transparency when camera is forced close
# ---------------------------------------------------------------------------

const PLAYER_WORLD_HEIGHT  : float = 3.0   # 96px sprite * (1.0/32) px-per-unit
const PLAYER_SPRITE_SIZE   : int   = 96    # entity sprite height in pixels (3 tiles × 32px)

# Assigned by main.gd via init()
var cam           : CameraSettings   # user settings (zoom/pitch/orbit prefs, saved to disk)
var player_body   : CharacterBody3D  # physics body the rig follows each frame
var player_sprite : AnimatedSprite3D # sprite used for pixel_size and player fade

# Camera node (child, built in init)
var camera : Camera3D  # the actual camera — positioned relative to the rig pivot

var sprite_half_h : float = 0.0  # cached: half player sprite world height — pivot lifted to sprite center

# Flags
var rmb_held         : bool = false  # true while RMB held — enables orbit + pitch drag
var lmb_held         : bool = false  # true while LMB held — reserved for future use
var scroll_zoom_blocked : bool = false  # blocks scroll zoom when mouse is over a UI panel
var is_indoors       : bool = false  # switches between outdoor/indoor presets on zone change


# =============================================================================
# ORBIT — horizontal rotation of the camera around the player
#
# One variable: h_angle (radians). No lerp — orbit is always immediate.
# Input:  RMB drag (horizontal) → h_angle
#         Q / E keys held       → h_angle
# Apply:  rotation.y = h_angle  (whole rig rotates, camera orbits as child)
# =============================================================================

var h_angle : float = 0.0  # current orbit angle in radians


# Called: _input().
func _orbit_input_mouse(event: InputEventMouseMotion) -> void:

	if not rmb_held:
		return
	var dir : float = -1.0 if not cam.invert_orbit else 1.0
	h_angle += deg_to_rad(event.relative.x * cam.orbit_sens * dir)


# Called: _process().
func _orbit_input_keys(delta: float) -> void:

	if not cam.qe_orbit_enabled:
		return
	if Input.is_key_pressed(KEY_Q):
		h_angle += deg_to_rad(cam.orbit_key_speed * delta)
	if Input.is_key_pressed(KEY_E):
		h_angle -= deg_to_rad(cam.orbit_key_speed * delta)


# Called: _process().
func _orbit_apply() -> void:

	rotation.y = h_angle


# =============================================================================
# PITCH — vertical tilt of the camera (how steeply it looks down)
#
# Two variables: pitch_target (desired) and v_angle (current, lerps toward target).
# Mouse drag moves both together (immediate — no lag during drag).
# Keyboard steps only move pitch_target (v_angle lerps smoothly to it).
# Input:  RMB drag (vertical) → pitch_target + v_angle (both, immediate)
#         Shift+- / Shift+=   → pitch_target only (v_angle lerps)
# Apply:  v_angle lerps toward pitch_target each frame
# =============================================================================

const PITCH_LERP : float = 8.0  # lerp speed for v_angle toward pitch_target

var v_angle      : float = -30.0  # current actual pitch in degrees
var pitch_target : float = -30.0  # desired pitch — v_angle lerps toward this


# Called: _input().
func _pitch_input_mouse(event: InputEventMouseMotion) -> void:

	if not rmb_held or not cam.mouse_pitch_enabled:
		return
	var dir : float = 1.0 if not cam.invert_pitch else -1.0
	# Both shift together — drag is immediate, not a lerp target.
	# Moving only pitch_target would make the camera feel laggy during drag.
	# Clamp both to keep pitch within allowed range.
	var delta_deg : float = event.relative.y * cam.pitch_sens * dir
	v_angle      = clampf(v_angle      + delta_deg, CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)
	pitch_target = clampf(pitch_target + delta_deg, CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)


# Called: _on_key().
func _pitch_input_key(direction: int) -> void:

	# Only pitch_target moves — v_angle lerps toward it for a smooth step feel.
	pitch_target = clampf(pitch_target + direction * CameraSettings.PITCH_STEP,
		CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)


# Called: _process().
func _pitch_apply(delta: float) -> void:

	v_angle += (pitch_target - v_angle) * minf(delta * PITCH_LERP, 1.0)


# =============================================================================
# ZOOM — camera distance from the player
#
# Three variables in a chain:
#   zoom_step   → integer index (0–10), used by keyboard steps
#   zoom_target → float distance, set by all input — zoom_dist lerps toward it
#   zoom_dist   → lerped distance, follows zoom_target smoothly
#   zoom_effective → actual camera distance after collision clip
#
# Input:  scroll wheel / trackpad → zoom_target (continuous float)
#         - / = keys             → zoom_step → zoom_target (discrete steps)
# Apply:  zoom_dist lerps toward zoom_target
#         ray cast checks for obstacles → zoom_effective snaps in / lerps out
#         camera.position set from zoom_effective + pitch
# =============================================================================

const ZOOM_LERP         : float = 12.0  # lerp speed for zoom_dist toward zoom_target
const CLIP_DIST         : float = 4.0   # obstacle clips camera in if within this many units of the camera
const PAN_MIN_DELTA_IN  : float = 1.5   # macOS trackpad: min delta to register a zoom-in
const PAN_MIN_DELTA_OUT : float = 0.9   # macOS trackpad: min delta to register a zoom-out

var zoom_step      : int   = 3    # current discrete step index (0 = closest, ZOOM_STEPS-1 = farthest)
var zoom_target    : float = 8.0  # desired zoom distance — set by scroll/keyboard
var zoom_dist      : float = 8.0  # current lerped zoom distance — follows zoom_target smoothly
var zoom_effective : float = 8.0  # actual camera distance after collision clip
var dbg_scroll     : int   = 0    # debug counter — increments on every scroll/pan event


# Called: _input() on wheel events, _zoom_input_pan().
# Mouse scroll changes zoom_target as a continuous float (e.g. 8.73).
# Keyboard zoom uses discrete integer steps (0-10).
# This converts zoom_target back to the nearest step so keyboard picks up cleanly.
# e.g. zoom_target=8.73 → offset 3.73 → fraction 0.373 → step 3.73 → round → step 4
# zoom_target will always be between ZOOM_MIN and ZOOM_MAX (no clamp needed).
func _zoom_sync_step() -> void:

	zoom_step = roundi(
		(zoom_target - CameraSettings.ZOOM_MIN) /             # offset from min (e.g. 3.73)
		(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) * # divide by full range → 0.0-1.0 fraction
		float(CameraSettings.ZOOM_STEPS - 1))                 # scale fraction to step count


# Called: _input() on wheel events.
func _zoom_input_scroll(delta: float) -> void:

	if not cam.mouse_zoom_enabled or scroll_zoom_blocked:
		return
	var dir : float = 1.0 if not cam.invert_zoom else -1.0
	dbg_scroll += 1
	zoom_target = clampf(zoom_target + delta * cam.zoom_sens * 10.0 * dir,
		CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
	_zoom_sync_step()


# Called: _on_pan_gesture().
func _zoom_input_pan(event: InputEventPanGesture) -> void:

	if not cam.mouse_zoom_enabled or scroll_zoom_blocked:
		return
	if event.delta.y >= PAN_MIN_DELTA_OUT or event.delta.y <= -PAN_MIN_DELTA_IN:
		var dir : float = 1.0 if not cam.invert_zoom else -1.0
		dbg_scroll += 1
		zoom_target = clampf(zoom_target + event.delta.y * cam.zoom_sens * dir,
			CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
		_zoom_sync_step()


# Called: _on_key().
# Move one step in the given direction (+1 zoom out, -1 zoom in).
# Clamped so boundary presses (step 0 - 1, step 10 + 1) don't go out of range.
func _zoom_input_key(direction: int) -> void:

	zoom_step = clampi(zoom_step + direction, 0, CameraSettings.ZOOM_STEPS - 1)
	# Convert the new step index back to a zoom_target float for the lerp to follow.
	zoom_target = CameraSettings.ZOOM_MIN + zoom_step * \
		(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) / float(CameraSettings.ZOOM_STEPS - 1)


# Called: _process().
func _zoom_apply(delta: float) -> void:

	# Lerp zoom_dist toward zoom_target
	zoom_dist += (zoom_target - zoom_dist) * minf(delta * ZOOM_LERP, 1.0)

	# Compute desired camera world position from current zoom_dist + pitch
	var pitch         : float   = deg_to_rad(-v_angle)
	var desired_local : Vector3 = Vector3(0.0, zoom_dist * sin(pitch), zoom_dist * cos(pitch))
	var desired_world : Vector3 = global_transform * desired_local

	# Ray from pivot toward desired camera position — check for obstacles
	var space  : PhysicsDirectSpaceState3D   = get_world_3d().direct_space_state
	var params : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position, desired_world)
	params.exclude = [player_body.get_rid()]
	var result : Dictionary = space.intersect_ray(params)

	# Clip camera in if obstacle is close enough to the camera to fill a large part of the view.
	# obstacle far from camera (close to player) = small screen coverage = no clip.
	# obstacle close to camera                   = large screen coverage = clip in.
	var raw_effective : float = zoom_dist
	if not result.is_empty():
		var hit_dist      : float = (result["position"] - global_position).length()
		var camera_to_obj : float = zoom_effective - hit_dist
		if camera_to_obj <= CLIP_DIST:
			raw_effective = maxf(hit_dist - 0.3, 0.5)

	# Snap in immediately on collision, lerp smoothly back out when clear
	if raw_effective < zoom_effective:
		zoom_effective = raw_effective
	else:
		zoom_effective += (raw_effective - zoom_effective) * minf(delta * ZOOM_LERP, 1.0)

	# Position camera from zoom_effective (collision-clipped) not zoom_dist
	camera.position           = Vector3(0.0, zoom_effective * sin(pitch), zoom_effective * cos(pitch))
	camera.rotation_degrees.x = v_angle


# =============================================================================
# FADE — fade player sprite when camera collision forces it too close
#
# Reads zoom_effective. Below PLAYER_FADE_START, sprite alpha drops toward
# a minimum (cam.player_fade_alpha). At PLAYER_FADE_FULL it is fully faded.
# =============================================================================

const PLAYER_FADE_START : float = 5.0  # zoom_effective below this starts fading the player sprite
const PLAYER_FADE_FULL  : float = 2.0  # zoom_effective at or below this = fully faded


# Called: _process().
func _fade_apply(delta: float) -> void:

	var target_alpha : float
	if zoom_effective >= PLAYER_FADE_START:
		target_alpha = 1.0
	else:
		var t : float = (PLAYER_FADE_START - zoom_effective) / (PLAYER_FADE_START - PLAYER_FADE_FULL)
		t = clampf(t, 0.0, 1.0)
		var min_alpha : float = cam.player_fade_alpha / 255.0
		target_alpha = lerpf(1.0, min_alpha, t)
	player_sprite.modulate.a = move_toward(player_sprite.modulate.a, target_alpha, delta * 5.0)


# =============================================================================
# PRESET HELPERS
# =============================================================================

# Called: apply_active_preset(), game_ui (settings panel save).
func apply_outdoor_preset(zoom_s: int, pitch: float) -> void:

	if not is_indoors:
		zoom_step    = zoom_s
		zoom_target  = CameraSettings.ZOOM_MIN + zoom_step * \
			(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) / float(CameraSettings.ZOOM_STEPS - 1)
		pitch_target = pitch


# Called: apply_active_preset(), game_ui (settings panel save).
func apply_indoor_preset(zoom_s: int, pitch: float) -> void:

	if is_indoors:
		zoom_step    = zoom_s
		zoom_target  = CameraSettings.ZOOM_MIN + zoom_step * \
			(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) / float(CameraSettings.ZOOM_STEPS - 1)
		pitch_target = pitch


# =============================================================================
# ENTRY POINTS
# =============================================================================

# Called: main._build_camera_rig().
func init(p_cam: CameraSettings, p_player_body: CharacterBody3D,
		p_player_sprite: AnimatedSprite3D) -> void:

	cam           = p_cam
	player_body   = p_player_body
	player_sprite = p_player_sprite
	sprite_half_h = PLAYER_SPRITE_SIZE * player_sprite.pixel_size * 0.5

	camera = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)
	var pitch : float = deg_to_rad(-v_angle)
	camera.position = Vector3(0.0, zoom_dist * sin(pitch), zoom_dist * cos(pitch))
	camera.rotation_degrees.x = v_angle


# Called: Godot engine (InputEvent).
func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				rmb_held = event.pressed
				if not rmb_held:
					_zoom_sync_step()  # snap step so keyboard zoom starts from correct position
			MOUSE_BUTTON_LEFT:
				lmb_held = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_input_scroll(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_input_scroll(1.0)
	elif event is InputEventPanGesture:
		_zoom_input_pan(event)
	elif event is InputEventMouseMotion:
		_orbit_input_mouse(event)
		_pitch_input_mouse(event)
	elif event is InputEventKey and event.pressed:
		var shift : bool = event.shift_pressed
		match event.keycode:
			KEY_MINUS:
				if shift: _pitch_input_key(-1)
				else:     _zoom_input_key(1)
			KEY_EQUAL:
				if shift: _pitch_input_key(1)
				else:     _zoom_input_key(-1)


# Called: Godot engine (every frame).
func _process(delta: float) -> void:

	# Follow player (center)
	position = player_body.position + Vector3(0.0, sprite_half_h, 0.0)

	# Run all four systems
	_orbit_input_keys(delta)
	_orbit_apply()
	_pitch_apply(delta)
	_zoom_apply(delta)
	_fade_apply(delta)


# Called: main._build_camera_rig(), game_ui (on is_indoors toggle).
func apply_active_preset() -> void:

	if is_indoors:
		apply_indoor_preset(cam.indoor_zoom_step, cam.indoor_pitch)
	else:
		apply_outdoor_preset(cam.outdoor_zoom_step, cam.outdoor_pitch)
	# Snap lerp state so the camera starts at the correct position immediately
	v_angle        = pitch_target
	zoom_dist      = zoom_target
	zoom_effective = zoom_target
