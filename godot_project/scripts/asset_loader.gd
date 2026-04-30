class_name AssetLoader

# Shared SpriteFrames cache keyed by a unique string per type+variant.
# Multiple instances of the same type share one SpriteFrames object,
# eliminating per-instance AtlasTexture construction cost.
static var _frames : Dictionary = {}


static func get_frames(key: String) -> SpriteFrames:
	return _frames.get(key, null) as SpriteFrames


static func store_frames(key: String, frames: SpriteFrames) -> void:
	print(key)
	_frames[key] = frames


# Call on scene unload to release cached SpriteFrames.
static func clear() -> void:
	_frames.clear()
	WorldProp._tex_cache.clear()
