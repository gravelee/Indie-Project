class_name Ability
extends RefCounted

var id          : String = ""
var damage_mult : float  = 1.0
var range_      : float  = 1.5
var cooldown    : float  = 1.0
var hit_frame   : int    = 1
var energy_cost : int    = 0

var _timer : float = 0.0


var is_ready : bool:
	
	get: return _timer <= 0.0


# Called: player._process() every frame.
func tick(dt: float) -> void:
	
	_timer = maxf(0.0, _timer - dt)


# Called: player.gd before using ability.
func can_use(user: Stats) -> bool:
	
	if _timer > 0.0:
		return false
	if float(energy_cost) > user.energy:
		return false
	return true


# Called: player.gd after can_use() == true.
func spend(user: Stats) -> void:
	
	user.energy -= float(energy_cost)
	_timer       = cooldown


# Called: player.gd at hit_frame.
func calc_damage(user: Stats) -> float:
	
	var actual  : float = maxf(1.0, user.patk * damage_mult)
	var is_crit : bool  = randf() < user.agi * 0.1
	if is_crit:
		actual *= 2.0
	return actual
