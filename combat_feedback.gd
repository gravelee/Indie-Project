extends Node2D

# =============================================================================
# COMBAT_FEEDBACK.GD
#
# Responsibilities:
#   - Spawn floating text (damage, dodge, block, resist, DoT, EXP, effect names)
#   - Draw all active floating numbers each frame via _draw()
#   - Read last_hit / dot_damage / expired_effects from player and creatures
#
# Drawn on a CanvasLayer so positions are in screen space.
# World positions are converted to screen space each frame before spawning.
#
# What this script does NOT do:
#   - Modify HP or stats  (Ability.use() and EffectManager do that)
# =============================================================================


# ── Layout / timing ───────────────────────────────────────────────────────────

const LIFETIME    := 1.2    # seconds before fully faded
const RISE_SPEED  := 40.0   # pixels per second upward
const DRIFT_SPEED := 14.0   # pixels per second sideways
const FONT_SIZE   := 18


# ── Colors ────────────────────────────────────────────────────────────────────

const COLOR_PHYSICAL := Color(1.00, 1.00, 1.00)
const COLOR_MAGIC    := Color(0.39, 0.63, 1.00)
const COLOR_CRIT     := Color(1.00, 0.25, 0.20)
const COLOR_DOT      := Color(1.00, 0.86, 0.20)
const COLOR_BLOCK    := Color(0.80, 0.80, 0.80)
const COLOR_DODGE    := Color(0.80, 0.80, 0.80)
const COLOR_RESIST   := Color(0.39, 0.63, 1.00)
const COLOR_EXP      := Color(0.51, 0.00, 0.86)
const COLOR_EFFECT   := Color(0.78, 0.71, 0.20)
const COLOR_FADE     := Color(0.63, 0.63, 0.63)


# ── Internal ──────────────────────────────────────────────────────────────────

var _numbers   : Array  = []   # Array[_FloatingNumber]
var _count     : int    = 0    # alternating drift direction index
var _font      : Font   = null # set _ready(); shared across all numbers

var _player      : CharacterBody2D   # set game._ready() via init().
var _creatures   : Array   = []      # set game._ready() via init(); Array[CharacterBody2D]
var _world_angle : float   = 0.0     # set game._process() via set_world_angle().
var _vp_center   : Vector2 = Vector2.ZERO   # set _ready(), _on_viewport_resized().


# =============================================================================
# SETUP
# =============================================================================

# INIT
func _ready() -> void:

	_font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


# Called: game._ready().
func init(p_player: CharacterBody2D, p_creatures: Array) -> void:

	_player    = p_player
	_creatures = p_creatures


# Called: game._process().
func set_world_angle(angle: float) -> void:

	_world_angle = angle

# Called: Node.get_viewport().size_changed signal emitted.
func _on_viewport_resized() -> void:

	_vp_center = get_viewport().get_visible_rect().size * 0.5


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP
func _process(delta: float) -> void:

	if not _player:
		return

	_read_player()
	_read_creatures()
	_update(delta)
	queue_redraw()


# Called: _process().
func _read_player() -> void:

	var total_damage  = _player.stats.effects.total_damage
	var expired_names = _player.stats.effects.expired_names

	# ── Damage results from player's last attack ─────────────────────────────
	for ability in _player.abilities:
		if ability.last_hit_verdict.is_empty():
			continue
		for i in range(ability.last_hit_verdict.size()):
			var r  : Dictionary      = ability.last_hit_verdict[i]
			var t  : CharacterBody2D = ability.last_hit_targets[i]
			var sp : Vector2         = _world_to_screen(t.position)
			_spawn_from_result(r, sp)
			if r.get("effect", "") != "":
				_spawn_text(_effect_label(r["effect"]), sp, COLOR_EFFECT)
		ability.last_hit_verdict.clear()
		ability.last_hit_targets.clear()

	# ── DoT ticks on player ──────────────────────────────────────────────────
	if total_damage[0] > 0.0:
		_spawn_dot(total_damage[0], _world_to_screen(_player.position))
		total_damage[0] = 0.0

	# ── Effect expiry text on player ─────────────────────────────────────────
	for eff_name in expired_names:
		_spawn_text(_effect_label(eff_name), _world_to_screen(_player.position), COLOR_FADE)
	expired_names.clear()


# Called: _process().
func _read_creatures() -> void:

	for creature in _creatures:
		
		var total_damage  = creature.stats.effects.total_damage
		var expired_names = creature.stats.effects.expired_names
		
		# ── Creature attack results — damage shown on the player ──────────────
		for ability in creature.abilities:
			if ability.last_hit_verdict.is_empty():
				continue
			for i in range(ability.last_hit_verdict.size()):
				var r  : Dictionary = ability.last_hit_verdict[i]
				var sp : Vector2    = _world_to_screen(_player.position)
				_spawn_from_result(r, sp)
				if r.get("effect", "") != "":
					_spawn_text(_effect_label(r["effect"]), sp, COLOR_EFFECT)
			ability.last_hit_verdict.clear()
			ability.last_hit_targets.clear()

		# ── EXP drop on creature death ────────────────────────────────────────
		if creature.state == creature.State.DEATH and not creature.has_meta("_exp_dropped"):
			creature.set_meta("_exp_dropped", true)
			var reward : float = creature.stats.exp_reward()
			if reward > 0.0:
				_spawn_exp(reward, _world_to_screen(creature.position))

		# ── DoT ticks on creature ─────────────────────────────────────────────
		if total_damage[0] > 0.0:
			_spawn_dot(total_damage[0], _world_to_screen(creature.position))
			total_damage[0] = 0.0

		# ── Effect expiry text on creature ────────────────────────────────────
		for eff_name in expired_names:
			_spawn_text(_effect_label(eff_name), _world_to_screen(creature.position), COLOR_FADE)
		expired_names.clear()


# Called: _process().
func _update(delta: float) -> void:

	for n in _numbers:
		n.elapsed  += delta
		n.world_y  -= RISE_SPEED  * delta
		n.world_x  += n.drift_dir * DRIFT_SPEED * delta

	_numbers = _numbers.filter(func(n): return n.elapsed < LIFETIME)


# Godot built-in — triggered by queue_redraw().
func _draw() -> void:

	for n in _numbers:
		var alpha : float = 1.0 - (n.elapsed / LIFETIME)
		var color : Color = Color(n.color.r, n.color.g, n.color.b, alpha)
		# Outline pass (black, slightly offset).
		var outline := Color(0, 0, 0, alpha * 0.8)
		for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(_font, Vector2(n.world_x, n.world_y) + offset, n.text,
						HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE, outline)
		draw_string(_font, Vector2(n.world_x, n.world_y), n.text,
					HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE, color)


# =============================================================================
# SPAWN HELPERS
# =============================================================================

# Called: _read_player(), _read_creatures().
func _spawn_from_result(result: Dictionary, screen_pos: Vector2) -> void:

	var hit_type : String = result.get("hit_type", "normal")
	var is_magic : bool   = result.get("is_magic", false)

	match hit_type:
		"resist": _spawn_text("RESIST", screen_pos, COLOR_RESIST)
		"dodge":  _spawn_text("DODGE",  screen_pos, COLOR_DODGE)
		"block":  _spawn_text("BLOCK",  screen_pos, COLOR_BLOCK)
		_:
			var dmg : float = result.get("damage", 0.0)
			if dmg <= 0.0:
				return
			if result.get("crit", false):
				_spawn_text(str(int(dmg)), screen_pos, COLOR_CRIT)
			elif is_magic:
				_spawn_text(str(int(dmg)), screen_pos, COLOR_MAGIC)
			else:
				_spawn_text(str(int(dmg)), screen_pos, COLOR_PHYSICAL)


# Called: _read_player(), _read_creatures().
func _spawn_dot(value: float, screen_pos: Vector2) -> void:

	_spawn_text(str(int(value)), screen_pos, COLOR_DOT)


# Called: _read_creatures().
func _spawn_exp(amount: float, screen_pos: Vector2) -> void:

	_spawn_text("EXP +" + str(int(amount)), screen_pos, COLOR_EXP)


# Called: all spawn helpers.
func _spawn_text(text: String, screen_pos: Vector2, color: Color) -> void:

	var n        = _FloatingNumber.new()
	n.text       = text
	n.world_x    = screen_pos.x
	n.world_y    = screen_pos.y - 40.0   # start 40 px above entity center
	n.color      = color
	n.elapsed    = 0.0
	n.drift_dir  = 1.0 if (_count % 2 == 0) else -1.0
	_numbers.append(n)
	_count += 1


# =============================================================================
# HELPERS
# =============================================================================

# Called: _read_player(), _read_creatures().
func _world_to_screen(world_pos: Vector2) -> Vector2:

	var delta : Vector2 = world_pos - _player.position
	return delta.rotated(deg_to_rad(_world_angle)) + _vp_center


# Called: _read_player(), _read_creatures().
func _effect_label(effect_name: String) -> String:

	# "ex rat_bite_bleed" → "Bleed"
	var parts := effect_name.split("_")
	if parts.size() > 0:
		return parts[-1].capitalize()
	return effect_name


# =============================================================================
# INNER CLASS
# =============================================================================

class _FloatingNumber:

	var text      : String
	var world_x   : float
	var world_y   : float
	var color     : Color
	var elapsed   : float
	var drift_dir : float
