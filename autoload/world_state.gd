extends Node

## WorldState
##
## Global singleton for managing world-related save data.
## Stores and persists information about the world state, including:
## - Metadata
## - General world data
## - Cities
## - Dungeons
## - Events
##
## Features:
## - Saves world state to JSON in user://saveGames/[player_id]/world_save.json
## - Loads world state back from disk
## - Keeps world state tied to a specific player_id
##
## Usage:
## - Add as an Autoload in Project Settings
## - Call `save_to_disk()` to persist world data
## - Call `load_from_disk(pid)` to restore world data for a given player

## Unique ID for the world.
var world_id : String = ""

## Player ID this world save belongs to.
var player_id : String = ""

## Metadata dictionary (e.g. created_unix, game_build).
var meta_data : Dictionary = {}

## General world information (e.g. biome progress, time).
var general_data : Dictionary = {}

## Cities-related state (ownership, upgrades, quests).
var cities_data : Dictionary = {}

## Dungeons-related state (cleared floors, boss flags).
var dungeons_data : Dictionary = {}

## Events-related state (triggered events, flags).
var events_data : Dictionary = {}

## Base path for save files.
var base_path : String = "user://saveGames/"


## Called when the node enters the scene tree.
func _ready() -> void:
	pass


## Saves the current world state to disk.
## Creates save folder if needed.
##
## @return bool: True if save succeeded, false otherwise.
func save_to_disk() -> bool: 
	var save_data := {
		"world_id": world_id,
		"player_id": player_id,
		"meta": meta_data,
		"general": general_data,
		"cities": cities_data,
		"dungeons": dungeons_data,
		"events": events_data,
	}
	
	var path := base_path + player_id + "/world_save.json"
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
	
	print("World save written at: ", path)
	return true


## Loads world state from disk for a given player ID.
##
## @param pid String: The player_id to load world data for.
## @return bool: True if load succeeded, false otherwise.
func load_from_disk(pid: String) -> bool:
	var path = base_path + pid + "/world_save.json"
	if not FileAccess.file_exists(path):
		push_error("No world save found at: " + path)
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: 
		push_error("Could not open file: " + path)
		return false
	
	var txt = file.get_as_text()
	file.close()
	
	var parsed := JSON.parse_string(txt) as Dictionary
	if typeof(parsed) != TYPE_DICTIONARY: 
		push_error("World save file invalid or corrupted: " + path)
		return false
	
	world_id = parsed.get("world_id", {})
	player_id = parsed.get("player_id", {})
	meta_data = parsed.get("meta", {})
	general_data = parsed.get("general", {})
	cities_data = parsed.get("cities", {})
	dungeons_data = parsed.get("dungeons", {})
	events_data = parsed.get("events", {})
	
	print("World save loaded: ", player_id)
	return true
