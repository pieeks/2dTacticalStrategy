class_name AggroArea
extends Area2D
## Radius for chase start. Logic lives in AggroController (also connected to body_entered).


func _on_body_entered(_body: Node2D) -> void:
	# Scene wires this signal; chase handling is in AggroController.
	pass
