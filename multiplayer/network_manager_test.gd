# File: network_manager.gd
extends Node

# ---------------- Signale ----------------
signal lobby_joined_finished
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

# ---------------- Konfiguration ----------------
var is_host: bool = false
var lobby_id: int = 0
var lobby_members := []
var lobby_members_max: int = 6

# ENet
var network: ENetMultiplayerPeer
var port: int = 4242
var host_address: String = "127.0.0.1"

func _ready() -> void:
	# Autoload initialisiert sich, macht aber noch nichts
	pass

# ---------------- Host / Join ----------------
func create_lobby() -> void:
	if is_host:
		print("Starting host...")
		network = ENetMultiplayerPeer.new()
		var err = network.create_server(port, lobby_members_max)
		if err != OK:
			push_error("Failed to start ENet server")
			return
		multiplayer.multiplayer_peer = network
		lobby_id = 1 # Platzhalter für Lobby-ID
		_on_lobby_joined()
		network.peer_connected.connect(_on_peer_connected)
		network.peer_disconnected.connect(_on_peer_disconnected)

func join_lobby(ip: String = "127.0.0.1", port: int = 4242) -> void:
	if is_host:
		push_error("Host kann nicht einem Client beitreten")
		return

	var network := ENetMultiplayerPeer.new()
	var err := network.create_client(ip, port)
	if err != OK:
		push_error("Failed to join ENet server")
		return

	multiplayer.multiplayer_peer = network

	# Statt ENet-Peer-Signale nutzen wir MultiplayerAPI-Signale
	multiplayer.connected_to_server.connect(_on_lobby_joined)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	print("Verbindung zum Server gestartet...")

# ---------------- Lobby / Connection ----------------
func _on_lobby_joined() -> void:
	print("Lobby joined (ENet)")
	emit_signal("lobby_joined_finished")

func _on_connection_failed() -> void:
	push_error("Failed to connect to host")

func _on_server_disconnected() -> void:
	print("Disconnected from server")

# ---------------- Player Events ----------------
func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	emit_signal("peer_connected", id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	emit_signal("peer_disconnected", id)

# ---------------- Hilfsfunktionen ----------------
func get_unique_id() -> int:
	if multiplayer.multiplayer_peer:
		return multiplayer.get_unique_id()
	return 1
