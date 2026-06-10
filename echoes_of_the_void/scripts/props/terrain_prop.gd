class_name TerrainProp
extends DamageableProp

# =============================================================================
# TERRAIN PROP — grass and other walkable terrain overlays.
# No static collision. Wobble animation when player walks through. Cut state on hit.
# Canvas padding: thin PNGs need bottom rows added so the sprite sits on the ground.
# =============================================================================


func _ready() -> void:
	states         = ["idle_alive", "idle_dead"]
	_reaction_anim = "wobble"
	_area_radius   = float(cols) * TILE_SIZE * 0.5 * PIXEL_SIZE
	# Thin-prop canvas padding (matches old project formula):
	#   blit_y = TILE_SIZE/4 − (cols−1)  →  8, 7, 6 for 1×1, 2×1, 3×1
	#   empty_bottom = TILE_SIZE/2 − blit_y  →  8, 9, 10
	_idle_blit_y = TILE_SIZE / 4 - (cols - 1)
	super._ready()


func _on_death_finished() -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(states[1]):
		sprite.animation = states[1]
		sprite.frame     = 0
