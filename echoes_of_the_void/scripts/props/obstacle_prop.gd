class_name ObstacleProp
extends DamageableProp

# =============================================================================
# OBSTACLE PROP — bushes and other destructible blocking props.
#
# Collision shape: full-height cylinder + cone cap.
#
# Cylinder — full height (_coll_height), vertical sides, normal.y = 0.
#   Blocks lateral approach from ground level to visual top with zero upward push.
#   Full height guarantees no lateral path exists to reach the cone from ground.
#
# Cone cap — apex at _coll_height (visual top), base at _coll_height - base_r * 1.3.
#   normal.y ≈ 0.61 < 0.707 → NOT treated as floor; move_and_slide deflects the
#   player sideways-and-off the slope on any jump landing. No balancing possible.
#   Cluster-walk is NOT possible: the full cylinder below means players can only
#   reach the cone from above (by jumping), never by walking into it laterally.
#   Apex degenerate vertex (GJK gives normal.y = 1.0 there) is handled by
#   player.gd _bush_landing_push_dir() as a last resort.
#
# Emergency escape: player.gd _emergency_escape_bush() destroys the nearest bush
#   after STUCK_AIR_TIMEOUT if the player is somehow trapped bouncing on the apex.
#
# Note: _cone_cache and _get_cone_shape() are static so that map_loader.gd (tree
# cone caps) can reuse them via ObstacleProp._get_cone_shape().
# =============================================================================

# Keyed "%.5f:%.5f" % [base_r, cap_height] → ConvexPolygonShape3D.
static var _cone_cache : Dictionary = {}


func _ready() -> void:
	states         = ["idle_alive"]
	_reaction_anim = "wobble"
	_area_radius   = 11.0 * float(mini(cols, rows)) * PIXEL_SIZE + 0.05
	super._ready()
	# Add cone cap on top of the full-height cylinder world_prop._ready() built.
	# Apex at _coll_height (visual top); base at _coll_height - cone_h above ground.
	# _measure_content_height() guarantees _coll_height >= 1.0, so the base is
	# always above ground (1.0 - base_r * 1.3 >= 0.55 for a 1×1 bush).
	if has_collision and _coll_height > 0.0:
		var base_r  : float = 11.0 * float(mini(cols, rows)) * PIXEL_SIZE
		# cone_h = 90% of _coll_height makes the cone very steep (normal.y ≈ 0.35).
		# A shallow cone (normal.y ≈ 0.61, cone_h = base_r * 1.3) only partially deflects
		# lateral approach velocity — the player inches toward the apex over several frames.
		# A steep cone REVERSES lateral approach velocity on contact, reliably pushing the
		# player away regardless of approach angle. Base sits at 10% of visual height
		# (still well above ground since _coll_height >= 1.0).
		var cone_h  : float = _coll_height * 0.9
		var cap_col := CollisionShape3D.new()
		cap_col.shape    = _get_cone_shape(base_r, cone_h)
		cap_col.position = Vector3(0.0, _coll_height * 0.1, 0.0)
		add_child(cap_col)


# Returns a cached cone shape. Hull computation runs only once per unique size.
# Called by map_loader.gd for tree cone caps.
static func _get_cone_shape(base_r: float, height: float) -> ConvexPolygonShape3D:
	var key : String = "%.5f:%.5f" % [base_r, height]
	if not _cone_cache.has(key):
		_cone_cache[key] = _make_cone_shape(base_r, height)
	return _cone_cache[key] as ConvexPolygonShape3D


# Builds a ConvexPolygonShape3D cone: apex at (0, height, 0), base ring at y=0.
static func _make_cone_shape(base_r: float, height: float,
		segments: int = 10) -> ConvexPolygonShape3D:
	var shp : ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	var pts : PackedVector3Array   = PackedVector3Array()
	pts.append(Vector3(0.0, height, 0.0))
	for i : int in range(segments):
		var a : float = float(i) * TAU / float(segments)
		pts.append(Vector3(cos(a) * base_r, 0.0, sin(a) * base_r))
	shp.points = pts
	return shp


func _on_death_finished() -> void:
	queue_free()
