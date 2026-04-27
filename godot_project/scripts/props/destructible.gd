class_name Destructible
extends WorldProp

signal died
#signal bump


const ANIMS := ["death","bump"]

# ── State ──────────────────────────────────────────────────────────────────────

var alive : bool = true


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	super._ready()            # WorldProp._ready() → collision + sprite + _load_animations() + play("idle").
	
	# Setup the bump area.
	var area := Area2D.new()
	var col_area := CollisionShape2D.new()
	area.position = Vector2.ZERO
	col_area.position = weight_central
	var shape := CircleShape2D.new()
	shape.radius = 11.0 * float(min(cols, rows)) + 0.1
	col_area.shape = shape
	area.add_child(col_area)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


# =============================================================================
# ANIMATIONS
# =============================================================================

# Override: called by WorldProp._ready() via virtual dispatch.
func _load_animations() -> void:

	# Idle — handled by WorldProp; also picks _variant_idx.
	super._load_animations()

	for anim in ANIMS:
		var frames := sprite.sprite_frames
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, 8.0)
		# Size prefix mirrors world_prop.gd: "{cols}x{rows}" — e.g. "1x1_death_3.png".
		var size_str    := "%dx%d" % [cols, rows]
		var v_part      := ("_%d" % [_variant_idx + 1]) if variant_count > 1 else ""
		var anim_path  := "res://assets/spritesheets/props/%s/%s/%s/%s%s.png" % [sprite_type, sprite_name, anim, size_str, v_part]
		var anim_tex   : Texture2D = load(anim_path)
		var frame_w     := anim_tex.get_height()   # frames are square
		var frame_count := anim_tex.get_width() / frame_w
		for i in range(frame_count):
			var atlas    := AtlasTexture.new()
			atlas.atlas   = anim_tex
			atlas.region  = Rect2(i * frame_w, 0, frame_w, anim_tex.get_height())
			frames.add_frame(anim, atlas)
		
	sprite.animation_finished.connect(_on_animation_finished)


# Called: sprite.animation_finished signal.
func _on_animation_finished() -> void:

	match sprite.animation:
		"death": queue_free()
		"bump":  sprite.play("idle")


# Called: area.body_entered signal.
func _on_body_entered(body: Node2D) -> void:

	# The bump animation triggers when:
	# 1) A character body 2d passes close to the prop AND
	# 2) The prop is alive AND
	# 3) The prop is not playing already the bump animation.
	if body is CharacterBody2D and alive and sprite.animation != "bump":
		#bump.emit()
		sprite.play("bump")


# =============================================================================
# PUBLIC API
# =============================================================================

# Called: game._on_player_attack().
func take_hit() -> void:

	alive = false
	died.emit()
	collision.set_deferred("disabled", true)
	sprite.play("death")
