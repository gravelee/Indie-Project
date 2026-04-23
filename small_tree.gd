extends StaticBody2D


# ── File path ──────────────────────────────────────────────────────────────────

const PATH_SPRITE := "res://assets/sprites/small_tree/small_tree.png"


# ── References ─────────────────────────────────────────────────────────────────

var sprite    : AnimatedSprite2D   # init _ready().
var collision : CollisionShape2D   # init _ready().


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	# Collision: circle r=33 (same as bush), centered on world_pos (the Tiled tile).
	collision       = CollisionShape2D.new()
	var shape       := CircleShape2D.new()
	shape.radius    = 33.0
	collision.shape = shape
	add_child(collision)

	# Sprite: 32x64 scaled x3 = 96x192 visual.
	# Pivot at (0, 0) = world_pos so the trunk is at the Tiled tile.
	# offset (0, -16) shifts the texture -48px in parent space so the tree
	# extends upward from world_pos rather than being centered on it.
	sprite               = AnimatedSprite2D.new()
	sprite.z_as_relative = false
	sprite.offset        = Vector2(0.0, -16.0)
	sprite.scale         = Vector2(3.0, 3.0)
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

	var tex    : Texture2D = load(PATH_SPRITE)
	var atlas  := AtlasTexture.new()
	atlas.atlas  = tex
	atlas.region = Rect2(0, 0, tex.get_width(), tex.get_height())
	frames.add_frame("idle", atlas)
