class_name WorldProp
extends StaticBody3D

# =============================================================================
# WORLD PROP — base visual prop with optional collision.
# Configured before add_child() so _ready() fires with all vars set.
#
# Asset path formula (matches old project):
#   res://assets/sprites/{sprite_type}/{sprite_name}/{state}[/{variant}]/{cols}x{rows}[_h{ext}].png
#
# Canvas padding (trees only):
#   set _idle_blit_y = rows * TILE_SIZE / 4
#   set _canvas_add_rows = rows * TILE_SIZE / 2
#   before add_child(). Default -1 = no padding (bushes, etc.).
# =============================================================================

const TILE_SIZE        : int   = 32
const PIXEL_SIZE       : float = 1.0 / 32.0
# Godot collision layer 3 (bitmask 4) — prop reaction detection.
# Entity Area3D uses mask=PROP_REACT_LAYER to find damageable props without
# polling per prop per frame.
const PROP_REACT_LAYER : int   = 4

# ── Static caches (shared across all instances) ────────────────────────────────
static var _tex_cache    : Dictionary = {}   # "path:blit_y:rows" → Texture2D  (padded)
static var _frames_cache : Dictionary = {}   # frames_key → SpriteFrames

# ── Config (set before add_child) ─────────────────────────────────────────────
var cols          : int    = 1
var rows          : int    = 1
var sprite_type   : String = ""
var sprite_name   : String = ""
var states        : Array  = ["idle_alive"]
var has_collision : bool   = false
var height_ext    : int    = 0
var variant_count : int    = 1   # 1 = no variants; >1 = random pick; <0 = fixed (-1 = variant 1, etc.)

# Canvas padding — set by map_loader for trees; override in TerrainProp._ready() for grass.
var _idle_blit_y     : int = -1   # -1 = raw PNG, ≥0 = pad canvas by _canvas_add_rows
var _canvas_add_rows : int = TILE_SIZE / 2

# ── Runtime ────────────────────────────────────────────────────────────────────
var sprite       : AnimatedSprite3D
var _variant_idx : int = 0


# =============================================================================
# SETUP
# =============================================================================

func _ready() -> void:
	if variant_count > 1:
		_variant_idx = randi_range(0, variant_count - 1)
	elif variant_count < 0:
		_variant_idx = -variant_count - 1
		variant_count = 2

	if has_collision:
		var col    := CollisionShape3D.new()
		var shp    := CylinderShape3D.new()
		var base_r : float = 11.0 * float(mini(cols, rows)) * PIXEL_SIZE
		shp.radius = base_r

		# Trees: extend collision to full visual height so the player can't enter the
		# canopy. Minimum 2.0 ensures even a 1×1 tree blocks the 1.5-unit jump peak.
		# Note: map_loader routes non-destructible tree collision to _tree_col_body
		# (with pixel-measured height), so this branch is for any tree spawned
		# standalone. Bushes: 1-unit cylinder is sufficient.
		var coll_h : float = 1.0
		if sprite_type == "tree":
			coll_h = maxf(float(rows) + float(height_ext), 2.0)

		shp.height     = coll_h
		col.position.y = coll_h * 0.5
		col.shape      = shp
		add_child(col)

	sprite = AnimatedSprite3D.new()
	sprite.billboard      = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size     = PIXEL_SIZE
	sprite.alpha_cut               = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter          = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.sorting_use_aabb_center = false
	add_child(sprite)

	_load_animations()
	# Set idle frame without calling play() — play() registers for INTERNAL_PROCESS
	# every frame, which with 1000+ props destroys performance. Direct assignment
	# renders the correct frame with zero per-frame cost. Only reaction/death
	# animations need play() since they actually advance frames.
	sprite.animation = states[0]
	sprite.frame     = 0


# =============================================================================
# ANIMATIONS
# =============================================================================

func _load_animations() -> void:
	var key    : String       = _frames_key()
	var cached : SpriteFrames = _frames_cache.get(key, null) as SpriteFrames
	if cached != null:
		sprite.sprite_frames = cached
		_apply_sprite_position(_load_prop_tex(states[0]))
		return

	var frames := SpriteFrames.new()
	for state : String in states:
		var tex : Texture2D = _load_prop_tex(state)
		if tex == null:
			continue
		frames.add_animation(state)
		frames.set_animation_loop(state, true)
		frames.set_animation_speed(state, 8.0)
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(0, 0, tex.get_width(), tex.get_height())
		frames.add_frame(state, atlas)
		if state == states[0]:
			_apply_sprite_position(tex)

	sprite.sprite_frames = frames
	_frames_cache[key]   = frames


# =============================================================================
# TEXTURE HELPERS
# =============================================================================

func _load_prop_tex(state: String) -> Texture2D:
	var size_str : String = "%dx%d" % [cols, rows]
	var h_part   : String = ("_h%d" % height_ext) if height_ext > 0 else ""
	var v_part   : String = ("/%d" % (_variant_idx + 1)) if variant_count > 1 else ""
	var path     : String = "res://assets/sprites/%s/%s/%s%s/%s%s.png" % [
		sprite_type, sprite_name, state, v_part, size_str, h_part]
	if not ResourceLoader.exists(path):
		return null
	if _idle_blit_y < 0:
		return load(path) as Texture2D
	# Canvas padding for trees — cache by path+blit params
	var cache_key : String = path + ":" + str(_idle_blit_y) + ":" + str(_canvas_add_rows)
	var cached    : Texture2D = _tex_cache.get(cache_key, null) as Texture2D
	if cached != null:
		return cached
	var src_tex  : Texture2D = load(path) as Texture2D
	var src_img  : Image = src_tex.get_image()
	src_img.convert(Image.FORMAT_RGBA8)
	var new_w    : int = src_img.get_width()
	var new_h    : int = src_img.get_height() + _canvas_add_rows
	var new_img  : Image = Image.create(new_w, new_h, false, Image.FORMAT_RGBA8)
	new_img.blit_rect(src_img, Rect2i(0, 0, new_w, src_img.get_height()), Vector2i(0, _idle_blit_y))
	var tex      : ImageTexture = ImageTexture.create_from_image(new_img)
	_tex_cache[cache_key] = tex
	return tex


func _frames_key() -> String:
	var size_str : String = "%dx%d" % [cols, rows]
	var h_part   : String = ("_h%d" % height_ext) if height_ext > 0 else ""
	var v_part   : String = ("/%d" % (_variant_idx + 1)) if variant_count > 1 else ""
	return "res://assets/sprites/%s/%s/%s%s/%s%s.png" % [
		sprite_type, sprite_name, states[0], v_part, size_str, h_part]


func _apply_sprite_position(tex: Texture2D) -> void:
	if tex == null:
		return
	var empty_bottom : int
	if _idle_blit_y >= 0:
		# Canvas-padded: empty rows are exactly the rows below the blitted content.
		empty_bottom = _canvas_add_rows - _idle_blit_y
	else:
		var img : Image = tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		empty_bottom = tex.get_height() - img.get_used_rect().end.y
	# Use pixel offset instead of position.y so the sprite node stays at y = 0.
	# With a pitched camera, position.y contributes to depth-sort, causing tall
	# sprites (player) to sort in front of short sprites (small bushes) prematurely.
	# Keeping all sprites at y = 0 makes Z-sort purely Z-based — correct for top-down.
	sprite.offset.y = float(tex.get_height()) * 0.5 - float(empty_bottom)
