extends Node2D

@onready var lobby_id = $UI/LobbyID
@onready var lobby_list : ItemList = $UI/ItemList

var refresh_timer := 1.0
#var ms  = SteamMultiplayerPeer.new()
var start_scene = preload("res://scenes/tests/test_scene_tilemap_multiplayer.tscn")

func _ready() -> void: 
	setTimer()
	start_scene = start_scene.instantiate()
	NetworkManagerSteam.connect("_on_lobby_joined_finished", Callable(self, '_on_lobby_joined_finished'))
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	open_lobby_list()


func setTimer() -> void:
	var t = Timer.new()
	t.wait_time = refresh_timer
	t.autostart = true
	t.one_shot = false
	t.timeout.connect(_update_friend_lobbies)
	add_child(t)


func _on_host_button_pressed() -> void:
	NetworkManagerSteam.create_lobby()


func _on_join_button_pressed() -> void:
	var id: int = int(lobby_id.text)
	NetworkManagerTest.join_lobby(str(id), 4242)


func open_lobby_list(): 
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()


func _on_lobby_match_list(lobbies): 
	for lobby in lobbies:
		
		var lobby_name = Steam.getLobbyData(lobby, "name")
		var memb_count = Steam.getNumLobbyMembers(lobby)
		
		var but = Button.new()
		but.set_Text(str(lobby_name), "| Player Count: ", memb_count)
		but.set_size(Vector2(100, 5))
		but.connect("pressed", Callable(NetworkManagerSteam, "join_lobby").bind(lobby))
		
		$UI/TestLobbyContainer/Lobbies.add_child(but)


func _update_friend_lobbies(): 
	lobby_list.clear()
	lobby_list.select_mode = ItemList.SELECT_SINGLE
	
	var friends = Steam.getFriendCount()
	
	for i in range(friends):
		var friend_steam_id = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_ALL)
		var friend_playing_game = Steam.getFriendGamePlayed(friend_steam_id)
		var friend_name = Steam.getFriendPersonaName(friend_steam_id)
		
		if not friend_playing_game.is_empty(): 
			var display_text = "Name: " + str(friend_name) 
			var item = lobby_list.add_item(display_text)
			lobby_list.set_item_metadata(item, friend_playing_game['lobby'])

func _on_lobby_joined_finished(): 
	print("lobby joined!")
	print("Lobby_member: ", str(Globals.steam_lobby_member))
	get_tree().change_scene_to_packed(start_scene)
	add_child(start_scene)
