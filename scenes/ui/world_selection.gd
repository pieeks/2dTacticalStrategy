extends Control

const LEVEL_SCENE_PATH := "res://_dev/tests/test_scene_tilemap_multiplayer.tscn"
var level_scene: PackedScene

func _ready() -> void:
	level_scene = load(LEVEL_SCENE_PATH)
	if NetworkManagerTest.has_signal("lobby_joined_finished"):
		NetworkManagerTest.connect("lobby_joined_finished", Callable(self, "_on_lobby_joined"))

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_lobby_joined() -> void:
	get_tree().change_scene_to_packed(level_scene)

func _on_start_world_pressed() -> void:
	print(str(PlayerPartyState.selected_character_id))
	PlayerPartyState.load_form_disk(PlayerPartyState.selected_character_id)
	NetworkManagerTest.is_host = true
	NetworkManagerTest.create_lobby()


func _on_join_world_pressed() -> void:
	PlayerPartyState.load_form_disk(PlayerPartyState.selected_character_id)
	NetworkManagerTest.is_host = false
	NetworkManagerTest.join_lobby("127.0.0.1", 4242)
