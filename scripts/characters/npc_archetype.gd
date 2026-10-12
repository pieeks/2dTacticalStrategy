class_name NpcArchetype
extends RefCounted
## Loads NPC unit archetype JSON from resources/npcs/<npc_type>.json.

const BASE_PATH := "res://resources/npcs/"


## Parsed archetype dict, or {} if missing/invalid.
static func load_type(npc_type: String) -> Dictionary:
	var type_id := npc_type.strip_edges()
	if type_id.is_empty():
		return {}
	var path := BASE_PATH + type_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("NpcArchetype: file missing %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("NpcArchetype: could not open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("NpcArchetype: invalid JSON %s" % path)
		return {}
	return parsed as Dictionary
