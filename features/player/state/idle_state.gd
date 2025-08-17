class_name IdleState
extends NodeState

var _player: Player
var _sprite: AnimatedSprite2D

func _on_enter() -> void:
	# Warum: Referenzen erst hier holen, States bleiben netzwerkagnostisch.
	_player = owner_actor as Player
	if _player:
		_sprite = _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		# Sofort korrektes Idle anhand Facing setzen
		var name := "idle_" + _dir_name(_player.facing_dir())
		_player.play_animation(name)

func _on_physics_process(_delta: float) -> void:
	if _player == null:
		return
	# Idle folgt Facing; bei Bewegung wechselt State in _on_next_transitions
	var name := "idle_" + _dir_name(_player.facing_dir())
	_player.play_animation(name)

func _on_next_transitions() -> void:
	if _player and _player.is_moving():
		request_transition("Walk")

func _on_exit() -> void:
	if _sprite:
		_sprite.stop()

func _dir_name(v: Vector2) -> String:
	# Warum: Einheitliches Mapping zu deinen Anim-Namen (front/back/left/right)
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	else:
		return "front" if v.y >= 0.0 else "back"
