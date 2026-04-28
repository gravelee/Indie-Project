class_name ObstacleProp
extends DamageableProp


# =============================================================================
# SETUP
# =============================================================================

# Called: map._spawn_prop().
func _ready() -> void:

	states         = ["idle_alive"]
	_reaction_anim = "bump"
	_area_radius   = 11.0 * float(min(cols, rows)) + 0.1
	super._ready()


# =============================================================================
# ANIMATIONS
# =============================================================================

# Called: DamageableProp._on_animation_finished().
func _on_death_finished() -> void:

	queue_free()
