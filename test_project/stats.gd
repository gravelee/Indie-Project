class_name Stats
extends RefCounted


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Flat mspd added per point of AGI. Intentionally small — speed is primarily a bms stat.
# At 200 AGI the bonus is 1.0 world unit/s, so AGI never outpaces a direct bms investment.
const AGI_MSPD     : float = 0.005

# Crit chance added per point of AGI. 0.5% per point — 200 AGI = 100% crit rate.
# Lives here because it is a stat formula — ability.gd must not read raw stat fields directly.
const AGI_CRIT     : float = 0.005

# HP recovered per second while out of combat and regen is not gated.
const HP_REGEN     : float = 1.0

# Energy recovered per second while out of combat and not sprinting.
const ENERGY_REGEN : float = 1.0

# Focus lost per second while out of combat. Keeps focus from carrying over between pulls.
const FOCUS_DECAY  : float = 1.0

# Hard cap on focus. Abilities that cost focus gate on this via check_resources().
const FOCUS_MAX         : int   = 100

# Focus awarded to the attacker on a normal hit. Aggressive play builds focus steadily.
const FOCUS_GAIN_HIT    : int   = 1

# Focus awarded to the attacker on a crit. Double reward for landing a critical strike.
const FOCUS_GAIN_CRIT   : int   = 2

# Focus awarded to the defender on receiving a hit. Being in danger builds aggression.
const FOCUS_GAIN_RECEIVE : int  = 1

# Damage multiplier applied on a critical hit. 2.0 = double damage.
const CRIT_MULT         : float = 2.0

# Global cooldown in seconds — minimum time between any two ability uses.
# Not yet enforced in the test project; reserved for when the full ability system is wired.
const GCD               : float = 1.0


# ---------------------------------------------------------------------------
# Base stats — set on init, raised by upgrade_stat() (future leveling system).
# These are the raw inputs to _recalculate_all(). Never write derived values here.
# ---------------------------------------------------------------------------

# Physical strength. Primary driver of patk. Higher str_ = harder hits.
var str_ : int

# Agility. Contributes to pdef, crit chance, and a small flat bonus to mspd.
var agi  : int

# Stamina. Drives hp_max — the only stat that increases the HP pool.
var sta  : int

# Defense. Primary driver of pdef. Reduces incoming physical damage.
var def_ : int

# Base move speed. The flat movement speed value before AGI contribution.
# Fed into mspd via _recalculate_all(). Never read directly outside of that formula.
var bms  : int


# ---------------------------------------------------------------------------
# Resources — current values, fluctuate during gameplay.
# ---------------------------------------------------------------------------

# Current HP. Reduced by take_damage(), restored by regen(). Death at 0.
var hp     : float

# Current energy. Spent by abilities via spend_resources(), restored by regen().
# Also drained by sprinting and jumping.
var energy : float

# Current focus. Gained by landing hits (+1), crits (+2), receiving damage (+1),
# and passively +1 every 5s while in combat. Decays at FOCUS_DECAY per second
# out of combat. Starts at 0 — never pre-filled.
var focus  : float

# Accumulated experience points. Increased by gain_exp() on creature death.
# No exp_max yet — leveling system is Stage future. Tracked now so the value
# is available when HUD and leveling are added.
var exp         : float = 0.0

# Block chance [0.0–1.0]. Probability that an incoming hit is blocked while in
# shield stance. On success knockback is halved. Talent tree increases this value.
var block_chance : float = 0.5


# ---------------------------------------------------------------------------
# Derived stats — recalculated clean by _recalculate_all() whenever base stats change.
# Never write to these directly — always go through base stats + _recalculate_all().
# ---------------------------------------------------------------------------

# Character level. Derived from the sum of base stats. Feeds into hp_max, patk, etc.
var level      : int

# Maximum HP. Scales with sta and level. hp is capped at this value.
var hp_max     : int

# Maximum energy. Scales with level. energy is capped at this value.
var energy_max : int

# Maximum focus. Fixed at FOCUS_MAX for now — no stat scales it yet.
var focus_max  : int

# Physical attack power. Base damage input for calc_ability_damage(). ability.calc_damage() delegates here.
var patk       : float

# Physical defense. Subtracted from incoming damage in take_damage().
var pdef       : float

# Effective move speed in world units per second. Derived from bms + (agi * AGI_MSPD).
# AGI contribution is intentionally small — speed is primarily a bms stat.
var mspd       : float


# ---------------------------------------------------------------------------
# Stat modifiers — written by status effects, never touched by _recalculate_all().
# ---------------------------------------------------------------------------
# Design (implement at Stage 11 — status effects):
#
# Three-layer system:
#   Layer 1 — base stats   : str_, agi, sta, def_, bms  (set on init, raised by upgrade_stat())
#   Layer 2 — derived stats: patk, pdef, mspd, etc.     (recalculated clean by _recalculate_all())
#   Layer 3 — modifiers    : bonus + mult per stat       (never touched by _recalculate_all())
#
# Formula at read time: (derived_stat + X_bonus) * X_mult
#   flat first, then percent — so a -5 weaken + -20% slow on 20 patk = (20-5)*0.8 = 12.
#
# Stacking rule: bonuses sum, mults multiply.
#   two -20% slows = 0.8 * 0.8 = 0.64 (64% speed). Two -5 weakens = -10 flat.
#
# Apply: status effect adds its flat to X_bonus and its mult to X_mult.
# Cleanse: status effect subtracts its flat from X_bonus and divides its mult from X_mult.
# No original_value needed — math is reversible. Level up safe: _recalculate_all() never runs here.
#
# Fields to declare here at Stage 11 (one bonus+mult pair per modifiable stat):
#   var mspd_bonus       : float = 0.0  ;  var mspd_mult       : float = 1.0
#   var patk_bonus       : float = 0.0  ;  var patk_mult       : float = 1.0
#   var pdef_bonus       : float = 0.0  ;  var pdef_mult       : float = 1.0
#   var hp_max_bonus     : float = 0.0  ;  var hp_max_mult     : float = 1.0
#   var energy_max_bonus : float = 0.0  ;  var energy_max_mult : float = 1.0
#   var crit_bonus       : float = 0.0  ;  var crit_mult       : float = 1.0
#   var dodge_bonus      : float = 0.0  ;  var dodge_mult      : float = 1.0
#   (expand when magic stats — matk, mdef, mcrit, resist — are added)
#
# Helper methods to add at Stage 11 (one per modifiable stat):
#   func effective_mspd()   -> float: return (mspd   + mspd_bonus)   * mspd_mult
#   func effective_patk()   -> float: return (patk   + patk_bonus)   * patk_mult
#   func effective_pdef()   -> float: return (pdef   + pdef_bonus)   * pdef_mult
#   func effective_hp_max() -> float: return (hp_max + hp_max_bonus) * hp_max_mult
#   etc.
#
# Flag effects (stunned, silenced, frozen) — separate bools, longest duration wins:
#   var stunned  : bool = false
#   var silenced : bool = false
#   var frozen   : bool = false


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

# Counts down the global cooldown. Ability use is blocked while above zero.
var gcd_timer : float = 0.0

# Accumulates elapsed time during out-of-combat regen. Focus is reduced by one
# whole point per second — same pattern as sprint energy drain in player.gd.
var _focus_decay_accum : float = 0.0


# ===========================================================================
# INIT
# ===========================================================================

# Called: Stats.new().
# Sets all base stats, derives everything else, then fills resources to full.
func _init(_str: int, _agi: int, _sta: int, _def: int, _bms: int) -> void:

	str_ = _str
	agi  = _agi
	sta  = _sta
	def_ = _def
	bms  = _bms

	_recalculate_all()

	# Fill resources after recalc so hp_max and energy_max are already set.
	# Focus starts at 0 — it is earned in combat, never pre-filled.
	hp     = hp_max
	energy = energy_max
	focus  = 0.0


# ===========================================================================
# DERIVED STAT FORMULAS
# ===========================================================================

# Called: _init(), upgrade_stat() (future).
# Recomputes all derived stats from current base stats. Safe to call at any time —
# never touches modifiers, resources, or gcd_timer.
func _recalculate_all() -> void:

	# Level is the average of the four combat base stats (not bms).
	# Floor division means four 1s = level 1, four 5s = level 6, etc.
	level      = 1 + int((str_ + agi + sta + def_) / 4.0)

	hp_max     = 20 + (sta * 2) + (level * 2)
	energy_max = 10 + level
	focus_max  = FOCUS_MAX
	patk       = (str_ * 3.0) + (level * 2.0)
	pdef       = def_ + (agi  * 0.5)
	# AGI adds a tiny flat bonus on top of bms — meaningful at very high AGI only.
	mspd       = bms  + (agi  * AGI_MSPD)


# ===========================================================================
# TICK
# ===========================================================================

# Called: player._physics_process() every frame.
# Counts the GCD timer down. Nothing else — callers check gcd_timer > 0 directly.
func tick(dt: float) -> void:

	gcd_timer = maxf(0.0, gcd_timer - dt)


# ===========================================================================
# REGEN
# ===========================================================================

# Called: player._physics_process() when _regen_timer <= 0 and not sprinting.
# Restores HP and energy at flat per-second rates. Capped at their maximums.
# Also decays focus — both regen and focus decay share the same out-of-combat condition.
func regen(dt: float) -> void:

	hp     = minf(hp_max,     hp     + HP_REGEN     * dt)
	energy = minf(energy_max, energy + ENERGY_REGEN * dt)
	_focus_decay_accum += FOCUS_DECAY * dt
	if _focus_decay_accum >= FOCUS_DECAY:
		var ticks : int = int(_focus_decay_accum / FOCUS_DECAY)
		focus              = maxf(0.0, focus - float(ticks))
		_focus_decay_accum -= float(ticks) * FOCUS_DECAY


# ===========================================================================
# COMBAT
# ===========================================================================

# Called: ability.can_use() — gates ability activation.
# Returns true only if all three resource costs can be met simultaneously.
# All costs are checked before any are deducted — partial affordability is never accepted.
func check_resources(hp_cost: int, energy_cost: int, focus_cost: int) -> bool:

	if float(hp_cost)     > hp:     return false
	if float(energy_cost) > energy: return false
	if float(focus_cost)  > focus:  return false
	return true


# Called: ability.spend() — deducts resources after can_use() confirmed affordability.
func spend_resources(hp_cost: int, energy_cost: int, focus_cost: int) -> void:

	hp     = hp     - float(hp_cost)
	energy = energy - float(energy_cost)
	focus  = focus  - float(focus_cost)


# Called: ability.calc_damage().
# Rolls crit from AGI, applies damage multiplier, awards focus, returns final damage.
# All damage math and focus gain for offensive hits live here — never in ability.gd.
func calc_ability_damage(mult: float) -> float:

	var base    : float = patk * mult # patk = 0 means no damage.
	var is_crit : bool  = randf() < agi * AGI_CRIT
	if is_crit:
		base *= CRIT_MULT
		gain_focus(FOCUS_GAIN_CRIT)
		print("focus +", FOCUS_GAIN_CRIT, " (crit) — focus: ", int(focus), "/", focus_max)
	else:
		gain_focus(FOCUS_GAIN_HIT)
		print("focus +", FOCUS_GAIN_HIT, " (hit) — focus: ", int(focus), "/", focus_max)
	return base


# Called: calc_ability_damage(), gain_focus_on_receive(), player._physics_process() passive tick.
# Adds amount to focus, clamped to focus_max.
func gain_focus(amount: int) -> void:

	focus = minf(float(focus_max), floor(focus + float(amount) + 0.4999))


# Called: player.receive_hit().
# Awards +1 focus when the entity takes a hit — being in danger builds aggression.
func gain_focus_on_receive() -> void:

	gain_focus(FOCUS_GAIN_RECEIVE)
	print("focus +", FOCUS_GAIN_RECEIVE, " (received hit) — focus: ", int(focus), "/", focus_max)


# Called: ability.calc_damage() result passed in from player._attack_check() or creature.
# Subtracts pdef from raw damage, floors the result, and returns the actual damage dealt.
# Minimum damage is 1.0 — pdef can reduce a hit but never fully negate it.
# The + 0.4999 before floor() is a rounding trick: values >= X.5 round up, below round down,
# without using round() which would round X.5 up to X+1 (we want conservative rounding).
func take_damage(raw_damage: float) -> float:

	var actual : float = maxf(1.0, floor(raw_damage - pdef + 0.4999))
	hp = maxf(0.0, hp - actual)
	# Snap to exactly 0.0 if below 1 — avoids floating point values like 0.0001
	# being treated as alive by is_alive().
	if hp < 1.0:
		hp = 0.0
	return actual


# Called: player._attack_check() when a creature dies from the player's hit.
# Adds amount to the player's EXP total. No cap — leveling system is future.
func gain_exp(amount: float) -> void:

	exp += amount
	print("exp +", int(amount), " — total exp: ", int(exp))


# ===========================================================================
# READ-ONLY HELPERS
# ===========================================================================

# Called: player.gd, creature.gd, hud.gd.
# Returns true while the entity has at least 1 HP.
# Threshold is 1.0 rather than 0.0 because take_damage() snaps sub-1 HP to exactly 0.0 —
# any value between 0 and 1 would be a float artifact, not a real HP state.
func is_alive() -> bool:

	return hp >= 1.0


# Called: hud.gd (bar display).
# Returns HP as a 0.0–1.0 fraction for drawing the HP bar. Guards against divide-by-zero.
func hp_pct() -> float:

	return hp / float(hp_max) if hp_max > 0 else 0.0


# Called: hud.gd (bar display).
# Returns energy as a 0.0–1.0 fraction for drawing the energy bar. Guards against divide-by-zero.
func energy_pct() -> float:

	return energy / float(energy_max) if energy_max > 0 else 0.0


# Called: hud.gd (bar display).
# Returns focus as a 0.0–1.0 fraction for drawing the focus bar. Guards against divide-by-zero.
func focus_pct() -> float:

	return focus / float(focus_max) if focus_max > 0 else 0.0
