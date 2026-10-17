class_name NPCIdleState
extends NodeState

var _npc: NPCCharacter

func _on_enter() -> void:
	_npc = owner_actor as NPCCharacter
	if _npc == null or not NetworkManagerTest.is_authority(_npc):
		return
	_npc.velocity = Vector2.ZERO
	# Do not resume patrol while talking or fight-locked.
	if _npc.is_interacting or _npc.is_fight_locked():
		return
	if not _npc.patrol_points.is_empty() or is_instance_valid(_npc.path_follower):
		_npc.start_patrol_pause()
