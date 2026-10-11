class_name PlayerUI
extends CanvasLayer

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
const QUEST_OFFER_PANEL_SCENE := preload("res://scenes/ui/quest/quest_offer_panel.tscn")

var current_interaction_npc_path: String
var current_npc_data: Dictionary
## Peer currently in a fight that we may join (Overworld interaction).
var _fight_join_target_peer_id: int = 0

var _quest_panel: Node = null


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
	_ensure_quest_panel()
	_apply_static_texts()
	_refresh_quest_log()
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)
	var qm := _qm()
	if qm != null and not qm.quests_changed.is_connected(_on_quests_changed):
		qm.quests_changed.connect(_on_quests_changed)


func _on_language_changed(_locale: String) -> void:
	_apply_static_texts()
	_refresh_quest_log()


func _on_quests_changed() -> void:
	_refresh_quest_log()


func _apply_static_texts() -> void:
	if has_node("InteractionMenu/InteractionButtonContainer/Talk"):
		$InteractionMenu/InteractionButtonContainer/Talk.text = tr("ui.interact.talk")
	if has_node("InteractionMenu/InteractionButtonContainer/Trade"):
		$InteractionMenu/InteractionButtonContainer/Trade.text = tr("ui.interact.trade")
	if has_node("InteractionMenu/InteractionButtonContainer/Quest"):
		$InteractionMenu/InteractionButtonContainer/Quest.text = tr("ui.interact.quest")
	if has_node("InteractionMenu/InteractionButtonContainer/Leave"):
		$InteractionMenu/InteractionButtonContainer/Leave.text = tr("ui.interact.leave")
	if has_node("FightJoinMenu/FightJoinButtonContainer"):
		var box: Node = $FightJoinMenu/FightJoinButtonContainer
		if box.has_node("Title"):
			box.get_node("Title").text = tr("battle.join.title")
		if box.has_node("JoinPlayer"):
			box.get_node("JoinPlayer").text = tr("battle.join.player")
		if box.has_node("JoinEnemy"):
			box.get_node("JoinEnemy").text = tr("battle.join.enemy")
		if box.has_node("JoinNeutral"):
			box.get_node("JoinNeutral").text = tr("battle.join.neutral")
		if box.has_node("Cancel"):
			box.get_node("Cancel").text = tr("battle.join.cancel")


func show_interaction_menu(npc_data: Dictionary, npc_path: String) -> void:
	hide_fight_join_menu()
	if _quest_panel != null and _quest_panel.has_method("hide_panel"):
		_quest_panel.hide_panel()
	current_interaction_npc_path = npc_path
	current_npc_data = npc_data
	$InteractionMenu.show()
	$InteractionMenu/InteractionButtonContainer/Talk.show()
	$InteractionMenu/InteractionButtonContainer/Leave.show()
	_update_quest_button_visibility()


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
		_hide_interaction_buttons()
	if _quest_panel != null and _quest_panel.has_method("hide_panel"):
		_quest_panel.hide_panel()


func _on_leave_pressed() -> void:
	$InteractionMenu.hide()
	_hide_interaction_buttons()
	if _quest_panel != null and _quest_panel.has_method("hide_panel"):
		_quest_panel.hide_panel()

	if not current_interaction_npc_path:
		return

	var current_npc_target = get_node_or_null(current_interaction_npc_path)
	if not is_instance_valid(current_npc_target):
		return

	current_npc_target.end_interaction.rpc_id(1)
	current_interaction_npc_path = ""
	current_npc_data = {}


func _qm() -> Node:
	return get_tree().root.get_node_or_null("QuestManager")


## Talk stub + talk objective progress for current NPC.
func _on_talk_pressed() -> void:
	var qm := _qm()
	if qm == null:
		return
	var target := str(current_npc_data.get("npc_type", current_npc_data.get("name", "")))
	if target != "":
		qm.report_progress({
			"type": "talk",
			"target": target,
			"amount": 1,
		})


## Open offer or turn-in panel for the current NPC.
func _on_quest_pressed() -> void:
	_ensure_quest_panel()
	var qm := _qm()
	if _quest_panel == null or qm == null:
		return
	var turn_ins: Array = qm.get_turn_in_from_npc(current_npc_data)
	if not turn_ins.is_empty():
		_quest_panel.show_turn_in(str(turn_ins[0]))
		return
	var offers: Array = qm.get_offerable_from_npc(current_npc_data)
	if not offers.is_empty():
		_quest_panel.show_offer(str(offers[0]))


func _on_quest_accepted(quest_id: String) -> void:
	var qm := _qm()
	if qm != null and qm.accept(quest_id):
		if _quest_panel != null:
			_quest_panel.hide_panel()
		_update_quest_button_visibility()


func _on_quest_turned_in(quest_id: String) -> void:
	var qm := _qm()
	if qm != null and qm.turn_in(quest_id):
		if _quest_panel != null:
			_quest_panel.hide_panel()
		_update_quest_button_visibility()


func _update_quest_button_visibility() -> void:
	if not has_node("InteractionMenu/InteractionButtonContainer/Quest"):
		return
	var btn: Button = $InteractionMenu/InteractionButtonContainer/Quest
	var qm := _qm()
	if qm == null:
		btn.visible = false
		return
	var offers: Array = qm.get_offerable_from_npc(current_npc_data)
	var turn_ins: Array = qm.get_turn_in_from_npc(current_npc_data)
	var show_quest := not offers.is_empty() or not turn_ins.is_empty()
	btn.visible = show_quest
	btn.disabled = not show_quest


func _refresh_quest_log() -> void:
	if not has_node("HUD/Quests"):
		return
	var list: ItemList = $HUD/Quests
	list.clear()
	var qm := _qm()
	if qm == null:
		return
	var active: Dictionary = qm.get_active()
	for quest_id in active.keys():
		var entry: Dictionary = active[quest_id]
		var def: Dictionary = qm.get_definition(str(quest_id))
		var title := tr(str(def.get("title_key", quest_id)))
		var status := str(entry.get("status", "active"))
		var obj_bits: PackedStringArray = PackedStringArray()
		for obj in entry.get("objectives", []):
			if typeof(obj) != TYPE_DICTIONARY:
				continue
			var key := str(obj.get("text_key", ""))
			var label := tr(key) if key != "" else str(obj.get("id", ""))
			obj_bits.append("%s %d/%d" % [label, int(obj.get("current", 0)), int(obj.get("count", 1))])
		var line := "%s [%s]" % [title, status]
		if not obj_bits.is_empty():
			line += " — " + ", ".join(obj_bits)
		list.add_item(line)


func _ensure_quest_panel() -> void:
	if _quest_panel != null and is_instance_valid(_quest_panel):
		return
	_quest_panel = QUEST_OFFER_PANEL_SCENE.instantiate()
	add_child(_quest_panel)
	if _quest_panel.has_signal("accepted"):
		_quest_panel.accepted.connect(_on_quest_accepted)
	if _quest_panel.has_signal("declined"):
		_quest_panel.declined.connect(func() -> void: pass)
	if _quest_panel.has_signal("turned_in"):
		_quest_panel.turned_in.connect(_on_quest_turned_in)
	if _quest_panel.has_signal("cancelled"):
		_quest_panel.cancelled.connect(func() -> void: pass)


func _hide_interaction_buttons() -> void:
	if has_node("InteractionMenu/InteractionButtonContainer/Talk"):
		$InteractionMenu/InteractionButtonContainer/Talk.hide()
	if has_node("InteractionMenu/InteractionButtonContainer/Quest"):
		$InteractionMenu/InteractionButtonContainer/Quest.hide()
	if has_node("InteractionMenu/InteractionButtonContainer/Leave"):
		$InteractionMenu/InteractionButtonContainer/Leave.hide()


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
	pass


func _on_join_neutral_stub() -> void:
	pass


func _get_fight_manager() -> Node:
	var overworld := get_tree().get_root().get_node_or_null("Overworld")
	if overworld == null:
		return null
	return overworld.get_node_or_null("FightManager")
