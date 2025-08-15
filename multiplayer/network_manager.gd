# NetworkManager.gd
class_name NetworkManager
extends Node2D

signal lobby_created_success(lobby_id)
signal lobby_joined_success(lobby_id)

var steam_peer: SteamMultiplayerPeer
var lobby_id: int = 0

func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		push_error("Steam API nicht geladen!")
		return
	
	# Steam-Signale
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.p2p_session_request.connect(_on_p2p_session_request)
	
	print("NetworkManager ready.")

# ---------------- Host / Client ----------------
func host_game() -> void:
	steam_peer = SteamMultiplayerPeer.new()
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)
	print("Host: Lobby wird erstellt...")

func join_game_from_file() -> void:
	# Lobby-ID aus user:// lesen
	if not FileAccess.file_exists("user://lobby_id.txt"):
		push_warning("Keine lokale Lobby-ID gefunden.")
		return
	
	var f = FileAccess.open("user://lobby_id.txt", FileAccess.READ)
	var read_id = int(f.get_line())
	f.close()
	
	#if not read_id:
		#push_error("Ungültige Lobby-ID im File: " + read_id)
		#return
	
	lobby_id = int(read_id)
	print("Client: Lobby-ID aus Datei: ", lobby_id)
	
	steam_peer = SteamMultiplayerPeer.new()
	steam_peer.create_client(lobby_id, 0)
	multiplayer.multiplayer_peer = steam_peer
	Steam.joinLobby(lobby_id)
	print("Client: Versuche Lobby zu joinen...")

# ---------------- Signal-Handler ----------------
func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != 1 or new_lobby_id <= 0:
		push_error("Lobby-Erstellung fehlgeschlagen")
		return
	
	lobby_id = new_lobby_id
	print("Host: Lobby erstellt! ID =", lobby_id)
	
	# Lobby-ID für lokale Tests speichern
	var f = FileAccess.open("user://lobby_id.txt", FileAccess.WRITE)
	f.store_line(str(lobby_id))
	f.close()
	
	steam_peer.create_host(lobby_id)
	multiplayer.multiplayer_peer = steam_peer
	
	emit_signal("lobby_created_success", lobby_id)

func _on_lobby_joined(joined_lobby_id: int, permissions: int, locked: bool, result: int) -> void:
	if result != 1:
		push_warning("Lobby-Beitritt fehlgeschlagen. ID:", joined_lobby_id, " Result:", result)
		return

	var host_id = Steam.getLobbyOwner(joined_lobby_id)
	print("Lobby beigetreten:", joined_lobby_id, " Host:", host_id)
	
	print("getSteamID: ", str(Steam.getSteamID()), " Host ID: ", str(host_id))
	#if host_id != Steam.getSteamID():
	if host_id > 0:
		print("Client: Erstelle SteamMultiplayerPeer als Client.")
		steam_peer.create_client(joined_lobby_id)
		multiplayer.multiplayer_peer = steam_peer
	
	emit_signal("lobby_joined_success", joined_lobby_id)

# ---------------- Helpers ----------------
func _wait_for_peer_connected() -> void:
	while steam_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		await get_tree().process_frame

# ---------------- P2P ----------------
func _on_p2p_session_request(remote_id: int) -> void:
	Steam.acceptP2PSessionWithUser(remote_id)

# ---------------- Debug / Test ----------------
func debug_print_lobby_id() -> void:
	print("Aktuelle Lobby-ID:", lobby_id)
