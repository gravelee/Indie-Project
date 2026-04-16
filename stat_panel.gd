extends Node2D

# =============================================================================
# STAT_PANEL.GD
#
# Responsibilities:
#   - Creature panel: left-click a creature to open its stat panel (left side).
#   - Player panel:   P key toggles the player's stat panel + pauses the game.
#   - Auto-close creature panel when that creature dies.
#
# Drawn on a CanvasLayer so it stays on screen regardless of camera.
# =============================================================================


# ── Layout ────────────────────────────────────────────────────────────────────

const PANEL_W     := 280.0
const PADDING     := 12.0
const LINE_H      := 18.0
const SECTION_GAP := 8.0
const BAR_H       := 8.0
const TITLE_SIZE  := 17
const FONT_SIZE   := 14

const CREATURE_PANEL_X := 10.0
const CREATURE_PANEL_Y := 10.0
const PLAYER_PANEL_X   := 10.0
const PLAYER_PANEL_Y   := 10.0


# ── Colors ────────────────────────────────────────────────────────────────────

const C_BG      := Color(0.059, 0.059, 0.078, 0.86)
const C_BORDER  := Color(0.31, 0.31, 0.39)
const C_DIVIDER := Color(0.20, 0.20, 0.25)
const C_LABEL   := Color(0.55, 0.55, 0.63)
const C_VALUE   := Color(1.00, 1.00, 1.00)
const C_TITLE   := Color(0.78, 0.71, 0.39)
const C_STATE   := Color(0.39, 0.78, 0.47)
const C_EFFECT  := Color(1.00, 0.71, 0.20)

const C_HP_HIGH := Color(0.24, 0.78, 0.31)
const C_HP_MID  := Color(0.90, 0.78, 0.16)
const C_HP_LOW  := Color(0.86, 0.24, 0.24)
const C_ENERGY  := Color(1.00, 0.55, 0.00)
const C_RAGE    := Color(0.82, 0.16, 0.16)
const C_MANA    := Color(0.31, 0.47, 1.00)
const C_BAR_BG  := Color(0.12, 0.12, 0.16)


# ── References ────────────────────────────────────────────────────────────────

var player    : CharacterBody2D   # set game._ready() via init().
var creatures : Array = []        # set game._ready() via init().

var _creature_entity : CharacterBody2D = null   # Currently open creature.
var _player_open     : bool            = false
var _world_angle     : float           = 0.0    # set game._process() via set_world_angle().
var _font            : Font
var _font_title      : Font

# Caches script → State enum dict so get_script_constant_map() is not called every frame.
var _state_enum_cache : Dictionary = {}


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	# Must process even when the tree is paused so P can unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font        = ThemeDB.fallback_font
	_font_title  = ThemeDB.fallback_font


# Called: game._ready().
func init(p_player: CharacterBody2D, p_creatures: Array) -> void:

	player    = p_player
	creatures = p_creatures


# Called: game._process().
func set_world_angle(angle: float) -> void:

	_world_angle = angle


# =============================================================================
# INPUT
# =============================================================================

# LOOP
func _input(event: InputEvent) -> void:

	# ── P key: toggle player panel ────────────────────────────────────────────
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_player_open = not _player_open
			get_tree().paused = _player_open
			queue_redraw()

	# ── Left-click: open/close creature panel ─────────────────────────────────
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos : Vector2 = event.position
		_handle_creature_click(click_pos)


# Called: _input().
func _handle_creature_click(click_pos: Vector2) -> void:

	# Check if click is inside an existing open panel (ignore if so).
	if _creature_entity != null:
		var panel_rect := Rect2(CREATURE_PANEL_X, CREATURE_PANEL_Y, PANEL_W, 600)
		if panel_rect.has_point(click_pos):
			return

	# Find any creature whose screen-space position is within 32px of the click.
	var vp_center : Vector2 = get_viewport().get_visible_rect().size * 0.5
	for creature in creatures:
		if not creature.alive:
			continue
		var screen_pos : Vector2 = _world_to_screen(creature.position, vp_center, _world_angle)
		if screen_pos.distance_to(click_pos) <= 32.0:
			_creature_entity = creature
			queue_redraw()
			return

	# Clicked empty space — close creature panel.
	_creature_entity = null
	queue_redraw()


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP
func _process(_delta: float) -> void:

	# Auto-close creature panel when entity dies.
	if _creature_entity != null and (not _creature_entity.alive or
			_creature_entity.state == _creature_entity.State.DEAD):
		_creature_entity = null

	# Skip redraw entirely when nothing is open.
	if not _player_open and _creature_entity == null:
		return

	queue_redraw()


# Called: _input(), _handle_creature_click(), _process().
func _draw() -> void:

	# Godot built-in — triggered by queue_redraw().
	if _creature_entity != null:
		_draw_panel(_creature_entity, CREATURE_PANEL_X, CREATURE_PANEL_Y)

	if _player_open and player:
		var px := get_viewport().get_visible_rect().size.x - PANEL_W - 10.0
		_draw_panel(player, px, PLAYER_PANEL_Y)


# =============================================================================
# PANEL RENDERING
# =============================================================================

# Called: _draw().
func _draw_panel(entity: CharacterBody2D, px: float, py: float) -> void:

	var lines : Array = _build_lines(entity)
	var panel_h : float = _calc_height(lines)

	# Background.
	draw_rect(Rect2(px, py, PANEL_W, panel_h), C_BG)
	# Border.
	draw_rect(Rect2(px, py, PANEL_W, panel_h), C_BORDER, false, 1.0)

	var cursor_y : float = py + PADDING

	for item in lines:
		var kind : String = item[0]

		match kind:

			"title":
				draw_string(_font_title, Vector2(px + PADDING, cursor_y + TITLE_SIZE),
							item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, C_TITLE)
				cursor_y += TITLE_SIZE + 4.0

			"divider":
				draw_line(
					Vector2(px + PADDING, cursor_y + 3.0),
					Vector2(px + PANEL_W - PADDING, cursor_y + 3.0),
					C_DIVIDER, 1.0
				)
				cursor_y += SECTION_GAP

			"row":
				var label   : String = item[1]
				var value   : String = str(item[2])
				var color   : Color  = item[3] if item.size() > 3 else C_VALUE
				var inner_w : float  = PANEL_W - PADDING * 2.0
				draw_string(_font, Vector2(px + PADDING, cursor_y + FONT_SIZE),
							label, HORIZONTAL_ALIGNMENT_LEFT, inner_w * 0.55, FONT_SIZE, C_LABEL)
				draw_string(_font, Vector2(px + PADDING, cursor_y + FONT_SIZE),
							value, HORIZONTAL_ALIGNMENT_RIGHT, inner_w, FONT_SIZE, color)
				cursor_y += LINE_H

			"bar":
				var label   : String = item[1]
				var pct     : float  = item[2]
				var color   : Color  = item[3]
				var cur     : float  = item[4]
				var mx      : float  = item[5]
				var inner_w : float  = PANEL_W - PADDING * 2.0
				draw_string(_font, Vector2(px + PADDING, cursor_y + FONT_SIZE),
							label, HORIZONTAL_ALIGNMENT_LEFT, inner_w * 0.55, FONT_SIZE, C_LABEL)
				var val_txt := str(int(cur)) + "/" + str(int(mx))
				draw_string(_font, Vector2(px + PADDING, cursor_y + FONT_SIZE),
							val_txt, HORIZONTAL_ALIGNMENT_RIGHT, inner_w, FONT_SIZE, C_VALUE)
				cursor_y += LINE_H - 4.0
				var bx := px + PADDING
				var bw := PANEL_W - PADDING * 2.0
				draw_rect(Rect2(bx, cursor_y, bw, BAR_H), C_BAR_BG)
				var fill_w := maxf(0.0, bw * clampf(pct, 0.0, 1.0))
				if fill_w > 0.0:
					draw_rect(Rect2(bx, cursor_y, fill_w, BAR_H), color)
				cursor_y += BAR_H + 6.0

			"text":
				var color : Color = item[2] if item.size() > 2 else C_VALUE
				draw_string(_font, Vector2(px + PADDING, cursor_y + FONT_SIZE),
							item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
				cursor_y += LINE_H


# =============================================================================
# LINE BUILDERS
# =============================================================================

# Called: _draw_panel().
func _build_lines(entity: CharacterBody2D) -> Array:

	var lines : Array = []
	var s     : Stats = entity.stats

	# ── Title ────────────────────────────────────────────────────────────────
	var etype : String = entity.get_script().resource_path.get_file().get_basename().capitalize()
	lines.append(["title", "%s  Lv%d" % [etype, s.level]])
	lines.append(["title", "%s  %s"   % [s.rank_grade(), s.rank_title()]])
	lines.append(["divider"])

	# ── Resources ────────────────────────────────────────────────────────────
	lines.append(["bar", "HP",     s.hp_pct(),     _hp_color(s.hp_pct()),    s.hp,     s.hp_max])
	lines.append(["bar", "Energy", s.energy_pct(), C_ENERGY,                 s.energy, s.energy_max])
	if s.rage > 0.0:
		lines.append(["bar", "Rage",  s.rage_pct(),   C_RAGE,   s.rage, s.rage_max])
	if s.spr > 0 and s.mp_max > 0.0:
		lines.append(["bar", "Mana",  s.mp_pct(),     C_MANA,   s.mp,   s.mp_max])
	lines.append(["divider"])

	# ── Base stats ───────────────────────────────────────────────────────────
	lines.append(["row", "STR", s.str_])
	lines.append(["row", "AGI", s.agi])
	lines.append(["row", "STA", s.sta])
	lines.append(["row", "INT", s.int_])
	lines.append(["row", "SPR", s.spr])
	lines.append(["row", "RES", s.res])
	lines.append(["row", "DEF", s.def_])
	lines.append(["divider"])

	# ── Derived stats ────────────────────────────────────────────────────────
	lines.append(["row", "PATK",   "%.1f" % s.patk])
	lines.append(["row", "MATK",   "%.1f" % s.matk])
	lines.append(["row", "PDEF",   "%.1f" % s.pdef])
	lines.append(["row", "MDEF",   "%.1f" % s.mdef])
	lines.append(["row", "CRIT",   "%.1f%%" % s.crit])
	lines.append(["row", "MCRIT",  "%.1f%%" % s.mcrit])
	lines.append(["row", "DODGE",  "%.1f%%" % s.dodge])
	lines.append(["row", "BLOCK",  "%.1f%%" % s.block])
	lines.append(["row", "RESIST", "%.1f%%" % s.resist])
	lines.append(["row", "MSPD",   "%.1f" % s.mspd])
	lines.append(["divider"])

	# ── Combat state ─────────────────────────────────────────────────────────
	lines.append(["row", "STATE", _get_state_name(entity), C_STATE])
	var ic : bool = entity.get("in_combat") if entity.get("in_combat") != null else false
	lines.append(["row", "COMBAT", "true" if ic else "false",
				  Color(0.86, 0.24, 0.24) if ic else Color(0.39, 0.78, 0.47)])
	lines.append(["row", "GCD",
				  "Ready" if s.gcd_timer <= 0.0 else "%.2f" % s.gcd_timer,
				  C_STATE if s.gcd_timer <= 0.0 else C_LABEL])
	lines.append(["divider"])

	# ── EXP and rank ─────────────────────────────────────────────────────────
	lines.append(["row", "EXP",      int(s.exp)])
	lines.append(["row", "LIFETIME", int(s.lifetime_exp)])
	lines.append(["divider"])

	# ── Abilities ────────────────────────────────────────────────────────────
	var abilities = entity.get("abilities")
	if abilities and abilities.size() > 0:
		for ability in abilities:
			var cd_txt : String = "Ready" if ability.ready else "%.1fs" % ability._timer
			lines.append(["row", ability.name, cd_txt,
						  C_STATE if ability.ready else C_LABEL])
			for result in ability.last_hit_verdict:
				var txt : String
				match result["hit_type"]:
					"dodge":   txt = "Dodged"
					"block":   txt = "Blocked"
					"resist":  txt = "Resisted"
					_:
						txt = "%.0f dmg" % result["damage"]
						if result["crit"]:        txt += "  CRIT"
						if result["effect"] != "": txt += "  [%s]" % result["effect"]
				lines.append(["text", "  → " + txt,
							  C_EFFECT if result["crit"] else C_VALUE])
		lines.append(["divider"])

	# ── Active effects ───────────────────────────────────────────────────────
	var eff_manager : StatusEffect.EffectManager = entity.stats.effects
	if eff_manager and eff_manager.count() > 0:
		var active := eff_manager.get_active()
		for eff_name in active:
			var eff : StatusEffect.Effect = active[eff_name]
			var txt := "%s  x%d  %.1fs" % [eff.name, eff.stacks, eff.time_remaining]
			lines.append(["text", txt, C_EFFECT])
	else:
		lines.append(["text", "No active effects", C_LABEL])

	return lines


# =============================================================================
# HELPERS
# =============================================================================

# Called: _draw_panel().
func _calc_height(lines: Array) -> float:

	var h : float = PADDING * 2.0
	for item in lines:
		match item[0]:
			"title"  : h += TITLE_SIZE + 4.0
			"divider": h += SECTION_GAP
			"row"    : h += LINE_H
			"bar"    : h += (LINE_H - 4.0) + BAR_H + 6.0
			"text"   : h += LINE_H
	return h


# Called: _build_lines().
func _hp_color(pct: float) -> Color:

	if pct > 0.75:   return C_HP_HIGH
	elif pct > 0.25: return C_HP_MID
	else:            return C_HP_LOW


# Called: _build_lines().
func _get_state_name(entity: CharacterBody2D) -> String:

	var state_val = entity.get("state")
	if state_val == null:
		return "N/A"
	var script = entity.get_script()
	if not script:
		return str(int(state_val))
	if not _state_enum_cache.has(script):
		var consts : Dictionary = script.get_script_constant_map()
		_state_enum_cache[script] = consts.get("State", {})
	var key = _state_enum_cache[script].find_key(int(state_val))
	return str(key) if key != null else str(int(state_val))


# Called: _handle_creature_click().
func _world_to_screen(world_pos: Vector2, vp_center: Vector2, angle: float) -> Vector2:

	var delta : Vector2 = world_pos - player.position
	return delta.rotated(deg_to_rad(angle)) + vp_center
