## Character Selection UI
##
## This script handles the character selection screen.
## It displays a list of available characters from PlayerPartyState
## and allows the user to select one by clicking on its row.
##
## Features:
## - Dynamically creates list entries (name + level)
## - Highlights the selected row
## - Updates PlayerPartyState.selected_character_id when a character is chosen

extends Control

## Container that holds all generated character rows.
@onready var character_list: VBoxContainer = $ScrollContainer/CharacterListVBoxContainer

## Currently selected row in the character list.
var selected_row: Control = null


## Called when the node enters the scene tree.
## Populates the list with all available characters and selects the first one if present.
func _ready() -> void: 
	for char_entry in PlayerPartyState.available_characters:
		_add_character_entry(char_entry)
	
	if character_list.get_child_count() > 0:
		var first_row: Control = character_list.get_child(0)
		var first_data: Dictionary = PlayerPartyState.available_characters[0]
		_select_first_item(first_row, first_data)


## Adds a new row to the character list UI.
##
## @param data Dictionary: character information from PlayerPartyState.
## Expected keys:
## - "id": unique character identifier
## - "name": character name
## - "level": character level
func _add_character_entry(data: Dictionary) -> void:
	var row = HBoxContainer.new()
	var name_label = Label.new()
	var lvl_label = Label.new()
	
	name_label.text = data.get("name", "Unknown")
	lvl_label.text = "lvl: " + str(data.get("level", 1))
	
	row.add_child(name_label)
	row.add_child(lvl_label)
	# Connect mouse input to row click handler
	row.gui_input.connect(_on_character_row_clicked.bind(row, data))
	
	character_list.add_child(row)


## Handles clicks on a character row.
## Highlights the clicked row and updates PlayerPartyState with the selected ID.
##
## @param event InputEvent: The input event received (mouse button press).
## @param row Control: The clicked row container.
## @param data Dictionary: Character data associated with the row.
func _on_character_row_clicked(event: InputEvent, row: Control, data: Dictionary) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# Reset previous selection highlight
		if selected_row: 
			selected_row.modulate = Color(1, 1, 1) 
		# Highlight current row
		selected_row = row 
		selected_row.modulate = Color(0.6, 0.8, 1)
		
		# Update global selection
		PlayerPartyState.selected_character_id = data.get("id", "")
		print("Character selected: ", PlayerPartyState.selected_character_id)


## Highlights and selects the first available character row.
## Called automatically on _ready() if list is not empty.
##
## @param row Control: The row to select.
## @param data Dictionary: The associated character data.
func _select_first_item(row: Control, data: Dictionary) -> void:
	if selected_row: 
		selected_row.modulate = Color(1, 1, 1) 
	selected_row = row 
	selected_row.modulate = Color(0.6, 0.8, 1)
	PlayerPartyState.selected_character_id = data.get("id", "")
	print("Character selected: ", PlayerPartyState.selected_character_id)
