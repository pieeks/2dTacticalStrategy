extends Control

const LEVEL_SCENE_PATH := "res://_dev/tests/test_scene_tilemap_multiplayer.tscn"
var level_scene: PackedScene

func _ready() -> void:
	level_scene = load(LEVEL_SCENE_PATH)
	if NetworkManagerTest.has_signal("lobby_joined_finished"):
		NetworkManagerTest.connect("lobby_joined_finished", Callable(self, "_on_lobby_joined"))
	
	var test = PlayerPartyState.available_characters
	print(str(test))
	


func _on_quit_game_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	$CanvasLayer/UIRoot/SettingsPopup.visible = true
	$CanvasLayer/UIRoot/ButtonContainer.visible = false


func _on_back_pressed() -> void:
	$CanvasLayer/UIRoot/SettingsPopup.visible = false
	$CanvasLayer/UIRoot/ButtonContainer.visible = true


func _on_audio_settings_pressed() -> void:
	$CanvasLayer/UIRoot/SettingsPopup/SettingsButtonContainer.visible = false
	$CanvasLayer/UIRoot/SettingsPopup/AudioSettingsPopup.visible = true


func _on_video_settings_pressed() -> void:
	$CanvasLayer/UIRoot/SettingsPopup/SettingsButtonContainer.visible = false
	$CanvasLayer/UIRoot/SettingsPopup/VideoSettingsPopup.visible = true


func _on_controls_pressed() -> void:
	$CanvasLayer/UIRoot/SettingsPopup/SettingsButtonContainer.visible = false
	$CanvasLayer/UIRoot/SettingsPopup/ControlSettingsPopup.visible = true

func _on_back_to_settings_popup_pressed() -> void:
	$CanvasLayer/UIRoot/SettingsPopup/SettingsButtonContainer.visible = true
	$CanvasLayer/UIRoot/SettingsPopup/AudioSettingsPopup.visible = false
	$CanvasLayer/UIRoot/SettingsPopup/VideoSettingsPopup.visible = false
	$CanvasLayer/UIRoot/SettingsPopup/ControlSettingsPopup.visible = false


func _on_lobby_joined() -> void:
	get_tree().change_scene_to_packed(level_scene)

func _on_start_game_pressed() -> void:
	NetworkManagerTest.is_host = true
	NetworkManagerTest.create_lobby()


func _on_create_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")
