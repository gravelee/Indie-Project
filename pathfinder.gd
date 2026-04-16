class_name Pathfinder
extends RefCounted

# =============================================================================
# PATHFINDER.GD
#
# Responsibilities:
#   - Wrap AStarGrid2D for tile-based A* pathfinding ( _grid).
#   - Provide line-of-sight check via tile raycast ( _grid2).
#   - Update walkability when obstacles are removed.
#
# What this script does NOT do:
#   - Move creatures  (rat.gd / snake.gd do that via _move_smart).
#   - Handle physics  (Godot engine does that via move_and_slide).
# =============================================================================


# ── Constants ──────────────────────────────────────────────────────────────────

const TILE_SIZE := 32


# ── Internal ──────────────────────────────────────────────────────────────────

var _grid         		: AStarGrid2D   	# init build(). Used by find_path().
var _grid2         		: AStarGrid2D   	# init build(). Used by line_of_sight().
var _map_cols     		: int           	# init build().
var _map_rows     		: int           	# init build().
# Counts how many obstacles claim the tile. Updated when an obstacle is been removed.
var _solid_counts    	: Dictionary = {}   # set_tile_solid().
# True for the creatures central tile. Updated per second.
var _dynamic_blockers	: Dictionary = {}   # game._update_dynamic_blockers().


# =============================================================================
# SETUP
# =============================================================================

# Called: game._build_pathfinder().
func build(map_cols: int, map_rows: int) -> void:

	_map_cols            = map_cols
	_map_rows            = map_rows
	
	_grid                = AStarGrid2D.new()
	_grid.region         = Rect2i(0, 0, map_cols, map_rows)
	_grid.cell_size      = Vector2(TILE_SIZE, TILE_SIZE)
	_grid.offset         = Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	_grid.diagonal_mode  = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_grid.update()
	
	_grid2                = AStarGrid2D.new()
	_grid2.region         = Rect2i(0, 0, map_cols, map_rows)
	_grid2.cell_size      = Vector2(TILE_SIZE, TILE_SIZE)
	_grid2.offset         = Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	_grid2.diagonal_mode  = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_grid2.update()


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
					
	# Updates _grid2.
	if solid:
		_grid2.set_point_solid(tile, true)
	else:
		_grid2.set_point_solid(tile, false)


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

	# Creatures tile solid. Happens when creature follows the player with LOS.
	if _grid.is_point_solid(from_tile):
		from_tile = _nearest_walkable(from_tile)

	# Temporarily marks all creature center tiles as solid so A* routes around them.
	for tile in _dynamic_blockers:
		_solid_counts[tile] = _solid_counts.get(tile, 0) + 1
		_grid.set_point_solid(tile, true)

	# "For now" it will always find a path.
	var raw : PackedVector2Array = _grid.get_point_path(from_tile, to_tile)

	# Unmarks all creature center tiles.
	for tile in _dynamic_blockers:
		var count : int = _solid_counts.get(tile, 1) - 1
		if count <= 0:
			_solid_counts.erase(tile)
			_grid.set_point_solid(tile, false)
		else:
			_solid_counts[tile] = count

	# A list of waypoint coordinates (center of a tile) that builds a path from_tile to to_tile.
	return Array(raw)   


# Called: creature._move_smart().
func line_of_sight(from_world: Vector2, to_world: Vector2) -> bool:

	# Tile-space DDA raycast. Walks between the two tile positions.
	# Returns false if any intermediate tile is solid.
	var from_tile := _world_to_tile(from_world)
	var to_tile   := _world_to_tile(to_world)

	var x0    := float(from_tile.x)
	var y0    := float(from_tile.y)
	var dx    := float(to_tile.x) - x0
	var dy    := float(to_tile.y) - y0
	var steps := int(maxf(absf(dx), absf(dy)))

	if steps == 0:
		return true

	for i in range(1, steps):
		var t  := float(i) / float(steps)
		var tc := Vector2i(int(roundf(x0 + dx * t)), int(roundf(y0 + dy * t)))
		if _grid2.is_point_solid(tc):
			return false
		if _dynamic_blockers.has(tc):
			return false

	return true


# =============================================================================
# HELPERS
# =============================================================================

# Called: find_path(), line_of_sight().
func _world_to_tile(world_pos: Vector2) -> Vector2i:

	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))


# Called: find_path().
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
