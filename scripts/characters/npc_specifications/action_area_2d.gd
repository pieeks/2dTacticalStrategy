class_name ActionTriggerArea
extends Area2D


var current_target: Array[Node]

signal end_interaction_signal(Node2D)

func _on_body_entered(body: Node2D) -> void:
	current_target.append(body)
	print("in body action area:" , body.name )


func _on_body_exited(body: Node2D) -> void:
	emit_signal("end_interaction_signal", body)
	current_target.erase(body)


func get_closest_target(from_position: Vector2) -> Node:
	var closest_target: Node = null
	var closest_dist_sq: float = INF
	
	for target in current_target:
		if not is_instance_valid(target):
			continue 
		var dist_sq: float = from_position.distance_squared_to(target.global_position)
		
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_target = target
	
	return closest_target
