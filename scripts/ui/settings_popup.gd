extends Control

signal popup_closed

func _on_audio_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	$UIRoot/Panel/AudioSettingsPopup.visible = true


func _on_video_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	$UIRoot/Panel/VideoSettingsPopup.visible = true


func _on_controls_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	$UIRoot/Panel/ControlSettingsPopup.visible = true


func _on_back_to_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = true
	$UIRoot/Panel/AudioSettingsPopup.visible = false
	$UIRoot/Panel/VideoSettingsPopup.visible = false
	$UIRoot/Panel/ControlSettingsPopup.visible = false


func _on_back_pressed() -> void:
	visible = false
	emit_signal("popup_closed")
