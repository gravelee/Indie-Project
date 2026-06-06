class_name DamageableProp
extends WorldProp

# =============================================================================
# DAMAGEABLE PROP — adds death + reaction animations and take_hit().
# Base for ObstacleProp (bushes) and TerrainProp (grass).
#
# Reaction detection:
#   Each prop owns a child Area3D ("DetectZone") with:
#     collision_layer = PROP_REACT_LAYER  (layer 3, bitmask 4)
#     monitoring      = false             — prop never checks anything per-frame
#     monitorable     = true              — entity react zones CAN detect this area
#   Entity react zones (player / creature) have monitoring=true and mask=PROP_REACT_LAYER.
#   They use area_entered to find the prop via area.get_parent().trigger_reaction().
#
# This keeps the detection shape completely separate from the blocking layer (1).
# Grass has no blocking shape; bushes have a blocking shape on layer 1 only.
# Neither is affected by the detection area's layer assignment.
# =============================================================================

signal died

const ANIM_DEATH : String = "death"

var alive          : bool   = true
var _reaction_anim : String = ""   # "bump" for obstacles, "pass" for terrain
var _area_radius   : float  = 0.0  # set in subclass _ready() before super._ready()
var _react_shape   : CollisionShape3D = null   # detection shape; disabled on death
var _react_count   : int    = 0    # entities currently driving the reaction animation


# =============================================================================
# SETUP
# =============================================================================

func _ready() -> void:
	super._ready()
	add_to_group("react_props")

	# Passive detection zone — entity react zones detect this via area_entered.
	# monitoring=false  → zero per-frame cost on the prop side.
	# monitorable=true  → entity Area3D (mask=PROP_REACT_LAYER) fires area_entered.
	# collision_layer=PROP_REACT_LAYER only — NOT layer 1, so player movement
	# is never blocked by the detection cylinder.
	var detect_area := Area3D.new()
	detect_area.name            = "DetectZone"
	detect_area.collision_layer = WorldProp.PROP_REACT_LAYER
	detect_area.collision_mask  = 0
	detect_area.monitorable     = true
	detect_area.monitoring      = false

	_react_shape = CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius          = _area_radius
	shp.height          = 1.5
	_react_shape.position.y = 0.75
	_react_shape.shape  = shp
	detect_area.add_child(_react_shape)
	add_child(detect_area)


# =============================================================================
# ANIMATIONS — unchanged from original
# =============================================================================

func _load_animations() -> void:
	var key    : String       = _frames_key()
	var cached : SpriteFrames = _frames_cache.get(key, null) as SpriteFrames
	if cached != null:
		sprite.sprite_frames = cached
		_apply_sprite_position(_load_prop_tex(states[0]))
		sprite.animation_finished.connect(_on_animation_finished)
		return

	var frames := SpriteFrames.new()
	for state : String in states:
		var tex : Texture2D = _load_prop_tex(state)
		if tex == null:
			continue
		frames.add_animation(state)
		frames.set_animation_loop(state, true)
		frames.set_animation_speed(state, 8.0)
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(0, 0, tex.get_width(), tex.get_height())
		frames.add_frame(state, atlas)
		if state == states[0]:
			_apply_sprite_position(tex)

	var extra : Array[String] = [ANIM_DEATH]
	if not _reaction_anim.is_empty():
		extra.append(_reaction_anim)

	for anim : String in extra:
		var sheet : Texture2D = _load_anim_sheet(anim)
		if sheet == null:
			continue
		var idle_atlas : AtlasTexture = frames.get_frame_texture(states[0], 0) as AtlasTexture
		if idle_atlas == null:
			continue
		var frame_w : int = int(idle_atlas.region.size.x)
		var frame_h : int = int(idle_atlas.region.size.y)
		var count   : int = sheet.get_width() / frame_w
		if count <= 0:
			continue
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, 8.0)
		for i : int in range(count):
			var atlas := AtlasTexture.new()
			atlas.atlas  = sheet
			atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			frames.add_frame(anim, atlas)

	sprite.sprite_frames = frames
	sprite.animation_finished.connect(_on_animation_finished)
	_frames_cache[key] = frames


func _load_anim_sheet(anim: String) -> Texture2D:
	var size_str : String = "%dx%d" % [cols, rows]
	var h_part   : String = ("_h%d" % height_ext) if height_ext > 0 else ""
	var v_part   : String = ("/%d" % (_variant_idx + 1)) if variant_count > 1 else ""
	var path     : String = "res://assets/spritesheets/props/%s/%s/%s%s/%s%s.png" % [
		sprite_type, sprite_name, anim, v_part, size_str, h_part]
	if not ResourceLoader.exists(path):
		return null
	var raw : Texture2D = load(path) as Texture2D
	# If this prop uses canvas padding, pad the animation sheet the same way so all
	# frame heights match the padded idle frame. Without this the atlas samples beyond
	# the sheet bounds, shifting/wrapping the animation content visually.
	if _idle_blit_y < 0:
		return raw
	var cache_key : String = path + ":anim:" + str(_idle_blit_y) + ":" + str(_canvas_add_rows)
	var cached    : Texture2D = _tex_cache.get(cache_key, null) as Texture2D
	if cached != null:
		return cached
	var src_img : Image = raw.get_image()
	src_img.convert(Image.FORMAT_RGBA8)
	var new_w   : int   = src_img.get_width()
	var new_h   : int   = src_img.get_height() + _canvas_add_rows
	var new_img : Image = Image.create(new_w, new_h, false, Image.FORMAT_RGBA8)
	new_img.blit_rect(src_img, Rect2i(0, 0, new_w, src_img.get_height()), Vector2i(0, _idle_blit_y))
	var tex : ImageTexture = ImageTexture.create_from_image(new_img)
	_tex_cache[cache_key] = tex
	return tex


# =============================================================================
# ANIMATION SIGNAL
# =============================================================================

func _on_animation_finished() -> void:
	if sprite.animation == ANIM_DEATH:
		_on_death_finished()
	elif sprite.animation == _reaction_anim:
		if _react_count > 0:
			sprite.play(_reaction_anim)   # entity still inside and moving — loop
		else:
			sprite.animation = states[0]  # entity left — let this cycle be the last
			sprite.frame     = 0


func _on_death_finished() -> void:
	pass   # override in subclass


# =============================================================================
# PUBLIC API
# =============================================================================

# Call when an entity enters the prop area while moving (or starts moving while inside).
# Each caller must pair every start_reaction() with a matching stop_reaction().
func start_reaction() -> void:
	if not alive or _reaction_anim.is_empty():
		return
	_react_count += 1
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(_reaction_anim):
		if sprite.animation != _reaction_anim:
			sprite.play(_reaction_anim)


# Call when an entity stops moving or leaves the prop area.
# The current animation cycle finishes naturally before snapping back to idle (~0.5s wind-down).
func stop_reaction() -> void:
	_react_count = maxi(0, _react_count - 1)


func take_hit() -> void:
	if not alive:
		return
	alive = false
	died.emit()
	# Disable blocking collision shapes (direct children of this StaticBody3D)
	for child : Node in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	# Disable detection shape (inside child DetectZone Area3D)
	if _react_shape != null:
		_react_shape.set_deferred("disabled", true)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ANIM_DEATH):
		sprite.play(ANIM_DEATH)
	else:
		_on_death_finished()
