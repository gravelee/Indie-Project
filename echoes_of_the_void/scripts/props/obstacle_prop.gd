class_name ObstacleProp
extends DamageableProp

# =============================================================================
# OBSTACLE PROP — bushes and other destructible blocking props.
# Solid collision. Bump animation when player presses against it. Destroyed on hit.
# =============================================================================


func _ready() -> void:
	states         = ["idle_alive"]
	_reaction_anim = "bump"
	_area_radius   = 11.0 * float(mini(cols, rows)) * PIXEL_SIZE + 0.05
	super._ready()


func _on_death_finished() -> void:
	queue_free()
