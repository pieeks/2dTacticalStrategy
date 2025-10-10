class_name ActionTriggerArea
extends Area2D

signal action_triggerd

var current_target: Node = null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Action"): 
		emit_signal("action_triggerd")


func _on_body_entered(body: Node2D) -> void:
	current_target = body
	print("in body action area:" , body.name )
	if body.specification.npc_is_hostile == true &&  not body.force_fight_area.force_fight.is_connected(_on_force_fight):
		body.force_fight_area.force_fight.connect(_on_force_fight)



func _on_force_fight() -> void:
	print("Fight is forced.")
