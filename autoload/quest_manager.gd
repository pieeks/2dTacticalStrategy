extends Node

## QuestManager
##
## Loads quest definitions, tracks local party quest state, and applies rewards.
## Group shared progress is stubbed until a group system exists.

signal quests_changed

const QUESTS_DIR := "res://resources/quests/"
const DEMO_QUEST_ID := "q_intro_slime"

## id -> definition Dictionary
var _definitions: Dictionary = {}


func _ready() -> void:
	load_definitions()
	_ensure_quest_data()
	_ensure_inventory()


## Load all JSON quest definitions from resources/quests/.
func load_definitions() -> void:
	_definitions.clear()
	var dir := DirAccess.open(QUESTS_DIR)
	if dir == null:
		push_warning("QuestManager: cannot open %s" % QUESTS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_definition_file(QUESTS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func get_definition(quest_id: String) -> Dictionary:
	return _definitions.get(quest_id, {})


## All known quest definition ids (sorted).
func get_all_quest_ids() -> Array:
	var ids: Array = _definitions.keys()
	ids.sort()
	return ids


## Runtime status for debug UI: inactive | active | ready | completed.
func get_status(quest_id: String) -> String:
	if has_completed(quest_id):
		return "completed"
	var active := get_active()
	if active.has(quest_id):
		return str(active[quest_id].get("status", "active"))
	return "inactive"


func can_accept(quest_id: String) -> bool:
	if not _definitions.has(quest_id):
		return false
	if has_completed(quest_id):
		return false
	if get_active().has(quest_id):
		return false
	var def: Dictionary = _definitions[quest_id]
	var requires: Array = def.get("requires_completed", [])
	for req in requires:
		if not has_completed(str(req)):
			return false
	return true


## Accept a quest into local active state.
func accept(quest_id: String) -> bool:
	if not can_accept(quest_id):
		return false
	var def: Dictionary = _definitions[quest_id]
	var objectives: Array = []
	for obj in def.get("objectives", []):
		if typeof(obj) != TYPE_DICTIONARY:
			continue
		objectives.append({
			"id": str(obj.get("id", "")),
			"type": str(obj.get("type", "")),
			"target": str(obj.get("target", "")),
			"count": int(obj.get("count", 1)),
			"current": 0,
			"done": false,
			"text_key": str(obj.get("text_key", "")),
		})
	var entry := {
		"id": quest_id,
		"status": "active",
		"category": str(def.get("category", "side")),
		"objectives": objectives,
	}
	_ensure_quest_data()
	PlayerPartyState.quest_data["active"][quest_id] = entry
	_notify_changed("quest_accept")
	return true


## Active quests map: id -> runtime entry.
func get_active() -> Dictionary:
	_ensure_quest_data()
	var active = PlayerPartyState.quest_data.get("active", {})
	return active if typeof(active) == TYPE_DICTIONARY else {}


## Completed quest id list.
func get_completed() -> Array:
	_ensure_quest_data()
	var completed = PlayerPartyState.quest_data.get("completed", [])
	return completed if typeof(completed) == TYPE_ARRAY else []


func has_completed(quest_id: String) -> bool:
	return get_completed().has(quest_id)


func is_ready_to_turn_in(quest_id: String) -> bool:
	var active := get_active()
	if not active.has(quest_id):
		return false
	return str(active[quest_id].get("status", "")) == "ready"


## Apply a progress event locally. Group share is stubbed.
func report_progress(event: Dictionary) -> void:
	_apply_progress_local(event)
	share_progress_with_group(event)


## Turn in a ready quest and apply rewards.
func turn_in(quest_id: String) -> bool:
	if not is_ready_to_turn_in(quest_id):
		return false
	var active := get_active()
	active.erase(quest_id)
	var completed: Array = get_completed()
	if not completed.has(quest_id):
		completed.append(quest_id)
	PlayerPartyState.quest_data["completed"] = completed
	var def := get_definition(quest_id)
	_apply_rewards(def.get("rewards", {}))
	_notify_changed("quest_turn_in")
	return true


## Force all objectives done and status ready (debug / cheats).
func debug_complete_objectives(quest_id: String) -> bool:
	var active := get_active()
	if not active.has(quest_id):
		return false
	var entry: Dictionary = active[quest_id]
	var objectives: Array = entry.get("objectives", [])
	for i in range(objectives.size()):
		var obj: Dictionary = objectives[i]
		obj["current"] = int(obj.get("count", 1))
		obj["done"] = true
		objectives[i] = obj
	entry["objectives"] = objectives
	entry["status"] = "ready"
	active[quest_id] = entry
	_notify_changed("quest_debug_ready")
	return true


## Accept (if needed), complete objectives, and turn in.
func debug_force_complete(quest_id: String) -> bool:
	if has_completed(quest_id):
		return false
	if not get_active().has(quest_id):
		if not accept(quest_id):
			return false
	debug_complete_objectives(quest_id)
	return turn_in(quest_id)


## Debug: remove quest from completed (and active if present) so it can be accepted again.
func debug_uncomplete(quest_id: String) -> bool:
	if quest_id.is_empty() or not _definitions.has(quest_id):
		return false
	_ensure_quest_data()
	var changed := false
	var active := get_active()
	if active.has(quest_id):
		active.erase(quest_id)
		changed = true
	var completed: Array = get_completed()
	var idx := completed.find(quest_id)
	if idx >= 0:
		completed.remove_at(idx)
		PlayerPartyState.quest_data["completed"] = completed
		changed = true
	if not changed:
		return false
	_notify_changed("quest_debug_uncomplete")
	return true


## Offer quest ids available from an NPC spec payload.
func get_offerable_from_npc(npc_data: Dictionary) -> Array:
	var quests: Dictionary = npc_data.get("quests", {})
	if typeof(quests) != TYPE_DICTIONARY:
		return []
	var offer: Array = quests.get("offer", [])
	var result: Array = []
	for qid in offer:
		var id := str(qid)
		if can_accept(id):
			result.append(id)
	return result


## Turn-in quest ids ready at this NPC.
func get_turn_in_from_npc(npc_data: Dictionary) -> Array:
	var quests: Dictionary = npc_data.get("quests", {})
	if typeof(quests) != TYPE_DICTIONARY:
		return []
	var turn_in_ids: Array = quests.get("turn_in", [])
	var result: Array = []
	for qid in turn_in_ids:
		var id := str(qid)
		if is_ready_to_turn_in(id):
			result.append(id)
	return result


## True when peers share a session group (GroupManager).
func _peers_in_same_group(peer_a: int, peer_b: int) -> bool:
	if GroupManager == null:
		return false
	if GroupManager.has_method("is_grouped_with_peers"):
		return GroupManager.is_grouped_with_peers(peer_a, peer_b)
	return false


## Stub: share progress with group members later.
func share_progress_with_group(_event: Dictionary) -> void:
	pass


func _apply_progress_local(event: Dictionary) -> void:
	var ev_type := str(event.get("type", ""))
	var ev_target := str(event.get("target", ""))
	var amount := int(event.get("amount", 1))
	if ev_type.is_empty() or amount <= 0:
		return
	var active := get_active()
	var changed := false
	for quest_id in active.keys():
		var entry: Dictionary = active[quest_id]
		var status := str(entry.get("status", "active"))
		if status != "active" and status != "ready":
			continue
		var objectives: Array = entry.get("objectives", [])
		for i in range(objectives.size()):
			var obj: Dictionary = objectives[i]
			if bool(obj.get("done", false)):
				continue
			if str(obj.get("type", "")) != ev_type:
				continue
			if str(obj.get("target", "")) != ev_target:
				continue
			var count := int(obj.get("count", 1))
			var current := mini(count, int(obj.get("current", 0)) + amount)
			obj["current"] = current
			obj["done"] = current >= count
			objectives[i] = obj
			changed = true
		var all_done := true
		for obj2 in objectives:
			if not bool(obj2.get("done", false)):
				all_done = false
				break
		entry["objectives"] = objectives
		entry["status"] = "ready" if all_done else "active"
		active[quest_id] = entry
	if changed:
		_notify_changed("quest_progress")


func _apply_rewards(rewards: Dictionary) -> void:
	_ensure_inventory()
	var gold := int(rewards.get("gold", 0))
	if gold != 0:
		PlayerPartyState.inventory_data["gold"] = int(PlayerPartyState.inventory_data.get("gold", 0)) + gold
	var items = rewards.get("items", [])
	if typeof(items) == TYPE_ARRAY and not items.is_empty():
		var bag: Array = PlayerPartyState.inventory_data.get("items", [])
		if typeof(bag) != TYPE_ARRAY:
			bag = []
		for item in items:
			bag.append(item)
		PlayerPartyState.inventory_data["items"] = bag


func _ensure_quest_data() -> void:
	if typeof(PlayerPartyState.quest_data) != TYPE_DICTIONARY:
		PlayerPartyState.quest_data = {}
	if not PlayerPartyState.quest_data.has("active") or typeof(PlayerPartyState.quest_data["active"]) != TYPE_DICTIONARY:
		PlayerPartyState.quest_data["active"] = {}
	if not PlayerPartyState.quest_data.has("completed") or typeof(PlayerPartyState.quest_data["completed"]) != TYPE_ARRAY:
		PlayerPartyState.quest_data["completed"] = []


func _ensure_inventory() -> void:
	if typeof(PlayerPartyState.inventory_data) != TYPE_DICTIONARY:
		PlayerPartyState.inventory_data = {}
	if not PlayerPartyState.inventory_data.has("gold"):
		PlayerPartyState.inventory_data["gold"] = 0
	if not PlayerPartyState.inventory_data.has("items") or typeof(PlayerPartyState.inventory_data["items"]) != TYPE_ARRAY:
		PlayerPartyState.inventory_data["items"] = []


func _load_definition_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("QuestManager: cannot read %s" % path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("QuestManager: invalid JSON %s" % path)
		return
	var id := str(parsed.get("id", ""))
	if id.is_empty():
		push_warning("QuestManager: missing id in %s" % path)
		return
	if not parsed.has("category"):
		parsed["category"] = "side"
	_definitions[id] = parsed


func _notify_changed(autosave_reason: String) -> void:
	quests_changed.emit()
	if PlayerPartyState != null and PlayerPartyState.has_method("try_autosave"):
		PlayerPartyState.try_autosave(autosave_reason)
