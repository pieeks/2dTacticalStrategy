extends CanvasLayer
class_name DebugOverlay

## DebugOverlay — network info + fight debug buttons (F3 toggle).

@export var autoload_path: NodePath = NodePath("/root/NetworkManagerTest")
@export var start_visible: bool = false

@onready var panel: PanelContainer = $UIRoot/PanelContainer
@onready var vbox: VBoxContainer = $UIRoot/PanelContainer/VBoxContainer
@onready var lbl_title: Label = $UIRoot/PanelContainer/VBoxContainer/DebugOverlay
@onready var lbl_network: Label = $UIRoot/PanelContainer/VBoxContainer/NetworkInfo
@onready var btn_start: Button = $UIRoot/PanelContainer/VBoxContainer/FightButtons/StartFight
@onready var btn_join: Button = $UIRoot/PanelContainer/VBoxContainer/FightButtons/JoinFight
@onready var btn_leave: Button = $UIRoot/PanelContainer/VBoxContainer/FightButtons/LeaveFight
@onready var fight_select_panel: PanelContainer = $UIRoot/FightSelectPanel
@onready var fight_select_hint: Label = $UIRoot/FightSelectPanel/VBox/Hint
@onready var fight_list: ItemList = $UIRoot/FightSelectPanel/VBox/FightList
@onready var btn_join_selected: Button = $UIRoot/FightSelectPanel/VBox/Buttons/JoinSelected
@onready var btn_join_cancel: Button = $UIRoot/FightSelectPanel/VBox/Buttons/Cancel

var _nm: Node = null
var _visible_overlay := true
var _listed_fights: Array[Dictionary] = []


func _ready() -> void:
	if not InputMap.has_action("ui_debug_toggle"):
		InputMap.add_action("ui_debug_toggle")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F3
		InputMap.action_add_event("ui_debug_toggle", ev)

	_nm = get_node_or_null(autoload_path)

	_visible_overlay = start_visible
	panel.visible = _visible_overlay
	fight_select_panel.visible = false
	lbl_title.text = "Debug Overlay"
	_update_network()

	btn_start.pressed.connect(_on_start_fight_pressed)
	btn_join.pressed.connect(_on_join_fight_pressed)
	btn_leave.pressed.connect(_on_leave_fight_pressed)
	btn_join_selected.pressed.connect(_on_join_selected_pressed)
	btn_join_cancel.pressed.connect(_hide_fight_select)
	fight_list.item_activated.connect(func(_index: int) -> void: _on_join_selected_pressed())


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_debug_toggle"):
		_visible_overlay = not _visible_overlay
		panel.visible = _visible_overlay
		if not _visible_overlay:
			_hide_fight_select()
	if _visible_overlay:
		_update_network()


func _get_fight_manager() -> Node:
	var overworld := get_tree().get_root().get_node_or_null("Overworld")
	if overworld == null:
		return null
	return overworld.get_node_or_null("FightManager")


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
	if fm and fm.has_method("is_peer_in_fight"):
		in_fight = fm.is_peer_in_fight(peer_id)

	lbl_network.text = "Peer ID: %s\nIs Host: %s\nConnected: %s\nReady: %s\nIn Fight: %s" % [
		peer_id, is_host, peers, ready_list, in_fight
	]
