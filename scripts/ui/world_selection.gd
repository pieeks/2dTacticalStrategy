extends Control

## WorldSelection
##
## UI for choosing how to start or join a multiplayer world.
## Provides options to go back to the main menu, start a new world as host,
## or join an existing world as client.
##
## Features:
## - Loads overworld scene after lobby is created/joined
## - Calls into PlayerPartyState to load selected character data
## - Configures NetworkManagerTest as host or client
##
## Usage:
## - Attach this script to the World Selection scene
## - Connect buttons: Back, Start World, Join World
## - Ensure PlayerPartyState.selected_character_id is set before use

## File path to the overworld scene.
const LEVEL_SCENE_PATH := "res://scenes/world/overworld.tscn"

## PackedScene for the overworld (preloaded in _ready()).
var level_scene: PackedScene


## Called when the node enters the scene tree.
## Preloads the overworld scene and connects to lobby signals.
func _ready() -> void:
	level_scene = preload(LEVEL_SCENE_PATH)
	if NetworkManagerTest.has_signal("lobby_joined_finished"):
		NetworkManagerTest.connect("lobby_joined_finished", Callable(self, "_on_lobby_joined"))


## Button callback: returns to the main menu scene.
func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


## Called when the lobby is successfully joined or created.
## Changes the scene to the loaded overworld.
func _on_lobby_joined() -> void:
	get_tree().change_scene_to_packed(level_scene)


## Button callback: starts a world as host.
## Loads player save data, sets NetworkManagerTest as host, and creates a lobby.
func _on_start_world_pressed() -> void:
	print(str(PlayerPartyState.selected_character_id))
	PlayerPartyState.load_form_disk(PlayerPartyState.selected_character_id)
	NetworkManagerTest.is_host = true
	NetworkManagerTest.create_lobby()


## Button callback: joins an existing world as client.
## Loads player save data, sets NetworkManagerTest as client, and attempts to join host.
func _on_join_world_pressed() -> void:
	PlayerPartyState.load_form_disk(PlayerPartyState.selected_character_id)
	NetworkManagerTest.is_host = false
	NetworkManagerTest.join_lobby("127.0.0.1", 4242)
