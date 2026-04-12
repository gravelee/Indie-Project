extends CharacterBody2D

# =============================================================================
# PLAYER.GD
#
# Responsibilities:
#   - Read WASD input and move the physics body
#   - Keep movement direction relative to the camera angle
#     (so pressing W always moves "up on screen", not "north in the world")
#   - Play the correct walk/idle animation based on facing direction
#
# What this script does NOT do:
#   - Position the visual sprite  (game.gd does that)
#   - Rotate the visual sprite    (game.gd does that)
#   - Set z_index                 (game.gd does that)
# =============================================================================


# ── Settings ───────────────────────────────────────────────────────────────────

const SPEED := 200.0


# ── State ──────────────────────────────────────────────────────────────────────

var camera_angle : float  = 0.0     # set by game.gd every frame
var facing       : String = "south" # last direction the player faced


# ── References ─────────────────────────────────────────────────────────────────

var sprite : AnimatedSprite2D   # set by game.gd before load_animations() is called


# =============================================================================
# SETUP
# Called by game.gd after it creates the sprite node and assigns it above.
# =============================================================================

# Called: game._build_scene().
func load_animations() -> void:
	
	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames

	# Each entry: animation name -> spritesheet file path
	var sheets := {
		"idle_south": "res://assets/spritesheets/player/idle_neutral_south.png",
		"idle_north": "res://assets/spritesheets/player/idle_neutral_north.png",
		"idle_east":  "res://assets/spritesheets/player/idle_neutral_east.png",
		"idle_west":  "res://assets/spritesheets/player/idle_neutral_west.png",
		"walk_south": "res://assets/spritesheets/player/walking_south.png",
		"walk_north": "res://assets/spritesheets/player/walking_north.png",
		"walk_east":  "res://assets/spritesheets/player/walking_east.png",
		"walk_west":  "res://assets/spritesheets/player/walking_west.png",
	}

	for anim_name in sheets:
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 8.0)

		var texture    : Texture2D = load(sheets[anim_name])
		var frame_count := texture.get_width() / 96  # every frame is 96 px wide

		for i in range(frame_count):
			var atlas   := AtlasTexture.new()
			atlas.atlas  = texture
			atlas.region = Rect2(i * 96, 0, 96, 96)
			frames.add_frame(anim_name, atlas)

	sprite.play("idle_south")


# =============================================================================
# MOVEMENT  -  runs every physics frame
# =============================================================================

# LOOP
func _physics_process(_delta: float) -> void:

	# Read raw input from the keyboard
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input.y -= 1
	if Input.is_key_pressed(KEY_S): input.y += 1
	if Input.is_key_pressed(KEY_A): input.x -= 1
	if Input.is_key_pressed(KEY_D): input.x += 1

	if input.length() > 0:
		input = input.normalized()

		# Decide which direction the player is facing based on the
		# screen-space input (before we rotate it to world space).
		if abs(input.x) >= abs(input.y):
			facing = "east" if input.x > 0 else "west"
		else:
			facing = "south" if input.y > 0 else "north"

		# Rotate the input vector so movement is always relative to the
		# screen, not the world. Without this, pressing W would always
		# move toward world-north even when the camera is rotated.
		input = input.rotated(deg_to_rad(-camera_angle))

		sprite.play("walk_" + facing)
	else:
		sprite.play("idle_" + facing)

	velocity = input * SPEED
	move_and_slide()
