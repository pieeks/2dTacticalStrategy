class_name NPCIdleState
extends NodeState

var _npc: NPCCharacter

func _on_enter() -> void:
	_npc = owner_actor as NPCCharacter
	# Stelle sicher, dass der NPC beim Betreten des Idle-States anhält.
	if _npc and NetworkManagerTest.is_authority(_npc):
		_npc.velocity = Vector2.ZERO
		if not _npc.patrol_points.is_empty():
			# Sage dem NPC-Boss, er soll seinen Pausen-Timer starten.
			print("DEBUG: IdleState -> Patrouille wird fortgesetzt. Starte Pause.")
			_npc.start_patrol_pause()
