class_name ReactiveProp
extends WorldProp

const ANIM_PASS := "pass"

# ── State ──────────────────────────────────────────────────────────────────────

var _bodies_inside : Array = []


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	super._ready()
	var area       := Area2D.new()
	var col_area   := CollisionShape2D.new()
	col_area.position = weight_central
	var shape      := CircleShape2D.new()
	shape.radius   = float(min(cols, rows)) * TILE_SIZE * 0.5   # half-tile per tile — covers walkable area through the sprite
	col_area.shape = shape
	area.add_child(col_area)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


# =============================================================================
# ANIMATIONS
# =============================================================================

# Override: called by WorldProp._ready() via virtual dispatch.
func _load_animations() -> void:

	super._load_animations()
	var frames     := sprite.sprite_frames
	frames.add_animation(ANIM_PASS)
	frames.set_animation_loop(ANIM_PASS, true)
	frames.set_animation_speed(ANIM_PASS, 8.0)
	var size_str   := "%dx%d" % [cols, rows]
	var v_part     := ("_%d" % [_variant_idx + 1]) if variant_count > 1 else ""
	var anim_path  := "res://assets/spritesheets/props/%s/%s/%s/%s%s.png" % [sprite_type, sprite_name, ANIM_PASS, size_str, v_part]
	var anim_tex   : Texture2D = load(anim_path)
	var frame_w    := anim_tex.get_height()
	var frame_count := anim_tex.get_width() / frame_w
	for i in range(frame_count):
		var atlas   := AtlasTexture.new()
		atlas.atlas  = anim_tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, anim_tex.get_height())
		frames.add_frame(ANIM_PASS, atlas)


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP
func _process(_dt: float) -> void:

	for body in _bodies_inside:
		if is_instance_valid(body) and body.velocity != Vector2.ZERO:
			if sprite.animation != ANIM_PASS:
				sprite.play(ANIM_PASS)
			return
	if sprite.animation == ANIM_PASS:
		sprite.play("idle")


# =============================================================================
# SIGNALS
# =============================================================================

# Called: area.body_entered signal.
func _on_body_entered(body: Node2D) -> void:

	if body is CharacterBody2D:
		_bodies_inside.append(body)


# Called: area.body_exited signal.
func _on_body_exited(body: Node2D) -> void:

	_bodies_inside.erase(body)
