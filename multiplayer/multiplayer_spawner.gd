# File: scripts/MultiplayerSpawn.gd
class_name MultiplayerSpawn
extends MultiplayerSpawner

@export var player_scene: PackedScene
var players: = {}

func _ready() -> void:
	# WICHTIG: nur instanzieren + zurückgeben; Parenting macht der Spawner.
	spawn_function = _spawn_player

	# Host spawnt sich selbst + bereits verbundene Peers.
	if multiplayer.is_server():
		spawn(multiplayer.get_unique_id())
		for id in multiplayer.get_peers():
			if id != multiplayer.get_unique_id():
				spawn(id)

	# Neue/gehende Peers über den NetworkManager behandeln.
	if NetworkManagerTest.has_signal("peer_connected"):
		NetworkManagerTest.connect("peer_connected", Callable(self, "_on_peer_connected"))
	if NetworkManagerTest.has_signal("peer_disconnected"):
		NetworkManagerTest.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))

func _spawn_player(peer_id: int) -> Node:
	if player_scene == null:
		push_error("Player scene not set on MultiplayerSpawn!")
		return null
	var p := player_scene.instantiate()
	p.set_multiplayer_authority(peer_id)  # Authority zuweisen
	players[peer_id] = p
	return p  # << KEIN add_child! Spawner parentet gemäß spawn_path

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn(peer_id)  # serverseitig erzeugen -> repliziert zu Clients

func _on_peer_disconnected(peer_id: int) -> void:
	remove_player(peer_id)

func remove_player(peer_id: int) -> void:
	if players.has(peer_id) and is_instance_valid(players[peer_id]):
		players[peer_id].queue_free()
	players.erase(peer_id)
