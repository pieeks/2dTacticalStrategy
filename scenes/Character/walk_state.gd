class_name WalkState
extends NodeState

var _player: Player
var _sprite: AnimatedSprite2D

func _on_enter() -> void:
	_player = owner_actor as Player
	if _player:
		var v := _player.move_vec_for_anim()
		var facing := (v.normalized() if v.length() > 0.01 else _player.facing_dir())
		var name := "walk_" + _dir_name(facing)
		_player.play_animation(name)

func _on_physics_process(_delta: float) -> void:
	if _player == null:
		return
	# Richtung während der Bewegung dynamisch anpassen
	var v := _player.move_vec_for_anim()
	var facing := (v.normalized() if v.length() > 0.01 else _player.facing_dir())
	var name := "walk_" + _dir_name(facing)
	_player.play_animation(name)

func _on_next_transitions() -> void:
	if _player and not _player.is_moving():
		request_transition("Idle")

func _on_exit() -> void:
	if _sprite:
		_sprite.stop()

func _dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	else:
		return "front" if v.y >= 0.0 else "back"
