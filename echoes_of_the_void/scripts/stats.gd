class_name Stats
extends RefCounted

# =============================================================================
# STATS — all stat math for player and creatures.
# Pure data object (RefCounted, no node). Created via Stats.new(...).
#
# Resources:
#   HP     — health. 0 = faint (no permanent death).
#   Energy — universal action resource. Builds from AGI. Regens out of combat.
#   Focus  — adrenaline. Builds IN combat from landing/taking hits. Decays out.
#   Flow   — magic resource. Builds from SPR. Regens out of combat.
#
# Resource index order (for check_resources / spend_resources arrays):
#   [0] hp   [1] energy   [2] focus   [3] flow
# =============================================================================

# ---------------------------------------------------------------------------
# Weights — used by level formula
# ---------------------------------------------------------------------------
const W_STR         : float = 1.0
const W_AGI         : float = 1.0
const W_STA         : float = 1.0
const W_INT         : float = 1.0
const W_SPR         : float = 1.0
const W_RES         : float = 1.0
const W_DEF         : float = 1.0
const LEVEL_DIVISOR : int   = 7

# ---------------------------------------------------------------------------
# Regen / decay rates (per second, out of combat)
# ---------------------------------------------------------------------------
const HP_REGEN     : float = 1.0
const ENERGY_REGEN : float = 1.0
const FLOW_REGEN   : float = 1.0
const FOCUS_DECAY  : float = 1.0   # Focus falls when danger passes

# ---------------------------------------------------------------------------
# Global cooldown
# ---------------------------------------------------------------------------
const GCD : float = 1.0

# ---------------------------------------------------------------------------
# Base stats
# ---------------------------------------------------------------------------
var str_ : int   # physical attack, Focus generation
var agi  : int   # move speed, dodge, crit, energy pool
var sta  : int   # HP pool
var int_ : int   # magic attack
var spr  : int   # Flow pool, magic defense
var res  : int   # magic resistance
var def_ : int   # physical defense
var bms  : int   # base move speed offset
var exp  : int   # current spendable EXP

# ---------------------------------------------------------------------------
# Resources (current values)
# ---------------------------------------------------------------------------
var hp           : float
var energy       : float
var focus        : float   # was rage — adrenaline, builds in combat
var flow         : float   # was mana/mp — magic resource

var lifetime_exp : int

# ---------------------------------------------------------------------------
# Derived stats — recomputed via _recalculate_all() whenever base stats change
# ---------------------------------------------------------------------------
var level      : int
var hp_max     : int
var energy_max : int
var focus_max  : int
var flow_max   : int
var patk       : float
var matk       : float
var pdef       : float
var mdef       : float
var crit       : float
var mcrit      : float
var dodge      : float
var block      : float
var resist     : float
var mspd       : float   # move speed — used by player.gd / creature.gd

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------
var exp_multiplier  : float        = 1.0
var upgrade_history : Array[String] = []
var gcd_timer       : float        = 0.0


# =============================================================================
# INIT
# =============================================================================

func _init(
		_str: int, _agi: int, _sta: int, _int: int,
		_spr: int, _res: int, _def: int, _bms: int, _exp: int) -> void:
	str_ = _str
	agi  = _agi
	sta  = _sta
	int_ = _int
	spr  = _spr
	res  = _res
	def_ = _def
	bms  = _bms
	exp  = _exp
	lifetime_exp = exp

	_recalculate_all()

	# Resources start full, except Focus (zero until first combat)
	hp     = hp_max
	energy = energy_max
	flow   = flow_max
	focus  = 0.0


# =============================================================================
# DERIVED STAT FORMULAS
# =============================================================================

func _recalculate_all() -> void:
	level      = _calc_level()
	hp_max     = 20 + (sta * 2) + (level * 2)
	energy_max = 10 + level
	focus_max  = 50 + (str_ * 5)
	flow_max   = (spr * 2) + (level * 2)
	patk       = (str_ * 3.0) + (level * 2.0)
	matk       = (int_ * 3.0) + (level * 2.0)
	pdef       = def_ + (agi  * 0.5)
	mdef       = res  + (spr  * 0.5)
	crit       = agi  * 0.1
	mcrit      = spr  * 0.1
	dodge      = (agi  * 0.1) + (sta * 0.1)
	block      = (def_ * 0.1) + (sta * 0.1)
	resist     = res  * 0.1
	mspd       = bms  + (agi  * 0.005)   # 0.005 per agi ≈ 0.25% per point on bms=2 base


func _calc_level() -> int:
	var weighted : float = (
		str_ * W_STR + agi * W_AGI + sta * W_STA +
		int_ * W_INT + spr * W_SPR + res * W_RES + def_ * W_DEF
	)
	return 1 + int(weighted / float(LEVEL_DIVISOR))


# =============================================================================
# PER-FRAME UPDATES
# =============================================================================

func tick(dt: float) -> void:
	# Call every frame regardless of combat state.
	gcd_timer = maxf(0.0, gcd_timer - dt)


func regen(dt: float, decay_focus: bool = true) -> void:
	# Call when NOT in combat. Regens HP/Energy/Flow, decays Focus.
	# Pass decay_focus=false when retreating — adrenaline lingers mid-flight.
	hp     = minf(hp_max,     hp     + HP_REGEN     * dt)
	energy = minf(energy_max, energy + ENERGY_REGEN * dt)
	flow   = minf(flow_max,   flow   + FLOW_REGEN   * dt)
	if decay_focus:
		focus = maxf(0.0, focus - FOCUS_DECAY * dt)


# =============================================================================
# COMBAT
# =============================================================================

func take_damage(raw_damage: float, is_magic: bool = false, is_crit: bool = false) -> float:
	var defense : float = mdef if is_magic else pdef
	var minimum : float = 2.0  if is_crit  else 1.0
	var actual  : float = floor(maxf(minimum, raw_damage - defense) + 0.4999)
	hp = maxf(0.0, hp - actual)
	if hp < 1.0:
		hp = 0.0   # snap fractional remainder — displayed 0 must equal dead
	return actual


# =============================================================================
# RESOURCE MANAGEMENT
# Resource index order: [0] hp  [1] energy  [2] focus  [3] flow
# =============================================================================

func check_resources(costs: Array[int]) -> bool:
	# Returns false if GCD is active or any cost exceeds current resource.
	if gcd_timer > 0.0:
		return false
	var resources : Array[float] = [hp, energy, focus, flow]
	for i : int in range(costs.size()):
		if float(costs[i]) > resources[i]:
			return false
	return true


func spend_resources(costs: Array[int]) -> void:
	# Deducts all four resources at once and starts GCD.
	hp     -= float(costs[0])
	energy -= float(costs[1])
	focus  -= float(costs[2])
	flow   -= float(costs[3])
	gcd_timer = GCD


func spend_resource(resource: String, amount: float) -> bool:
	# Deducts a single named resource. Returns false if insufficient.
	match resource:
		"hp":     if hp     < amount: return false;  hp     -= amount
		"energy": if energy < amount: return false;  energy -= amount
		"focus":  if focus  < amount: return false;  focus  -= amount
		"flow":   if flow   < amount: return false;  flow   -= amount
		"exp":    if float(exp) < amount: return false;  exp -= int(amount)
		_: return false
	return true


func restore_resource(resource: String, amount: float) -> void:
	if amount <= 0.0:
		return
	match resource:
		"hp":     hp     = minf(hp_max,     hp     + amount)
		"energy": energy = minf(energy_max, energy + amount)
		"focus":  focus  = minf(focus_max,  focus  + amount)
		"flow":   flow   = minf(flow_max,   flow   + amount)


func gain_exp(amount: float) -> void:
	exp          += int(amount)
	lifetime_exp += int(amount)


# =============================================================================
# STAT UPGRADES
# =============================================================================

func upgrade_stat(stat_name: String, exp_cost: float = 0.0) -> bool:
	# Raises one base stat by 1, spending exp_cost EXP.
	# The same stat cannot appear in the last two upgrades (prevents spam).
	var valid : Array[String] = ["str_", "agi", "sta", "int_", "spr", "res", "def_"]
	if stat_name not in valid:
		return false

	var recent : Array = upgrade_history.slice(maxi(0, upgrade_history.size() - 2))
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

	# Preserve current resources when maximums change
	var old_hp     : float = hp
	var old_energy : float = energy
	var old_focus  : float = focus
	var old_flow   : float = flow
	_recalculate_all()
	hp     = minf(old_hp,     float(hp_max))
	energy = minf(old_energy, float(energy_max))
	focus  = minf(old_focus,  float(focus_max))
	flow   = minf(old_flow,   float(flow_max))

	return true


# =============================================================================
# FOCUS HELPERS
# =============================================================================

func gain_focus_on_hit(damage_dealt: float) -> void:
	# Called when player lands a hit. Formula: hp_max / damage_dealt
	if damage_dealt <= 0.0:
		return
	focus = minf(float(focus_max), focus + float(hp_max) / damage_dealt)


func gain_focus_on_receive(damage_taken: float) -> void:
	# Called when player takes a hit. Formula: hp_max / (damage_taken * 2)
	if damage_taken <= 0.0:
		return
	focus = minf(float(focus_max), focus + float(hp_max) / (damage_taken * 2.0))


func focus_damage_mult() -> float:
	# Passive bonus multiplier: focus/10 % bonus damage.
	# 100 focus → ×1.10, 50 focus → ×1.05, 0 focus → ×1.00
	return 1.0 + focus * 0.001


# =============================================================================
# READ-ONLY HELPERS
# =============================================================================

func is_alive() -> bool:
	return hp >= 1.0   # fractional hp < 1 = dead (matches int display)

func hp_pct()     -> float: return hp     / float(hp_max)     if hp_max     > 0 else 0.0
func energy_pct() -> float: return energy / float(energy_max) if energy_max > 0 else 0.0
func focus_pct()  -> float: return focus  / float(focus_max)  if focus_max  > 0 else 0.0
func flow_pct()   -> float: return flow   / float(flow_max)   if flow_max   > 0 else 0.0

func exp_reward() -> float:
	return float(level) * exp_multiplier
