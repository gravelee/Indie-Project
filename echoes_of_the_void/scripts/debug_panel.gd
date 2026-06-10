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

# ── Helper overlay (3D wireframe) ─────────────────────────────────────────────
const HELPER_RANGE_SQ   : float = 100.0   # 10u radius²
const HELPER_CIRCLE_SEGS : int  = 20
const C_HELPER_PLAYER   : Color = Color(0.30, 0.55, 1.00, 0.90)
const C_HELPER_HOSTILE  : Color = Color(1.00, 0.22, 0.22, 0.90)
const C_HELPER_NEUTRAL  : Color = Color(1.00, 0.88, 0.15, 0.90)
const C_HELPER_COL_PROP : Color = Color(0.22, 0.90, 0.38, 0.90)
const C_HELPER_BUMP     : Color = Color(1.00, 0.50, 0.10, 0.85)
const C_HELPER_PASS     : Color = Color(1.00, 0.90, 0.12, 0.75)
const C_HELPER_TREE     : Color = Color(0.15, 0.80, 0.80, 0.90)

# ── State ─────────────────────────────────────────────────────────────────────
var _player      : CharacterBody3D = null
var _player_open : bool            = false
var _font        : Font            = null

# Collapse state — keyed by full prefixed key e.g. "c_stats", "p_state".
var _collapsed     : Dictionary = {}
# Click rects for section headers — rebuilt each _draw().
var _section_rects : Dictionary = {}
# Click rects for option rows (helper toggles) — rebuilt each _draw().
var _option_rects  : Dictionary = {}
# Script → enum dict cache so get_script_constant_map() isn't called every frame.
var _enum_cache    : Dictionary = {}
# Rect of the creature panel (updated each draw) — used for click-outside detection.
var _creature_panel_rect : Rect2 = Rect2()
# Tracks whether a target existed last frame — ensures one final redraw on clear.
var _had_target : bool = false

# ── Helper overlay ─────────────────────────────────────────────────────────────
var _helper_col  : bool             = false   # show collision shapes
var _helper_int  : bool             = false   # show interact/detect areas
var _helper_tree : bool             = false   # show tree collision cylinders
var _helper_mesh : MeshInstance3D   = null


# =============================================================================
# INIT
# =============================================================================

func init(p_player: CharacterBody3D) -> void:
	_player      = p_player
	_font        = ThemeDB.fallback_font
	process_mode = Node.PROCESS_MODE_ALWAYS   # P key works while paused

	# 3D wireframe overlay for helper modes — added as sibling of player.
	# ImmediateMesh is created once here and reused each physics frame via
	# clear_surfaces() to avoid per-frame GPU buffer allocation churn.
	_helper_mesh = MeshInstance3D.new()
	_helper_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var im := ImmediateMesh.new()
	_helper_mesh.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test              = true
	mat.vertex_color_use_as_albedo = true
	_helper_mesh.material_override = mat
	if _player != null and _player.get_parent() != null:
		_player.get_parent().add_child(_helper_mesh)


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

		# Helper option row toggles
		for key : String in _option_rects:
			if _option_rects[key].has_point(click):
				match key:
					"p_h_col":  _helper_col  = not _helper_col
					"p_h_int":  _helper_int  = not _helper_int
					"p_h_tree": _helper_tree = not _helper_tree
				# Surfaces are cleared by _physics_process when all helpers are off.
				# Never null the mesh — _update_helper_mesh() casts it to ImmediateMesh
				# and returns early if null, making helpers impossible to re-enable.
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
	var tgt        : Node = _get_target()
	var has_target : bool = tgt != null
	if has_target or _player_open or has_target != _had_target:
		queue_redraw()
	_had_target = has_target


# Helper mesh updates at physics rate (fixed 60 hz) to avoid GPU buffer churn
# from rebuilding ImmediateMesh every display frame.
func _physics_process(_delta: float) -> void:
	if _helper_col or _helper_int or _helper_tree:
		_update_helper_mesh()
	elif _helper_mesh != null and is_instance_valid(_helper_mesh):
		var im : ImmediateMesh = _helper_mesh.mesh as ImmediateMesh
		if im != null:
			im.clear_surfaces()


func _get_target() -> Node:
	if _player == null:
		return null
	var raw : Variant = _player.get("_target")
	if raw == null or not is_instance_valid(raw):
		if raw != null:
			_player.call("_clear_target")
		return null
	return raw as Node


func _draw() -> void:
	_section_rects.clear()
	_option_rects.clear()
	_creature_panel_rect = Rect2()

	var tgt : Node = _get_target()
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

			"effect":
				# item: [kind, display_name, stacks, max_stacks, duration_pct, color, time_remaining]
				var ename   : String = item[1]
				var stacks  : int    = item[2]
				var max_s   : int    = item[3]
				var d_pct   : float  = item[4]
				var ecol    : Color  = item[5]
				var t_rem   : float  = item[6]
				var lbl_str : String = ename + ("  %dx" % stacks if max_s > 1 else "")
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					lbl_str, HORIZONTAL_ALIGNMENT_LEFT, iw * 0.65, FONT_SIZE, ecol)
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					"%.1fs" % t_rem, HORIZONTAL_ALIGNMENT_RIGHT, iw, FONT_SIZE, C_LABEL)
				cy += LINE_H - 4.0
				var ebx : float = px + PADDING
				var ebw : float = iw
				draw_rect(Rect2(ebx, cy, ebw, 4.0), C_BAR_BG)
				var efw : float = ebw * clampf(d_pct, 0.0, 1.0)
				if efw > 0.0:
					var bar_col : Color = ecol
					bar_col.a = 0.75
					draw_rect(Rect2(ebx, cy, efw, 4.0), bar_col)
				cy += 8.0

			"section":
				var full_key : String = prefix + item[2]
				draw_rect(Rect2(px + 1.0, cy, PANEL_W - 2.0, SECTION_H), C_SECTION_BG)
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					item[1], HORIZONTAL_ALIGNMENT_LEFT, iw, FONT_SIZE, C_TITLE)
				_section_rects[full_key] = Rect2(px, cy, PANEL_W, SECTION_H)
				cy += SECTION_H

			"option":
				# item: ["option", display_label, option_key, active_bool]
				var opt_lbl    : String = item[1]
				var opt_key    : String = item[2]
				var opt_active : bool   = item[3]
				var opt_bg     : Color  = Color(0.18, 0.52, 0.18, 0.30) if opt_active else Color(0.0, 0.0, 0.0, 0.0)
				draw_rect(Rect2(px + PADDING - 2.0, cy, iw + 4.0, LINE_H - 2.0), opt_bg)
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					opt_lbl, HORIZONTAL_ALIGNMENT_LEFT, iw * 0.75, FONT_SIZE, C_VALUE)
				draw_string(_font,
					Vector2(px + PADDING, cy + float(FONT_SIZE)),
					"ON" if opt_active else "OFF",
					HORIZONTAL_ALIGNMENT_RIGHT, iw, FONT_SIZE,
					C_STATE if opt_active else C_LABEL)
				_option_rects[opt_key] = Rect2(px + PADDING - 2.0, cy, iw + 4.0, LINE_H - 2.0)
				cy += LINE_H


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

	# Active status effects
	var c_effects : Dictionary = tgt.get("_effects") if "_effects" in tgt else {}
	if c_effects != null and not c_effects.is_empty():
		lines.append(["divider"])
		for eid : String in c_effects:
			var se : StatusEffect = c_effects[eid] as StatusEffect
			if se != null and not se.expired:
				lines.append(["effect",
					se.display_name, se.stacks, se.max_stacks,
					se.duration_pct(), se.color, se.time_remaining])
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

	# Active status effects
	var p_effects : Dictionary = _player.get("_effects") if "_effects" in _player else {}
	if p_effects != null and not p_effects.is_empty():
		lines.append(["divider"])
		for eid : String in p_effects:
			var se : StatusEffect = p_effects[eid] as StatusEffect
			if se != null and not se.expired:
				lines.append(["effect",
					se.display_name, se.stacks, se.max_stacks,
					se.duration_pct(), se.color, se.time_remaining])
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

	# ── HELPERS ───────────────────────────────────────────────────────────────
	var hc : bool = _collapsed.get("p_helpers", false)
	lines.append(["section", ("▶" if hc else "▼") + " HELPERS", "helpers"])
	if not hc:
		lines.append(["option", "Collisions (10u)",     "p_h_col",  _helper_col])
		lines.append(["option", "Interact Areas (10u)", "p_h_int",  _helper_int])
		lines.append(["option", "Trees (10u)",          "p_h_tree", _helper_tree])
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
			"option" : h += LINE_H
			"bar"    : h += (LINE_H - 4.0) + BAR_H + 6.0
			"effect" : h += (LINE_H - 4.0) + 8.0
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


# =============================================================================
# HELPER OVERLAY — 3D wireframe circles
# =============================================================================

func _update_helper_mesh() -> void:
	if _helper_mesh == null or not is_instance_valid(_helper_mesh) or _player == null:
		return
	var im : ImmediateMesh = _helper_mesh.mesh as ImmediateMesh
	if im == null:
		return
	im.clear_surfaces()
	var p_pos : Vector3 = _player.global_position
	im.surface_begin(Mesh.PRIMITIVE_LINES)

	if _helper_col:
		# Player — blue cylinder wireframe
		var p_r   : float = _get_entity_radius(_player)
		var p_top : float = p_pos.y + _get_entity_col_top(_player)
		_add_cylinder_wire(im, p_pos.x, p_pos.y, p_pos.z, p_r, p_top, C_HELPER_PLAYER)

		# Creatures — red (hostile) or yellow (neutral/other) cylinder wireframes
		for node : Node in get_tree().get_nodes_in_group("creatures"):
			if not is_instance_valid(node):
				continue
			var body : Node3D = node as Node3D
			if body == null:
				continue
			var diff : Vector3 = body.global_position - p_pos
			diff.y = 0.0
			if diff.length_squared() > HELPER_RANGE_SQ:
				continue
			var aggr_raw : Variant = node.get("aggression_type")
			var aggr_str : String  = str(aggr_raw).to_lower()
			var ent_col  : Color   = C_HELPER_HOSTILE if aggr_str.contains("hostile") else C_HELPER_NEUTRAL
			var c_r      : float   = _get_entity_radius(body)
			var c_top    : float   = body.global_position.y + _get_entity_col_top(body)
			_add_cylinder_wire(im, body.global_position.x, body.global_position.y,
				body.global_position.z, c_r, c_top, ent_col)

		# Collidable props — full-height cylinder + cone cap.
		# Mirrors obstacle_prop.gd: cylinder base-to-col_h (normal.y=0 sides),
		# cone cap apex at col_h, base at col_h - base_r * 1.3.
		for node : Node in get_tree().get_nodes_in_group("damageable_props"):
			if not is_instance_valid(node):
				continue
			if not node.get("has_collision"):
				continue
			var prop3d : Node3D = node as Node3D
			if prop3d == null:
				continue
			var diff2 : Vector3 = prop3d.global_position - p_pos
			diff2.y = 0.0
			if diff2.length_squared() > HELPER_RANGE_SQ:
				continue
			# base_r: _area_radius - 0.05 (detect zone is 0.05 wider than collision)
			var base_r   : float = maxf(float(node.get("_area_radius")) - 0.05, 0.1)
			var col_h    : float = float(node.get("_coll_height"))
			var base_y   : float = prop3d.global_position.y
			# Mirrors obstacle_prop.gd: cone_h = col_h * 0.9, base sits at col_h * 0.1.
			# Full-height cylinder
			_add_cylinder_wire(im, prop3d.global_position.x, base_y,
				prop3d.global_position.z, base_r, base_y + col_h, C_HELPER_COL_PROP)
			# Cone cap: base at col_h * 0.1, apex at col_h
			_add_cone_wire(im, prop3d.global_position.x, base_y + col_h * 0.1,
				prop3d.global_position.z, base_r, base_y + col_h, C_HELPER_COL_PROP)

	if _helper_int:
		# Non-collision damageable props — DetectZone sphere wireframe.
		# Sphere radius = area_radius * 0.8, center at y = radius above prop base.
		# "wobble" on obstacle props → orange; on terrain props → yellow.
		for node : Node in get_tree().get_nodes_in_group("damageable_props"):
			if not is_instance_valid(node):
				continue
			if node.get("has_collision"):
				continue
			var prop3d : Node3D = node as Node3D
			if prop3d == null:
				continue
			var diff3 : Vector3 = prop3d.global_position - p_pos
			diff3.y = 0.0
			if diff3.length_squared() > HELPER_RANGE_SQ:
				continue
			var detect_r : float  = float(node.get("_area_radius")) * 0.8
			var is_obstacle : bool = node is ObstacleProp
			var icol        : Color = C_HELPER_BUMP if is_obstacle else C_HELPER_PASS
			_add_sphere_wire(im, prop3d.global_position.x,
				prop3d.global_position.y + detect_r, prop3d.global_position.z,
				detect_r, icol)

	if _helper_tree:
		# Tree collision shapes — shared StaticBody3D ("TreeCollision" group).
		# Each tree contributes a CylinderShape3D + ConvexPolygonShape3D cone cap.
		# Cylinders drawn in teal; cone caps read their base_r from the hull points.
		var tree_body_arr : Array = get_tree().get_nodes_in_group("tree_collision_body")
		if not tree_body_arr.is_empty():
			var tree_body : Node3D = tree_body_arr[0] as Node3D
			if tree_body != null:
				for child : Node in tree_body.get_children():
					var cs : CollisionShape3D = child as CollisionShape3D
					if cs == null:
						continue
					var diff_t : Vector3 = cs.global_position - p_pos
					diff_t.y = 0.0
					if diff_t.length_squared() > HELPER_RANGE_SQ:
						continue
					var shape : Shape3D = cs.shape
					if shape is CylinderShape3D:
						var cyl    : CylinderShape3D = shape as CylinderShape3D
						var base_y : float = cs.global_position.y - cyl.height * 0.5
						var top_y  : float = cs.global_position.y + cyl.height * 0.5
						_add_cylinder_wire(im, cs.global_position.x, base_y,
							cs.global_position.z, cyl.radius, top_y, C_HELPER_TREE)
					elif shape is ConvexPolygonShape3D:
						# Cone cap — derive base_r and apex height from hull points.
						var cpoly  : ConvexPolygonShape3D = shape as ConvexPolygonShape3D
						var max_r  : float = 0.0
						var max_h  : float = 0.0
						for pt : Vector3 in cpoly.points:
							var pr : float = sqrt(pt.x * pt.x + pt.z * pt.z)
							if pr > max_r: max_r = pr
							if pt.y > max_h: max_h = pt.y
						var cap_base_y : float = cs.global_position.y
						_add_cone_wire(im, cs.global_position.x, cap_base_y,
							cs.global_position.z, max_r, cap_base_y + max_h, C_HELPER_TREE)

	im.surface_end()


# Full cylinder wireframe: bottom circle + top circle + 4 vertical struts.
func _add_cylinder_wire(im: ImmediateMesh, cx: float, y_bot: float, cz: float,
		r: float, y_top: float, col: Color) -> void:
	_add_circle_xz(im, cx, y_bot + 0.02, cz, r, col)
	_add_circle_xz(im, cx, y_top,        cz, r, col)
	# 4 cardinal vertical struts
	for i : int in range(4):
		var a  : float = float(i) * (PI * 0.5)
		var vx : float = cx + cos(a) * r
		var vz : float = cz + sin(a) * r
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(vx, y_bot + 0.02, vz))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(vx, y_top, vz))


# Cone wireframe: base circle at y_base + 8 struts running up to the apex.
func _add_cone_wire(im: ImmediateMesh, cx: float, y_base: float, cz: float,
		r: float, y_apex: float, col: Color) -> void:
	_add_circle_xz(im, cx, y_base + 0.02, cz, r, col)
	for i : int in range(8):
		var a  : float = float(i) * (PI * 0.25)
		var vx : float = cx + cos(a) * r
		var vz : float = cz + sin(a) * r
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(vx, y_base + 0.02, vz))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx, y_apex, cz))


# Sphere wireframe: horizontal equator + two vertical circles (XY and ZY planes).
func _add_sphere_wire(im: ImmediateMesh, cx: float, cy: float, cz: float,
		r: float, col: Color) -> void:
	var step : float = TAU / float(HELPER_CIRCLE_SEGS)
	for i : int in range(HELPER_CIRCLE_SEGS):
		var a0 : float = float(i) * step
		var a1 : float = float(i + 1) * step
		# Horizontal equator (XZ plane)
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx + cos(a0) * r, cy, cz + sin(a0) * r))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx + cos(a1) * r, cy, cz + sin(a1) * r))
		# Vertical circle in XY plane
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx + cos(a0) * r, cy + sin(a0) * r, cz))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx + cos(a1) * r, cy + sin(a1) * r, cz))
		# Vertical circle in ZY plane
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx, cy + sin(a0) * r, cz + cos(a0) * r))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx, cy + sin(a1) * r, cz + cos(a1) * r))


func _add_circle_xz(im: ImmediateMesh, cx: float, y: float, cz: float,
		r: float, col: Color) -> void:
	var step : float = TAU / float(HELPER_CIRCLE_SEGS)
	for i : int in range(HELPER_CIRCLE_SEGS):
		var a0 : float = float(i) * step
		var a1 : float = float(i + 1) * step
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx + cos(a0) * r, y, cz + sin(a0) * r))
		im.surface_set_color(col)
		im.surface_add_vertex(Vector3(cx + cos(a1) * r, y, cz + sin(a1) * r))


func _get_entity_radius(entity: Node3D) -> float:
	for child : Node in entity.get_children():
		if child is CollisionShape3D:
			var shape : Shape3D = (child as CollisionShape3D).shape
			if shape is CapsuleShape3D:
				return (shape as CapsuleShape3D).radius
			if shape is CylinderShape3D:
				return (shape as CylinderShape3D).radius
			if shape is SphereShape3D:
				return (shape as SphereShape3D).radius
			if shape is BoxShape3D:
				var bs : BoxShape3D = shape as BoxShape3D
				return maxf(bs.size.x, bs.size.z) * 0.5
	return 0.35


# Returns the world-space Y offset of the collision top above entity.global_position.y.
func _get_entity_col_top(entity: Node3D) -> float:
	for child : Node in entity.get_children():
		if child is CollisionShape3D:
			var cs    : CollisionShape3D = child as CollisionShape3D
			var shape : Shape3D          = cs.shape
			if shape is CapsuleShape3D:
				return cs.position.y + (shape as CapsuleShape3D).height * 0.5
			if shape is CylinderShape3D:
				return cs.position.y + (shape as CylinderShape3D).height * 0.5
			if shape is SphereShape3D:
				return cs.position.y + (shape as SphereShape3D).radius
	return 1.5
