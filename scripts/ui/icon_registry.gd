class_name IconRegistry
extends RefCounted

## Loads 2D UI icons for context-menu actions and product ids.

const ICON_DIR := "res://assets/ui/icons/"

static var _cache: Dictionary = {}


static func has_icon(id: String) -> bool:
	return ResourceLoader.exists(_path_for(id))


static func get_icon(id: String) -> Texture2D:
	if id.is_empty():
		return null
	if _cache.has(id):
		return _cache[id]
	var path := _path_for(id)
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_cache[id] = tex
	return tex


static func action_icon(action_id: String) -> Texture2D:
	return get_icon(action_id)


static func product_icon(product_id: String) -> Texture2D:
	return get_icon(product_id)


static func _path_for(id: String) -> String:
	return ICON_DIR + id + ".png"
