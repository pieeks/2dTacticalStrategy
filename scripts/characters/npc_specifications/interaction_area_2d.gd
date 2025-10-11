extends Area2D


func _ready() -> void:
	pass


#func _area_entered(area: Area2D) -> void:
	#print("in area interaction: ", area.name)
#
#
func _on_body_entered(body: Node2D) -> void:
	print("in body interaction:" , body.name )
	if body.is_in_group("Players"): 
		if not body.action.action_triggerd.is_connected(_on_interact):
			body.action.action_triggerd.connect(_on_interact.bind(body))


func _on_body_exited(_body: Node2D) -> void:
	$"..".resume_patrol()

func _on_interact(player: Node2D):
	print("Player: ", player.name, " hat die Taste E gedrückt.")
	$"..".stop_patrol()
	$"..".state_machine.transition_to("IdleNPC")
