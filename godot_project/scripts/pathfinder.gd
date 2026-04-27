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

const TILE_SIZE      := 32
const TEMP_BLOCK_DURATION := 3
const MAX_PATH_TILES := 120


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
# Temporary creature-collision blocks. Tile → seconds_remaining.
var _temp_block_timer  : Dictionary = {}   # add_temp_block(), update_temp_block().
# How many times each tile has been updated before timer is up.
var _temp_block_update  : Dictionary = {}   # add_temp_block(), update_temp_block().
# How many times each tile has been re-blocked (after timer is up).
var _temp_block_times   : Dictionary = {}   # add_temp_block(), update_temp_block().
# How much time since _temp_block_times[tile] is to be reseted.
var _temp_block_duration: Dictionary = {}   # update_temp_block().


# =============================================================================
# SETUP
# =============================================================================

# Called: map._build_pathfinder().
func build(map_cols: int, map_rows: int) -> void:

	_map_cols            = map_cols
	_map_rows            = map_rows
	
	_grid                = AStarGrid2D.new()
	#_grid.cell_shape	 = AStarGrid2D.CELL_SHAPE_SQUARE
	_grid.cell_size      = Vector2(TILE_SIZE, TILE_SIZE)
	_grid.diagonal_mode  = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES 
	#_grid.jumping_enabled= true
	_grid.region         = Rect2i(0, 0, map_cols, map_rows)
	_grid.offset         = Vector2.ZERO
	
	_grid.update()


# Called: map._update_dynamic_blockers().
func set_dynamic_blockers(tiles: Dictionary) -> void:

	# Not by reference but by value. Because reference is been updated constantly.
	_dynamic_blockers = tiles.duplicate()


# Called: map._spawn_prop().
func set_tile_solid(tile: Vector2i, cols: int, rows: int, solid: bool) -> void:

	# Sprite anchor is bottom-left; tile grid grows right (+x) and up (−y in world, −dy in tile).
	# range_x: cols tiles to the right of the anchor.
	# range_y: rows tiles upward — dy=0 is anchor row, dy=-(rows-1) is the topmost row.
	var range_x := range(0, cols)
	var range_y := range(1 - rows, 1)   # e.g. rows=3 → [-2,-1,0]; rows=1 → [0]

	for dx in range_x:
		for dy in range_y:
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
func add_temp_block(world_pos: Vector2) -> void:

	# Blocks the creatures next waypoint so A* routes around it. Ignored if 
	# the tile is already permanently solid. 
	var tile := _world_to_tile(world_pos)
	if tile.x < 0 or tile.x >= _map_cols or tile.y < 0 or tile.y >= _map_rows:
		return
	if _solid_counts.has(tile):
		return   # aAlready a permanent obstacle. No need to track.
	if not _temp_block_timer.has(tile):
		_grid.set_point_solid(tile, true)
	_temp_block_update[tile] = _temp_block_update.get(tile, 0) + 1
	_temp_block_times[tile] = _temp_block_times.get(tile, 0)
	_temp_block_timer[tile] = minf(TEMP_BLOCK_DURATION  
		+ (_temp_block_times[tile] + _temp_block_update[tile] - 1) * TEMP_BLOCK_DURATION, 32)


# Called: map._process().
func update_temp_block(dt: float) -> void:

	if _temp_block_timer.is_empty() and _temp_block_duration.is_empty():
		return
	var expired_couter   : Array = []
	var expired_duration : Array = []
	for tile in _temp_block_timer:
		_temp_block_timer[tile] -= dt
		if _temp_block_timer[tile] <= 0.0:
			expired_couter.append(tile)
	for tile in _temp_block_duration:
		_temp_block_duration[tile] -= dt
		if _temp_block_duration[tile] <= 0.0:
			expired_duration.append(tile)
	for tile in expired_duration:
		_temp_block_times.erase(tile)
		_temp_block_duration.erase(tile)
	for tile in expired_couter:
		_temp_block_update.erase(tile)
		_temp_block_times[tile] = _temp_block_times.get(tile, 0) + 1
		_temp_block_duration[tile] = 32
		_temp_block_timer.erase(tile)
		# There is no way that tile to be part of _solid_counts. Son no check.
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

	# 1. Pre-check: Chebyshev distance > MAX_PATH_TILES — too far, skip A*.                   
	var cheb := maxi(absi(to_tile.x - from_tile.x), absi(to_tile.y - from_tile.y))            
	if cheb > MAX_PATH_TILES:                                                                 
		return []

	# 2. Neighbor solidity heuristic — start A* from the more-enclosed side so                
	#    the search exhausts a small blocked area fast instead of exploring open space.       
	var from_score := _count_solid_neighbors(from_tile)
	var to_score   := _count_solid_neighbors(to_tile)
	var reversed   := to_score > from_score
	
	# If creature and player tiles are solid find nearest walkable.
	if _grid.is_point_solid(to_tile):
		to_tile = _nearest_walkable(to_tile)
		
	# Temporarily marks all creature center tiles (except specific creature tile)
	# as solid so A* routes around them.
	for tile in _dynamic_blockers:
		if tile == from_tile:
			continue
		_solid_counts[tile] = _solid_counts.get(tile, 0) + 1
		_grid.set_point_solid(tile, true)
	
	var search_from := to_tile   if reversed else from_tile
	var search_to   := from_tile if reversed else to_tile

	var raw : PackedVector2Array = _grid.get_point_path(search_from, search_to)

	# Unmarks all creature center tiles (except specific creature tile).
	for tile in _dynamic_blockers:
		if tile == from_tile:
			continue
		var count : int = _solid_counts.get(tile, 1) - 1
		if count <= 0:
			_solid_counts.erase(tile)
			_grid.set_point_solid(tile, false)
		else:
			_solid_counts[tile] = count
	
	# 3. Path length cap — unreasonably long path means effectively unreachable, treat as dead+lock.
	var path := Array(raw)
	if path.size() > MAX_PATH_TILES:
		return []
		
	# If we searched in reverse order, flip the path back to creature→player order.
	if reversed:
		path.reverse()
		
	# raw[0] is the search_from anchor — the creature is already inside that tile so
	# navigating back to it causes a momentary backward step. Drop it.
	if path.size() > 1:
		path.pop_front()

	# AStarGrid2D with offset=Vector2.ZERO returns tile top-left corners.
	# Shift every waypoint to tile center so creatures aim for the middle of each tile.
	var half := TILE_SIZE / 2.0
	for i in path.size():
		path[i] = path[i] + Vector2(half, half)

	return path


# =============================================================================
# HELPERS
# =============================================================================

# Called: find_path().
func _world_to_tile(world_pos: Vector2) -> Vector2i:

	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))


# Called: find_path().                                                                             
func _count_solid_neighbors(tile: Vector2i) -> int:                                              

	# Counts solid tiles in the 8 neighbors of tile (out-of-bounds counts as solid).
	var count := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var t := tile + Vector2i(dx, dy)
			if t.x < 0 or t.x >= _map_cols or t.y < 0 or t.y >= _map_rows:
				count += 1
			elif _grid.is_point_solid(t) or _dynamic_blockers.has(t):
				count += 1
	return count


# Called: find_path(), creature._exit_wait().
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
	return _temp_block_timer


# Called: debug_overlay._draw_path_grid().
func get_walkable_tiles() -> Array:

	# Returns all tile coords that are not solid in _grid.
	var result : Array = []
	for y in range(_map_rows):
		for x in range(_map_cols):
			var tile := Vector2i(x, y)
			if not _grid.is_point_solid(tile):
				result.append(tile)
	return result
