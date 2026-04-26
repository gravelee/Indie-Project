extends Node2D

# =============================================================================
# HUD.GD
#
# Responsibilities:
#   - Draw player HP / energy / rage / mana bars (bottom-centre of screen)
#   - Draw creature overhead bars (HP + energy + rage/mana) above each sprite
#   - Bars only redraw when stats actually change (_process dirty check)
#
# Drawn on a CanvasLayer — positions are in screen space.
# World→screen: (world_pos - player.position).rotated(-angle) + viewport_centre
# =============================================================================


# ── Player bar dimensions ─────────────────────────────────────────────────────

const P_BAR_W   := 300.0   # wider — most important bar
const P_HP_H    := 18.0
const P_SUB_H   := 12.0    # energy, rage, mana
const P_GAP     := 6.0
const P_PAD_BOT := 40.0    # pixels from bottom of screen


# ── Creature bar dimensions ───────────────────────────────────────────────────

const C_BAR_W   := 60.0
const C_HP_H    := 5.0
const C_SUB_H   := 3.0
const C_GAP     := 3.0
const C_OFFSET  := 60.0   # pixels above entity center (screen space)


# ── Colors ────────────────────────────────────────────────────────────────────

const COLOR_BG         := Color(0.15, 0.15, 0.15)
const COLOR_BORDER     := Color(0.04, 0.04, 0.04)
const COLOR_HP_HIGH    := Color(0.24, 0.78, 0.31)
const COLOR_HP_MID     := Color(0.90, 0.78, 0.16)
const COLOR_HP_LOW     := Color(0.86, 0.24, 0.24)
const COLOR_ENERGY     := Color(1.00, 0.55, 0.00)
const COLOR_RAGE       := Color(0.82, 0.16, 0.16)
const COLOR_MANA       := Color(0.31, 0.47, 1.00)


# ── References set by game.gd ─────────────────────────────────────────────────

var player_stats  : Stats              # set game._ready().
var player        : CharacterBody2D    # set game._ready() via init().
var creatures     : Dictionary  = {}   # set game._ready() via init().
var world_angle   : float  = 0.0       # set game._process() via set_world_angle().


# ── Cached layout ─────────────────────────────────────────────────────────────

var _vp_size   : Vector2 = Vector2.ZERO   # set _on_viewport_resized().
var _vp_center : Vector2 = Vector2.ZERO   # set _on_viewport_resized().


# ── Dirty tracking — redraw only when a value changes ────────────────────────

var _last_hp     : int = -1
var _last_energy : int = -1
var _last_rage   : int = -1
var _last_mp     : int = -1


# =============================================================================
# LIFECYCLE
# =============================================================================

# INIT
func _ready() -> void:

	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


# Called: _ready(), size_changed signal.
func _on_viewport_resized() -> void:

	_vp_size   = get_viewport().get_visible_rect().size
	_vp_center = _vp_size * 0.5
	queue_redraw()


# Called: game._ready() after player and creatures are set up.
func init(p_player: CharacterBody2D, p_creatures: Dictionary) -> void:

	player    = p_player
	creatures = p_creatures


# Called: game._process().
func set_world_angle(angle: float) -> void:

	world_angle = angle
	queue_redraw()


# LOOP
func _process(_delta: float) -> void:

	if not player_stats:
		return

	var hp     : int = int(player_stats.hp)
	var energy : int = int(player_stats.energy)
	var rage   : int = int(player_stats.rage)
	var mp     : int = int(player_stats.mp)

	if hp != _last_hp or energy != _last_energy or rage != _last_rage or mp != _last_mp:
		_last_hp     = hp
		_last_energy = energy
		_last_rage   = rage
		_last_mp     = mp
		queue_redraw()

	# Creature bars always need a redraw (creatures move every frame).
	if creatures.size() > 0:
		queue_redraw()


# Godot built-in — triggered by queue_redraw().
func _draw() -> void:

	_draw_player_bars()
	_draw_creature_bars()


# =============================================================================
# PLAYER BARS
# =============================================================================

# Called: _draw().
func _draw_player_bars() -> void:

	if not player_stats:
		return

	var s := player_stats

	# Each bar only visible when below its maximum.
	var has_hp     := int(s.hp)     < int(s.hp_max)
	var has_energy := int(s.energy) < int(s.energy_max)
	var has_rage   := s.rage > 0.0 and s.rage < s.rage_max
	var has_mana   := s.spr > 0 and s.mp_max > 0.0 and s.mp > 0.0 and s.mp < s.mp_max

	if not has_hp and not has_energy and not has_rage and not has_mana:
		return

	var x := _vp_center.x - P_BAR_W * 0.5

	# Measure total stack height (top → bottom: energy, HP, rage/mana).
	var total_h := 0.0
	if has_energy:           total_h += P_SUB_H + P_GAP
	if has_hp:               total_h += P_HP_H  + P_GAP
	if has_rage or has_mana: total_h += P_SUB_H + P_GAP
	total_h = maxf(0.0, total_h - P_GAP)

	var stack_top := _vp_size.y - P_PAD_BOT - total_h

	if has_energy:
		_draw_bar(x, stack_top, P_BAR_W, P_SUB_H, _int_pct(s.energy, s.energy_max), COLOR_ENERGY)
		stack_top += P_SUB_H + P_GAP

	if has_hp:
		_draw_bar(x, stack_top, P_BAR_W, P_HP_H, _int_pct(s.hp, s.hp_max), _hp_color(s.hp_pct()))
		stack_top += P_HP_H + P_GAP

	if has_rage:
		_draw_bar(x, stack_top, P_BAR_W, P_SUB_H, _int_pct(s.rage, s.rage_max), COLOR_RAGE)
	elif has_mana:
		_draw_bar(x, stack_top, P_BAR_W, P_SUB_H, _int_pct(s.mp, s.mp_max), COLOR_MANA)


# =============================================================================
# CREATURE OVERHEAD BARS
# =============================================================================

# Called: _draw().
func _draw_creature_bars() -> void:

	if not player:
		return

	for creature in creatures.values():
		
		if not creature.alive:
			continue

		var s : Stats = creature.stats

		# Each bar only visible when below its maximum.
		var has_hp     := int(s.hp)     < int(s.hp_max)
		var has_energy := int(s.energy) < int(s.energy_max)
		var has_rage   := s.rage > 0.0 and s.rage < s.rage_max
		var has_mana   := s.spr > 0 and s.mp_max > 0.0 and s.mp > 0.0 and s.mp < s.mp_max

		if not has_hp and not has_energy and not has_rage and not has_mana:
			continue

		# Convert world position to screen space.
		var sp : Vector2 = _world_to_screen(creature.position)
		var bx : float   = sp.x - C_BAR_W * 0.5
		var by : float   = sp.y - C_OFFSET

		# Measure total stack height.
		var total_h := 0.0
		if has_energy:           total_h += C_SUB_H + C_GAP
		if has_hp:               total_h += C_HP_H  + C_GAP
		if has_rage or has_mana: total_h += C_SUB_H + C_GAP
		total_h = maxf(0.0, total_h - C_GAP)

		var cursor_y := by - total_h

		if has_energy:
			_draw_bar(bx, cursor_y, C_BAR_W, C_SUB_H, _int_pct(s.energy, s.energy_max), COLOR_ENERGY)
			cursor_y += C_SUB_H + C_GAP

		if has_hp:
			_draw_bar(bx, cursor_y, C_BAR_W, C_HP_H, _int_pct(s.hp, s.hp_max), _hp_color(s.hp_pct()))
			cursor_y += C_HP_H + C_GAP

		if has_rage:
			_draw_bar(bx, cursor_y, C_BAR_W, C_SUB_H, _int_pct(s.rage, s.rage_max), COLOR_RAGE)
		elif has_mana:
			_draw_bar(bx, cursor_y, C_BAR_W, C_SUB_H, _int_pct(s.mp, s.mp_max), COLOR_MANA)


# =============================================================================
# HELPERS
# =============================================================================

# Called: _draw_player_bars(), _draw_creature_bars().
func _draw_bar(x: float, y: float, w: float, h: float, pct: float, color: Color) -> void:

	var border := 1.0
	draw_rect(Rect2(x - border, y - border, w + border * 2.0, h + border * 2.0), COLOR_BORDER)
	draw_rect(Rect2(x, y, w, h), COLOR_BG)
	var fill_w := maxf(0.0, w * clampf(pct, 0.0, 1.0))
	if fill_w > 0.0:
		draw_rect(Rect2(x, y, fill_w, h), color)


# Called: _draw_player_bars(), _draw_creature_bars().
func _hp_color(pct: float) -> Color:

	if pct > 0.75:   return COLOR_HP_HIGH
	elif pct > 0.25: return COLOR_HP_MID
	else:            return COLOR_HP_LOW


# Called: _draw_player_bars(), _draw_creature_bars().
func _int_pct(val: float, max_val: float) -> float:

	if max_val <= 0.0:
		return 0.0
	return clampf(float(int(val)) / max_val, 0.0, 1.0)


# Called: _draw_creature_bars().
func _world_to_screen(world_pos: Vector2) -> Vector2:

	var delta : Vector2 = world_pos - player.position
	return delta.rotated(deg_to_rad(world_angle)) + _vp_center
