extends Node3D

# The rig is a Node3D that sits at the player's position and rotates horizontally.
# The Camera3D is a child of the rig — it orbits with the rig and positions itself
# along the pitch/zoom arc. All camera movement goes through this node.


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Sprite height in pixels. Used to lift the rig pivot to sprite center
# so the camera orbits around the character's midpoint, not their feet.
const PLAYER_SPRITE_SIZE : int = 32


# ---------------------------------------------------------------------------
# External references
# ---------------------------------------------------------------------------

# Camera slot settings — controls sensitivity, invert flags, step sizes, etc.
var cam           : CameraSettings

# The player's physics body. Rig follows its position every frame.
var player_body   : CharacterBody3D

# The player sprite. Used to read pixel_size for sprite_half_h calculation
# and alpha for player fade when obstructed.
var player_sprite : AnimatedSprite3D

# The actual Camera3D node — child of this rig. Repositioned each frame by pitch/zoom.
var camera        : Camera3D


# ---------------------------------------------------------------------------
# Pivot offset
# ---------------------------------------------------------------------------

# Half the player sprite's world height. Added to the rig's Y position so
# the camera orbits around the sprite's center rather than the body's feet.
var sprite_half_h : float = 0.0


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

# True while the right mouse button is held. Gates orbit and pitch mouse input.
var rmb_held            : bool = false

# True when the mouse cursor is hovering over a UI panel.
# Blocks scroll zoom so UI scrolling doesn't accidentally zoom the camera.
var scroll_zoom_blocked : bool = false

# True when the player is inside a building or dungeon.
# Triggers apply_active_preset() to switch to the indoor pitch/zoom defaults.
var is_indoors          : bool = false


# =============================================================================
# ORBIT — horizontal rotation around the player (Y axis)
# =============================================================================

# Current horizontal rotation of the rig in radians. Written by orbit input,
# read by player.gd every frame for camera-relative WASD movement.
var h_angle : float = 0.0


# Called: _input().
# Rotates h_angle by horizontal mouse delta while RMB is held.
func _orbit_input_mouse(event: InputEventMouseMotion) -> void:

	if not rmb_held:
		return
	var dir : float = -1.0 if not cam.invert_orbit else 1.0
	h_angle += deg_to_rad(event.relative.x * cam.orbit_sens * dir)


# Called: _process().
# Rotates h_angle at a fixed speed per second while Q or E is held.
func _orbit_input_keys(delta: float) -> void:

	if not cam.qe_orbit_enabled:
		return
	var dir : float = -1.0 if not cam.invert_orbit else 1.0
	if Input.is_key_pressed(KEY_Q):
		h_angle += deg_to_rad(cam.orbit_key_speed * delta * dir)
	if Input.is_key_pressed(KEY_E):
		h_angle -= deg_to_rad(cam.orbit_key_speed * delta * dir)


# Called: _process().
# Applies h_angle to the rig's Y rotation — the camera follows as a child.
func _orbit_apply() -> void:

	rotation.y = h_angle


# =============================================================================
# PITCH — vertical tilt of the camera
# =============================================================================

# How fast v_angle lerps toward pitch_target per second.
# Higher = snappier pitch response. Lower = smoother but sluggish.
const PITCH_LERP : float = 8.0

# Current pitch angle in degrees (negative = tilted down). Lerps toward pitch_target.
var v_angle      : float = -30.0

# The pitch angle we're moving toward. Set by mouse drag or key press.
# v_angle chases this value each frame via lerp.
var pitch_target : float = -30.0

# Current discrete keyboard pitch step (0 = shallowest, PITCH_STEPS-1 = steepest).
# Kept in sync with pitch_target so keyboard and mouse pitch don't fight each other.
var pitch_step   : int   = 3


# Called: _pitch_input_mouse().
# Converts the current pitch_target float back to the nearest discrete step index.
# Keeps pitch_step in sync after a mouse drag so the next key press starts from
# the right step rather than jumping back to wherever pitch_step was before.
func _pitch_sync_step() -> void:

	pitch_step = roundi(
		(pitch_target - CameraSettings.PITCH_MAX) / (-CameraSettings.PITCH_STEP_VALUE))


# Called: _input().
# Adjusts pitch by vertical mouse delta while RMB is held.
# Clamps to the allowed pitch range and syncs the discrete step index.
func _pitch_input_mouse(event: InputEventMouseMotion) -> void:

	if not rmb_held or not cam.mouse_pitch_enabled:
		return
	var dir : float = -1.0 if not cam.invert_pitch else 1.0
	v_angle += event.relative.y * cam.pitch_sens * dir
	v_angle = clampf(v_angle, CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)

	# Keep pitch_target and pitch_step consistent with the new v_angle.
	pitch_target = v_angle
	_pitch_sync_step()


# Called: _input().
# Steps pitch up or down by one discrete step (direction: +1 = steeper, -1 = shallower).
# Calculates the exact float target from the step index so there's no drift over time.
func _pitch_input_key(direction: int) -> void:

	pitch_step   = clampi(pitch_step + direction, 0, CameraSettings.PITCH_STEPS - 1)
	pitch_target = CameraSettings.PITCH_MAX + pitch_step * (-CameraSettings.PITCH_STEP_VALUE)


# Called: init(), _process().
# Lerps v_angle toward pitch_target, then repositions the camera along the pitch arc.
# Passing delta=1.0 forces an instant snap (used in init() to avoid a startup lerp).
func _pitch_apply(delta: float) -> void:

	v_angle += (pitch_target - v_angle) * minf(delta * PITCH_LERP, 1.0)

	# Place the camera along the arc defined by pitch angle and zoom distance.
	# sin(pitch) = Y offset (height above rig), cos(pitch) = Z offset (distance behind rig).
	var pitch : float = deg_to_rad(-v_angle)
	camera.position           = Vector3(0.0, zoom_effective * sin(pitch), zoom_effective * cos(pitch))
	camera.rotation_degrees.x = v_angle


# =============================================================================
# ZOOM — camera distance from the player
# =============================================================================

# How fast zoom_dist lerps toward zoom_target per second.
const ZOOM_LERP : float = 12.0

# When a wall clips between the player and the camera, the camera snaps forward
# only if the wall is within this distance of the camera. Beyond CLIP_DIST the
# camera lerps back normally without snapping.
const CLIP_DIST : float = 4.0

# Current lerped zoom distance. Moves smoothly toward zoom_target each frame.
var zoom_dist      : float = 8.0

# The zoom distance we're moving toward. Set by scroll, pan gesture, or key press.
var zoom_target    : float = 8.0

# The zoom distance actually used to position the camera. Normally equals zoom_dist,
# but pulls in when a wall clips between the player and the camera (obstacle avoidance).
var zoom_effective : float = 8.0

# Current discrete keyboard zoom step (0 = closest, ZOOM_STEPS-1 = furthest).
# Kept in sync with zoom_target so keyboard and scroll zoom don't fight each other.
var zoom_step      : int   = 3


# Called: _zoom_input_scroll(), _zoom_input_pan().
# Converts the current zoom_target float back to the nearest discrete step index.
# Keeps zoom_step in sync after a scroll so the next key press starts from the right step.
func _zoom_sync_step() -> void:

	zoom_step = roundi((zoom_target - CameraSettings.ZOOM_MIN) / CameraSettings.ZOOM_STEP_VALUE)


# Called: _input().
# Adjusts zoom by mouse wheel scroll delta (Windows/Linux).
# Sensitivity is higher while RMB is held — faster zoom during active orbit.
func _zoom_input_scroll(scroll_dir: float) -> void:

	if not cam.mouse_zoom_enabled or scroll_zoom_blocked:
		return
	var sens : float = cam.zoom_sens_rmb if rmb_held else cam.zoom_sens
	var dir  : float = -1.0 if not cam.invert_zoom else 1.0
	zoom_target = clampf(zoom_target + scroll_dir * sens * dir,
		CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
	_zoom_sync_step()


# Called: _input().
# Adjusts zoom by trackpad pan gesture delta (macOS).
# Same logic as scroll — separate handler because Godot fires a different event type.
func _zoom_input_pan(event: InputEventPanGesture) -> void:

	if not cam.mouse_zoom_enabled or scroll_zoom_blocked:
		return
	var sens : float = cam.zoom_sens_rmb if rmb_held else cam.zoom_sens
	var dir  : float = -1.0 if not cam.invert_zoom else 1.0
	zoom_target = clampf(zoom_target + event.delta.y * sens * dir,
		CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
	_zoom_sync_step()


# Called: _input().
# Steps zoom in or out by one discrete step (direction: +1 = further, -1 = closer).
func _zoom_input_key(direction: int) -> void:

	zoom_step   = clampi(zoom_step + direction, 0, CameraSettings.ZOOM_STEPS - 1)
	zoom_target = CameraSettings.ZOOM_MIN + zoom_step * CameraSettings.ZOOM_STEP_VALUE


# Called: _process().
# Lerps zoom_dist toward zoom_target, then casts a ray from the rig to the desired
# camera position. If a wall is in the way AND it is within CLIP_DIST of the camera,
# zoom_effective snaps forward just in front of it to keep the player visible.
# If the wall is far from the camera, or there is no wall, zoom_effective lerps
# toward zoom_dist normally.
func _zoom_apply(delta: float) -> void:

	zoom_dist += (zoom_target - zoom_dist) * delta * ZOOM_LERP

	# Compute the desired camera world position from current pitch and zoom.
	var pitch         : float   = deg_to_rad(-v_angle)
	var desired_local : Vector3 = Vector3(0.0, zoom_dist * sin(pitch), zoom_dist * cos(pitch))
	var desired_world : Vector3 = global_transform * desired_local

	# Cast a ray from the rig pivot to the desired camera position.
	var space  : PhysicsDirectSpaceState3D   = get_world_3d().direct_space_state
	var params : PhysicsRayQueryParameters3D = \
		PhysicsRayQueryParameters3D.create(global_position, desired_world)
	params.exclude = [player_body.get_rid()]
	var result : Dictionary = space.intersect_ray(params)

	if result.is_empty():
		# Nothing between player and camera — lerp zoom_effective out to zoom_dist normally.
		zoom_effective += (zoom_dist - zoom_effective) * delta * ZOOM_LERP
	else:
		var hit_dist      : float = (result["position"] - global_position).length()
		var camera_to_obj : float = zoom_effective - hit_dist
		if camera_to_obj <= CLIP_DIST:
			# Wall is close to the camera — snap just in front of it so the player stays visible.
			# The small offsets prevent the camera from clipping inside the player model.
			zoom_effective = maxf(hit_dist - 0.3, 0.5)
		else:
			# Wall is far from the camera — lerp back out normally, no hard snap needed.
			zoom_effective += (zoom_dist - zoom_effective) * delta * ZOOM_LERP


# =============================================================================
# ENTRY POINTS
# =============================================================================

# Called: main._ready() after player and rig nodes are in the scene tree.
# Stores external references, computes sprite_half_h, creates the Camera3D child,
# and snaps to the active pitch/zoom preset instantly (delta=1.0 bypasses lerp).
func init(p_cam: CameraSettings, p_player_body: CharacterBody3D,
		p_player_sprite: AnimatedSprite3D) -> void:

	cam           = p_cam
	player_body   = p_player_body
	player_sprite = p_player_sprite

	# Lift the rig pivot to sprite center so orbit feels natural rather than floor-pivoting.
	sprite_half_h = PLAYER_SPRITE_SIZE * player_sprite.pixel_size * 0.5

	camera      = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)

	# delta=1.0 forces minf(1.0 * PITCH_LERP, 1.0) = 1.0 — instant snap, no startup lerp.
	_pitch_apply(1.0)


# Called: Godot engine (InputEvent).
# Routes all camera-relevant input events to the appropriate handler.
# +/- zoom; Shift++/- pitch; RMB held = orbit + pitch drag; scroll/pan = zoom.
func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				rmb_held = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_input_scroll(1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_input_scroll(-1.0)
	elif event is InputEventMouseMotion:
		_orbit_input_mouse(event)
		_pitch_input_mouse(event)
	elif event is InputEventPanGesture:
		# macOS trackpad pan — treated as scroll zoom.
		_zoom_input_pan(event)
	elif event is InputEventKey and event.pressed:
		var shift : bool = event.shift_pressed
		match event.keycode:
			KEY_MINUS:
				if shift: _pitch_input_key(1)
				else:     _zoom_input_key(1)
			KEY_EQUAL:
				if shift: _pitch_input_key(-1)
				else:     _zoom_input_key(-1)


# Called: Godot engine (every frame).
# Snaps the rig to the player, then applies all camera transforms in order:
# orbit → zoom (needs current pitch for ray) → pitch (repositions camera child).
func _process(delta: float) -> void:

	# Follow the player. Lift by sprite_half_h so orbit pivots at sprite center.
	position = player_body.position + Vector3(0.0, sprite_half_h, 0.0)

	_orbit_input_keys(delta)
	_orbit_apply()
	_zoom_apply(delta)
	_pitch_apply(delta)


# Called: Area transition system (future — triggered when player enters/exits a building).
# Applies the appropriate pitch and zoom defaults for indoor vs outdoor environments,
# then snaps all values instantly so there's no lerp on area transition.
func apply_active_preset() -> void:

	if is_indoors:
		pitch_step = cam.indoor_pitch_step
		zoom_step  = cam.indoor_zoom_step
	else:
		pitch_step = cam.outdoor_pitch_step
		zoom_step  = cam.outdoor_zoom_step

	pitch_target   = CameraSettings.PITCH_MAX + pitch_step * (-CameraSettings.PITCH_STEP_VALUE)
	zoom_target    = CameraSettings.ZOOM_MIN  + zoom_step  * CameraSettings.ZOOM_STEP_VALUE

	# Snap current values to target so the transition is instant.
	v_angle        = pitch_target
	zoom_dist      = zoom_target
	zoom_effective = zoom_target
