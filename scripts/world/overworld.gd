extends Node2D

@onready var level_container: Node2D = $LevelContainer
@onready var multiplayer_spawner: MultiplayerSpawn = $MultiplayerSpawner
@onready var players: Node = $Players

const DEFAULT_LEVEL = preload("res://scenes/world/levels/biom_1.tscn")

func _ready() -> void: 
	# Sauberes Parenting-Ziel für Spawns (kannst du auch im Inspector setzen)
	if multiplayer_spawner and multiplayer_spawner.spawn_path == NodePath():
		if players:
			multiplayer_spawner.spawn_path = NodePath("../Players")
	
	# Client: nach Level-Load Host informieren → vermeidet Race-Conditions
	if not multiplayer.is_server():
		await get_tree().process_frame
		NetworkManagerTest.notify_server_level_ready()
	
	# Cleanup on disconnect
	if NetworkManagerTest.has_signal("peer_disconnected"):
		NetworkManagerTest.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))
	
	# Level Laden
		_load_level(DEFAULT_LEVEL)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer_spawner:
		multiplayer_spawner.remove_player(peer_id)


func _load_level(level_scene: PackedScene) -> void:
	for child in level_container.get_children():
		child.queue_free()
	
	var level: Node2D = level_scene.instantiate()
	level_container.add_child(level)
	
	print("Level geladen: ", level_scene)
