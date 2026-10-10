class_name PlayerUI
extends CanvasLayer

var current_interaction_npc_path: String
var current_npc_data: Dictionary
## Peer currently in a fight that we may join (Overworld interaction).
var _fight_join_target_peer_id: int = 0


func _ready() -> void:
	if has_node("FightJoinMenu"):
		$FightJoinMenu.visible = false
		var box: Node = $FightJoinMenu/FightJoinButtonContainer
		if box.has_node("JoinPlayer"):
			$FightJoinMenu/FightJoinButtonContainer/JoinPlayer.pressed.connect(_on_join_player_pressed)
		if box.has_node("JoinEnemy"):
			$FightJoinMenu/FightJoinButtonContainer/JoinEnemy.pressed.connect(_on_join_enemy_stub)
		if box.has_node("JoinNeutral"):
			$FightJoinMenu/FightJoinButtonContainer/JoinNeutral.pressed.connect(_on_join_neutral_stub)
		if box.has_node("Cancel"):
			$FightJoinMenu/FightJoinButtonContainer/Cancel.pressed.connect(hide_fight_join_menu)


func show_interaction_menu(npc_data: Dictionary, npc_path: String) -> void:
	hide_fight_join_menu()
	current_interaction_npc_path = npc_path
	current_npc_data = npc_data
	$InteractionMenu.show()
	$InteractionMenu/InteractionButtonContainer/Talk.show()
	$InteractionMenu/InteractionButtonContainer/Leave.show()


func show_fight_join_menu(target_peer_id: int) -> void:
	_on_leave_pressed_ui_only()
	_fight_join_target_peer_id = target_peer_id
	if not has_node("FightJoinMenu"):
		push_warning("PlayerUI: FightJoinMenu fehlt in der Scene.")
		return
	$FightJoinMenu.show()
	var box: Node = $FightJoinMenu/FightJoinButtonContainer
	if box.has_node("JoinPlayer"):
		$FightJoinMenu/FightJoinButtonContainer/JoinPlayer.show()
		$FightJoinMenu/FightJoinButtonContainer/JoinPlayer.disabled = false
	if box.has_node("JoinEnemy"):
		$FightJoinMenu/FightJoinButtonContainer/JoinEnemy.show()
		$FightJoinMenu/FightJoinButtonContainer/JoinEnemy.disabled = true
	if box.has_node("JoinNeutral"):
		$FightJoinMenu/FightJoinButtonContainer/JoinNeutral.show()
		$FightJoinMenu/FightJoinButtonContainer/JoinNeutral.disabled = true
	if box.has_node("Cancel"):
		$FightJoinMenu/FightJoinButtonContainer/Cancel.show()


func hide_fight_join_menu() -> void:
	_fight_join_target_peer_id = 0
	if has_node("FightJoinMenu"):
		$FightJoinMenu.hide()


func _on_leave_pressed_ui_only() -> void:
	if has_node("InteractionMenu"):
		$InteractionMenu.hide()
		$InteractionMenu/InteractionButtonContainer/Talk.hide()
		$InteractionMenu/InteractionButtonContainer/Leave.hide()


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


func _on_join_player_pressed() -> void:
	var target_id := _fight_join_target_peer_id
	hide_fight_join_menu()
	if target_id == 0:
		return
	var fm := _get_fight_manager()
	if fm == null:
		return
	if fm.has_method("request_join_fight_as_local"):
		fm.request_join_fight_as_local(target_id, "player")


func _on_join_enemy_stub() -> void:
	# TODO §6 later: join enemy side
	pass


func _on_join_neutral_stub() -> void:
	# TODO §6 later: neutral intervention
	pass


func _get_fight_manager() -> Node:
	var overworld := get_tree().get_root().get_node_or_null("Overworld")
	if overworld == null:
		return null
	return overworld.get_node_or_null("FightManager")
