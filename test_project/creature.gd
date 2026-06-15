class_name Creature
extends CharacterBody3D

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Sprite-to-world scale. 1 tile = 32px = 1.0 world unit. Sprite is 96px = 3.0 world units.
# Shared contract with player — all entity sprites use the same pixel_size.
const PIXEL_SIZE : float = 3.0 / 32.0


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

# All creature stat values. Set in init() with creature-specific values.
var stats  : Stats

# The visual AnimatedSprite3D child. Handles animation playback.
var sprite : AnimatedSprite3D


# ===========================================================================
# SPRITE LOADING
# ===========================================================================

# Called: init().
# Builds the SpriteFrames resource for the rat from individual PNG files.
# Only idle_neutral/front is loaded — front faces south-east (toward the camera).
# flip_h gives south-west. Back and flipped back cover the two north diagonals.
# Only front is needed while the creature has no AI and never turns.
func _load_sprite_frames() -> SpriteFrames:

	var frames : SpriteFrames = SpriteFrames.new()
	var path   : String       = "res://assets/creatures/rat/frames/idle_neutral/front/"
	var count  : int          = 7

	frames.add_animation("idle_neutral")
	frames.set_animation_speed("idle_neutral", 8.0)
	for i : int in range(count):
		var tex : Texture2D = load(path + str(i) + ".png")
		frames.add_frame("idle_neutral", tex)

	return frames


# ===========================================================================
# INIT
# ===========================================================================

# Called: main._build_rat().
# Builds collision, sprite, and stats. Called after add_child() so the node is in the tree.
func init() -> void:

	# --- Collision ---
	# Capsule centered at y=1.0 so its base sits flush with the ground plane.
	var col : CollisionShape3D = CollisionShape3D.new()
	var shp : CapsuleShape3D   = CapsuleShape3D.new()
	shp.radius   = 0.4
	shp.height   = 1.8
	col.shape    = shp
	col.position = Vector3(0.0, 1.0, 0.0)
	add_child(col)

	# --- Sprite ---
	# BILLBOARD_FIXED_Y: sprite always faces camera on Y axis only — correct for
	# the angled overhead 3D view. Full billboard would break the isometric look.
	# ALPHA_CUT_DISABLED: prevents sprite A depth-prepass cutting holes in sprite B
	# when two sprites overlap. Required for all sprites in the scene.
	# TEXTURE_FILTER_NEAREST: prevents bilinear bleed at atlas frame edges.
	sprite                = AnimatedSprite3D.new()
	sprite.pixel_size     = PIXEL_SIZE
	sprite.billboard      = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut      = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Lift anchor to sprite vertical center so the sprite base sits on the ground.
	sprite.position.y     = 32.0 * PIXEL_SIZE * 0.5
	sprite.sprite_frames  = _load_sprite_frames()
	sprite.play("idle_neutral")
	add_child(sprite)

	# --- Stats ---
	# STR=0 AGI=0 STA=20 DEF=0 BMS=0 — rat has HP to absorb hits but no movement or attack yet.
	stats = Stats.new(0, 0, 20, 0, 0)


# ===========================================================================
# COMBAT
# ===========================================================================

# Called: player._attack_check() when the player's raycast hits this body.
# damage : raw damage value from ability.calc_damage().
# _dir   : flat direction vector from player to this creature — unused now, reserved for knockback.
func receive_hit(damage: float, _dir: Vector3) -> void:

	var actual : float = stats.take_damage(damage)
	print("rat hit for ", actual, " — hp: ", stats.hp, "/", stats.hp_max)
