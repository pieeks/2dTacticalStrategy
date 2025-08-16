extends Node2D

@onready var multiplayer_spawn: MultiplayerSpawn = $MultiplayerSpawner

func _ready() -> void:
	if multiplayer_spawn == null:
		push_error("MultiplayerSpawner Node nicht gefunden!")
		return

	# Falls du keinen Players-Container nutzt, parentet der Spawner in sich selbst.
	# Sauberer ist ein dedizierter Container:
	if multiplayer_spawn.spawn_path == NodePath():
		var players_node := get_node_or_null("Players")
		if players_node:
			multiplayer_spawn.spawn_path = NodePath("../Players")  # vom Spawner aus gesehen

	# Nur Cleanup hier; Spawns macht der Spawner selbst.
	if NetworkManagerTest.has_signal("peer_disconnected"):
		NetworkManagerTest.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer_spawn:
		multiplayer_spawn.remove_player(peer_id)
