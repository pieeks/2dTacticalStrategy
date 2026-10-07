# File: network_manager.gd
extends Node
class_name NetworkManager

## NetworkManager
##
## Central multiplayer manager for hosting and joining ENet lobbies.
## Handles lobby creation/join, peer connection/disconnection,
## late-join handshakes, and authority checks.
##
## Features:
## - Host and client creation with ENet
## - Signals for lobby events (joined, peer connected/disconnected, peer ready)
## - "Ready" handshake system for late joiners
## - Utility for authority checks
##
## Usage:
## - Add as an Autoload (singleton) so it is always accessible.
## - Call `create_lobby()` on host, `join_lobby(ip, port)` on client.
## - Connect to signals for lobby events.
## - Use `is_authority(node)` to determine whether a node should process input.

## Emitted when lobby creation or join finishes successfully.
signal lobby_joined_finished
## Emitted when a new peer connects to the session.
signal peer_connected(peer_id: int)
## Emitted when a peer disconnects from the session.
signal peer_disconnected(peer_id: int)
## Emitted when a peer signals that it is ready (late-join handshake).
signal peer_ready(peer_id: int)
## Emitted when a peer later joined
signal late_joiner_detected(peer_id: int)

## True if this instance is running as host/server.
var is_host: bool = false
## Maximum number of lobby members (host + clients).
var lobby_members_max: int = 6

## Active ENet peer (server or client).
var network: ENetMultiplayerPeer
## Port used for hosting/joining.
var port: int = 4242
## Default host address for connecting as client.
var host_address: String = "127.0.0.1"

## Dictionary of peers that are marked as ready.
## Keys: peer_id, Value: true
var _ready_peers := {}


## Clears multiplayer peer, ready peers, and host flag.
func reset_session() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	_ready_peers.clear()
	is_host = false
	network = null


## Creates a new ENet lobby as host.
## Initializes server peer, sets multiplayer peer, connects signals.
func create_lobby() -> void:
	if multiplayer.has_multiplayer_peer():
		reset_session()
	is_host = true
	network = ENetMultiplayerPeer.new()
	var err := network.create_server(port, lobby_members_max)
	if err != OK:
		push_error("Failed to start ENet server")
		reset_session()
		return
	multiplayer.multiplayer_peer = network
	network.peer_connected.connect(_on_peer_connected_server)
	network.peer_disconnected.connect(_on_peer_disconnected_server)
	emit_signal("lobby_joined_finished")
	# Host is immediately ready
	_mark_ready(multiplayer.get_unique_id())


## Joins an existing ENet lobby as client.
## Sets multiplayer peer and connects client-side signals.
##
## @param ip String: IP address of the host (default = 127.0.0.1).
## @param p int: Port of the host (default = 4242).
func join_lobby(ip: String = "127.0.0.1", p: int = 4242) -> void:
	if multiplayer.has_multiplayer_peer():
		reset_session()
	is_host = false
	var cli := ENetMultiplayerPeer.new()
	var err := cli.create_client(ip, p)
	if err != OK:
		push_error("Failed to join ENet server")
		reset_session()
		return
	network = cli
	multiplayer.multiplayer_peer = cli
	multiplayer.connected_to_server.connect(_on_connected_client)
	multiplayer.connection_failed.connect(func(): push_error("Connect failed"))
	multiplayer.server_disconnected.connect(func(): print("Disconnected"))


## Called when client connects successfully to host.
func _on_connected_client() -> void:
	emit_signal("lobby_joined_finished")


## Called when a peer connects to the host.
## Broadcasts already ready peers to the new peer.
func _on_peer_connected_server(id: int) -> void:
	emit_signal("peer_connected", id)
	for pid in _ready_peers.keys():
		rpc_id(id, "rpc_mark_ready", pid)
	emit_signal("late_joiner_detected", id)


## Called when a peer disconnects from the host.
## Removes the peer from ready list and emits signal.
func _on_peer_disconnected_server(id: int) -> void:
	_ready_peers.erase(id)
	emit_signal("peer_disconnected", id)


## Returns the unique multiplayer ID for this peer.
func get_unique_id() -> int:
	return multiplayer.get_unique_id()


# ---------------- Late-Join Handshake ----------------

## RPC called by a client after finishing level load.
## Host marks this peer as ready and notifies others.
@rpc("any_peer","reliable")
func rpc_client_level_ready() -> void:
	if multiplayer.is_server():
		var pid := multiplayer.get_remote_sender_id()
		_mark_ready(pid)
		rpc("rpc_mark_ready", pid)


## RPC called by host to mark a peer as ready.
## Also used to propagate ready status to new joiners.
@rpc("any_peer", "reliable")
func rpc_mark_ready(peer_id: int) -> void:
	_mark_ready(peer_id)


## Notifies the host that the client finished level load.
func notify_server_level_ready() -> void:
	if not multiplayer.is_server():
		rpc_id(1, "rpc_client_level_ready")  # 1 = host


## Marks a peer as ready and emits the signal.
## @param peer_id int: The peer ID to mark.
func _mark_ready(peer_id: int) -> void:
	_ready_peers[peer_id] = true
	emit_signal("peer_ready", peer_id)


## Returns true if the given peer has been marked ready.
func is_peer_ready(peer_id: int) -> bool:
	return _ready_peers.has(peer_id)


# --- Multiplayer Authority ---

## Checks whether this node is controlled by the local peer.
## Only authority peers should process input and movement.
##
## @param current_node Node: The node to check.
## @return bool: True if local peer is the authority for this node.
func is_authority(current_node: Node) -> bool:
	if current_node.multiplayer == null or not current_node.multiplayer.has_multiplayer_peer():
		return false
	return current_node.multiplayer.get_unique_id() == current_node.get_multiplayer_authority()
