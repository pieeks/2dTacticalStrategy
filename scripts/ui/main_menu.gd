extends Control

@onready var settings_popup: Control = $CanvasLayer/SettingsPopup
@onready var character_list_control: Control = $CanvasLayer/UIRoot/Panel/CharacterListControl
var level_scene: PackedScene

const LEVEL_SCENE_PATH := "res://_dev/tests/test_scene_tilemap_multiplayer.tscn"


func _ready() -> void:
	level_scene = load(LEVEL_SCENE_PATH)
	$CanvasLayer/UIRoot/Panel/ButtonContainer/WorldSelection.disabled = true
	settings_popup.connect("popup_closed", Callable(self, "_on_back_pressed"))
	if PlayerPartyState.available_characters.size() > 0:
		_enable_world_selection()


func _on_quit_game_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	$CanvasLayer/SettingsPopup.visible = false
	$CanvasLayer/UIRoot/Panel/ButtonContainer.visible = true
	$CanvasLayer/UIRoot/Panel/CharacterListControl.visible = true
	$CanvasLayer/UIRoot/Label.visible = true


func _on_settings_pressed() -> void:
	$CanvasLayer/SettingsPopup.visible = true
	$CanvasLayer/UIRoot/Panel/ButtonContainer.visible = false
	$CanvasLayer/UIRoot/Panel/CharacterListControl.visible = false
	$CanvasLayer/UIRoot/Label.visible = false


func _enable_world_selection() -> void:
	$CanvasLayer/UIRoot/Panel/ButtonContainer/WorldSelection.disabled = false


func _on_lobby_joined() -> void:
	get_tree().change_scene_to_packed(level_scene)


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/world_selection.tscn")


func _on_create_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")
