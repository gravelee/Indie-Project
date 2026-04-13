extends StaticBody2D

# =============================================================================
# BUSH.GD
#
# Responsibilities:
#   - Create its own collision shape and visual sprite in code
#   - Play idle animation normally, death animation when hit
#
# What this script does NOT do:
#   - Set z_index or rotation  (game.gd handles all camera-dependent rendering)
# =============================================================================


# ── State ──────────────────────────────────────────────────────────────────────

var alive : bool = true


# ── References (created in _ready) ────────────────────────────────────────────

var sprite    : AnimatedSprite2D
var collision : CollisionShape2D


# =============================================================================
# SETUP  -  runs once when this node enters the scene tree
# =============================================================================

# INIT
func _ready() -> void:

	# Collision circle
	collision       = CollisionShape2D.new()
	var shape       := CircleShape2D.new()
	shape.radius    = 33.0
	collision.shape = shape
	add_child(collision)

	# Visual sprite
	# z_as_relative = false so z_index is absolute, compared directly against
	# the player sprite on the same scale (required for z-sort to work).
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

	# ── Idle: one static frame ─────────────────────────────────────────────────
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 1.0)

	var idle_tex   : Texture2D = load("res://assets/sprites/bush/bush.png")
	var idle_atlas := AtlasTexture.new()
	idle_atlas.atlas  = idle_tex
	idle_atlas.region = Rect2(0, 0, idle_tex.get_width(), idle_tex.get_height())
	frames.add_frame("idle", idle_atlas)

	# ── Death: 12-frame animation ──────────────────────────────────────────────
	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", 8.0)

	var death_tex : Texture2D = load("res://assets/spritesheets/bush/death.png")
	var frame_w   := death_tex.get_width() / 12

	for i in range(12):
		var atlas   := AtlasTexture.new()
		atlas.atlas  = death_tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, death_tex.get_height())
		frames.add_frame("death", atlas)
	
	# When the death animation is complete call _on_death_finished().
	sprite.animation_finished.connect(_on_death_finished)


# Called: take_hit().
func _on_death_finished() -> void:

	queue_free()


# =============================================================================
# PUBLIC API
# =============================================================================

# Called: None.
func take_hit() -> void:

	alive = false
	collision.set_deferred("disabled", true)
	sprite.play("death")
