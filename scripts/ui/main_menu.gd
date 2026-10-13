extends Control

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
const GameSettingsScript := preload("res://scripts/ui/game_settings.gd")

@onready var settings_popup: Control = $CanvasLayer/SettingsPopup
@onready var character_list_control: Control = $CanvasLayer/UIRoot/Panel/CharacterListControl


func _ready() -> void:
	GameSettingsScript.apply_boot_settings()
	PlayerPartyState.enable_autosave(false)
	NetworkManagerTest.reset_session()
	PlayerPartyState.get_available_character()
	settings_popup.connect("popup_closed", Callable(self, "_on_back_pressed"))
	_apply_static_texts()
	_refresh_continue_and_world()
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)
	_show_pending_network_message()


func _on_language_changed(_locale: String) -> void:
	_apply_static_texts()
	_refresh_continue_and_world()


func _apply_static_texts() -> void:
	$CanvasLayer/UIRoot/Label.text = tr("ui.main_menu.title")
	$CanvasLayer/UIRoot/Panel/ButtonContainer/WorldSelection.text = tr("ui.main_menu.world_selection")
	$CanvasLayer/UIRoot/Panel/ButtonContainer/CreateCharacter.text = tr("ui.main_menu.new_character")
	$CanvasLayer/UIRoot/Panel/ButtonContainer/Settings.text = tr("ui.main_menu.settings")
	$"CanvasLayer/UIRoot/Panel/ButtonContainer/Quit Game".text = tr("ui.main_menu.quit_game")
	var cont := $CanvasLayer/UIRoot/Panel/ButtonContainer.get_node_or_null("Continue") as Button
	if cont:
		cont.text = tr("ui.main_menu.continue")


## Enables Continue / World based on saves and last character id.
func _refresh_continue_and_world() -> void:
	var has_saves := PlayerPartyState.available_characters.size() > 0
	$CanvasLayer/UIRoot/Panel/ButtonContainer/WorldSelection.disabled = not has_saves
	var cont := $CanvasLayer/UIRoot/Panel/ButtonContainer.get_node_or_null("Continue") as Button
	if cont == null:
		return
	var last_id := GameSettingsScript.get_last_character_id()
	var last_ok := false
	if not last_id.is_empty():
		for entry in PlayerPartyState.available_characters:
			if str(entry.get("id", "")) == last_id:
				last_ok = true
				break
	cont.visible = last_ok
	cont.disabled = not last_ok


func _show_pending_network_message() -> void:
	var msg_key := NetworkManagerTest.take_pending_menu_message()
	if msg_key.is_empty():
		return
	var dialog := AcceptDialog.new()
	dialog.title = tr("ui.net.disconnected_title")
	dialog.dialog_text = tr(msg_key)
	dialog.ok_button_text = tr("ui.net.ok")
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()


func _on_quit_game_pressed() -> void:
	if PlayerPartyState != null and PlayerPartyState.has_method("try_autosave"):
		PlayerPartyState.try_autosave("app_quit")
	get_tree().quit()


func _on_back_pressed() -> void:
	$CanvasLayer/SettingsPopup.visible = false
	$CanvasLayer/UIRoot/Panel/ButtonContainer.visible = true
	$CanvasLayer/UIRoot/Panel/CharacterListControl.visible = true
	$CanvasLayer/UIRoot/Label.visible = true


func _on_settings_pressed() -> void:
	$CanvasLayer/SettingsPopup.visible = true
	$CanvasLayer/UIRoot/Panel/ButtonContainer.visible = false
	$CanvasLayer/UIRoot/Panel/CharacterListControl.visible = false
	$CanvasLayer/UIRoot/Label.visible = false


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/world_selection.tscn")


func _on_continue_pressed() -> void:
	var last_id := GameSettingsScript.get_last_character_id()
	if last_id.is_empty():
		return
	PlayerPartyState.selected_character_id = last_id
	get_tree().change_scene_to_file("res://scenes/ui/world_selection.tscn")


func _on_create_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")
