extends Node3D

# ---------------------------------------------------------------------------
# Scene references
# ---------------------------------------------------------------------------

# The player's physics body — handles movement, collision, and combat logic.
var player_body   : CharacterBody3D

# The player's visual sprite — purely cosmetic, child of player_body.
var player_sprite : AnimatedSprite3D

# Camera slot settings (pitch, zoom, input flags). Created here, passed to camera_rig and player.
var cam           : CameraSettings

# The camera rig node — follows player_body and handles orbit, pitch, and zoom.
# Passed to player so player can read h_angle for camera-relative movement.
var camera_rig    : Node3D


# ===========================================================================
# BUILDERS
# ===========================================================================

# Called: _ready().
# Constructs the player CharacterBody3D with collision and sprite as children.
# Script is assigned last so _ready() on player.gd does not fire before init() is called.
func _build_player() -> void:

	# Load once — used both to read constants and to assign the script.
	var script : GDScript = load("res://player.gd")

	player_body          = CharacterBody3D.new()
	player_body.name     = "Player"
	# Initial drop height accounts for the body origin being above ground.
	player_body.position = Vector3(50.0, 21.5, 50.0)

	# Body origin is at fist/chest height so global_position.y reflects strike height.
	# Capsule world center stays at y=0.9 (bottom flush at y=0).
	# Local offset = capsule_half_height - body_origin_y (read from script).
	var col := CollisionShape3D.new()
	var shp := CapsuleShape3D.new()
	shp.radius   = 0.4
	shp.height   = 1.8
	col.shape    = shp
	col.position = Vector3(0.0, shp.height * 0.5 - script.BODY_ORIGIN_Y, 0.0)
	player_body.add_child(col)

	# BILLBOARD_FIXED_Y, ALPHA_CUT_DISABLED, TEXTURE_FILTER_NEAREST are required
	# on all sprites in the scene — see player.gd init() for full explanation.
	player_sprite                = AnimatedSprite3D.new()
	player_sprite.pixel_size     = script.PIXEL_SIZE
	player_sprite.billboard      = BaseMaterial3D.BILLBOARD_FIXED_Y
	player_sprite.alpha_cut      = SpriteBase3D.ALPHA_CUT_DISABLED
	player_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	player_body.add_child(player_sprite)

	player_body.set_script(script)
	add_child(player_body)


# Called: _ready().
# Creates the camera rig node. init() is called later in _ready() once player_body exists.
func _build_camera_rig() -> void:

	cam = CameraSettings.new()

	camera_rig      = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.set_script(load("res://camera_rig.gd"))
	add_child(camera_rig)


# Called: _ready().
# Spawns a rat creature with no AI — stands still and takes damage when punched.
# creature.gd owns its own collision and sprite setup via init().
func _build_rat() -> void:

	# Load once — used both to read constants and to assign the script.
	var script : GDScript = load("res://creature.gd")

	var body : CharacterBody3D = CharacterBody3D.new()
	body.name     = "Rat"
	# Body origin at visual center of the rat's drawn pixels (read from script).
	body.position = Vector3(52.0, script.BODY_ORIGIN_Y, 52.0)
	body.set_script(script)
	add_child(body)
	body.call("init")


# Called: _ready().
# Generic helper — spawns a colored static box with collision at the given position.
# Used to place test geometry (walls, obstacles, ramps) without a full prop system.
func _build_box(pos: Vector3, size: Vector3, color: Color) -> void:

	var body := StaticBody3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var vis := MeshInstance3D.new()
	vis.mesh             = mesh
	vis.material_override = mat
	body.add_child(vis)

	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size  = size
	col.shape = shp
	body.add_child(col)
	body.position = pos
	add_child(body)


# Called: _ready().
# Creates a flat 100×100 ground plane with visual mesh and box collision.
# Centered at (50, 0, 50) to match the 100×100 tile coordinate space.
func _build_ground() -> void:

	var body      := StaticBody3D.new()
	body.name      = "Ground"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(100.0, 100.0)
	var mat  := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.32)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var vis  := MeshInstance3D.new()
	vis.mesh              = mesh
	vis.material_override = mat
	# Offset to tile-space center — map origin is (0,0,0), tiles run to (100,0,100).
	vis.position          = Vector3(50.0, 0.0, 50.0)
	body.add_child(vis)

	# Thin box collision instead of a plane — plane collision can miss fast-moving objects.
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size     = Vector3(100.0, 0.1, 100.0)
	col.shape    = shp
	col.position = Vector3(50.0, -0.05, 50.0)
	body.add_child(col)

	add_child(body)


# ===========================================================================
# READY
# ===========================================================================

# Called: Godot engine on scene load.
# Build order matters: player and rig must exist before their init() calls,
# and player.init() must run before camera_rig.init() so player_sprite is
# ready for the rig to read pixel_size.
func _ready() -> void:

	_build_player()
	_build_camera_rig()
	# camera_rig.init() must run first — it sets camera_rig.cam, which player.init()
	# reads via camera_rig.get("cam"). pixel_size is already set in _build_player()
	# so the rig doesn't need player.init() to have run first.
	camera_rig.call("init", cam, player_body, player_sprite)
	player_body.call("init", camera_rig, player_sprite)

	_build_rat()
	_build_box(Vector3(54.0, 1.0, 50.0), Vector3(3.0, 3.0, 3.0), Color(0.3, 0.3, 0.8))
	_build_ground()
