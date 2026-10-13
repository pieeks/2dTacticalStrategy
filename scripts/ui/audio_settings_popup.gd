## Audio settings: Master / Music / SFX volume sliders with persistence.
extends Control

const GameSettingsScript := preload("res://scripts/ui/game_settings.gd")

@onready var _master: HSlider = $AudioSettingsButtonContainer/VolumeSlider
@onready var _music: HSlider = $AudioSettingsButtonContainer/MusicSlider
@onready var _sfx: HSlider = $AudioSettingsButtonContainer/SfxSlider

var _syncing: bool = false


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_sync_from_store()


func _on_visibility_changed() -> void:
	if visible:
		_sync_from_store()


func _sync_from_store() -> void:
	_syncing = true
	if _master:
		_master.value = GameSettingsScript.get_master_linear() * 100.0
	if _music:
		_music.value = GameSettingsScript.get_music_linear() * 100.0
	if _sfx:
		_sfx.value = GameSettingsScript.get_sfx_linear() * 100.0
	_syncing = false


func _on_volume_slider_value_changed(value: float) -> void:
	if _syncing:
		return
	GameSettingsScript.set_master_linear(value / 100.0)


func _on_music_slider_value_changed(value: float) -> void:
	if _syncing:
		return
	GameSettingsScript.set_music_linear(value / 100.0)


func _on_sfx_slider_value_changed(value: float) -> void:
	if _syncing:
		return
	GameSettingsScript.set_sfx_linear(value / 100.0)
