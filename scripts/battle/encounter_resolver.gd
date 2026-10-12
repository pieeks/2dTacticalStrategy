class_name EncounterResolver
extends RefCounted
## Resolves World-Encounter / encounter_id / group_size into a host enemy_roster snapshot.

const NPC_BASE_PATH := "res://resources/npcs/"
const ENCOUNTER_BASE_PATH := "res://resources/encounters/"


## Ensure encounter has enemy_roster. Skips rebuild if already non-empty (Join/Late-Join).
static func attach_enemy_roster(encounter: Dictionary) -> Dictionary:
	var out: Dictionary = encounter.duplicate(true)
	var existing: Variant = out.get("enemy_roster", [])
	if existing is Array and not (existing as Array).is_empty():
		return out
	var roster: Array = resolve(out)
	out["enemy_roster"] = roster
	if not roster.is_empty():
		out["group_size"] = roster.size()
	return out


## Build enemy_roster from units[] / encounter file / group_size × npc_type.
static func resolve(encounter: Dictionary) -> Array:
	var units_spec: Array = _collect_units_spec(encounter)
	var roster: Array = []
	if not units_spec.is_empty():
		for entry in units_spec:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var npc_type := str(entry.get("npc_type", "")).strip_edges()
			if npc_type.is_empty():
				push_warning("EncounterResolver: units entry missing npc_type — skipped")
				continue
			var count := maxi(1, int(entry.get("count", 1)))
			var archetype := _load_npc_archetype(npc_type)
			if archetype.is_empty():
				push_warning("EncounterResolver: missing archetype for npc_type=%s — skipped" % npc_type)
				continue
			for _i in range(count):
				roster.append(_make_roster_entry(npc_type, archetype, roster.size()))
		return roster
	# Fallback: group_size × encounter npc_type (legacy).
	var npc_type_fb := str(encounter.get("npc_type", "")).strip_edges()
	var group_size := maxi(1, int(encounter.get("group_size", 1)))
	if npc_type_fb.is_empty():
		# Debug fights with no type: still one placeholder from encounter fields.
		for i in range(group_size):
			roster.append({
				"unit_key": "enemy_%d" % i,
				"npc_type": "",
				"display_name": str(encounter.get("npc_name", "Enemy")),
				"stats": _dict_or_empty(encounter.get("stats", {})),
				"appearance": _dict_or_empty(encounter.get("appearance", {})),
			})
		return roster
	var archetype_fb := _load_npc_archetype(npc_type_fb)
	if archetype_fb.is_empty():
		# Spec already on encounter (map NPC) — use those fields.
		for i in range(group_size):
			roster.append({
				"unit_key": "enemy_%d" % i,
				"npc_type": npc_type_fb,
				"display_name": str(encounter.get("npc_name", npc_type_fb)),
				"stats": _dict_or_empty(encounter.get("stats", {})),
				"appearance": _dict_or_empty(encounter.get("appearance", {})),
			})
		return roster
	for i in range(group_size):
		roster.append(_make_roster_entry(npc_type_fb, archetype_fb, i))
	return roster


static func _collect_units_spec(encounter: Dictionary) -> Array:
	# Inline units on encounter dict (already merged from NPC).
	var inline: Variant = encounter.get("units", [])
	if inline is Array and not (inline as Array).is_empty():
		return inline as Array
	var nested: Variant = encounter.get("encounter", {})
	if nested is Dictionary:
		var nested_units: Variant = (nested as Dictionary).get("units", [])
		if nested_units is Array and not (nested_units as Array).is_empty():
			return nested_units as Array
	var encounter_id := str(encounter.get("encounter_id", "")).strip_edges()
	if encounter_id.is_empty() and nested is Dictionary:
		encounter_id = str((nested as Dictionary).get("id", "")).strip_edges()
	if encounter_id.is_empty():
		return []
	var file_data := _load_encounter_file(encounter_id)
	if file_data.is_empty():
		return []
	var file_units: Variant = file_data.get("units", [])
	if file_units is Array:
		return file_units as Array
	return []


static func _make_roster_entry(npc_type: String, archetype: Dictionary, index: int) -> Dictionary:
	var display := str(archetype.get("name", npc_type))
	return {
		"unit_key": "enemy_%d" % index,
		"npc_type": npc_type,
		"display_name": display,
		"stats": _dict_or_empty(archetype.get("stats", {})),
		"appearance": _dict_or_empty(archetype.get("appearance", {})),
	}


static func _load_npc_archetype(npc_type: String) -> Dictionary:
	if npc_type.is_empty():
		return {}
	return _load_json_dict(NPC_BASE_PATH + npc_type + ".json")


static func _load_encounter_file(encounter_id: String) -> Dictionary:
	if encounter_id.is_empty():
		return {}
	return _load_json_dict(ENCOUNTER_BASE_PATH + encounter_id + ".json")


static func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("EncounterResolver: file missing %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("EncounterResolver: could not open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("EncounterResolver: invalid JSON %s" % path)
		return {}
	return parsed as Dictionary


static func _dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
