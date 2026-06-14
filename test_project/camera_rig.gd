extends Node3D

const PLAYER_SPRITE_SIZE : int = 32 # Future change to var if player sprite changes size.

var cam           : CameraSettings # Camera slot settings (memory file).
var player_body   : CharacterBody3D # Needed for rig position and by extension for camera position.
var player_sprite : AnimatedSprite3D # Used for pixel_size and player fade.
var camera        : Camera3D # The actual camera — child of the rig, orbits with it.

var sprite_half_h : float = 0.0 # Half player sprite world height — lifts pivot to sprite center.

var rmb_held            : bool = false # True when player holds the right mouse button.
var scroll_zoom_blocked : bool = false # True when mouse hovers over a UI panel.
var is_indoors          : bool = false # True when player is in indoors space.


# =============================================================================
# ORBIT
# =============================================================================

var h_angle : float = 0.0 # Rotates the rig (along with camera) around the vertical (y) axis.


# Called: _input().
func _orbit_input_mouse(event: InputEventMouseMotion) -> void:
	
	# If rmb held then based on the settings invert_orbit value we rotate the 
	# camera by the rotation sensitivity setting multiplied by the horizontal 
	# mouse movement (delta per event).
	
	if not rmb_held:
		return
	var dir : float = -1.0 if not cam.invert_orbit else 1.0
	h_angle += deg_to_rad(event.relative.x * cam.orbit_sens * dir)


# Called: _process().
func _orbit_input_keys(delta: float) -> void:
	
	# If Q or E keyboard buttons are clicked and also are enabled via camera settings
	# then based on the settings invert_orbit value we rotate the camera by settings
	# orbit_key_speed.
	
	if not cam.qe_orbit_enabled:
		return
	var dir : float = -1.0 if not cam.invert_orbit else 1.0
	if Input.is_key_pressed(KEY_Q):
		h_angle += deg_to_rad(cam.orbit_key_speed * delta * dir)
	if Input.is_key_pressed(KEY_E):
		h_angle -= deg_to_rad(cam.orbit_key_speed * delta * dir)


# Called: _process().
func _orbit_apply() -> void:
	
	# We apply the rotation angle to the node.
	
	rotation.y = h_angle


# =============================================================================
# PITCH
# =============================================================================

const PITCH_LERP : float = 8.0

var v_angle      : float = -30.0
var pitch_target : float = -30.0

var pitch_step   : int   = 3


# Called: _pitch_input_mouse().
func _pitch_sync_step() -> void:
	
	# Conversion between the discrete keyboard pitch steps and the float pitch 
	# target values. Keeps pitch steps in sync with pitch_target floating point value.
	pitch_step = roundi(
		(pitch_target - CameraSettings.PITCH_MAX) / (-CameraSettings.PITCH_STEP_VALUE))


# Called: _input().
func _pitch_input_mouse(event: InputEventMouseMotion) -> void:
	
	# If rmb held and mouse_pitch_enabled then based on the settings invert_pitch 
	# value we pitch the camera by the pitch sensitivity setting multiplied by 
	# the vertical mouse movement (delta per event).
	
	if not rmb_held or not cam.mouse_pitch_enabled:
		return
	var dir : float = -1.0 if not cam.invert_pitch else 1.0
	v_angle += event.relative.y * cam.pitch_sens * dir
	v_angle = clampf(v_angle, CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)
	
	# Consistency between v_angle and pitch_target and pitch_step.
	pitch_target = v_angle
	_pitch_sync_step()


# Called: _input().
func _pitch_input_key(direction: int) -> void:
	
	# Calculate the new pitch_step within the apropriate range and then sets the
	# pitch_target to the actual step distance.
	
	pitch_step = clampi(pitch_step + direction, 0, CameraSettings.PITCH_STEPS - 1)
	pitch_target = CameraSettings.PITCH_MAX + pitch_step * (-CameraSettings.PITCH_STEP_VALUE)


# Called: init(), _process().
func _pitch_apply(delta: float) -> void:
	
	# We lerp v_angle towards pitch_target per frame based on their distance 
	# value and the pitch lerp value.
	
	v_angle += (pitch_target - v_angle) * minf(delta * PITCH_LERP, 1.0)
	
	# We reposition the camera based on the new pitch and zoom values and apply 
	# the pitch angle to the camera.
	
	var pitch : float = deg_to_rad(-v_angle)
	camera.position = Vector3(0.0, zoom_effective * sin(pitch), zoom_effective * cos(pitch))
	camera.rotation_degrees.x = v_angle


# =============================================================================
# ZOOM
# =============================================================================

const ZOOM_LERP    : float = 12.0
const CLIP_DIST    : float = 4.0

var zoom_dist      : float = 8.0
var zoom_target    : float = 8.0
var zoom_effective : float = 8.0
var zoom_step      : int   = 3


# Called: _zoom_input_scroll(), _zoom_input_pan().
func _zoom_sync_step() -> void:
	
	# Conversion between the discrete keyboard zoom steps and the float zoom  
	# target values. Keeps zoom steps in sync with zoom_target floating point value.
	zoom_step = roundi((zoom_target - CameraSettings.ZOOM_MIN) / CameraSettings.ZOOM_STEP_VALUE)


# Called: _input().
func _zoom_input_scroll(scroll_dir: float) -> void:
	
	# Windows mouse wheel handle.
	# If mouse_zoom_enabled or not scroll_zoom_blocked then based on the settings 
	# invert_zoom value we zoom the camera by the zoom sensitivity setting multiplied 
	# by the wheel movement direction.
	
	if not cam.mouse_zoom_enabled or scroll_zoom_blocked:
		return
	var sens : float = cam.zoom_sens_rmb if rmb_held else cam.zoom_sens
	var dir : float = -1.0 if not cam.invert_zoom else 1.0
	zoom_target += scroll_dir * sens * dir
	zoom_target = clampf(zoom_target, CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
	
	# Consistency between zoom_target and zoom_step.
	_zoom_sync_step()


# Called: _input().
func _zoom_input_pan(event: InputEventPanGesture) -> void:
	
	# MacOS trackpad pan gesture handle.
	# If mouse_zoom_enabled or not scroll_zoom_blocked then based on the settings 
	# invert_zoom value we zoom the camera by the zoom sensitivity setting multiplied 
	# by the wheel movement direction.
	
	if not cam.mouse_zoom_enabled or scroll_zoom_blocked:
		return
	var sens : float = cam.zoom_sens_rmb if rmb_held else cam.zoom_sens
	var dir : float = -1.0 if not cam.invert_zoom else 1.0
	zoom_target += event.delta.y * sens * dir
	zoom_target = clampf(zoom_target, CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
	
	# Consistency between zoom_target and zoom_step.
	_zoom_sync_step()


# Called: _input().
func _zoom_input_key(direction: int) -> void:
	
	# Calculate the new zoom_step within the apropriate range and then sets the
	# zoom_target to the actual step distance.
	
	zoom_step = clampi(zoom_step + direction, 0, CameraSettings.ZOOM_STEPS - 1)
	zoom_target = CameraSettings.ZOOM_MIN + zoom_step * CameraSettings.ZOOM_STEP_VALUE


# Called: _process().
func _zoom_apply(delta: float) -> void:
	
	# We lerp zoom_dist towards zoom_target per frame based on their distance 
	# value and the zoom lerp value.
	
	zoom_dist += (zoom_target - zoom_dist) * delta * ZOOM_LERP
	
	# We cast a ray from the rig to the cameras world position and if no 
	# collision is found we lerp zoom_effective towards zoom_dist per frame 
	# based on their distance value and the zoom lerp value. If there is an
	# object found in between then if that object is far from the camera then we
	# again lerp zoom_effective towards zoom_dist. But if the object is too close
	# we set the camera just in front of the object to clearly see the player.
	
	var pitch : float = deg_to_rad(-v_angle)
	var desired_local : Vector3 = Vector3(0.0, zoom_dist * sin(pitch), zoom_dist * cos(pitch))
	var desired_world : Vector3 = global_transform * desired_local
	var space  : PhysicsDirectSpaceState3D   = get_world_3d().direct_space_state
	# Sets up the rays starting and ending position.
	var params : PhysicsRayQueryParameters3D = \
		PhysicsRayQueryParameters3D.create(global_position, desired_world)
	# Exclude the player body from the ray cast collision dict.
	params.exclude = [player_body.get_rid()] 
	# Casts the ray from the rig to the cameras world position and collects all 
	# results in a dict.
	var result : Dictionary = space.intersect_ray(params)
	
	# If no objects found between the camera and the player we lerp zoom_effective
	# towards zoom_dist.
	if result.is_empty():
		zoom_effective += (zoom_dist - zoom_effective) * delta * ZOOM_LERP
	# If an object is found.
	else:
		var hit_dist      : float = (result["position"] - global_position).length()
		var camera_to_obj : float = zoom_effective - hit_dist
		# If object close to the camera.
		if camera_to_obj <= CLIP_DIST:
			# Sets zoom_effective just in front of the obstacle, those magic
			# numbers prevents the camera from going inside the player.
			zoom_effective = maxf(hit_dist - 0.3, 0.5)
		# Object far from the camera.
		else:
			# No clip needed, lerp back out normally.
			zoom_effective += (zoom_dist - zoom_effective) * delta * ZOOM_LERP


# =============================================================================
# ENTRY POINTS
# =============================================================================

# Called: main._build_camera_rig().
func init(p_cam: CameraSettings, p_player_body: CharacterBody3D, 
	p_player_sprite: AnimatedSprite3D) -> void:
	
	# Inits the basic vars and creates the actual camera putting it behind the 
	# player placeholder at a height with an angle (pitch value).
	
	cam = p_cam
	player_body = p_player_body
	player_sprite = p_player_sprite
	
	sprite_half_h = PLAYER_SPRITE_SIZE * player_sprite.pixel_size * 0.5
	
	camera = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)
	
	# Pass delta parameter value of 1.0 to force instant snap.
	_pitch_apply(1.0)


# Called: Godot engine (InputEvent).
func _input(event: InputEvent) -> void:
	
	# Reads any player input event from the keyboard or the mouse and sets the rigs vars.
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				rmb_held = event.pressed
			# windows mouse wheel handle.
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_input_scroll(1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_input_scroll(-1.0)
	elif event is InputEventMouseMotion:
		_orbit_input_mouse(event)
		_pitch_input_mouse(event)
	# macos mouse wheel handle.
	elif event is InputEventPanGesture:
		_zoom_input_pan(event)
	elif event is InputEventKey and event.pressed:
		var shift : bool = event.shift_pressed
		match event.keycode:
			KEY_MINUS:
				if shift:
					_pitch_input_key(1)
				else:
					_zoom_input_key(1)
			KEY_EQUAL:
				if shift:
					_pitch_input_key(-1)
				else:
					_zoom_input_key(-1)


# Called: Godot engine (every frame).
func _process(delta: float) -> void:
	
	# Rig follows the player body and reads and applies any player input 
	# (rotation/pitch/zoom) from keyboard or the mouse.
	
	position = player_body.position + Vector3(0.0, sprite_half_h, 0.0)
	_orbit_input_keys(delta)
	_orbit_apply()
	_zoom_apply(delta)
	_pitch_apply(delta)


# Called: area transition system (future).
func apply_active_preset() -> void:
	
	# We set the apropriate pitch and zoom step values.
	if is_indoors:
		pitch_step = cam.indoor_pitch_step
		zoom_step = cam.indoor_zoom_step
	else:
		pitch_step = cam.outdoor_pitch_step
		zoom_step = cam.outdoor_zoom_step
	
	# We set the apropriate pitch and zoom target values.
	pitch_target = CameraSettings.PITCH_MAX + pitch_step * (-CameraSettings.PITCH_STEP_VALUE)
	zoom_target  = CameraSettings.ZOOM_MIN + zoom_step * CameraSettings.ZOOM_STEP_VALUE
	
	v_angle        = pitch_target
	zoom_dist      = zoom_target
	zoom_effective = zoom_target
	
