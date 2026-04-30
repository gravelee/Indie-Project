class_name DamageableProp
extends WorldProp

signal died

const ANIM_DEATH := "death"


# ── State ──────────────────────────────────────────────────────────────────────

var alive          : bool   = true
var _bodies        : Array  = []
var _reaction_anim : String = ""     # "bump" for Destructible, "pass" for ReactiveProp — set before super._ready().
var _area_radius   : float  = 0.0   # set by subclass before super._ready().


# =============================================================================
# SETUP
# =============================================================================

# Called: Destructible._ready(), ReactiveProp._ready().
func _ready() -> void:

	super._ready()
	set_process(false)
	add_to_group("react_props")
	var area         := Area2D.new()
	var col_area     := CollisionShape2D.new()
	area.position     = Vector2.ZERO
	col_area.position = weight_central
	var shape        := CircleShape2D.new()
	shape.radius      = _area_radius
	col_area.shape    = shape
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

	var anims := [ANIM_DEATH]
	if not _reaction_anim.is_empty():
		anims.append(_reaction_anim)

	for anim in anims:
		var frames     := sprite.sprite_frames
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, 8.0)
		var size_str   := "%dx%d" % [cols, rows]
		var h_part     := ("_h%d" % height_ext) if height_ext > 0 else ""
		var v_part     := ("/%d" % [_variant_idx + 1]) if variant_count > 1 else ""
		var anim_path  := "res://assets/spritesheets/props/%s/%s/%s%s/%s%s.png" % [sprite_type, sprite_name, anim, v_part, size_str, h_part]
		print(anim_path)
		# Per-animation blit_y for thin props (terrain grass, etc.).
		# death: base shifted (cols−1) px lower than idle  → blit_y = TILE_SIZE/4        (8)
		# pass:  base shifted 2*(cols−1) px lower than idle → blit_y = TILE_SIZE/4 + (cols−1)
		# −1 when _idle_blit_y < 0 (manually-sized sprites — no padding needed).
		var anim_blit_y : int
		if _idle_blit_y >= 0:
			if anim == ANIM_DEATH:
				# Lower by (cols−1) px: 0, 1, 2 for 1×1, 2×1, 3×1  →  blit_y always = TILE_SIZE/4
				anim_blit_y = _idle_blit_y + (cols - 1)
			else:  # reaction_anim ("pass")
				# Lower by 2^(cols−1) px: 1, 2, 4 for 1×1, 2×1, 3×1  →  blit_y 9, 9, 10
				anim_blit_y = _idle_blit_y + (1 << (cols - 1))
		else:
			anim_blit_y = -1

		# Frame dimensions must match the idle_alive canvas (same height after padding).
		var anim_tex    : Texture2D = _load_tex(anim_path, anim_blit_y)
		var idle_frame  := sprite.sprite_frames.get_frame_texture(states[0], 0)
		var frame_w     := idle_frame.get_width()
		var frame_h     := idle_frame.get_height()
		var frame_count := anim_tex.get_width() / frame_w
		for i in range(frame_count):
			var atlas   := AtlasTexture.new()
			atlas.atlas  = anim_tex
			atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			frames.add_frame(anim, atlas)

	sprite.animation_finished.connect(_on_animation_finished)


# Called: sprite.animation_finished signal.
func _on_animation_finished() -> void:

	if sprite.animation == ANIM_DEATH:
		_on_death_finished()
	elif sprite.animation == _reaction_anim:
		sprite.play(states[0])


# Virtual — override in subclass.
func _on_death_finished() -> void:
	pass


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP (Only when at least one CharacterBody2D is in the area).
func _process(_dt: float) -> void:

	if not alive:
		return
	for body in _bodies:
		if _is_body_active(body):
			if sprite.animation != _reaction_anim:
				sprite.play(_reaction_anim)
			return
	if sprite.animation == _reaction_anim:
		sprite.play(states[0])


# Called: _process().
func _is_body_active(body: CharacterBody2D) -> bool:

	# True if body is moving OR pressing against this prop.
	if body.velocity != Vector2.ZERO:
		return true
	var m = body.get("moving")
	return m != null and m == true


# =============================================================================
# SIGNALS
# =============================================================================

# Called: area.body_entered signal.
func _on_body_entered(body: Node2D) -> void:

	if alive and body is CharacterBody2D:
		_bodies.append(body)
		set_process(true)


# Called: area.body_exited signal.
func _on_body_exited(body: Node2D) -> void:

	_bodies.erase(body)
	if _bodies.is_empty():
		set_process(false)


# =============================================================================
# PUBLIC API
# =============================================================================

# Called: creature._bump_nearby_props().
func trigger_reaction() -> void:

	if alive and not _reaction_anim.is_empty() and sprite.animation != _reaction_anim:
		sprite.play(_reaction_anim)


# Called: map._on_player_attack().
func take_hit() -> void:

	alive = false
	died.emit()
	_bodies = []
	set_process(false)
	if collision:
		collision.set_deferred("disabled", true)
	sprite.play(ANIM_DEATH)
