extends CharacterBody2D

var speed: float = 200.0
var camera_angle: float = 0.0

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

		# Rotate input vector by camera angle so WASD always
		# moves relative to screen orientation not world.
		input = input.rotated(deg_to_rad(-camera_angle))

	velocity = input * speed
	move_and_slide()
