# File: network_manager.gd
extends Node
class_name NetworkManager

signal lobby_joined_finished
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal peer_ready(peer_id: int)  # ← neu

var is_host: bool = false
var lobby_members_max: int = 6

var network: ENetMultiplayerPeer
var port: int = 4242
var host_address: String = "127.0.0.1"

var _ready_peers := {} # peer_id -> true

func create_lobby() -> void:
	if is_host:
		network = ENetMultiplayerPeer.new()
		var err := network.create_server(port, lobby_members_max)
		if err != OK:
			push_error("Failed to start ENet server")
			return
		multiplayer.multiplayer_peer = network
		network.peer_connected.connect(_on_peer_connected_server)
		network.peer_disconnected.connect(_on_peer_disconnected_server)
		emit_signal("lobby_joined_finished")
		_mark_ready(multiplayer.get_unique_id()) # Host ist sofort ready

func join_lobby(ip: String = "127.0.0.1", p: int = 4242) -> void:
	if is_host:
		push_error("Host kann nicht Client joinen")
		return
	var cli := ENetMultiplayerPeer.new()
	var err := cli.create_client(ip, p)
	if err != OK:
		push_error("Failed to join ENet server")
		return
	multiplayer.multiplayer_peer = cli
	multiplayer.connected_to_server.connect(_on_connected_client)
	multiplayer.connection_failed.connect(func(): push_error("Connect failed"))
	multiplayer.server_disconnected.connect(func(): print("Disconnected"))

func _on_connected_client() -> void:
	emit_signal("lobby_joined_finished")


func _on_peer_connected_server(id: int) -> void:
	emit_signal("peer_connected", id)
	for pid in _ready_peers.keys():
		rpc_id(id, "rpc_mark_ready", pid)


func _on_peer_disconnected_server(id: int) -> void:
	_ready_peers.erase(id)
	emit_signal("peer_disconnected", id)

func get_unique_id() -> int:
	return multiplayer.get_unique_id()

# ---------------- Late-Join Handshake ----------------
@rpc("any_peer","reliable")
func rpc_client_level_ready() -> void:
	# Host markiert den anfragenden Peer als ready
	if multiplayer.is_server():
		var pid := multiplayer.get_remote_sender_id()
		_mark_ready(pid)
		rpc("rpc_mark_ready", pid)

@rpc("any_peer", "reliable")
func rpc_mark_ready(peer_id: int) -> void:
	_mark_ready(peer_id)

func notify_server_level_ready() -> void:
	# Client ruft das nach Level-Load
	if not multiplayer.is_server():
		rpc_id(1, "rpc_client_level_ready")  # 1 = Host

func _mark_ready(peer_id: int) -> void:
	_ready_peers[peer_id] = true
	emit_signal("peer_ready", peer_id)

func is_peer_ready(peer_id: int) -> bool:
	return _ready_peers.has(peer_id)
