class_name Creature
extends Entity


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Y height of the body origin above the ground plane.
# Body origin sits at the visual center of the rat's drawn pixels.
# Spawn position and sprite offset in main.gd and init() are derived from this value.
const BODY_ORIGIN_Y : float = 0.75


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
# Joins the "creatures" group so player._attack_check() can find it via group iteration.
func init() -> void:

	add_to_group("creatures")

	# hit_half_height = BODY_ORIGIN_Y — rat drawn sprite is ~1.5u, center at 0.75u.
	# Body origin is at center so hit_half_height equals the origin height above ground.
	hit_half_height = BODY_ORIGIN_Y

	# --- Collision ---
	# Body origin is at visual center (0.75u above ground) so local offset is 0.
	# Capsule sized to the drawn body: height=1.2, radius=0.3 — smaller than the
	# full 1.5u drawn area to avoid snagging on geometry above the rat's head.
	var col : CollisionShape3D = CollisionShape3D.new()
	var shp : CapsuleShape3D   = CapsuleShape3D.new()
	shp.radius   = 0.3
	shp.height   = 1.2
	col.shape    = shp
	col.position = Vector3(0.0, 0.0, 0.0)
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
	# Body origin is at 0.75u above ground (visual center). Sprite anchor is at
	# its frame center, so shift up by half the frame world height minus the body offset
	# to keep the sprite base on the ground: (32 * PIXEL_SIZE * 0.5) - 0.75 = 0.75.
	sprite.position.y     = 32.0 * PIXEL_SIZE * 0.5 - BODY_ORIGIN_Y
	sprite.sprite_frames  = _load_sprite_frames()
	sprite.play("idle_neutral")
	add_child(sprite)

	# --- Stats ---
	# STR=0 AGI=0 STA=20 DEF=0 BMS=0 — rat has HP to absorb hits but no movement or attack yet.
	stats = Stats.new(0, 0, 20, 0, 0)


# ===========================================================================
# COMBAT
# ===========================================================================

# Called: player._attack_check() when the player's attack reaches this creature.
# damage : raw damage value from ability.calc_damage().
# dir    : flat direction vector from player to this creature — reserved for knockback.
func receive_hit(damage: float, dir: Vector3) -> void:

	super.receive_hit(damage, dir)
	print("rat hit for ", _last_damage, " — hp: ", stats.hp, "/", stats.hp_max)
