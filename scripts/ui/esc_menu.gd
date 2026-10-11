extends CanvasLayer

## Pause Menu UI
##
## ESC toggles the pause menu. Quit autosaves via PlayerPartyState, then
## resets the multiplayer session and returns to the main menu.

@onready var settings_popup: Control = $SettingsPopup


func _ready() -> void:
	visible = false
	settings_popup.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_popup.connect("popup_closed", Callable(self, "_on_back_pressed"))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_close_menu()
		else:
			_open_menu()


func _open_menu() -> void:
	visible = true
	if _can_pause():
		get_tree().paused = true
	else:
		get_tree().paused = false


func _close_menu() -> void:
	visible = false
	get_tree().paused = false


## Multiplayer servers should not pause while peers are connected.
func _can_pause() -> bool:
	if not multiplayer.is_server():
		return false
	var peers := multiplayer.get_peers()
	return peers.size() == 0


func _on_resume_pressed() -> void:
	_close_menu()


func _on_options_pressed() -> void:
	$UIRoot/Panel/VBoxContainer.visible = false
	$SettingsPopup.visible = true


func _on_back_pressed() -> void:
	$UIRoot/Panel/VBoxContainer.visible = true
	$SettingsPopup.visible = false


## Quit to main menu; autosave runs inside reset_session / try_autosave.
func _on_quit_pressed() -> void:
	print("Quit pressed — autosave then main menu")
	get_tree().paused = false
	if PlayerPartyState != null and PlayerPartyState.has_method("try_autosave"):
		PlayerPartyState.try_autosave("quit")
	PlayerPartyState.enable_autosave(false)
	# Close peer first so clients get server_disconnected and leave cleanly.
	NetworkManagerTest.reset_session()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
