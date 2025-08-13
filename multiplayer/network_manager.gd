extends Node2D

signal lobby_created_success(lobby_id)
signal lobby_joined_success(lobby_id)

var steam_peer: SteamMultiplayerPeer


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		push_error("Steam API nicht geladen!")
		return
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.p2p_session_request.connect(_on_p2p_session_request)


# ---------------- Host / Client ----------------
func host_game() -> void:
	steam_peer = SteamMultiplayerPeer.new()
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 4)


func join_game(lobby_id: int) -> void:
	steam_peer = SteamMultiplayerPeer.new()
	Steam.joinLobby(lobby_id)


# ---------------- Signal-Handler ----------------
func _on_lobby_created(result, lobby_id) -> void:
	if result != 1:
		push_error("Lobby-Erstellung fehlgeschlagen")
		return

	steam_peer.create_host(lobby_id)
	print("Host ID: ", Steam.getLobbyOwner(lobby_id))
	await _wait_for_peer_connected()
	multiplayer.multiplayer_peer = steam_peer


func _on_lobby_joined(lobby_id, permissions, locked, result) -> void:
	if result != 1:
		push_error("Lobby-Beitritt fehlgeschlagen")
		return

	var host_id = Steam.getLobbyOwner(lobby_id)
	if host_id != Steam.getSteamID():
		steam_peer.create_client(lobby_id)
		multiplayer.multiplayer_peer = steam_peer


# ---------------- Helpers ----------------
func _wait_for_peer_connected() -> void:
	while steam_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		await get_tree().process_frame

# ---------------- P2P ----------------
func _on_p2p_session_request(remote_id: int) -> void:
	Steam.acceptP2PSessionWithUser(remote_id)
