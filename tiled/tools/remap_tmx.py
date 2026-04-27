#!/usr/bin/env python3
"""
remap_tmx.py  —  Safe single-pass tile ID remapper for Tiled TMX files.

Usage:
  1. Edit the MAPPING dict below with your (old_tile_id → new_tile_id) pairs.
  2. Run:  python3 remap_tmx.py
  3. Reopen Tiled to verify, then re-export your CSV if needed.

How it works:
  All replacements happen simultaneously in one pass — no chain reactions.
  A→B and B→C in the same run is safe: the B that came from A will NOT
  be caught by the B→C rule (it was already processed).

Tile ID ↔ GID conversion (for this project):
  GID = tile_id + 96       (firstgid=97, local IDs are 0-based)
  tile_id = GID − 96
"""

import re

# ── Edit these two things only ────────────────────────────────────────────────

TMX_PATH = "/Users/Grproth/Desktop/Indie\ Project/tiled/level1/map.tmx"

MAPPING = {
    114: 115,   # 3x2 tree h=0 → 115
    115: 116,   # 3x2 tree h=1 → 116
    116: 117,   # 3x2 tree h=2 → 117
    117: 118,   # 1x1 grass    → 118
    118: 119,   # 2x2 grass    → 119
    119: 120,   # 3x3 grass    → 120
}

# ── Do not edit below this line ───────────────────────────────────────────────

FIRST_GID  = 97   # from <tileset firstgid="97" …> in your TMX

def to_gid(tile_id: int) -> int:
    return tile_id + FIRST_GID - 1   # local IDs are 0-based

gid_map = {to_gid(k): to_gid(v) for k, v in MAPPING.items()}

if not gid_map:
    print("MAPPING is empty — nothing to do.")
    raise SystemExit

# Warn about same-run chains (safe but worth flagging).
shared = set(gid_map) & set(gid_map.values())
if shared:
    shared_tiles = [g - FIRST_GID + 1 for g in shared]
    print(f"Note: tile(s) {shared_tiles} appear as both input and output.")
    print("Single-pass handles this safely, but double-check your intent.\n")

with open(TMX_PATH, "r", encoding="utf-8") as f:
    content = f.read()

# Count before.
before = {g: len(re.findall(rf"\b{g}\b", content)) for g in gid_map}

def replace(m: re.Match) -> str:
    g = int(m.group(0))
    return str(gid_map.get(g, g))

result = re.sub(r"\b\d+\b", replace, content)

# Report.
any_changed = False
for old_gid, new_gid in gid_map.items():
    n = before[old_gid]
    old_t = old_gid - FIRST_GID + 1
    new_t = new_gid - FIRST_GID + 1
    if n:
        print(f"  tile {old_t} → tile {new_t}: {n} tiles replaced")
        any_changed = True
    else:
        print(f"  tile {old_t} → tile {new_t}: 0 found (nothing changed)")

if any_changed:
    with open(TMX_PATH, "w", encoding="utf-8") as f:
        f.write(result)
    print("\nDone. Reopen Tiled to verify.")
else:
    print("\nNo tiles found — TMX not written.")
