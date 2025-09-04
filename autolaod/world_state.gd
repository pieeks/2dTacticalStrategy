extends Node

var world_id : String = ""
var player_id : String = ""
var meta_data : Dictionary = {}
var general_data : Dictionary = {}
var cities_data : Dictionary = {}
var dungeons_data : Dictionary = {}
var events_data : Dictionary = {}
var base_path : String = "user://saveGames/"

func _ready() -> void:
	pass


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
			push_error("Konnte Save-Ordner nicht erstellen: " + base_path + player_id)
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: 
		push_error("Fehler: Save-Datei konnte nicht geöffnet werden! ", path)
		return false
	var  json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("Save geschrieben unter: ", path)
	return true


func load_from_disk(pid: String) -> bool:
	var path = base_path + pid + "/world_save.json"
	if not FileAccess.file_exists(path):
		push_error("Kein Save gefunden unter: " + path)
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: 
		push_error("Konnte Datei nicht öffnen: " + path)
		return false
	
	var txt = file.get_as_text()
	file.close()
	
	var parsed := JSON.parse_string(txt) as Dictionary
	if typeof(parsed) != TYPE_DICTIONARY: 
		push_error("Save-Datei ungültig oder beschädigt: " + path)
		return false
	
	world_id = parsed.get("world_id", {})
	player_id = parsed.get("player_id", {})
	meta_data = parsed.get("meta", {})
	general_data = parsed.get("general", {})
	cities_data = parsed.get("cities", {})
	dungeons_data = parsed.get("dungeons", {})
	events_data = parsed.get("events", {})
	
	print("Save geladen: ", player_id)
	return true
