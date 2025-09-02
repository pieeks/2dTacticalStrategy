extends Control

@onready var character_list: VBoxContainer = $ScrollContainer/CharacterListVBoxContainer

func _ready() -> void: 
	for char_entry in PlayerPartyState.available_characters:
		_add_character_entry(char_entry)


func _add_character_entry(data: Dictionary) -> void:
	var row = HBoxContainer.new()
	var name_label = Label.new()
	var lvl_label = Label.new()
	
	name_label.text = data.get("name", "Unbekannt")
	lvl_label.text = "lvl: " + str(data.get("level", 1))
	
	row.add_child(name_label)
	row.add_child(lvl_label)
	
	character_list.add_child(row)
