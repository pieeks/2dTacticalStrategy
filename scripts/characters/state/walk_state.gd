class_name WalkState
extends NodeState

var _player: PlayerCharacter
var _sprite: AnimatedSprite2D

func _on_enter() -> void:
	_player = owner_actor as PlayerCharacter
	if _player:
		var v := _player.move_vec_for_anim()
		var card := _snap_to_cardinal(v)
		var facing := (card if card != Vector2.ZERO else _snap_to_cardinal(_player.facing_dir()))
		_player._last_anim = ""
		var animationName := "walk_" + _dir_name(facing)
		_emit_and_play(animationName)

func _on_physics_process(_delta: float) -> void:
	if _player == null:
		return
	# Richtung während der Bewegung dynamisch anpassen
	var v := _player.move_vec_for_anim()
	var card := _snap_to_cardinal(v)
	var facing := (card if card != Vector2.ZERO else _snap_to_cardinal(_player.facing_dir()))
	var animationName := "walk_" + _dir_name(facing)
	_emit_and_play(animationName)

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

func _snap_to_cardinal(v: Vector2) -> Vector2:
	if v.length() < 0.01:
		return Vector2.ZERO
	if abs(v.x) >= abs(v.y): 
		return Vector2(signf(v.x), 0.0)
	else:
		return Vector2(0.0, signf(v.y))

func _emit_and_play(anim: String) -> void:
	if _player:
		_player.emit_signal("animation_state_changed", anim)
		_player.play_animation(anim)
