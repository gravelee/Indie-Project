extends CanvasLayer

# =============================================================================
# HUD — resource bars (HP / Energy / Focus / Flow) + 10-slot ability hotbar.
# Built programmatically by main.gd via:
#   canvas.set_script(load("res://scripts/hud.gd"))
#   canvas.call("init", player_body)
#   canvas.call("refresh")   ← once per frame from main.gd._process()
# =============================================================================

# Player bar geometry (bottom-left, just above hotbar)
const BAR_W   : int = 200
const BAR_H   : int = 12
const BAR_PAD : int = 4      # gap between bars
const BAR_X   : int = 8
const BAR_Y   : int = 956    # 1028 - 4*(12+4) - 8

# Target frame geometry (top-left)
const TGT_X      : int = 8
const TGT_Y      : int = 8
const TGT_NAME_H : int = 14   # name label height
const TGT_BAR_W  : int = 200
const TGT_BAR_H  : int = 12
const TGT_PAD    : int = 4

# Hotbar geometry (bottom-center)
const SLOT_SIZE : int = 44
const SLOT_GAP  : int = 2
const HOTBAR_Y  : int = 1028  # 1080 - 44 - 8

# Resource bar colors
const COLOR_HP     : Color = Color(0.80, 0.13, 0.13)
const COLOR_ENERGY : Color = Color(0.87, 0.80, 0.13)
const COLOR_FOCUS  : Color = Color(0.87, 0.53, 0.13)
const COLOR_FLOW   : Color = Color(0.13, 0.40, 0.87)
const COLOR_BG     : Color = Color(0.10, 0.10, 0.10, 0.70)
const COLOR_CDIM   : Color = Color(0.00, 0.00, 0.00, 0.55)

# ---------------------------------------------------------------------------
var _player : CharacterBody3D

var _bar_fills   : Array[ColorRect] = []   # indexed [0]=HP [1]=Energy [2]=Focus [3]=Flow
var _slot_frames : Array[ColorRect] = []   # slot backgrounds (10)
var _slot_covers : Array[ColorRect] = []   # cooldown overlays (10)

# Target frame nodes
var _tgt_root      : Control          = null   # container — hidden when no target
var _tgt_name_lbl  : Label            = null
var _tgt_bar_bgs   : Array[ColorRect] = []     # bar backgrounds (up to 4)
var _tgt_bar_fills : Array[ColorRect] = []     # bar fills (up to 4)

# Dirty-check caches — player
var _last_hp     : float = -1.0
var _last_energy : float = -1.0
var _last_focus  : float = -1.0
var _last_flow   : float = -1.0
var _last_cdpct  : Array[float] = []

# Dirty-check caches — target
var _last_tgt          : Node    = null
var _last_tgt_hp       : float   = -1.0
var _last_tgt_energy   : float   = -1.0
var _last_tgt_focus    : float   = -1.0
var _last_tgt_flow     : float   = -1.0


# =============================================================================
# INIT
# =============================================================================

func init(p_player: CharacterBody3D) -> void:
	_player = p_player
	layer   = 1
	_build_bars()
	_build_hotbar()
	_build_target_frame()
	_last_cdpct.resize(10)
	_last_cdpct.fill(-1.0)


func _build_bars() -> void:
	var colors : Array[Color] = [COLOR_HP, COLOR_ENERGY, COLOR_FOCUS, COLOR_FLOW]
	for i : int in range(4):
		var y : int = BAR_Y + i * (BAR_H + BAR_PAD)
		var bg := ColorRect.new()
		bg.color    = COLOR_BG
		bg.position = Vector2(BAR_X, y)
		bg.size     = Vector2(BAR_W, BAR_H)
		add_child(bg)
		var fill := ColorRect.new()
		fill.color    = colors[i]
		fill.position = Vector2(BAR_X, y)
		fill.size     = Vector2(BAR_W, BAR_H)
		add_child(fill)
		_bar_fills.append(fill)


func _build_hotbar() -> void:
	var total_w : int = 10 * SLOT_SIZE + 9 * SLOT_GAP
	var start_x : int = (1920 - total_w) / 2
	for i : int in range(10):
		var x : int = start_x + i * (SLOT_SIZE + SLOT_GAP)
		# Background
		var bg := ColorRect.new()
		bg.color    = COLOR_BG
		bg.position = Vector2(x, HOTBAR_Y)
		bg.size     = Vector2(SLOT_SIZE, SLOT_SIZE)
		add_child(bg)
		_slot_frames.append(bg)
		# Key label
		var lbl := Label.new()
		lbl.text     = str((i + 1) % 10)   # "1"…"9" then "0"
		lbl.position = Vector2(3, 2)
		lbl.add_theme_font_size_override("font_size",  11)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		bg.add_child(lbl)
		# Cooldown overlay — fills from top when ability is on cooldown
		var cover := ColorRect.new()
		cover.color    = COLOR_CDIM
		cover.position = Vector2(x, HOTBAR_Y)
		cover.size     = Vector2(SLOT_SIZE, 0)
		cover.visible  = false
		add_child(cover)
		_slot_covers.append(cover)


func _build_target_frame() -> void:
	_tgt_root = Control.new()
	_tgt_root.position = Vector2(TGT_X, TGT_Y)
	_tgt_root.visible  = false
	add_child(_tgt_root)

	# Name label
	_tgt_name_lbl = Label.new()
	_tgt_name_lbl.position = Vector2(0, 0)
	_tgt_name_lbl.size     = Vector2(TGT_BAR_W, TGT_NAME_H)
	_tgt_name_lbl.add_theme_font_size_override("font_size", 11)
	_tgt_name_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	_tgt_root.add_child(_tgt_name_lbl)

	# 4 bar slots (HP / Energy / Focus / Flow) — all built, shown/hidden per target
	var colors : Array[Color] = [COLOR_HP, COLOR_ENERGY, COLOR_FOCUS, COLOR_FLOW]
	for i : int in range(4):
		var y : int = TGT_NAME_H + TGT_PAD + i * (TGT_BAR_H + TGT_PAD)
		var bg := ColorRect.new()
		bg.color    = COLOR_BG
		bg.position = Vector2(0, y)
		bg.size     = Vector2(TGT_BAR_W, TGT_BAR_H)
		_tgt_root.add_child(bg)
		_tgt_bar_bgs.append(bg)
		var fill := ColorRect.new()
		fill.color    = colors[i]
		fill.position = Vector2(0, y)
		fill.size     = Vector2(TGT_BAR_W, TGT_BAR_H)
		_tgt_root.add_child(fill)
		_tgt_bar_fills.append(fill)


# =============================================================================
# REFRESH — call once per frame from main.gd._process()
# =============================================================================

func refresh() -> void:
	if _player == null:
		return
	var s : Stats = _player.get("stats") as Stats
	if s == null:
		return

	# Resource bars — update only on whole-integer changes (no bar flicker during regen)
	if int(s.hp) != int(_last_hp):
		_last_hp = s.hp
		_bar_fills[0].size.x = BAR_W * clampf(float(int(s.hp)) / s.hp_max, 0.0, 1.0)
	if int(s.energy) != int(_last_energy):
		_last_energy = s.energy
		_bar_fills[1].size.x = BAR_W * clampf(float(int(s.energy)) / s.energy_max, 0.0, 1.0)
	if int(s.focus) != int(_last_focus):
		_last_focus = s.focus
		_bar_fills[2].size.x = BAR_W * clampf(float(int(s.focus)) / s.focus_max, 0.0, 1.0)
	if int(s.flow) != int(_last_flow):
		_last_flow = s.flow
		_bar_fills[3].size.x = BAR_W * clampf(float(int(s.flow)) / s.flow_max, 0.0, 1.0)

	# Hotbar cooldowns
	var ability_bar : Array = _player.get("ability_bar")
	for i : int in range(mini(ability_bar.size(), 10)):
		var ab : Ability = ability_bar[i] as Ability
		if ab == null:
			_slot_covers[i].visible = false
			continue
		var pct : float = ab.cooldown_pct
		if pct == _last_cdpct[i]:
			continue
		_last_cdpct[i] = pct
		var cover : ColorRect = _slot_covers[i]
		if pct >= 1.0:
			cover.visible = false
		else:
			cover.visible    = true
			cover.size.y     = SLOT_SIZE * (1.0 - pct)
			cover.position.y = float(HOTBAR_Y)

	_refresh_target()


func _refresh_target() -> void:
	var tgt : Node = _player.get("_target")

	# Show/hide frame and reset dirty cache when target changes
	if tgt != _last_tgt:
		_last_tgt        = tgt
		_last_tgt_hp     = -1.0
		_last_tgt_energy = -1.0
		_last_tgt_focus  = -1.0
		_last_tgt_flow   = -1.0
		_tgt_root.visible = tgt != null
		if tgt != null:
			# Capitalise first letter of creature type for display name
			var raw : String = tgt.get("type") if "type" in tgt else "?"
			_tgt_name_lbl.text = raw.capitalize()
			# Show only bars the creature actually has (max > 0)
			var ts : Stats = tgt.get("stats") as Stats
			_tgt_bar_bgs[0].visible   = true    # HP always shown
			_tgt_bar_fills[0].visible = true
			_tgt_bar_bgs[1].visible   = ts != null and ts.energy_max > 0
			_tgt_bar_fills[1].visible = ts != null and ts.energy_max > 0
			_tgt_bar_bgs[2].visible   = ts != null and ts.focus_max  > 0
			_tgt_bar_fills[2].visible = ts != null and ts.focus_max  > 0
			_tgt_bar_bgs[3].visible   = ts != null and ts.flow_max   > 0
			_tgt_bar_fills[3].visible = ts != null and ts.flow_max   > 0
		return

	if tgt == null:
		return

	# Update bars dirty-checked
	var ts : Stats = tgt.get("stats") as Stats
	if ts == null:
		return
	if int(ts.hp) != int(_last_tgt_hp):
		_last_tgt_hp = ts.hp
		_tgt_bar_fills[0].size.x = TGT_BAR_W * clampf(float(int(ts.hp)) / ts.hp_max, 0.0, 1.0)
	if ts.energy_max > 0 and int(ts.energy) != int(_last_tgt_energy):
		_last_tgt_energy = ts.energy
		_tgt_bar_fills[1].size.x = TGT_BAR_W * clampf(float(int(ts.energy)) / ts.energy_max, 0.0, 1.0)
	if ts.focus_max > 0 and int(ts.focus) != int(_last_tgt_focus):
		_last_tgt_focus = ts.focus
		_tgt_bar_fills[2].size.x = TGT_BAR_W * clampf(float(int(ts.focus)) / ts.focus_max, 0.0, 1.0)
	if ts.flow_max > 0 and int(ts.flow) != int(_last_tgt_flow):
		_last_tgt_flow = ts.flow
		_tgt_bar_fills[3].size.x = TGT_BAR_W * clampf(float(int(ts.flow)) / ts.flow_max, 0.0, 1.0)
