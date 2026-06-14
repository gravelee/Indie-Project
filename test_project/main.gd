extends Node3D

var player_body   : CharacterBody3D # Handles physics, collision, movement.
var player_sprite : AnimatedSprite3D # Purely visual.
var cam : CameraSettings # Camera slot settings. Passed to the camera rig.
var camera_rig : Node3D # Its been passed to the player.


# Called: _ready().
func _build_placeholder_player() -> void:
	
	# Create a player placeholder for the scene.
	
	# player instance
	player_body = CharacterBody3D.new()
	player_body.name = "Player"
	player_body.position = Vector3(50.0, 0.0, 50.0)
	
	# player collision
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius = 0.4
	shp.height = 1.8
	col.shape = shp
	col.position = Vector3(0.0, 1.0, 0.0)
	player_body.add_child(col)
	
	# player sprite
	player_sprite = AnimatedSprite3D.new()
	player_sprite.pixel_size = 3.0 / 32.0
	player_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	player_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	player_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	player_body.add_child(player_sprite)
	
	player_body.set_script(load("res://player.gd"))
	add_child(player_body)


# Called: _ready().
func _build_camera_rig() -> void:
	
	# Create a camera rig and call its init function.
	
	cam = CameraSettings.new()
	
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.set_script(load("res://camera_rig.gd"))
	add_child(camera_rig)


# Called: _ready().
func _build_dummy() -> void:
	
	var body := StaticBody3D.new()
	body.name = "Dummy"
	body.position = Vector3(52.0, 0.0, 50.0)
	
	var mesh : BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 2.0, 1.0)
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var vis : MeshInstance3D = MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	vis.position = Vector3(0.0, 1.0, 0.0)
	body.add_child(vis)
	
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius = 0.4
	shp.height = 1.8
	col.shape = shp
	col.position = Vector3(0.0, 1.0, 0.0)
	body.add_child(col)
		
	var dummy_stats : Stats = Stats.new(1, 1, 5, 1, 2)
	body.set_meta("stats", dummy_stats)
		
	add_child(body)


# Called: _ready().
func _build_box(pos: Vector3, size: Vector3, color: Color) -> void:

	# Creates a box body and adds a box mesh with color and no shading.
	var body := StaticBody3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	body.add_child(vis)
	
	# Adds collision to the box body.
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = size
	col.shape = shp
	body.add_child(col)
	body.position = pos
	add_child(body)


# Called: _ready().
func _build_ground() -> void:
 
	# Creates the ground for the scene.
	
	# ground instance
	var body := StaticBody3D.new()
	body.name = "Ground"
	
	# ground body (looks)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(100.0, 100.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.32)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	vis.position = Vector3(50.0, 0.0, 50.0)
	body.add_child(vis)
	
	# ground collision
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(100.0, 0.1, 100.0)
	col.shape = shp
	col.position = Vector3(50.0, -0.05, 50.0)
	body.add_child(col)
	
	add_child(body)


# Called: Godot engine (_ready).
func _ready() -> void:
	
	_build_placeholder_player()
	_build_camera_rig()
	player_body.call("init", camera_rig, player_sprite)
	camera_rig.call("init", cam, player_body, player_sprite)
	
	_build_dummy()
	_build_box(Vector3(54.0, 1.0, 50.0), Vector3(2.0, 2.0, 2.0), Color(0.3, 0.3, 0.8))
	_build_ground()
