extends Node
## Grid-Bewegung: Linksklick setzt Pfad, Bewegung entlang Hex-Punkten (nur Authority).

@export var speed: float = 150.0
@export var arrival_tolerance: float = 2.0

var current_path: PackedVector2Array = []
var target_point: Vector2 = Vector2.ZERO
var is_moving: bool = false
var grid_manager: GridManager


func process_movement(character: CharacterBody2D, delta: float) -> void:
	if not character.is_multiplayer_authority():
		return
	if not is_moving:
		_check_for_input(character)
	if is_moving:
		_move_along_path(character, delta)


func _check_for_input(character: CharacterBody2D) -> void:
	if not Input.is_action_just_pressed("left_click") or grid_manager == null:
		return
	var path := grid_manager.get_action_path(
		character.global_position,
		character.get_global_mouse_position()
	)
	if path.size() <= 1:
		return
	current_path = path.duplicate()
	current_path.remove_at(0)
	target_point = current_path[0]
	is_moving = true
	grid_manager.set_preview_path(path)


func _move_along_path(character: CharacterBody2D, _delta: float) -> void:
	var direction := character.global_position.direction_to(target_point)
	character.velocity = direction * speed
	character.move_and_slide()
	if character.global_position.distance_to(target_point) < arrival_tolerance:
		current_path.remove_at(0)
		if current_path.size() > 0:
			target_point = current_path[0]
		else:
			_stop_movement(character)


func _stop_movement(character: CharacterBody2D) -> void:
	is_moving = false
	character.velocity = Vector2.ZERO
	if grid_manager:
		grid_manager.clear_preview_path()
