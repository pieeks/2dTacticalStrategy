extends Control

## SettingsPopup
##
## Manages the in-game settings menu and its submenus (audio, video, controls).
## Handles showing and hiding the different panels and emits a signal when closed.
##
## Features:
## - Opens audio, video, or controls submenus
## - Provides back navigation to the main settings panel
## - Emits `popup_closed` when the entire settings menu is closed
##
## Usage:
## - Attach this script to the root node of the SettingsPopup scene
## - Connect `popup_closed` in the parent (e.g. pause menu) to restore its UI

## Emitted when the settings popup is closed.
signal popup_closed


## Button callback: shows audio settings, hides main settings buttons.
func _on_audio_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	$UIRoot/Panel/AudioSettingsPopup.visible = true


## Button callback: shows video settings, hides main settings buttons.
func _on_video_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	$UIRoot/Panel/VideoSettingsPopup.visible = true


## Button callback: shows control settings, hides main settings buttons.
func _on_controls_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	$UIRoot/Panel/ControlSettingsPopup.visible = true


## Button callback: returns to main settings panel,
## hides all submenu panels.
func _on_back_to_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = true
	$UIRoot/Panel/AudioSettingsPopup.visible = false
	$UIRoot/Panel/VideoSettingsPopup.visible = false
	$UIRoot/Panel/ControlSettingsPopup.visible = false


## Button callback: closes the entire settings popup
## and notifies parent nodes via `popup_closed` signal.
func _on_back_pressed() -> void:
	visible = false
	emit_signal("popup_closed")
