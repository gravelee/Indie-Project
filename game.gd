extends Node2D

# =============================================================================
# GAME.GD  —  main controller
#
# Responsibilities:
#   - Build the entire scene tree in code.
#   - Load the map from txt files.
#   - Rotate the camera when RMB is dragged.
#   - Update draw order (z-sort) every frame so sprites overlap correctly.
#
# Scene tree we build here:
#   Game (Node2D)          <- This script.
#   |-- TileMap            <- Terrain tiles (ground).
#   |-- Camera2D           <- Follows player, can rotate.
#   |-- CharacterBody2D    <- Player physics + movement  (player.gd).
#   |-- AnimatedSprite2D   <- Player visual sprite.
#   |-- StaticBody2D ...   <- One per bush (bush.gd), added at load time.
#   |-- CharacterBody2D .. <- One per creature  (creature.gd),  added at load time.
#   +-- CanvasLayer
#         |-- Node2D       <- HUD bars (hud.gd).
#         |-- Node2D       <- Floating combat numbers (combat_feedback.gd).
#         +-- Node2D       <- Debug stat panel (stat_panel.gd).
# =============================================================================

const TILE_SIZE 			:= 32
const Z_DEPTH_SCALE 		:= 32
const TERRAIN_Z 			:= -4096
const TILE_TYPE_MAP     	:= {2: "rat", 3: "snake"}

const ATTACK_RADIUS       := 96.0
const ATTACK_RADIUS_SQ    := ATTACK_RADIUS * ATTACK_RADIUS
const ATTACK_QUARTER_CONE := 45.0
const ATTACK_SEARCH_R     := 3   # ceili(ATTACK_RADIUS / TILE_SIZE)


# ── File paths ─────────────────────────────────────────────────────────────────

const PATH_PLAYER_SCRIPT          := "res://player.gd"
const PATH_HUD_SCRIPT             := "res://hud.gd"
const PATH_COMBAT_FEEDBACK_SCRIPT := "res://combat_feedback.gd"
const PATH_STAT_PANEL_SCRIPT      := "res://stat_panel.gd"
const PATH_DEBUG_OVERLAY_SCRIPT   := "res://debug_overlay.gd"
const PATH_BUSH_SCRIPT            := "res://bush.gd"
const PATH_CREATURE_SCRIPT		  := "res://creature.gd"
const PATH_TILESET        		  := "res://assets/tilemaps/leaf/leaf.png"
const PATH_MAP_TERRAIN    		  := "res://assets/maps/level_01/level_01_terrain.txt"
const PATH_MAP_ENTITIES   		  := "res://assets/maps/level_01/level_01_entities_test.txt"
const PATH_MAP_JSON       		  := "res://assets/maps/level_01/level_01.json"

# ── Camera rotation state ──────────────────────────────────────────────────────

var world_angle : float  = 0.0   # positive = world rotates clockwise
var rmb_held    : bool   = false
var last_mouse  : Vector2 = Vector2.ZERO

# _angle_dirty is set to true whenever world_angle changes.
var _angle_dirty : bool  = true

# Recomputed only when _angle_dirty is true.
var cached_sin_a : float = 0.0
var cached_cos_a : float = 1.0


# ── Node ───────────────────────────────────────────────────────────────────────

var tilemap           : TileMap				# init _build_scene(), set _load_terrain().
var camera            : Camera2D			# init _build_scene().
var player            : CharacterBody2D		# init _build_scene().
var player_sprite     : AnimatedSprite2D	# init _build_scene().
var weapon_sprite     : AnimatedSprite2D	# init _build_scene().
var hud               : Node2D				# init _build_scene().
var combat_feedback   : Node2D				# init _build_scene().
var stat_panel        : Node2D				# init _build_scene().
var debug_overlay     : Node2D				# init _build_scene().
var pathfinder        : Pathfinder			# init _build_pathfinder().
var rotatable_sprites : Array      = []		# init _spawn_bush().
var obstacle_map      : Dictionary = {}		# init _spawn_bush().
var creature_sprites  : Array      = []		# init _spawn_creature().
var creatures         : Array      = []		# init _spawn_creature().
var _creature_configs : Dictionary = {}   	# init _load_json().
var _map_cols         : int        = 0     	# set _load_terrain().
var _map_rows         : int        = 0     	# set _load_terrain().
var _creature_tile_set: Dictionary = {}    	# set _update_dynamic_blockers().
var _blocker_timer    : float      = 0.0   	# set _update_dynamic_blockers().


# =============================================================================
# LIFECYCLE
# =============================================================================

# INIT
func _ready() -> void:
	print("------------------- GAME INITIALIZATION --------------------")
	_build_scene()
	_load_json()
	_load_terrain()
	_build_pathfinder()
	_load_entities()
	
	hud.player_stats = player.stats

	debug_overlay.init(player, creatures, obstacle_map, pathfinder, _map_cols, _map_rows)

	hud.init(player, creatures)
	combat_feedback.init(player, creatures)
	stat_panel.init(player, creatures)
	stat_panel.debug_overlay = debug_overlay
	player.init()


# LOOP
func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		rmb_held = event.pressed
		if not rmb_held:
			last_mouse = Vector2.ZERO


# LOOP
func _process(delta: float) -> void:

	_rotate_camera()
	_update_sprites()
	_update_z_sort()
	_update_dynamic_blockers(delta)
	pathfinder.update(delta)
	_update_player_combat()
	
	if _angle_dirty:
		hud.set_world_angle(world_angle)
		combat_feedback.set_world_angle(world_angle)
		stat_panel.set_world_angle(world_angle)

	_angle_dirty = false


# =============================================================================
# SCENE CONSTRUCTION
# =============================================================================

# Called: _ready().
func _build_scene() -> void:

	tilemap = TileMap.new()
	tilemap.position = Vector2(-TILE_SIZE * 0.5, -TILE_SIZE * 0.5)
	tilemap.z_index = TERRAIN_Z
	tilemap.tile_set = _create_tileset()
	add_child(tilemap)

	camera = Camera2D.new()
	camera.ignore_rotation = false
	add_child(camera)

	player = CharacterBody2D.new()
	player.set_script(load(PATH_PLAYER_SCRIPT))
	var col_shape := CollisionShape2D.new()
	var shape      := CircleShape2D.new()
	shape.radius   = 30.0
	col_shape.shape = shape
	player.add_child(col_shape)
	add_child(player)

	player_sprite = AnimatedSprite2D.new()
	player_sprite.z_as_relative = false
	add_child(player_sprite)

	weapon_sprite = AnimatedSprite2D.new()
	weapon_sprite.z_as_relative = false
	add_child(weapon_sprite)

	player.sprite        = player_sprite
	player.weapon_sprite  = weapon_sprite
	player.load_animations()
	
	# attack signal is connected with _on_player_attack().
	player.attack.connect(_on_player_attack)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	hud = Node2D.new()
	hud.set_script(load(PATH_HUD_SCRIPT))
	hud_layer.add_child(hud)

	combat_feedback = Node2D.new()
	combat_feedback.set_script(load(PATH_COMBAT_FEEDBACK_SCRIPT))
	hud_layer.add_child(combat_feedback)

	stat_panel = Node2D.new()
	stat_panel.set_script(load(PATH_STAT_PANEL_SCRIPT))
	hud_layer.add_child(stat_panel)

	# World-space debug overlay — must be a direct child of game, not CanvasLayer.
	debug_overlay = Node2D.new()
	debug_overlay.set_script(load(PATH_DEBUG_OVERLAY_SCRIPT))
	add_child(debug_overlay)


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

	var p : Dictionary = data["player"]
	player.stats = Stats.new(p["str"], p["agi"], p["sta"], p["int"],
							 p["spr"], p["res"], p["def"], p["bms"], p["exp"])

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
		if _map_cols == 0:
			_map_cols = cols.size()
		for col in range(cols.size()):
			var tile_id    := int(cols[col])
			var atlas_col  := tile_id % 24
			var atlas_row  := tile_id / 24
			tilemap.set_cell(0, Vector2i(col, row), 0, Vector2i(atlas_col, atlas_row))
		row += 1
	_map_rows = row

	file.close()


# Called: _ready().
func _build_pathfinder() -> void:

	pathfinder = Pathfinder.new()
	pathfinder.build(_map_cols, _map_rows)


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
			elif tile_id in TILE_TYPE_MAP:    # 2 = rat, 3 = snake, ...
				_spawn_creature(world_pos, row, col, tile_id)
			elif tile_id == 101:              # 101 = bush
				_spawn_bush(world_pos)
		row += 1

	file.close()


# Called: _load_entities().
func _spawn_creature(world_pos: Vector2, row: int, col: int, tile_id: int) -> void:

	# Read the json file.
	var key       	:= Vector2i(row, col)
	if not _creature_configs.has(key):
		push_error("No JSON config for creature at row %d col %d." % [row, col])
		return
	var cfg       	: Dictionary = _creature_configs[key]
	var type_id 	: String     = TILE_TYPE_MAP[tile_id]
	if cfg["type"] != type_id:
		push_error("Type mismatch at row %d col %d: map=%s json=%s." % [row, col, type_id, cfg["type"]])
		return

	# Create and add creature as child.
	var creature  	:= CharacterBody2D.new()
	creature.set_script(load(PATH_CREATURE_SCRIPT))
	var col_shape	:= CollisionShape2D.new()
	var shape      	:= CircleShape2D.new()
	shape.radius   = 20.0
	col_shape.shape = shape
	creature.add_child(col_shape)
	creature.position = world_pos
	add_child(creature)

	# Init creature.
	creature.init(cfg, player, world_angle, pathfinder)

	# Creature.queue_free() also calls:
	creature.tree_exiting.connect(func():
		creature_sprites.erase(creature.sprite)
		creatures.erase(creature)
	)
	# Update lists.
	creature_sprites.append(creature.sprite)
	creatures.append(creature)


# Called: _load_entities().
func _spawn_bush(world_pos: Vector2) -> void:

	var bush     := StaticBody2D.new()
	var tile_key := Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)
	bush.set_script(load(PATH_BUSH_SCRIPT))
	bush.position = world_pos
	add_child(bush)   # triggers bush._ready() which creates its sprite + collision
	pathfinder.set_tile_solid(tile_key, true)
	bush.tree_exiting.connect(func():
		rotatable_sprites.erase(bush.sprite)
		obstacle_map.erase(tile_key)
		pathfinder.set_tile_solid(tile_key, false)
	)
	rotatable_sprites.append(bush.sprite)
	obstacle_map[tile_key] = bush


# Called: player._try_attack() who emits player.attack signal.
func _on_player_attack(world_pos: Vector2, facing_direction: Vector2) -> void:
	
	# Attackable obstacles are resolved here.
	var player_tile := Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)
	# 7x7 broad phase = 49 tiles to check.
	for dy in range(-ATTACK_SEARCH_R, ATTACK_SEARCH_R + 1):
		for dx in range(-ATTACK_SEARCH_R, ATTACK_SEARCH_R + 1):
			var key      := Vector2i(player_tile.x + dx, player_tile.y + dy)
			if not obstacle_map.has(key):
				continue
			var obstacle := obstacle_map[key] as StaticBody2D
			if not obstacle.alive:
				continue
			var to_obs : Vector2 = obstacle.position - world_pos
			# circle (r=3 tiles) = 29 tiles left.
			if to_obs.length_squared() > ATTACK_RADIUS_SQ:
				continue
			if to_obs != Vector2.ZERO:
				var deg := rad_to_deg(facing_direction.angle_to(to_obs.normalized()))
				# 45° cone ≈ 3-4 tiles left.
				if absf(deg) > ATTACK_QUARTER_CONE:
					continue
			obstacle.take_hit()

	# Collect all creatures inside players attack area.
	var creature_targets : Array = []
	for creature in creatures:
		if not creature.alive:
			continue
		var to_c : Vector2 = creature.position - world_pos
		if to_c.length_squared() > ATTACK_RADIUS_SQ:
			continue
		if to_c != Vector2.ZERO:
			var deg := rad_to_deg(facing_direction.angle_to(to_c.normalized()))
			if absf(deg) > ATTACK_QUARTER_CONE:
				continue
		creature_targets.append(creature)
	
	# Resolve the attack.
	player.resolve_attack(creature_targets)


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
	player_sprite.global_position  = player.global_position
	camera.global_position         = player.global_position
	if weapon_sprite.visible:
		weapon_sprite.global_position  = player.global_position
		# Sword rotation = camera counter-rotation + per-facing offset (updated every frame
		# because either world_angle or sword_facing_deg can change independently).
		weapon_sprite.rotation_degrees = -world_angle + player.sword_facing_deg

	# Only on rotation: update angles.
	if _angle_dirty:
		player_sprite.rotation_degrees = -world_angle
		camera.rotation_degrees        = -world_angle
		player.camera_angle            = world_angle
		for creature in creatures:
			creature.camera_angle = world_angle


# Called: _process().
func _update_z_sort() -> void:

	# Z-SORT  —  who draws on top of whom.
	# Depth formula = x*sin(angle) + y*cos(angle).
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
	if weapon_sprite.visible:
		var sword_center := player.global_position + Vector2(-48.0, -48.0).rotated(weapon_sprite.rotation)
		weapon_sprite.z_index = int((sword_center.x * cached_sin_a + sword_center.y * cached_cos_a) / Z_DEPTH_SCALE)
	for i in range(creatures.size()):
		var pos : Vector2 = (creatures[i] as Node2D).position
		creature_sprites[i].z_index = int((pos.x * cached_sin_a + pos.y * cached_cos_a) / Z_DEPTH_SCALE)


# Called: _process().
func _update_dynamic_blockers(delta: float) -> void:

	_blocker_timer += delta
	if _blocker_timer < 0.15:
		return
	_blocker_timer = 0.0
	_creature_tile_set.clear()
	for creature in creatures:
		var tile := Vector2i(
			int(creature.position.x) / TILE_SIZE, int(creature.position.y) / TILE_SIZE)
		_creature_tile_set[tile] = true
	pathfinder.set_dynamic_blockers(_creature_tile_set)


# Called: _process().
func _update_player_combat() -> void:

	var any_combat := false
	for creature in creatures:
		if creature.in_combat:
			any_combat = true
			break
	player.in_combat = any_combat
