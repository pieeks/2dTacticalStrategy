class_name MultiplayerSpawn
extends MultiplayerSpawner

## MultiplayerSpawn
##
## Custom spawner for multiplayer player characters.
## Uses Godot's MultiplayerSpawner as base but adds:
## - Handling of "peer_ready" signals
## - Explicit spawn function for instantiating Player scenes
## - Tracking of spawned player instances
##
## Features:
## - Host waits for peers to signal readiness before spawning them
## - Ensures host spawns itself immediately if already ready
## - Keeps a dictionary of all active players for easy access
## - Provides a method to remove players cleanly

## The scene to be spawned for each peer (usually PlayerCharacter.tscn).
@export var player_scene: PackedScene

## Dictionary of spawned players, keyed by peer_id.
var players := {}


## Called when the node enters the scene tree.
## - Sets spawn function
## - Connects to peer_ready signal on host
## - Spawns host immediately if already ready
func _ready() -> void:
	spawn_function = _spawn_player  # Only instantiate & return player
	# Host listens for ready signal and spawns players
	if multiplayer.is_server():
		if NetworkManagerTest.has_signal("peer_ready"):
			NetworkManagerTest.connect("peer_ready", Callable(self, "_on_peer_ready"))
		# Spawn host immediately if marked ready at startup
		if NetworkManagerTest.is_peer_ready(multiplayer.get_unique_id()):
			spawn(multiplayer.get_unique_id())


## Called when a peer signals readiness.
## Host spawns the corresponding player.
##
## @param peer_id int: The peer ID of the ready client.
func _on_peer_ready(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn(peer_id)  # MultiplayerSpawner handles parenting & replication


## Instantiates and returns a new player instance for the given peer.
## Sets multiplayer authority to the peer ID and tracks it in the dictionary.
##
## @param peer_id int: The peer ID for which to spawn the player.
## @return Node: The newly instantiated player node, or null if scene is missing.
func _spawn_player(peer_id: int) -> Node:
	print("[Spawner] on peer", multiplayer.get_unique_id(), 
		  "spawn for", peer_id, " player_scene set?", player_scene != null)
	if not player_scene:
		push_error("Player scene not set on MultiplayerSpawn (peer " + str(multiplayer.get_unique_id()) + ")")
		return null
	var p := player_scene.instantiate()
	print("[Spawner] instantiate OK on peer", multiplayer.get_unique_id(), " -> ", p)
	p.set_multiplayer_authority(peer_id)
	players[peer_id] = p
	return p


## Removes a spawned player instance for the given peer.
## Frees the node and erases it from the players dictionary.
##
## @param peer_id int: The peer ID of the player to remove.
func remove_player(peer_id: int) -> void:
	if players.has(peer_id) and is_instance_valid(players[peer_id]):
		players[peer_id].queue_free()
	players.erase(peer_id)
