class_name AggroArea
extends Area2D



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):  
		print("Trigger Fight is activated")
