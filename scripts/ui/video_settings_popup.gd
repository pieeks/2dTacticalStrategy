extends Control

func _on_resolution_drop_down_item_selected(index: int) -> void:
	var dropdown = $VideoSettingsButtonContainer/ResolutionDropDown
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
