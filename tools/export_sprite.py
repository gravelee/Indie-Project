#!/usr/bin/env python3
"""
Sprite export tool for Echoes of the Void.

Run:  python3 tools/export_sprite.py

────────────────────────────────────────────────────────
ENTITY exports (EXPORTS list)
  Reads numbered frames (0.png, 1.png … N.png) from an art_source folder,
  assembles them into a horizontal strip, applies rotsprite scale-up by SCALE,
  and writes the result to the game assets path.
  Also saves an unscaled 0-sheet.png preview back into the source folder.
  Used for: player, rat, snake — anything drawn at small base size.

PROP exports (PROP_DIRS + SCALABLE_PROPS)
  Scalable props (bush, grass, tree):
    Only the smallest source size(s) need to exist in art_source.
    All larger sizes are generated automatically via rotsprite:
      bush  → frames directly in the animation folder (bump/0.png, bump/1.png …)
              generates 1x1 (1×), 2x2 (2×), 3x3 (3×)
      grass → same — generates 1x1 (1×), 2x1 (2×), 3x1 (3×)
      tree  → flat PNG files (1x1.png, 1x1_h1.png …) — generates 2x2/2x2_h*, 3x3/3x3_h*
    bush/grass: numbered frames (0.png, 1.png …) sit directly in the animation folder.
    The script detects them automatically — no size subfolder needed.
    tree: still flat PNG files (single-frame sprites, not animations).
    Any old derived-size files (2x2, 3x3 …) still in art_source are silently ignored.
    To add a new scalable prop type: add an entry to SCALABLE_PROPS below.

TILEMAP exports (pass-through)
  Every .png in art_source/tilemaps/ is copied as-is (PROP_SCALE=1).
  Tilemaps are pixel art drawn at final resolution — no scaling needed.
────────────────────────────────────────────────────────
"""

from PIL import Image
import os
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── Settings ──────────────────────────────────────────────────────────────────

SCALE  = 3           # entity upscale factor  (3 → 32 px becomes 96 px per frame)

METHOD = "rotsprite"  # "nearest"   — nearest-neighbor (sharp, no edge smoothing)
                      # "rotsprite" — pixel-art aware, same as LibreSprite RotSprite
                      #               decomposes SCALE into 2x/3x steps (e.g. 6=2×3,
                      #               4=2×2, 9=3×3). Any leftover factor uses nearest.
                      # "bilinear"  — smooth blur (not recommended for pixel art)
                      # "lanczos"   — high quality but also blurs pixel art

# Prop/tilemap scale — 1 = straight copy (already at game resolution).
# Raise to 2+ if you redraw props at a smaller base resolution.
PROP_SCALE = 1

# ── Prop/Tilemap auto-discovery ───────────────────────────────────────────────
# art_source/props/ is the single source for all props (bush, grass, tree).
# Output is routed automatically by frame count — both go to assets/gfx/props/:
#   1 frame  → echoes_of_the_void/assets/gfx/props/  (idle stills)
#   2+ frames → echoes_of_the_void/assets/gfx/props/  (animations)
# Tilemaps are a separate pass-through source — always copied as-is.
PROP_SRC         = "art_source/props"
DST_PROPS        = "echoes_of_the_void/assets/gfx/props"

TILEMAP_DIRS = [
    ("art_source/tilemaps", "echoes_of_the_void/assets/gfx/tilemaps"),
]

# ── Scalable prop rules ───────────────────────────────────────────────────────
# Two rule formats:
#
#   Frame-folder props (bush, grass) — rule is a flat list [(out_stem, scale)]:
#     Numbered PNGs (0.png, 1.png …) sit directly in the animation folder.
#     The script assembles them into a strip and emits all listed output sizes.
#     Any plain .png files inside a frame-folder path (numbered frames) are
#     silently skipped in the flat-file loop — they are handled as a batch.
#
#   File-based props (tree) — rule is a dict {source_stem: [(out_stem, scale)]}:
#     Source files are flat PNGs (1x1.png, 1x1_h1.png …). Stem lookup picks
#     the right output list. Unlisted stems are derived sizes → silently skipped.
#
#   Pass-through (tilemaps / anything not matched): copied as-is at PROP_SCALE.
#
# Scaling is uniform: the whole image (or assembled strip) is scaled, so every
# animation frame scales identically.
#
# To add a new scalable prop type: add an entry here.

SCALABLE_PROPS = {
    # Frame-folder props: flat list of (out_stem, scale)
    "/bush/":  [("1x1", 1), ("2x2", 2), ("3x3", 3)],
    "/grass/": [("1x1", 1), ("2x2", 2), ("3x3", 3)],

    # File-based props: dict keyed by source stem
    "/tree/":  {
        "h0": [("1x1_h0", 1), ("2x2_h0", 2), ("3x3_h0", 3)],
        "h1": [("1x1_h1", 1), ("2x2_h1", 2), ("3x3_h1", 3)],
        "h2": [("1x1_h2", 1), ("2x2_h2", 2), ("3x3_h2", 3)],
    },
}

# ── Export list ───────────────────────────────────────────────────────────────
# Each entry: (source_frames_folder, game_asset_output_path)
# Optional 3rd element: flip_h=True  — mirrors every frame horizontally before
#   assembling. Use for creatures whose source art faces left (e.g. snake) so
#   all game assets face right, matching the flip_h logic in creature.gd.
# Both paths are relative to the project root.
# Add or comment out entries as needed.

_R = "art_source/entities/creatures/rat/frames"
_RO = "echoes_of_the_void/assets/gfx/entities/creatures/rat"

_S = "art_source/entities/creatures/snake/frames"
_SO = "echoes_of_the_void/assets/gfx/entities/creatures/snake"

_P = "art_source/entities/player/ares/frames"
_PO = "echoes_of_the_void/assets/gfx/entities/player/ares"

EXPORTS = [
    # ── PLAYER (4-direction, no front/back) ───────────────────────────────────
    (f"{_P}/south/idle_neutral",  f"{_PO}/idle_neutral_south.png"),
    (f"{_P}/north/idle_neutral",  f"{_PO}/idle_neutral_north.png"),
    (f"{_P}/east/idle_neutral",   f"{_PO}/idle_neutral_east.png"),
    (f"{_P}/west/idle_neutral",   f"{_PO}/idle_neutral_west.png"),

    (f"{_P}/south/idle_attack/unarmed",  f"{_PO}/idle_attack_unarmed_south.png"),
    (f"{_P}/north/idle_attack/unarmed",  f"{_PO}/idle_attack_unarmed_north.png"),
    (f"{_P}/east/idle_attack/unarmed",   f"{_PO}/idle_attack_unarmed_east.png"),
    (f"{_P}/west/idle_attack/unarmed",   f"{_PO}/idle_attack_unarmed_west.png"),

    (f"{_P}/south/walking",       f"{_PO}/walking_south.png"),
    (f"{_P}/north/walking",       f"{_PO}/walking_north.png"),
    (f"{_P}/east/walking",        f"{_PO}/walking_east.png"),
    (f"{_P}/west/walking",        f"{_PO}/walking_west.png"),

    (f"{_P}/south/running",       f"{_PO}/running_south.png"),
    (f"{_P}/north/running",       f"{_PO}/running_north.png"),
    (f"{_P}/east/running",        f"{_PO}/running_east.png"),
    (f"{_P}/west/running",        f"{_PO}/running_west.png"),

    (f"{_P}/south/attack/unarmed",  f"{_PO}/attack_unarmed_south.png"),
    (f"{_P}/north/attack/unarmed",  f"{_PO}/attack_unarmed_north.png"),
    (f"{_P}/east/attack/unarmed",   f"{_PO}/attack_unarmed_east.png"),
    (f"{_P}/west/attack/unarmed",   f"{_PO}/attack_unarmed_west.png"),

    (f"{_P}/south/push",          f"{_PO}/push_south.png"),
    (f"{_P}/north/push",          f"{_PO}/push_north.png"),
    (f"{_P}/east/push",           f"{_PO}/push_east.png"),
    (f"{_P}/west/push",           f"{_PO}/push_west.png"),

    (f"{_P}/south/pull",          f"{_PO}/pull_south.png"),
    (f"{_P}/north/pull",          f"{_PO}/pull_north.png"),
    (f"{_P}/east/pull",           f"{_PO}/pull_east.png"),
    (f"{_P}/west/pull",           f"{_PO}/pull_west.png"),

    (f"{_P}/south/grab",          f"{_PO}/grab_south.png"),
    (f"{_P}/north/grab",          f"{_PO}/grab_north.png"),
    (f"{_P}/east/grab",           f"{_PO}/grab_east.png"),
    (f"{_P}/west/grab",           f"{_PO}/grab_west.png"),

    (f"{_P}/south/jump",          f"{_PO}/jump_south.png"),
    (f"{_P}/north/jump",          f"{_PO}/jump_north.png"),
    (f"{_P}/east/jump",           f"{_PO}/jump_east.png"),
    (f"{_P}/west/jump",           f"{_PO}/jump_west.png"),

    (f"{_P}/spawn",               f"{_PO}/spawn.png"),
    (f"{_P}/death",               f"{_PO}/death.png"),

    # ── RAT (source faces right — no flip needed) ─────────────────────────────
    (f"{_R}/idle_neutral/front",    f"{_RO}/idle_neutral_front.png"),
    (f"{_R}/idle_neutral/back",     f"{_RO}/idle_neutral_back.png"),
    (f"{_R}/wander/front",          f"{_RO}/wander_front.png"),
    (f"{_R}/wander/back",           f"{_RO}/wander_back.png"),
    (f"{_R}/run/front",             f"{_RO}/run_front.png"),
    (f"{_R}/run/back",              f"{_RO}/run_back.png"),
    (f"{_R}/notice/front",          f"{_RO}/notice_front.png"),
    (f"{_R}/notice/back",           f"{_RO}/notice_back.png"),
    (f"{_R}/neutral_to_attack/front", f"{_RO}/neutral_to_attack_front.png"),
    (f"{_R}/neutral_to_attack/back",  f"{_RO}/neutral_to_attack_back.png"),
    (f"{_R}/idle_attack/front",     f"{_RO}/idle_attack_front.png"),
    (f"{_R}/idle_attack/back",      f"{_RO}/idle_attack_back.png"),
    (f"{_R}/attack_bite/front",     f"{_RO}/attack_bite_front.png"),
    (f"{_R}/attack_bite/back",      f"{_RO}/attack_bite_back.png"),
    (f"{_R}/attack_slash/front",    f"{_RO}/attack_slash_front.png"),
    (f"{_R}/attack_slash/back",     f"{_RO}/attack_slash_back.png"),
    (f"{_R}/attack_to_neutral/front", f"{_RO}/attack_to_neutral_front.png"),
    (f"{_R}/attack_to_neutral/back",  f"{_RO}/attack_to_neutral_back.png"),
    (f"{_R}/death/front",           f"{_RO}/death_front.png"),
    (f"{_R}/death/back",            f"{_RO}/death_back.png"),

    # ── SNAKE (source faces left — flip_h=True to match rat convention) ───────
    (f"{_S}/idle_neutral/front",    f"{_SO}/idle_neutral_front.png"),
    (f"{_S}/idle_neutral/back",     f"{_SO}/idle_neutral_back.png"),
    (f"{_S}/wander/front",          f"{_SO}/wander_front.png"),
    (f"{_S}/wander/back",           f"{_SO}/wander_back.png"),
    (f"{_S}/run/front",             f"{_SO}/run_front.png"),
    (f"{_S}/run/back",              f"{_SO}/run_back.png"),
    (f"{_S}/notice/front",          f"{_SO}/notice_front.png"),
    (f"{_S}/notice/back",           f"{_SO}/notice_back.png"),
    (f"{_S}/neutral_to_attack/front", f"{_SO}/neutral_to_attack_front.png"),
    (f"{_S}/neutral_to_attack/back",  f"{_SO}/neutral_to_attack_back.png"),
    (f"{_S}/idle_attack/front",      f"{_SO}/idle_attack_front.png"),
    (f"{_S}/idle_attack/back",       f"{_SO}/idle_attack_back.png"),
    (f"{_S}/attack_bite/front",     f"{_SO}/attack_bite_front.png"),
    (f"{_S}/attack_bite/back",      f"{_SO}/attack_bite_back.png"),
    (f"{_S}/attack_tail_slam/front", f"{_SO}/attack_tail_slam_front.png"),
    (f"{_S}/attack_tail_slam/back",  f"{_SO}/attack_tail_slam_back.png"),
    (f"{_S}/attack_to_neutral/front", f"{_SO}/attack_to_neutral_front.png"),
    (f"{_S}/attack_to_neutral/back",  f"{_SO}/attack_to_neutral_back.png"),
    (f"{_S}/death/front",           f"{_SO}/death_front.png"),
    (f"{_S}/death/back",            f"{_SO}/death_back.png"),
]

# ─────────────────────────────────────────────────────────────────────────────

_PIL_METHOD_MAP = {
    "nearest":  Image.NEAREST,
    "bilinear": Image.BILINEAR,
    "lanczos":  Image.LANCZOS,
}


def _pack(img: Image.Image) -> np.ndarray:
    """Convert RGBA image to uint32 array for fast per-pixel comparison."""
    rgba = np.array(img.convert("RGBA"), dtype=np.uint8)
    return (rgba[:, :, 0].astype(np.uint32) << 24 |
            rgba[:, :, 1].astype(np.uint32) << 16 |
            rgba[:, :, 2].astype(np.uint32) << 8  |
            rgba[:, :, 3].astype(np.uint32))


def _unpack(out: np.ndarray) -> Image.Image:
    """Convert uint32 array back to RGBA PIL image."""
    result = np.empty((*out.shape, 4), dtype=np.uint8)
    result[:, :, 0] = (out >> 24) & 0xFF
    result[:, :, 1] = (out >> 16) & 0xFF
    result[:, :, 2] = (out >>  8) & 0xFF
    result[:, :, 3] =  out        & 0xFF
    return Image.fromarray(result, "RGBA")


def _scale2x(img: Image.Image) -> Image.Image:
    """
    Scale image exactly 2x using the Scale2x (EPX) algorithm.
    Pixel-art aware: smooths diagonal edges only, no blur.
    """
    p = np.pad(_pack(img), 1, mode="edge")
    h, w = img.height, img.width

    #   A
    # C P B
    #   D
    A = p[0:h,   1:w+1]
    B = p[1:h+1, 2:w+2]
    C = p[1:h+1, 0:w  ]
    D = p[2:h+2, 1:w+1]
    P = p[1:h+1, 1:w+1]

    e0 = np.where((C == A) & (C != D) & (A != B), A, P)  # top-left
    e1 = np.where((A == B) & (A != C) & (B != D), B, P)  # top-right
    e2 = np.where((D == C) & (D != B) & (C != A), C, P)  # bot-left
    e3 = np.where((B == D) & (B != A) & (D != C), D, P)  # bot-right

    out = np.empty((2 * h, 2 * w), dtype=np.uint32)
    out[0::2, 0::2] = e0;  out[0::2, 1::2] = e1
    out[1::2, 0::2] = e2;  out[1::2, 1::2] = e3

    return _unpack(out)


def _scale3x(img: Image.Image) -> Image.Image:
    """
    Scale image exactly 3x using the Scale3x algorithm.
    Pixel-art aware: smooths diagonal edges only, no blur.
    This is the same algorithm LibreSprite calls 'RotSprite' for scaling.
    """
    p = np.pad(_pack(img), 1, mode="edge")
    h, w = img.height, img.width

    # A B C
    # D E F
    # G H I
    A = p[0:h,   0:w  ];  B = p[0:h,   1:w+1];  C = p[0:h,   2:w+2]
    D = p[1:h+1, 0:w  ];  E = p[1:h+1, 1:w+1];  F = p[1:h+1, 2:w+2]
    G = p[2:h+2, 0:w  ];  H = p[2:h+2, 1:w+1];  I = p[2:h+2, 2:w+2]

    c1 = (D == B) & (D != H) & (B != F)
    c2 = (B == F) & (B != D) & (F != H)
    c3 = (D == H) & (D != B) & (H != F)
    c4 = (H == F) & (H != D) & (F != B)

    e0 = np.where(c1,                              D, E)
    e1 = np.where(c1 & (E != C) | c2 & (E != A),  B, E)
    e2 = np.where(c2,                              F, E)
    e3 = np.where(c1 & (E != G) | c3 & (E != A),  D, E)
    e4 = E
    e5 = np.where(c2 & (E != I) | c4 & (E != C),  F, E)
    e6 = np.where(c3,                              D, E)
    e7 = np.where(c3 & (E != I) | c4 & (E != G),  H, E)
    e8 = np.where(c4,                              F, E)

    out = np.empty((3 * h, 3 * w), dtype=np.uint32)
    out[0::3, 0::3] = e0;  out[0::3, 1::3] = e1;  out[0::3, 2::3] = e2
    out[1::3, 0::3] = e3;  out[1::3, 1::3] = e4;  out[1::3, 2::3] = e5
    out[2::3, 0::3] = e6;  out[2::3, 1::3] = e7;  out[2::3, 2::3] = e8

    return _unpack(out)


def _scale_rotsprite(img: Image.Image, scale: int) -> Image.Image:
    """
    Apply RotSprite (Scale2x/Scale3x) for any scale factor.
    Decomposes scale into 3x and 2x steps (e.g. 6=3×2, 4=2×2, 9=3×3).
    Any leftover factor that can't be decomposed uses nearest-neighbor.
    """
    n = scale
    while n % 3 == 0:
        img = _scale3x(img)
        n //= 3
    while n % 2 == 0:
        img = _scale2x(img)
        n //= 2
    if n > 1:
        img = img.resize((img.width * n, img.height * n), Image.NEAREST)
    return img


def _scale_image(img: Image.Image, scale: int, method: str) -> Image.Image:
    if method == "rotsprite":
        return _scale_rotsprite(img, scale)
    resample = _PIL_METHOD_MAP.get(method, Image.NEAREST)
    return img.resize((img.width * scale, img.height * scale), resample)


def _get_frame_folder_variants(norm_dir: str):
    """
    For frame-folder props (bush, grass): return the output variant list if
    norm_dir lives inside a frame-folder prop path, otherwise None.
    Used when numbered PNGs are detected directly in the current directory.
    """
    check = "/" + norm_dir
    for prop_key, rule in SCALABLE_PROPS.items():
        if prop_key in check and isinstance(rule, list):
            return rule
    return None


_SKIP = object()   # sentinel: "skip this file silently"


def _get_file_variants(norm_path: str, stem: str):
    """
    For flat PNG files (sprites, tilemaps).

    Returns:
      list[(out_stem, scale)]  — source file; emit all listed variants
      _SKIP                    — skip silently (numbered frame or derived size)
      None                     — pass-through (tilemap / not in SCALABLE_PROPS)
    """
    check = "/" + norm_path
    for prop_key, rule in SCALABLE_PROPS.items():
        if prop_key in check:
            if isinstance(rule, list):
                # Frame-folder prop (bush, grass) — all source frames are now
                # numbered PNGs handled as a batch in the frame-folder branch.
                # Any remaining .png with a digit stem here is already handled;
                # anything else in this path is unexpected — skip silently.
                return _SKIP
            # File-based prop (tree): look up by stem.
            variants = rule.get(stem)
            return variants if variants is not None else _SKIP  # None → derived size
    return None   # pass-through (tilemaps / unknown)


def export_props() -> None:
    """Export props and tilemaps from art_source to game assets."""
    print(f"Props/Tilemaps — Method: rotsprite\n")
    files_written = skipped = 0

    # ── Props: single source, output routed by frame count ───────────────────
    src_base = os.path.join(ROOT, PROP_SRC)
    if not os.path.isdir(src_base):
        print(f"  SKIP  (folder missing)  {PROP_SRC}/")
    else:
        for dirpath, subdirs, filenames in os.walk(src_base):
            rel_dir  = os.path.relpath(dirpath, src_base)
            norm_dir = rel_dir.replace(os.sep, "/") if rel_dir != "." else ""

            # ── Frame-folder sources: numbered PNGs directly in this dir ──────
            # All props (idle stills and animations) go to assets/gfx/props/.
            frame_files = sorted(
                [f for f in filenames
                 if f.endswith(".png") and os.path.splitext(f)[0].isdigit()],
                key=lambda f: int(os.path.splitext(f)[0])
            )
            if frame_files:
                variants = _get_frame_folder_variants(norm_dir)
                if variants is not None:
                    images = [Image.open(os.path.join(dirpath, ff)).convert("RGBA")
                              for ff in frame_files]
                    fw, fh  = images[0].size
                    strip   = Image.new("RGBA", (fw * len(images), fh), (0, 0, 0, 0))
                    for i, img in enumerate(images):
                        strip.paste(img, (i * fw, 0))
                    dst_dir  = os.path.join(ROOT, DST_PROPS, rel_dir)
                    os.makedirs(dst_dir, exist_ok=True)
                    for out_stem, scale in variants:
                        out_img = _scale_rotsprite(strip, scale) if scale > 1 else strip.copy()
                        dst     = os.path.join(dst_dir, out_stem + ".png")
                        out_img.save(dst)
                        w, h    = out_img.size
                        tag     = f"{DST_PROPS}/{norm_dir}/{out_stem}.png".replace("//", "/")
                        n_tag   = f"{len(frame_files)} frame{'s' if len(frame_files) > 1 else ''}"
                        print(f"  OK    {n_tag}  {fw}x{fh}px → {w}x{h}px  {scale}x  |  {tag}")
                        files_written += 1
                    continue   # entire dir handled — skip per-file loop below

            # ── Flat PNG sources: tree sprites (named stems) ──────────────────
            for fname in sorted(filenames):
                if not fname.lower().endswith(".png"):
                    continue

                src       = os.path.join(dirpath, fname)
                rel       = os.path.relpath(src, src_base)
                norm      = rel.replace(os.sep, "/")
                stem      = os.path.splitext(fname)[0]
                rel_dir_f = os.path.dirname(rel)

                variants = _get_file_variants(norm, stem)

                if variants is _SKIP:
                    skipped += 1
                    continue
                if variants is None:
                    skipped += 1   # unknown file in props/ — ignore
                    continue

                # File-based scalable prop (tree): routes to assets/gfx/props/.
                img     = Image.open(src).convert("RGBA")
                dst_dir = os.path.join(ROOT, DST_PROPS, rel_dir_f)
                os.makedirs(dst_dir, exist_ok=True)
                for out_stem, scale in variants:
                    out_img = _scale_rotsprite(img, scale) if scale > 1 else img.copy()
                    dst     = os.path.join(dst_dir, out_stem + ".png")
                    out_img.save(dst)
                    w, h    = out_img.size
                    print(f"  OK    {w}x{h}px  {scale}x  |  {DST_PROPS}/{rel_dir_f}/{out_stem}.png")
                    files_written += 1

    # ── Tilemaps: pass-through ────────────────────────────────────────────────
    for src_base_rel, dst_base_rel in TILEMAP_DIRS:
        src_base = os.path.join(ROOT, src_base_rel)
        dst_base = os.path.join(ROOT, dst_base_rel)
        if not os.path.isdir(src_base):
            print(f"  SKIP  (folder missing)  {src_base_rel}/")
            continue
        for dirpath, subdirs, filenames in os.walk(src_base):
            rel_dir_f = os.path.relpath(dirpath, src_base)
            for fname in sorted(filenames):
                if not fname.lower().endswith(".png"):
                    continue
                src = os.path.join(dirpath, fname)
                rel = os.path.relpath(src, src_base).replace(os.sep, "/")
                img = Image.open(src).convert("RGBA")
                if PROP_SCALE > 1:
                    img = _scale_rotsprite(img, PROP_SCALE)
                dst_dir = os.path.join(dst_base, rel_dir_f)
                os.makedirs(dst_dir, exist_ok=True)
                dst = os.path.join(dst_dir, fname)
                img.save(dst)
                w, h = img.size
                print(f"  OK    {w}x{h}px      |  {dst_base_rel}/{rel}")
                files_written += 1

    print(f"\nDone.  {files_written} files written,  {skipped} skipped.")


def export_all() -> None:
    print(f"Entities — Scale: {SCALE}x   Method: {METHOD}\n")

    ok = skipped = 0

    for entry in EXPORTS:
        src_rel, dst_rel = entry[0], entry[1]
        flip_h : bool = entry[2] if len(entry) > 2 else False

        src = os.path.join(ROOT, src_rel)
        dst = os.path.join(ROOT, dst_rel)

        if not os.path.isdir(src):
            print(f"  SKIP  (folder missing)  {src_rel}")
            skipped += 1
            continue

        # Collect numbered frames only
        frame_files = sorted(
            [f for f in os.listdir(src)
             if f.endswith(".png") and os.path.splitext(f)[0].isdigit()],
            key=lambda f: int(os.path.splitext(f)[0])
        )

        if not frame_files:
            print(f"  SKIP  (no frames)       {src_rel}")
            skipped += 1
            continue

        images = [Image.open(os.path.join(src, f)).convert("RGBA")
                  for f in frame_files]
        if flip_h:
            images = [img.transpose(Image.FLIP_LEFT_RIGHT) for img in images]
        fw, fh = images[0].size

        # Assemble horizontal strip at source size
        strip = Image.new("RGBA", (fw * len(images), fh), (0, 0, 0, 0))
        for i, img in enumerate(images):
            strip.paste(img, (i * fw, 0))

        # Scale up
        scaled = _scale_image(strip, SCALE, METHOD)

        # Save game asset
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        scaled.save(dst)

        flip_tag : str = "  [flipped]" if flip_h else ""
        print(f"  OK    {len(images)} frames  "
              f"{fw}x{fh}px → {fw * SCALE}x{fh * SCALE}px  |  {dst_rel}{flip_tag}")
        ok += 1

    print(f"\nDone.  {ok} exported,  {skipped} skipped.")


if __name__ == "__main__":
    export_all()
    print()
    export_props()
