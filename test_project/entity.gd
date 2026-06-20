class_name Entity
extends CharacterBody3D


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Pixel-to-world scale. 1 tile = 32px = 1.0 world unit.
# Single source of truth — all entity sprites use this value.
const PIXEL_SIZE         : float = 3.0 / 32.0

# Seconds the sprite tints red after taking a hit before tweening back to normal.
const HIT_FLASH_DURATION : float = 0.1


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

# The visual AnimatedSprite3D child. Set in each entity's init().
var sprite          : AnimatedSprite3D

# All stat values. Set in each entity's init().
var stats           : Stats

# Half the drawn sprite height in world units.
# Defines the Y window in which this entity can receive a hit:
#   attack connects when absf(attacker.y - self.y) <= hit_half_height.
# Set in each entity's init() to match its drawn pixel area.
var hit_half_height : float

# True once HP reaches zero. Read externally to stop targeting dead entities.
var is_dead         : bool = false

# Damage applied on the most recent receive_hit() call.
# Set by this class, read by child classes for their print statements —
# keeps take_damage() logic in one place without duplicating it.
var _last_damage    : float = 0.0


# ===========================================================================
# COMBAT
# ===========================================================================

# Called: child receive_hit() via super.receive_hit().
# Applies damage, awards focus, flashes the sprite, and marks the entity dead
# if HP reaches zero. Child classes must guard their own state-specific early
# returns (e.g. SPAWN) before calling super.
func receive_hit(damage: float, _dir: Vector3) -> void:

	if is_dead:
		return
	_last_damage = stats.take_damage(damage)
	stats.gain_focus_on_receive()
	_flash_sprite()
	if not stats.is_alive():
		is_dead = true


# Called: receive_hit().
# Snaps the sprite to a red tint then tweens it back to normal over HIT_FLASH_DURATION.
# Alpha is preserved from the current modulate so it does not fight active fade effects.
# Red tint instead of overbright white — GL Compatibility clamps modulate to [0,1]
# so Color(2,2,2) looks identical to Color(1,1,1) and the flash would be invisible.
func _flash_sprite() -> void:

	var a : float = sprite.modulate.a
	sprite.modulate = Color(1.0, 0.15, 0.15, a)
	var tween : Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, a), HIT_FLASH_DURATION)
