extends Control

## VideoSettings
##
## Handles resolution and fullscreen settings from the video options menu.
##
## Features:
## - Reads resolution strings (e.g. "1920x1080") from a dropdown
## - Changes window size based on selected resolution
## - Toggles fullscreen mode on/off
##
## Usage:
## - Attach this script to your Video Settings UI root node
## - Ensure there is a `ResolutionDropDown` OptionButton inside
##   `$VideoSettingsButtonContainer`
## - Connect dropdown's `item_selected` to `_on_resolution_drop_down_item_selected`
## - Connect fullscreen toggle's `toggled` to `_on_fullscreen_toggled`

## Handles resolution changes when a dropdown item is selected.
##
## @param index int: The index of the selected item in the dropdown.
func _on_resolution_drop_down_item_selected(index: int) -> void:
	var dropdown = $VideoSettingsButtonContainer/ResolutionDropDown
	var res_text = dropdown.get_item_text(index)
	var parts = res_text.split("x")
	
	print(str(parts.size))
	
	if parts.size() == 2: 
		var width = int(parts[0])
		var height = int(parts[1])
		DisplayServer.window_set_size(Vector2i(width, height))


## Handles toggling fullscreen mode on/off.
##
## @param toggled_on bool: True if fullscreen enabled, false if windowed mode.
func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
