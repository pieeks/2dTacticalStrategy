extends Node

var player_id := ""
var player_data : Dictionary = {}
var party_data : Dictionary = {}
var inventory_data : Dictionary = {}
var base_path : String = "user://saveGames/"
var selected_character_id : String = ""

var available_characters : Array = []

func _ready() -> void:
	print("PlayerPartyState available!")
	get_available_character()


func save_to_disk() -> bool: 
	var save_data := {
		"save_version": 1.0,
		"player_id": player_id,
		"player": player_data,
		"party": party_data,
		"inventory": inventory_data
	}
	var path := base_path + player_id + "/save.json"
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


func load_form_disk(pid: String) -> bool: 
	var path = base_path + pid + "/save.json"
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
	
	player_data = parsed.get("player", {})
	party_data = parsed.get("party", {})
	inventory_data = parsed.get("inventory", {})
	player_id = pid
	
	print("Save geladen: ", player_id)
	return true


func get_available_character() -> Array: 
	available_characters.clear() 
	
	if not DirAccess.dir_exists_absolute(base_path): 
		return available_characters
	
	var dir := DirAccess.open(base_path)
	if dir == null:
		push_error("Konnte Ordner nicht öffnen: " + base_path)
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
						var entry := {
							"id": subfolder,
							"name": player.get("name", "Unbekannt"),
							"level": party.get("members", [])[0].get("stats", {}).get("level", 1) if party.has("members") else 1,
							"update_unix": player.get("meta", {}).get("updated_unix", 0),
							"path": save_path
						}
						available_characters.append(entry)
		subfolder = dir.get_next()
	dir.list_dir_end()
	return available_characters
