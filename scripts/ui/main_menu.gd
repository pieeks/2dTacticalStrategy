extends Control

## Main Menu UI
##
## This script manages the main menu of the game, including:
## - Character list visibility
## - Settings popup
## - Starting the game, quitting, or creating a character
##
## It also enables or disables world selection depending on whether
## a character save exists.

## Reference to the settings popup window.
@onready var settings_popup: Control = $CanvasLayer/SettingsPopup

## Reference to the character list control UI.
@onready var character_list_control: Control = $CanvasLayer/UIRoot/Panel/CharacterListControl

## PackedScene for the default level (loaded in _ready()).
var level_scene: PackedScene

## File path for the test multiplayer level.
const LEVEL_SCENE_PATH := "res://_dev/tests/test_scene_tilemap_multiplayer.tscn"


## Called when the node enters the scene tree.
## Loads the level scene, disables world selection by default,
## connects popup signals, and enables world selection if characters exist.
func _ready() -> void:
	level_scene = load(LEVEL_SCENE_PATH)
	$CanvasLayer/UIRoot/Panel/ButtonContainer/WorldSelection.disabled = true
	settings_popup.connect("popup_closed", Callable(self, "_on_back_pressed"))
	if PlayerPartyState.available_characters.size() > 0:
		_enable_world_selection()


## Button callback: quits the game application.
func _on_quit_game_pressed() -> void:
	get_tree().quit()


## Called when returning from the settings popup.
## Restores visibility of main menu panels and labels.
func _on_back_pressed() -> void:
	$CanvasLayer/SettingsPopup.visible = false
	$CanvasLayer/UIRoot/Panel/ButtonContainer.visible = true
	$CanvasLayer/UIRoot/Panel/CharacterListControl.visible = true
	$CanvasLayer/UIRoot/Label.visible = true


## Button callback: opens the settings popup and hides the main menu panels.
func _on_settings_pressed() -> void:
	$CanvasLayer/SettingsPopup.visible = true
	$CanvasLayer/UIRoot/Panel/ButtonContainer.visible = false
	$CanvasLayer/UIRoot/Panel/CharacterListControl.visible = false
	$CanvasLayer/UIRoot/Label.visible = false


## Enables the world selection button.
## Called when at least one character save is available.
func _enable_world_selection() -> void:
	$CanvasLayer/UIRoot/Panel/ButtonContainer/WorldSelection.disabled = false


## Called when the lobby has been joined successfully.
## Changes the scene to the loaded level scene.
func _on_lobby_joined() -> void:
	get_tree().change_scene_to_packed(level_scene)


## Button callback: goes to the world selection screen.
func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/world_selection.tscn")


## Button callback: goes to the character creation screen.
func _on_create_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")
