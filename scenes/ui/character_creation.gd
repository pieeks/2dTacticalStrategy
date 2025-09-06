extends Control

@onready var character: Character = $CanvasLayer/UIRoot/CharacterPreview/Character

var hair_index := 0

signal character_created

func _ready() -> void:
	
	# Dev stuff
	var hairs = character.hairSprites
	print("Haare geladen: ", hairs.size())


func _on_hair_left_button_pressed() -> void:
	hair_index = (hair_index - 1 + character.hairSprites.size()) % character.hairSprites.size()
	var path = character.hairSprites[hair_index].resource_path
	print(hair_index)
	character.set_hair(path)


func _on_hair_right_button_pressed() -> void:
	hair_index = (hair_index + 1) % character.hairSprites.size()
	var path = character.hairSprites[hair_index].resource_path
	print(hair_index)
	character.set_hair(path)


func _on_create_button_pressed() -> void:
	var appearance := {
		"hair_path": character.hairSprites[hair_index].resource_path,
		"body_path": "", # später Ergänzen 
		"leg_path": ""   # später Ergänzen 
	}
	# Player Data
	PlayerPartyState.player_id = "player_guid_1234" + $CanvasLayer/UIRoot/NameHContainer/NameLineEdit.text #Später Generieren!
	PlayerPartyState.player_data = {
		"name": $CanvasLayer/UIRoot/NameHContainer/NameLineEdit.text, 
		"appearance": appearance,
	}
	# Meta Data initialize
	PlayerPartyState.meta_data = {
			"created_unix": Time.get_unix_time_from_system(),
			"game_build": "0.1.0"
		}
	# Party Data initialize
	PlayerPartyState.party_data = {
		"leader_id": PlayerPartyState.player_id,
		"members": [
			{
				"id": PlayerPartyState.player_id,
				"name": PlayerPartyState.player_data["name"],
				"role": "leader",
				"appearance": appearance, 
				"stats": {},
				"equipment": {}
			}
		]
	}
	# Inventory Data initialize
	PlayerPartyState.inventory_data = {
		"gold": 50,
		"items": {}
	}
	# Position Data initialzie
	PlayerPartyState.position_data = {
		"x": 0.0,
		"y": 0.0,
	}
	# Save Data
	PlayerPartyState.save_to_disk() 
	WorldState.player_id = PlayerPartyState.player_id
	WorldState.save_to_disk()
	print("Character created and saved: ", PlayerPartyState.player_data)
	emit_signal("character_created")
	_on_back_to_menu_pressed()


func _on_back_to_menu_pressed() -> void:
	PlayerPartyState.get_available_character()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
