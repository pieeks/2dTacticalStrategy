class_name MultiplayerSpawn
extends MultiplayerSpawner

@export var player_scene: PackedScene
var players := {}

func _ready() -> void:
	spawn_function = _spawn_player  # nur instanziert & zurückgeben
	# Host hört auf "ready" und spawnt dann
	if multiplayer.is_server():
		if NetworkManagerTest.has_signal("peer_ready"):
			NetworkManagerTest.connect("peer_ready", Callable(self, "_on_peer_ready"))
		# Host selbst sofort spawnen, falls schon ready (direkt beim Host-Start)
		if NetworkManagerTest.is_peer_ready(multiplayer.get_unique_id()):
			spawn(multiplayer.get_unique_id())

func _on_peer_ready(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn(peer_id)  # MultiplayerSpawner übernimmt Parenting & Replikation

func _spawn_player(peer_id: int) -> Node:
	if not player_scene:
		push_error("Player scene not set on MultiplayerSpawn")
		return null
	var p := player_scene.instantiate()
	p.set_multiplayer_authority(peer_id)
	
	# Save-Daten & Aussehen zuweisen
	call_deferred("setup_player_from_save", p, peer_id) 
	
	players[peer_id] = p
	return p


func setup_player_from_save(player: Node, peer_id: int) -> void:
	var save_data := {}
	if peer_id == multiplayer.get_unique_id():
		save_data = {
			"player_id": PlayerPartyState.player_id,
			"name": PlayerPartyState.player_data.get("name"),
			"position":PlayerPartyState.position_data,
			"appearance": PlayerPartyState.player_data.get("appearance")
		}
	else: 
		save_data = {
			"player_id": str(peer_id),
			"name": "Remote_" + str(peer_id),
			"position": Vector2.ZERO
		}
	player.apply_save_data(save_data, player)


func remove_player(peer_id: int) -> void:
	if players.has(peer_id) and is_instance_valid(players[peer_id]):
		players[peer_id].queue_free()
	players.erase(peer_id)
