# /autoload/SteamManager.gd
extends Node

func _ready():
	if not Engine.has_singleton("Steam"):
		push_error("Steam API nicht gefunden!")
		return

	var init_res = Steam.steamInit()
	if init_res != true:
		push_error("Steam konnte nicht initialisiert werden! Code: %s" % init_res)
		return

	if not Steam.isSteamRunning():
		push_error("Steam läuft nicht – bitte Steam starten!")
		return

	print("[STEAM] Initialisiert als User:", Steam.getPersonaName())

	# Events verbinden
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.p2p_session_request.connect(_on_p2p_session_request)


func _process(_delta: float) -> void:
	if Engine.has_singleton("Steam"):
		Steam.run_callbacks()

func _on_lobby_created(result, lobby_id) -> void:
	print("lobby id: ", lobby_id)
	print("lobby_created", result)

func _on_lobby_joined(lobby_id, permissions, locked, result) -> void:
	print("lobby_joined: ", lobby_id)
	print("permissions: ", permissions)
	print("locked: ", locked)
	print("connect: ", result)

func _on_p2p_session_request(remote_id: int) -> void:
	Steam.acceptP2PSessionWithUser(remote_id)
