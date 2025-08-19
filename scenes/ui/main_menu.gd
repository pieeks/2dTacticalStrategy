extends Control

var waiting_for_key : String = ""
var rebind_button : Button = null

func _ready() -> void:
	for container in $SettingsPopup/ControlSettingsPopup/ControlSettingsButtonContainer.get_children(): 
		for button in container.get_children(): 
			print(button.has_meta("action_name"))
			if button is Button and button.has_meta("action_name"):
				button.pressed.connect(_on_rebind_button_pressed.bind(button))


func _on_quit_game_pressed() -> void:
	get_tree().quit()


func _on_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(value / 100.0)
	)


func _on_resolution_drop_down_item_selected(index: int) -> void:
	var dropdown = $SettingsPopup/VideoSettingsPopup/VBoxContainer/ResolutionDropDown
	var res_text = dropdown.get_item_text(index)
	var parts = res_text.split('x')
	
	print(str(parts.size))
	
	if parts.size() == 2: 
		var width = int(parts[0])
		var height = int(parts[1])
		
		DisplayServer.window_set_size(Vector2i(width, height))


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_rebind_button_pressed(button: Button): 
	waiting_for_key = button.get_meta("action_name")
	rebind_button = button


func _input(event): 
	if waiting_for_key != "" and event is InputEventKey and event.is_pressed():
		InputMap.action_erase_events(waiting_for_key)
		InputMap.action_add_event(waiting_for_key, event)
		
		if rebind_button: 
			rebind_button.text = event.as_text()
		
		#Reset
		waiting_for_key = ""
		rebind_button = null


func _on_settings_pressed() -> void:
	$SettingsPopup.visible = true
	$ButtonContainer.visible = false


func _on_back_pressed() -> void:
	$SettingsPopup.visible = false
	$ButtonContainer.visible = true


func _on_audio_settings_pressed() -> void:
	$SettingsPopup/SettingsButtonContainer.visible = false
	$SettingsPopup/AudioSettingsPopup.visible = true


func _on_video_settings_pressed() -> void:
	$SettingsPopup/SettingsButtonContainer.visible = false
	$SettingsPopup/VideoSettingsPopup.visible = true


func _on_controls_pressed() -> void:
	$SettingsPopup/SettingsButtonContainer.visible = false
	$SettingsPopup/ControlSettingsPopup.visible = true

func _on_back_to_settings_popup_pressed() -> void:
	$SettingsPopup/SettingsButtonContainer.visible = true
	$SettingsPopup/AudioSettingsPopup.visible = false
	$SettingsPopup/VideoSettingsPopup.visible = false
	$SettingsPopup/ControlSettingsPopup.visible = false
