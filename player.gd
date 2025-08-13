class_name Player
extends CharacterBody2D

var player_direction : Vector2

@onready var cam: Camera2D = $Camera2D


func _ready() -> void: 
	cam.enabled = is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
