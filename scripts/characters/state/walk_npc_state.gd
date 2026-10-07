class_name NPCWalkState
extends NodeState

var _npc: NPCCharacter

func _on_enter() -> void:
	_npc = owner_actor as NPCCharacter

func _on_physics_process(_delta: float) -> void:
	# Diese Logik läuft NUR auf der "Meister-Kopie" des NPCs auf dem Host.
	if not NetworkManagerTest.is_authority(_npc):
		return
	
	if _npc.is_interacting:
		request_transition("IdleNPC")
		return
	
	if _npc.patrol_behavior == NPCCharacter.PatrolBehavior.FOLLOW_PATH:
		if not is_instance_valid(_npc.path_follower):
			request_transition("IdleNPC")
			return
		
		_npc.path_follower.progress += _npc.speed * _delta * _npc.patrol_direction
		var patrol_point_pos = _npc.path_follower.global_position
		var direction = (_npc.global_position - patrol_point_pos).normalized()
		_npc.velocity = direction * -_npc.speed
		
		if _npc.path_follower.progress_ratio >= 1.0 or _npc.path_follower.progress_ratio <= 0.0:
			_npc.patrol_direction *= -1
			_npc.path_follower.progress_ratio = clampf(_npc.path_follower.progress_ratio, 0.0, _npc.path_follower.get_parent().curve.get_baked_length())
			
			_npc.velocity = Vector2.ZERO
			_npc.start_patrol_pause()
			request_transition("IdleNPC")
		else: 
			_npc.facing_direction = _npc.path_follower.transform.x.normalized()
	else: 
		if _npc.patrol_points.is_empty():
			request_transition("IdleNPC")
			return
	
		var target_pos = _npc.patrol_points[_npc.current_patrol_index]
	
		if _npc.global_position.distance_to(target_pos) < 5.0:
			_npc.velocity = Vector2.ZERO
			print("DEBUG: WalkState -> Ziel erreicht. Wechsle zu Idle.") 
			request_transition("IdleNPC")
		else:
			var direction = (target_pos - _npc.global_position).normalized()
			_npc.velocity = direction * _npc.speed
			if direction.length_squared() > 0:
				_npc.facing_direction = direction

func _on_exit() -> void:
	# Stelle sicher, dass der NPC anhält, wenn der State verlassen wird.
	if _npc:
		_npc.velocity = Vector2.ZERO
