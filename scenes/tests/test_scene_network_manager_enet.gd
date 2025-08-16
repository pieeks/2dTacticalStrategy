# File: scripts/test_main.gd
extends Node2D

@onready var btn_host : Button = $UI/Host
@onready var btn_join : Button = $UI/Join
@onready var camera   : Camera2D = $Camera2D

const LEVEL_SCENE_PATH := "res://scenes/tests/test_scene_tilemap_multiplayer.tscn"
var level_scene: PackedScene

func _ready() -> void:
	level_scene = load(LEVEL_SCENE_PATH)
	btn_host.pressed.connect(_on_host_pressed)
	btn_join.pressed.connect(_on_join_pressed)

	if NetworkManagerTest.has_signal("lobby_joined_finished"):
		NetworkManagerTest.connect("lobby_joined_finished", Callable(self, "_on_lobby_joined"))

func _on_host_pressed() -> void:
	NetworkManagerTest.is_host = true
	NetworkManagerTest.create_lobby()

func _on_join_pressed() -> void:
	NetworkManagerTest.is_host = false
	NetworkManagerTest.join_lobby("127.0.0.1", 4242)

func _on_lobby_joined() -> void:
	# Der saubere Weg in Godot 4.x
	get_tree().change_scene_to_packed(level_scene)
