extends StaticBody2D


# ── File paths ─────────────────────────────────────────────────────────────────

const PATH_IDLE  := "res://assets/sprites/bush/"
const BUSHES	 : Array = ["bush_1.png","bush_2.png","bush_3.png","bush_4.png"]
const BUSHES_DEATH: Array = ["death_1.png","death_2.png","death_3.png","death_4.png"]
const PATH_DEATH := "res://assets/spritesheets/bush/"


# ── State ──────────────────────────────────────────────────────────────────────

var alive : bool = true


# ── References (created in _ready) ────────────────────────────────────────────

var sprite    : AnimatedSprite2D   # init _ready().
var collision : CollisionShape2D   # init _ready().


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	# Collision circle
	collision       = CollisionShape2D.new()
	var shape       := CircleShape2D.new()
	shape.radius    = 33.0
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

	# Idle srite setup.
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 1.0)
	
	var index = randi_range(0, BUSHES.size() - 1)
	
	var idle_tex   : Texture2D = load(PATH_IDLE + BUSHES[index])
	var idle_atlas := AtlasTexture.new()
	idle_atlas.atlas  = idle_tex
	idle_atlas.region = Rect2(0, 0, idle_tex.get_width(), idle_tex.get_height())
	frames.add_frame("idle", idle_atlas)

	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", 8.0)

	# Death animation setup.
	var death_tex   : Texture2D = load(PATH_DEATH + BUSHES_DEATH[index])
	var frame_w     := death_tex.get_height()   # frames are square
	var frame_count := death_tex.get_width() / frame_w

	for i in range(frame_count):
		var atlas   := AtlasTexture.new()
		atlas.atlas  = death_tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, death_tex.get_height())
		frames.add_frame("death", atlas)
	
	# When the death animation is complete call _on_death_finished().
	sprite.animation_finished.connect(_on_death_finished)


# Called: sprite.animation_finished signal.
func _on_death_finished() -> void:

	queue_free()


# =============================================================================
# PUBLIC API
# =============================================================================

# Called: game._on_player_attacked().
func take_hit() -> void:

	alive = false
	collision.set_deferred("disabled", true)
	sprite.play("death")
