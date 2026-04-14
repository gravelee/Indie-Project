class_name Pathfinder
extends RefCounted

# =============================================================================
# PATHFINDER.GD
#
# Responsibilities:
#   - Wrap AStarGrid2D for tile-based A* pathfinding
#   - Provide line-of-sight check via tile raycast
#   - Update walkability when bushes are destroyed
#
# What this script does NOT do:
#   - Move creatures  (rat.gd / snake.gd do that via _move_smart)
#   - Handle physics  (Godot engine does that via move_and_slide)
# =============================================================================


# ── Constants ──────────────────────────────────────────────────────────────────

const TILE_SIZE := 32


# ── Internal ──────────────────────────────────────────────────────────────────

var _grid         : AStarGrid2D   # init build().
var _map_cols     : int           # init build().
var _map_rows     : int           # init build().
var _solid_counts    : Dictionary = {}   # tile → how many bushes claim it solid; updated by set_tile_solid().
var _dynamic_blockers: Dictionary = {}   # tile → true for each creature; set game._update_dynamic_blockers().


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
	_grid.diagonal_mode  = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()


# Called: game._update_dynamic_blockers() every second.
func set_dynamic_blockers(tiles: Dictionary) -> void:

	# Duplicate to avoid reference aliasing — game.gd clears its own dict each cycle,
	# which would silently clear _dynamic_blockers too if they shared the same object.
	_dynamic_blockers = tiles.duplicate()


# Called: game._spawn_bush(), game (on bush death).
# Dilates by 1 tile: marks the bush's center and its 4 cardinal neighbours solid (cross pattern).
# A reference count per tile handles overlapping dilation zones between adjacent bushes —
# a tile is only unsolid when the last bush claiming it is removed.
# Result: a gap of 3+ free tiles between two bush centres is routable; 2 or fewer is blocked.
func set_tile_solid(tile: Vector2i, solid: bool) -> void:

	# Cross (4-directional) dilation: mark the bush centre and its 4 cardinal neighbours.
	# Diagonal neighbours are intentionally excluded so diagonal corridors stay open —
	# the bush's physical collision handles corner-blocking; the pathfinder only needs
	# to account for orthogonal clearance.
	# Reference-count each tile so overlapping zones from adjacent bushes unmark correctly.
	var cross : Array[Vector2i] = [
		tile,
		tile + Vector2i( 1,  0),
		tile + Vector2i(-1,  0),
		tile + Vector2i( 0,  1),
		tile + Vector2i( 0, -1),
	]
	for t in cross:
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

	# Target tile solid (e.g. player standing next to a bush) — find nearest open tile.
	if _grid.is_point_solid(to_tile):
		to_tile = _nearest_walkable(to_tile)
		if to_tile == Vector2i(-1, -1):
			return []

	# Creature somehow inside a solid tile — skip rather than crash.
	if _grid.is_point_solid(from_tile):
		return []

	# Temporarily mark creature tiles solid so A* routes around them.
	# Each creature center is dilated to center + 4 cardinal neighbours so the blocked
	# zone matches the creature's physical collision footprint — without dilation, A*
	# routes to tiles that are technically open but physically impassable next to the creature.
	# Exclusions per tile:
	#   - Manhattan distance ≤ 1 from from_tile: can't block the pathfinding start zone.
	#   - to_tile: must remain reachable.
	#   - Already solid (bush or previously marked by another creature's dilation): skip to
	#     avoid double-marking and incorrectly unmarking a bush tile on cleanup.
	var temp_marked : Array[Vector2i] = []
	var dirs5 : Array[Vector2i] = [
		Vector2i( 0,  0),
		Vector2i( 1,  0), Vector2i(-1,  0),
		Vector2i( 0,  1), Vector2i( 0, -1),
	]
	for center in _dynamic_blockers:
		for offset in dirs5:
			var tile : Vector2i = center + offset
			if abs(tile.x - from_tile.x) + abs(tile.y - from_tile.y) <= 1:
				continue
			if tile == to_tile:
				continue
			if tile.x < 0 or tile.x >= _map_cols or tile.y < 0 or tile.y >= _map_rows:
				continue
			if _grid.is_point_solid(tile):
				continue   # already solid (bush or earlier dilation) — don't touch
			_grid.set_point_solid(tile, true)
			temp_marked.append(tile)

	var raw : PackedVector2Array = _grid.get_point_path(from_tile, to_tile)

	for tile in temp_marked:
		_grid.set_point_solid(tile, false)

	return Array(raw)   # Array of Vector2 tile-center world positions


# Called: creature._move_smart().
func line_of_sight(from_world: Vector2, to_world: Vector2) -> bool:

	# Tile-space DDA raycast — walks between the two tile positions and
	# returns false if any intermediate tile is solid.
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
		if tc.x < 0 or tc.x >= _map_cols or tc.y < 0 or tc.y >= _map_rows:
			continue
		if _grid.is_point_solid(tc):
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

	var dirs : Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
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

	return Vector2i(-1, -1)
