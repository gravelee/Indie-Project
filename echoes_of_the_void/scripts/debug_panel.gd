extends Node2D

# =============================================================================
# DEBUG PANEL — replaces the simple target frame.
#
# Creature panel: top-left. Always mirrors player._target.
#   Always-visible: name + resource bars with int current/max.
#   Collapsible: STATS / STATE / AI
#
# Player panel: top-right. P key toggles + pauses game.
#   Always-visible: resource bars.
#   Collapsible: STATS / STATE / ABILITIES
#
# Built programmatically in main.gd:
#   var dp := Node2D.new()
#   canvas.add_child(dp)
#   dp.set_script(load("res://scripts/debug_panel.gd"))
#   dp.call("init", player_body)
# =============================================================================

# ── Layout ────────────────────────────────────────────────────────────────────
const PANEL_W    : float = 260.0
const PADDING    : float = 10.0
const LINE_H     : float = 18.0
const SECTION_H  : float = 18.0
const BAR_H      : float = 8.0
const TITLE_SIZE : int   = 15
const FONT_SIZE  : int   = 13
const SEC_GAP    : float = 6.0

const CREATURE_X           : float = 8.0
const CREATURE_Y           : float = 8.0
const CREATURE_CLICK_RADIUS : float = 52.0   # screen-space px radius for creature selection

# ── Colors ────────────────────────────────────────────────────────────────────
const C_BG            : Color = Color(0.06, 0.06, 0.08, 0.88)
const C_BORDER        : Color = Color(0.30, 0.30, 0.38, 1.00)
const C_COMBAT_BORDER : Color = Color(0.65, 0.12, 0.12, 0.90)
const C_COMBAT_TINT   : Color = Color(0.30, 0.04, 0.04, 0.18)
const C_DIVIDER       : Color = Color(0.20, 0.20, 0.25, 1.00)
const C_SECTION_BG    : Color = Color(0.14, 0.14, 0.19, 0.70)
const C_LABEL         : Color = Color(0.55, 0.55, 0.63, 1.00)
const C_VALUE         : Color = Color(1.00, 1.00, 1.00, 1.00)
const C_TITLE         : Color = Color(0.78, 0.71, 0.39, 1.00)
const C_STATE         : Color = Color(0.39, 0.78, 0.47, 1.00)
const C_WARN          : Color = Color(0.86, 0.24, 0.24, 1.00)

const C_HP_HIGH : Color = Color(0.24, 0.78, 0.31, 1.00)
const C_HP_MID  : Color = Color(0.90, 0.78, 0.16, 1.00)
const C_HP_LOW  : Color = Color(0.86, 0.24, 0.24, 1.00)
const C_ENERGY  : Color = Color(0.87, 0.80, 0.13, 1.00)
const C_FOCUS   : Color = Color(0.87, 0.53, 0.13, 1.00)
const C_FLOW    : Color = Color(0.13, 0.40, 0.87, 1.00)
const C_BAR_BG  : Color = Color(0.12, 0.12, 0.16, 1.00)

# ── State ─────────────────────────────────────────────────────────────────────
var _player      : CharacterBody3D = null
var _player_open : bool            = false
var _font        : Font            = null

# Collapse state — keyed by full prefixed key e.g. "c_stats", "p_state".
var _collapsed     : Dictionary = {}
# Click rects for section headers — rebuilt each _draw().
var _section_rects : Dictionary = {}
# Script → enum dict cache so get_script_constant_map() isn't called every frame.
var _enum_cache    : Dictionary = {}
# Rect of the creature panel (updated each draw) — used for click-outside detection.
var _creature_panel_rect : Rect2 = Rect2()
# Tracks whether a target existed last frame — ensures one final redraw on clear.
var _had_target : bool = false


# =============================================================================
# INIT
# =============================================================================

func init(p_player: CharacterBody3D) -> void:
	_player      = p_player
	_font        = ThemeDB.fallback_font
	process_mode = Node.PROCESS_MODE_ALWAYS   # P key works while paused


# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	# ── Keyboard ──────────────────────────────────────────────────────────────
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_player_open      = not _player_open
			get_tree().paused = _player_open
			queue_redraw()
			return
		# Tab cycles creatures even while paused (panel has PROCESS_MODE_ALWAYS).
		# Mark handled so player._unhandled_input doesn't call _try_tab_target a second time.
		if event.keycode == KEY_TAB and _player != null:
			_player.call("_try_tab_target")
			get_viewport().set_input_as_handled()
			queue_redraw()
			return

	# ── Mouse click ───────────────────────────────────────────────────────────
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		var click : Vector2 = event.position

		# Section header collapse toggles — highest priority
		for key : String in _section_rects:
			if _section_rects[key].has_point(click):
				_collapsed[key] = not _collapsed.get(key, false)
				queue_redraw()
				return

		# Creature click detection via world→screen projection
		var camera : Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
		if camera != null and _player != null:
			var best_node   : Node  = null
			var best_dist   : float = CREATURE_CLICK_RADIUS

			for node : Node in get_tree().get_nodes_in_group("creatures"):
				if not is_instance_valid(node):
					continue
				var body : Node3D = node as Node3D
				if body == null:
					continue
				var screen_pos : Vector2 = camera.unproject_position(body.global_position)
				var dist       : float   = click.distance_to(screen_pos)
				if dist < best_dist:
					best_dist = dist
					best_node = node

			if best_node != null:
				# Toggle: clicking the already-targeted creature clears it.
				# Mark handled so player._unhandled_input's raycast doesn't override us.
				var cur_tgt : Node = _player.get("_target")
				if cur_tgt == best_node:
					_player.call("_clear_target")
				else:
					_player.call("_set_target", best_node)
				get_viewport().set_input_as_handled()
				queue_redraw()
				return

		# Click outside the creature panel (and not on any creature) → clear target.
		# Mark handled so player._unhandled_input doesn't double-clear or re-target.
		if _player != null:
			var has_panel : bool = _creature_panel_rect.size.x > 0.0
			if has_panel and not _creature_panel_rect.has_point(click):
				_player.call("_clear_target")
				get_viewport().set_input_as_handled()
				queue_redraw()


# =============================================================================
# LOOP
# =============================================================================

func _process(_delta: float) -> void:
	var tgt        : Node = _player.get("_target") if _player != null else null
	var has_target : bool = tgt != null
	if has_target or _player_open or has_target != _had_target:
		queue_redraw()
	_had_target = has_target


func _draw() -> void:
	_section_rects.clear()
	_creature_panel_rect = Rect2()

	var tgt : Node = _player.get("_target") if _player != null else null
	if tgt != null and is_instance_valid(tgt):
		var lines : Array = _build_lines(tgt, "c_")
		var h     : float = _calc_height(lines)
		_creature_panel_rect = Rect2(CREATURE_X, CREATURE_Y, PANEL_W, h)
		_draw_panel(tgt, CREATURE_X, CREATURE_Y, "c_")

	if _player_open and _player != null:
		var px : float = 1920.0 - PANEL_W - 8.0
		_draw_panel(_player, px, 8.0, "p_")


# =============================================================================
# PANEL DRAW
# =============================================================================

func _draw_panel(entity: Node, px: float, py: float, prefix: String) -> void:
	var lines    : Array = _build_lines(entity, prefix)
	var h        : float = _calc_height(lines)
	var in_cbt   : bool  = entity.get("in_combat") == true

	# Background
	draw_rect(Rect2(px, py, PANEL_W, h), C_BG)
	if in_cbt:
		draw_rect(Rect2(px, py, PANEL_W, h), C_COMBAT_TINT)
	draw_rect(Rect2(px, py, PANEL_W, h),
		C_COMBAT_BORDER if in_cbt else C_BORDER, false, 1.0)

	var cy : float = py + PADDING
	var iw : float = PANEL_W - PADDING * 2.0

	for item : Array in lines:
		var kind : String = item[0]
		match kind:

			"title":
				draw_string(_font,
					Vector2(px + PADDING, cy + float(TITLE_SIZE)),
					item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, C_TITLE)
				cy += float(TITLE_SIZE) + 4.0

			"divider":
				draw_line(
					Vector2(px + PADDING,           cy + 3.0),
					Vector2(px + PANEL_W - PADDING, cy + 3.0),
					C_DIVIDER, 1.0)
				cy += SEC_GAP

			"row":
				var lbl   : String = item[1]
				var val   : String = str(item[2])
				var color : Color  = item[3] if item.size() > 3 else C_VALUE
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					lbl, HORIZONTAL_ALIGNMENT_LEFT, iw * 0.58, FONT_SIZE, C_LABEL)
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					val, HORIZONTAL_ALIGNMENT_RIGHT, iw, FONT_SIZE, color)
				cy += LINE_H

			"bar":
				var lbl   : String = item[1]
				var pct   : float  = item[2]
				var color : Color  = item[3]
				var cur   : int    = item[4]
				var mx    : int    = item[5]
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					lbl, HORIZONTAL_ALIGNMENT_LEFT, iw * 0.50, FONT_SIZE, C_LABEL)
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					str(cur) + "/" + str(mx),
					HORIZONTAL_ALIGNMENT_RIGHT, iw, FONT_SIZE, C_VALUE)
				cy += LINE_H - 4.0
				var bx : float = px + PADDING
				var bw : float = iw
				draw_rect(Rect2(bx, cy, bw, BAR_H), C_BAR_BG)
				var fw : float = maxf(0.0, bw * clampf(pct, 0.0, 1.0))
				if fw > 0.0:
					draw_rect(Rect2(bx, cy, fw, BAR_H), color)
				cy += BAR_H + 6.0

			"section":
				var full_key : String = prefix + item[2]
				draw_rect(Rect2(px + 1.0, cy, PANEL_W - 2.0, SECTION_H), C_SECTION_BG)
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					item[1], HORIZONTAL_ALIGNMENT_LEFT, iw, FONT_SIZE, C_TITLE)
				_section_rects[full_key] = Rect2(px, cy, PANEL_W, SECTION_H)
				cy += SECTION_H


# =============================================================================
# LINE BUILDERS
# =============================================================================

func _build_lines(entity: Node, prefix: String) -> Array:
	var is_creature : bool = prefix == "c_"
	if is_creature:
		return _build_creature_lines(entity)
	return _build_player_lines()


func _build_creature_lines(tgt: Node) -> Array:
	var lines : Array = []
	var s     : Stats = tgt.get("stats") as Stats
	if s == null:
		return lines

	var ctype   : String = str(tgt.get("type")) if "type" in tgt else "?"
	var is_dead : bool   = tgt.get("is_dead") == true
	lines.append(["title",
		"%s  Lv%d%s" % [ctype.capitalize(), s.level, "  [DEAD]" if is_dead else ""]])
	lines.append(["divider"])

	# Resource bars — always visible (pct truncated to int so bar matches displayed number)
	var hp_pct  : float = float(int(s.hp))     / float(s.hp_max)
	var en_pct  : float = float(int(s.energy)) / float(s.energy_max)
	lines.append(["bar", "HP",     hp_pct, _hp_color(hp_pct), int(s.hp),     s.hp_max])
	lines.append(["bar", "Energy", en_pct, C_ENERGY,          int(s.energy), s.energy_max])
	if s.focus_max > 0:
		var fo_pct : float = float(int(s.focus)) / float(s.focus_max)
		lines.append(["bar", "Focus", fo_pct, C_FOCUS, int(s.focus), s.focus_max])
	if s.flow_max > 0:
		var fl_pct : float = float(int(s.flow)) / float(s.flow_max)
		lines.append(["bar", "Flow", fl_pct, C_FLOW, int(s.flow), s.flow_max])
	lines.append(["divider"])

	# ── STATS ────────────────────────────────────────────────────────────────
	var sc : bool = _collapsed.get("c_stats", false)
	lines.append(["section", ("▶" if sc else "▼") + " STATS", "stats"])
	if not sc:
		lines.append(["row", "STR",       str(s.str_)])
		lines.append(["row", "AGI",       str(s.agi)])
		lines.append(["row", "STA",       str(s.sta)])
		lines.append(["row", "INT",       str(s.int_)])
		lines.append(["row", "SPR",       str(s.spr)])
		lines.append(["row", "RES",       str(s.res)])
		lines.append(["row", "DEF",       str(s.def_)])
		lines.append(["divider"])
		lines.append(["row", "PATK",      "%.1f" % s.patk])
		lines.append(["row", "PDEF",      "%.1f" % s.pdef])
		lines.append(["row", "MDEF",      "%.1f" % s.mdef])
		lines.append(["row", "CRIT",      "%.1f%%" % s.crit])
		lines.append(["row", "DODGE",     "%.1f%%" % s.dodge])
		lines.append(["row", "BLOCK",     "%.1f%%" % s.block])
		lines.append(["row", "MSPD",      "%.2f" % s.mspd])
		lines.append(["row", "FOCUS MAX", str(s.focus_max)])
		lines.append(["divider"])

	# ── STATE ─────────────────────────────────────────────────────────────────
	var stc : bool = _collapsed.get("c_state", false)
	lines.append(["section", ("▶" if stc else "▼") + " STATE", "state"])
	if not stc:
		lines.append(["row", "STATE",
			_get_enum_name(tgt, "State", int(tgt.get("state"))), C_STATE])
		var ic : bool = tgt.get("in_combat") == true
		lines.append(["row", "IN COMBAT",
			"yes" if ic else "no", C_WARN if ic else C_LABEL])
		lines.append(["row", "AGGRESSION",
			str(tgt.get("aggression_type"))])
		lines.append(["row", "VOID TOUCH",
			"yes" if tgt.get("void_touched") == true else "no"])
		lines.append(["divider"])

	# ── AI ────────────────────────────────────────────────────────────────────
	var aic : bool = _collapsed.get("c_ai", false)
	lines.append(["section", ("▶" if aic else "▼") + " AI", "ai"])
	if not aic:
		lines.append(["row", "HAS HOME",
			"yes" if tgt.get("has_home") == true else "no"])
		var wan_t : float   = tgt.get("_wander_timer")  if tgt.get("_wander_timer")  != null else 0.0
		var kb    : Vector3 = tgt.get("_knockback_vel") if tgt.get("_knockback_vel") != null else Vector3.ZERO
		var pd    : bool    = tgt.get("_pending_death") == true
		lines.append(["row", "WAN TIMER",  "%.2f" % wan_t])
		lines.append(["row", "KNOCKBACK",  "%.2f" % kb.length()])
		lines.append(["row", "PEND DEATH",
			"yes" if pd else "no", C_WARN if pd else C_LABEL])
		# Per-ability cooldowns
		var abilities : Array = tgt.get("_creature_abilities")
		if abilities != null:
			for ab : Ability in abilities:
				var cd_txt : String = "Ready" if ab.is_ready else "%.1fs" % ab._timer
				lines.append(["row", ab.display_name, cd_txt,
					C_STATE if ab.is_ready else C_WARN])
		lines.append(["divider"])

	return lines


func _build_player_lines() -> Array:
	var lines : Array = []
	if _player == null:
		return lines
	var s : Stats = _player.get("stats") as Stats
	if s == null:
		return lines

	lines.append(["title", "Ares  Lv%d" % s.level])
	lines.append(["divider"])

	# Resource bars — always visible (pct truncated to int so bar matches displayed number)
	var hp_pct : float = float(int(s.hp))     / float(s.hp_max)
	var en_pct : float = float(int(s.energy)) / float(s.energy_max)
	var fo_pct : float = float(int(s.focus))  / float(s.focus_max)
	lines.append(["bar", "HP",     hp_pct, _hp_color(hp_pct), int(s.hp),     s.hp_max])
	lines.append(["bar", "Energy", en_pct, C_ENERGY,          int(s.energy), s.energy_max])
	lines.append(["bar", "Focus",  fo_pct, C_FOCUS,           int(s.focus),  s.focus_max])
	if s.flow_max > 0:
		var fl_pct : float = float(int(s.flow)) / float(s.flow_max)
		lines.append(["bar", "Flow", fl_pct, C_FLOW, int(s.flow), s.flow_max])
	lines.append(["divider"])

	# ── STATS ────────────────────────────────────────────────────────────────
	var sc : bool = _collapsed.get("p_stats", false)
	lines.append(["section", ("▶" if sc else "▼") + " STATS", "stats"])
	if not sc:
		lines.append(["row", "STR",       str(s.str_)])
		lines.append(["row", "AGI",       str(s.agi)])
		lines.append(["row", "STA",       str(s.sta)])
		lines.append(["row", "INT",       str(s.int_)])
		lines.append(["row", "SPR",       str(s.spr)])
		lines.append(["row", "RES",       str(s.res)])
		lines.append(["row", "DEF",       str(s.def_)])
		lines.append(["divider"])
		lines.append(["row", "PATK",      "%.1f" % s.patk])
		lines.append(["row", "PDEF",      "%.1f" % s.pdef])
		lines.append(["row", "MDEF",      "%.1f" % s.mdef])
		lines.append(["row", "CRIT",      "%.1f%%" % s.crit])
		lines.append(["row", "DODGE",     "%.1f%%" % s.dodge])
		lines.append(["row", "BLOCK",     "%.1f%%" % s.block])
		lines.append(["row", "MSPD",      "%.2f" % s.mspd])
		lines.append(["row", "FOCUS MAX", str(s.focus_max)])
		var bonus : float = (s.focus_damage_mult() - 1.0) * 100.0
		lines.append(["row", "FOCUS DMG",
			"+%.1f%%" % bonus, C_FOCUS if bonus > 0.0 else C_LABEL])
		lines.append(["divider"])

	# ── STATE ─────────────────────────────────────────────────────────────────
	var stc : bool = _collapsed.get("p_state", false)
	lines.append(["section", ("▶" if stc else "▼") + " STATE", "state"])
	if not stc:
		lines.append(["row", "STATE",
			_get_enum_name(_player, "State", int(_player.get("state"))), C_STATE])
		lines.append(["row", "FACING",
			_get_enum_name(_player, "Facing", int(_player.get("facing")))])
		var ct  : float = _player.get("_combat_timer")     if _player.get("_combat_timer")     != null else 0.0
		var rt  : float = _player.get("_regen_timer")      if _player.get("_regen_timer")      != null else 0.0
		var rea : float = _player.get("_run_energy_accum") if _player.get("_run_energy_accum") != null else 0.0
		lines.append(["row", "COMBAT TMR",
			"%.2f" % ct, C_WARN if ct > 0.0 else C_LABEL])
		lines.append(["row", "REGEN TMR",
			"%.2f" % rt, C_WARN if rt > 0.0 else C_LABEL])
		lines.append(["row", "RUN ACCUM", "%.2f" % rea])
		lines.append(["divider"])

	# ── ABILITIES ─────────────────────────────────────────────────────────────
	var abc : bool = _collapsed.get("p_ab", false)
	lines.append(["section", ("▶" if abc else "▼") + " ABILITIES", "ab"])
	if not abc:
		lines.append(["row", "GCD",
			"Ready" if s.gcd_timer <= 0.0 else "%.2f" % s.gcd_timer,
			C_STATE if s.gcd_timer <= 0.0 else C_LABEL])
		lines.append(["divider"])
		var ability_bar : Array = _player.get("ability_bar")
		if ability_bar != null:
			for i : int in range(mini(ability_bar.size(), 10)):
				var ab : Ability = ability_bar[i] as Ability
				if ab == null:
					continue
				var key_str : String = str((i + 1) % 10)
				var cd_txt  : String = "Ready" if ab.is_ready else "%.1fs" % ab._timer
				lines.append(["row",
					"[%s] %s" % [key_str, ab.display_name],
					cd_txt,
					C_STATE if ab.is_ready else C_LABEL])
		lines.append(["divider"])

	return lines


# =============================================================================
# HELPERS
# =============================================================================

func _calc_height(lines: Array) -> float:
	var h : float = PADDING * 2.0
	for item : Array in lines:
		match item[0]:
			"title"  : h += float(TITLE_SIZE) + 4.0
			"divider": h += SEC_GAP
			"section": h += SECTION_H
			"row"    : h += LINE_H
			"bar"    : h += (LINE_H - 4.0) + BAR_H + 6.0
	return h


func _hp_color(pct: float) -> Color:
	if pct > 0.60:   return C_HP_HIGH
	elif pct > 0.25: return C_HP_MID
	else:            return C_HP_LOW


func _get_enum_name(entity: Node, enum_name: String, value: int) -> String:
	# Returns the string name of an enum value from entity's script.
	# Uses a per-script cache so get_script_constant_map() isn't called every frame.
	var script : Script = entity.get_script()
	if script == null:
		return str(value)
	if not _enum_cache.has(script):
		_enum_cache[script] = script.get_script_constant_map()
	var consts : Dictionary = _enum_cache[script]
	var enum_dict : Dictionary = consts.get(enum_name, {}) as Dictionary
	var key : Variant = enum_dict.find_key(value)
	return str(key) if key != null else str(value)
