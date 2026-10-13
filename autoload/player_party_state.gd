extends Node

## PlayerPartyState
##
## Global singleton for managing player party state, savegames, and character data.
##
## Features:
## - Stores player, meta, position, party, and inventory data
## - Saves and loads persistent save files in JSON format
## - Provides helper to list available characters from disk
## - Keeps track of currently selected character
##
## Usage:
## - Add as an Autoload in Project Settings
## - Use `save_to_disk()` to persist player state
## - Use `load_from_disk(pid)` to restore state
## - Use `get_available_character()` to populate UI lists
## - Update position with `update_position(Vector2)`

## Unique identifier for the current player.
var player_id := ""

## Data dictionary storing player-specific information (name, appearance, etc.).
var player_data : Dictionary = {}

## Metadata dictionary (e.g. save timestamps, build version).
var meta_data : Dictionary = {}

## Position dictionary storing current world position `{x, y}`.
var position_data : Dictionary = {}

## Party-related data (leader_id, members, max_size). Filled on character creation.
var party_data: Dictionary = {}

const DEFAULT_PARTY_MAX_SIZE := 4

## Inventory data (gold, items).
var inventory_data : Dictionary = {}

## Quest runtime: { "active": { id: entry }, "completed": [ids] }.
var quest_data : Dictionary = { "active": {}, "completed": [] }

## Base folder for all savegames (inside user://).
var base_path : String = "user://saveGames/"

## Currently selected character ID (used in menus).
var selected_character_id : String = ""

## List of all available characters found on disk.
## Each entry is a dictionary containing id, name, level, update_unix, and path.
var available_characters : Array = []

const AUTOSAVE_INTERVAL_SEC := 45.0

var _autosave_enabled: bool = false
var _autosave_accum: float = 0.0
## Ensures rapid add_companion calls never collide on the same id.
var _companion_id_seq: int = 0


## Called when the singleton is initialized.
## Prints debug info and refreshes available characters.
func _ready() -> void:
	print("PlayerPartyState available!")
	get_available_character()
	# Intercept window close so we can autosave first.
	var tree := get_tree()
	if tree != null:
		tree.set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		try_autosave("wm_close")
		var tree := get_tree()
		if tree != null:
			tree.quit()


func _process(delta: float) -> void:
	if not _autosave_enabled:
		return
	if player_id == "":
		return
	_autosave_accum += delta
	if _autosave_accum < AUTOSAVE_INTERVAL_SEC:
		return
	_autosave_accum = 0.0
	try_autosave("interval")


## Enable/disable periodic autosave (Overworld on, Main Menu off).
func enable_autosave(enabled: bool) -> void:
	_autosave_enabled = enabled
	_autosave_accum = 0.0


## Persist current party state if a character is loaded. Returns true on write.
func try_autosave(reason: String = "") -> bool:
	if player_id == "":
		return false
	_sync_position_from_overworld_player()
	meta_data["updated_unix"] = int(Time.get_unix_time_from_system())
	var ok := save_to_disk()
	if ok:
		print("PlayerPartyState: autosave ok reason=", reason if reason != "" else "manual")
	return ok


func _sync_position_from_overworld_player() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	var players: Node = tree.root.get_node_or_null("Overworld/Players")
	if players == null:
		return
	var local_id := multiplayer.get_unique_id()
	var player: Node2D = players.get_node_or_null(str(local_id)) as Node2D
	if player != null:
		update_position(player.global_position)


## Saves the current state to disk as JSON.
## Creates the save folder if necessary.
##
## @return bool: True if save succeeded, false otherwise.
func save_to_disk() -> bool: 
	_normalize_inventory()
	_normalize_quest_data()
	_normalize_party_data()
	var save_data := {
		"save_version": 1.0,
		"player_id": player_id,
		"meta" : meta_data,
		"position" : position_data,
		"player": player_data,
		"party": party_data,
		"inventory": inventory_data,
		"quests": quest_data
	}
	var path := base_path + player_id + "/save.json"
	if not DirAccess.dir_exists_absolute(base_path + player_id):
		var err := DirAccess.make_dir_recursive_absolute(base_path + player_id)
		if err != OK:
			push_error("Failed to create save folder: " + base_path + player_id)
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: 
		push_error("Error: could not open save file! " + path)
		return false
	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	print("Save written at: ", path)
	return true


## Loads a savegame from disk by player ID.
##
## @param pid String: The player ID whose save should be loaded.
## @return bool: True if load succeeded, false otherwise.
func load_from_disk(pid: String) -> bool: 
	var path = base_path + pid + "/save.json"
	if not FileAccess.file_exists(path):
		push_error("No save found at: " + path)
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: 
		push_error("Could not open file: " + path)
		return false
	
	var txt = file.get_as_text()
	file.close()
	
	var parsed := JSON.parse_string(txt) as Dictionary
	if typeof(parsed) != TYPE_DICTIONARY: 
		push_error("Save file invalid or corrupted: " + path)
		return false
	
	player_data = parsed.get("player", {})
	meta_data = parsed.get("meta", {})
	position_data = parsed.get("position", {})
	party_data = parsed.get("party", {})
	inventory_data = parsed.get("inventory", {})
	quest_data = parsed.get("quests", { "active": {}, "completed": [] })
	player_id = pid
	_normalize_inventory()
	_normalize_quest_data()
	_normalize_party_data()
	
	print("Save loaded: ", player_id)
	return true


## Ensure inventory has gold/items keys.
func _normalize_inventory() -> void:
	if typeof(inventory_data) != TYPE_DICTIONARY:
		inventory_data = {}
	if not inventory_data.has("gold"):
		inventory_data["gold"] = 0
	if not inventory_data.has("items") or typeof(inventory_data["items"]) != TYPE_ARRAY:
		inventory_data["items"] = []


## Ensure quest_data shape is valid.
func _normalize_quest_data() -> void:
	if typeof(quest_data) != TYPE_DICTIONARY:
		quest_data = {}
	if not quest_data.has("active") or typeof(quest_data["active"]) != TYPE_DICTIONARY:
		quest_data["active"] = {}
	if not quest_data.has("completed") or typeof(quest_data["completed"]) != TYPE_ARRAY:
		quest_data["completed"] = []


## Public entry: ensure party_data shape is valid (call after creation / edits).
func ensure_party_data() -> void:
	_normalize_party_data()


## Ensure party_data has leader_id, members[], max_size.
func _normalize_party_data() -> void:
	if typeof(party_data) != TYPE_DICTIONARY:
		party_data = {}
	if not party_data.has("members") or typeof(party_data["members"]) != TYPE_ARRAY:
		party_data["members"] = []
	var members: Array = party_data["members"]
	var normalized_members: Array = []
	for raw in members:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = (raw as Dictionary).duplicate(true)
		if not m.has("id"):
			m["id"] = str(m.get("name", player_id if player_id != "" else "member"))
		if not m.has("role"):
			m["role"] = "companion"
		if not m.has("name"):
			m["name"] = str(m.get("id", "Unknown"))
		if not m.has("appearance") or typeof(m["appearance"]) != TYPE_DICTIONARY:
			m["appearance"] = {}
		if not m.has("stats") or typeof(m["stats"]) != TYPE_DICTIONARY:
			m["stats"] = {}
		if not m.has("equipment") or typeof(m["equipment"]) != TYPE_DICTIONARY:
			m["equipment"] = {}
		normalized_members.append(m)
	party_data["members"] = normalized_members
	var max_size := int(party_data.get("max_size", DEFAULT_PARTY_MAX_SIZE))
	if max_size < 1:
		max_size = DEFAULT_PARTY_MAX_SIZE
	party_data["max_size"] = max_size
	var leader_id := str(party_data.get("leader_id", ""))
	if leader_id.is_empty() or get_member(leader_id).is_empty():
		leader_id = ""
		for m2 in normalized_members:
			if str(m2.get("role", "")) == "leader":
				leader_id = str(m2.get("id", ""))
				break
		if leader_id.is_empty() and not normalized_members.is_empty():
			leader_id = str(normalized_members[0].get("id", ""))
			normalized_members[0]["role"] = "leader"
		if leader_id.is_empty() and player_id != "":
			leader_id = player_id
	party_data["leader_id"] = leader_id


## All party members (normalized copy is not required; returns live array).
func get_members() -> Array:
	_normalize_party_data()
	return party_data.get("members", [])


## Leader member dict, or empty if none.
func get_leader() -> Dictionary:
	_normalize_party_data()
	var leader_id := str(party_data.get("leader_id", ""))
	if leader_id != "":
		var by_id := get_member(leader_id)
		if not by_id.is_empty():
			return by_id
	for m in get_members():
		if typeof(m) == TYPE_DICTIONARY and str(m.get("role", "")) == "leader":
			return m as Dictionary
	return {}


## Member by id, or empty dict.
func get_member(member_id: String) -> Dictionary:
	if member_id.is_empty():
		return {}
	if typeof(party_data) != TYPE_DICTIONARY:
		return {}
	var members = party_data.get("members", [])
	if typeof(members) != TYPE_ARRAY:
		return {}
	for m in members:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("id", "")) == member_id:
			return m as Dictionary
	return {}


func get_party_max_size() -> int:
	_normalize_party_data()
	return int(party_data.get("max_size", DEFAULT_PARTY_MAX_SIZE))


## Append a companion if under max_size. Returns false if full or invalid.
func add_companion(data: Dictionary) -> bool:
	_normalize_party_data()
	var members: Array = party_data["members"]
	if members.size() >= get_party_max_size():
		return false
	if data.is_empty():
		return false
	var entry: Dictionary = data.duplicate(true)
	var new_id := str(entry.get("id", "")).strip_edges()
	if new_id.is_empty() or _member_id_exists(new_id):
		new_id = _make_unique_companion_id()
	entry["id"] = new_id
	if str(entry.get("role", "")) == "leader":
		entry["role"] = "companion"
	elif not entry.has("role"):
		entry["role"] = "companion"
	if not entry.has("name"):
		entry["name"] = str(entry.get("id", "Companion"))
	if not entry.has("appearance") or typeof(entry["appearance"]) != TYPE_DICTIONARY:
		entry["appearance"] = {}
	if not entry.has("stats") or typeof(entry["stats"]) != TYPE_DICTIONARY:
		entry["stats"] = {}
	if not entry.has("equipment") or typeof(entry["equipment"]) != TYPE_DICTIONARY:
		entry["equipment"] = {}
	members.append(entry)
	party_data["members"] = members
	_normalize_party_data()
	return true


func _member_id_exists(member_id: String) -> bool:
	for m in party_data.get("members", []):
		if typeof(m) == TYPE_DICTIONARY and str(m.get("id", "")) == member_id:
			return true
	return false


func _make_unique_companion_id() -> String:
	_companion_id_seq += 1
	var candidate := "companion_%d_%d" % [Time.get_ticks_msec(), _companion_id_seq]
	while _member_id_exists(candidate):
		_companion_id_seq += 1
		candidate = "companion_%d_%d" % [Time.get_ticks_msec(), _companion_id_seq]
	return candidate


## Remove a non-leader member by id. Returns false if missing or target is leader.
func remove_companion(member_id: String) -> bool:
	_normalize_party_data()
	if member_id.is_empty():
		return false
	var leader_id := str(party_data.get("leader_id", ""))
	if member_id == leader_id:
		return false
	var members: Array = party_data["members"]
	for i in range(members.size()):
		var m: Variant = members[i]
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if str(m.get("id", "")) != member_id:
			continue
		if str(m.get("role", "")) == "leader":
			return false
		members.remove_at(i)
		party_data["members"] = members
		_normalize_party_data()
		return true
	return false


## Remove the last companion (non-leader). Returns false if none.
func remove_last_companion() -> bool:
	_normalize_party_data()
	var members: Array = party_data["members"]
	for i in range(members.size() - 1, -1, -1):
		var m: Variant = members[i]
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if str(m.get("role", "")) == "leader":
			continue
		var mid := str(m.get("id", ""))
		return remove_companion(mid)
	return false


## Remove all non-leader members. Returns how many were removed.
func clear_companions() -> int:
	_normalize_party_data()
	var members: Array = party_data["members"]
	var kept: Array = []
	var removed := 0
	for m in members:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if str(m.get("role", "")) == "leader":
			kept.append(m)
		else:
			removed += 1
	party_data["members"] = kept
	_normalize_party_data()
	return removed


## True when at least one member has a stats dictionary (fight-ready placeholder).
func is_party_fight_ready() -> bool:
	for m in get_members():
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var stats = m.get("stats", {})
		if typeof(stats) == TYPE_DICTIONARY and not (stats as Dictionary).is_empty():
			return true
	return false


## Snapshot for later fight sync (§5b). Does not start fights.
func build_party_roster_snapshot() -> Array:
	var roster: Array = []
	for m in get_members():
		if typeof(m) != TYPE_DICTIONARY:
			continue
		roster.append({
			"member_id": str(m.get("id", "")),
			"role": str(m.get("role", "companion")),
			"name": str(m.get("name", "")),
			"appearance": (m.get("appearance", {}) as Dictionary).duplicate(true) if typeof(m.get("appearance", {})) == TYPE_DICTIONARY else {},
			"stats": (m.get("stats", {}) as Dictionary).duplicate(true) if typeof(m.get("stats", {})) == TYPE_DICTIONARY else {},
		})
	return roster


## Scans save folder for available characters.
## Builds a list of entries containing metadata for each save.
##
## @return Array: List of dictionaries with character info.
func get_available_character() -> Array: 
	available_characters.clear() 
	
	if not DirAccess.dir_exists_absolute(base_path): 
		return available_characters
	
	var dir := DirAccess.open(base_path)
	if dir == null:
		push_error("Could not open folder: " + base_path)
		return available_characters
	
	dir.list_dir_begin()
	var subfolder := dir.get_next()
	while subfolder != "": 
		if dir.current_is_dir() and not subfolder.begins_with("."):
			var save_path := base_path + subfolder + "/save.json"
			if FileAccess.file_exists(save_path):
				var file := FileAccess.open(save_path, FileAccess.READ)
				if file != null:
					var parsed := JSON.parse_string(file.get_as_text()) as Dictionary
					file.close()
					
					if typeof(parsed) == TYPE_DICTIONARY:
						var player = parsed.get("player", {})
						var party = parsed.get("party", {})
						var members: Array = party.get("members", [])
						var level := 1
						if not members.is_empty() and typeof(members[0]) == TYPE_DICTIONARY:
							level = members[0].get("stats", {}).get("level", 1)
						var meta: Dictionary = parsed.get("meta", {})
						var entry := {
							"id": subfolder,
							"name": player.get("name", "Unknown"),
							"level": level,
							"update_unix": meta.get("updated_unix", meta.get("created_unix", 0)),
							"path": save_path
						}
						available_characters.append(entry)
		subfolder = dir.get_next()
	dir.list_dir_end()
	available_characters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("update_unix", 0)) > int(b.get("update_unix", 0))
	)
	return available_characters


## Creates a new character save from display name + appearance dict. Returns true on success.
func create_new_character(char_name: String, appearance: Dictionary) -> bool:
	var now_unix := int(Time.get_unix_time_from_system())
	player_id = "%d_%d" % [now_unix, randi()]
	player_data = {
		"name": char_name,
		"appearance": appearance.duplicate(true),
	}
	meta_data = {
		"created_unix": now_unix,
		"updated_unix": now_unix,
		"game_build": "0.1.0",
	}
	party_data = {
		"leader_id": player_id,
		"max_size": DEFAULT_PARTY_MAX_SIZE,
		"members": [
			{
				"id": player_id,
				"name": char_name,
				"role": "leader",
				"appearance": appearance.duplicate(true),
				"stats": {
					"level": 1,
					"health": 100,
					"minDamage": 8,
					"maxDamage": 14,
					"initiative": 10,
					"move": 3,
					"attack_range": 1,
				},
				"equipment": {},
			}
		],
	}
	ensure_party_data()
	inventory_data = {"gold": 50, "items": []}
	position_data = {"x": 0.0, "y": 0.0}
	quest_data = {"active": {}, "completed": []}
	if not save_to_disk():
		return false
	WorldState.player_id = player_id
	WorldState.save_to_disk()
	selected_character_id = player_id
	return true


## Deletes a character save folder. Returns true if removed.
func delete_character(pid: String) -> bool:
	var id := pid.strip_edges()
	if id.is_empty() or id.contains("..") or id.contains("/") or id.contains("\\"):
		return false
	var folder := base_path + id
	if not DirAccess.dir_exists_absolute(folder):
		return false
	_remove_dir_recursive(folder)
	if selected_character_id == id:
		selected_character_id = ""
	if player_id == id:
		player_id = ""
	get_available_character()
	return not DirAccess.dir_exists_absolute(folder)


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child := path.path_join(name)
		if dir.current_is_dir():
			_remove_dir_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


## Updates the stored position for the current player.
##
## @param pos Vector2: The new position of the player.
func update_position(pos: Vector2) -> void:
	position_data = {"x": pos.x, "y": pos.y}
