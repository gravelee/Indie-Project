extends CharacterBody3D

# =============================================================================
# PUSHABLE BLOCK — test prop for push/pull mechanic.
# Group: "pushable"
# Player drives movement in PUSH/PULL states (sets velocity + calls move_and_slide).
# When _driven = false, block handles gravity and friction on its own.
# =============================================================================

const GRAVITY  : float = -20.0
const FRICTION : float = 20.0

var half_size : float = 1.0   # half of the block's side length — set to match collision shape
var _driven   : bool  = false


func _physics_process(delta: float) -> void:
	if _driven:
		return   # player controls velocity and calls move_and_slide directly
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
	move_and_slide()
