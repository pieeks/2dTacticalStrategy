class_name NPCFollowTargetState
extends NodeState

var _npc: NPCCharacter
var _target: Node2D = null
var _speed: float = 80.0

func _on_enter(msg: Dictionary = {}) -> void:
	_npc = owner_actor as NPCCharacter
	if _npc == null: return

	if "target" in msg and is_instance_valid(msg["target"]):
		_target = msg["target"]
	else:
		request_transition("IdleNPC")

func _on_physics_process(_delta: float) -> void:
	# Diese Logik läuft NUR auf dem Host.
	if not _npc.is_multiplayer_authority():
		return
	
	if not is_instance_valid(_target):
		request_transition("IdleNPC")
		return
	
	if _npc.is_interacting:
		request_transition("IdleNPC")
		return
	
	var dir = (_target.global_position - _npc.global_position)
	
	if dir.length() > 16.0:
		dir = dir.normalized()
		_npc.velocity = dir * _speed
		if dir.length_squared() > 0:
			_npc.facing_direction = dir
	else:
		_npc.velocity = Vector2.ZERO
		request_transition("IdleNPC")

func _on_exit() -> void:
	if _npc:
		_npc.velocity = Vector2.ZERO
	_target = null
