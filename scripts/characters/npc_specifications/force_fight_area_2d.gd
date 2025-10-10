class_name ForceFightArea
extends Area2D

signal force_fight



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"): 
		print("Is in Force Fight Area.")
		emit_signal("force_fight")
