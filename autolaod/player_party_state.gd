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

## Party-related data (members, roles, stats).
## NOTE: This is initialized with a default `{x, y}` which may be a bug,
##       since party_data should probably be a dictionary with members.
var party_data : Dictionary = {"x": 0.0, "y": 0.0}

## Inventory data (gold, items).
var inventory_data : Dictionary = {}

## Base folder for all savegames (inside user://).
var base_path : String = "user://saveGames/"

## Currently selected character ID (used in menus).
var selected_character_id : String = ""

## List of all available characters found on disk.
## Each entry is a dictionary containing id, name, level, update_unix, and path.
var available_characters : Array = []


## Called when the singleton is initialized.
## Prints debug info and refreshes available characters.
func _ready() -> void:
	print("PlayerPartyState available!")
	get_available_character()


## Saves the current state to disk as JSON.
## Creates the save folder if necessary.
##
## @return bool: True if save succeeded, false otherwise.
func save_to_disk() -> bool: 
	var save_data := {
		"save_version": 1.0,
		"player_id": player_id,
		"meta" : meta_data,
		"position" : position_data,
		"player": player_data,
		"party": party_data,
		"inventory": inventory_data
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
func load_form_disk(pid: String) -> bool: 
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
	player_id = pid
	
	print("Save loaded: ", player_id)
	return true


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
	return available_characters


## Updates the stored position for the current player.
##
## @param pos Vector2: The new position of the player.
func update_position(pos: Vector2) -> void:
	position_data = {"x": pos.x, "y": pos.y}
