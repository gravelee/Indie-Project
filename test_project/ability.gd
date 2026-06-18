class_name Ability
extends RefCounted

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Data fields — all set by _init(), never left at a default.
# ---------------------------------------------------------------------------

# Unique string key matching the entry in Abilities._DATA (e.g. "punch").
var id          : String

# Multiplier applied to user.patk to get base damage. 1.0 = full patk, 0.8 = weaker hit.
var damage_mult : float

# Maximum raycast reach in world units (1 unit = 32px = 1 tile).
var range_      : float

# Seconds before this ability can be used again. Written to _timer on spend().
var cooldown    : float

# Animation frame index at which the hit is applied. Checked each tick by _attack_update().
var hit_frame   : int

# HP drained from the user when spend() is called. 0 = no HP cost.
var hp_cost     : int

# Energy drained from the user when spend() is called. can_use() gates on this before allowing use.
var energy_cost : int

# Focus drained from the user when spend() is called. 0 = no focus cost.
var focus_cost  : int

# Animation base name (e.g. "attack_unarmed"). Direction suffix appended by player/creature at play time.
var anim        : String


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

# Countdown timer in seconds. Ability is on cooldown while above zero.
var _timer : float = 0.0


# Computed property — true when _timer has reached zero (cooldown expired).
var is_ready : bool:
	
	get: return _timer <= 0.0


# ===========================================================================
# INIT
# ===========================================================================

# Called: Abilities.get_ability().
# Hard crash on any missing or malformed field — never fire a broken ability.
func _init(p_id: String, data: Dictionary) -> void:

	assert(p_id != "",                  "Ability._init: id cannot be empty")
	assert(data.has("damage_mult"),     "Ability._init: missing 'damage_mult' for '%s'" % p_id)
	assert(data.has("range_"),          "Ability._init: missing 'range_' for '%s'" % p_id)
	assert(data.has("cooldown"),        "Ability._init: missing 'cooldown' for '%s'" % p_id)
	assert(data.has("hit_frame"),       "Ability._init: missing 'hit_frame' for '%s'" % p_id)
	assert(data.has("hp_cost"),         "Ability._init: missing 'hp_cost' for '%s'" % p_id)
	assert(data.has("energy_cost"),     "Ability._init: missing 'energy_cost' for '%s'" % p_id)
	assert(data.has("focus_cost"),      "Ability._init: missing 'focus_cost' for '%s'" % p_id)
	assert(data.has("anim"),            "Ability._init: missing 'anim' for '%s'" % p_id)

	id          = p_id
	damage_mult = float(data["damage_mult"])
	range_      = float(data["range_"])
	cooldown    = float(data["cooldown"])
	hit_frame   = int(data["hit_frame"])
	hp_cost     = int(data["hp_cost"])
	energy_cost = int(data["energy_cost"])
	focus_cost  = int(data["focus_cost"])
	anim        = str(data["anim"])


# ===========================================================================
# TICK
# ===========================================================================

# Called: player._process(), creature._physics_process() every frame.
# Counts the cooldown timer down to zero. Nothing else — callers read is_ready.
func tick(dt: float) -> void:

	_timer = maxf(0.0, _timer - dt)


# ===========================================================================
# USE
# ===========================================================================

# Called: player.gd, creature.gd before triggering the ability.
# Returns false if on cooldown or the user cannot afford the energy cost.
func can_use(user: Stats) -> bool:

	if _timer > 0.0:
		return false
	return user.check_resources(hp_cost, energy_cost, focus_cost)


# Called: player.gd, creature.gd immediately after can_use() returns true.
# Deducts resources and starts the cooldown — committed, no refund.
func spend(user: Stats) -> void:

	user.spend_resources(hp_cost, energy_cost, focus_cost)
	_timer = cooldown


# Called: player.gd, creature.gd at hit_frame.
# Routes through stats.calc_ability_damage() — all damage math and focus gain live there.
func calc_damage(user: Stats) -> float:

	return user.calc_ability_damage(damage_mult)
