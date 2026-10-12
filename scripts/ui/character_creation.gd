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

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
const AppearanceCatalogScript := preload("res://scripts/characters/appearance_catalog.gd")
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
func _ready() -> void:
	_apply_static_texts()
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	_apply_static_texts()


func _apply_static_texts() -> void:
	$CanvasLayer/UIRoot/Label.text = tr("ui.character_creation.title")
	$CanvasLayer/UIRoot/VBoxContainer/RaceHContainer/Label.text = tr("ui.character_creation.race")
	$CanvasLayer/UIRoot/VBoxContainer/HairHContainer/Label.text = tr("ui.character_creation.hair")
	$CanvasLayer/UIRoot/VBoxContainer/BodyHContainer/Label.text = tr("ui.character_creation.body")
	$CanvasLayer/UIRoot/VBoxContainer/LegHContainer/Label.text = tr("ui.character_creation.leg")
	$CanvasLayer/UIRoot/NameHContainer/Label.text = tr("ui.character_creation.name")
	$CanvasLayer/UIRoot/CreateButton.text = tr("ui.character_creation.create")
	$CanvasLayer/UIRoot/BackToMenu.text = tr("ui.character_creation.back")


# --- Race selection ---

## Cycles race selection backwards and updates preview.
func _on_race_left_button_pressed() -> void:
	var races: Array = AppearanceCatalogScript.race_sprites()
	if races.is_empty():
		return
	race_index = (race_index - 1 + races.size()) % races.size()
	character.set_race(races[race_index].resource_path)

## Cycles race selection forwards and updates preview.
func _on_race_right_button_pressed() -> void:
	var races: Array = AppearanceCatalogScript.race_sprites()
	if races.is_empty():
		return
	race_index = (race_index + 1) % races.size()
	character.set_race(races[race_index].resource_path)


# --- Hair selection ---

## Cycles hair selection backwards and updates preview.
func _on_hair_left_button_pressed() -> void:
	var hairs: Array = AppearanceCatalogScript.hair_sprites()
	if hairs.is_empty():
		return
	hair_index = (hair_index - 1 + hairs.size()) % hairs.size()
	character.set_hair(hairs[hair_index].resource_path)


## Cycles hair selection forwards and updates preview.
func _on_hair_right_button_pressed() -> void:
	var hairs: Array = AppearanceCatalogScript.hair_sprites()
	if hairs.is_empty():
		return
	hair_index = (hair_index + 1) % hairs.size()
	character.set_hair(hairs[hair_index].resource_path)


# --- Body selection ---

## Cycles body selection backwards and updates preview.
func _on_body_left_button_pressed() -> void:
	var bodies: Array = AppearanceCatalogScript.body_sprites()
	if bodies.is_empty():
		return
	body_index = (body_index - 1 + bodies.size()) % bodies.size()
	character.set_body(bodies[body_index].resource_path)

## Cycles body selection forwards and updates preview.
func _on_body_right_button_pressed() -> void:
	var bodies: Array = AppearanceCatalogScript.body_sprites()
	if bodies.is_empty():
		return
	body_index = (body_index + 1) % bodies.size()
	character.set_body(bodies[body_index].resource_path)


# --- Leg selection ---

## Cycles leg selection backwards and updates preview.
func _on_leg_left_button_pressed() -> void:
	var legs: Array = AppearanceCatalogScript.leg_sprites()
	if legs.is_empty():
		return
	leg_index = (leg_index - 1 + legs.size()) % legs.size()
	character.set_leg(legs[leg_index].resource_path)

## Cycles leg selection forwards and updates preview.
func _on_leg_right_button_pressed() -> void:
	var legs: Array = AppearanceCatalogScript.leg_sprites()
	if legs.is_empty():
		return
	leg_index = (leg_index + 1) % legs.size()
	character.set_leg(legs[leg_index].resource_path)


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

	var races: Array = AppearanceCatalogScript.race_sprites()
	var hairs: Array = AppearanceCatalogScript.hair_sprites()
	var bodies: Array = AppearanceCatalogScript.body_sprites()
	var legs: Array = AppearanceCatalogScript.leg_sprites()
	if races.is_empty() or hairs.is_empty() or bodies.is_empty() or legs.is_empty():
		push_warning("Character creation aborted: appearance catalog incomplete.")
		return

	var appearance := {
		"race_path": races[race_index].resource_path,
		"hair_path": hairs[hair_index].resource_path,
		"body_path": bodies[body_index].resource_path,
		"leg_path": legs[leg_index].resource_path,
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
	
	# Party Data initialize (leader only at start). Stats = fight placeholders for §7 v1.
	PlayerPartyState.party_data = {
		"leader_id": PlayerPartyState.player_id,
		"max_size": PlayerPartyState.DEFAULT_PARTY_MAX_SIZE,
		"members": [
			{
				"id": PlayerPartyState.player_id,
				"name": PlayerPartyState.player_data["name"],
				"role": "leader",
				"appearance": appearance,
				"stats": {
					"level": 1,
					"health": 100,
					"minDamage": 8,
					"maxDamage": 14,
					"initiative": 10,
					"move": 3,
					"attack_range": 1,
				},
				"equipment": {}
			}
		]
	}
	PlayerPartyState.ensure_party_data()

	
	# Inventory Data initialize
	PlayerPartyState.inventory_data = {
		"gold": 50,
		"items": [],
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
