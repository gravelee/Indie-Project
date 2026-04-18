class_name Stats
extends RefCounted


# ── Weights ────────────────────────────────────────────────────────────────────

const W_STR         := 1.0
const W_AGI         := 1.0
const W_STA         := 1.0
const W_INT         := 1.0
const W_SPR         := 1.0
const W_RES         := 1.0
const W_DEF         := 1.0
const LEVEL_DIVISOR := 7


# ── Regen rates (per second, out of combat) ────────────────────────────────────

const HP_REGEN     := 1.0
const ENERGY_REGEN := 1.0
const RAGE_DECAY   := 1.0
const MP_REGEN     := 1.0


# ── Global cooldown ────────────────────────────────────────────────────────────

const GCD := 1.0


# ── Rank table ─────────────────────────────────────────────────────────────────

# Lifetime experience -> [Grade, Title].
const RANKS : Array = [                                                                                     
	  [1250000000, "SSS", "Kami"],                                                                            
	  [250000000,  "SS",  "Legend"],                                                                          
	  [50000000,   "S",   "Master"],                                                                          
	  [12000000,   "A++", "Elite"],
	  [3000000,    "A+",  "Champion"],                                                                        
	  [900000,     "A",   "General"],
	  [300000,     "B+",  "Captain"],                                                                         
	  [150000,     "B",   "Hunter"],
	  [72000,      "C+",  "Scout"],                                                                           
	  [24000,      "C",   "Apprentice"],                                                                      
	  [8000,       "D+",  "Recruit"],
	  [2000,       "D",   "Wanderer"],                                                                        
	  [500,        "E",   "Novice"],                                                                          
	  [0,          "None","Unranked"]
  ]                                   

# ── Base stats ─────────────────────────────────────────────────────────────────

var str_ : int
var agi  : int
var sta  : int
var int_ : int
var spr  : int
var res  : int
var def_ : int
var bms  : int
var exp  : int


# ── Resources (current values) ────────────────────────────────────────────────

var hp           : float
var energy       : float 
var rage         : float
var mp           : float
var lifetime_exp : int


# ── Derived stats (recalculated whenever base stats change) ───────────────────

var level      : int
var hp_max     : int
var energy_max : int
var rage_max   : int
var mp_max     : int
var patk       : float
var matk       : float
var pdef       : float
var mdef       : float
var crit       : float
var mcrit      : float
var dodge      : float
var block      : float
var resist     : float
var mspd       : float


# ── Internal ──────────────────────────────────────────────────────────────────

var exp_multiplier  : float = 1.0
var upgrade_history : Array = []
var effects   		: StatusEffect.EffectManager	# init creature.configure(), player.init_combat().
var stunned			: bool = false
var silenced		: bool = false
var frozen			: bool = false
var modified_stats 	: Dictionary = { "str_" : false, "agi" : false, "sta" : false,
	"int_" : false, "spr" : false, "res" : false, "def_" : false, "bms" : false,
	"hp_max" : false, "energy_max" : false, "rage_max" : false, "mp_max" : false,
	"patk" : false, "matk" : false, "pdef" : false, "mdef" : false, "crit" : false,
	"mcrit" : false, "dodge" : false, "block" : false, "resist" : false, "mspd" : false}
var gcd_timer       : float  = 0.0

# =============================================================================
# INIT
# =============================================================================

# Called: game._load_json() (player), creature.configure() (creatures).
func _init(_str: int, _agi: int, _sta: int, _int: int,
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

	hp     = hp_max
	energy = energy_max
	rage   = 0
	mp     = mp_max


# =============================================================================
# DERIVED STAT FORMULAS
# =============================================================================

# Called: _init(), upgrade_stat().
func _recalculate_all() -> void:

	level      = _calc_level()
	energy_max = 10 + level
	hp_max     = 20 + (sta * 2) + (level * 2)
	rage_max   = 10 + level
	mp_max     = (spr * 2) + (level * 2)
	
	patk       = (str_ * 3) + (level * 2)
	matk       = (int_ * 3) + (level * 2)
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

# Called creature._physics_process(), player._physics_process().
func update_effects(dt: float) -> float:
	
	gcd_timer -= dt
	effects.update(dt)
	for effect_name in effects.expired_names:
		cleanse_effect(effect_name)
	return effects.total_damage[0]


# Called: creature._physics_process(), player._physics_process().
func regen(dt: float) -> void:

	# Regenerates HP, energy and mana, decays rage. Only called when out of combat.
	energy = minf(energy_max, energy + ENERGY_REGEN * dt)
	hp     = minf(hp_max,     hp     + HP_REGEN     * dt)
	rage   = maxf(0.0,        rage   - RAGE_DECAY   * dt)
	mp     = minf(mp_max,     mp     + MP_REGEN     * dt)


# Called: creature.take_damage(), player.take_damage().
func take_damage(raw_damage: float, dot: bool = false, is_magic: bool = false, is_crit: bool = false) -> float:

	var actual : float = 0.0
	
	if dot:
		actual = raw_damage
	else:
		var defense : float = mdef if is_magic else pdef
		var minimum : float = 2.0  if is_crit  else 1.0
		actual = floor(maxf(minimum, raw_damage - defense) + 0.4999)
		
	hp = maxf(0.0, hp - actual)
	return actual
	
	
# Called ability.use().
func apply_effect(effect_name: String) -> void:
	
	if effects.apply(effect_name):
		var effect : StatusEffect.Effect = effects._active[effect_name]
		if effect.type == "modifier":
			# An effect already modifies that stat.
			var target_stat = effect.stat
			if modified_stats[target_stat]:
				var already_applied_effect : StatusEffect.Effect = null
				for eff_name in effects._active:
					var e : StatusEffect.Effect = effects._active[eff_name]
					if e.stat == target_stat and e.original_value != 0.0:
						already_applied_effect = e
						break
				# If new modifier is stronger do apply.
				if effect.modifier < already_applied_effect.modifier:
					var target_stat_original_value = already_applied_effect.original_value
					already_applied_effect.original_value = 0.0
					effect.original_value = target_stat_original_value
					set(target_stat, target_stat_original_value * effect.modifier)
			# Apply the only effect that modifies target stat.
			else:
				var target_stat_value = get(target_stat)
				effect.original_value = target_stat_value
				set(target_stat, target_stat_value * effect.modifier)
				modified_stats[target_stat] = true
		elif effect.type == "flag":
			# An effect already controls the flag.
			var target_flag = effect.flag
			if get(target_flag):
				var already_applied_effect : StatusEffect.Effect = null
				for eff_name in effects._active:
					var e : StatusEffect.Effect = effects._active[eff_name]
					if e.flag == target_flag and e.weak_flag == false:
						already_applied_effect = e
						break
				# If new flag duration is longer.
				if already_applied_effect.time_remaining < effect.duration:
					already_applied_effect.weak_flag = true
				else:
					effect.weak_flag = true
			# Apply the only effect that controls the flag.
			else:
				set(target_flag, true)
			


# Called: update_effects(), cleanse_all_effects().
func cleanse_effect(effect_name: String) -> void:
	
	var effect : StatusEffect.Effect = effects._active[effect_name]
	# Modifier effect with the strongest modifier gets removed.
	if effect.type == "modifier" and effect.original_value != 0.0:
		var target_stat = effect.stat
		var next_modifier_effect : StatusEffect.Effect = null
		var min_modifier = 1.0
		for eff_name in effects._active:
			var e : StatusEffect.Effect = effects._active[eff_name]
			if (e.stat == target_stat) and (e.modifier < min_modifier) and (e.original_value == 0.0): 
				next_modifier_effect = e
				min_modifier = e.modifier
				break
		# If no other effect with same modifier then remove.
		if next_modifier_effect == null:
			set(target_stat, effect.original_value)
			effect.original_value = 0.0
			modified_stats[target_stat] = false
		# An effect with the next lowest modifier found.
		else:
			next_modifier_effect.original_value = effect.original_value
			effect.original_value = 0.0
			set(target_stat, next_modifier_effect.original_value * next_modifier_effect.modifier)
	# The only flag type effect to be removed (longest duration).
	elif effect.type == "flag" and effect.weak_flag == false:
		set(effect.flag, false)
	
	effects.cleanse(effect_name)
	

# Called: creature._begin_death(), player._begin_death().
func cleanse_all_effects() -> void:
	
	for effect in effects._active.keys():
		cleanse_effect(effect)
	
	effects.cleanse_all()


# Called: ability.check_resources().
func check_resources(costs: Array [int]) -> bool:
	
	if gcd_timer > 0.0:
		return false
	
	var i : int = 0
	var count : int = 0
	var resources : Array[int] = [int(hp), int(energy), int(rage), int(mp)]
	for cost in costs:
		if cost <= resources[i]:
			count += 1
		i += 1
	# Check if all resources are found.
	return count == costs.size()
	
	
# Called: ability.use().
func spend_resources(costs: Array[int]) -> void:
	
	hp -= costs[0]
	energy -= costs[1]
	rage -= costs[2]
	mp -= costs[3]


# Called: upgrade_stat().
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
	

# Called: None.
func restore_resource(resource: String, amount: float) -> void:

	# Adds amount to the named resource, capped at its maximum.
	if amount <= 0.0:
		return
	match resource:
		"hp":     hp     = minf(hp_max,     hp     + amount)
		"energy": energy = minf(energy_max, energy + amount)
		"rage":   rage   = minf(rage_max,   rage   + amount)
		"mp":     mp     = minf(mp_max,     mp     + amount)


# Called: ability.use().
func gain_exp(amount: float) -> void:

	exp          += amount
	lifetime_exp += amount


# =============================================================================
# UPGRADES
# =============================================================================

# Called: None.
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

# Called: creature.take_damage(), player.take_damage().
func is_alive() -> bool:
	
	return hp > 0.0


# Called: stat_panel._build_lines(), hud._draw_creatire_bars(), hud._draw_player_bars().
func hp_pct() -> float:
	
	return hp / hp_max if hp_max > 0.0 else 0.0


# Called: stat_panel._build_lines(), hud._draw_creatire_bars(), hud._draw_player_bars().
func energy_pct() -> float:
	
	return energy / energy_max if energy_max > 0.0 else 0.0


# Called: stat_panel._build_lines(), hud._draw_creatire_bars(), hud._draw_player_bars().
func rage_pct() -> float:
	
	return rage / rage_max if rage_max > 0.0 else 0.0


# Called: stat_panel._build_lines(), hud._draw_creatire_bars(), hud._draw_player_bars().
func mp_pct() -> float:
	
	return mp / mp_max if mp_max > 0.0 else 0.0


# Called: combat_feedback._read_creatures().
func exp_reward() -> float:
	
	return level * exp_multiplier


# Called: stat panel._build_lines().
func rank_grade() -> String:
	
	for entry in RANKS:
		if lifetime_exp >= entry[0]:                                                                        
			return entry[1]
	return "None"	# Never happens.


# Called: stat panel._build_lines().
func rank_title() -> String:
	
	for entry in RANKS:
		if lifetime_exp >= entry[0]:
			return entry[2]
	return "Unranked"	# Never happens.
