class_name Stats
extends RefCounted

# =============================================================================
# STATS.GD
#
# Holds all base stats, derived stats, and resources for any entity
# (player or creature). Mirrors stats.py from the Python prototype.
#
# Usage:
#   var stats := Stats.new(str_, agi, sta, int_, spr, res, def_, is_player)
# =============================================================================


# ── Weights ────────────────────────────────────────────────────────────────────

const W_STR         := 1.0
const W_AGI         := 1.0
const W_STA         := 1.0
const W_INT         := 1.0
const W_SPR         := 1.0
const W_RES         := 1.0
const W_DEF         := 1.0
const LEVEL_DIVISOR := 7


# ── Speed floors ───────────────────────────────────────────────────────────────

const PLAYER_BASE_SPEED := 200.0
const BASE_SPEED        := 180.0


# ── Regen rates (per second, out of combat) ────────────────────────────────────

const HP_REGEN     := 1.0
const ENERGY_REGEN := 1.0
const RAGE_DECAY   := 1.0


# ── Global cooldown ────────────────────────────────────────────────────────────

const GCD := 1.0


# ── Rank table ─────────────────────────────────────────────────────────────────

const RANKS := [
	[0,          "None", "Unranked"],
	[500,        "E",    "Novice"],
	[2000,       "D",    "Wanderer"],
	[8000,       "D+",   "Recruit"],
	[24000,      "C",    "Apprentice"],
	[72000,      "C+",   "Scout"],
	[150000,     "B",    "Hunter"],
	[300000,     "B+",   "Captain"],
	[900000,     "A",    "General"],
	[3000000,    "A+",   "Champion"],
	[12000000,   "A++",  "Elite"],
	[50000000,   "S",    "Master"],
	[250000000,  "SS",   "Legend"],
	[1250000000, "SSS",  "Kami"],
]


# ── Base stats ─────────────────────────────────────────────────────────────────

var str_ : int
var agi  : int
var sta  : int
var int_ : int
var spr  : int
var res  : int
var def_ : int


# ── Resources (current values) ────────────────────────────────────────────────

var hp           : float = 0.0
var energy       : float = 0.0
var rage         : float = 0.0
var mp           : float = 0.0
var exp          : float = 0.0
var lifetime_exp : float = 0.0


# ── Derived stats (recalculated whenever base stats change) ───────────────────

var level      : int   = 1
var hp_max     : float = 0.0
var energy_max : float = 0.0
var rage_max   : float = 0.0
var mp_max     : float = 0.0
var patk       : float = 0.0
var matk       : float = 0.0
var pdef       : float = 0.0
var mdef       : float = 0.0
var crit       : float = 0.0
var mcrit      : float = 0.0
var dodge      : float = 0.0
var block      : float = 0.0
var resist     : float = 0.0
var mspd       : float = 0.0


# ── Internal ──────────────────────────────────────────────────────────────────

var bms             : float = BASE_SPEED
var exp_multiplier  : float = 1.0
var upgrade_history : Array = []


# =============================================================================
# INIT
# =============================================================================

# Called: game._load_json() (player), creature.configure() (creatures).
func _init(p_str: int, p_agi: int, p_sta: int, p_int: int,
		   p_spr: int, p_res: int, p_def: int,
		   is_player: bool = false) -> void:

	str_ = p_str
	agi  = p_agi
	sta  = p_sta
	int_ = p_int
	spr  = p_spr
	res  = p_res
	def_ = p_def

	bms = PLAYER_BASE_SPEED if is_player else BASE_SPEED

	_recalculate_all()

	# Fill resources to max on spawn.
	hp     = hp_max
	energy = energy_max
	rage   = 0.0
	mp     = mp_max


# =============================================================================
# DERIVED STAT FORMULAS
# =============================================================================

# Called: _init(), upgrade_stat().
func _recalculate_all() -> void:

	# Mirrors _recalculate_all() in stats.py.
	level      = _calc_level()
	energy_max = 10.0 + level
	hp_max     = 20.0 + (sta * 2) + (level * 2)
	rage_max   = 10.0 + level
	mp_max     = (spr * 2.0) + (level * 2)
	patk       = (str_ * 3.0) + (level * 2)
	matk       = (int_ * 3.0) + (level * 2)
	pdef       = def_ + (agi * 0.5)
	mdef       = res  + (spr * 0.5)
	crit       = agi  * 0.1
	mcrit      = spr  * 0.1
	dodge      = (agi * 0.1) + (sta * 0.1)
	block      = (def_ * 0.1) + (sta * 0.1)
	resist     = res  * 0.1
	mspd       = bms  + (agi * 0.5)


# Called: _recalculate_all().
func _calc_level() -> int:

	var weighted := (
		str_ * W_STR +
		agi  * W_AGI +
		sta  * W_STA +
		int_ * W_INT +
		spr  * W_SPR +
		res  * W_RES +
		def_ * W_DEF
	)
	return 1 + int(weighted / LEVEL_DIVISOR)


# =============================================================================
# RESOURCES
# =============================================================================

# Called: player._physics_process(), creature._physics_process().
func regen(dt: float) -> void:

	# Regenerates HP and energy, decays rage. Only called when out of combat.
	energy = minf(energy_max, energy + ENERGY_REGEN * dt)
	hp     = minf(hp_max,     hp     + HP_REGEN     * dt)
	rage   = maxf(0.0,        rage   - RAGE_DECAY   * dt)


# Called: creature.take_damage(); ability.use(), combat system (future).
func take_damage(raw_damage: float, is_magic: bool = false, is_crit: bool = false) -> float:

	# Returns the actual damage dealt after defense is applied.
	var defense : float = mdef if is_magic else pdef
	var minimum : float = 2.0  if is_crit  else 1.0
	var actual  : float = floor(maxf(minimum, raw_damage - defense) + 0.4999)
	hp = maxf(0.0, hp - actual)
	return actual


# Called: upgrade_stat(), combat system (future).
func spend_resource(resource: String, amount: float) -> bool:

	# Deducts amount from the named resource. Returns false if insufficient.
	match resource:
		"hp":     if hp     < amount: return false; hp     -= amount
		"energy": if energy < amount: return false; energy -= amount
		"rage":   if rage   < amount: return false; rage   -= amount
		"mp":     if mp     < amount: return false; mp     -= amount
		"exp":    if exp    < amount: return false; exp    -= amount
		_: return false
	return true


# Called: combat system.
func restore_resource(resource: String, amount: float) -> void:

	# Adds amount to the named resource, capped at its maximum.
	if amount <= 0.0:
		return
	match resource:
		"hp":     hp     = minf(hp_max,     hp     + amount)
		"energy": energy = minf(energy_max, energy + amount)
		"rage":   rage   = minf(rage_max,   rage   + amount)
		"mp":     mp     = minf(mp_max,     mp     + amount)


# Called: combat system (future).
func gain_exp(amount: float) -> void:

	exp          += amount
	lifetime_exp += amount


# =============================================================================
# UPGRADES
# =============================================================================

# Called: upgrade UI (future).
func upgrade_stat(stat_name: String, exp_cost: float = 0.0) -> bool:

	# Spends exp to raise one base stat by 1. The same stat cannot be upgraded
	# twice in a row (mirrors the Python cooldown rule).
	var valid := ["str_", "agi", "sta", "int_", "spr", "res", "def_"]
	if stat_name not in valid:
		return false

	var recent := upgrade_history.slice(upgrade_history.size() - 2)
	if stat_name in recent:
		return false

	if not spend_resource("exp", exp_cost):
		return false

	match stat_name:
		"str_": str_ += 1
		"agi":  agi  += 1
		"sta":  sta  += 1
		"int_": int_ += 1
		"spr":  spr  += 1
		"res":  res  += 1
		"def_": def_ += 1

	upgrade_history.append(stat_name)
	if upgrade_history.size() > 2:
		upgrade_history.pop_front()

	# Preserve current resources when maximums change.
	var old_hp     := hp
	var old_energy := energy
	var old_rage   := rage
	var old_mp     := mp
	_recalculate_all()
	hp     = minf(old_hp,     hp_max)
	energy = minf(old_energy, energy_max)
	rage   = minf(old_rage,   rage_max)
	mp     = minf(old_mp,     mp_max)

	return true


# =============================================================================
# READ-ONLY HELPERS
# =============================================================================

# Called: entity death check.
func is_alive() -> bool:
	return hp > 0.0

# Called: HUD.
func hp_pct() -> float:
	return hp / hp_max if hp_max > 0.0 else 0.0

# Called: HUD.
func energy_pct() -> float:
	return energy / energy_max if energy_max > 0.0 else 0.0

# Called: HUD.
func rage_pct() -> float:
	return rage / rage_max if rage_max > 0.0 else 0.0

# Called: HUD.
func mp_pct() -> float:
	return mp / mp_max if mp_max > 0.0 else 0.0

# Called: combat system (future).
func exp_reward() -> float:
	return maxf(1.0, level * exp_multiplier)

# Called: HUD, stat panel.
func rank_grade() -> String:
	var result := RANKS[0][1] as String
	for entry in RANKS:
		if lifetime_exp >= entry[0]:
			result = entry[1]
	return result

# Called: HUD, stat panel.
func rank_title() -> String:
	var result := RANKS[0][2] as String
	for entry in RANKS:
		if lifetime_exp >= entry[0]:
			result = entry[2]
	return result
