class_name NPCSync
extends Node

## Synchronizes the character's global position.
## Sent frequently by the authority using unreliable_ordered replication.
##
## @param pos Vector2: The global position of the player.
@rpc("any_peer", "unreliable_ordered")
func rpc_sync_position(pos: Vector2) -> void:
	var actor := get_parent() # Expected to be PlayerCharacter
	if actor:
		actor.global_position = pos
