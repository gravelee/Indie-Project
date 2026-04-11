extends CharacterBody2D

var speed: float = 200.0
var camera_angle: float = 0.0
var facing: String = "south"

@onready var sprite: AnimatedSprite2D = $"../CanvasLayer/PlayerSprite"

func _ready() -> void:
	_load_animations()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	#print("pos: ", position, "  cam_angle: ", camera_angle)

func _handle_movement(delta: float) -> void:
	
	var input = Vector2.ZERO

	if Input.is_key_pressed(KEY_W):	input.y -= 1
	if Input.is_key_pressed(KEY_S):	input.y += 1
	if Input.is_key_pressed(KEY_A):	input.x -= 1
	if Input.is_key_pressed(KEY_D):	input.x += 1

	if input.length() > 0:
		input = input.normalized()

		# Update facing based on screen-space input
		if abs(input.x) >= abs(input.y):
			facing = "east" if input.x > 0 else "west"
		else:
			facing = "south" if input.y > 0 else "north"
			
		# Rotate input vector by camera angle so WASD always
		# moves relative to screen orientation not world.
		input = input.rotated(deg_to_rad(-camera_angle))

		sprite.play("walking_" + facing)
	else:
		sprite.play("idle_neutral_" + facing)

	velocity = input * speed
	move_and_slide()

func _load_animations() -> void:
	
	var frames = SpriteFrames.new()
	sprite.sprite_frames = frames
	
	var animations = {
		"idle_neutral_south": "res://player/idle_neutral_south.png",
		"idle_neutral_north": "res://player/idle_neutral_north.png",
		"idle_neutral_east": "res://player/idle_neutral_east.png",
		"idle_neutral_west": "res://player/idle_neutral_west.png",
		"walking_south": "res://player/walking_south.png",
		"walking_north": "res://player/walking_north.png",
		"walking_east": "res://player/walking_east.png",
		"walking_west": "res://player/walking_west.png",
	}
	
	for anim_name in animations:
		
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 8.0)
		
		var texture = load(animations[anim_name])
		var width = texture.get_width()
		var frame_count = width / 96
		
		for i in range(frame_count):
			
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * 96, 0, 96, 96)
			frames.add_frame(anim_name, atlas)
	
	sprite.play("idle_neutral_south")
