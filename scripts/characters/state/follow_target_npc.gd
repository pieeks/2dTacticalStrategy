## NPCFollowTargetState
##
## StateMachine state for NPCs actively following a target (e.g. player).
## Triggered by the AggroController.
## Handles direction, movement, and walk animations while pursuing the target.
##
## Expects the AggroController to provide {"target": Node2D} on enter().

class_name NPCFollowTargetState
extends NodeState

var _npc: NPCCharacter
var _sprite: AnimatedSprite2D
var _target: Node2D = null
var _speed: float = 80.0


func _on_enter(msg: Dictionary = {}) -> void:
	_npc = owner_actor as NPCCharacter
	if _npc == null:
		return

	_sprite = _npc.get_node_or_null("CharacterAppearance") as AnimatedSprite2D
	if "target" in msg and msg["target"]:
		_target = msg["target"]
	else:
		print("[FollowTargetNPC]: No target passed in state transition.")
		return

	print("[FollowTargetNPC]: Started following", _target.name)
	_npc._last_anim = ""


func _on_physics_process(_delta: float) -> void:
	if _npc == null or _target == null:
		request_transition("idle")
		return

	# Berechne Bewegungsrichtung zum Target
	var dir = (_target.global_position - _npc.global_position)
	var dist = dir.length()

	if dist > 16.0: # 16 px Toleranz
		dir = dir.normalized()
		_npc.velocity = dir * _speed
		_npc.move_and_slide()

		# Animation & Blickrichtung
		var facing = _snap_to_cardinal(dir)
		var animationName := "walk_" + _dir_name(facing)
		_emit_and_play(animationName)
	else:
		# Ziel erreicht → Idle
		_npc.velocity = Vector2.ZERO
		_emit_and_play("idle_front") # oder einfach Idle-State wechseln
		request_transition("idle")


func _on_exit() -> void:
	if _sprite:
		_sprite.stop()
	_npc.velocity = Vector2.ZERO
	_target = null
	print("[FollowTargetNPC]: Exited state")


## Hilfsfunktionen aus WalkState übernommen

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
	if _npc and anim != _npc._last_anim:
		_npc._last_anim = anim
		_npc.emit_signal("animation_state_changed", anim)
		_npc.play_animation(anim)
