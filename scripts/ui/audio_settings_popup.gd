## Volume Slider UI
##
## This script controls the master audio volume based on a UI slider.
## It converts the slider's linear percentage value (0–100) into decibels
## and applies it to the Master audio bus in Godot's AudioServer.
##
## Usage:
## - Attach this script to a Control node with a Slider child.
## - Connect the slider's `value_changed(float)` signal to `_on_volume_slider_value_changed`.
## - Adjusting the slider will update the game's master volume.

extends Control


## Handles changes to the volume slider.
##
## @param value float: The slider value in the range 0–100 (percentage).
## Converts the linear slider value to decibels before applying it to the Master bus.
func _on_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(value / 100.0)
	)
