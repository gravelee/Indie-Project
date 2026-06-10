extends CharacterBody3D

# =============================================================================
# PUSHABLE BLOCK — test prop for push/pull mechanic.
# Group: "pushable"
# Player drives movement in PUSH/PULL states (sets velocity + calls move_and_slide).
# When _driven = false, block handles gravity and friction on its own.
#
# CrushZone (mask = PROP_REACT_LAYER):
#   has_collision = false props (grass, 1×1 bushes)  → take_hit() on entry
#   has_collision = true  props (mid/large bushes)   → wobble while player is driving
#     _wobble_overlap : props whose DetectZone the block is currently inside
#     _wobble_driving : props currently showing the bump reaction (start_reaction called)
#     Wobble starts when _driven becomes true and the block is in contact.
#     Wobble stops when _driven becomes false or contact ends (area_exited).
# =============================================================================

const GRAVITY          : float = -20.0
const FRICTION         : float = 20.0
const PROP_REACT_LAYER : int   = 4   # matches WorldProp.PROP_REACT_LAYER

var half_size : float = 1.0   # half of the block's side length — set to match collision shape
var _driven   : bool  = false

var _wobble_overlap : Array = []   # collision props whose DetectZone we are inside
var _wobble_driving : Array = []   # collision props currently wobbling


func _ready() -> void:
	var area := Area3D.new()
	area.name            = "CrushZone"
	area.collision_layer = 0
	area.collision_mask  = PROP_REACT_LAYER
	area.monitoring      = true
	area.monitorable     = false
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size  = Vector3(half_size * 2.0, half_size * 2.0, half_size * 2.0)
	col.shape = shp
	area.add_child(col)
	area.area_entered.connect(_on_crush_entered)
	area.area_exited.connect(_on_crush_exited)
	add_child(area)


func _on_crush_entered(area: Area3D) -> void:
	var prop : Node = area.get_parent()
	if not is_instance_valid(prop):
		return
	if not prop.get("alive"):
		return
	if _driven and prop.get("has_collision"):
		# Player is actively pushing the block — wobble collidable props, don't destroy.
		if not _wobble_overlap.has(prop):
			_wobble_overlap.append(prop)
	else:
		# Block is free (falling from cliff, sliding) — crush everything it lands on.
		prop.call("take_hit")


func _on_crush_exited(area: Area3D) -> void:
	var prop : Node = area.get_parent()
	_wobble_overlap.erase(prop)
	if _wobble_driving.has(prop):
		_wobble_driving.erase(prop)
		if is_instance_valid(prop) and prop.get("alive"):
			prop.call("stop_reaction")


func _physics_process(delta: float) -> void:
	# Purge stale refs (props freed by the streamer or killed by the player)
	for p : Variant in _wobble_overlap.duplicate():
		if not is_instance_valid(p) or p.get("alive") == false:
			_wobble_overlap.erase(p)
	for p : Variant in _wobble_driving.duplicate():
		if not is_instance_valid(p) or p.get("alive") == false:
			_wobble_driving.erase(p)

	if _driven:
		# Player is controlling the block — start wobble for any contacted collision prop
		for p : Variant in _wobble_overlap:
			var prop : Node = p as Node
			if not _wobble_driving.has(prop):
				_wobble_driving.append(prop)
				prop.call("start_reaction")
		return

	# Block released — stop any active wobble
	for p : Variant in _wobble_driving.duplicate():
		var prop : Node = p as Node
		_wobble_driving.erase(prop)
		if is_instance_valid(prop) and prop.get("alive"):
			prop.call("stop_reaction")

	# Normal free physics
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
	move_and_slide()
