class_name WorldProp
extends StaticBody2D

const TILE_SIZE := 32

# Cache for runtime-padded textures — shared across all WorldProp instances.
static var _tex_cache : Dictionary = {}


# ── References ─────────────────────────────────────────────────────────────────

var sprite            : AnimatedSprite2D   # init _ready().
var collision         : CollisionShape2D   # init _ready(), null if has_collision=false.
var cols              : int  = 1           # tile footprint width  (x axis).
var rows              : int  = 1           # tile footprint height (y axis).
var sprite_type       : String
var sprite_name       : String
var states            : Array = ["idle_alive"]
var has_collision     : bool
var weight_central    : Vector2        # tile-footprint centre, used for collision and rotation center.
var empty_bottom      : int    = 0     # transparent rows at canvas bottom — set in set_prop_attr().
var z_radius          : float  = 0.0   # radius of the z-sort circle = |weight_central.y| - empty_bottom.
var height_ext        : int   = 0      # 0=standard, 1=one extension taller, 2=two, … — int scales to any height.
var variant_count     : int   = 1      # >1 enables random variant suffix in sprite path.
var _variant_idx      : int   = 0      # set in _ready().
# Thin-prop canvas padding.
# -1  = disabled: PNG is already sized correctly (bushes, …); pixel scan used for empty_bottom.
# ≥ 0 = enabled:  PNG is content-fitted (south at last row); code pads +_canvas_add_rows at runtime.
#       Value = row inside the NEW canvas where the original content is blitted (blit_y).
#       empty_bottom = _canvas_add_rows − blit_y  (no pixel scan needed).
#       Set by TerrainProp / map._spawn_prop() before super._ready().
var _idle_blit_y     : int = -1
# Rows added to the canvas bottom when padding (TILE_SIZE/2 for 1-row props like grass;
# rows * TILE_SIZE/2 for multi-row props like trees).  Ignored when _idle_blit_y < 0.
var _canvas_add_rows : int = TILE_SIZE / 2


# =============================================================================
# SETUP
# =============================================================================

# Called: DamageableProp._ready() (via super); Godot engine directly for tree instances.
func _ready() -> void:	# states never empty.

	# Footprint centre: half the tile width right, half the tile height up from the bottom-left anchor.
	weight_central = Vector2(cols * TILE_SIZE / 2.0, -(rows * TILE_SIZE / 2.0))

	if has_collision:
		collision = CollisionShape2D.new()
		collision.position = weight_central
		var shape := CircleShape2D.new()
		# Radius scales with the narrower footprint dimension — 11 px per tile (same as before for squares).
		shape.radius = 11.0 * float(min(cols, rows))
		collision.shape = shape
		add_child(collision)

	sprite = AnimatedSprite2D.new()
	sprite.z_as_relative = false
	add_child(sprite)

	# Variant setup — runs here so _frames_key() is valid before _load_animations() is entered.
	if variant_count >= 1:
		_variant_idx = randi_range(0, variant_count - 1)
	else:
		_variant_idx = -variant_count - 1
		variant_count = 2

	# Calls: DamageableProp._load_animations() via virtual dispatch; itself for trees.
	_load_animations()
	sprite.play(states[0]) # idle_alive is the first state to play.


# =============================================================================
# ANIMATIONS
# =============================================================================

# Called: DamageableProp._load_animations() (via super); directly for trees.
func _load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	for state in states:

		frames.add_animation(state)
		frames.set_animation_loop(state, true)
		frames.set_animation_speed(state, 1.0)
		var size_str := "%dx%d" % [cols, rows]
		var h_part   := ("_h%d" % height_ext) if height_ext > 0 else ""
		var v_part   := ("/%d" % [_variant_idx + 1]) if variant_count > 1 else ""
		var path     := "res://assets/sprites/%s/%s/%s%s/%s%s.png" % [sprite_type, sprite_name, state, v_part, size_str, h_part]
		var tex      : Texture2D = _load_tex(path, _idle_blit_y)
		var atlas    := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(0, 0, tex.get_width(), tex.get_height())
		frames.add_frame(state, atlas)

		# Position, offset, and z-sort are derived from the primary (alive) sprite only.
		if state == states[0]:
			set_prop_attr(tex)


# Called: damageable_prop._load_animations().
# Returns the idle_alive asset path — unique per type+variant, matches _tex_cache convention.
func _frames_key() -> String:
	var size_str := "%dx%d" % [cols, rows]
	var h_part   := ("_h%d" % height_ext) if height_ext > 0 else ""
	var v_part   := ("/%d" % [_variant_idx + 1]) if variant_count > 1 else ""
	return "res://assets/sprites/%s/%s/%s%s/%s%s.png" % [sprite_type, sprite_name, states[0], v_part, size_str, h_part]


# Called: WorldProp._load_animations(), DamageableProp._load_animations().
func _load_tex(path: String, blit_y: int) -> Texture2D:

	# Loads a texture, optionally padding the canvas bottom with transparent rows.
	# blit_y < 0  → return raw asset (no padding).
	# blit_y ≥ 0  → return a padded version: height += _canvas_add_rows, original content starts at row blit_y.
	# Results are cached by (path, blit_y, _canvas_add_rows) so each unique combination is processed only once.
	if blit_y < 0:
		return load(path) as Texture2D

	var key := path + ":" + str(blit_y) + ":" + str(_canvas_add_rows)
	if _tex_cache.has(key):
		return _tex_cache[key] as Texture2D

	var src_tex := load(path) as Texture2D
	var src_img := src_tex.get_image()
	src_img.convert(Image.FORMAT_RGBA8)
	var new_w   := src_img.get_width()
	var new_h   := src_img.get_height() + _canvas_add_rows
	var new_img := Image.create(new_w, new_h, false, Image.FORMAT_RGBA8)
	new_img.blit_rect(src_img, Rect2i(0, 0, new_w, src_img.get_height()), Vector2i(0, blit_y))
	var tex     := ImageTexture.create_from_image(new_img)
	_tex_cache[key] = tex
	return tex


# Called: WorldProp._load_animations(), DamageableProp._load_animations() (cache hit path).
func set_prop_attr(tex : Texture2D) -> void:

	# Visual centre of the texture relative to prop.position (Tiled bottom-left anchor).
	var cx := tex.get_width()  / 2.0
	var cy := -tex.get_height() / 2.0

	# sprite.offset shifts the texture so it still renders at the correct visual position.
	sprite.position = weight_central
	sprite.offset   = Vector2(cx - weight_central.x, cy - weight_central.y)

	if _idle_blit_y >= 0:
		# For padded textures: empty_bottom is exactly the rows below the blitted content.
		# new_h = orig_h + _canvas_add_rows.  Content ends at row (blit_y + orig_h − 1).
		# empty_bottom = new_h − (blit_y + orig_h) = _canvas_add_rows − blit_y.
		empty_bottom = _canvas_add_rows - _idle_blit_y
	else:
		# Count consecutive transparent rows from the canvas bottom (manually-sized sprites).
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for row in range(tex.get_height() - 1, -1, -1):
			var row_empty := true
			for col in range(tex.get_width()):
				if img.get_pixel(col, row).a > 0.0:
					row_empty = false
					break
			if row_empty: empty_bottom += 1
			else:         break

	# Radius of the z-sort circle: distance from weight_central to the bottom visible pixel.
	# weight_central.y is negative (above prop.position), so -weight_central.y gives its magnitude.
	z_radius = -weight_central.y - float(empty_bottom)
