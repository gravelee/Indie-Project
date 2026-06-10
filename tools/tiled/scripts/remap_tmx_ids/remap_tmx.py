#!/usr/bin/env python3
"""
remap_tmx.py  —  Safe single-pass tile ID remapper for Tiled TMX files.

Usage:
  1. Set TMX_PATH to the .tmx file you want to edit.
  2. Set TILESET to the name of the tileset layer you want to remap
     (matches the 'source' attribute in the TMX, filename only, no path needed).
  3. Edit MAPPING with your (old_tile_id → new_tile_id) pairs (0-based local IDs).
  4. Run:  python3 remap_tmx.py

How it works:
  The firstgid for the chosen tileset is read automatically from the TMX.
  All replacements happen simultaneously in one pass — no chain reactions.
  A→B and B→C in the same run is safe: the B that came from A will NOT
  be caught by the B→C rule (it was already processed).
"""

import re
import xml.etree.ElementTree as ET

# ── Edit these three things only ──────────────────────────────────────────────

TMX_PATH = "/Users/Grproth/Desktop/Indie Project/tools/tiled/level_01/map.tmx"

TILESET  = "entities.tsx"   # source name as it appears in the TMX

MAPPING  = {
    # Grassy bush added at IDs 125-142; trees+grass shifted +18.
    125: 143,   # tree 1x1_h0
    126: 144,   # tree 1x1_h1
    127: 145,   # tree 1x1_h2
    128: 146,   # tree 2x2_h0
    129: 147,   # tree 2x2_h1
    130: 148,   # tree 2x2_h2
    131: 149,   # tree 3x3_h0
    132: 150,   # tree 3x3_h1
    133: 151,   # tree 3x3_h2
    134: 152,   # grass 1x1
    135: 153,   # grass 2x2
    136: 154,   # grass 3x3
}

# ── Do not edit below this line ───────────────────────────────────────────────

# Read firstgid for the target tileset from the TMX.
tree     = ET.parse(TMX_PATH)
root     = tree.getroot()
first_gid = None
for ts in root.iter("tileset"):
    src = ts.get("source", "")
    if src.endswith(TILESET) or src == TILESET:
        first_gid = int(ts.get("firstgid"))
        break

if first_gid is None:
    raise SystemExit(f"Tileset '{TILESET}' not found in {TMX_PATH}.\n"
                     f"Available tilesets: "
                     + ", ".join(ts.get("source", "") for ts in root.iter("tileset")))

print(f"Tileset : {TILESET}  (firstgid={first_gid})")

if not MAPPING:
    raise SystemExit("MAPPING is empty — nothing to do.")


def to_gid(tile_id: int) -> int:
    return tile_id + first_gid


gid_map = {to_gid(k): to_gid(v) for k, v in MAPPING.items()}

# Warn about same-run chains (safe but worth flagging).
shared = set(gid_map) & set(gid_map.values())
if shared:
    shared_tiles = [g - first_gid for g in shared]
    print(f"Note: tile(s) {shared_tiles} appear as both input and output.")
    print("Single-pass handles this safely, but double-check your intent.\n")

with open(TMX_PATH, "r", encoding="utf-8") as f:
    content = f.read()

# Count occurrences before replacing.
before = {g: len(re.findall(rf"\b{g}\b", content)) for g in gid_map}

def replace(m: re.Match) -> str:
    g = int(m.group(0))
    return str(gid_map.get(g, g))

result = re.sub(r"\b\d+\b", replace, content)

# Report.
any_changed = False
for old_gid, new_gid in gid_map.items():
    n        = before[old_gid]
    old_tid  = old_gid - first_gid
    new_tid  = new_gid - first_gid
    if n:
        print(f"  tile {old_tid:3d} → tile {new_tid:3d}:  {n} replaced")
        any_changed = True
    else:
        print(f"  tile {old_tid:3d} → tile {new_tid:3d}:  0 found (nothing changed)")

if any_changed:
    with open(TMX_PATH, "w", encoding="utf-8") as f:
        f.write(result)
    print("\nDone. Reopen Tiled to verify.")
else:
    print("\nNo tiles found — TMX not written.")
