extends Area2D

signal enter_activation_area(body)
signal exit_activation_area(body)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("NPCs"):
		emit_signal("enter_activation_area", body)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("NPCs"):
		emit_signal("exit_activation_area", body)
