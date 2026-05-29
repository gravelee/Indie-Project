#!/usr/bin/env python3
"""
autotile.py — Multi-phase terrain map generator using the TILESET_TSX tileset.

Phase 0. Read INPUT_TMX if it exists.
  If input.tmx is present, skip phases 1 and 2 and jump straight to phase 3.
  Only the layer named after TILESET_TSX (e.g. 'dark_grass') is extracted and
  smoothed; all other layers are carried through unchanged.  The output
  map_autotile_smooth.tmx is the full multi-layer TMX with only that layer
  replaced.

Phase 1. Cellular Automata (9-point).
  If no input file is found, generates a binary TERRAIN/NONE grid using a
  Moore-neighbourhood CA.  Saves every iteration (plus the initial random state)
  as a TMX into ca_grids/ and copies TILESET_TSX there too.

Phase 2. 4-point tile matching (dual-grid).
  Builds a tile grid offset by half a tile from the CA grid.  For each tile
  position, reads the four surrounding CA cells as [NW, NE, SW, SE] and picks
  the matching tile from tile_values.json (random choice when multiple match).
  GID = tile_id + 1.  Writes map_autotile.tmx.

Phase 3. Corner smoothing.
  Three passes over the tile grid:
  1. Outer corners (OUTER_CORNERS) smoothed left-to-right, top-to-bottom.
     Each outer or double-outer tile checks the two orthogonal neighbours that
     share each terrain corner.  When both qualify the corner is smoothed:
     all terrain corners removed → full NONE; one of two removed → single-corner
     tile.  Each qualifying neighbour's facing corner becomes -1 and is replaced
     by a smooth or extra-smooth tile (LAST_BASIC_TILE+1 … LAST_DOUBLE_SMOOTH).
  2. Inner corners (INNER_CORNERS), same logic, full TERRAIN replacement.
  3. Remaining basic line tiles (1,3,11,13) upgraded to smooth variants (45–48).
  Writes map_autotile_smooth.tmx.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONFIG
  TILESET_TSX          Tileset filename.  Also used as the layer selector when
                       reading a multi-layer input.tmx (layer name = stem of this
                       filename, e.g. 'dark_grass.tsx' → layer 'dark_grass').
  GRID_W / GRID_H      Output map size in tiles.
  TILE_SIZE            The tile size in pixels.
  LAST_BASIC_TILE      Highest tile ID of the basic tiles     (0–17).
  LAST_SMOOTH_TILE     Highest tile ID of the single-blend smooth tiles (18–33).
  LAST_DOUBLE_SMOOTH   Highest tile ID overall; extra-smooth tiles end here (34–49).
  FILL_DENSITY         Initial TERRAIN probability (0.0–1.0).
  CA_ITERATIONS        CA passes (5–8 gives natural blobs).
  BIRTH_THRESHOLD      NONE → TERRAIN when Moore TERRAIN-count ≥ N.
  SURVIVAL_THRESHOLD   TERRAIN stays when Moore TERRAIN-count ≥ N.
  BORDER               1 (TERRAIN) or 0 (NONE) — cell value beyond map edges.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

import os
import json
import random
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path


# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------

# Tileset parameters
TILESET_TSX        = "dark_grass.tsx"
TILE_SIZE          = 32
LAST_BASIC_TILE    = 17
LAST_SMOOTH_TILE   = 33
LAST_DOUBLE_SMOOTH = 49

# Grid parameters
GRID_W             = 100
GRID_H             = 100
BORDER             = 1 # 1 for TERRAIN / 0 for NONE.

# CA parameters
FILL_DENSITY       = 0.50
CA_ITERATIONS      = 4
BIRTH_THRESHOLD    = 5
SURVIVAL_THRESHOLD = 5


# ---------------------------------------------------------------------------
# Paths / Tileset constants.
# ---------------------------------------------------------------------------

TERRAIN = 1
NONE    = 0

SCRIPTS_DIR        = Path(__file__).parent
TILE_VALUES_JSON   = SCRIPTS_DIR / "tile_values.json"

INPUT_TMX          = SCRIPTS_DIR / "input.tmx"
OUTPUT_TMX_1       = SCRIPTS_DIR
OUTPUT_TMX_2       = SCRIPTS_DIR / "map_autotile.tmx"
OUTPUT_TMX_3       = SCRIPTS_DIR / "map_autotile_smooth.tmx"

TILESET_FIRST_GID  = 1


# ---------------------------------------------------------------------------
# Read input tmx — Phase 0.
# ---------------------------------------------------------------------------

# Called: main().
def read_tmx(path: Path, tileset: str) -> tuple[list[list[int]], ET.ElementTree, ET.Element]:

    """
    Parse the GID grid for a specific tileset layer from a (possibly multi-layer) TMX.

    Finds the layer whose name matches the tileset filename stem (e.g. 'dark_grass'
    for 'dark_grass.tsx') and returns:
      gid_grid   — 2-D list of raw GIDs for that layer only.
      xml_tree   — the full parsed XML tree (all layers intact, for patching).
      data_elem  — the <data> XML element of the target layer (for write_patched_tmx).
    """
    tree = ET.parse(path)
    root = tree.getroot()

    layer_name = Path(tileset).stem   # "dark_grass.tsx" → "dark_grass"

    data_elem = None
    for layer in root.iter("layer"):
        if layer.get("name") == layer_name:
            data_elem = layer.find("data")
            break

    if data_elem is None:
        available = [l.get("name", "") for l in root.iter("layer")]
        raise SystemExit(f"Layer '{layer_name}' not found in {path}.\n"
                         f"Available layers: {available}")

    rows = []
    for line in data_elem.text.strip().split("\n"):
        line = line.strip().rstrip(",")
        if line:
            rows.append([int(x) for x in line.split(",")])

    return rows, tree, data_elem


# ---------------------------------------------------------------------------
# Cellular Automata — Phase 1.
# ---------------------------------------------------------------------------

# Called: main().
def generate_ca_grid() -> list[list[int]]:

    rows, cols = GRID_H, GRID_W
    # Init grid randomly with 1s and 0s.
    grid = [
        [TERRAIN if random.random() >= FILL_DENSITY else NONE for _ in range(cols)]
        for _ in range(rows)
    ]

    # Create ca_grids folder if not exists.
    try:
        os.mkdir("ca_grids")
    except FileExistsError:
        pass

    # Copy TILESET_TSX file into ca_grids (updating xml image source path too).
    move_tsx(SCRIPTS_DIR / TILESET_TSX, TILESET_TSX)

    # Create tmx files for all steps of the CA algorithm into ca_grids.
    count = 0
    ca_tile_grid = build_ca_tile_grid(grid)
    write_tmx(ca_tile_grid, OUTPUT_TMX_1 / f"ca_grids/map_ca_{count}.tmx")

    # CA main loop.
    for _ in range(CA_ITERATIONS):
        # Init next_grid with 0s.
        next_grid = [[0] * cols for _ in range(rows)]

        for r in range(rows):
            for c in range(cols):

                # For every cell check moores law for cell survival or birth.
                n = _moore_grass_count(grid, r, c)
                if grid[r][c] == TERRAIN:
                    next_grid[r][c] = TERRAIN if n >= SURVIVAL_THRESHOLD else NONE
                else:
                    next_grid[r][c] = TERRAIN if n >= BIRTH_THRESHOLD else NONE
        grid = next_grid
        count += 1

        # Create tmx files for all steps of the CA algorithm into ca_grids.
        ca_tile_grid = build_ca_tile_grid(grid)
        write_tmx(ca_tile_grid, OUTPUT_TMX_1 / f"ca_grids/map_ca_{count}.tmx")

    # Statistics.
    pct = sum(grid[r][c] for r in range(rows) for c in range(cols)) / (rows * cols) * 100
    print(f"  CA grid {cols}×{rows}: {pct:.1f}% grass  {100-pct:.1f}% dirt\n")
    return grid


# Called: generate_ca_grid().
def move_tsx(path_str: Path, file_name: str) -> None:

    # Update the xml style (.tsx) file with the new path and copy it into ca_grids.
    mytree = ET.parse(path_str)
    myroot = mytree.getroot()
    image_atr : dict = myroot[0].attrib
    updated_source = "../" + image_atr["source"]
    image_atr["source"] = updated_source
    mytree.write("ca_grids/" + file_name)


# Called: generate_ca_grid().
def build_ca_tile_grid(ca_grid: list[list[int]]) -> list[list[int]]:

    rows, cols = len(ca_grid), len(ca_grid[0])
    tile_grid = [[0] * cols for _ in range(rows)]

    for r in range(rows):
        for c in range(cols):
            if ca_grid[r][c] == TERRAIN:
                tile_grid[r][c] = 8  # Full terrain tile (tile 7, GID 8).
            else:
                tile_grid[r][c] = 15 # Full none tile    (tile 14, GID 15).
    return tile_grid


# Called: generate_ca_grid().
def _moore_grass_count(grid, r, c):

    rows, cols = len(grid), len(grid[0])
    border = _border_value()
    count = 0
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            nr, nc = r + dr, c + dc
            count += grid[nr][nc] if 0 <= nr < rows and 0 <= nc < cols else border
    return count


# Called: _moore_grass_count(), build_tile_grid().
def _border_value() -> int:

    return TERRAIN if BORDER == 1 else NONE


# ---------------------------------------------------------------------------
# 4-point tile matching — Phase 2.
# ---------------------------------------------------------------------------

# Called: main().
def load_tile_values(path: Path) -> tuple[list[tuple[int, list[int]]], dict[int, list[int] | None]]:

    """
    Returns:
      candidates — List of (tile_id, pattern) for every non-empty tile.
      tile_data  — Dict {tile_id: pattern | None} for all tiles (None = empty).
    pattern = [NW, NE, SW, SE]
    """
    with open(path) as f:
        data = json.load(f)

    candidates = []
    tile_data: dict[int, list[int] | None] = {}
    for tid_str, val in data["tiles"].items():

        tid = int(tid_str)
        if val == "empty":
            tile_data[tid] = None
            continue

        tile_data[tid] = val
        candidates.append((tid, val))

    candidates.sort(key=lambda x: x[0])
    return candidates, tile_data


# ---------------------------------------------------------------------------
# 4-point tile matching — Phase 2  (dual-grid system).
# ---------------------------------------------------------------------------
#
# The tile grid is offset by half a tile from the CA (data) grid.
# Each tile sits at the intersection of 4 CA cells and reads one corner value
# from each of those cells:
#
#   CA grid                Tile grid (offset by 0.5)
#   ·─────·─────·          ·─────·─────·
#   │     │     │          │  T  │  T  │
#   · NW  · NE  ·          ·─────·─────·
#   │     │     │          │  T  │  T  │
#   · SW  · SE  ·          ·─────·─────·
#   │     │     │
#   ·─────·─────·
#
#   Tile (r, c):
#       NW corner = ca[r-1][c-1]
#       NE corner = ca[r-1][c  ]
#       SW corner = ca[r  ][c-1]
#       SE corner = ca[r  ][c  ]
#
# Adjacent tiles share corners automatically because they read the SAME CA cell
# at the shared point — no inter-tile constraint propagation is needed.


# Called: main().
def build_tile_grid(
    ca_grid:    list[list[int]],
    candidates: list[tuple[int, list[int]]],
    tile_data:  dict[int, list[int] | None],
) -> list[list[int]]:

    """
    Phase 2 — Dual-grid tile placement.

    For each tile position (r, c) read the four surrounding CA cells and pick
    the tile whose [NW, NE, SW, SE] pattern matches (ties broken randomly for
    visual variety).  No sequential propagation is needed: any two adjacent
    tiles that share a visual corner both read the exact same CA cell for that
    corner, so they are always consistent.
    """
    rows, cols = len(ca_grid), len(ca_grid[0])
    tile_grid  = [[0] * cols for _ in range(rows)]
    border     = _border_value()


    def ca_val(r: int, c: int) -> int:

        return ca_grid[r][c] if 0 <= r < rows and 0 <= c < cols else border


    for r in range(rows):
        for c in range(cols):

            required = [
                ca_val(r - 1, c - 1),   # NW
                ca_val(r - 1, c    ),   # NE
                ca_val(r,     c - 1),   # SW
                ca_val(r,     c    ),   # SE
            ]

            tid = pick_tile(required, candidates)

            if tid == -1:
                # Should never happen if tile_values.json covers all 16 patterns.
                print(f"No tile found  row={r} col={c}  pattern={required}")
                tile_grid[r][c] = None
            else:
                tile_grid[r][c] = tid + TILESET_FIRST_GID

    return tile_grid


# Called: build_tile_grid().
def pick_tile(required: list[int], candidates: list[tuple[int, list[int]]]) -> int:

    """
    Return a tile ID whose 4-point pattern matches `required`.
    When multiple tiles match (visual variants), one is chosen at random.
    Returns -1 if no tile matches.
    """
    matches: list[int] = []

    for tid, pattern in candidates:
        if tid > LAST_BASIC_TILE:
            break
        if _match(required, pattern):
            matches.append(tid)

    if matches:
        return random.choice(matches)
    return -1


# Called: pick_tile().
def _match(required: list[int], pattern: list[int]) -> bool:

    """
    True if the tile pattern matches the required [NW, NE, SW, SE] values.
    """
    return all(p == r for p, r in zip(pattern, required))


# Called: main().
def smooth_tile_grid(
    tile_grid : list[list[int]],
    tile_data : dict[int, list[int] | None],
) -> list[list[int]]:

    """
    Phase 3 — Corner smoothing.  Three sequential passes.

    Pass 1 — outer corners (OUTER_CORNERS, left-to-right top-to-bottom):
      For each outer-corner or double-outer tile, checks the two orthogonal
      tile-neighbours that share each terrain corner.  If both neighbours of a
      corner qualify, that corner is smoothed:
        • All terrain corners removed  →  center becomes full-none (tile 14).
        • One of two terrain corners removed  →  center reduced to the matching
          single-corner tile (looked up in the basic range 0…LAST_BASIC_TILE).
      Each qualifying neighbour has its facing corner set to -1 and is replaced
      by the matching smooth/extra-smooth tile (range LAST_BASIC_TILE+1…
      LAST_DOUBLE_SMOOTH).  Double-inner tiles (5, 17) are never used as side
      tiles in this pass — no tileset tiles exist to represent that blend.

    Pass 2 — inner corners (INNER_CORNERS, same scan order):
      Identical logic with corner_val = 0 (none corners) and full-terrain (tile
      7) as the full replacement.  Double-outer tiles (4, 9) are excluded as
      side tiles for the same reason.

    Pass 3 — line upgrade:
      Any basic line tile that was not consumed as a side tile during passes 1–2
      is upgraded to its smooth visual variant (1→45, 3→46, 11→47, 13→48).
    """

    # NEIGHBOURS[corner_idx] — the two orthogonal tile-neighbours that share
    # corner_idx with the current tile, as (row_offset, col_offset) pairs.
    # Phase 2 guarantees each neighbour's facing corner holds the same CA value
    # as our corner (both read the same CA cell), so they are always consistent.
    #   NW (0): west (0,-1)  and north (-1, 0)
    #   NE (1): north(-1, 0) and east  ( 0,+1)
    #   SW (2): south(+1, 0) and west  ( 0,-1)
    #   SE (3): east ( 0,+1) and south (+1, 0)
    NEIGHBOURS = [
        [(0,-1), (-1, 0)],
        [(-1,0), ( 0, 1)],
        [(1, 0), ( 0,-1)],
        [(0, 1), ( 1, 0)],
    ]

    # NEIGHBOUR_INDEX[(row_off, col_off, own_corner_idx)] → neighbour_corner_idx.
    # Given the direction we stepped and our own corner, returns which corner
    # index on the neighbour tile connects back to the same ca_grid point.
    # Used in pass 1/2 to identify which corner of the neighbour to set to -1.
    NEIGHBOUR_INDEX = {
        ( 0, -1, 0): 1,   # stepped west  from our NW → neighbour's NE faces back
        (-1,  0, 0): 2,   # stepped north from our NW → neighbour's SW faces back
        (-1,  0, 1): 3,   # stepped north from our NE → neighbour's SE faces back
        ( 0,  1, 1): 0,   # stepped east  from our NE → neighbour's NW faces back
        ( 1,  0, 2): 0,   # stepped south from our SW → neighbour's NW faces back
        ( 0, -1, 2): 3,   # stepped west  from our SW → neighbour's SE faces back
        ( 0,  1, 3): 2,   # stepped east  from our SE → neighbour's SW faces back
        ( 1,  0, 3): 1,   # stepped south from our SE → neighbour's NE faces back
    }

    FULL_TERRAIN  = 7
    FULL_EMPTY    = 14
    LINES         = [1, 3, 11, 13]
    OUTER_CORNERS = {0, 4, 9, 10, 15, 16}   # tiles with one or two terrain corners
    INNER_CORNERS = {2, 5, 6, 8, 12, 17}    # tiles with one or two none corners
    DOUBLE_OUTER  = {4, 9}                   # two terrain corners (subset of OUTER_CORNERS)
    DOUBLE_INNER  = {5, 17}                  # two none corners    (subset of INNER_CORNERS)
    LINES_SMOOTH  = [45, 46, 47, 48]         # visual upgrade of LINES, same corner values

    def find_tid(pattern: list[int], from_tid: int, to_tid: int) -> int:

        for tid in range(from_tid, to_tid + 1):
            p = tile_data.get(tid)
            if p is not None and p == pattern:
                return tid
        return -1

    rows  = len(tile_grid)
    cols  = len(tile_grid[0]) if rows else 0
    smooth = [row[:] for row in tile_grid]

    # Pass 1 defaults (outer corners); pass 2 overrides these at run == 1.
    corner_set = OUTER_CORNERS   # tiles eligible as the center of a smoothing op
    double_set = DOUBLE_INNER    # tiles excluded as side tiles in this pass
    corner_val = 1               # the corner value that marks a "key" corner (terrain)
    full_type  = FULL_EMPTY      # tile_id to replace center with when fully smoothed
    for run in range(0, 2):

        if run == 1:   # pass 2 — inner corners
            corner_set = INNER_CORNERS
            double_set = DOUBLE_OUTER
            corner_val = 0               # key corner value is none
            full_type  = FULL_TERRAIN

        for tile_row in range(rows):
            for tile_col in range(cols):

                tile_id = smooth[tile_row][tile_col] - TILESET_FIRST_GID

                if tile_id in corner_set:
                    pat     = tile_data[tile_id]
                    # Collect all corner indices that hold a key value (1 for
                    # outer pass, 0 for inner pass).  Single-corner tiles yield
                    # one index; double tiles yield two.
                    corners = [i for i in range(len(pat)) if int(pat[i]) == corner_val]
                else:
                    continue

                # For each key corner, add its two orthogonal neighbours to
                # border — but only if they are not other corner/double tiles
                # (no tileset tiles exist to blend those transitions).
                # If a corner finds only one qualifying neighbour instead of
                # two, that single entry is discarded: both neighbours must
                # qualify for a corner to be smoothed.
                border = []
                for index in corners:
                    for x, y in NEIGHBOURS[index]:
                        cx = tile_row + x
                        cy = tile_col + y
                        if not (0 <= cx < rows and 0 <= cy < cols):
                            continue
                        neighbor_tid = smooth[cx][cy] - TILESET_FIRST_GID
                        if neighbor_tid in corner_set or neighbor_tid in double_set:
                            continue
                        neighbor_pat   = tile_data.get(neighbor_tid)
                        neighbor_index = NEIGHBOUR_INDEX[(x, y, index)]
                        border.append((cy, cx, neighbor_index, index, neighbor_pat))

                    # Odd count means only one of this corner's two neighbours
                    # qualified — discard it, this corner will not be smoothed.
                    if len(border) % 2 == 1:
                        border.pop()

                corner_count = len(corners)
                border_count = len(border)

                if border_count == 0:
                    continue
                elif (corner_count == 1 and border_count == 2) or border_count == 4:
                    # All key corners smoothed: replace center with the full tile.
                    smooth[tile_row][tile_col] = full_type + TILESET_FIRST_GID
                else:
                    # corner_count == 2 and border_count == 2: only one of the
                    # two corners qualified.  Flip that corner's value to produce
                    # the matching single-corner tile in the basic range.
                    idx     = border[0][3]   # corner index that will be removed
                    new_pat = pat[:]
                    new_pat[idx] = 1 - corner_val
                    new_tid = find_tid(new_pat, 0, LAST_BASIC_TILE)
                    smooth[tile_row][tile_col] = new_tid + TILESET_FIRST_GID

                # Set each qualifying neighbour's facing corner to -1 and look
                # up the resulting smooth (or extra-smooth) tile.
                for cy, cx, neighbor_index, _, neighbor_pat in border:
                    new_pat        = list(neighbor_pat)
                    new_pat[neighbor_index] = -1
                    new_tid = find_tid(new_pat, LAST_BASIC_TILE + 1, LAST_DOUBLE_SMOOTH)
                    if new_tid != -1:
                        smooth[cx][cy] = new_tid + TILESET_FIRST_GID
                    else:
                        print(f"  Warning: no smooth tile for {new_pat} at ({cy},{cx})")

    # Pass 3 — upgrade any basic line tile that was not consumed as a side tile
    # during passes 1–2 to its smooth visual variant (same corner values).
    for tile_row in range(rows):
        for tile_col in range(cols):
            tile_id = smooth[tile_row][tile_col] - TILESET_FIRST_GID
            for basic, upgraded in zip(LINES, LINES_SMOOTH):
                if tile_id == basic:
                    smooth[tile_row][tile_col] = upgraded + TILESET_FIRST_GID
                    break

    return smooth


# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------

# Called: main().
def report(tile_grid: list[list[int]]) -> None:

    flat = [tile_grid[r][c] for r in range(len(tile_grid)) for c in range(len(tile_grid[0]))]
    counts = Counter(flat)
    total = len(flat)
    print("  All tiles:")
    for gid, n in counts.most_common():
        lid = gid - TILESET_FIRST_GID
        print(f"    GID {gid:4d}  (tile {lid:3d})  {n:5d}  ({n/total*100:.1f}%)")
    print()


# ---------------------------------------------------------------------------
# TMX writer
# ---------------------------------------------------------------------------

# Called: main().
def write_tmx(tile_grid: list[list[int]], path: Path) -> None:

    rows, cols = len(tile_grid), len(tile_grid[0])
    csv_lines = []
    for r, row in enumerate(tile_grid):
        line = ",".join(str(gid) for gid in row)
        if r < rows - 1:
            line += ","
        csv_lines.append(line)

    tmx = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<map version="1.10" tiledversion="1.11.0" orientation="orthogonal" '
        f'renderorder="right-down" width="{cols}" height="{rows}" '
        f'tilewidth="{TILE_SIZE}" tileheight="{TILE_SIZE}" infinite="0" '
        f'nextlayerid="2" nextobjectid="1">\n'
        f' <tileset firstgid="{TILESET_FIRST_GID}" source="{TILESET_TSX}"/>\n'
        f' <layer id="1" name="Terrain" width="{cols}" height="{rows}">\n'
        f'  <data encoding="csv">\n{"\n".join(csv_lines)}\n</data>\n'
        f' </layer>\n'
        f'</map>\n'
    )
    path.write_text(tmx, encoding="utf-8")
    print(f"  Written: {path}  ({cols}×{rows} tiles)\n")


# Called: main() — Phase 0 output path only.
def write_patched_tmx(
    xml_tree:  ET.ElementTree,
    data_elem: ET.Element,
    tile_grid: list[list[int]],
    path:      Path,
) -> None:

    """
    Replace the CSV data inside `data_elem` with `tile_grid` and write the
    full XML tree (all layers) to `path`.  All other layers are untouched.
    """
    rows, cols = len(tile_grid), len(tile_grid[0])
    csv_lines = []
    for r, row in enumerate(tile_grid):
        line = ",".join(str(gid) for gid in row)
        if r < rows - 1:
            line += ","
        csv_lines.append(line)

    data_elem.text = "\n" + "\n".join(csv_lines) + "\n"

    import io
    buf = io.StringIO()
    xml_tree.write(buf, encoding="unicode", xml_declaration=False)
    path.write_text('<?xml version="1.0" encoding="UTF-8"?>\n' + buf.getvalue(),
                    encoding="utf-8")
    print(f"  Written: {path}  ({cols}×{rows} tiles, {TILESET_TSX} layer only)\n")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:

    if INPUT_TMX.exists():

        print(f"  Reading '{TILESET_TSX}' layer from {INPUT_TMX.name}.\n")
        phase3_input, xml_tree, data_elem = read_tmx(INPUT_TMX, TILESET_TSX)
        _, tile_data = load_tile_values(TILE_VALUES_JSON)

    else:

        xml_tree  = None
        data_elem = None

        print("\nPhase 1 — Cellular Automata …\n")
        ca_grid = generate_ca_grid()
        candidates, tile_data = load_tile_values(TILE_VALUES_JSON)

        print("Phase 2 — 4-point constraint matching …\n")
        print(f"  Loaded {len(candidates)} tiles from tile_values.json\n")
        tile_grid = build_tile_grid(ca_grid, candidates, tile_data)
        report(tile_grid)
        write_tmx(tile_grid, OUTPUT_TMX_2)

        phase3_input = tile_grid

    print("Phase 3 — Corner smoothing …\n")
    smooth_grid = smooth_tile_grid(phase3_input, tile_data)
    report(smooth_grid)

    if xml_tree is not None:
        # Phase 0 path: patch only the target layer and preserve all others.
        write_patched_tmx(xml_tree, data_elem, smooth_grid, OUTPUT_TMX_3)
    else:
        write_tmx(smooth_grid, OUTPUT_TMX_3)

    print("\n  Done.  Open the .tmx outputs in Tiled to review.\n")


if __name__ == "__main__":

    main()
