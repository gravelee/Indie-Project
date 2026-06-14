class_name Stats
extends RefCounted

# ---------------------------------------------------------------------------
# Regen rates (per second, out of combat)
# ---------------------------------------------------------------------------
const HP_REGEN     : float = 1.0
const ENERGY_REGEN : float = 1.0
const GCD          : float = 1.0

# ---------------------------------------------------------------------------
# Base stats
# ---------------------------------------------------------------------------
var str_ : int  # physical attack
var agi  : int  # move speed, dodge, crit, energy pool
var sta  : int  # HP pool
var def_ : int  # physical defense
var bms  : int  # base move speed

# ---------------------------------------------------------------------------
# Resources (current values)
# ---------------------------------------------------------------------------

var hp     : float
var energy : float

# ---------------------------------------------------------------------------
# Derived stats
# ---------------------------------------------------------------------------
var level      : int
var hp_max     : int
var energy_max : int
var patk       : float
var pdef       : float
var mspd       : float

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------
var gcd_timer : float = 0.0


# Called: Stats.new().
func _init(_str: int, _agi: int, _sta: int, _def: int, _bms: int) -> void:
	
	str_ = _str
	agi  = _agi
	sta  = _sta
	def_ = _def
	bms  = _bms
	
	_recalculate_all()
	
	hp     = hp_max
	energy = energy_max


# Called: _init(), upgrade_stat() (future).
func _recalculate_all() -> void:
	
	level      = 1 + int((str_ + agi + sta + def_) / 4.0)
	hp_max     = 20 + (sta * 2) + (level * 2)
	energy_max = 10 + level
	patk       = (str_ * 3.0) + (level * 2.0)
	pdef       = def_ + (agi  * 0.5)
	mspd       = bms  + (agi  * 0.005)


# Called: player._process() every frame.
func tick(dt: float) -> void:
	
	gcd_timer = maxf(0.0, gcd_timer - dt)


# Called: player._process() when out of combat.
func regen(dt: float) -> void:
	
	hp     = minf(hp_max,     hp     + HP_REGEN     * dt)
	energy = minf(energy_max, energy + ENERGY_REGEN * dt)


# Called: ability.gd after hit lands on target.
func take_damage(raw_damage: float) -> float:
	
	var actual : float = floor(maxf(1.0, raw_damage - pdef) + 0.4999)
	hp = maxf(0.0, hp - actual)
	if hp < 1.0:
		hp = 0.0
	return actual


# Called: player.gd, creature.gd, hud.gd.
func is_alive() -> bool:
	
	return hp >= 1.0


# Called: hud.gd (bar display).
func hp_pct() -> float:
	
	return hp / float(hp_max) if hp_max > 0 else 0.0


# Called: hud.gd (bar display).
func energy_pct() -> float:
	
	return energy / float(energy_max) if energy_max > 0 else 0.0
