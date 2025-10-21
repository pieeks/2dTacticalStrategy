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
	#if multiplayer_spawner and multiplayer_spawner.spawn_path == NodePath():
		#if players:
			#multiplayer_spawner.spawn_path = NodePath("../Players")
	
	# Client: notify host after level load to avoid race conditions
	if not multiplayer.is_server():
		await get_tree().process_frame
		NetworkManagerTest.notify_server_level_ready()
	
	# Cleanup when peers disconnect
	if NetworkManagerTest.has_signal("peer_disconnected"):
		NetworkManagerTest.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))
	
	if multiplayer.is_server():
		NetworkManagerTest.late_joiner_detected.connect(_on_later_joiner_detected)
	
	# Load default level
	_load_level(DEFAULT_LEVEL)


## Handles peer disconnection.
## Removes the corresponding player instance from the spawner.
##
## @param peer_id int: ID of the disconnected peer.
func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer_spawner:
		multiplayer_spawner.remove_player(peer_id)


func _on_later_joiner_detected(new_peer_id: int) -> void:
	print("Overworld (Host): Synchronisiere Level-Zustand für neuen Spieler ", new_peer_id)
	
	await get_tree().create_timer(0.5).timeout
	
	if level_container.get_child_count() == 0:
		print("Overworld (Host): Kein Level zum Synchronisieren gefunden.")
		return
	var current_level = level_container.get_child(0)
	
	var npc_container = current_level.get_node_or_null("NPCContainer")
	if not npc_container:
		print("Overworld (Host): Kein NPCContainer im Level gefunden.")
		return
	
	for npc in npc_container.get_children():
		if npc is NPCCharacter and npc.is_awake:
			var current_anim = npc._last_anim 
			if not current_anim.is_empty():
				print("Overworld (Host): Sende Init-Anim '", current_anim, "' für ", npc.name, " an Client ", new_peer_id)
				npc.play_animation_rpc.rpc_id(new_peer_id, current_anim)


func _on_level_ready() -> void:
	pass


## Loads a given level scene.
## Clears the current LevelContainer and instantiates the new scene.
##
## @param level_scene PackedScene: The level scene to load.
func _load_level(level_scene: PackedScene) -> void:
	for child in level_container.get_children():
		child.queue_free()
	
	var level: Node2D = level_scene.instantiate()
	
	level.level_ready.connect(_on_level_ready)
	level_container.add_child(level)
	level.initialize_level_for_players(players)
	
	print("Level loaded: ", level_scene)
