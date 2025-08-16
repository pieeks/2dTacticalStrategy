extends Node2D


func _ready() -> void:
	print("Level Ready")
	
	if Globals.steam_lobby_member > 0: 
		add_player(Globals.steam_lobby_member)
	
	if not multiplayer.is_server():
		return
	Steam.steam_server_connected.connect(add_player)
	Steam.steam_server_disconnected.connect(del_player)
	


func add_player(id: int):
	$MultiplayerSpawner.spawnPlayer(Globals.steam_lobby_member)


func del_player():
	pass
