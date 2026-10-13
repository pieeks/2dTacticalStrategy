## Character selection list with select + delete.
extends Control

const GameSettingsScript := preload("res://scripts/ui/game_settings.gd")
const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")

@onready var character_list: VBoxContainer = $ScrollContainer/CharacterListVBoxContainer

var selected_row: Control = null
var _delete_dialog: ConfirmationDialog


func _ready() -> void:
	_ensure_delete_dialog()
	refresh_list()
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	refresh_list()


## Rebuild the list from PlayerPartyState.available_characters.
func refresh_list() -> void:
	PlayerPartyState.get_available_character()
	for child in character_list.get_children():
		child.queue_free()
	selected_row = null
	for char_entry in PlayerPartyState.available_characters:
		_add_character_entry(char_entry)
	if character_list.get_child_count() > 0 and not PlayerPartyState.available_characters.is_empty():
		var first_row: Control = character_list.get_child(0)
		_select_row(first_row, PlayerPartyState.available_characters[0])


func _ensure_delete_dialog() -> void:
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.ok_button_text = tr("ui.character_list.delete_confirm_ok")
	add_child(_delete_dialog)
	_delete_dialog.confirmed.connect(_on_delete_confirmed)


func _add_character_entry(data: Dictionary) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	var lvl_label := Label.new()
	var delete_btn := Button.new()
	name_label.text = str(data.get("name", tr("ui.character_list.unknown")))
	lvl_label.text = tr("ui.character_list.level") % [int(data.get("level", 1))]
	delete_btn.text = tr("ui.character_list.delete")
	delete_btn.pressed.connect(_on_delete_pressed.bind(data))
	row.add_child(name_label)
	row.add_child(lvl_label)
	row.add_child(delete_btn)
	row.gui_input.connect(_on_character_row_clicked.bind(row, data))
	character_list.add_child(row)


func _on_character_row_clicked(event: InputEvent, row: Control, data: Dictionary) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		_select_row(row, data)


func _select_row(row: Control, data: Dictionary) -> void:
	if selected_row:
		selected_row.modulate = Color(1, 1, 1)
	selected_row = row
	selected_row.modulate = Color(0.85, 0.75, 0.45)
	PlayerPartyState.selected_character_id = str(data.get("id", ""))
	GameSettingsScript.set_last_character_id(PlayerPartyState.selected_character_id)


func _on_delete_pressed(data: Dictionary) -> void:
	_delete_dialog.set_meta("pending_id", str(data.get("id", "")))
	_delete_dialog.title = tr("ui.character_list.delete_title")
	_delete_dialog.dialog_text = tr("ui.character_list.delete_confirm") % [str(data.get("name", ""))]
	_delete_dialog.ok_button_text = tr("ui.character_list.delete_confirm_ok")
	_delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	var pid := str(_delete_dialog.get_meta("pending_id", ""))
	if pid.is_empty():
		return
	if PlayerPartyState.delete_character(pid):
		GameSettingsScript.clear_last_character_id_if(pid)
	refresh_list()
	var menu := get_tree().current_scene
	if menu != null and menu.has_method("_refresh_continue_and_world"):
		menu._refresh_continue_and_world()
