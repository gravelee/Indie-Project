class_name Pathfinder
extends RefCounted

# =============================================================================
# PATHFINDER.GD
#
# Responsibilities:
#   - Wrap AStarGrid2D for tile-based A* pathfinding ( _grid).
#   - Update walkability when obstacles are removed.
#
# What this script does NOT do:
#   - Move creatures  (creature.gd do that via _move_smart).
#   - Handle physics  (Godot engine does that via move_and_slide).
# =============================================================================

const TILE_SIZE := 32


# ── Internal ──────────────────────────────────────────────────────────────────

var _grid         		: AStarGrid2D   	# init build(). Used by find_path().
var _map_cols     		: int           	# init build().
var _map_rows     		: int           	# init build().
# Counts how many obstacles claim the tile. Updated when an obstacle is been removed.
var _solid_counts    	: Dictionary = {}   # set_tile_solid().
# True for the creatures central tile. Updated per second.
var _dynamic_blockers	: Dictionary = {}   #as game._update_dynamic_blockers().
# Tracks which exact tiles are solid (no dilation). For debug_overlay.
var _grid_centers    	: Dictionary = {}   # set_tile_solid().
# Temporary creature-collision blocks. tile → seconds_remaining.
var _temp_blocks     	: Dictionary = {}   # add_temp_block(), update().


# =============================================================================
# SETUP
# =============================================================================

# Called: game._build_pathfinder().
func build(map_cols: int, map_rows: int) -> void:

	_map_cols            = map_cols
	_map_rows            = map_rows
	
	_grid                = AStarGrid2D.new()
	#_grid.cell_shape	 = AStarGrid2D.CELL_SHAPE_SQUARE
	_grid.cell_size      = Vector2(TILE_SIZE, TILE_SIZE)
	_grid.diagonal_mode  = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	#_grid.jumping_enabled= true
	_grid.region         = Rect2i(0, 0, map_cols, map_rows)
	_grid.offset         = Vector2.ZERO
	
	_grid.update()


# Called: game._update_dynamic_blockers().
func set_dynamic_blockers(tiles: Dictionary) -> void:

	# Not by reference but by value. Because reference is been updated constantly.
	_dynamic_blockers = tiles.duplicate()


# Called: game._spawn_bush(), game._spawn_bush() tree_exiting.
func set_tile_solid(tile: Vector2i, solid: bool) -> void:

	# Updates _grid.
	# 3x3 square dilation: centre + all 8 neighbours marked as solid.
	# A reference count per tile handles overlapping dilation zones between adjacent obstacles.
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var t := tile + Vector2i(dx, dy)
			if t.x < 0 or t.x >= _map_cols or t.y < 0 or t.y >= _map_rows:
				continue
			if solid:
				_solid_counts[t] = _solid_counts.get(t, 0) + 1
				_grid.set_point_solid(t, true)
			else:
				var count : int = _solid_counts.get(t, 1) - 1
				if count <= 0:
					_solid_counts.erase(t)
					_grid.set_point_solid(t, false)
				else:
					_solid_counts[t] = count
					
	# Tracks exact center tile (no dilation) for debug_overlay.
	if solid:
		_grid_centers[tile] = true
	else:
		_grid_centers.erase(tile)


# =============================================================================
# TEMP BLOCKING
# =============================================================================

# Called: creature._on_collision().
# Blocks the tile under world_pos for `duration` seconds so A* routes around it.
# Ignored if the tile is already permanently solid.
func add_temp_block(world_pos: Vector2, duration: float = 3.0) -> void:

	var tile := _world_to_tile(world_pos)
	if tile.x < 0 or tile.x >= _map_cols or tile.y < 0 or tile.y >= _map_rows:
		return
	if _solid_counts.has(tile):
		return   # already a permanent obstacle — no need to track
	if not _temp_blocks.has(tile):
		_grid.set_point_solid(tile, true)
	_temp_blocks[tile] = duration   # refresh duration if already blocked


# Called: game._process().
func update(dt: float) -> void:

	if _temp_blocks.is_empty():
		return
	var expired : Array = []
	for tile in _temp_blocks:
		_temp_blocks[tile] -= dt
		if _temp_blocks[tile] <= 0.0:
			expired.append(tile)
	for tile in expired:
		_temp_blocks.erase(tile)
		if not _solid_counts.has(tile):
			_grid.set_point_solid(tile, false)


# =============================================================================
# PATHFINDING
# =============================================================================

# Called: creature._move_smart().
func find_path(from_world: Vector2, to_world: Vector2) -> Array:

	var from_tile := _world_to_tile(from_world)
	var to_tile   := _world_to_tile(to_world)
	
	from_tile = from_tile.clamp(Vector2i.ZERO, Vector2i(_map_cols - 1, _map_rows - 1))
	to_tile   = to_tile.clamp(Vector2i.ZERO,   Vector2i(_map_cols - 1, _map_rows - 1))
	
	if from_tile == to_tile:
		return []

	# Targets tile solid. Happens when player is near an obstacle.
	if _grid.is_point_solid(to_tile):
		to_tile = _nearest_walkable(to_tile)

	# Creatures tile solid. Happens when creature is pushed into an obstacle.
	if _grid.is_point_solid(from_tile):
		from_tile = _nearest_walkable(from_tile)

	# Temporarily marks all creature center tiles as solid so A* routes around them.
	for tile in _dynamic_blockers:
		_solid_counts[tile] = _solid_counts.get(tile, 0) + 1
		_grid.set_point_solid(tile, true)

	var raw : PackedVector2Array = _grid.get_point_path(from_tile, to_tile)

	# Unmarks all creature center tiles.
	for tile in _dynamic_blockers:
		var count : int = _solid_counts.get(tile, 1) - 1
		if count <= 0:
			_solid_counts.erase(tile)
			_grid.set_point_solid(tile, false)
		else:
			_solid_counts[tile] = count
	
	# raw[0] is the from_tile anchor — the creature is already inside that tile so                        
	# navigating back to it causes a momentary backward step. Drop it.
	var path := Array(raw)
	if path.size() > 1:
		if path.size() < 4:
			print("First cleared! from size<4.")
		path.pop_front()
		
	# A list of waypoint coordinates (center of a tile) that builds a path from_tile to to_tile.
	return path   


# =============================================================================
# HELPERS
# =============================================================================

# Called: find_path().
func _world_to_tile(world_pos: Vector2) -> Vector2i:

	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))


# Called: find_path(), _exit_wait().
func _nearest_walkable(tile: Vector2i) -> Vector2i:

	# BFS outward until a non-solid tile is found.
	var visited : Dictionary = {tile: true}
	var queue   : Array[Vector2i] = [tile]

	# Check first all tiles around the blocked tile.
	var dirs : Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while queue.size() > 0:
		var cur : Vector2i = queue.pop_front()
		for dir in dirs:
			var next := cur + dir
			if next.x < 0 or next.x >= _map_cols or next.y < 0 or next.y >= _map_rows:
				continue
			if visited.has(next):
				continue
			visited[next] = true
			if not _grid.is_point_solid(next):
				return next
			queue.append(next)

	# It actually never happens.
	return Vector2i(-1, -1)


# =============================================================================
# DEBUG ACCESSORS
# =============================================================================

# Called: debug_overlay._draw_pf_grid().
func get_grid_solid_counts() -> Dictionary:

	# Keys are solid tiles in _grid (with 3x3 dilation). Values are ref counts.
	return _solid_counts


# Called: debug_overlay._draw_pf_grid2().
func get_grid2_solid_tiles() -> Dictionary:

	# Keys are solid tiles in _grid_centers (exact center only, no dilation).
	return _grid_centers


# Called: debug_overlay._draw_dyn_blockers().
func get_dynamic_blockers() -> Dictionary:

	# Keys are tile coords (creature + player center tiles). Updated every 1 s.
	return _dynamic_blockers


# Called: debug_overlay._draw_temp_blocks().
func get_temp_blocks() -> Dictionary:

	# Keys are tile coords; values are remaining seconds.
	return _temp_blocks
