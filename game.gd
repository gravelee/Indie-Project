extends Node2D

# =============================================================================
# GAME.GD  —  main controller
#
# Responsibilities:
#   - Build the entire scene tree in code (no visual editor needed)
#   - Load the map from txt files
#   - Rotate the camera when RMB is dragged
#   - Update draw order (z-sort) every frame so sprites overlap correctly
#
# Scene tree we build here:
#   Game (Node2D)          <- this script
#   |-- TileMap            <- terrain tiles (ground)
#   |-- Camera2D           <- follows player, can rotate
#   |-- CharacterBody2D    <- player physics + movement  (player.gd)
#   |-- AnimatedSprite2D   <- player visual sprite
#   |-- StaticBody2D ...   <- one per bush (bush.gd), added at load time
#   |-- CharacterBody2D .. <- one per rat  (rat.gd),  added at load time
#   +-- CanvasLayer
#         +-- Node2D       <- HUD bars (hud.gd)
# =============================================================================


# ── Constants ─────────────────────────────────────────────────────────────────

const TILE_SIZE := 32

# Pixel depths on a 100x100 map reach ~4525. Dividing by this keeps
# values inside Godot's hard z_index limit of +/-4096.
const Z_DEPTH_SCALE := 32

# Godot's minimum z_index. Pins terrain below all sprites, even when
# a sprite's depth goes negative (which happens at certain camera angles).
const TERRAIN_Z := -4096

# Melee attack reach and forward arc half-angle (degrees either side of facing).
const TILE_TYPE_MAP       := {2: "rat", 3: "snake"}

const ATTACK_RADIUS       := 96.0
const ATTACK_RADIUS_SQ    := ATTACK_RADIUS * ATTACK_RADIUS
const ATTACK_QUARTER_CONE := 45.0
const ATTACK_SEARCH_R     := 3   # ceili(ATTACK_RADIUS / TILE_SIZE)

# ── File paths ─────────────────────────────────────────────────────────────────

const PATH_PLAYER_SCRIPT  := "res://player.gd"
const PATH_HUD_SCRIPT     := "res://hud.gd"
const PATH_BUSH_SCRIPT    := "res://bush.gd"
const PATH_TILESET        := "res://assets/tilemaps/leaf/leaf.png"
const PATH_MAP_TERRAIN    := "res://assets/maps/level_01/level_01_terrain.txt"
const PATH_MAP_ENTITIES   := "res://assets/maps/level_01/level_01_other.txt"
const PATH_MAP_JSON       := "res://assets/maps/level_01/level_01.json"

# ── Camera rotation state ──────────────────────────────────────────────────────

var world_angle : float  = 0.0   # degrees; positive = world rotates clockwise
var rmb_held    : bool   = false
var last_mouse  : Vector2 = Vector2.ZERO

# _angle_dirty is set to true whenever world_angle changes.
# Functions that only need to run on rotation check this flag
# instead of recalculating every frame.
# Starts as true so the first frame always runs a full update.
var _angle_dirty : bool  = true

# Cached trig values for the current world_angle.
# Recomputed only when _angle_dirty is true.
# sin(0) = 0.0, cos(0) = 1.0 match the initial world_angle of 0.
var cached_sin_a : float = 0.0
var cached_cos_a : float = 1.0


# ── Node references (all created in _build_scene) ─────────────────────────────

var tilemap           : TileMap				# init _build_scene(), set _load_terrain().
var camera            : Camera2D			# init _build_scene().
var player            : CharacterBody2D		# init _build_scene().
var player_sprite     : AnimatedSprite2D	# init _build_scene().
var hud               : Node2D				# init _build_scene().
var rotatable_sprites : Array      = []		# init _spawn_bush().
var obstacle_map      : Dictionary = {}		# init _spawn_bush().
var creature_sprites  : Array      = []		# init _spawn_creature().
var creatures         : Array      = []		# init _spawn_creature().
var _creature_configs : Dictionary = {}   	# init _load_json().


# =============================================================================
# LIFECYCLE
# =============================================================================

# INIT
func _ready() -> void:

	_build_scene()
	_load_json()
	_load_terrain()
	_load_entities()
	hud.player_stats = player.stats


# LOOP
func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		rmb_held = event.pressed
		if not rmb_held:
			last_mouse = Vector2.ZERO


# LOOP
func _process(_delta: float) -> void:

	_rotate_camera()
	_update_sprites()
	_update_z_sort()
	_angle_dirty = false


# =============================================================================
# SCENE CONSTRUCTION
# Builds every node in code so we never need the visual editor.
# =============================================================================

# Called: _ready().
func _build_scene() -> void:

	# ── Terrain tilemap ────────────────────────────────────────────────────────
	# TERRAIN_Z keeps tiles always behind every sprite, even at negative depths.
	tilemap = TileMap.new()
	tilemap.z_index = TERRAIN_Z
	tilemap.tile_set = _create_tileset()
	add_child(tilemap)

	# ── Camera ─────────────────────────────────────────────────────────────────
	# ignore_rotation = false means the camera itself can tilt,
	# which rotates the entire view when we change camera.rotation_degrees.
	camera = Camera2D.new()
	camera.ignore_rotation = false
	add_child(camera)

	# ── Player physics body ────────────────────────────────────────────────────
	# CharacterBody2D handles movement and collision.
	# The visible sprite is a separate node (see below) so it can be
	# z-sorted alongside bushes independently of the physics body.
	player = CharacterBody2D.new()
	player.set_script(load(PATH_PLAYER_SCRIPT))
	var col_shape := CollisionShape2D.new()
	var shape      := CircleShape2D.new()
	shape.radius   = 30.0
	col_shape.shape = shape
	player.add_child(col_shape)
	add_child(player)

	# ── Player visual sprite ───────────────────────────────────────────────────
	# Kept separate from the physics body so z_index sorting works correctly.
	# z_as_relative = false means this node's z_index is absolute, compared
	# directly against bush sprites on the same scale.
	player_sprite = AnimatedSprite2D.new()
	player_sprite.z_as_relative = false
	add_child(player_sprite)

	player.sprite = player_sprite
	player.load_animations()
	player.attacked.connect(_on_player_attacked)

	# ── HUD ────────────────────────────────────────────────────────────────────
	# CanvasLayer keeps the bars on screen regardless of camera position/rotation.
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Node2D.new()
	hud.set_script(load(PATH_HUD_SCRIPT))
	hud_layer.add_child(hud)


# Called: _build_scene().
func _create_tileset() -> TileSet:

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var texture : Texture2D = load(PATH_TILESET)
	var source  := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Register every tile in the atlas so set_cell() can place them.
	var cols := texture.get_width()  / TILE_SIZE
	var rows := texture.get_height() / TILE_SIZE
	for row in range(rows):
		for col in range(cols):
			source.create_tile(Vector2i(col, row))

	tileset.add_source(source, 0)   # source id 0 matches the set_cell() calls below
	return tileset


# =============================================================================
# MAP LOADING
# Both txt files are grids of comma-separated numbers.
# =============================================================================

# Called: _ready().
func _load_json() -> void:

	var file := FileAccess.open(PATH_MAP_JSON, FileAccess.READ)
	if file == null:
		push_error("Cannot open level_01.json.")
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		push_error("Failed to parse level_01.json.")
		return

	# Apply player stats from JSON.
	var p : Dictionary = data["player"]
	player.stats = Stats.new(p["str"], p["agi"], p["sta"], p["int"],
							 p["spr"], p["res"], p["def"], true)

	# Build creature config lookup keyed by tile coordinates.
	for entry in data["creatures"]:
		_creature_configs[Vector2i(entry["row"], entry["col"])] = entry


# Called: _ready().
func _load_terrain() -> void:

	var file := FileAccess.open(PATH_MAP_TERRAIN, FileAccess.READ)
	if file == null:
		push_error("Cannot open terrain file.")
		return

	var row := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var cols := line.split(",")
		for col in range(cols.size()):
			var tile_id    := int(cols[col])
			var atlas_col  := tile_id % 24
			var atlas_row  := tile_id / 24
			tilemap.set_cell(0, Vector2i(col, row), 0, Vector2i(atlas_col, atlas_row))
		row += 1

	file.close()


# Called: _ready().
func _load_entities() -> void:

	var file := FileAccess.open(PATH_MAP_ENTITIES, FileAccess.READ)
	if file == null:
		push_error("Cannot open entities file.")
		return

	var row := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var cols := line.split(",")
		for col in range(cols.size()):
			var tile_id   := int(cols[col])
			var world_pos := Vector2(col * TILE_SIZE, row * TILE_SIZE)

			if tile_id == 1:                  # 1 = player spawn
				player.position = world_pos
			elif tile_id in TILE_TYPE_MAP:    # 2 = rat, 3 = snake, …
				_spawn_creature(world_pos, row, col, tile_id)
			elif tile_id == 101:              # 101 = bush
				_spawn_bush(world_pos)
		row += 1

	file.close()


# Called: _load_entities().
func _spawn_creature(world_pos: Vector2, row: int, col: int, tile_id: int) -> void:

	var key       := Vector2i(row, col)
	if not _creature_configs.has(key):
		push_error("No JSON config for creature at row %d col %d." % [row, col])
		return
	var cfg       : Dictionary = _creature_configs[key]
	var type_name : String     = TILE_TYPE_MAP[tile_id]
	if cfg["type"] != type_name:
		push_error("Type mismatch at row %d col %d: map=%s json=%s." % [row, col, type_name, cfg["type"]])
		return

	var creature  := CharacterBody2D.new()
	creature.set_script(load("res://" + type_name + ".gd"))
	var col_shape := CollisionShape2D.new()
	var shape      := CircleShape2D.new()
	shape.radius   = 20.0
	col_shape.shape = shape
	creature.add_child(col_shape)
	creature.position = world_pos
	add_child(creature)   # triggers _ready() which creates sprite

	creature.configure(cfg, world_pos)
	creature.player       = player
	creature.camera_angle = world_angle

	creature.tree_exiting.connect(func():
		creature_sprites.erase(creature.sprite)
		creatures.erase(creature)
	)
	creature_sprites.append(creature.sprite)
	creatures.append(creature)


# Called: _load_entities().
func _spawn_bush(world_pos: Vector2) -> void:

	var bush     := StaticBody2D.new()
	var tile_key := Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)
	bush.set_script(load(PATH_BUSH_SCRIPT))
	bush.position = world_pos
	add_child(bush)   # triggers bush._ready() which creates its sprite + collision
	bush.tree_exiting.connect(func():
		rotatable_sprites.erase(bush.sprite)
		obstacle_map.erase(tile_key)
	)
	rotatable_sprites.append(bush.sprite)
	obstacle_map[tile_key] = bush


# Called: player.attacked signal.
func _on_player_attacked(world_pos: Vector2, facing_dir: Vector2) -> void:

	# Spatial hash lookup — only tiles within ATTACK_RADIUS are checked.
	# O(search_area) not O(n_obstacles).
	# 7x7 broad phase = 49 tiles → circle (r=3 tiles, dx²+dy²≤9) = 29 → 90° cone (±45°) ≈ 9 tiles.
	var player_tile := Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)

	for dr in range(-ATTACK_SEARCH_R, ATTACK_SEARCH_R + 1):
		for dc in range(-ATTACK_SEARCH_R, ATTACK_SEARCH_R + 1):
			var key      := Vector2i(player_tile.x + dr, player_tile.y + dc)
			if not obstacle_map.has(key):
				continue
			var obstacle := obstacle_map[key] as StaticBody2D
			if not obstacle.alive:
				continue
			var to_obs : Vector2 = obstacle.position - world_pos
			if to_obs.length_squared() > ATTACK_RADIUS_SQ:
				continue
			# Angle check — obstacle must be within the forward arc.
			if to_obs != Vector2.ZERO:
				var deg := rad_to_deg(facing_dir.angle_to(to_obs.normalized()))
				if absf(deg) > ATTACK_QUARTER_CONE:
					continue
			obstacle.take_hit()


# =============================================================================
# PER-FRAME UPDATES
# =============================================================================

# Called: _process().
func _rotate_camera() -> void:

	# Drag RMB left/right to rotate the world view.

	if not rmb_held:
		return

	var mouse := get_viewport().get_mouse_position()

	if last_mouse == Vector2.ZERO:
		last_mouse = mouse
		return

	var delta_x := mouse.x - last_mouse.x
	if abs(delta_x) >= 1.0:
		world_angle  = fmod(world_angle + delta_x * 0.5, 360.0)
		_angle_dirty = true

	last_mouse = mouse


# Called: _process().
func _update_sprites() -> void:

	# Always: keep sprite and camera locked to the physics body position.
	player_sprite.global_position = player.global_position
	camera.global_position        = player.global_position

	# Only on rotation: update angles.
	if _angle_dirty:
		player_sprite.rotation_degrees = -world_angle
		camera.rotation_degrees        = -world_angle
		player.camera_angle            = world_angle
		for creature in creatures:
			creature.camera_angle = world_angle


# =============================================================================
# Z-SORT  —  who draws on top of whom
#
# depth = x*sin(angle) + y*cos(angle) projects each world position onto the
# current screen-down direction. Higher depth = lower on screen = drawn on top.
# Dividing by Z_DEPTH_SCALE keeps values inside Godot's z_index limit of +/-4096.
# =============================================================================

# Called: _process().
func _update_z_sort() -> void:

	# Only on rotation: recompute trig, rotate all entity sprites, update depths.
	if _angle_dirty:
		var rad      := deg_to_rad(world_angle)
		cached_sin_a  = sin(rad)
		cached_cos_a  = cos(rad)
		for sprite in rotatable_sprites:
			var pos             := (sprite.get_parent() as Node2D).position
			sprite.rotation_degrees = -world_angle
			sprite.z_index          = int((pos.x * cached_sin_a + pos.y * cached_cos_a) / Z_DEPTH_SCALE)
		for sprite in creature_sprites:
			sprite.rotation_degrees = -world_angle

	# Always: player and creatures move every frame so depth must stay current.
	player_sprite.z_index = int((player.position.x * cached_sin_a + player.position.y * cached_cos_a) / Z_DEPTH_SCALE)
	for sprite in creature_sprites:
		var pos := (sprite.get_parent() as Node2D).position
		sprite.z_index = int((pos.x * cached_sin_a + pos.y * cached_cos_a) / Z_DEPTH_SCALE)
