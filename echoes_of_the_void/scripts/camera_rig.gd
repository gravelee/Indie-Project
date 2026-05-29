extends Node3D

# ---------------------------------------------------------------------------
# CameraRig — owns all camera state and input.
# Attach to a Node3D that acts as the pivot (camera orbits around it).
# Call init() once after adding to the scene tree.
# ---------------------------------------------------------------------------

const ZOOM_LERP          : float = 12.0
const PITCH_LERP         : float = 8.0
const PAN_MIN_DELTA_IN   : float = 1.5   # macOS pan gesture: zoom-in threshold
const PAN_MIN_DELTA_OUT  : float = 0.9   # macOS pan gesture: zoom-out threshold
const PLAYER_WORLD_HEIGHT : float = 3.0  # 96px sprite * (1.0/32) px-per-unit
const PLAYER_FADE_START  : float = 5.0   # fade begins when collision forces zoom below this
const PLAYER_FADE_FULL   : float = 2.0   # fully faded at this collision distance

# Assigned by main.gd via init()
var cam           : CameraSettings
var player_body   : CharacterBody3D
var player_sprite : AnimatedSprite3D

# Camera node (child, built in init)
var camera : Camera3D

# Camera state
var h_angle      : float = 0.0
var v_angle      : float = -30.0
var pitch_target : float = -30.0
var zoom_step    : int   = 3
var zoom_target  : float = 8.0
var zoom_dist    : float = 8.0
var zoom_effective : float = 8.0
var rmb_held     : bool  = false
var lmb_held     : bool  = false
var dbg_scroll   : int   = 0

# Set by main.gd each frame from game_ui.is_mouse_over_panel()
var scroll_zoom_blocked : bool = false

# Set by main.gd when is_indoors changes — only used for preset application
var is_indoors : bool = false


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


# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rmb_held = event.pressed
			if not rmb_held:
				# Snap zoom_step to nearest step so keyboard zoom starts from correct position
				zoom_step = clampi(
					roundi((zoom_target - CameraSettings.ZOOM_MIN) /
					(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) *
					float(CameraSettings.ZOOM_STEPS - 1)),
					0, CameraSettings.ZOOM_STEPS - 1)
		if event.button_index == MOUSE_BUTTON_LEFT:
			lmb_held = event.pressed

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and cam.mouse_zoom_enabled and not scroll_zoom_blocked:
			var zoom_dir : float = 1.0 if not cam.invert_zoom else -1.0
			dbg_scroll += 1
			zoom_target = clampf(zoom_target - cam.zoom_sens * 10.0 * zoom_dir,
				CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
			_sync_zoom_step()

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and cam.mouse_zoom_enabled and not scroll_zoom_blocked:
			var zoom_dir : float = 1.0 if not cam.invert_zoom else -1.0
			dbg_scroll += 1
			zoom_target = clampf(zoom_target + cam.zoom_sens * 10.0 * zoom_dir,
				CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
			_sync_zoom_step()

	if event is InputEventPanGesture and cam.mouse_zoom_enabled and not scroll_zoom_blocked:
		var zoom_dir : float = 1.0 if not cam.invert_zoom else -1.0
		if event.delta.y >= PAN_MIN_DELTA_OUT or event.delta.y <= -PAN_MIN_DELTA_IN:
			dbg_scroll += 1
			zoom_target = clampf(zoom_target + event.delta.y * cam.zoom_sens * zoom_dir,
				CameraSettings.ZOOM_MIN, CameraSettings.ZOOM_MAX)
			_sync_zoom_step()

	if event is InputEventMouseMotion:
		if rmb_held:
			var orbit_dir : float = -1.0 if not cam.invert_orbit else 1.0
			h_angle += deg_to_rad(event.relative.x * cam.orbit_sens * orbit_dir)
			if cam.mouse_pitch_enabled:
				var pitch_dir : float = 1.0 if not cam.invert_pitch else -1.0
				_adjust_pitch_direct(event.relative.y * cam.pitch_sens * pitch_dir)

	if event is InputEventKey and event.pressed:
		var shift : bool = event.shift_pressed
		match event.keycode:
			KEY_MINUS:
				if shift: _adjust_pitch_step(-1)
				else:     _adjust_zoom(1)
			KEY_EQUAL:
				if shift: _adjust_pitch_step(1)
				else:     _adjust_zoom(-1)


# ---------------------------------------------------------------------------
# PROCESS
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Keep pivot centered at player sprite midpoint
	var pixel_size   : float = player_sprite.pixel_size
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


# ---------------------------------------------------------------------------
# CAMERA UPDATE — smooth zoom + two-ray collision
# ---------------------------------------------------------------------------

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
		var player_top : Vector3 = player_body.global_position + Vector3(0.0, PLAYER_WORLD_HEIGHT, 0.0)
		var params2 : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			player_top, desired_world)
		params2.exclude = [player_body.get_rid()]
		var result2 : Dictionary = space.intersect_ray(params2)
		if not result2.is_empty():
			var hit_dist : float = (result["position"] - global_position).length()
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
# ZOOM / PITCH HELPERS
# ---------------------------------------------------------------------------

func _adjust_zoom(direction: int) -> void:
	zoom_step   = clampi(zoom_step + direction, 0, CameraSettings.ZOOM_STEPS - 1)
	zoom_target = CameraSettings.ZOOM_MIN + zoom_step * \
		(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) / float(CameraSettings.ZOOM_STEPS - 1)


func _sync_zoom_step() -> void:
	zoom_step = clampi(
		roundi((zoom_target - CameraSettings.ZOOM_MIN) /
		(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) *
		float(CameraSettings.ZOOM_STEPS - 1)),
		0, CameraSettings.ZOOM_STEPS - 1)


func _adjust_pitch_direct(delta_deg: float) -> void:
	v_angle      = clampf(v_angle      + delta_deg, CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)
	pitch_target = clampf(pitch_target + delta_deg, CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)


func _adjust_pitch_step(direction: int) -> void:
	pitch_target = clampf(pitch_target + direction * CameraSettings.PITCH_STEP,
		CameraSettings.PITCH_MIN, CameraSettings.PITCH_MAX)


# ---------------------------------------------------------------------------
# PRESET APPLY — called by GameUI when a preset slider changes
# ---------------------------------------------------------------------------

func apply_outdoor_preset(zoom_s: int, pitch: float) -> void:
	if not is_indoors:
		zoom_step   = zoom_s
		zoom_target = CameraSettings.ZOOM_MIN + zoom_step * \
			(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) / float(CameraSettings.ZOOM_STEPS - 1)
		pitch_target = pitch


func apply_indoor_preset(zoom_s: int, pitch: float) -> void:
	if is_indoors:
		zoom_step   = zoom_s
		zoom_target = CameraSettings.ZOOM_MIN + zoom_step * \
			(CameraSettings.ZOOM_MAX - CameraSettings.ZOOM_MIN) / float(CameraSettings.ZOOM_STEPS - 1)
		pitch_target = pitch


func apply_active_preset() -> void:
	if is_indoors:
		apply_indoor_preset(cam.indoor_zoom_step, cam.indoor_pitch)
	else:
		apply_outdoor_preset(cam.outdoor_zoom_step, cam.outdoor_pitch)
	# Snap lerp state so the camera starts at the correct position immediately
	v_angle        = pitch_target
	zoom_dist      = zoom_target
	zoom_effective = zoom_target
