class_name PlayerUI
extends CanvasLayer

var current_interaction_npc_path: String
var current_npc_data: Dictionary


func _ready() -> void:
	pass


func show_interaction_menu(npc_data: Dictionary, npc_path: String) -> void:
	current_interaction_npc_path = npc_path
	current_npc_data = npc_data
	$InteractionMenu.show()
	$InteractionMenu/InteractionButtonContainer/Talk.show()
	$InteractionMenu/InteractionButtonContainer/Leave.show()



func _on_leave_pressed() -> void:
	$InteractionMenu.hide()
	$InteractionMenu/InteractionButtonContainer/Talk.hide()
	$InteractionMenu/InteractionButtonContainer/Leave.hide()
	
	if not current_interaction_npc_path:
		return
	
	var current_npc_target = get_node_or_null(current_interaction_npc_path)
	if not is_instance_valid(current_npc_target): 
		return
	
	current_npc_target.end_interaction.rpc_id(1)
	current_interaction_npc_path = ""
	current_npc_data = {}
