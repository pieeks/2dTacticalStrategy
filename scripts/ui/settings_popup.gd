extends Control

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
## SettingsPopup
##
## Manages the in-game settings menu and its submenus
## (general, audio, video, controls).

signal popup_closed


func _ready() -> void:
	_apply_static_texts()
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	_apply_static_texts()


func _apply_static_texts() -> void:
	$UIRoot/Name.text = tr("ui.settings.title")
	$UIRoot/Panel/SettingsButtonContainer/GeneralSettings.text = tr("ui.settings.general")
	$UIRoot/Panel/SettingsButtonContainer/AudioSettings.text = tr("ui.settings.audio")
	$UIRoot/Panel/SettingsButtonContainer/VideoSettings.text = tr("ui.settings.video")
	$UIRoot/Panel/SettingsButtonContainer/Controls.text = tr("ui.settings.controls")
	$UIRoot/Panel/SettingsButtonContainer/Back.text = tr("ui.settings.back")
	$UIRoot/Panel/GeneralSettingsPopup/GeneralSettingsButtonContainer/Name.text = tr("ui.settings.general_title")
	$UIRoot/Panel/GeneralSettingsPopup/GeneralSettingsButtonContainer/LanguageLabel.text = tr("ui.settings.language")
	$UIRoot/Panel/GeneralSettingsPopup/GeneralSettingsButtonContainer/BackToSettingsPopup.text = tr("ui.settings.back_to_settings")
	$UIRoot/Panel/AudioSettingsPopup/AudioSettingsButtonContainer/Name.text = tr("ui.settings.audio_title")
	$UIRoot/Panel/AudioSettingsPopup/AudioSettingsButtonContainer/VolumeSliderName.text = tr("ui.settings.volume")
	var music_lbl := $UIRoot/Panel/AudioSettingsPopup/AudioSettingsButtonContainer.get_node_or_null("MusicSliderName") as Label
	if music_lbl:
		music_lbl.text = tr("ui.settings.music")
	var sfx_lbl := $UIRoot/Panel/AudioSettingsPopup/AudioSettingsButtonContainer.get_node_or_null("SfxSliderName") as Label
	if sfx_lbl:
		sfx_lbl.text = tr("ui.settings.sfx")
	$UIRoot/Panel/AudioSettingsPopup/AudioSettingsButtonContainer/BackToSettingsPopup.text = tr("ui.settings.back_to_settings")
	$UIRoot/Panel/VideoSettingsPopup/VideoSettingsButtonContainer/Label.text = tr("ui.settings.video_title")
	$UIRoot/Panel/VideoSettingsPopup/VideoSettingsButtonContainer/ResolutionDropDownName.text = tr("ui.settings.resolution")
	$UIRoot/Panel/VideoSettingsPopup/VideoSettingsButtonContainer/Fullscreen.text = tr("ui.settings.fullscreen")
	$UIRoot/Panel/VideoSettingsPopup/VideoSettingsButtonContainer/BackToSettingsPopup.text = tr("ui.settings.back_to_settings")
	$UIRoot/Panel/ControlSettingsPopup/ControlSettingsButtonContainer/Name.text = tr("ui.settings.controls_title")
	$UIRoot/Panel/ControlSettingsPopup/ControlSettingsButtonContainer/MoveUPContainer/MoveUpName.text = tr("ui.settings.move_up")
	$UIRoot/Panel/ControlSettingsPopup/ControlSettingsButtonContainer/MoveDownContainer/MoveDownName.text = tr("ui.settings.move_down")
	$UIRoot/Panel/ControlSettingsPopup/ControlSettingsButtonContainer/MoveLeftContainer/MoveLeftName.text = tr("ui.settings.move_left")
	$UIRoot/Panel/ControlSettingsPopup/ControlSettingsButtonContainer/MoveRightContainer/MoveRightName.text = tr("ui.settings.move_right")
	var reset_btn := $UIRoot/Panel/ControlSettingsPopup/ControlSettingsButtonContainer.get_node_or_null("ResetControls") as Button
	if reset_btn:
		reset_btn.text = tr("ui.settings.reset_controls")
	$UIRoot/Panel/ControlSettingsPopup/ControlSettingsButtonContainer/BackToSettings.text = tr("ui.settings.back_to_settings")


func _hide_all_submenus() -> void:
	$UIRoot/Panel/GeneralSettingsPopup.visible = false
	$UIRoot/Panel/AudioSettingsPopup.visible = false
	$UIRoot/Panel/VideoSettingsPopup.visible = false
	$UIRoot/Panel/ControlSettingsPopup.visible = false


func _on_general_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	_hide_all_submenus()
	$UIRoot/Panel/GeneralSettingsPopup.visible = true


func _on_audio_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	_hide_all_submenus()
	$UIRoot/Panel/AudioSettingsPopup.visible = true


func _on_video_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	_hide_all_submenus()
	$UIRoot/Panel/VideoSettingsPopup.visible = true


func _on_controls_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = false
	_hide_all_submenus()
	$UIRoot/Panel/ControlSettingsPopup.visible = true


func _on_back_to_settings_pressed() -> void:
	$UIRoot/Panel/SettingsButtonContainer.visible = true
	_hide_all_submenus()


func _on_back_pressed() -> void:
	visible = false
	emit_signal("popup_closed")
