extends Node2D

var lobby_id = 0
var peer = SteamMultiplayerPeer.new()

@onready var ms: MultiplayerSpawner = $MultiplayerSpawner

@export var lobby_members_max : int

func _ready() -> void:
	ms.spawn_function = spawn_level
	multiplayer.multiplayer_peer = peer
	# Signal für Connection Status ändern
	peer.network_connection_status_changed.connect(_on_network_connection_status_changed)


func spawn_level(data):
	var a = (load(data) as PackedScene).instantiate()
	return a


func _on_host_pressed() -> void:
	peer.create_host(lobby_members_max)
	
	ms.spawn("res://scenes/tests/test_scene_tilemap_multiplayer.tscn")
	$Host.hide()


func _on_network_connection_status_changed(connect_handle, connection, old_state):
	if connection.is_connected():
		#lobby_id = Steam.getLobbyID()
		Steam.setLobbyData(lobby_id, "name", str(Steam.getPersonaName() + "'s Lobby"))
		Steam.setLobbyJoinable(lobby_id, true)
		print("Lobby created with ID: ", lobby_id)
