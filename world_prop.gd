class_name WorldProp
extends StaticBody2D

const TILE_SIZE := 32


# ── Other ──────────────────────────────────────────────────────────────────────

enum Size { SMALL, MEDIUM, LARGE }

const SIZE_STR := ["small", "medium", "large"]


# ── References ─────────────────────────────────────────────────────────────────

var sprite            : AnimatedSprite2D   # init _ready().
var collision         : CollisionShape2D   # init _ready(), null if has_collision=false.
var size              : Size
var sprite_name       : String
var has_collision     : bool  = true
var central_rotation  : bool  = true
var weight_central    : Vector2   # tile-footprint centre, used for collision and rotation pivot.
var empty_bottom      : int    = 0     # transparent rows at canvas bottom — set in _load_animations().
var z_radius          : float  = 0.0  # radius of the z-sort circle = |weight_central.y| - empty_bottom.
var variant_count     : int   = 1      # >1 enables random variant suffix in sprite path.
var _variant_idx      : int   = 0      # chosen in _load_animations().


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	weight_central = Vector2((size + 1) * TILE_SIZE / 2.0, -(size + 1) * TILE_SIZE / 2.0)
	if has_collision:
		collision = CollisionShape2D.new()
		collision.position = weight_central
		var shape := CircleShape2D.new()
		match size:
			Size.SMALL:  shape.radius = 11.0
			Size.MEDIUM: shape.radius = 22.0
			_:           shape.radius = 33.0   # LARGE
		collision.shape = shape
		add_child(collision)

	sprite               = AnimatedSprite2D.new()
	sprite.z_as_relative = false
	add_child(sprite)

	_load_animations()
	sprite.play("idle")


# =============================================================================
# ANIMATIONS
# =============================================================================

# Called: _ready().
func _load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 1.0)

	_variant_idx = randi_range(0, variant_count - 1)
	var path : String
	if variant_count > 1:
		path = "res://assets/sprites/%s/%s_%s_%d.png" % [sprite_name, SIZE_STR[size], sprite_name, _variant_idx + 1]
	else:
		path = "res://assets/sprites/%s/%s_%s.png" % [sprite_name, SIZE_STR[size], sprite_name]
	var tex  : Texture2D = load(path)
	print(path)

	# Visual centre of the texture relative to prop.position (Tiled bottom-left anchor).
	var cx := tex.get_width()  / 2.0
	var cy := -tex.get_height() / 2.0

	# Rotation pivot = weight_central (tile-footprint centre, set in _ready()).
	# sprite.offset shifts the texture so it still renders at the correct visual position.
	sprite.position = weight_central
	sprite.offset   = Vector2(cx - weight_central.x, cy - weight_central.y)

	# Count consecutive transparent rows from the canvas bottom.
	# Used by game.gd for angle-aware z-sort (see z-sort comment there).
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

	var atlas  := AtlasTexture.new()
	atlas.atlas  = tex
	atlas.region = Rect2(0, 0, tex.get_width(), tex.get_height())
	frames.add_frame("idle", atlas)
