extends CharacterBody3D

# =============================================================================
# PUSHABLE — base script for all pushable objects.
# Group: "pushable"
#
# When _driven = true the player owns all movement — _physics_process returns
# early so there is no conflict. The player calls move_and_slide() directly on
# this body inside _do_push_movement() and _drive_pulled_block().
#
# When _driven = false the block handles its own gravity and friction.
#
# half_size is set by the builder to match the actual collision shape.
# Player reads it via block.get("half_size") to compute grab reach.
# =============================================================================

# Downward acceleration in world units/s² — matches player.gd GRAVITY.
const GRAVITY  : float = -20.0

# Deceleration in world units/s applied per second to XZ velocity when free.
const FRICTION : float = 20.0

# Set by the builder to match this object's collision shape (sphere radius,
# box half-side, etc). Player uses it to determine grab reach.
var half_size : float = 0.5

# Set to true by the player on grab entry, false on release.
# While true, _physics_process returns immediately — player drives all movement.
var _driven : bool = false


# Called: Godot engine (every physics frame).
# Skipped entirely when the player is driving — player owns velocity and move_and_slide.
# When free: apply gravity, decay XZ velocity via friction, then slide.
func _physics_process(delta: float) -> void:

	if _driven:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
	move_and_slide()
