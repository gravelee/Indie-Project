extends Node2D

# =============================================================================
# DEBUG_OVERLAY.GD
#
# Responsibilities:
#   - Draw collision circles for creatures, player, and obstacles.
#   - Draw tile-grid lines across the full map.
#   - Draw solid tiles of pathfinder _grid (dilated) and _grid2 (LOS, exact).
#   - Draw creature A* paths and home markers.
#   - Draw per-creature AI range circles and pathfinder blocker tiles.
#
# Drawn in world space (child of game.gd at origin).
# All flags toggled from stat_panel.gd via the player/creature panel debug sections.
# =============================================================================


# ── Colors ────────────────────────────────────────────────────────────────────

const COLOR_CREATURE_LINE  := Color(0.35, 0.78, 1.00, 0.55)
const COLOR_CREATURE_FILL  := Color(0.35, 0.78, 1.00, 0.14)
const COLOR_PLAYER_LINE    := Color(0.35, 1.00, 0.50, 0.55)
const COLOR_PLAYER_FILL    := Color(0.35, 1.00, 0.50, 0.14)
const COLOR_OBSTACLE_LINE  := Color(1.00, 0.55, 0.22, 0.55)
const COLOR_OBSTACLE_FILL  := Color(1.00, 0.55, 0.22, 0.14)
const COLOR_GRID           := Color(1.00, 1.00, 1.00, 0.13)
const COLOR_PF_GRID_FILL   := Color(0.90, 0.18, 0.55, 0.22)   # magenta — A* dilation solid
const COLOR_PF_GRID_LINE   := Color(0.90, 0.18, 0.55, 0.50)
const COLOR_PF_GRID2_FILL  := Color(0.95, 0.80, 0.10, 0.22)   # amber — LOS solid
const COLOR_PF_GRID2_LINE  := Color(0.95, 0.80, 0.10, 0.50)
const COLOR_PATH_DOT       := Color(1.00, 0.85, 0.00, 0.90)
const COLOR_PATH_LINE      := Color(0.00, 0.75, 1.00, 0.60)
const COLOR_HOME_LINE      := Color(0.39, 0.78, 0.47, 0.35)
const COLOR_HOME_CROSS     := Color(0.39, 0.78, 0.47, 0.90)

# Creature debug ranges
const COLOR_NOTICE_DIR_FILL  := Color(0.00, 0.90, 0.80, 0.04)
const COLOR_NOTICE_DIR_LINE  := Color(0.00, 0.90, 0.80, 0.22)
const COLOR_NOTICE_DIST_FILL := Color(1.00, 0.95, 0.00, 0.04)
const COLOR_NOTICE_DIST_LINE := Color(1.00, 0.95, 0.00, 0.22)
const COLOR_ATTACK_DIST_FILL := Color(1.00, 0.20, 0.20, 0.08)
const COLOR_ATTACK_DIST_LINE := Color(1.00, 0.20, 0.20, 0.38)
const COLOR_CHASE_DIST_LINE  := Color(0.75, 0.30, 1.00, 0.22)
const COLOR_HOME_MAX_LINE    := Color(0.50, 0.50, 1.00, 0.28)
const COLOR_DYN_BLOCKER_FILL := Color(1.00, 0.55, 0.00, 0.22)
const COLOR_DYN_BLOCKER_LINE := Color(1.00, 0.55, 0.00, 0.55)
const COLOR_TEMP_BLOCK_FILL  := Color(1.00, 0.10, 0.50, 0.25)
const COLOR_TEMP_BLOCK_LINE  := Color(1.00, 0.10, 0.50, 0.60)

const TILE_SIZE      := 32
const ARC_PTS        := 48
const DRAW_INTERVAL  := 0.1   # 10 fps — enough for debug readability
const FILL_MAX_RADIUS := 600.0  # circles larger than this draw arc-only (no pixel fill)

var _draw_timer : float = 0.0

# Mirrors of creature.gd constants — used only for debug drawing.
const _CRE_ATTACK_DIST := 60.0
const _CRE_NOTICE_DIST := 400.0
const _CRE_NOTICE_DIR  := 450.0
const _CRE_CHASE_DIST  := 900.0
const _CRE_HOME_MAX    := 2000.0


# ── Flags — set by stat_panel._toggle_debug() ────────────────────────────────

var show_creature_col    : bool = false
var show_player_col      : bool = false
var show_obstacle_col    : bool = false
var show_tile_grid       : bool = false
var show_pf_grid         : bool = false   # A* pathfinding grid (dilated)
var show_pf_grid2        : bool = false   # LOS grid (exact, no dilation)
var show_cre_paths       : bool = false   # creature A* waypoint paths
var show_home_markers    : bool = false   # creature home position markers

# Creature debug ranges / blockers
var show_cre_attack_dist : bool = false
var show_cre_notice_dist : bool = false
var show_cre_notice_dir  : bool = false
var show_cre_chase_dist  : bool = false
var show_cre_home_max    : bool = false
var show_dyn_blockers    : bool = false
var show_temp_blocks     : bool = false


# ── References set by game._ready() via init() ───────────────────────────────

var player       : CharacterBody2D
var creatures    : Array      = []   # shared Array ref from game — always current.
var obstacle_map : Dictionary = {}   # shared Dict ref from game — tile → StaticBody2D.
var pathfinder   : Object     = null # Pathfinder ref from game.
var map_cols     : int        = 0
var map_rows     : int        = 0


# =============================================================================
# SETUP
# =============================================================================

# Called: game._ready().
func init(p_player: CharacterBody2D, p_creatures: Array,
		  p_obstacle_map: Dictionary, p_pathfinder: Object,
		  cols: int, rows: int) -> void:

	player        = p_player
	creatures     = p_creatures
	obstacle_map  = p_obstacle_map
	pathfinder    = p_pathfinder
	map_cols      = cols
	map_rows      = rows
	z_index       = 1000
	z_as_relative = false
	process_mode  = Node.PROCESS_MODE_ALWAYS


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP
func _process(delta: float) -> void:

	_draw_timer += delta
	if _draw_timer >= DRAW_INTERVAL:
		_draw_timer = 0.0
		queue_redraw()


# Godot built-in — triggered by queue_redraw().
func _draw() -> void:

	# Back to front: grid → pf solids → blockers → ranges → paths/markers → collisions.
	if show_tile_grid:
		_draw_tile_grid()
	if show_pf_grid:
		_draw_pf_grid()
	if show_pf_grid2:
		_draw_grid_centers()
	if show_dyn_blockers:
		_draw_dyn_blockers()
	if show_temp_blocks:
		_draw_temp_blocks()
	if show_cre_home_max:
		_draw_cre_home_max()
	if show_cre_chase_dist:
		_draw_cre_range(_CRE_CHASE_DIST,  Color(0,0,0,0),          COLOR_CHASE_DIST_LINE)
	if show_cre_notice_dir:
		_draw_cre_range(_CRE_NOTICE_DIR,  COLOR_NOTICE_DIR_FILL,   COLOR_NOTICE_DIR_LINE)
	if show_cre_notice_dist:
		_draw_cre_range(_CRE_NOTICE_DIST, COLOR_NOTICE_DIST_FILL,  COLOR_NOTICE_DIST_LINE)
	if show_cre_attack_dist:
		_draw_cre_range(_CRE_ATTACK_DIST, COLOR_ATTACK_DIST_FILL,  COLOR_ATTACK_DIST_LINE)
	if show_home_markers:
		_draw_home_markers()
	if show_cre_paths:
		_draw_creature_paths()
	if show_obstacle_col:
		_draw_obstacle_collisions()
	if show_creature_col:
		_draw_creature_collisions()
	if show_player_col:
		_draw_player_collision()


# =============================================================================
# DRAW LAYERS
# =============================================================================

# Called: _draw().
func _draw_tile_grid() -> void:

	# Offset by -half tile so grid lines land between tiles and obstacle positions
	# (which are at col*TILE_SIZE, row*TILE_SIZE) sit at the center of each cell.
	var half := TILE_SIZE * 0.5
	var w    := float(map_cols * TILE_SIZE)
	var h    := float(map_rows * TILE_SIZE)

	for col in range(map_cols + 1):
		var x := float(col * TILE_SIZE) - half
		draw_line(Vector2(x, -half), Vector2(x, h + half), COLOR_GRID, 2.0)

	for row in range(map_rows + 1):
		var y := float(row * TILE_SIZE) - half
		draw_line(Vector2(-half, y), Vector2(w + half, y), COLOR_GRID, 2.0)


# Called: _draw(). Draws solid tiles in the A* pathfinding grid (3x3 dilation).
func _draw_pf_grid() -> void:

	if not pathfinder:
		return
	var half   := TILE_SIZE * 0.5
	var solids : Dictionary = pathfinder.get_grid_solid_counts()
	for tile in solids:
		var rect := Rect2(
			float(tile.x * TILE_SIZE) - half, float(tile.y * TILE_SIZE) - half,
			float(TILE_SIZE), float(TILE_SIZE))
		draw_rect(rect, COLOR_PF_GRID_FILL)
		draw_rect(rect, COLOR_PF_GRID_LINE, false, 1.0)


# Called: _draw(). Draws solid tiles in the LOS grid (exact center, no dilation).
func _draw_grid_centers() -> void:

	if not pathfinder:
		return
	var half   := TILE_SIZE * 0.5
	var solids : Dictionary = pathfinder.get_grid2_solid_tiles()
	for tile in solids:
		var rect := Rect2(
			float(tile.x * TILE_SIZE) - half, float(tile.y * TILE_SIZE) - half,
			float(TILE_SIZE), float(TILE_SIZE))
		draw_rect(rect, COLOR_PF_GRID2_FILL)
		draw_rect(rect, COLOR_PF_GRID2_LINE, false, 1.0)


# Called: _draw(). Dynamic blocker tiles — creature + player center tiles (stale 1 s).
func _draw_dyn_blockers() -> void:

	if not pathfinder:
		return
	var half     := TILE_SIZE * 0.5
	var blockers : Dictionary = pathfinder.get_dynamic_blockers()
	for tile in blockers:
		var rect := Rect2(
			float(tile.x * TILE_SIZE) - half, float(tile.y * TILE_SIZE) - half,
			float(TILE_SIZE), float(TILE_SIZE))
		draw_rect(rect, COLOR_DYN_BLOCKER_FILL)
		draw_rect(rect, COLOR_DYN_BLOCKER_LINE, false, 1.0)


# Called: _draw(). Temp-blocked tiles from creature-creature collision response.
func _draw_temp_blocks() -> void:

	if not pathfinder:
		return
	var half   := TILE_SIZE * 0.5
	var blocks : Dictionary = pathfinder.get_temp_blocks()
	for tile in blocks:
		var rect := Rect2(
			float(tile.x * TILE_SIZE) - half, float(tile.y * TILE_SIZE) - half,
			float(TILE_SIZE), float(TILE_SIZE))
		draw_rect(rect, COLOR_TEMP_BLOCK_FILL)
		draw_rect(rect, COLOR_TEMP_BLOCK_LINE, false, 1.0)


# Called: _draw(). Home-max-dist boundary circle (arc only — radius 2000 px is huge).
func _draw_cre_home_max() -> void:

	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		if not creature.get("has_home"):
			continue
		var home_pos = creature.get("home_position")
		if home_pos == null:
			continue
		draw_arc(home_pos, _CRE_HOME_MAX, 0.0, TAU, 128, COLOR_HOME_MAX_LINE, 1.5)


# Called: _draw(). Range circle for notice / attack distances.
# Large radii draw arc-only — filling hundreds of thousands of pixels per creature kills fps.
func _draw_cre_range(radius: float, fill_color: Color, line_color: Color) -> void:

	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		if radius <= FILL_MAX_RADIUS:
			draw_circle(creature.position, radius, fill_color)
		draw_arc(creature.position, radius, 0.0, TAU, ARC_PTS, line_color, 1.0)


# Called: _draw(). Draws A* waypoint paths for all creatures.
func _draw_creature_paths() -> void:

	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		var path = creature.get("path")
		if path == null or path.is_empty():
			continue
		var prev : Vector2 = creature.position
		for wp in path:
			draw_circle(wp, 4.0, COLOR_PATH_DOT)
			draw_line(prev, wp, COLOR_PATH_LINE, 1.5)
			prev = wp


# Called: _draw(). Draws home position marker for each creature in combat.
func _draw_home_markers() -> void:

	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		if not creature.get("in_combat"):
			continue
		var home_pos = creature.get("home_position")
		if home_pos == null:
			continue
		var cpos : Vector2 = creature.position
		draw_line(cpos, home_pos, COLOR_HOME_LINE, 3.0)
		var size := 6.0
		draw_line(home_pos + Vector2(-size, -size), home_pos + Vector2( size,  size), COLOR_HOME_CROSS, 3.0)
		draw_line(home_pos + Vector2( size, -size), home_pos + Vector2(-size,  size), COLOR_HOME_CROSS, 3.0)


# Called: _draw().
func _draw_creature_collisions() -> void:

	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		var r := _get_collision_radius(creature)
		draw_circle(creature.position, r, COLOR_CREATURE_FILL)
		draw_arc(creature.position, r, 0.0, TAU, ARC_PTS, COLOR_CREATURE_LINE, 1.5)


# Called: _draw().
func _draw_player_collision() -> void:

	if not is_instance_valid(player):
		return
	var r := _get_collision_radius(player)
	draw_circle(player.position, r, COLOR_PLAYER_FILL)
	draw_arc(player.position, r, 0.0, TAU, ARC_PTS, COLOR_PLAYER_LINE, 1.5)


# Called: _draw().
func _draw_obstacle_collisions() -> void:

	for tile in obstacle_map:
		var obs : Node2D = obstacle_map[tile]
		if not is_instance_valid(obs):
			continue
		var r := _get_collision_radius(obs)
		draw_circle(obs.position, r, COLOR_OBSTACLE_FILL)
		draw_arc(obs.position, r, 0.0, TAU, ARC_PTS, COLOR_OBSTACLE_LINE, 1.5)


# =============================================================================
# HELPERS
# =============================================================================

# Called: _draw_creature_collisions(), _draw_player_collision(), _draw_obstacle_collisions().
func _get_collision_radius(node: Node) -> float:

	for child in node.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			if shape is CircleShape2D:
				return shape.radius
			elif shape is CapsuleShape2D:
				return shape.radius
			elif shape is RectangleShape2D:
				return (shape.size * 0.5).length()
	return 16.0
