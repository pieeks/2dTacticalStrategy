class_name ForceFightArea
extends Area2D

signal force_fight(body: Node2D)
signal force_fight_exit(body: Node2D)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		force_fight.emit(body)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Players"):
		force_fight_exit.emit(body)
