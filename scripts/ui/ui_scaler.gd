extends Control

## UIScaler
##
## Scales the entire UI based on the current window size,
## keeping the aspect ratio consistent with a base resolution.
## Uses integer scaling factors (rounded) for crisp visuals.
##
## Features:
## - Exports a base resolution (default 1280×720)
## - Listens for window resize events
## - Updates the `scale` of the root Control node
##
## Usage:
## - Attach this script to a root UI Control node
## - Set `base_resolution` to your target resolution
## - The UI will automatically scale up/down on window resize

## Base resolution used as reference for scaling.
@export var base_resolution: Vector2i = Vector2i(1280, 720)


## Called when the node enters the scene tree.
## Initializes scaling and connects to resize events.
func _ready() -> void:
	_update_ui_scale()
	get_tree().get_root().size_changed.connect(_update_ui_scale)


## Updates the UI scaling factor.
## Calculates scale as (current height ÷ base height),
## rounds to nearest integer, and applies to this Control node.
func _update_ui_scale() -> void:
	var screen_size = get_viewport_rect().size
	var factor = screen_size.y / float(base_resolution.y)
	factor = round(factor)
	scale = Vector2(factor, factor)
