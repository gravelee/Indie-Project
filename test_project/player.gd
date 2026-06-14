extends CharacterBody3D

var cam        : CameraSettings
var camera_rig : Node3D
var h_angle    : float = 0.0
var player_sprite : AnimatedSprite3D
var last_dir      : String = "south"
var stats : Stats
enum State { IDLE, MOVE, ATTACK }
var state : State = State.IDLE
var punch : Ability


# Called: init().
func _load_sprite_frames() -> SpriteFrames:
	
	var frames : SpriteFrames = SpriteFrames.new()
	var anims  : Array = [
		["walking_north",      "res://assets/player/north_walking/", 6],
		["walking_south",      "res://assets/player/south_walking/", 6],
		["walking_east",       "res://assets/player/east_walking/",  6],
		["walking_west",       "res://assets/player/west_walking/",  6],
		["idle_neutral_north", "res://assets/player/north_idle/",    10],
		["idle_neutral_south", "res://assets/player/south_idle/",    10],
		["idle_neutral_east",  "res://assets/player/east_idle/",     10],
		["idle_neutral_west",  "res://assets/player/west_idle/",     10],
		["attack_unarmed_north", "res://assets/player/north_attack_unarmed/", 5],
		["attack_unarmed_south", "res://assets/player/south_attack_unarmed/", 5],
		["attack_unarmed_east",  "res://assets/player/east_attack_unarmed/",  5],
		["attack_unarmed_west",  "res://assets/player/west_attack_unarmed/",  5]]
	
	for anim : Array in anims:
		var anim_name  : String = anim[0]
		var path       : String = anim[1]
		var frame_count : int   = anim[2]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		for i : int in range(frame_count):
			var tex : Texture2D = load(path + str(i) + ".png")
			frames.add_frame(anim_name, tex)
	
	frames.set_animation_loop("attack_unarmed_north", false)
	frames.set_animation_loop("attack_unarmed_south", false)
	frames.set_animation_loop("attack_unarmed_east",  false)
	frames.set_animation_loop("attack_unarmed_west",  false)
	
	return frames


# Called: _anim_apply().
func _get_dir(input: Vector2) -> String:
	
	if input.length() < 0.1:
		return last_dir
	if abs(input.y) >= abs(input.x):
		return "north" if input.y < 0.0 else "south"
	else:
		return "east" if input.x > 0.0 else "west"


# Called: _process().
func _anim_apply(input: Vector2) -> void:
	
	last_dir = _get_dir(input)
	var anim_name : String
	if input.length() >= 0.1:
		anim_name = "walking_" + last_dir
	else:
		anim_name = "idle_neutral_" + last_dir
		
	if player_sprite.animation != anim_name:
		player_sprite.play(anim_name)


# Called: _process().
func _attack_update() -> void:
	
	if not player_sprite.is_playing():
		state = State.IDLE
		return
	
	var frame : int = player_sprite.get_frame()
	if frame == punch.hit_frame:
		_attack_check()


# Called: _attack_update().
func _attack_check() -> void:
	
	var dir_vec : Vector3
	match last_dir:
		"north":
			dir_vec = Vector3( sin(h_angle), 0.0,  cos(h_angle))
		"south":
			dir_vec = Vector3(-sin(h_angle), 0.0, -cos(h_angle))
		"east":
			dir_vec = Vector3( cos(h_angle), 0.0, -sin(h_angle))
		"west":
			dir_vec = Vector3(-cos(h_angle), 0.0,  sin(h_angle))
		
	var space  : PhysicsDirectSpaceState3D   = get_world_3d().direct_space_state
	var origin : Vector3                     = global_position + Vector3(0.0, 1.0, 0.0)
	var target : Vector3                     = origin + dir_vec * punch.range_
	var params : PhysicsRayQueryParameters3D
	params = PhysicsRayQueryParameters3D.create(origin, target)
	params.exclude = [get_rid()]
	var result : Dictionary                  = space.intersect_ray(params)
	
	if result.is_empty():
		return
	
	var hit_body : Node = result["collider"]
	if not hit_body.has_meta("stats"):
		return
	
	var target_stats : Stats = hit_body.get_meta("stats")
	var damage       : float = punch.calc_damage(stats)
	var actual       : float = target_stats.take_damage(damage)
	print("hit: ", actual, " — dummy hp: ", target_stats.hp, "/", target_stats.hp_max)


# Called: main._build_player().
func init(p_camera_rig: Node3D, p_player_sprite: AnimatedSprite3D) -> void:
	
	camera_rig = p_camera_rig
	cam = camera_rig.get("cam")
	
	player_sprite = p_player_sprite
	player_sprite.sprite_frames = _load_sprite_frames()
	
	player_sprite.position.y = 32.0 * player_sprite.pixel_size * 0.5
	
	stats = Stats.new(5, 5, 5, 3, 2)
	punch = Abilities.get_ability("punch")


# Called: Godot engine (InputEvent).
func _input(event: InputEvent) -> void:
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			if state != State.ATTACK and punch.can_use(stats):
				state = State.ATTACK
				punch.spend(stats)
				player_sprite.play("attack_unarmed_" + last_dir)


# Called: Godot engine (every frame).
func _process(delta: float) -> void:
	
	h_angle = camera_rig.get("h_angle")
	
	# If WASD or arrow keyboard buttons are clicked and also are enabled via 
	# camera settings we take the 2d vector and convert it into 3d. Then we can 
	# apply the player movement based on the players basic movements speed.
	
	var input : Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction : Vector3 = Vector3(
		input.x * cos(h_angle) + input.y * sin(h_angle), 0.0, 
		input.x * -sin(h_angle) + input.y * cos(h_angle))
	
	var speed : float = 3.0
	velocity = direction * speed
	move_and_slide()
	
	match state:
		State.IDLE, State.MOVE:
			_anim_apply(input)
		State.ATTACK:
			_attack_update()
	
	stats.tick(delta)
	stats.regen(delta)
	punch.tick(delta)
