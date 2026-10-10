extends Node
## Legacy free-move helper kept for animation; turn clicks go through BattleTurnController.

@export var speed: float = 150.0
@export var arrival_tolerance: float = 2.0

var current_path: PackedVector2Array = []
var target_point: Vector2 = Vector2.ZERO
var is_moving: bool = false
var grid_manager: GridManager
## When false, left-click free-move is disabled (turn-based mode).
var input_enabled: bool = false


func process_movement(character: CharacterBody2D, _delta: float) -> void:
	# Animated turn moves run for any unit this peer simulates (local + host AI).
	if not is_moving and input_enabled:
		if not character.is_multiplayer_authority():
			return
		_check_for_input(character)
	if is_moving:
		_move_along_path(character)


func play_path(_character: CharacterBody2D, path: PackedVector2Array) -> void:
	if path.size() <= 1:
		return
	current_path = path.duplicate()
	current_path.remove_at(0)
	target_point = current_path[0]
	is_moving = true
	if grid_manager:
		grid_manager.set_preview_path(path)


func _check_for_input(character: CharacterBody2D) -> void:
	if not Input.is_action_just_pressed("left_click") or grid_manager == null:
		return
	var path := grid_manager.get_action_path(
		character.global_position,
		character.get_global_mouse_position()
	)
	if path.size() <= 1:
		return
	play_path(character, path)


func _move_along_path(character: CharacterBody2D) -> void:
	var direction := character.global_position.direction_to(target_point)
	# Avoid CharacterBody2D physics for remote puppets; lerp position instead.
	var step: float = speed * character.get_physics_process_delta_time()
	if character.global_position.distance_to(target_point) <= step:
		character.global_position = target_point
		current_path.remove_at(0)
		if current_path.size() > 0:
			target_point = current_path[0]
		else:
			_stop_movement(character)
	else:
		character.global_position += direction * step
		character.velocity = direction * speed


func _stop_movement(character: CharacterBody2D) -> void:
	is_moving = false
	character.velocity = Vector2.ZERO
	if grid_manager:
		grid_manager.clear_preview_path()
