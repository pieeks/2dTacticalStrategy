## Character Creation UI
##
## This script handles the character creation screen.
## It allows the player to preview and cycle through available
## race, hair, body, and leg options, enter a name, and save
## the resulting character data to persistent storage.
##
## The UI includes left/right buttons for each appearance category,
## as well as a "Create" button that finalizes the character.
##
## Emits:
## - `character_created`: emitted after the character is saved successfully.

extends Control

## Reference to the CharacterAppearance node used for preview.
@onready var character: CharacterAppearance = $CanvasLayer/UIRoot/CharacterPreview/CharacterAppearance

## Index trackers for each appearance category.
var race_index := 0
var hair_index := 0
var body_index := 0
var leg_index := 0

## Signal emitted when a new character has been created and saved.
signal character_created


## Called when the node enters the scene tree.
## Prints debug information about loaded hair options.
func _ready() -> void:
	pass
	# Dev/debug output
	#var hairs = character.hairSprites
	#print("Haare geladen: ", hairs.size())


# --- Race selection ---

## Cycles race selection backwards and updates preview.
func _on_race_left_button_pressed() -> void:
	race_index = (race_index - 1 + character.raceSprites.size()) % character.raceSprites.size()
	var path = character.raceSprites[race_index].resource_path
	character.set_race(path)

## Cycles race selection forwards and updates preview.
func _on_race_right_button_pressed() -> void:
	race_index = (race_index + 1) % character.raceSprites.size()
	var path = character.raceSprites[race_index].resource_path
	character.set_race(path)


# --- Hair selection ---

## Cycles hair selection backwards and updates preview.
func _on_hair_left_button_pressed() -> void:
	hair_index = (hair_index - 1 + character.hairSprites.size()) % character.hairSprites.size()
	var path = character.hairSprites[hair_index].resource_path
	character.set_hair(path)


## Cycles hair selection forwards and updates preview.
func _on_hair_right_button_pressed() -> void:
	hair_index = (hair_index + 1) % character.hairSprites.size()
	var path = character.hairSprites[hair_index].resource_path
	character.set_hair(path)



# --- Body selection ---

## Cycles body selection backwards and updates preview.
func _on_body_left_button_pressed() -> void:
	body_index = (body_index - 1 + character.bodySprites.size()) % character.bodySprites.size()
	var path = character.bodySprites[body_index].resource_path
	character.set_body(path)

## Cycles body selection forwards and updates preview.
func _on_body_right_button_pressed() -> void:
	body_index = (body_index + 1) % character.bodySprites.size()
	var path = character.bodySprites[body_index].resource_path
	character.set_body(path)


# --- Leg selection ---

## Cycles leg selection backwards and updates preview.
func _on_leg_left_button_pressed() -> void:
	leg_index = (leg_index - 1 + character.legSprites.size()) % character.legSprites.size()
	var path = character.legSprites[leg_index].resource_path
	character.set_leg(path)

## Cycles leg selection forwards and updates preview.
func _on_leg_right_button_pressed() -> void:
	leg_index = (leg_index + 1) % character.legSprites.size()
	var path = character.legSprites[leg_index].resource_path
	character.set_leg(path)


# --- Character creation ---

## Called when the "Create" button is pressed.
## Collects selected appearance data, name, and initializes all
## relevant PlayerPartyState/WorldState structures before saving to disk.
##
## Emits: `character_created`
func _on_create_button_pressed() -> void:
	var char_name: String = $CanvasLayer/UIRoot/NameHContainer/NameLineEdit.text.strip_edges()
	if char_name.is_empty():
		push_warning("Character creation aborted: name is empty.")
		return

	var appearance := {
		"race_path": character.raceSprites[race_index].resource_path,
		"hair_path": character.hairSprites[hair_index].resource_path,
		"body_path": character.bodySprites[body_index].resource_path,
		"leg_path": character.legSprites[leg_index].resource_path,
	}

	# Unique folder-safe ID (no display name in path)
	var now_unix := int(Time.get_unix_time_from_system())
	PlayerPartyState.player_id = "%d_%d" % [now_unix, randi()]
	PlayerPartyState.player_data = {
		"name": char_name,
		"appearance": appearance,
	}

	# Meta Data initialize
	PlayerPartyState.meta_data = {
		"created_unix": now_unix,
		"updated_unix": now_unix,
		"game_build": "0.1.0"
	}
	
	# Party Data initialize (leader only at start)
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
	
	# Position Data initialize
	PlayerPartyState.position_data = {
		"x": 0.0,
		"y": 0.0,
	}
	
	# Save Data to disk
	PlayerPartyState.save_to_disk() 
	WorldState.player_id = PlayerPartyState.player_id
	WorldState.save_to_disk()
	
	print("Character created and saved: ", PlayerPartyState.player_data)
	emit_signal("character_created")
	_on_back_to_menu_pressed()


# --- Navigation ---

## Returns back to the main menu scene after character creation.
func _on_back_to_menu_pressed() -> void:
	PlayerPartyState.get_available_character()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
