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

const C_COMBAT_TINT   := Color(0.30, 0.04, 0.04, 0.20)   # dark red bg overlay when in combat.
const C_COMBAT_BORDER := Color(0.65, 0.12, 0.12, 0.90)   # red border when in combat.


# ── References ────────────────────────────────────────────────────────────────

var player    : CharacterBody2D   # set game._ready() via init().
var creatures : Dictionary = {}   # set game._ready() via init().

var _creature_entity : CharacterBody2D = null   # Currently open creature.
var _player_open     : bool            = false
var _world_angle     : float           = 0.0    # set game._process() via set_world_angle().
var _font            : Font
var _font_title      : Font

# Caches script → State enum dict so get_script_constant_map() is not called every frame.
var _state_enum_cache : Dictionary = {}

# Collapsible section state and hit rects (populated each _draw(), checked in _input()).
# keyed by full prefixed section key e.g. "c_stats", "p_stats", "c_ai".
var _collapsed     : Dictionary = {}
var _section_rects : Dictionary = {}   # key → Rect2 in screen space.

# Debug overlay reference and toggle states (player panel only).
var debug_overlay     : Node2D = null   # set game._ready().
var _dbg_creature_col : bool   = false
var _dbg_player_col   : bool   = false
var _dbg_obstacle_col : bool   = false
var _dbg_prop_z       : bool   = false
var _dbg_tile_grid    : bool   = false
var _dbg_pf_grid      : bool   = false
var _dbg_pf_grid2     : bool   = false
var _dbg_cre_paths      : bool   = false
var _dbg_home_markers   : bool   = false
var _dbg_player_attack  : bool   = false

# Creature debug toggles (creature panel)
var _dbg_cre_attack_dist : bool = false
var _dbg_cre_notice_dist : bool = false
var _dbg_cre_notice_dir  : bool = false
var _dbg_cre_chase_dist  : bool = false
var _dbg_cre_home_max    : bool = false
var _dbg_dyn_blockers    : bool = false
var _dbg_temp_blocks     : bool = false

var _toggle_rects     : Dictionary = {}   # key → Rect2 in screen space.


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
func init(p_player: CharacterBody2D, p_creatures: Dictionary) -> void:

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

	# ── Left-click: toggles → section headers → creature click ─────────────────
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos : Vector2 = event.position
		for key in _toggle_rects:
			if _toggle_rects[key].has_point(click_pos):
				_toggle_debug(key)
				queue_redraw()
				return
		for full_key in _section_rects:
			if _section_rects[full_key].has_point(click_pos):
				_collapsed[full_key] = not _collapsed.get(full_key, false)
				queue_redraw()
				return
		_handle_creature_click(click_pos)


# Called: _input().
func _handle_creature_click(click_pos: Vector2) -> void:

	# Check if click is inside any open panel (ignore if so).
	if _creature_entity != null:
		var panel_rect := Rect2(CREATURE_PANEL_X, CREATURE_PANEL_Y, PANEL_W, 1200)
		if panel_rect.has_point(click_pos):
			return
	if _player_open:
		var ppx := get_viewport().get_visible_rect().size.x - PANEL_W - 10.0
		if Rect2(ppx, PLAYER_PANEL_Y, PANEL_W, 1200).has_point(click_pos):
			return

	# Find any creature whose screen-space position is within 32px of the click.
	var vp_center : Vector2 = get_viewport().get_visible_rect().size * 0.5
	for creature in creatures.values():
		if not is_instance_valid(creature):
			continue
		var screen_pos : Vector2 = _world_to_screen(creature.position, vp_center, _world_angle)
		if screen_pos.distance_to(click_pos) <= 32.0:
			if _creature_entity != null and is_instance_valid(_creature_entity):
				_creature_entity.is_inspected = false
			_creature_entity             = creature
			_creature_entity.is_inspected = true
			queue_redraw()
			return

	# Clicked empty space — close creature panel.
	if _creature_entity != null and is_instance_valid(_creature_entity):
		_creature_entity.is_inspected = false
	_creature_entity = null
	queue_redraw()


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP
func _process(_delta: float) -> void:

	# Guard against freed creature (was freed externally without is_inspected).
	if _creature_entity != null and not is_instance_valid(_creature_entity):
		_creature_entity = null
		return

	# Skip redraw entirely when nothing is open.
	if not _player_open and _creature_entity == null:
		return

	queue_redraw()


# Called: _input(), _handle_creature_click(), _process().
func _draw() -> void:

	# Godot built-in — triggered by queue_redraw().
	_section_rects.clear()
	_toggle_rects.clear()

	if _creature_entity != null and is_instance_valid(_creature_entity):
		_draw_panel(_creature_entity, CREATURE_PANEL_X, CREATURE_PANEL_Y, "c_")

	if _player_open and player:
		var px := get_viewport().get_visible_rect().size.x - PANEL_W - 10.0
		_draw_panel(player, px, PLAYER_PANEL_Y, "p_")


# =============================================================================
# PANEL RENDERING
# =============================================================================

# Called: _draw().
func _draw_panel(entity: CharacterBody2D, px: float, py: float, p_prefix: String = "") -> void:

	var lines : Array = _build_lines(entity, p_prefix)
	var panel_h : float = _calc_height(lines)
	var ic : bool = entity.get("in_combat") == true

	# Background — tinted dark red when in combat.
	draw_rect(Rect2(px, py, PANEL_W, panel_h), C_BG)
	if ic:
		draw_rect(Rect2(px, py, PANEL_W, panel_h), C_COMBAT_TINT)
	# Border — red when in combat.
	draw_rect(Rect2(px, py, PANEL_W, panel_h), C_COMBAT_BORDER if ic else C_BORDER, false, 1.0)

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

			"section":
				# Clickable collapsible header — highlighted background + arrow label.
				var inner_w : float = PANEL_W - PADDING * 2.0
				draw_rect(Rect2(px + 1, cursor_y, PANEL_W - 2, LINE_H), Color(0.14, 0.14, 0.19, 0.7))
				draw_string(_font, Vector2(px + PADDING, cursor_y + FONT_SIZE),
							item[1], HORIZONTAL_ALIGNMENT_LEFT, inner_w, FONT_SIZE, C_TITLE)
				_section_rects[p_prefix + item[2]] = Rect2(px, cursor_y, PANEL_W, LINE_H)
				cursor_y += LINE_H

			"text":
				var color : Color = item[2] if item.size() > 2 else C_VALUE
				draw_string(_font, Vector2(px + PADDING, cursor_y + FONT_SIZE),
							item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
				cursor_y += LINE_H

			"toggle":
				var key     : String = item[1]
				var label   : String = item[2]
				var on      : bool   = item[3]
				var inner_w : float  = PANEL_W - PADDING * 2.0
				var mark    : String = "[X] " if on else "[ ] "
				var col     : Color  = C_STATE if on else C_LABEL
				draw_string(_font, Vector2(px + PADDING, cursor_y + FONT_SIZE),
							mark + label, HORIZONTAL_ALIGNMENT_LEFT, inner_w, FONT_SIZE, col)
				_toggle_rects[key] = Rect2(px, cursor_y, PANEL_W, LINE_H)
				cursor_y += LINE_H


# =============================================================================
# LINE BUILDERS
# =============================================================================

# Called: _draw_panel().
func _build_lines(entity: CharacterBody2D, p_prefix: String = "") -> Array:

	var lines : Array = []
	var s     : Stats = entity.stats

	var is_creature : bool = entity.get("home_position") != null

	# ── Title ────────────────────────────────────────────────────────────────
	var etype   : String = entity.get_script().resource_path.get_file().get_basename().capitalize()
	var is_dead : bool   = entity.get("alive") == false
	lines.append(["title", "%s  Lv%d%s" % [etype, s.level, "  [DEAD]" if is_dead else ""]])
	lines.append(["title", "%s  %s"     % [s.rank_grade(), s.rank_title()]])
	lines.append(["divider"])

	# ── Resources (always shown) ──────────────────────────────────────────────
	lines.append(["bar", "HP",     s.hp_pct(),     _hp_color(s.hp_pct()),    s.hp,     s.hp_max])
	lines.append(["bar", "Energy", s.energy_pct(), C_ENERGY,                 s.energy, s.energy_max])
	if s.rage_max > 0:
		lines.append(["bar", "Rage", s.rage_pct(), C_RAGE, s.rage, s.rage_max])
	if s.spr >= 1 and s.mp_max > 0:
		lines.append(["bar", "Mana", s.mp_pct(),   C_MANA, s.mp,   s.mp_max])
	lines.append(["divider"])

	# ── Stats collapsible (STR → MSPD, then EXP / LIFETIME) ──────────────────
	var stats_collapsed : bool = _collapsed.get(p_prefix + "stats", false)
	lines.append(["section", "▶ STATS" if stats_collapsed else "▼ STATS", "stats"])
	if not stats_collapsed:
		lines.append(["row", "STR", s.str_])
		lines.append(["row", "AGI", s.agi])
		lines.append(["row", "STA", s.sta])
		lines.append(["row", "INT", s.int_])
		lines.append(["row", "SPR", s.spr])
		lines.append(["row", "RES", s.res])
		lines.append(["row", "DEF", s.def_])
		lines.append(["divider"])
		lines.append(["row", "PATK",   "%.1f"   % s.patk])
		lines.append(["row", "MATK",   "%.1f"   % s.matk])
		lines.append(["row", "PDEF",   "%.1f"   % s.pdef])
		lines.append(["row", "MDEF",   "%.1f"   % s.mdef])
		lines.append(["row", "CRIT",   "%.1f%%" % s.crit])
		lines.append(["row", "MCRIT",  "%.1f%%" % s.mcrit])
		lines.append(["row", "DODGE",  "%.1f%%" % s.dodge])
		lines.append(["row", "BLOCK",  "%.1f%%" % s.block])
		lines.append(["row", "RESIST", "%.1f%%" % s.resist])
		lines.append(["row", "MSPD",   "%.1f"   % s.mspd])
		lines.append(["divider"])
		lines.append(["row", "EXP",      int(s.exp)])
		lines.append(["row", "LIFETIME", int(s.lifetime_exp)])
	lines.append(["divider"])

	# ── Player State collapsible (state + abilities) ─────────────────────────
	if not is_creature:
		var ps_collapsed : bool = _collapsed.get(p_prefix + "ps", false)
		lines.append(["section", "▶ PLAYER STATE" if ps_collapsed else "▼ PLAYER STATE", "ps"])
		if not ps_collapsed:
			lines.append(["row", "STATE", _get_state_name(entity), C_STATE])
			var abilities = entity.get("abilities")
			if abilities and abilities.size() > 0:
				lines.append(["divider"])
				lines.append(["row", "GCD",
							  "Ready" if s.gcd_timer <= 0.0 else "%.2f" % s.gcd_timer,
							  C_STATE if s.gcd_timer <= 0.0 else C_LABEL])
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
								if result["crit"]:         txt += "  CRIT"
								if result["effect"] != "": txt += "  [%s]" % result["effect"]
						lines.append(["text", "  → " + txt,
									  C_EFFECT if result["crit"] else C_VALUE])
		lines.append(["divider"])

	# ── Creature State collapsible (state + abilities) ───────────────────────
	if is_creature:
		var cs_collapsed : bool = _collapsed.get(p_prefix + "cs", false)
		lines.append(["section", "▶ CREATURE STATE" if cs_collapsed else "▼ CREATURE STATE", "cs"])
		if not cs_collapsed:
			lines.append(["row", "STATE", _get_state_name(entity), C_STATE])
			var abilities_cs = entity.get("abilities")
			if abilities_cs and abilities_cs.size() > 0:
				lines.append(["divider"])
				lines.append(["row", "GCD",
							  "Ready" if s.gcd_timer <= 0.0 else "%.2f" % s.gcd_timer,
							  C_STATE if s.gcd_timer <= 0.0 else C_LABEL])
				for ability in abilities_cs:
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
								if result["crit"]:         txt += "  CRIT"
								if result["effect"] != "": txt += "  [%s]" % result["effect"]
						lines.append(["text", "  → " + txt,
									  C_EFFECT if result["crit"] else C_VALUE])
		lines.append(["divider"])

	# ── AI State Machine collapsible (creatures only) ─────────────────────────
	if is_creature:
		var ai_collapsed : bool = _collapsed.get(p_prefix + "ai", false)
		lines.append(["section", "▶ AI STATE MACHINE" if ai_collapsed else "▼ AI STATE MACHINE", "ai"])
		if not ai_collapsed:
			var has_home_v  : bool  = entity.get("has_home")        == true
			var temp_home_v : bool  = entity.get("temp_home")       == true
			var returning_v : bool  = entity.get("is_returning")    == true
			var max_dist_v  : bool  = entity.get("home_max_dist")   == true
			var fleeing_v   : bool  = entity.get("fleeing")         == true
			var in_wait_v     : bool  = entity.get("_wait")            == true
			var wait_cnt      : int   = entity.get("_wait_counter")   if entity.get("_wait_counter")   != null else 0
			var wait_tmr      : float = entity.get("_wait_timer")     if entity.get("_wait_timer")     != null else 0.0
			var wait_interval : float = entity.get("_wait_interval")  if entity.get("_wait_interval")  != null else 0.0
			var wait_dmg      : float = entity.get("_wait_damage_acc")if entity.get("_wait_damage_acc")!= null else 0.0

			# Home / AI flags
			var orig_home_txt   : String
			var orig_home_color : Color
			if has_home_v:
				orig_home_txt   = "true";  orig_home_color = C_STATE
			elif temp_home_v:
				orig_home_txt   = "temp";  orig_home_color = Color(0.86, 0.78, 0.24)
			else:
				orig_home_txt   = "false"; orig_home_color = C_LABEL
			lines.append(["row", "ORIG HOME", orig_home_txt, orig_home_color])
			lines.append(["row", "RETURNING", "true" if returning_v else "false",
						  Color(0.86, 0.24, 0.24) if returning_v else C_LABEL])
			lines.append(["row", "MAX DIST",  "true" if max_dist_v  else "false",
						  Color(0.86, 0.24, 0.24) if max_dist_v  else C_LABEL])
			lines.append(["row", "FLEEING",   "true" if fleeing_v   else "false",
						  Color(0.86, 0.24, 0.24) if fleeing_v   else C_LABEL])

			# Wait cycle
			lines.append(["divider"])
			lines.append(["row", "WAIT",      "true" if in_wait_v else "false",
						  Color(0.86, 0.24, 0.24) if in_wait_v else C_LABEL])
			lines.append(["row", "WAIT CNT",  str(wait_cnt),          C_VALUE if wait_cnt > 0 else C_LABEL])
			lines.append(["row", "WAIT TMR",  "%.2f" % wait_tmr])
			lines.append(["row", "WAIT INTV", "%.2f" % wait_interval, C_VALUE if in_wait_v else C_LABEL])
			lines.append(["row", "WAIT DMG",  "%.1f" % wait_dmg])
		lines.append(["divider"])

	# ── Creature debug toggles (creatures only) ───────────────────────────────
	if is_creature:
		var cdbg_collapsed : bool = _collapsed.get(p_prefix + "cdbg", false)
		lines.append(["section", "▶ CREATURE DEBUG" if cdbg_collapsed else "▼ CREATURE DEBUG", "cdbg"])
		if not cdbg_collapsed:
			lines.append(["toggle", "dbg_cre_attack_dist", "Attack Distance",   _dbg_cre_attack_dist])
			lines.append(["toggle", "dbg_cre_notice_dist", "Notice Distance",   _dbg_cre_notice_dist])
			lines.append(["toggle", "dbg_cre_notice_dir",  "Notice Direction",  _dbg_cre_notice_dir])
			lines.append(["toggle", "dbg_cre_chase_dist",  "Chase Distance",    _dbg_cre_chase_dist])
			lines.append(["toggle", "dbg_cre_home_max",    "Home Distance",     _dbg_cre_home_max])
			lines.append(["toggle", "dbg_home_markers",    "Home Markers",      _dbg_home_markers])
			lines.append(["toggle", "dbg_cre_paths",       "Creature Paths",    _dbg_cre_paths])
			lines.append(["toggle", "dbg_dyn_blockers",    "Dynamic Blockers",  _dbg_dyn_blockers])
			lines.append(["toggle", "dbg_temp_blocks",     "Temp Blocks",       _dbg_temp_blocks])
		lines.append(["divider"])

	# ── Debug toggles (player panel only) ────────────────────────────────────
	if not is_creature:
		var dbg_collapsed : bool = _collapsed.get(p_prefix + "dbg", false)
		lines.append(["section", "▶ DEBUG" if dbg_collapsed else "▼ DEBUG", "dbg"])
		if not dbg_collapsed:
			lines.append(["toggle", "dbg_player_attack", "Attack Area",         _dbg_player_attack])
			lines.append(["toggle", "dbg_cre_col",       "Creature Collisions", _dbg_creature_col])
			lines.append(["toggle", "dbg_ply_col",     "Player Collision",    _dbg_player_col])
			lines.append(["toggle", "dbg_obs_col",     "Obstacle Collisions", _dbg_obstacle_col])
			lines.append(["toggle", "dbg_prop_z",      "Prop Z Score",        _dbg_prop_z])
			lines.append(["toggle", "dbg_grid",        "Tile Grid",           _dbg_tile_grid])
			lines.append(["toggle", "dbg_pf_grid",     "PF Grid (dilated)",   _dbg_pf_grid])
			lines.append(["toggle", "dbg_pf_grid2",    "PF Grid2 (LOS)",      _dbg_pf_grid2])
		lines.append(["divider"])

	# ── Active effects (last) ─────────────────────────────────────────────────
	var eff_manager : StatusEffect.EffectManager = entity.stats.effects
	if eff_manager and eff_manager.count() > 0:
		var active := eff_manager.get_active()
		for eff_name in active:
			var eff : StatusEffect.Effect = active[eff_name]
			lines.append(["text", "%s  x%d  %.1fs" % [eff.name, eff.stacks, eff.time_remaining], C_EFFECT])
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
			"section": h += LINE_H
			"row"    : h += LINE_H
			"bar"    : h += (LINE_H - 4.0) + BAR_H + 6.0
			"text"   : h += LINE_H
			"toggle" : h += LINE_H
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


# Called: _input() on toggle row click.
func _toggle_debug(key: String) -> void:

	if not debug_overlay:
		return
	match key:
		"dbg_player_attack":
			_dbg_player_attack                      = not _dbg_player_attack
			debug_overlay.show_player_attack_area   = _dbg_player_attack
		"dbg_cre_col":
			_dbg_creature_col                  = not _dbg_creature_col
			debug_overlay.show_creature_col    = _dbg_creature_col
		"dbg_ply_col":
			_dbg_player_col                    = not _dbg_player_col
			debug_overlay.show_player_col      = _dbg_player_col
		"dbg_obs_col":
			_dbg_obstacle_col                  = not _dbg_obstacle_col
			debug_overlay.show_obstacle_col    = _dbg_obstacle_col
		"dbg_prop_z":
			_dbg_prop_z                        = not _dbg_prop_z
			debug_overlay.show_prop_z_score    = _dbg_prop_z
		"dbg_grid":
			_dbg_tile_grid                     = not _dbg_tile_grid
			debug_overlay.show_tile_grid       = _dbg_tile_grid
		"dbg_pf_grid":
			_dbg_pf_grid                       = not _dbg_pf_grid
			debug_overlay.show_pf_grid         = _dbg_pf_grid
		"dbg_pf_grid2":
			_dbg_pf_grid2                      = not _dbg_pf_grid2
			debug_overlay.show_pf_grid2        = _dbg_pf_grid2
		"dbg_cre_paths":
			_dbg_cre_paths                     = not _dbg_cre_paths
			debug_overlay.show_cre_paths       = _dbg_cre_paths
		"dbg_home_markers":
			_dbg_home_markers                  = not _dbg_home_markers
			debug_overlay.show_home_markers    = _dbg_home_markers
		"dbg_cre_attack_dist":
			_dbg_cre_attack_dist               = not _dbg_cre_attack_dist
			debug_overlay.show_cre_attack_dist = _dbg_cre_attack_dist
		"dbg_cre_notice_dist":
			_dbg_cre_notice_dist               = not _dbg_cre_notice_dist
			debug_overlay.show_cre_notice_dist = _dbg_cre_notice_dist
		"dbg_cre_notice_dir":
			_dbg_cre_notice_dir                = not _dbg_cre_notice_dir
			debug_overlay.show_cre_notice_dir  = _dbg_cre_notice_dir
		"dbg_cre_chase_dist":
			_dbg_cre_chase_dist                = not _dbg_cre_chase_dist
			debug_overlay.show_cre_chase_dist  = _dbg_cre_chase_dist
		"dbg_cre_home_max":
			_dbg_cre_home_max                  = not _dbg_cre_home_max
			debug_overlay.show_cre_home_max    = _dbg_cre_home_max
		"dbg_dyn_blockers":
			_dbg_dyn_blockers                  = not _dbg_dyn_blockers
			debug_overlay.show_dyn_blockers    = _dbg_dyn_blockers
		"dbg_temp_blocks":
			_dbg_temp_blocks                   = not _dbg_temp_blocks
			debug_overlay.show_temp_blocks     = _dbg_temp_blocks
	debug_overlay.queue_redraw()
