#!/usr/bin/env python3
"""
Sprite export tool for Echoes of the Void.

Edit EXPORTS, SCALE, and METHOD at the top, then run:
  python3 tools/export_sprite.py

For each entry the script will:
  1. Read numbered frames (0.png, 1.png ... N.png) from the source folder
  2. Assemble them into a horizontal spritesheet and save it back to the
     source folder as 0-sheet.png  (overwrites any existing sheet)
  3. Scale up by SCALE using METHOD and save to the game assets path
"""

from PIL import Image
import os
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── Settings ──────────────────────────────────────────────────────────────────

SCALE  = 3           # upscale factor  (3 → 32 px becomes 96 px per frame)

METHOD = "rotsprite"  # "nearest"   — nearest-neighbor (sharp, no edge smoothing)
                      # "rotsprite" — pixel-art aware, same as LibreSprite RotSprite
                      #               decomposes SCALE into 2x/3x steps (e.g. 6=2×3,
                      #               4=2×2, 9=3×3). Any leftover factor uses nearest.
                      # "bilinear"  — smooth blur (not recommended for pixel art)
                      # "lanczos"   — high quality but also blurs pixel art

# ── Export list ───────────────────────────────────────────────────────────────
# Each entry: (source_frames_folder, game_asset_output_path)
# Both paths are relative to the project root.
# Add or comment out entries as needed.

EXPORTS = [
    (
        "art_source/creatures/rat/frames/wander/front",
        "echoes_of_the_void/assets/spritesheets/creatures/rat/wander_front.png",
    ),
    (
        "art_source/creatures/rat/frames/wander/back",
        "echoes_of_the_void/assets/spritesheets/creatures/rat/wander_back.png",
    ),
    (
        "art_source/creatures/rat/frames/idle_neutral/front",
        "echoes_of_the_void/assets/spritesheets/creatures/rat/idle_neutral_front.png",
    ),
    (
        "art_source/creatures/rat/frames/idle_neutral/back",
        "echoes_of_the_void/assets/spritesheets/creatures/rat/idle_neutral_back.png",
    ),
    # Uncomment when ready:
    # (
    #     "art_source/creatures/snake/frames/move/front",
    #     "echoes_of_the_void/assets/spritesheets/creatures/snake/move_front.png",
    # ),
    # (
    #     "art_source/creatures/snake/frames/move/back",
    #     "echoes_of_the_void/assets/spritesheets/creatures/snake/move_back.png",
    # ),
    # (
    #     "art_source/creatures/snake/frames/idle_neutral/front",
    #     "echoes_of_the_void/assets/spritesheets/creatures/snake/idle_neutral_front.png",
    # ),
    # (
    #     "art_source/creatures/snake/frames/idle_neutral/back",
    #     "echoes_of_the_void/assets/spritesheets/creatures/snake/idle_neutral_back.png",
    # ),
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


def export_all() -> None:
    print(f"Scale: {SCALE}x   Method: {METHOD}\n")

    ok = skipped = 0

    for src_rel, dst_rel in EXPORTS:
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
        fw, fh = images[0].size

        # Assemble horizontal strip at source size
        strip = Image.new("RGBA", (fw * len(images), fh), (0, 0, 0, 0))
        for i, img in enumerate(images):
            strip.paste(img, (i * fw, 0))

        # Save source-size sheet back into the frames folder
        strip.save(os.path.join(src, "0-sheet.png"))

        # Scale up
        scaled = _scale_image(strip, SCALE, METHOD)

        # Save game asset
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        scaled.save(dst)

        print(f"  OK    {len(images)} frames  "
              f"{fw}x{fh}px → {fw * SCALE}x{fh * SCALE}px  |  {dst_rel}")
        ok += 1

    print(f"\nDone.  {ok} exported,  {skipped} skipped.")


if __name__ == "__main__":
    export_all()
