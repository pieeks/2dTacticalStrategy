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
## - Join opens an IP dialog before connecting

## File path to the overworld scene.
const LEVEL_SCENE_PATH := "res://scenes/world/overworld.tscn"
const JOIN_DIALOG_SCENE := preload("res://scenes/ui/confirmation_join_dialog.tscn")

## PackedScene for the overworld (preloaded in _ready()).
var level_scene: PackedScene

var _join_dialog: Node


## Called when the node enters the scene tree.
## Preloads the overworld scene and connects to lobby signals.
func _ready() -> void:
	level_scene = preload(LEVEL_SCENE_PATH)
	if NetworkManagerTest.has_signal("lobby_joined_finished"):
		NetworkManagerTest.connect("lobby_joined_finished", Callable(self, "_on_lobby_joined"))

	_join_dialog = JOIN_DIALOG_SCENE.instantiate()
	add_child(_join_dialog)
	_join_dialog.connect("join_confirmed", Callable(self, "_on_join_confirmed"))


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
	PlayerPartyState.load_from_disk(PlayerPartyState.selected_character_id)
	NetworkManagerTest.create_lobby()


## Button callback: opens the join IP dialog.
func _on_join_world_pressed() -> void:
	if _join_dialog and _join_dialog.has_method("popup_join"):
		_join_dialog.popup_join()
	elif _join_dialog:
		_join_dialog.popup_centered()


## Called when the join dialog confirms an IP address.
func _on_join_confirmed(ip: String) -> void:
	PlayerPartyState.load_from_disk(PlayerPartyState.selected_character_id)
	NetworkManagerTest.join_lobby(ip, 4242)
