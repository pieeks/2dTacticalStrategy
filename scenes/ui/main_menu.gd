extends Control

const LEVEL_SCENE_PATH := "res://_dev/tests/test_scene_tilemap_multiplayer.tscn"
var level_scene: PackedScene

func _ready() -> void:
	level_scene = load(LEVEL_SCENE_PATH)
	if NetworkManagerTest.has_signal("lobby_joined_finished"):
		NetworkManagerTest.connect("lobby_joined_finished", Callable(self, "_on_lobby_joined"))
	


func _on_quit_game_pressed() -> void:
	get_tree().quit()


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


func _on_lobby_joined() -> void:
	# Der saubere Weg in Godot 4.x
	get_tree().change_scene_to_packed(level_scene)

func _on_start_game_pressed() -> void:
	NetworkManagerTest.is_host = true
	NetworkManagerTest.create_lobby()
