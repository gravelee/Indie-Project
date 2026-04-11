extends Node2D

# Camera rotation
var world_angle: float = 0.0
var rmb_held: bool = false
var rmb_last_mouse: Vector2 = Vector2.ZERO

@onready var world: TileMap = $World
@onready var camera: Camera2D = $Camera
@onready var player: CharacterBody2D = $Player

const TILE_SIZE = 32

func _ready() -> void:
	_load_terrain()
	player.position = Vector2(50 * 32, 50 * 32)  # middle of 100x100 map
	var screen_size = get_viewport().get_visible_rect().size
	$CanvasLayer/PlayerSprite.position = screen_size / 2.0

func _process(delta: float) -> void:
	_handle_camera_rotation()
	player.camera_angle = world_angle
	camera.global_position = player.global_position
	#print("FPS: ", Engine.get_frames_per_second(), "  angle: ", world_angle)

func _handle_camera_rotation() -> void:
	
	if not rmb_held:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	
	if rmb_last_mouse == Vector2.ZERO:
		rmb_last_mouse = mouse_pos
		return

	var delta_x = mouse_pos.x - rmb_last_mouse.x

	if abs(delta_x) >= 1.0:
		world_angle = fmod(world_angle + delta_x * 0.5, 360.0)
		camera.rotation_degrees = -world_angle

	rmb_last_mouse = mouse_pos

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rmb_held = event.pressed
			if not rmb_held:
				rmb_last_mouse = Vector2.ZERO

func _load_terrain() -> void:
	
	var file = FileAccess.open("res://level_01_terrain.txt", FileAccess.READ)
	
	if file == null:
		print("Could not open terrain file: ", FileAccess.get_open_error())
		return
		
	print("File opened successfully")

	var rows = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		var cols = line.split(",")
		rows.append(cols)
	file.close()

	# Transpose — same as pygame (grid[x][y])
	for y in range(rows.size()):
		for x in range(rows[y].size()):
			var tile_id = int(rows[y][x])
			world.set_cell(0, Vector2i(x, y), 0, Vector2i(tile_id % 24, tile_id / 24))
