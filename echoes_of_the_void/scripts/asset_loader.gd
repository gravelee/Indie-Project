class_name AssetLoader

# =============================================================================
# ASSET LOADER — static caches for shared assets.
# Prevents loading the same resource more than once per session.
#
# SpriteFrames cache: keyed by folder path (e.g. "res://assets/spritesheets/player/")
#   — shared across all instances of the same entity type.
#
# Texture cache: keyed by full file path (e.g. "res://assets/sprites/tree/mystic/3x2_h1.png")
#   — shared across all scene objects using the same static image.
#
# Call AssetLoader.clear() on scene unload to release all cached resources.
# =============================================================================

static var _frames         : Dictionary = {}   # String → SpriteFrames
static var _textures       : Dictionary = {}   # String → Texture2D
static var _creature_stats : Dictionary = {}   # String → stat Dictionary (lazy-loaded from JSON)


# ---------------------------------------------------------------------------
# SpriteFrames — for AnimatedSprite3D (player, creatures)
# ---------------------------------------------------------------------------

static func get_frames(key: String) -> SpriteFrames:
	return _frames.get(key, null) as SpriteFrames


static func store_frames(key: String, frames: SpriteFrames) -> void:
	_frames[key] = frames


# ---------------------------------------------------------------------------
# Textures — for Sprite3D (trees, props, static images)
# ---------------------------------------------------------------------------

static func get_texture(path: String) -> Texture2D:
	return _textures.get(path, null) as Texture2D


static func store_texture(path: String, tex: Texture2D) -> void:
	_textures[path] = tex


static func load_texture(path: String) -> Texture2D:
	# Convenience: returns cached texture, or loads+caches it on first call.
	var cached : Texture2D = get_texture(path)
	if cached:
		return cached
	if ResourceLoader.exists(path):
		var tex : Texture2D = load(path)
		store_texture(path, tex)
		return tex
	return null


# ---------------------------------------------------------------------------
# Creature stats — loaded once from JSON, keyed by creature type string.
# Returns an empty Dictionary if the type is unknown or file is missing.
# ---------------------------------------------------------------------------

static func get_creature_stats(p_type: String) -> Dictionary:
	if _creature_stats.is_empty():
		_load_creature_stats()
	return _creature_stats.get(p_type, {}) as Dictionary


static func _load_creature_stats() -> void:
	const PATH : String = "res://assets/data/_creature_stats.json"
	if not FileAccess.file_exists(PATH):
		push_error("AssetLoader: _creature_stats.json not found at " + PATH)
		return
	var text   : String  = FileAccess.get_file_as_string(PATH)
	var parsed : Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_creature_stats = parsed as Dictionary
	else:
		push_error("AssetLoader: failed to parse _creature_stats.json")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

static func clear() -> void:
	_frames.clear()
	_textures.clear()
	_creature_stats.clear()
