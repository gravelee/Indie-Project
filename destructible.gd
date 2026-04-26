class_name Destructible
extends WorldProp

signal died

# ── State ──────────────────────────────────────────────────────────────────────

var alive : bool = true


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	super._ready()            # WorldProp._ready() → collision + sprite + _load_animations() + play("idle").


# =============================================================================
# ANIMATIONS
# =============================================================================

# Override: called by WorldProp._ready() via virtual dispatch.
func _load_animations() -> void:

	# Idle — handled by WorldProp; also picks _variant_idx.
	super._load_animations()

	# Death — horizontal spritesheet matching the chosen idle variant.
	var frames := sprite.sprite_frames
	frames.add_animation("death")
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", 8.0)
	var death_path  : String
	if variant_count > 1:
		death_path = "res://assets/spritesheets/%s/%s_death_%d.png" % [sprite_name, SIZE_STR[size], _variant_idx + 1]
	else:
		death_path = "res://assets/spritesheets/%s/%s_death.png" % [sprite_name, SIZE_STR[size]]
	var death_tex   : Texture2D = load(death_path)
	var frame_w     := death_tex.get_height()   # frames are square
	var frame_count := death_tex.get_width() / frame_w
	for i in range(frame_count):
		var atlas    := AtlasTexture.new()
		atlas.atlas   = death_tex
		atlas.region  = Rect2(i * frame_w, 0, frame_w, death_tex.get_height())
		frames.add_frame("death", atlas)
	sprite.animation_finished.connect(_on_death_finished)


# Called: sprite.animation_finished signal.
func _on_death_finished() -> void:

	queue_free()


# =============================================================================
# PUBLIC API
# =============================================================================

# Called: game._on_player_attack().
func take_hit() -> void:

	alive = false
	died.emit()
	collision.set_deferred("disabled", true)
	sprite.play("death")
