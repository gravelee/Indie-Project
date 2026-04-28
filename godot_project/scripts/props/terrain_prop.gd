class_name TerrainProp
extends DamageableProp


# =============================================================================
# SETUP
# =============================================================================

# Called: map._spawn_prop().
func _ready() -> void:

	states         = ["idle_alive", "idle_dead"]
	_reaction_anim = "pass"
	_area_radius   = float(min(cols, rows)) * TILE_SIZE * 0.5
	super._ready()


# =============================================================================
# ANIMATIONS
# =============================================================================

# Called: DamageableProp._on_animation_finished().
func _on_death_finished() -> void:

	sprite.play(states[1])   # idle_dead — stays in world as cut grass.
