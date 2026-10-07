extends Control

## UIScaler
##
## Previously scaled UI Controls manually. Scaling is now handled by the
## project stretch settings (canvas_items + aspect keep).
## This script remains attached to existing scenes as a no-op for compatibility.

@export var base_resolution: Vector2i = Vector2i(640, 360)


func _ready() -> void:
	scale = Vector2.ONE
