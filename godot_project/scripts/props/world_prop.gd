class_name WorldProp
extends StaticBody2D

const TILE_SIZE := 32


# ── References ─────────────────────────────────────────────────────────────────

var sprite            : AnimatedSprite2D   # init _ready().
var collision         : CollisionShape2D   # init _ready(), null if has_collision=false.
var cols              : int  = 1           # tile footprint width  (x axis).
var rows              : int  = 1           # tile footprint height (y axis).
var sprite_type       : String
var sprite_name       : String
var states            : Array = ["idle_alive"]
var has_collision     : bool  = true
var central_rotation  : bool  = true
var weight_central    : Vector2        # tile-footprint centre, used for collision and rotation pivot.
var empty_bottom      : int    = 0     # transparent rows at canvas bottom — set in _load_animations().
var z_radius          : float  = 0.0   # radius of the z-sort circle = |weight_central.y| - empty_bottom.
var height_ext        : int   = 0      # 0=standard, 1=one extension taller, 2=two, … — int scales to any height.
var variant_count     : int   = 1      # >1 enables random variant suffix in sprite path.
var _variant_idx      : int   = 0      # chosen in _load_animations().


# =============================================================================
# SETUP
# =============================================================================

# Called: destructable._ready(), reactive_prop._ready().
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
	
	# Calls: destructable._load_animations(), reactive_prop._load_animations().
	_load_animations()
	sprite.play(states[0]) # idle_alive is the first state to play.


# =============================================================================
# ANIMATIONS
# =============================================================================

# Called: destructable._load_animations(), reactive_prop._load_animations().
func _load_animations() -> void:

	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames
	_variant_idx = randi_range(0, variant_count - 1)
	
	for state in states:
		
		frames.add_animation(state)
		frames.set_animation_loop(state, true)
		frames.set_animation_speed(state, 1.0)
		var size_str := "%dx%d" % [cols, rows]
		var h_part   := ("_h%d" % height_ext) if height_ext > 0 else ""
		var v_part   := ("_v%d" % [_variant_idx + 1]) if variant_count > 1 else ""
		var path     := "res://assets/sprites/%s/%s/%s/%s%s%s.png" % [sprite_type, sprite_name, state, size_str, h_part, v_part]
		print(path)
		var tex  : Texture2D = load(path)
		var atlas  := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(0, 0, tex.get_width(), tex.get_height())
		frames.add_frame(state, atlas)

		# Position, offset, and z-sort are derived from the primary (alive) sprite only.     
		if state == states[0]:  
			set_prop_attr(tex)


# Called: _load_animations().
func set_prop_attr(tex : Texture2D) -> void:
	
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
