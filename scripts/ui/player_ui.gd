class_name PlayerUI
extends CanvasLayer


func _ready() -> void:
	pass


func show_interaction_menu() -> void:
	$InteractionMenu.show()
	$InteractionMenu/InteractionButtonContainer/Talk.show()
	$InteractionMenu/InteractionButtonContainer/Leave.show()
