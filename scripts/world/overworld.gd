extends Node2D

## LevelManager
##
## Handles world/level loading and player spawning in a multiplayer session.
##
## Features:
## - Ensures clean parenting target for MultiplayerSpawn
## - Notifies host when client finishes loading to avoid race conditions
## - Cleans up players on disconnect
## - Loads and replaces levels dynamically
##
## Usage:
## - Attach this script to a level root node containing:
##   - `LevelContainer` (Node2D): Holds the currently loaded level
##   - `MultiplayerSpawner`: Spawns PlayerCharacters
##   - `Players`: Container node for all spawned players
## - Call `_load_level()` to switch between level scenes.

## Container where the active level is instantiated.
@onready var level_container: Node2D = $LevelContainer

## Multiplayer spawner used for spawning PlayerCharacters.
@onready var multiplayer_spawner: MultiplayerSpawn = $MultiplayerSpawner

## Node used as the parent for all player instances.
@onready var players: Node = $Players

## Default level to load when this scene starts.
const DEFAULT_LEVEL = preload("res://scenes/world/levels/biom_1.tscn")


## Called when the node enters the scene tree.
## - Ensures spawner has a valid spawn path
## - Notifies host when client finished loading
## - Connects to disconnect cleanup
## - Loads default level
func _ready() -> void: 
	# Ensure clean parenting target for spawns (can also be set in Inspector)
	if multiplayer_spawner and multiplayer_spawner.spawn_path == NodePath():
		if players:
			multiplayer_spawner.spawn_path = NodePath("../Players")
	
	# Client: notify host after level load to avoid race conditions
	if not multiplayer.is_server():
		await get_tree().process_frame
		NetworkManagerTest.notify_server_level_ready()
	
	# Cleanup when peers disconnect
	if NetworkManagerTest.has_signal("peer_disconnected"):
		NetworkManagerTest.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))
	
	# Load default level
	_load_level(DEFAULT_LEVEL)


## Handles peer disconnection.
## Removes the corresponding player instance from the spawner.
##
## @param peer_id int: ID of the disconnected peer.
func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer_spawner:
		multiplayer_spawner.remove_player(peer_id)


## Loads a given level scene.
## Clears the current LevelContainer and instantiates the new scene.
##
## @param level_scene PackedScene: The level scene to load.
func _load_level(level_scene: PackedScene) -> void:
	for child in level_container.get_children():
		child.queue_free()
	
	var level: Node2D = level_scene.instantiate()
	level_container.add_child(level)
	
	print("Level loaded: ", level_scene)
