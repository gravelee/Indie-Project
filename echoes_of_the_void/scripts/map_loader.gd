class_name MapLoader
extends RefCounted

# =============================================================================
# MAP LOADER — streaming terrain + entity system.
#
# Terrain: one composite PlaneMesh covering the full map (1 draw call, loaded
# once on startup). Never streamed — cheap enough to keep always.
#
# Props + Creatures: streamed in/out in a LOAD_WINDOW × LOAD_WINDOW tile region
# centered on the player. Re-evaluated every STREAM_TRIGGER_TILES tile of player
# movement. Edges fade in/out smoothly (FADE_DURATION seconds).
#
# Tree collision: all non-destructible static props share ONE StaticBody3D.
# This collapses hundreds of individual BVH broadphase entries into one.
#
# Entity reaction: damageable props carry a detection shape on PROP_REACT_LAYER.
# Entity Area3D zones (player/creature, radius 0.35) call trigger_reaction()
# on body_entered. Zero per-prop _process polling.
#
# Usage (main.gd):
#   map_loader = MapLoader.new()
#   map_loader.load_terrain(self)
#   var spawn := map_loader.get_player_spawn()
#   # ... build player, camera_rig ...
#   map_loader.init_streaming(self, camera_rig, player_body)
#
#   # In _process:
#   map_loader.update(player_body.global_position)
# =============================================================================

const TILE_PIXELS          : int   = 32
const TILE_WORLD           : float = 1.0
const MAP_COLS             : int   = 100
const MAP_ROWS             : int   = 100

# 75×75 tile window around the player.
const LOAD_WINDOW          : int   = 75
# Re-evaluate window when player moves this many tiles in any axis.
const STREAM_TRIGGER_TILES : int   = 5
# Max prop/creature nodes spawned per frame during streaming catch-up.
const MAX_SPAWNS_PER_FRAME : int   = 15
# Fade-in / fade-out duration in seconds.
const FADE_DURATION        : float = 0.4

const PIXEL_SIZE : float = 1.0 / float(TILE_PIXELS)

# ── Layer definitions ──────────────────────────────────────────────────────────
# Each entry: [tileset_path, csv_path, tiles_per_row, use_blend]
const TERRAIN_LAYERS : Array = [
	["res://assets/tilemaps/terrain/dark_dirt.png",     "res://assets/maps/level_01/_dark_dirt.csv",    3,  false],
	["res://assets/tilemaps/terrain/dark_grass.png",    "res://assets/maps/level_01/_dark_grass.csv",   5,  true],
	["res://assets/tilemaps/sub_terrain/rock_path.png", "res://assets/maps/level_01/_rock_path.csv",    10, true],
	["res://assets/tilemaps/sub_terrain/flora.png",     "res://assets/maps/level_01/_flora.csv",        5,  true],
]

const ENTITIES_CSV : String = "res://assets/maps/level_01/_entities.csv"

# ── Prop table ─────────────────────────────────────────────────────────────────
# tile_id → [cols, rows, sprite_type, sprite_name, height_ext, variant_count, has_collision, destructible]
const PROP_TABLE : Dictionary = {
	101: [1, 1, "bush", "classic", 0,  5, false, true ],   # 1×1 — no collision (too small)
	102: [2, 2, "bush", "classic", 0,  5, true,  true ],
	103: [3, 3, "bush", "classic", 0,  5, true,  true ],
	104: [1, 1, "bush", "classic", 0, -1, false, true ],
	105: [2, 2, "bush", "classic", 0, -1, true,  true ],
	106: [3, 3, "bush", "classic", 0, -1, true,  true ],
	107: [1, 1, "bush", "classic", 0, -2, false, true ],
	108: [2, 2, "bush", "classic", 0, -2, true,  true ],
	109: [3, 3, "bush", "classic", 0, -2, true,  true ],
	110: [1, 1, "bush", "classic", 0, -3, false, true ],
	111: [2, 2, "bush", "classic", 0, -3, true,  true ],
	112: [3, 3, "bush", "classic", 0, -3, true,  true ],
	113: [1, 1, "bush", "classic", 0, -4, false, true ],
	114: [2, 2, "bush", "classic", 0, -4, true,  true ],
	115: [3, 3, "bush", "classic", 0, -4, true,  true ],
	116: [1, 1, "bush", "classic", 0, -5, false, true ],
	117: [2, 2, "bush", "classic", 0, -5, true,  true ],
	118: [3, 3, "bush", "classic", 0, -5, true,  true ],
	119: [1, 1, "bush", "leafy",   0,  1, false, true ],
	120: [2, 2, "bush", "leafy",   0,  1, true,  true ],
	121: [3, 3, "bush", "leafy",   0,  1, true,  true ],
	122: [1, 1, "bush", "spiky",   0,  1, false, true ],
	123: [2, 2, "bush", "spiky",   0,  1, true,  true ],
	124: [3, 3, "bush", "spiky",   0,  1, true,  true ],
	125: [1, 1, "tree", "mystic",  0,  1, true,  false],  # 1x1
	126: [1, 1, "tree", "mystic",  1,  1, true,  false],  # 1x1_h1 (new middle height)
	127: [1, 1, "tree", "mystic",  2,  1, true,  false],  # 1x1_h2 (old h1, renamed)
	128: [2, 2, "tree", "mystic",  0,  1, true,  false],  # 2x2
	129: [2, 2, "tree", "mystic",  1,  1, true,  false],  # 2x2_h1
	130: [2, 2, "tree", "mystic",  2,  1, true,  false],  # 2x2_h2
	131: [3, 2, "tree", "mystic",  0,  1, true,  false],  # 3x2
	132: [3, 2, "tree", "mystic",  1,  1, true,  false],  # 3x2_h1
	133: [3, 2, "tree", "mystic",  2,  1, true,  false],  # 3x2_h2
	134: [1, 1, "grass", "classic", 0, 1, false, true ],  # 1x1
	135: [2, 1, "grass", "classic", 0, 1, false, true ],  # 2x1
	136: [3, 1, "grass", "classic", 0, 1, false, true ],  # 3x1
}

# Creature defaults: tile_id → [type, stat_id, aggression, has_home, can_wander]
const CREATURE_TABLE : Dictionary = {
	2: ["rat",   "rat_common",   "hostile", true,  true ],
	3: ["snake", "snake_common", "hostile", false, true ],
}

# ── Scan results (spatial grids, built once at startup) ───────────────────────
var _player_spawn_col : int        = 57
var _player_spawn_row : int        = 64
var _prop_grid        : Dictionary = {}   # Vector2i → Array (PROP_TABLE entry)
var _creature_grid    : Dictionary = {}   # Vector2i → Array (CREATURE_TABLE entry)

# ── Streaming state ────────────────────────────────────────────────────────────
var _parent      : Node3D           = null
var _camera_rig  : Node3D           = null
var _player_body : CharacterBody3D  = null

# Currently spawned nodes
var _loaded_props     : Dictionary  = {}   # Vector2i → WorldProp node
var _loaded_creatures : Dictionary  = {}   # Vector2i → CharacterBody3D node
var _fading_props     : Dictionary  = {}   # Vector2i → WorldProp node (fading out, slot cleared)

# Shared collision for non-destructible props (trees) — one BVH entry for all
var _tree_col_body  : StaticBody3D  = null
var _tree_shapes    : Dictionary    = {}   # Vector2i → CollisionShape3D on _tree_col_body

# Window tracking
var _current_window   : Dictionary  = {c0=0, r0=0, c1=0, r1=0}
var _last_player_tile : Vector2i    = Vector2i(-9999, -9999)
var _initial_load     : bool        = false   # true during first _spawn_window_contents call

# Deferred spawn queue — processed at MAX_SPAWNS_PER_FRAME per update() call
var _spawn_queue : Array = []   # Array of {is_prop: bool, key: Vector2i}

var _scanned : bool = false


# =============================================================================
# PUBLIC API
# =============================================================================

func load_terrain(parent: Node3D) -> void:
	_ensure_scanned()
	_build_composite_terrain(parent)
	_build_ground_collision(parent)


func get_player_spawn() -> Vector3:
	_ensure_scanned()
	return Vector3(
		(float(_player_spawn_col) + 0.5) * TILE_WORLD,
		0.0,
		(float(_player_spawn_row) + 0.5) * TILE_WORLD
	)


# Call after building player + camera_rig. Replaces old spawn_entities().
func init_streaming(parent: Node3D, camera_rig: Node3D, player_body: CharacterBody3D) -> void:
	_ensure_scanned()
	_parent      = parent
	_camera_rig  = camera_rig
	_player_body = player_body

	# One shared static body for all tree collision shapes.
	# Each tree adds a CylinderShape3D here instead of owning a StaticBody3D.
	_tree_col_body      = StaticBody3D.new()
	_tree_col_body.name = "TreeCollision"
	parent.add_child(_tree_col_body)

	var spawn_tile    : Vector2i  = _world_to_tile(get_player_spawn())
	_current_window   = _compute_window(spawn_tile)
	_last_player_tile = spawn_tile

	# Spawn all initial-window contents immediately — no fade, no queue.
	_initial_load = true
	_spawn_window_contents(_current_window)
	_initial_load = false


# Call from main._process every frame.
func update(player_world_pos: Vector3) -> void:
	_process_queues()

	var player_tile : Vector2i = _world_to_tile(player_world_pos)
	var dx          : int      = abs(player_tile.x - _last_player_tile.x)
	var dy          : int      = abs(player_tile.y - _last_player_tile.y)
	if dx >= STREAM_TRIGGER_TILES or dy >= STREAM_TRIGGER_TILES:
		_last_player_tile = player_tile
		var new_win : Dictionary = _compute_window(player_tile)
		_update_window(new_win)
		_current_window = new_win


# =============================================================================
# SCAN — parse full CSV into spatial grids (runs once, lazy)
# =============================================================================

func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	_scan_entities_csv()


func _scan_entities_csv() -> void:
	var file := FileAccess.open(ENTITIES_CSV, FileAccess.READ)
	if file == null:
		return
	var map_row : int = 0
	while not file.eof_reached():
		var line : String = file.get_line().strip_edges()
		if line == "":
			continue
		var tokens : PackedStringArray = line.split(",")
		for map_col : int in range(tokens.size()):
			var tile_id : int = int(tokens[map_col])
			if tile_id == 1:
				_player_spawn_col = map_col
				_player_spawn_row = map_row
			elif CREATURE_TABLE.has(tile_id):
				_creature_grid[Vector2i(map_col, map_row)] = CREATURE_TABLE[tile_id]
			elif PROP_TABLE.has(tile_id):
				_prop_grid[Vector2i(map_col, map_row)] = PROP_TABLE[tile_id]
		map_row += 1
	file.close()


# =============================================================================
# TERRAIN — composite PlaneMesh for the full map (built once, never streamed)
# =============================================================================

func _build_composite_terrain(parent: Node3D) -> void:
	var img_w     : int   = MAP_COLS * TILE_PIXELS
	var img_h     : int   = MAP_ROWS * TILE_PIXELS
	var composite : Image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)

	for layer : Array in TERRAIN_LAYERS:
		var tileset_path : String = layer[0]
		var csv_path     : String = layer[1]
		var row_width    : int    = layer[2]
		var use_blend    : bool   = layer[3]
		_blit_layer(composite, tileset_path, csv_path, row_width, use_blend, MAP_COLS, MAP_ROWS)

	var tex : ImageTexture = ImageTexture.create_from_image(composite)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture    = tex
	mat.texture_filter    = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.flags_transparent = false
	mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED

	var plane := PlaneMesh.new()
	plane.size = Vector2(float(MAP_COLS) * TILE_WORLD, float(MAP_ROWS) * TILE_WORLD)

	var vis := MeshInstance3D.new()
	vis.name              = "Terrain"
	vis.mesh              = plane
	vis.material_override = mat
	vis.position          = Vector3(
		float(MAP_COLS) * 0.5 * TILE_WORLD,
		0.0,
		float(MAP_ROWS) * 0.5 * TILE_WORLD
	)
	parent.add_child(vis)


func _blit_layer(composite: Image, tileset_path: String, csv_path: String,
		row_width: int, use_blend: bool, load_cols: int, load_rows: int) -> void:
	if not FileAccess.file_exists(tileset_path):
		push_warning("MapLoader: tileset not found: " + tileset_path)
		return
	if not FileAccess.file_exists(csv_path):
		push_warning("MapLoader: CSV not found: " + csv_path)
		return

	var ts_tex : Texture2D = load(tileset_path) as Texture2D
	if ts_tex == null:
		return
	var ts_img : Image = ts_tex.get_image()
	ts_img.convert(Image.FORMAT_RGBA8)
	var ts_w   : int   = ts_img.get_width()
	var ts_h   : int   = ts_img.get_height()

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return

	var map_row : int = 0
	while not file.eof_reached():
		var line : String = file.get_line().strip_edges()
		if line == "":
			continue
		if map_row >= load_rows:
			break
		var tokens  : PackedStringArray = line.split(",")
		var img_row : int               = map_row
		for map_col : int in range(mini(load_cols, tokens.size())):
			var tile_id : int = int(tokens[map_col])
			if tile_id < 0:
				continue
			var ts_col : int = tile_id % row_width
			var ts_row : int = tile_id / row_width
			var src_x  : int = ts_col * TILE_PIXELS
			var src_y  : int = ts_row * TILE_PIXELS
			if src_x + TILE_PIXELS > ts_w or src_y + TILE_PIXELS > ts_h:
				continue
			var dst_x    : int      = map_col * TILE_PIXELS
			var dst_y    : int      = img_row * TILE_PIXELS
			var src_rect : Rect2i   = Rect2i(src_x, src_y, TILE_PIXELS, TILE_PIXELS)
			var dst_pos  : Vector2i = Vector2i(dst_x, dst_y)
			if use_blend:
				composite.blend_rect(ts_img, src_rect, dst_pos)
			else:
				composite.blit_rect(ts_img, src_rect, dst_pos)
		map_row += 1
	file.close()


func _build_ground_collision(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)
	parent.add_child(body)


# =============================================================================
# STREAMING — window management
# =============================================================================

func _world_to_tile(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / TILE_WORLD)),
		int(floor(world_pos.z / TILE_WORLD))
	)


func _compute_window(player_tile: Vector2i) -> Dictionary:
	var half : int = LOAD_WINDOW / 2
	var c0   : int = clampi(player_tile.x - half, 0, MAP_COLS)
	var r0   : int = clampi(player_tile.y - half, 0, MAP_ROWS)
	var c1   : int = clampi(c0 + LOAD_WINDOW, 0, MAP_COLS)
	var r1   : int = clampi(r0 + LOAD_WINDOW, 0, MAP_ROWS)
	# Re-clamp start in case end hit the map boundary
	c0 = clampi(c1 - LOAD_WINDOW, 0, MAP_COLS)
	r0 = clampi(r1 - LOAD_WINDOW, 0, MAP_ROWS)
	return {c0=c0, r0=r0, c1=c1, r1=r1}


func _in_window(key: Vector2i, win: Dictionary) -> bool:
	return key.x >= win.c0 and key.x < win.c1 and key.y >= win.r0 and key.y < win.r1


# Spawn everything in window immediately (used for initial load only).
func _spawn_window_contents(win: Dictionary) -> void:
	for row : int in range(win.r0, win.r1):
		for col : int in range(win.c0, win.c1):
			var key := Vector2i(col, row)
			if _prop_grid.has(key):
				_do_spawn_prop(key, _prop_grid[key])
			if _creature_grid.has(key):
				_do_spawn_creature(key, _creature_grid[key])


# Called when player crosses STREAM_TRIGGER_TILES boundary.
func _update_window(new_win: Dictionary) -> void:
	# Despawn props/creatures that left the new window
	for key : Vector2i in _loaded_props.keys():
		if not _in_window(key, new_win):
			_start_despawn_prop(key)
	for key : Vector2i in _loaded_creatures.keys():
		if not _in_window(key, new_win):
			_start_despawn_creature(key)

	# Queue spawns for tiles newly inside the window.
	# Only iterate the edge strips that are new — NOT the full 75×75 grid.
	# Full-window fallback only when windows don't overlap (e.g. teleport).
	_queue_new_window_spawns(new_win)


func _queue_new_window_spawns(new_win: Dictionary) -> void:
	var old : Dictionary = _current_window
	# No overlap (e.g. player teleported) — fall back to full new window.
	if new_win.c1 <= old.c0 or new_win.c0 >= old.c1 \
			or new_win.r1 <= old.r0 or new_win.r0 >= old.r1:
		_queue_tile_range(new_win.c0, new_win.c1, new_win.r0, new_win.r1)
		return
	# Top strip (rows above old window)
	if new_win.r0 < old.r0:
		_queue_tile_range(new_win.c0, new_win.c1, new_win.r0, mini(old.r0, new_win.r1))
	# Bottom strip (rows below old window)
	if new_win.r1 > old.r1:
		_queue_tile_range(new_win.c0, new_win.c1, maxi(old.r1, new_win.r0), new_win.r1)
	# Middle rows (only new left/right columns, not corners already counted above)
	var mid_r0 : int = maxi(new_win.r0, old.r0)
	var mid_r1 : int = mini(new_win.r1, old.r1)
	if mid_r0 < mid_r1:
		if new_win.c0 < old.c0:
			_queue_tile_range(new_win.c0, mini(old.c0, new_win.c1), mid_r0, mid_r1)
		if new_win.c1 > old.c1:
			_queue_tile_range(maxi(old.c1, new_win.c0), new_win.c1, mid_r0, mid_r1)


func _queue_tile_range(c0: int, c1: int, r0: int, r1: int) -> void:
	for row : int in range(r0, r1):
		for col : int in range(c0, c1):
			var key := Vector2i(col, row)
			if _prop_grid.has(key) \
					and not _loaded_props.has(key) \
					and not _fading_props.has(key):
				_spawn_queue.append({is_prop=true, key=key})
			if _creature_grid.has(key) and not _loaded_creatures.has(key):
				_spawn_queue.append({is_prop=false, key=key})


func _process_queues() -> void:
	var count : int = 0
	while not _spawn_queue.is_empty() and count < MAX_SPAWNS_PER_FRAME:
		var entry : Dictionary = _spawn_queue.pop_front()
		var key   : Vector2i   = entry.key
		if entry.is_prop:
			if _prop_grid.has(key) \
					and not _loaded_props.has(key) \
					and not _fading_props.has(key):
				_do_spawn_prop(key, _prop_grid[key])
		else:
			if _creature_grid.has(key) and not _loaded_creatures.has(key):
				_do_spawn_creature(key, _creature_grid[key])
		count += 1


# =============================================================================
# SPAWN / DESPAWN
# =============================================================================

func _do_spawn_prop(key: Vector2i, pd: Array) -> void:
	if _loaded_props.has(key) or _fading_props.has(key):
		return

	var map_col      : int    = key.x
	var map_row      : int    = key.y
	var prop_cols    : int    = pd[0]
	var prop_rows    : int    = pd[1]
	var sprite_type  : String = pd[2]
	var sprite_name  : String = pd[3]
	var height_ext   : int    = pd[4]
	var variant_cnt  : int    = pd[5]
	var has_coll     : bool   = pd[6]
	var destructible : bool   = pd[7]

	var script_path : String
	if not destructible:
		script_path = "res://scripts/props/world_prop.gd"
	elif sprite_type == "grass":
		script_path = "res://scripts/props/terrain_prop.gd"
	else:
		script_path = "res://scripts/props/obstacle_prop.gd"

	var prop : WorldProp = WorldProp.new()
	prop.set_script(load(script_path))
	prop.cols          = prop_cols
	prop.rows          = prop_rows
	prop.sprite_type   = sprite_type
	prop.sprite_name   = sprite_name
	prop.height_ext    = height_ext
	prop.variant_count = variant_cnt
	# Trees: collision goes to _tree_col_body, not to the prop itself.
	# The prop StaticBody3D without shapes has no BVH entry — negligible overhead.
	prop.has_collision = has_coll and destructible

	var world_x : float = (float(map_col) + float(prop_cols) * 0.5) * TILE_WORLD
	var world_z : float = (float(map_row) + float(prop_rows) * 0.5) * TILE_WORLD
	prop.position = Vector3(world_x, 0.0, world_z)

	# Canvas padding — must be set before add_child() triggers _ready()
	if sprite_type == "tree":
		prop._idle_blit_y     = prop_rows * WorldProp.TILE_SIZE / 4
		prop._canvas_add_rows = prop_rows * WorldProp.TILE_SIZE / 2

	_parent.add_child(prop)

	# Fade in (skipped during initial load so first frame shows world fully)
	if not _initial_load and prop.sprite != null:
		prop.sprite.modulate.a = 0.0
		var tw := prop.create_tween()
		tw.tween_property(prop.sprite, "modulate:a", 1.0, FADE_DURATION)

	_loaded_props[key] = prop

	# Trees: add a CylinderShape3D to the shared body instead of per-prop collision.
	# One BVH entry covers all tree shapes — broadphase cost drops from 547 to 1.
	if not destructible and has_coll and _tree_col_body != null:
		var col := CollisionShape3D.new()
		var shp := CylinderShape3D.new()
		shp.radius    = 11.0 * float(mini(prop_cols, prop_rows)) * PIXEL_SIZE
		shp.height    = 1.0
		col.position  = Vector3(world_x, 0.5, world_z)
		col.shape     = shp
		_tree_col_body.add_child(col)
		_tree_shapes[key] = col


func _do_spawn_creature(key: Vector2i, cd: Array) -> void:
	if _loaded_creatures.has(key):
		return

	var map_col : int = key.x
	var map_row : int = key.y
	var body := CharacterBody3D.new()
	body.name     = cd[0].capitalize()
	body.position = Vector3(
		(float(map_col) + 0.5) * TILE_WORLD,
		0.0,
		(float(map_row) + 0.5) * TILE_WORLD
	)
	body.set_script(load("res://scripts/creature.gd"))
	_parent.add_child(body)
	body.call("init", cd[0], cd[1], _camera_rig, _player_body, cd[2], cd[3], cd[4])

	if not _initial_load:
		var cr_sprite : AnimatedSprite3D = body.get("sprite") as AnimatedSprite3D
		if cr_sprite != null:
			cr_sprite.modulate.a = 0.0
			var tw := body.create_tween()
			tw.tween_property(cr_sprite, "modulate:a", 1.0, FADE_DURATION)

	_loaded_creatures[key] = body


func _start_despawn_prop(key: Vector2i) -> void:
	var prop : Node = _loaded_props.get(key, null)
	if prop == null or not is_instance_valid(prop):
		_loaded_props.erase(key)
		return
	# Move to fading dict immediately so the slot is free for re-spawning
	_loaded_props.erase(key)
	_fading_props[key] = prop

	var prop_sprite : AnimatedSprite3D = prop.get("sprite") as AnimatedSprite3D
	var tw := prop.create_tween()
	if prop_sprite != null:
		tw.tween_property(prop_sprite, "modulate:a", 0.0, FADE_DURATION)
	tw.tween_callback(func() -> void:
		_fading_props.erase(key)
		if _tree_shapes.has(key):
			_tree_shapes[key].queue_free()
			_tree_shapes.erase(key)
		if is_instance_valid(prop):
			prop.queue_free()
	)# discrete steps: 5,6,7,8,9,10,11,12,13,14,15


func _start_despawn_creature(key: Vector2i) -> void:
	var body : Node = _loaded_creatures.get(key, null)
	if body == null or not is_instance_valid(body):
		_loaded_creatures.erase(key)
		return
	_loaded_creatures.erase(key)

	var cr_sprite : AnimatedSprite3D = body.get("sprite") as AnimatedSprite3D
	var tw := body.create_tween()
	if cr_sprite != null:
		tw.tween_property(cr_sprite, "modulate:a", 0.0, FADE_DURATION)
	tw.tween_callback(func() -> void:
		if is_instance_valid(body):
			body.queue_free()
	)
