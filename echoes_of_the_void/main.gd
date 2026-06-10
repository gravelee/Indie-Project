extends Node3D

# =============================================================================
# MAIN — world building, player, input routing.
#
# !! INCREMENTAL REBUILD IN PROGRESS !!
# Everything is commented out. Systems are re-introduced one stage at a time.
# See SKILL.md "Incremental Rebuild Plan" for the stage order.
#
# Stage 1 — Bare scene: flat ground + fixed camera.           ← CURRENT
# Stage 2 — Camera rig: camera_rig.gd wired back in.
# Stage 3 — Player movement (cube placeholder).
# Stage 4 — Player sprite + billboard + directional anims.
# Stage 5 — Stats skeleton (HP only) + ability/abilities.
# Stage 6 — Player combat: attack state, hitbox, dummy target.
# Stage 7 — Terrain height: terrain_generator + HeightMapShape3D.
# Stage 8 — One creature, no AI.
# Stage 9 — Creature AI states (one at a time).
# Stage 10 — Pathfinding (A* XZ plane).
# Stage 11 — Status effects.
# Stage 12 — HUD.
# Stage 13 — Combat feedback (floating numbers).
# Stage 14 — Map loading (CSV terrain + props + streaming).
# =============================================================================

const TILE_SIZE : float = 1.0

# ---------------------------------------------------------------------------
# Variable declarations kept for reference — uncomment as each stage adds them
# ---------------------------------------------------------------------------

#var cam        : CameraSettings
#var camera_rig : Node3D
#var game_ui    : Node
#var hud        : CanvasLayer
#var debug_panel : Node2D
#var map_loader : MapLoader

#var player_body   : CharacterBody3D
#var player_sprite : AnimatedSprite3D
#var billboard_on  : bool = true

#var mat_light    : StandardMaterial3D
#var mat_dark     : StandardMaterial3D
#var mat_ledge    : StandardMaterial3D
#var mat_ramp     : StandardMaterial3D
#var mat_water    : StandardMaterial3D
#var mat_cliff    : StandardMaterial3D
#var mat_mountain : StandardMaterial3D


# ---------------------------------------------------------------------------
# STAGE 1 — Bare scene
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ground()
	_build_camera()


func _build_ground() -> void:
	# Flat 100×100 tile ground — visual mesh + collision.
	var body := StaticBody3D.new()
	body.name = "Ground"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(100.0, 100.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.32)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	# PlaneMesh is centered at origin; shift so (0,0)→(100,100) matches tile grid.
	vis.position = Vector3(50.0, 0.0, 50.0)
	body.add_child(vis)

	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(100.0, 0.1, 100.0)
	col.shape = shp
	col.position = Vector3(50.0, -0.05, 50.0)
	body.add_child(col)

	add_child(body)


func _build_camera() -> void:
	# Fixed camera looking straight down at map center — no controls yet.
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(50.0, 30.0, 50.0)
	cam.rotation_degrees = Vector3(-70.0, 0.0, 0.0)
	add_child(cam)


# ---------------------------------------------------------------------------
# Uncomment as stages are introduced
# ---------------------------------------------------------------------------

#func _input(event: InputEvent) -> void:
#	if event is InputEventKey and event.pressed:
#		match event.keycode:
#			KEY_ESCAPE:
#				game_ui.call("on_escape")
#			KEY_F:
#				billboard_on = not billboard_on
#				player_sprite.billboard = (
#					BaseMaterial3D.BILLBOARD_FIXED_Y if billboard_on
#					else BaseMaterial3D.BILLBOARD_DISABLED
#				)


#func _process(_delta: float) -> void:
#	camera_rig.scroll_zoom_blocked        = game_ui.call("is_mouse_over_panel")
#	player_body.set("movement_blocked", game_ui.call("any_ui_open"))
#	hud.call("refresh")
#	map_loader.update(player_body.global_position)


# -- Stage 2: camera rig -------------------------------------------------------
#func _build_camera_rig() -> void:
#	camera_rig = Node3D.new()
#	camera_rig.name = "CameraRig"
#	camera_rig.set_script(load("res://scripts/camera_rig.gd"))
#	add_child(camera_rig)
#	camera_rig.call("init", cam, player_body, player_sprite)
#	camera_rig.call("apply_active_preset")
#	player_body.set("camera_rig", camera_rig)


# -- Stage 3+4: player ---------------------------------------------------------
#func _build_player(spawn_pos: Vector3 = Vector3(50.0, 0.0, 50.0)) -> void:
#	player_body = CharacterBody3D.new()
#	player_body.name = "Player"
#	player_body.position = spawn_pos
#	player_body.set_script(load("res://scripts/player.gd"))
#	add_child(player_body)
#	player_body.call("init", cam)
#	player_sprite = player_body.get("sprite") as AnimatedSprite3D


# -- Stage 5+: settings / UI / HUD ---------------------------------------------
#const SETTINGS_SAVE_PATH : String = "user://camera_settings.tres"
#func _load_or_create_settings() -> void:
#	if ResourceLoader.exists(SETTINGS_SAVE_PATH):
#		cam = ResourceLoader.load(SETTINGS_SAVE_PATH) as CameraSettings
#	if cam == null:
#		cam = CameraSettings.new()

#func _build_ui() -> void:
#	game_ui = Node.new()
#	game_ui.name = "GameUI"
#	game_ui.set_script(load("res://scripts/game_ui.gd"))
#	add_child(game_ui)
#	game_ui.call("init", cam, camera_rig, player_body)

#func _build_hud() -> void:
#	hud = CanvasLayer.new()
#	hud.name  = "HUD"
#	hud.layer = 1
#	hud.set_script(load("res://scripts/hud.gd"))
#	add_child(hud)
#	hud.call("init", player_body)
#	var dp_canvas := CanvasLayer.new()
#	dp_canvas.name  = "DebugPanelCanvas"
#	dp_canvas.layer = 2
#	add_child(dp_canvas)
#	debug_panel = Node2D.new()
#	debug_panel.set_script(load("res://scripts/debug_panel.gd"))
#	dp_canvas.add_child(debug_panel)
#	debug_panel.call("init", player_body)


# -- Stage 7: terrain ----------------------------------------------------------
#func _build_terrain_light() -> void:
#	var env_node := WorldEnvironment.new()
#	var env      := Environment.new()
#	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
#	env.ambient_light_color  = Color(1.0, 1.0, 1.0)
#	env.ambient_light_energy = 0.5
#	env_node.environment     = env
#	add_child(env_node)
#	var light := DirectionalLight3D.new()
#	light.name             = "SunLight"
#	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
#	light.light_energy     = 0.7
#	light.shadow_enabled   = false
#	add_child(light)


# -- Stage 14: map loader ------------------------------------------------------
#func _build_map() -> void:
#	map_loader = MapLoader.new()
#	map_loader.load_terrain(self)


# -- Test / reference geometry (re-add when relevant) -------------------------
#func _build_materials() -> void: ...
#func _build_ledge() -> void: ...
#func _build_ramp() -> void: ...
#func _build_cliff() -> void: ...
#func _build_mountain() -> void: ...
#func _build_small_wall(center, size) -> void: ...
#func _build_test_block() -> void: ...
#func _build_creature(...) -> void: ...
#func _start_music() -> void: ...
