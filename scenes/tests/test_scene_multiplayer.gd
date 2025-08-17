extends Node2D

@onready var spawner: MultiplayerSpawn = $MultiplayerSpawner
@onready var players_container: Node = $Players

func _ready() -> void:
	# Sauberes Parenting-Ziel für Spawns (kannst du auch im Inspector setzen)
	if spawner and spawner.spawn_path == NodePath():
		if players_container:
			spawner.spawn_path = NodePath("../Players")

	# Client: nach Level-Load Host informieren → vermeidet Race-Conditions
	if not multiplayer.is_server():
		NetworkManagerTest.notify_server_level_ready()

	# Cleanup on disconnect
	if NetworkManagerTest.has_signal("peer_disconnected"):
		NetworkManagerTest.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))

func _on_peer_disconnected(peer_id: int) -> void:
	if spawner:
		spawner.remove_player(peer_id)
