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
	# Thin-prop canvas padding.
	# idle: blit_y = TILE_SIZE/4 − (cols−1)  →  8, 7, 6 for 1×1, 2×1, 3×1
	# Gives empty_bottom = TILE_SIZE/2 − blit_y  →  8, 9, 10
	_idle_blit_y = TILE_SIZE / 4 - (cols - 1)
	super._ready()


# =============================================================================
# ANIMATIONS
# =============================================================================

# Called: DamageableProp._on_animation_finished().
func _on_death_finished() -> void:

	sprite.play(states[1])   # idle_dead — stays in world as cut grass.
