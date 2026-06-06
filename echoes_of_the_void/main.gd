extends Node3D

# =============================================================================
# MAIN — world building, player, input routing.
# Camera logic  → scripts/camera_rig.gd
# UI (menus)    → scripts/game_ui.gd
# Cam settings  → scripts/camera_settings.gd  (Resource, saved to disk)
#
# Controls:
#   WASD / Arrows     — move (camera-relative)
#   LMB               — Select / Deselect targets
#   RMB drag Horizontal  — orbit
#   RMB drag Vertical    — pitch
#   Scroll / RMB+Scroll  — zoom (analog)
#   - / =             — zoom out / in (discrete steps)
#   Shift + (- / =)   — pitch steeper / shallower
#   Q / E             — orbit left / right
#   F                 — toggle billboard (remember to delete or release).
#   TAB               — select target
#   ESC               — game menu
# =============================================================================

const PLAYER_SPRITE_SIZE : int   = 96
const TILE_SIZE          : float = 1.0

const SETTINGS_SAVE_PATH : String = "user://camera_settings.tres"

# ---------------------------------------------------------------------------
# Core systems
# ---------------------------------------------------------------------------
var cam        : CameraSettings
var camera_rig : Node3D    # camera_rig.gd
var game_ui    : Node      # game_ui.gd
var hud        : CanvasLayer  # hud.gd
var debug_panel : Node2D      # debug_panel.gd
var map_loader : MapLoader    # streaming prop + creature system

# Player
var player_body   : CharacterBody3D
var player_sprite : AnimatedSprite3D
var billboard_on  : bool = true

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

	# Load terrain and props from map CSV files
	map_loader = MapLoader.new()
	map_loader.load_terrain(self)

	# Test geometry kept for dev reference — remove when map content replaces it
	_build_ledge()
	_build_ramp()
	_build_cliff()
	_build_mountain()
	_build_small_wall(Vector3( 6.0, 1.0,  14.0), Vector3(1.0, 2.0, 4.0))
	_build_small_wall(Vector3(14.0, 0.75, 22.0), Vector3(5.0, 1.5, 1.0))

	# Player at spawn position from entities CSV
	var spawn_pos : Vector3 = map_loader.get_player_spawn()
	_build_player(spawn_pos)
	_build_camera_rig()
	_build_hud()
	_build_test_block()

	# Spawn initial window of props and creatures; streaming handled in _process
	map_loader.init_streaming(self, camera_rig, player_body)

	_build_ui()


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
	game_ui.call("init", cam, camera_rig, player_body)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name  = "HUD"
	hud.layer = 1
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)
	hud.call("init", player_body)

	var dp_canvas := CanvasLayer.new()
	dp_canvas.name  = "DebugPanelCanvas"
	dp_canvas.layer = 2
	add_child(dp_canvas)
	debug_panel = Node2D.new()
	debug_panel.set_script(load("res://scripts/debug_panel.gd"))
	dp_canvas.add_child(debug_panel)
	debug_panel.call("init", player_body)


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

func _process(_delta: float) -> void:
	# Feed per-frame flags to subsystems
	camera_rig.scroll_zoom_blocked        = game_ui.call("is_mouse_over_panel")
	player_body.set("movement_blocked", game_ui.call("any_ui_open"))
	hud.call("refresh")
	map_loader.update(player_body.global_position)




# ---------------------------------------------------------------------------
# MATERIALS
# ---------------------------------------------------------------------------

func _build_materials() -> void:
	mat_light = StandardMaterial3D.new()
	mat_light.albedo_color = Color(0.72, 0.68, 0.55)
	mat_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.52, 0.50, 0.38)
	mat_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_ledge = StandardMaterial3D.new()
	mat_ledge.albedo_color = Color(0.45, 0.40, 0.35)
	mat_ledge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_ramp = StandardMaterial3D.new()
	mat_ramp.albedo_color = Color(0.58, 0.50, 0.40)
	mat_ramp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_water = StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.2, 0.5, 0.9, 0.7)
	mat_water.flags_transparent = true
	mat_water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_cliff = StandardMaterial3D.new()
	mat_cliff.albedo_color = Color(0.38, 0.35, 0.32)
	mat_cliff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_mountain = StandardMaterial3D.new()
	mat_mountain.albedo_color = Color(0.50, 0.46, 0.40)
	mat_mountain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED



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

func _build_player(spawn_pos: Vector3 = Vector3(12.0, 0.0, 20.0)) -> void:
	player_body = CharacterBody3D.new()
	player_body.name = "Player"
	player_body.position = spawn_pos
	player_body.set_script(load("res://scripts/player.gd"))
	add_child(player_body)
	player_body.call("init", cam)
	player_sprite = player_body.get("sprite") as AnimatedSprite3D


func _build_test_block() -> void:
	var body := CharacterBody3D.new()
	body.name = "TestBlock"
	body.position = Vector3(12.0, 1.0, 17.0)   # north of player spawn; Y=1 for 2×2×2 center
	body.set_script(load("res://scripts/pushable_block.gd"))
	body.add_to_group("pushable")
	# Visual — brown cube
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 2.0, 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.15)
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	body.add_child(vis)
	# Collision
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(2.0, 2.0, 2.0)
	col.shape = shp
	body.add_child(col)
	add_child(body)


func _build_creature(type: String, stat_id: String, world_pos: Vector3,
		aggression: String, has_home: bool, can_wander: bool) -> void:
	var body := CharacterBody3D.new()
	body.name = type.capitalize()
	body.position = world_pos
	body.set_script(load("res://scripts/creature.gd"))
	add_child(body)
	# home_position is recorded inside init() from body.global_position — set AFTER add_child
	body.call("init", type, stat_id, camera_rig, player_body, aggression, has_home, can_wander)
