extends Node3D

# ---------------------------------------------------------------------------
# CameraRig — owns all camera state and input.
# Attach to a Node3D that acts as the pivot (camera orbits around it).
# Call init() once after adding to the scene tree.
# ---------------------------------------------------------------------------

const ZOOM_LERP           : float = 12.0  # lerp speed for zoom_dist toward zoom_target
const PITCH_LERP          : float = 8.0   # lerp speed for v_angle toward pitch_target
const PAN_MIN_DELTA_IN    : float = 1.5   # macOS trackpad: min delta to register a zoom-in
const PAN_MIN_DELTA_OUT   : float = 0.9   # macOS trackpad: min delta to register a zoom-out
const PLAYER_WORLD_HEIGHT : float = 3.0   # 96px sprite * (1.0/32) px-per-unit
const PLAYER_FADE_START   : float = 5.0   # zoom_effective below this starts fading the player sprite
const PLAYER_FADE_FULL    : float = 2.0   # zoom_effective at or below this = fully faded
const CLIP_DIST           : float = 4.0   # obstacle clips camera in if within this many units of the camera

# Assigned by main.gd via init()
var cam           : CameraSettings   # user settings (zoom/pitch/orbit prefs, saved to disk)
var player_body   : CharacterBody3D  # physics body the rig follows each frame
var player_sprite : AnimatedSprite3D # sprite used for pixel_size and player fade

# Camera node (child, built in init)
var camera : Camera3D  # the actual camera — positioned relative to the rig pivot

# Horizontal orbit angle in radians — rotates the whole rig around Y axis
var h_angle : float = 0.0
# Current actual pitch in degrees — lerps toward pitch_target each frame
var v_angle : float = -30.0
# Desired pitch in degrees — set by mouse drag or keyboard step, v_angle lerps toward it
var pitch_target : float = -30.0
# Current discrete zoom step index (0 = closest, ZOOM_STEPS-1 = farthest)
var zoom_step : int = 3
# Desired zoom distance — set by scroll/keyboard, zoom_dist lerps toward it
var zoom_target : float = 8.0
# Current lerped zoom distance — follows zoom_target smoothly
var zoom_dist : float = 8.0
# Actual camera distance after collision — snaps in on hit, lerps back out when clear
var zoom_effective : float = 8.0
# True while right mouse button is held — enables orbit drag and pitch drag
var rmb_held : bool = false
# True while left mouse button is held — reserved for future use
var lmb_held : bool = false
# Debug counter — increments on every scroll/pan event
var dbg_scroll : int = 0

# Blocks scroll zoom when the mouse is over a UI panel — set by main.gd each frame
var scroll_zoom_blocked : bool = false
# Switches between outdoor and indoor camera presets — set by main.gd on zone change
var is_indoors : bool = false


# ---------------------------------------------------------------------------
# ZOOM / PITCH HELPERS
# ---------------------------------------------------------------------------

# Called: _on_mouse_button(), _on_pan_gesture().
func _zoom_sync_step() -> void:

	# Mouse scroll changes zoom_target as a continuous float (e.g. 8.73).
	# Keyboard zoom uses discrete integer steps (0-10).
	# This converts zoom_target back to the nearest step so keyboard picks up cleanly.
	# e.g. zoom_target=8.73 → offset 3.73 → fraction 0.373 → step 3.73 → round → step 4
	# zoom_target will always be between ZOOM_MIN and ZOOM_MAX (no clamp needed).
	zoom_step = roundi(
		(zoom_target - CameraSettings.ZOOM_MIN) /       # offset from min (e.g. 3.73)
		(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) *   # divide by full range → 0.0-1.0 fraction
		float(CameraSettings.ZOOM_STEPS - 1))                   # scale fraction to step count


# Called: _on_key().
func _zoom_by_step(direction: int) -> void:

	# Move one step in the given direction (+1 zoom out, -1 zoom in).
	# Clamped so boundary presses (step 0 - 1, step 10 + 1) don't go out of range.
	zoom_step = clampi(zoom_step + direction, 0, CameraSettings.ZOOM_STEPS - 1)
	# Convert the new step index back to a zoom_target float for the lerp to follow.
	zoom_target = CameraSettings.ZOOM_MIN + zoom_step * \
		(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) / float(CameraSettings.ZOOM_STEPS - 1)


# Called: _on_mouse_motion().
func _pitch_by_delta(delta_deg: float) -> void:

	# Both v_angle and pitch_target shift by the same amount — drag is immediate,
	# not a lerp target. Moving only pitch_target would make the camera feel laggy.
	# Clamped to keep pitch within the allowed range (PITCH_MIN to PITCH_MAX).
	v_angle      = clampf(v_angle      + delta_deg, CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)
	pitch_target = clampf(pitch_target + delta_deg, CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)


# Called: _on_key().
func _pitch_by_step(direction: int) -> void:

	pitch_target = clampf(pitch_target + direction * CameraSettings.PITCH_STEP,
		CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)


# ---------------------------------------------------------------------------
# CAMERA UPDATE — smooth zoom + two-ray collision
# ---------------------------------------------------------------------------

# Called: _process().
func _update_camera(delta: float) -> void:

	zoom_dist += (zoom_target - zoom_dist) * minf(delta * ZOOM_LERP, 1.0)

	var pitch         : float   = deg_to_rad(-v_angle)
	var desired_local : Vector3 = Vector3(0.0, zoom_dist * sin(pitch), zoom_dist * cos(pitch))
	var desired_world : Vector3 = global_transform * desired_local

	var space  : PhysicsDirectSpaceState3D   = get_world_3d().direct_space_state
	var params : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position, desired_world)
	params.exclude = [player_body.get_rid()]
	var result : Dictionary = space.intersect_ray(params)

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

	camera.position           = Vector3(0.0, zoom_effective * sin(pitch), zoom_effective * cos(pitch))
	camera.rotation_degrees.x = v_angle


# ---------------------------------------------------------------------------
# PLAYER FADE — fade sprite when camera collision forces it close
# ---------------------------------------------------------------------------

# Called: _process().
func _update_player_fade(delta: float) -> void:

	var target_alpha : float
	if zoom_effective >= PLAYER_FADE_START:
		target_alpha = 1.0
	else:
		var t : float = (PLAYER_FADE_START - zoom_effective) / (PLAYER_FADE_START - PLAYER_FADE_FULL)
		t = clampf(t, 0.0, 1.0)
		var min_alpha : float = cam.player_fade_alpha / 255.0
		target_alpha = lerpf(1.0, min_alpha, t)
	player_sprite.modulate.a = move_toward(player_sprite.modulate.a, target_alpha, delta * 5.0)


# ---------------------------------------------------------------------------
# INPUT HANDLERS
# ---------------------------------------------------------------------------

# Called: _input().
func _on_mouse_button(event: InputEventMouseButton) -> void:

	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			rmb_held = event.pressed
			if not rmb_held:
				# Snap zoom_step so keyboard zoom starts from the correct position
				_zoom_sync_step()
		MOUSE_BUTTON_LEFT:
			lmb_held = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if cam.mouse_zoom_enabled and not scroll_zoom_blocked:
				var zoom_dir : float = 1.0 if not cam.invert_zoom else -1.0
				dbg_scroll += 1
				zoom_target = clampf(zoom_target - cam.zoom_sens * 10.0 * zoom_dir,
					CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
				_zoom_sync_step()
		MOUSE_BUTTON_WHEEL_DOWN:
			if cam.mouse_zoom_enabled and not scroll_zoom_blocked:
				var zoom_dir : float = 1.0 if not cam.invert_zoom else -1.0
				dbg_scroll += 1
				zoom_target = clampf(zoom_target + cam.zoom_sens * 10.0 * zoom_dir,
					CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
				_zoom_sync_step()


# Called: _input().
func _on_pan_gesture(event: InputEventPanGesture) -> void:

	if not cam.mouse_zoom_enabled or scroll_zoom_blocked:
		return
	if event.delta.y >= PAN_MIN_DELTA_OUT or event.delta.y <= -PAN_MIN_DELTA_IN:
		var zoom_dir : float = 1.0 if not cam.invert_zoom else -1.0
		dbg_scroll += 1
		zoom_target = clampf(zoom_target + event.delta.y * cam.zoom_sens * zoom_dir,
			CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
		_zoom_sync_step()


# Called: _input().
func _on_mouse_motion(event: InputEventMouseMotion) -> void:

	if not rmb_held:
		return
	var orbit_dir : float = -1.0 if not cam.invert_orbit else 1.0
	h_angle += deg_to_rad(event.relative.x * cam.orbit_sens * orbit_dir)
	if cam.mouse_pitch_enabled:
		var pitch_dir : float = 1.0 if not cam.invert_pitch else -1.0
		_pitch_by_delta(event.relative.y * cam.pitch_sens * pitch_dir)


# Called: _input().
func _on_key(event: InputEventKey) -> void:

	if not event.pressed:
		return
	var shift : bool = event.shift_pressed
	match event.keycode:
		KEY_MINUS:
			if shift: _pitch_by_step(-1)
			else:     _zoom_by_step(1)
		KEY_EQUAL:
			if shift: _pitch_by_step(1)
			else:     _zoom_by_step(-1)


# ---------------------------------------------------------------------------
# PRESET HELPERS
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# ENTRY POINTS
# ---------------------------------------------------------------------------

# Called: main._build_camera_rig().
func init(p_cam: CameraSettings, p_player_body: CharacterBody3D,
		p_player_sprite: AnimatedSprite3D) -> void:

	cam           = p_cam
	player_body   = p_player_body
	player_sprite = p_player_sprite

	camera = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)
	var pitch : float = deg_to_rad(-v_angle)
	camera.position = Vector3(0.0, zoom_dist * sin(pitch), zoom_dist * cos(pitch))
	camera.rotation_degrees.x = v_angle


# Called: Godot engine (InputEvent).
func _input(event: InputEvent) -> void:

	if   event is InputEventMouseButton: _on_mouse_button(event)
	elif event is InputEventPanGesture:  _on_pan_gesture(event)
	elif event is InputEventMouseMotion: _on_mouse_motion(event)
	elif event is InputEventKey:         _on_key(event)


# Called: Godot engine (every frame).
func _process(delta: float) -> void:

	# Keep pivot centered at player sprite midpoint
	var pixel_size    : float = player_sprite.pixel_size
	var sprite_half_h : float = 96.0 * pixel_size * 0.5   # PLAYER_SPRITE_SIZE = 96
	position = player_body.position + Vector3(0.0, sprite_half_h, 0.0)

	# Q/E held orbit
	if cam.qe_orbit_enabled:
		if Input.is_key_pressed(KEY_Q):
			h_angle += deg_to_rad(cam.orbit_key_speed * delta)
		if Input.is_key_pressed(KEY_E):
			h_angle -= deg_to_rad(cam.orbit_key_speed * delta)

	# Lerp v_angle toward pitch_target (keyboard steps land smoothly)
	v_angle += (pitch_target - v_angle) * minf(delta * PITCH_LERP, 1.0)

	rotation.y = h_angle
	_update_camera(delta)
	_update_player_fade(delta)


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
