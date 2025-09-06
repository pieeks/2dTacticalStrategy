extends CanvasLayer

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


func _can_pause() -> bool:
	if not multiplayer.is_server():
		return false
	
	var peers := multiplayer.get_peers()
	return peers.size() == 0


func _save_game() -> void:
	if PlayerPartyState:
		PlayerPartyState.save_to_disk()
	#if WorldState: #TODO Save JSON von World Nachladen 
		#WorldState.save_to_disk()


func _on_resume_pressed() -> void:
	_close_menu()


func _on_options_pressed() -> void:
	$UIRoot/Panel/VBoxContainer.visible = false
	$SettingsPopup.visible = true



func _on_back_pressed() -> void:
	$UIRoot/Panel/VBoxContainer.visible = true
	$SettingsPopup.visible = false



func _on_save_and_quit_pressed() -> void:
	print("Save and Quit Button pressed!")
	get_tree().paused = false
	_save_game()
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
