extends Node2D

@onready var lobby_id = $UI/LobbyID
@onready var lobby_list : ItemList = $UI/ItemList

var refresh_timer := 1.0
var start_scene = preload("res://scenes/tests/test_scene_tilemap_multiplayer.tscn")

func _ready() -> void: 
	var t = Timer.new()
	t.wait_time = refresh_timer
	t.autostart = true
	t.one_shot = false
	t.timeout.connect(_update_friend_lobbies)
	add_child(t)
	
	start_scene = start_scene.instantiate()
	$NetworkManager.connect("_on_lobby_joined_finished", Callable(self, '_on_lobby_joined_finished'))

func _on_host_button_pressed() -> void:
	$NetworkManager.create_lobby()


func _on_join_button_pressed() -> void:
	var id: int = int(lobby_id.text)
	$NetworkManager.join_lobby(id)

func _update_friend_lobbies(): 
	lobby_list.clear()
	lobby_list.select_mode = ItemList.SELECT_SINGLE
	
	var friends = Steam.getFriendCount()
	#print("Friends Count: ", str(friends))
	for i in range(friends):
		var friend_steam_id = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_ALL)
		var friend_playing_game = Steam.getFriendGamePlayed(friend_steam_id)
		var friend_name = Steam.getFriendPersonaName(friend_steam_id)
		#print(str(friend_playing_game))
		#if not friend_playing_game.is_empty():
			#print(str(friend_playing_game['id']))
		
		if not friend_playing_game.is_empty(): 
			var display_text = "Name: " + str(friend_name)
			var item = lobby_list.add_item(display_text)
			lobby_list.set_item_metadata(item, friend_playing_game['lobby'])


func _on_lobby_joined_finished(): 
	print("lobby joined!")
	get_tree().current_scene = start_scene
	add_child(start_scene)
