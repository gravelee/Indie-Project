extends Node2D

const TERRAIN_Z := -4096
const TERAIN_TILESET_ROW_WIDTH:= 24
const TILE_SIZE := 32
const BLOCKER_TIMER_INTERVAL := 0.15

# Pre-computed _on_player_attack() consts.
const ATTACK_RADIUS       := 96.0
const ATTACK_RADIUS_SQ    := ATTACK_RADIUS * ATTACK_RADIUS
const ATTACK_QUARTER_CONE := 45.0
const ATTACK_SEARCH_R     := 3   # ceili(ATTACK_RADIUS / TILE_SIZE)

# ── File paths ─────────────────────────────────────────────────────────────────

const PATH_TILESET                := "res://assets/tilemaps/leaf/leaf.png"
const PATH_MAP_TERRAIN            := "res://assets/maps/level_01/level_01_Terain.csv"

const PATH_PLAYER_SCRIPT          := "res://scripts/entities/player.gd"
const PATH_PLAYER_STATS           := "res://assets/player_stats.json"

const PATH_CREATURE_SCRIPT		  := "res://scripts/entities/creature.gd"
const PATH_CREATURE_STATS         := "res://assets/maps/level_01/creature_stats.json"

const PATH_MAP_ENTITIES   		  := "res://assets/maps/level_01/level_01_Entities.csv"
const PATH_PROP_SCRIPT            := "res://scripts/props/world_prop.gd"
const PATH_DESTRUCTIBLE_SCRIPT    := "res://scripts/props/destructible.gd"
const PATH_REACTIVE_SCRIPT        := "res://scripts/props/reactive_prop.gd"


# ── Other ──────────────────────────────────────────────────────────────────────

enum Entity_Type {
	PLAYER, CREATURE
}

const MAP_ENTITY_TYPE := {
	Entity_Type.PLAYER	: "player",
	Entity_Type.CREATURE: "creature"
}


# ── Node ───────────────────────────────────────────────────────────────────────

var tilemap           : TileMap                       # init _load_terrain().
var _map_cols         : int        = 0                # set  _load_terrain().
var _map_rows         : int        = 0                # set  _load_terrain().

var pathfinder        : Pathfinder = Pathfinder.new() # set  _ready().
var _creature_tile_set: Dictionary = {}               # set _update_dynamic_blockers().
var _blocker_timer    : float      = 0.0              # set _update_dynamic_blockers().

var player            : CharacterBody2D               # init _init_player().
var player_sprite     : AnimatedSprite2D              # init _init_player().
var weapon_sprite     : AnimatedSprite2D              # init _init_player().

var creatures         : Dictionary = {}               # init _load_entities().
var creature_sprites  : Dictionary = {}               # init _load_entities().
var _creature_queue   : Dictionary = {}               # type_str -> [[creature, stats]], consumed in _load_entities().

var destructible_map  : Dictionary = {}               # init _spawn_prop().
var obstacle_map      : Dictionary = {}               # init _spawn_prop().
var rotatable_sprites : Array      = []               # init _spawn_prop().


# =============================================================================
# SETUP
# =============================================================================

# Called: game.ready().
func _ready() -> void:
	
	_load_terrain()
	_init_player()
	pathfinder.build(_map_cols, _map_rows)
	_init_creatures()
	_load_entities()


# =============================================================================
# TERRAIN INITIALIZATION.
# =============================================================================

# Called: _ready().
func _load_terrain() -> void:

	# Initializes the tilemap by setting position, z_index and tile_set.
	tilemap = TileMap.new()
	tilemap.position = Vector2.ZERO
	tilemap.z_index = TERRAIN_Z
	tilemap.tile_set = _create_tileset()
	add_child(tilemap)

	# Reads the level specific terrain file (.csv).
	var file := FileAccess.open(PATH_MAP_TERRAIN, FileAccess.READ)
	if file == null:
		push_error("Cannot open terrain file.")
		return

	# Sets every tilemap cell to the right tile_id from tileset based on the terrain file values.
	# Also sets the _map_cols and _map_rows values.
	var row := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var cols := line.split(",")
		if _map_cols == 0:
			_map_cols = cols.size()
		for col in range(cols.size()):
			var tile_id    := int(cols[col])
			var atlas_col  := tile_id % TERAIN_TILESET_ROW_WIDTH
			var atlas_row  := tile_id / TERAIN_TILESET_ROW_WIDTH
			tilemap.set_cell(0, Vector2i(col, row), 0, Vector2i(atlas_col, atlas_row))
		row += 1
	_map_rows = row

	file.close()


# Called: _load_terrain().
func _create_tileset() -> TileSet:

	# Initialize the tileset by setting the tile size first.
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Reads the terrain tileset file (.png) and loads it into a texture2D.
	# Creates an atlas source and sets the texture in it.
	# Also sets the tile size within source.
	var texture : Texture2D = load(PATH_TILESET)
	var source  := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Calculates the texture2Ds column and row sizes.
	# Registers every tile in the atlas source so set_cell() can place them.
	var cols := texture.get_width()  / TILE_SIZE
	var rows := texture.get_height() / TILE_SIZE
	for row in range(rows):
		for col in range(cols):
			source.create_tile(Vector2i(col, row))
	
	# Sets the atlas source in the tileset and return it.
	tileset.add_source(source, 0)   # source id 0 matches the set_cell() calls below
	return tileset


# =============================================================================
# PLAYER INITIALIZATION.
# =============================================================================

# Called: _ready().
func _init_player() -> void:
	
	player = CharacterBody2D.new()	
	player.set_script(load(PATH_PLAYER_SCRIPT))
	var col_shape := CollisionShape2D.new()
	var shape      := CircleShape2D.new()
	shape.radius   = 30.0
	col_shape.shape = shape
	player.add_child(col_shape)
	add_child(player)
	
	player_sprite = AnimatedSprite2D.new()
	player_sprite.z_as_relative = false
	add_child(player_sprite)

	weapon_sprite = AnimatedSprite2D.new()
	weapon_sprite.z_as_relative = false
	add_child(weapon_sprite)
	
	_load_player_stats()
	player.init(player_sprite, weapon_sprite)
	
	# attack signal is connected with _on_player_attack().
	player.attack.connect(_on_player_attack)


# Called: _init_player().
func _load_player_stats() -> void:
	
	var stats : Dictionary = _load_entity_stats(Entity_Type.PLAYER)[0]
	
	player.stats = Stats.new(stats["str"], stats["agi"], stats["sta"], stats["int"],
		stats["spr"], stats["res"], stats["def"], stats["bms"], stats["exp"])


# Called: _load_player_stats(), _init_creatures().
func _load_entity_stats(entity_type: Entity_Type) -> Array:

	var path : String = PATH_PLAYER_STATS if entity_type == Entity_Type.PLAYER else PATH_CREATURE_STATS
	# Tries to open the entity's json file.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s."%[path])
		return []
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		push_error("Failed to parse %s."%[path])
		return []
	
	# Returns the entity stats.
	return data[MAP_ENTITY_TYPE[entity_type]]


# Called: player._try_attack() who emits player.attack signal.
func _on_player_attack(world_pos: Vector2, facing_direction: Vector2) -> void:
	
	# Attackable obstacles are resolved here.
	var player_tile := Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)
	# 7x7 broad phase = 49 tiles to check.
	for dy in range(-ATTACK_SEARCH_R, ATTACK_SEARCH_R + 1):
		for dx in range(-ATTACK_SEARCH_R, ATTACK_SEARCH_R + 1):
			var key      := Vector2i(player_tile.x + dx, player_tile.y + dy)
			if not destructible_map.has(key):
				continue
			var obstacle := destructible_map[key] as WorldProp
			if not obstacle.alive:
				continue
			var to_obs : Vector2 = (obstacle.position + obstacle.weight_central) - world_pos
			# circle (r=3 tiles) = 29 tiles left.
			if to_obs.length_squared() > ATTACK_RADIUS_SQ:
				continue
			if to_obs != Vector2.ZERO:
				var deg := rad_to_deg(facing_direction.angle_to(to_obs.normalized()))
				# 45° cone ≈ 3-4 tiles left.
				if absf(deg) > ATTACK_QUARTER_CONE:
					continue
			obstacle.take_hit()

	# Collect all creatures inside players attack area.
	var creature_targets : Array = []
	for creature in creatures.values():
		if not creature.alive:
			continue
		var to_c : Vector2 = creature.position - world_pos
		if to_c.length_squared() > ATTACK_RADIUS_SQ:
			continue
		if to_c != Vector2.ZERO:
			var deg := rad_to_deg(facing_direction.angle_to(to_c.normalized()))
			if absf(deg) > ATTACK_QUARTER_CONE:
				continue
		creature_targets.append(creature)
	
	# Resolve the attack.
	player.resolve_attack(creature_targets)


# =============================================================================
# ALL CREATURE INITIALIZATION.
# =============================================================================

# Called: _ready(). 
func _init_creatures() -> void:

	# Builds a per-type queue of unpositioned creatures.
	# Positions and dict registration happen in _load_entities() (scan order).
	var all_creature_stats : Array = _load_entity_stats(Entity_Type.CREATURE)

	for creature_stats in all_creature_stats:

		var creature  	:= CharacterBody2D.new()
		creature.set_script(load(PATH_CREATURE_SCRIPT))
		var col_shape	:= CollisionShape2D.new()
		var shape      	:= CircleShape2D.new()
		shape.radius   = 20.0
		col_shape.shape = shape
		creature.add_child(col_shape)
		add_child(creature)

		var type_str : String = creature_stats["type"]
		if not _creature_queue.has(type_str):
			_creature_queue[type_str] = []
		_creature_queue[type_str].append([creature, creature_stats])


# Called: _load_entities().
func _load_creature_stats(tile_id: int, row: int, col: int, world_pos: Vector2) -> void:
	
	var type_id : String = Creature.TILE_TYPE_MAP[tile_id]
	if not _creature_queue.has(type_id) or _creature_queue[type_id].is_empty():
		push_error("No queued creature of type '%s' at row %d col %d." % [type_id, row, col])
		return
	var entry : Array = _creature_queue[type_id].pop_front()
	var creature = entry[0]
	var creature_stats : Dictionary = entry[1]
	creature.position = world_pos
	creature.init(creature_stats, player, 0.0, pathfinder)
	var spawn_key := world_pos
	creature.died.connect(func():
		creature_sprites.erase(spawn_key)
		creatures.erase(spawn_key)
	)
	creature_sprites[world_pos] = creature.sprite
	creatures[world_pos] = creature


# =============================================================================
# ALL PROPERTIES INITIALIZATION.
# =============================================================================

# Called: _ready().
func _load_entities() -> void:

	# Tries to open the entities file.
	var file := FileAccess.open(PATH_MAP_ENTITIES, FileAccess.READ)
	if file == null:
		push_error("Cannot open entities file.")
		return

	var row := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var cols := line.split(",")
		for col in range(cols.size()):
			var tile_id   := int(cols[col])
			# Tiled maps all sprite coordinates from top left to down right.
			# We map sprite coordinates from down left to top right.
			# This creates a whole tile difference in the vertical axis between the two systems.
			var world_pos := Vector2(col * TILE_SIZE, row * TILE_SIZE + TILE_SIZE)
			if tile_id == 1:                        # 1 = player spawn
				player.position = world_pos
			elif tile_id in Creature.TILE_TYPE_MAP: # 2 = rat, 3 = snake, ...
				_load_creature_stats(tile_id, row, col, world_pos)
			elif tile_id == 101:              # 101 = 1×1 classic
				_spawn_prop(world_pos, 1, 1, "bush", "classic", 0, 5, true, true, true)
			elif tile_id == 102:              # 102 = 2×2 classic
				_spawn_prop(world_pos, 2, 2, "bush", "classic", 0, 5, true, true, true)
			elif tile_id == 103:              # 103 = 3×3 classic
				_spawn_prop(world_pos, 3, 3, "bush", "classic", 0, 5, true, true, true)
			elif tile_id == 104:              # 104 = 1×1 leafy
				_spawn_prop(world_pos, 1, 1, "bush", "leafy", 0, 1, true, true, true)
			elif tile_id == 105:              # 105 = 2×2 leafy
				_spawn_prop(world_pos, 2, 2, "bush", "leafy", 0, 1, true, true, true)
			elif tile_id == 106:              # 106 = 3×3 leafy
				_spawn_prop(world_pos, 3, 3, "bush", "leafy", 0, 1, true, true, true)
			elif tile_id == 107:              # 107 = 1×1 spiky
				_spawn_prop(world_pos, 1, 1, "bush", "spiky", 0, 1, true, true, true)
			elif tile_id == 108:              # 108 = 2×2 spiky
				_spawn_prop(world_pos, 2, 2, "bush", "spiky", 0, 1, true, true, true)
			elif tile_id == 109:              # 109 = 3×3 spiky
				_spawn_prop(world_pos, 3, 3, "bush", "spiky", 0, 1, true, true, true)
			elif tile_id == 110:              # 110 = 1×1 tree  h=0
				_spawn_prop(world_pos, 1, 1, "tree", "mystic", 0, 1, false, true, false)
			elif tile_id == 111:              # 111 = 1×1 tree  h=1
				_spawn_prop(world_pos, 1, 1, "tree", "mystic", 1, 1, false, true, false)
			elif tile_id == 112:              # 112 = 2×2 tree  h=0
				_spawn_prop(world_pos, 2, 2, "tree", "mystic", 0, 1, false, true, false)
			elif tile_id == 113:              # 113 = 2×2 tree  h=1
				_spawn_prop(world_pos, 2, 2, "tree", "mystic", 1, 1, false, true, false)
			elif tile_id == 114:              # 114 = 2×2 tree  h=2
				_spawn_prop(world_pos, 2, 2, "tree", "mystic", 2, 1, false, true, false)
			elif tile_id == 115:              # 115 = 3×2 tree  h=0
				_spawn_prop(world_pos, 3, 2, "tree", "mystic", 0, 1, false, true, false)
			elif tile_id == 116:              # 116 = 3×2 tree  h=1
				_spawn_prop(world_pos, 3, 2, "tree", "mystic", 1, 1, false, true, false)
			elif tile_id == 117:              # 117 = 3×2 tree  h=2
				_spawn_prop(world_pos, 3, 2, "tree", "mystic", 2, 1, false, true, false)
			elif tile_id == 118:              # 118 = 1×1 grass
				_spawn_prop(world_pos, 1, 1, "grass", "classic", 0, 1, true, false, false, true)
			elif tile_id == 119:              # 119 = 2×2 grass
				_spawn_prop(world_pos, 2, 2, "grass", "classic", 0, 1, true, false, false, true)
			elif tile_id == 120:              # 120 = 3×3 grass
				_spawn_prop(world_pos, 3, 3, "grass", "classic", 0, 1, true, false, false, true)
		row += 1
	file.close()


# Called: _load_entities().
# cols/rows = tile footprint. height_ext = 0 for standard height, 1/2/… for progressively taller variants.
func _spawn_prop(world_pos: Vector2, cols: int, rows: int, sprite_type: String, sprite_name: String,
	height_ext: int, variant_count: int, central_rotation: bool, has_collision: bool, destructible: bool, reactive: bool = false) -> void:

	var prop             := WorldProp.new()
	var script_path      := PATH_DESTRUCTIBLE_SCRIPT if destructible else (PATH_REACTIVE_SCRIPT if reactive else PATH_PROP_SCRIPT)
	prop.set_script(load(script_path))
	prop.position         = world_pos
	prop.cols             = cols
	prop.rows             = rows
	prop.sprite_type      = sprite_type
	prop.sprite_name      = sprite_name
	prop.height_ext       = height_ext
	prop.variant_count    = variant_count
	prop.central_rotation = central_rotation
	prop.has_collision    = has_collision
	add_child(prop)   # triggers world_prop._ready() which creates sprite + optional collision

	if has_collision:
		# Pathfinder maps the grid coordinates from top left to down right.
		# We map sprite coordinates from down left to top right.
		# This creates a whole tile difference in the vertical axis between the two systems.
		var tile_key = Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE - 1)
		pathfinder.set_tile_solid(tile_key, cols, rows, true)
		if destructible:
			prop.died.connect(func():
				destructible_map.erase(tile_key)
				rotatable_sprites.erase(prop.sprite)
				pathfinder.set_tile_solid(tile_key, cols, rows, false)
			)
			destructible_map[tile_key] = prop
		else:
			prop.tree_exiting.connect(func():
				obstacle_map.erase(tile_key)
				rotatable_sprites.erase(prop.sprite)
				pathfinder.set_tile_solid(tile_key, cols, rows, false)
			)
			obstacle_map[tile_key] = prop
	#else:
		# No collision, not destructible — nothing to clean up until fully freed.
	rotatable_sprites.append(prop.sprite)


# =============================================================================
# LIFECYCLE
# =============================================================================

# LOOP
func _process(dt: float) -> void:
	
	_update_dynamic_blockers(dt)
	pathfinder.update_temp_block(dt)
	_update_player_combat()


# Called: _process().
func _update_dynamic_blockers(dt: float) -> void:

	_blocker_timer += dt
	if _blocker_timer < BLOCKER_TIMER_INTERVAL:
		return
	_blocker_timer = 0.0
	_creature_tile_set.clear()
	for creature in creatures.values():
		# Pathfinder maps the grid coordinates from top left to down right.
		# We map sprite coordinates from down left to top right.
		# This creates a whole tile difference in the vertical axis between the two systems.
		var tile := Vector2i(int(creature.position.x) / TILE_SIZE, int(creature.position.y) / TILE_SIZE - 1)
		_creature_tile_set[tile] = true
	pathfinder.set_dynamic_blockers(_creature_tile_set)


# Called: _process().
func _update_player_combat() -> void:

	var any_combat := false
	for creature in creatures.values():
		if creature.in_combat:
			any_combat = true
			break
	player.in_combat = any_combat
