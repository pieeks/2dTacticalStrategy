class_name ForceFightArea
extends Area2D


@onready var actor := get_parent()

var current_target: Array[Node]

signal force_fight


func _on_body_entered(body: Node2D) -> void:
	if not actor.is_multiplayer_authority(): 
		return
	if body == actor:
		return
	current_target.append(body)
	if body.is_in_group("Players"): 
		print("Is in Force Fight Area.")
		emit_signal("force_fight")


func _on_body_exited(body: Node2D) -> void:
	if not actor.is_multiplayer_authority(): 
		return
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
