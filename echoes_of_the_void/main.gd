extends Node3D

# =============================================================================
# MAIN — world building, player, input routing.
# =============================================================================

const TILE_SIZE           : float  = 1.0
const SETTINGS_SAVE_PATH  : String = "user://camera_settings.tres"

var cam           : CameraSettings
var camera_rig    : Node3D
var player_body   : CharacterBody3D
var player_sprite : AnimatedSprite3D
var game_ui       : Node
var hud           : CanvasLayer
var debug_panel   : Node2D
var map_loader    : MapLoader


# ---------------------------------------------------------------------------
# SETTINGS
# ---------------------------------------------------------------------------

# Called: _ready().
func _load_or_create_settings() -> void:

	if ResourceLoader.exists(SETTINGS_SAVE_PATH):
		cam = ResourceLoader.load(SETTINGS_SAVE_PATH) as CameraSettings
	if cam == null:
		cam = CameraSettings.new()


# ---------------------------------------------------------------------------
# TERRAIN LIGHT
# ---------------------------------------------------------------------------

# Called: _ready().
func _build_terrain_light() -> void:

	var env_node := WorldEnvironment.new()
	var env      := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(1.0, 1.0, 1.0)
	env.ambient_light_energy = 0.5
	env_node.environment     = env
	add_child(env_node)

	var light := DirectionalLight3D.new()
	light.name             = "SunLight"
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	light.light_energy     = 0.7
	light.shadow_enabled   = false
	add_child(light)


# ---------------------------------------------------------------------------
# MAP
# ---------------------------------------------------------------------------

# Called: _ready().
func _build_map() -> void:

	map_loader = MapLoader.new()
	map_loader.load_terrain(self)


# ---------------------------------------------------------------------------
# PLAYER
# ---------------------------------------------------------------------------

# Called: _ready().
func _build_player(spawn_pos: Vector3) -> void:

	player_body = CharacterBody3D.new()
	player_body.name     = "Player"
	player_body.position = spawn_pos
	player_body.set_script(load("res://scripts/player.gd"))
	add_child(player_body)
	player_body.call("init", cam)
	player_sprite = player_body.get("sprite") as AnimatedSprite3D


# ---------------------------------------------------------------------------
# CAMERA RIG
# ---------------------------------------------------------------------------

# Called: _ready().
func _build_camera_rig() -> void:

	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.set_script(load("res://scripts/camera_rig.gd"))
	add_child(camera_rig)
	camera_rig.call("init", cam, player_body, player_sprite)
	camera_rig.call("apply_active_preset")


# ---------------------------------------------------------------------------
# UI / HUD
# ---------------------------------------------------------------------------

# Called: _ready().
func _build_ui() -> void:

	game_ui = Node.new()
	game_ui.name = "GameUI"
	game_ui.set_script(load("res://scripts/game_ui.gd"))
	add_child(game_ui)
	game_ui.call("init", cam, camera_rig, player_body)


# Called: _ready().
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
# READY
# ---------------------------------------------------------------------------

# Called: Godot engine (_ready).
func _ready() -> void:

	_load_or_create_settings()
	_build_terrain_light()
	_build_map()

	var spawn_pos : Vector3 = map_loader.get_player_spawn()
	_build_player(spawn_pos)
	_build_camera_rig()

	player_body.set("camera_rig", camera_rig)
	map_loader.init_streaming(self, camera_rig, player_body)

	_build_ui()
	_build_hud()


# ---------------------------------------------------------------------------
# INPUT / PROCESS
# ---------------------------------------------------------------------------

# Called: Godot engine (InputEvent).
func _input(event: InputEvent) -> void:

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				game_ui.call("on_escape")


# Called: Godot engine (every frame).
func _process(_delta: float) -> void:

	camera_rig.set("scroll_zoom_blocked", game_ui.call("is_mouse_over_panel"))
	player_body.set("movement_blocked",   game_ui.call("any_ui_open"))
	hud.call("refresh")
	map_loader.update(player_body.global_position)
