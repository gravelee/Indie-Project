extends Node3D

# =============================================================================
# MAIN — world building, player, input routing.
# Camera logic  → scripts/camera_rig.gd
# UI (menus)    → scripts/game_ui.gd
# Cam settings  → scripts/camera_settings.gd  (Resource, saved to disk)
#
# Controls:
#   WASD / Arrows     — move (camera-relative)
#   RMB drag H        — orbit
#   RMB drag V        — pitch
#   Scroll / RMB+Scroll — zoom (analog)
#   - / =             — zoom out / in (discrete steps)
#   Shift+- / =       — pitch steeper / shallower
#   Q / E             — orbit left / right
#   F                 — toggle billboard
#   ESC               — pause menu
# =============================================================================

const PLAYER_SPRITE_SIZE : int   = 96
const TILE_SIZE          : float = 1.0
const TREE_SINK          : float = 0.9
const TREE_FADE_RADIUS   : float = 3.0

const SETTINGS_SAVE_PATH : String = "user://camera_settings.tres"

# ---------------------------------------------------------------------------
# Core systems
# ---------------------------------------------------------------------------
var cam        : CameraSettings
var camera_rig : Node3D    # camera_rig.gd
var game_ui    : Node      # game_ui.gd

# Player
var player_body   : CharacterBody3D
var player_sprite : AnimatedSprite3D
var billboard_on  : bool = true

# Scene refs
var debug_label : Label
var tree_sprites : Array[Sprite3D] = []

# Materials
var mat_light    : StandardMaterial3D
var mat_dark     : StandardMaterial3D
var mat_ledge    : StandardMaterial3D
var mat_ramp     : StandardMaterial3D
var mat_water    : StandardMaterial3D
var mat_cliff    : StandardMaterial3D
var mat_mountain : StandardMaterial3D


func _ready() -> void:
	_load_or_create_settings()
	_build_materials()
	_build_ground()
	_build_ledge()
	_build_ramp()
	_build_cliff()
	_build_mountain()
	_build_small_wall(Vector3( 6.0, 1.0,  14.0), Vector3(1.0, 2.0, 4.0))
	_build_small_wall(Vector3(14.0, 0.75, 22.0), Vector3(5.0, 1.5, 1.0))
	_build_tree(Vector3( 2.0, 0.0,  3.0))
	_build_tree(Vector3( 3.0, 0.0,  7.0))
	_build_tree(Vector3( 2.0, 0.0, 13.0))
	_build_tree(Vector3( 1.5, 0.0, 19.0))
	_build_tree(Vector3( 7.0, 0.0,  4.0))
	_build_tree(Vector3( 8.0, 0.0, 11.0))
	_build_tree(Vector3(16.0, 0.0,  4.0))
	_build_tree(Vector3(17.0, 0.0, 12.0))
	_build_tree(Vector3(14.0, 0.0, 17.0))
	_build_tree(Vector3(22.0, 0.0,  3.0))
	_build_tree(Vector3(23.0, 0.0, 13.0))
	_build_tree(Vector3(10.0, 0.0, 19.0))
	_build_water_tile(Vector3(17.0, 0.0, 18.0))
	_build_water_tile(Vector3(18.0, 0.0, 18.0))
	_build_water_tile(Vector3(17.0, 0.0, 19.0))
	_build_player()
	_build_camera_rig()
	_build_creature("rat",   Vector3( 9.0, 0.0, 16.0))
	_build_creature("rat",   Vector3(11.0, 0.0, 14.0))
	_build_creature("snake", Vector3(15.0, 0.0, 20.0))
	_build_ui()
	_build_debug_label()


# ---------------------------------------------------------------------------
# SETTINGS LOAD / SAVE
# ---------------------------------------------------------------------------

func _load_or_create_settings() -> void:
	if ResourceLoader.exists(SETTINGS_SAVE_PATH):
		cam = ResourceLoader.load(SETTINGS_SAVE_PATH) as CameraSettings
	if cam == null:
		cam = CameraSettings.new()


# ---------------------------------------------------------------------------
# SYSTEM SETUP
# ---------------------------------------------------------------------------

func _build_camera_rig() -> void:
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.set_script(load("res://scripts/camera_rig.gd"))
	add_child(camera_rig)
	camera_rig.call("init", cam, player_body, player_sprite)
	camera_rig.call("apply_active_preset")   # apply loaded settings immediately, no lerp drift
	player_body.set("camera_rig", camera_rig)  # wire back — player needs h_angle for movement


func _build_ui() -> void:
	game_ui = Node.new()
	game_ui.name = "GameUI"
	game_ui.set_script(load("res://scripts/game_ui.gd"))
	add_child(game_ui)
	game_ui.call("init", cam, camera_rig)


# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				game_ui.call("on_escape")
			KEY_F:
				billboard_on = not billboard_on
				player_sprite.billboard = (
					BaseMaterial3D.BILLBOARD_FIXED_Y if billboard_on
					else BaseMaterial3D.BILLBOARD_DISABLED
				)



# ---------------------------------------------------------------------------
# PROCESS
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Feed per-frame flags to subsystems
	camera_rig.scroll_zoom_blocked        = game_ui.call("is_mouse_over_panel")
	player_body.set("movement_blocked", game_ui.call("any_ui_open"))

	_update_tree_fade(delta)

	var rig    : Node3D  = camera_rig
	var pos    : Vector3 = player_body.position
	debug_label.text = (
		"[v6]  WASD: move  RMB: orbit+pitch  Q/E: orbit  Shift+-/=: pitch  -/=: zoom  ESC: menu\n"
		+ "Pitch: %.0f°   Zoom step: %d/10 (%.1f)   Zoom eff: %.1f   Orbit: %.0f°\n"
		+ "Pos: (%.1f, %.2f, %.1f)   Floor: %s   Anim: %s   Alpha: %.2f   Scroll: %d"
	) % [
		rig.v_angle, rig.zoom_step, rig.zoom_target, rig.zoom_effective,
		rad_to_deg(rig.h_angle),
		pos.x, pos.y, pos.z,
		str(player_body.is_on_floor()),
		str(player_sprite.animation),
		player_sprite.modulate.a,
		rig.dbg_scroll
	]



# ---------------------------------------------------------------------------
# TREE FADE
# ---------------------------------------------------------------------------

func _update_tree_fade(delta: float) -> void:
	var cam_pos    : Vector3 = camera_rig.camera.global_position
	var player_pos : Vector3 = player_body.global_position + \
		Vector3(0.0, PLAYER_SPRITE_SIZE * player_sprite.pixel_size * 0.5, 0.0)
	var to_player  : Vector3 = player_pos - cam_pos
	var cam_dist   : float   = to_player.length()

	for sprite : Sprite3D in tree_sprites:
		var tree_to_player : float = sprite.global_position.distance_to(player_pos)
		var target_alpha   : float = 1.0
		if tree_to_player < TREE_FADE_RADIUS:
			var to_tree  : Vector3 = sprite.global_position - cam_pos
			var t        : float   = to_tree.dot(to_player) / (cam_dist * cam_dist)
			if t > 0.0 and t < 1.0:
				var closest  : Vector3 = cam_pos + to_player * t
				var off_axis : float   = (sprite.global_position - closest).length()
				if off_axis < 1.2:
					var proximity : float = 1.0 - (tree_to_player / TREE_FADE_RADIUS)
					target_alpha = 1.0 - proximity * 0.85
		sprite.modulate.a = move_toward(sprite.modulate.a, target_alpha, delta * 4.0)


# ---------------------------------------------------------------------------
# MATERIALS
# ---------------------------------------------------------------------------

func _build_materials() -> void:
	mat_light = StandardMaterial3D.new()
	mat_light.albedo_color = Color(0.72, 0.68, 0.55)
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.52, 0.50, 0.38)
	mat_ledge = StandardMaterial3D.new()
	mat_ledge.albedo_color = Color(0.45, 0.40, 0.35)
	mat_ramp = StandardMaterial3D.new()
	mat_ramp.albedo_color = Color(0.58, 0.50, 0.40)
	mat_water = StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.2, 0.5, 0.9, 0.7)
	mat_water.flags_transparent = true
	mat_cliff = StandardMaterial3D.new()
	mat_cliff.albedo_color = Color(0.38, 0.35, 0.32)
	mat_mountain = StandardMaterial3D.new()
	mat_mountain.albedo_color = Color(0.50, 0.46, 0.40)


# ---------------------------------------------------------------------------
# GROUND — 25×25 tiles
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var root := Node3D.new()
	root.name = "GroundVisual"
	add_child(root)
	var plane := PlaneMesh.new()
	plane.size = Vector2(TILE_SIZE, TILE_SIZE)
	for row : int in range(25):
		for col : int in range(25):
			var tile := MeshInstance3D.new()
			tile.mesh = plane
			tile.material_override = mat_light if (row + col) % 2 == 0 else mat_dark
			tile.position = Vector3((col + 0.5) * TILE_SIZE, 0.0, (row + 0.5) * TILE_SIZE)
			root.add_child(tile)
	var body := StaticBody3D.new()
	body.name = "Ground"
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)
	add_child(body)


# ---------------------------------------------------------------------------
# BOX OBSTACLE HELPER
# ---------------------------------------------------------------------------

func _build_box_obstacle(center: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	body.add_child(vis)
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = size
	col.shape = shp
	body.add_child(col)
	add_child(body)


func _build_ledge() -> void:
	_build_box_obstacle(Vector3(5.0, 0.25, 3.5), Vector3(3.0, 0.5, 3.0), mat_ledge)
	var top := PlaneMesh.new()
	top.size = Vector2(3.0, 3.0)
	var top_vis := MeshInstance3D.new()
	top_vis.mesh = top
	top_vis.material_override = mat_light
	top_vis.position = Vector3(5.0, 0.502, 3.5)
	add_child(top_vis)


func _build_ramp() -> void:
	var rise   : float = 0.5
	var run    : float = 1.0
	var angle  : float = atan2(rise, run)
	var length : float = sqrt(run * run + rise * rise)
	var body := StaticBody3D.new()
	body.name = "Ramp"
	body.position = Vector3(5.0, 0.25, 5.5)
	body.rotation.x = angle
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.0, 0.06, length)
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat_ramp
	body.add_child(vis)
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(3.0, 0.06, length)
	col.shape = shp
	body.add_child(col)
	add_child(body)


func _build_cliff() -> void:
	_build_box_obstacle(Vector3(12.0, 3.0, 7.0), Vector3(10.0, 6.0, 2.0), mat_cliff)


func _build_mountain() -> void:
	_build_box_obstacle(Vector3(20.0, 1.25, 8.0), Vector3(6.0, 2.5, 6.0), mat_mountain)
	_build_box_obstacle(Vector3(20.0, 3.5,  8.0), Vector3(4.0, 2.0, 4.0), mat_mountain)
	_build_box_obstacle(Vector3(20.0, 5.5,  8.0), Vector3(2.0, 2.0, 2.0), mat_mountain)


func _build_small_wall(center: Vector3, size: Vector3) -> void:
	_build_box_obstacle(center, size, mat_cliff)


# ---------------------------------------------------------------------------
# TREES
# ---------------------------------------------------------------------------

func _build_tree(world_pos: Vector3) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "Tree"
	sprite.texture = _get_tree_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = TILE_SIZE / 32.0
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	var wh : float = sprite.texture.get_height() * sprite.pixel_size
	sprite.position = Vector3(world_pos.x, wh * 0.5 - TREE_SINK, world_pos.z)
	add_child(sprite)
	tree_sprites.append(sprite)
	var body := StaticBody3D.new()
	body.position = Vector3(world_pos.x, 0.5, world_pos.z)
	var col := CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius = 0.4
	shp.height = 1.0
	col.shape = shp
	body.add_child(col)
	add_child(body)


# ---------------------------------------------------------------------------
# WATER
# ---------------------------------------------------------------------------

func _build_water_tile(pos: Vector3) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(TILE_SIZE, TILE_SIZE)
	var vis := MeshInstance3D.new()
	vis.mesh = plane
	vis.material_override = mat_water
	vis.position = Vector3(pos.x, -0.02, pos.z)
	add_child(vis)


# ---------------------------------------------------------------------------
# PLAYER
# ---------------------------------------------------------------------------

func _build_player() -> void:
	player_body = CharacterBody3D.new()
	player_body.name = "Player"
	player_body.position = Vector3(12.0, 0.0, 20.0)
	player_body.set_script(load("res://scripts/player.gd"))
	add_child(player_body)
	player_body.call("init", cam)
	player_sprite = player_body.get("sprite") as AnimatedSprite3D


func _build_creature(type: String, world_pos: Vector3) -> void:
	var body := CharacterBody3D.new()
	body.name = type.capitalize()
	body.position = world_pos
	body.set_script(load("res://scripts/creature.gd"))
	add_child(body)
	body.call("init", type, camera_rig)



# ---------------------------------------------------------------------------
# DEBUG LABEL
# ---------------------------------------------------------------------------

func _build_debug_label() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	debug_label = Label.new()
	debug_label.position = Vector2(16, 16)
	debug_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(debug_label)


# ---------------------------------------------------------------------------
# TEXTURES
# ---------------------------------------------------------------------------

func _get_tree_texture() -> Texture2D:
	var path : String = "res://assets/sprites/tree/mystic/3x2_h1.png"
	var tex  : Texture2D = AssetLoader.load_texture(path)
	if tex:
		return tex
	return _make_placeholder_tree()


func _make_placeholder_tree() -> Texture2D:
	var img    := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	var trunk  := Color(0.38, 0.24, 0.10, 1.0)
	var dark   := Color(0.10, 0.42, 0.12, 1.0)
	var light  := Color(0.18, 0.60, 0.20, 1.0)
	var center := Vector2(16.0, 22.0)
	var radius : float = 13.0
	for y : int in range(48, 64):
		for x : int in range(13, 19):
			img.set_pixel(x, y, trunk)
	for y : int in range(0, 48):
		for x : int in range(0, 32):
			var t : float = Vector2(x, y).distance_to(center) / radius
			if t <= 1.0:
				img.set_pixel(x, y, dark.lerp(light, 1.0 - t))
	return ImageTexture.create_from_image(img)
