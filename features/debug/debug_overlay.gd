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

var _nm: Node = null
var _visible_overlay := true


func _ready() -> void:
	if not InputMap.has_action("ui_debug_toggle"):
		InputMap.add_action("ui_debug_toggle")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F3
		InputMap.action_add_event("ui_debug_toggle", ev)

	_nm = get_node_or_null(autoload_path)

	_visible_overlay = start_visible
	panel.visible = _visible_overlay
	lbl_title.text = "Debug Overlay"
	_update_network()

	btn_start.pressed.connect(_on_start_fight_pressed)
	btn_join.pressed.connect(_on_join_fight_pressed)
	btn_leave.pressed.connect(_on_leave_fight_pressed)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_debug_toggle"):
		_visible_overlay = not _visible_overlay
		panel.visible = _visible_overlay
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
	if multiplayer.is_server():
		fm._process_join_request(multiplayer.get_unique_id())
	else:
		fm.rpc_id(1, "rpc_request_join_fight")


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
