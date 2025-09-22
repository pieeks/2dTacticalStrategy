extends Control

@export var base_resolution: Vector2i = Vector2i(1280, 720)

func _ready() -> void:
	_update_ui_scale()
	get_tree().get_root().size_changed.connect(_update_ui_scale)

func _update_ui_scale() -> void:
	var screen_size = get_viewport_rect().size
	var factor = screen_size.y / float(base_resolution.y)
	
	factor = round(factor)
	scale = Vector2(factor, factor) 
