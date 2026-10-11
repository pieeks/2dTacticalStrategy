extends CanvasLayer
class_name DebugOverlay

## DebugOverlay — network info + fight/quest debug menus (F3 toggle).

enum Page { MAIN, FIGHT, QUESTS }

@export var autoload_path: NodePath = NodePath("/root/NetworkManagerTest")
@export var start_visible: bool = false

@onready var panel: PanelContainer = $UIRoot/PanelContainer
@onready var lbl_title: Label = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/DebugOverlay
@onready var lbl_network: Label = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/NetworkInfo
@onready var main_menu: VBoxContainer = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/MainMenu
@onready var fight_page: VBoxContainer = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/FightPage
@onready var quest_page: VBoxContainer = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/QuestPage
@onready var btn_menu_fight: Button = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/MainMenu/Fight
@onready var btn_menu_quests: Button = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/MainMenu/Quests
@onready var btn_fight_back: Button = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/FightPage/Back
@onready var btn_quest_back: Button = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/QuestPage/Back
@onready var btn_start: Button = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/FightPage/FightButtons/StartFight
@onready var btn_join: Button = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/FightPage/FightButtons/JoinFight
@onready var btn_leave: Button = $UIRoot/PanelContainer/ScrollContainer/VBoxContainer/FightPage/FightButtons/LeaveFight
@onready var fight_select_panel: PanelContainer = $UIRoot/FightSelectPanel
@onready var fight_select_hint: Label = $UIRoot/FightSelectPanel/VBox/Hint
@onready var fight_list: ItemList = $UIRoot/FightSelectPanel/VBox/FightList
@onready var btn_join_selected: Button = $UIRoot/FightSelectPanel/VBox/Buttons/JoinSelected
@onready var btn_join_cancel: Button = $UIRoot/FightSelectPanel/VBox/Buttons/Cancel

var _nm: Node = null
var _visible_overlay := true
var _page: Page = Page.MAIN
var _listed_fights: Array[Dictionary] = []

## Quest cheat list widgets (built at runtime).
var _quest_available_list: ItemList
var _quest_completed_list: ItemList
var _quest_all_list: ItemList
var _listed_available: Array[String] = []
var _listed_completed: Array[String] = []
var _listed_all: Array[String] = []


func _ready() -> void:
	# Above BattleHud (layer 100) so F3 buttons stay clickable in fights.
	# UIRoot uses MOUSE_FILTER_IGNORE so empty space still reaches the fight HUD.
	layer = 128

	if not InputMap.has_action("ui_debug_toggle"):
		InputMap.add_action("ui_debug_toggle")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F3
		InputMap.action_add_event("ui_debug_toggle", ev)

	_nm = get_node_or_null(autoload_path)

	_visible_overlay = start_visible
	panel.visible = _visible_overlay
	fight_select_panel.visible = false
	_show_page(Page.MAIN)
	_update_network()

	btn_menu_fight.pressed.connect(func() -> void: _show_page(Page.FIGHT))
	btn_menu_quests.pressed.connect(func() -> void: _show_page(Page.QUESTS))
	btn_fight_back.pressed.connect(func() -> void: _show_page(Page.MAIN))
	btn_quest_back.pressed.connect(func() -> void: _show_page(Page.MAIN))

	btn_start.pressed.connect(_on_start_fight_pressed)
	btn_join.pressed.connect(_on_join_fight_pressed)
	btn_leave.pressed.connect(_on_leave_fight_pressed)
	btn_join_selected.pressed.connect(_on_join_selected_pressed)
	btn_join_cancel.pressed.connect(_hide_fight_select)
	fight_list.item_activated.connect(func(_index: int) -> void: _on_join_selected_pressed())
	_setup_quest_cheat_buttons()
	var qm := _qm()
	if qm != null and qm.has_signal("quests_changed") and not qm.quests_changed.is_connected(_refresh_quest_lists):
		qm.quests_changed.connect(_refresh_quest_lists)
	_refresh_quest_lists()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_debug_toggle"):
		_visible_overlay = not _visible_overlay
		panel.visible = _visible_overlay
		if not _visible_overlay:
			_hide_fight_select()
		else:
			_show_page(Page.MAIN)
			_refresh_quest_lists()
	if _visible_overlay:
		_update_network()


func _show_page(page: Page) -> void:
	_page = page
	main_menu.visible = page == Page.MAIN
	fight_page.visible = page == Page.FIGHT
	quest_page.visible = page == Page.QUESTS
	match page:
		Page.MAIN:
			lbl_title.text = "Debug Overlay"
		Page.FIGHT:
			lbl_title.text = "Debug — Fight"
			_hide_fight_select()
		Page.QUESTS:
			lbl_title.text = "Debug — Quests"
			_refresh_quest_lists()


func _get_fight_manager() -> Node:
	var overworld := get_tree().get_root().get_node_or_null("Overworld")
	if overworld == null:
		return null
	return overworld.get_node_or_null("FightManager")


func _qm() -> Node:
	return get_tree().root.get_node_or_null("QuestManager")


## English-only quest debug controls (no CSV).
func _setup_quest_cheat_buttons() -> void:
	var box := VBoxContainer.new()
	box.name = "QuestCheats"
	quest_page.add_child(box)

	var lbl := Label.new()
	lbl.text = "Quest Cheats"
	box.add_child(lbl)

	var lbl_all := Label.new()
	lbl_all.text = "All Quests"
	box.add_child(lbl_all)
	_quest_all_list = _make_quest_list(box, 56)
	_quest_all_list.item_selected.connect(_on_all_quest_selected)

	var lbl_avail := Label.new()
	lbl_avail.text = "Available (Accept)"
	box.add_child(lbl_avail)
	_quest_available_list = _make_quest_list(box, 48)
	_add_cheat_button(box, "Accept Selected", _on_cheat_accept)

	var lbl_done := Label.new()
	lbl_done.text = "Completed (Reset)"
	box.add_child(lbl_done)
	_quest_completed_list = _make_quest_list(box, 48)
	_add_cheat_button(box, "Uncomplete Selected", _on_cheat_uncomplete)

	_add_cheat_button(box, "Complete Objectives", _on_cheat_ready)
	_add_cheat_button(box, "Turn In Selected", _on_cheat_turn_in)
	_add_cheat_button(box, "Force Complete Selected", _on_cheat_force)


func _make_quest_list(parent: Node, min_height: float) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, min_height)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.select_mode = ItemList.SELECT_SINGLE
	parent.add_child(list)
	return list


func _add_cheat_button(parent: Node, text: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(cb)
	parent.add_child(btn)


func _refresh_quest_lists() -> void:
	if _quest_all_list == null:
		return
	var qm := _qm()
	var selected_all := _selected_id_from(_quest_all_list, _listed_all)
	var selected_avail := _selected_id_from(_quest_available_list, _listed_available)
	var selected_done := _selected_id_from(_quest_completed_list, _listed_completed)

	_listed_all.clear()
	_listed_available.clear()
	_listed_completed.clear()
	_quest_all_list.clear()
	_quest_available_list.clear()
	_quest_completed_list.clear()

	if qm == null or not qm.has_method("get_all_quest_ids"):
		_quest_all_list.add_item("(no QuestManager)")
		return

	var ids: Array = qm.get_all_quest_ids()
	for raw_id in ids:
		var quest_id := str(raw_id)
		var status := str(qm.get_status(quest_id)) if qm.has_method("get_status") else "?"
		_listed_all.append(quest_id)
		_quest_all_list.add_item("%s [%s]" % [quest_id, status])
		if qm.can_accept(quest_id):
			_listed_available.append(quest_id)
			_quest_available_list.add_item(quest_id)
		if status == "completed":
			_listed_completed.append(quest_id)
			_quest_completed_list.add_item(quest_id)

	_reselect_id(_quest_all_list, _listed_all, selected_all)
	_reselect_id(_quest_available_list, _listed_available, selected_avail)
	_reselect_id(_quest_completed_list, _listed_completed, selected_done)


func _selected_id_from(list: ItemList, ids: Array[String]) -> String:
	if list == null:
		return ""
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.is_empty():
		return ""
	var idx := int(selected[0])
	if idx < 0 or idx >= ids.size():
		return ""
	return ids[idx]


func _reselect_id(list: ItemList, ids: Array[String], quest_id: String) -> void:
	if quest_id.is_empty() or list == null:
		return
	var idx := ids.find(quest_id)
	if idx >= 0:
		list.select(idx)


## Prefer Available list, else All list selection.
func _selected_action_quest_id() -> String:
	var from_avail := _selected_id_from(_quest_available_list, _listed_available)
	if not from_avail.is_empty():
		return from_avail
	return _selected_id_from(_quest_all_list, _listed_all)


func _on_all_quest_selected(index: int) -> void:
	if index < 0 or index >= _listed_all.size():
		return
	var quest_id := _listed_all[index]
	var avail_idx := _listed_available.find(quest_id)
	if avail_idx >= 0 and _quest_available_list != null:
		_quest_available_list.select(avail_idx)
	var done_idx := _listed_completed.find(quest_id)
	if done_idx >= 0 and _quest_completed_list != null:
		_quest_completed_list.select(done_idx)


func _on_cheat_accept() -> void:
	var qm := _qm()
	if qm == null:
		return
	var quest_id := _selected_action_quest_id()
	if quest_id.is_empty():
		push_warning("DebugOverlay: no quest selected for Accept.")
		return
	if qm.accept(quest_id):
		print("DebugOverlay: accept ", quest_id)
	else:
		push_warning("DebugOverlay: cannot accept %s" % quest_id)
	_refresh_quest_lists()


func _on_cheat_ready() -> void:
	var qm := _qm()
	if qm == null:
		return
	var quest_id := _selected_id_from(_quest_all_list, _listed_all)
	if quest_id.is_empty():
		quest_id = _selected_action_quest_id()
	if quest_id.is_empty():
		push_warning("DebugOverlay: no quest selected for Complete Objectives.")
		return
	if qm.debug_complete_objectives(quest_id):
		print("DebugOverlay: ready ", quest_id)
	else:
		push_warning("DebugOverlay: cannot ready %s" % quest_id)
	_refresh_quest_lists()


func _on_cheat_turn_in() -> void:
	var qm := _qm()
	if qm == null:
		return
	var quest_id := _selected_id_from(_quest_all_list, _listed_all)
	if quest_id.is_empty():
		quest_id = _selected_action_quest_id()
	if quest_id.is_empty():
		push_warning("DebugOverlay: no quest selected for Turn In.")
		return
	if qm.turn_in(quest_id):
		print("DebugOverlay: turn_in ", quest_id)
	else:
		push_warning("DebugOverlay: cannot turn in %s" % quest_id)
	_refresh_quest_lists()


func _on_cheat_force() -> void:
	var qm := _qm()
	if qm == null:
		return
	var quest_id := _selected_action_quest_id()
	if quest_id.is_empty():
		quest_id = _selected_id_from(_quest_all_list, _listed_all)
	if quest_id.is_empty():
		push_warning("DebugOverlay: no quest selected for Force Complete.")
		return
	if qm.debug_force_complete(quest_id):
		print("DebugOverlay: force complete ", quest_id)
	else:
		push_warning("DebugOverlay: cannot force complete %s" % quest_id)
	_refresh_quest_lists()


func _on_cheat_uncomplete() -> void:
	var qm := _qm()
	if qm == null:
		return
	var quest_id := _selected_id_from(_quest_completed_list, _listed_completed)
	if quest_id.is_empty():
		quest_id = _selected_id_from(_quest_all_list, _listed_all)
	if quest_id.is_empty():
		push_warning("DebugOverlay: no completed quest selected to reset.")
		return
	if qm.has_method("debug_uncomplete") and qm.debug_uncomplete(quest_id):
		print("DebugOverlay: uncomplete ", quest_id)
	else:
		push_warning("DebugOverlay: cannot uncomplete %s" % quest_id)
	_refresh_quest_lists()


func _on_start_fight_pressed() -> void:
	print("DebugOverlay: Start Fight pressed")
	var fm := _get_fight_manager()
	if fm == null:
		push_warning("DebugOverlay: FightManager nicht gefunden.")
		return
	if multiplayer.is_server():
		fm.start_fight_for_peer(multiplayer.get_unique_id())
	else:
		fm.rpc_id(1, "rpc_request_start_fight")


func _on_join_fight_pressed() -> void:
	print("DebugOverlay: Join Fight pressed")
	var fm := _get_fight_manager()
	if fm == null:
		push_warning("DebugOverlay: FightManager nicht gefunden.")
		return
	_show_fight_select(fm)


func _show_fight_select(fm: Node) -> void:
	_listed_fights.clear()
	fight_list.clear()
	if fm.has_method("list_active_fights"):
		var listed: Array = fm.list_active_fights()
		for entry in listed:
			if entry is Dictionary:
				_listed_fights.append(entry)
	for fight_info in _listed_fights:
		var owner_id: int = int(fight_info.get("owner_peer_id", 0))
		var npc_name: String = str(fight_info.get("npc_name", ""))
		var parts: Array = fight_info.get("participants", [])
		var label := "Owner %d | Peers %s" % [owner_id, str(parts)]
		if npc_name != "":
			label += " | %s" % npc_name
		fight_list.add_item(label)
	if _listed_fights.is_empty():
		fight_select_hint.text = "Keine aktiven Fights."
		btn_join_selected.disabled = true
	else:
		fight_select_hint.text = "Fight wählen, dann Beitreten."
		btn_join_selected.disabled = false
		fight_list.select(0)
	fight_select_panel.visible = true


func _hide_fight_select() -> void:
	fight_select_panel.visible = false


func _on_join_selected_pressed() -> void:
	var selected: PackedInt32Array = fight_list.get_selected_items()
	if selected.is_empty() or _listed_fights.is_empty():
		push_warning("DebugOverlay: Kein Fight ausgewählt.")
		return
	var idx: int = int(selected[0])
	if idx < 0 or idx >= _listed_fights.size():
		return
	var fight_info: Dictionary = _listed_fights[idx]
	var target_id: int = int(fight_info.get("owner_peer_id", 0))
	var parts: Array = fight_info.get("participants", [])
	if target_id == 0 and not parts.is_empty():
		target_id = int(parts[0])
	_hide_fight_select()
	_request_join(target_id)


func _request_join(target_peer_id: int) -> void:
	var fm := _get_fight_manager()
	if fm == null:
		return
	if fm.has_method("request_join_fight_as_local"):
		fm.request_join_fight_as_local(target_peer_id, "player")
	elif multiplayer.is_server():
		fm._process_join_request(multiplayer.get_unique_id(), target_peer_id, "player")
	else:
		fm.rpc_id(1, "rpc_request_join_fight", target_peer_id, "player")


func _on_leave_fight_pressed() -> void:
	print("DebugOverlay: Leave Fight pressed")
	var fm := _get_fight_manager()
	if fm == null:
		push_warning("DebugOverlay: FightManager nicht gefunden.")
		return
	if multiplayer.is_server():
		fm.end_fight_for_peer(multiplayer.get_unique_id())
	else:
		fm.rpc_id(1, "rpc_request_end_fight_for_peer")


func _update_network() -> void:
	if _nm == null:
		_nm = get_node_or_null(autoload_path)
		if _nm == null:
			lbl_network.text = "No NetworkManagerTest found at: %s" % [autoload_path]
			return

	var peer_id := 0
	var is_host := false
	var peers := []
	var ready_list := []
	var in_fight := false

	if "get_unique_id" in _nm:
		peer_id = _nm.get_unique_id()
	if "is_host" in _nm:
		is_host = _nm.is_host
	if "multiplayer" in _nm and _nm.multiplayer and _nm.multiplayer.has_multiplayer_peer():
		peers = _nm.multiplayer.get_peers()
	if "_ready_peers" in _nm and typeof(_nm._ready_peers) == TYPE_DICTIONARY:
		ready_list = _nm._ready_peers.keys()

	var fm := _get_fight_manager()
	var fight_owners: Array = []
	if fm and fm.has_method("is_peer_in_fight"):
		in_fight = fm.is_peer_in_fight(peer_id)
	if fm and fm.has_method("list_active_fights"):
		for entry in fm.list_active_fights():
			if entry is Dictionary:
				fight_owners.append(int(entry.get("owner_peer_id", 0)))

	lbl_network.text = "Peer ID: %s\nIs Host: %s\nConnected: %s\nReady: %s\nIn Fight: %s\nFights: %s" % [
		peer_id, is_host, peers, ready_list, in_fight, fight_owners
	]
