class_name TerrainGenerator

# =============================================================================
# TERRAIN GENERATOR — derives vertex heights from the dark_grass autotile layer.
#
# Height model (from tools/tiled/scripts/map_auto_generator/tile_values.json):
#   Each dark_grass tile has a [NW, NE, SW, SE] corner descriptor.
#     1  → 1.0  (full grass — elevated)
#     0  → 0.0  (full dirt — ground level)
#    -1  → 0.5  (blended edge — half height, produces a smooth slope)
#
#   For each tile, its 4 corner values are pushed directly to the 4 surrounding
#   vertices and accumulated. Adjacent tiles always agree at shared corners in a
#   properly autotiled map, so averaging gives the exact value. No Gaussian blur
#   is needed — the autotile system already encodes the smooth terrain curves.
#
# Public API:
#   generate(cols, rows, terrain_layers)  — call once at load time
#   get_height(world_x, world_z) → float — bilinear interpolation, any position
#   get_vert_heights() → PackedFloat32Array — (cols+1)×(rows+1) array,
#                         row-major, for HeightMapShape3D.map_data
# =============================================================================

# Default outdoor height — gentle undulation the player can walk across.
# Override via generate()'s grass_height parameter.
# Dungeon use (walls vs walkable floor): pass 4.0–6.0.
const GRASS_HEIGHT : float = 0.75

# Corner height lookup for the dark_grass autotile tileset (IDs 0–49).
# Each entry: [NW, NE, SW, SE] float heights derived from tile_values.json
# by mapping  1 → 1.0,  0 → 0.0,  -1 → 0.5.
const _GRASS_CORNERS : Array = [
#         NW    NE    SW    SE
	[0.0, 0.0, 1.0, 0.0],   #  0  SW corner
	[0.0, 1.0, 0.0, 1.0],   #  1  NE–SE line
	[1.0, 0.0, 1.0, 1.0],   #  2  inner NE corner
	[0.0, 0.0, 1.0, 1.0],   #  3  bottom half
	[0.0, 1.0, 1.0, 0.0],   #  4  NE–SW diagonal
	[1.0, 0.0, 0.0, 1.0],   #  5  NW–SE diagonal
	[0.0, 1.0, 1.0, 1.0],   #  6  inner NW corner
	[1.0, 1.0, 1.0, 1.0],   #  7  full grass
	[1.0, 1.0, 1.0, 0.0],   #  8  inner SE corner
	[1.0, 0.0, 0.0, 1.0],   #  9  NW–SE diagonal
	[0.0, 1.0, 0.0, 0.0],   # 10  NE corner
	[1.0, 1.0, 0.0, 0.0],   # 11  top half
	[1.0, 1.0, 0.0, 1.0],   # 12  inner SW corner
	[1.0, 0.0, 1.0, 0.0],   # 13  NW–SW line
	[0.0, 0.0, 0.0, 0.0],   # 14  full none (dirt)
	[1.0, 0.0, 0.0, 0.0],   # 15  NW corner
	[0.0, 0.0, 0.0, 1.0],   # 16  SE corner
	[0.0, 1.0, 1.0, 0.0],   # 17  NE–SW diagonal
	[0.0, 0.5, 0.0, 1.0],   # 18  smooth
	[0.5, 0.0, 1.0, 0.0],   # 19  smooth
	[1.0, 0.5, 1.0, 0.0],   # 20  smooth
	[0.5, 1.0, 0.0, 1.0],   # 21  smooth
	[1.0, 1.0, 0.5, 0.0],   # 22  smooth
	[0.0, 1.0, 0.0, 0.5],   # 23  smooth
	[1.0, 0.0, 0.5, 0.0],   # 24  smooth
	[1.0, 0.0, 1.0, 0.5],   # 25  smooth
	[0.0, 1.0, 0.5, 1.0],   # 26  smooth
	[1.0, 1.0, 0.0, 0.5],   # 27  smooth
	[0.0, 0.0, 0.5, 1.0],   # 28  smooth
	[0.0, 0.0, 1.0, 0.5],   # 29  smooth
	[1.0, 0.5, 0.0, 0.0],   # 30  smooth
	[0.5, 0.0, 1.0, 1.0],   # 31  smooth
	[0.0, 0.5, 1.0, 1.0],   # 32  smooth
	[0.5, 1.0, 0.0, 0.0],   # 33  smooth
	[0.0, 0.0, 0.5, 0.5],   # 34  extra-smooth (map edge)
	[0.5, 1.0, 0.5, 1.0],   # 35  extra-smooth
	[0.5, 0.5, 1.0, 1.0],   # 36  extra-smooth
	[1.0, 0.5, 1.0, 0.5],   # 37  extra-smooth
	[1.0, 1.0, 0.5, 0.5],   # 38  extra-smooth
	[0.5, 0.0, 0.5, 0.0],   # 39  extra-smooth (map edge)
	[0.0, 0.5, 0.5, 1.0],   # 40  extra-smooth
	[0.5, 0.0, 1.0, 0.5],   # 41  extra-smooth
	[1.0, 0.5, 0.5, 0.0],   # 42  extra-smooth
	[0.5, 1.0, 0.0, 0.5],   # 43  extra-smooth
	[0.5, 0.5, 0.0, 0.0],   # 44  extra-smooth (map edge)
	[0.0, 1.0, 0.0, 1.0],   # 45  smooth line
	[0.0, 0.0, 1.0, 1.0],   # 46  smooth line
	[1.0, 1.0, 0.0, 0.0],   # 47  smooth line
	[1.0, 0.0, 1.0, 0.0],   # 48  smooth line
	[0.0, 0.5, 0.0, 0.5],   # 49  extra-smooth (map edge)
]

var _cols   : int              = 100
var _rows   : int              = 100
# Vertex heights, row-major: index = col + row * (cols + 1).
# Passed directly to HeightMapShape3D.map_data.
var _vert_h : PackedFloat32Array


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# grass_height: world-unit peak for fully-grass vertices.
#   Outdoor zones  → use default (GRASS_HEIGHT = 1.5) — player walks naturally.
#   Dungeon zones  → pass 4.0–6.0 — large walls, floor stays at 0.
func generate(cols: int, rows: int, terrain_layers: Array,
		grass_height: float = GRASS_HEIGHT) -> void:
	_cols = cols
	_rows = rows
	var stride : int = cols + 1

	# Per-vertex accumulator: sum of all corner contributions + count.
	var vert_acc : PackedFloat32Array = PackedFloat32Array()
	var vert_cnt : PackedFloat32Array = PackedFloat32Array()
	vert_acc.resize(stride * (rows + 1))
	vert_cnt.resize(stride * (rows + 1))
	vert_acc.fill(0.0)
	vert_cnt.fill(0.0)

	# Push each dark_grass tile's [NW, NE, SW, SE] corner heights to its vertices.
	for layer_entry : Array in terrain_layers:
		var csv_path : String = layer_entry[1]
		if _layer_key(csv_path) == "dark_grass":
			_accumulate_corners(vert_acc, vert_cnt, csv_path, cols, rows, stride)

	# Resolve averages → scale → noise texture.
	var noise := FastNoiseLite.new()
	noise.seed      = 1337
	noise.frequency = 0.12

	_vert_h = PackedFloat32Array()
	_vert_h.resize(stride * (rows + 1))
	for j : int in range(rows + 1):
		for i : int in range(stride):
			var vi : int   = i + j * stride
			var h  : float = 0.0
			if vert_cnt[vi] > 0.0:
				h = (vert_acc[vi] / vert_cnt[vi]) * grass_height
			# Small noise adds texture without obscuring the autotile-accurate curves.
			var n : float = noise.get_noise_2d(float(i), float(j))
			_vert_h[vi] = maxf(0.0, h + n * 0.2)


func get_height(world_x: float, world_z: float) -> float:
	# Bilinear interpolation on the vertex grid.
	var stride : int   = _cols + 1
	var ix     : int   = clampi(int(world_x),       0, _cols - 1)
	var iz     : int   = clampi(int(world_z),       0, _rows - 1)
	var fx     : float = clampf(world_x - float(ix), 0.0, 1.0)
	var fz     : float = clampf(world_z - float(iz), 0.0, 1.0)
	var h00    : float = _vert_h[ix       + iz         * stride]
	var h10    : float = _vert_h[(ix + 1) + iz         * stride]
	var h01    : float = _vert_h[ix       + (iz + 1)   * stride]
	var h11    : float = _vert_h[(ix + 1) + (iz + 1)   * stride]
	return h00 * (1.0 - fx) * (1.0 - fz) \
		 + h10 * fx         * (1.0 - fz) \
		 + h01 * (1.0 - fx) * fz         \
		 + h11 * fx         * fz


func get_vert_heights() -> PackedFloat32Array:
	return _vert_h


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

# Extract layer key from CSV path: "_dark_grass.csv" → "dark_grass"
func _layer_key(csv_path: String) -> String:
	return csv_path.get_file().get_basename().lstrip("_")


# For each tile in the dark_grass CSV, look up its [NW, NE, SW, SE] corner
# heights from _GRASS_CORNERS and accumulate them into the 4 surrounding
# vertex positions. Adjacent tiles always agree at shared corners in a
# properly autotiled map, so averaging gives the exact height.
func _accumulate_corners(vert_acc: PackedFloat32Array, vert_cnt: PackedFloat32Array,
		csv_path: String, cols: int, rows: int, stride: int) -> void:
	if not FileAccess.file_exists(csv_path):
		push_warning("TerrainGenerator: dark_grass CSV not found: " + csv_path)
		return
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return
	var row : int = 0
	while not file.eof_reached() and row < rows:
		var line : String = file.get_line().strip_edges()
		if line == "":
			continue
		var tokens : PackedStringArray = line.split(",")
		for col : int in range(mini(cols, tokens.size())):
			var tile_id : int = int(tokens[col])
			if tile_id >= 0 and tile_id < _GRASS_CORNERS.size():
				var c  : Array = _GRASS_CORNERS[tile_id]
				# NW = (col,   row),   NE = (col+1, row)
				# SW = (col,   row+1), SE = (col+1, row+1)
				var nw : int = col       + row       * stride
				var ne : int = (col + 1) + row       * stride
				var sw : int = col       + (row + 1) * stride
				var se : int = (col + 1) + (row + 1) * stride
				vert_acc[nw] += c[0];  vert_cnt[nw] += 1.0
				vert_acc[ne] += c[1];  vert_cnt[ne] += 1.0
				vert_acc[sw] += c[2];  vert_cnt[sw] += 1.0
				vert_acc[se] += c[3];  vert_cnt[se] += 1.0
		row += 1
	file.close()
