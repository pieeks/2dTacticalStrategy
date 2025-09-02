extends Control

@onready var character_list: VBoxContainer = $ScrollContainer/CharacterListVBoxContainer
var selected_row: Control = null

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
	row.gui_input.connect(_on_character_row_clicked.bind(row, data))
	
	character_list.add_child(row)


func _on_character_row_clicked(event: InputEvent, row: Control, data: Dictionary) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_row: 
			selected_row.modulate = Color(1, 1, 1) 
		selected_row = row 
		selected_row.modulate = Color(0.6, 0.8, 1)
		PlayerPartyState.selected_character_id = data.get("id", "")
		print("Character ausgewählt: ", PlayerPartyState.selected_character_id)
	
