extends Node2D

const TILE_SIZE := 32
const Z_DEPTH_SCALE 		:= 2.0	# Very smooth sprite overlap. Keep between [2-32].
const ENTITY_MEDIUM_OFFSET := 48.0	# Medium size = 3x3 (32px tile), 48 = 1.5 tiles from bottom left.


# ── File paths ─────────────────────────────────────────────────────────────────

const PATH_MAP_SCRIPT             := "res://scripts/map.gd"
const PATH_HUD_SCRIPT             := "res://scripts/ui/hud.gd"
const PATH_COMBAT_FEEDBACK_SCRIPT := "res://scripts/ui/combat_feedback.gd"
const PATH_STAT_PANEL_SCRIPT      := "res://scripts/ui/stat_panel.gd"
const PATH_DEBUG_OVERLAY_SCRIPT   := "res://scripts/ui/debug_overlay.gd"


# ── Camera rotation state ──────────────────────────────────────────────────────

var world_angle : float  = 0.0   # positive = world rotates clockwise
var rmb_held    : bool   = false
var last_mouse  : Vector2 = Vector2.ZERO

# _angle_dirty is set to true whenever world_angle changes.
var _angle_dirty : bool  = true

# Recomputed only when _angle_dirty is true.
var cached_sin_a : float = 0.0
var cached_cos_a : float = 1.0


# ── Node ───────────────────────────────────────────────────────────────────────

var map               : Node2D				# init _build_scene().
var camera            : Camera2D			# init _build_scene().
var hud               : Node2D				# init _build_scene().
var combat_feedback   : Node2D				# init _build_scene().
var stat_panel        : Node2D				# init _build_scene().
var debug_overlay     : Node2D				# init _build_scene().


# =============================================================================
# INITIALIZATION
# =============================================================================

# INIT
func _ready() -> void:
	
	print("------------------- GAME INITIALIZATION --------------------")
	_build_scene()


# Called: _ready().
func _build_scene() -> void:
	
	map = Node2D.new()
	map.set_script(load(PATH_MAP_SCRIPT))
	add_child(map)
	
	camera = Camera2D.new()
	camera.ignore_rotation = false
	add_child(camera)
	
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	hud = Node2D.new()
	hud.set_script(load(PATH_HUD_SCRIPT))
	hud_layer.add_child(hud)

	combat_feedback = Node2D.new()
	combat_feedback.set_script(load(PATH_COMBAT_FEEDBACK_SCRIPT))
	hud_layer.add_child(combat_feedback)

	stat_panel = Node2D.new()
	stat_panel.set_script(load(PATH_STAT_PANEL_SCRIPT))
	hud_layer.add_child(stat_panel)

	# World-space debug overlay — must be a direct child of game, not CanvasLayer.
	debug_overlay = Node2D.new()
	debug_overlay.set_script(load(PATH_DEBUG_OVERLAY_SCRIPT))
	add_child(debug_overlay)
	
	hud.player_stats = map.player.stats

	debug_overlay.init(map.player, map.creatures, map.destructible_map, map.invulnerable_map, map.pathfinder, map._map_cols, map._map_rows, map.rotatable_sprites)

	hud.init(map.player, map.creatures)
	combat_feedback.init(map.player, map.creatures)
	stat_panel.init(map.player, map.creatures)
	stat_panel.debug_overlay = debug_overlay


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP
func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		rmb_held = event.pressed
		if not rmb_held:
			last_mouse = Vector2.ZERO


# LOOP
func _process(delta: float) -> void:

	_rotate_camera()
	_update_sprites()
	_update_z_sort()
	
	if _angle_dirty:
		hud.set_world_angle(world_angle)
		combat_feedback.set_world_angle(world_angle)
		stat_panel.set_world_angle(world_angle)
		debug_overlay.set_world_angle(world_angle)

	_angle_dirty = false


# =============================================================================
# PER-FRAME UPDATES
# =============================================================================


# Called: _process().
func _rotate_camera() -> void:

	# Drag RMB left/right to rotate the world view.
	if not rmb_held:
		return

	var mouse := get_viewport().get_mouse_position()

	if last_mouse == Vector2.ZERO:
		last_mouse = mouse
		return

	var delta_x := mouse.x - last_mouse.x
	if abs(delta_x) >= 1.0:
		world_angle  = fmod(world_angle + delta_x * 0.5, 360.0)
		_angle_dirty = true

	last_mouse = mouse


# Called: _process().
func _update_sprites() -> void:

	# Always: keep sprite and camera locked to the physics body position.
	map.player_sprite.global_position  = map.player.global_position
	camera.global_position         = map.player.global_position
	if map.weapon_sprite.visible:
		map.weapon_sprite.global_position  = map.player.global_position
		# Sword rotation = camera counter-rotation + per-facing offset (updated every frame
		# because either world_angle or sword_facing_deg can change independently).
		map.weapon_sprite.rotation_degrees = -world_angle + map.player.sword_facing_deg

	# Only on rotation: update angles.
	if _angle_dirty:
		map.player_sprite.rotation_degrees = -world_angle
		camera.rotation_degrees        = -world_angle
		map.player.camera_angle            = world_angle
		for creature in map.creatures.values():
			creature.camera_angle = world_angle


# Called: _process().
func _update_z_sort() -> void:

	# Formula: z ∝ pos.x·sin + pos.y·cos
	# Only on rotation: recompute trig, rotate all entity sprites, update depths.
	if _angle_dirty:
		var rad      := deg_to_rad(world_angle)
		cached_sin_a  = sin(rad)
		cached_cos_a  = cos(rad)
		for sprite in map.creature_sprites.values():
			sprite.rotation_degrees = -world_angle
		for sprite in map.rotatable_sprites:
			sprite.rotation_degrees = -world_angle
			var prop = sprite.get_parent() as WorldProp
			# Rotating-circle z-sort: anchor = screen-south tip of a circle of radius z_radius
			# centred at weight_central.  Projection: wc_x*sin + wc_y*cos + z_radius
			# z_radius is constant per prop (angle-independent) -- no lerp, no hard switch.
			var wc_x : float = prop.position.x + prop.weight_central.x
			var wc_y : float = prop.position.y + prop.weight_central.y
			sprite.z_index = int((wc_x * cached_sin_a + wc_y * cached_cos_a + prop.z_radius) / Z_DEPTH_SCALE)
		
	# Always: player and creatures move every frame so depth must stay current.
	# Rotating-circle z for entities: ENTITY_MEDIUM_OFFSET added as a constant.
	# This mirrors how prop z_radius works — offset stays positive at all angles.
	map.player_sprite.z_index = int((map.player.position.x * cached_sin_a + map.player.position.y * cached_cos_a + ENTITY_MEDIUM_OFFSET) / Z_DEPTH_SCALE)
	if map.weapon_sprite.visible:
		match map.player.facing:
			map.player.Facing.NORTH:
				map.weapon_sprite.z_index = map.player_sprite.z_index - 1  # behind player, above northern obstacles
			map.player.Facing.SOUTH:
				map.weapon_sprite.z_index = map.player_sprite.z_index      # tree order puts weapon in front of player
			_:  # EAST, WEST
				map.weapon_sprite.z_index = map.player_sprite.z_index + 1  # in front of player and same-y obstacles
	for creature in map.creatures.values():
		creature.sprite.z_index = int(
			(creature.position.x * cached_sin_a + creature.position.y * cached_cos_a + ENTITY_MEDIUM_OFFSET) / Z_DEPTH_SCALE)
