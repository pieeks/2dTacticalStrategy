extends CanvasLayer
class_name DebugOverlay

@export var autoload_path: NodePath = NodePath("/root/NetworkManagerTest") # <- anpassbar im Inspector
@export var start_visible: bool = false

@onready var panel: PanelContainer = $PanelContainer
@onready var vbox: VBoxContainer = $PanelContainer/VBoxContainer
@onready var lbl_title: Label = $PanelContainer/VBoxContainer/DebugOverlay    # deine Namen
@onready var lbl_network: Label = $PanelContainer/VBoxContainer/NetworkInfo   # deine Namen

var _nm: Node = null
var _visible_overlay := true

func _ready() -> void:
	# Toggle-Action bereitstellen (F3), falls nicht vorhanden
	if not InputMap.has_action("ui_debug_toggle"):
		InputMap.add_action("ui_debug_toggle")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F3
		InputMap.action_add_event("ui_debug_toggle", ev)

	# Autoload-Instanz holen (wichtig: Autoloads hängen unter /root/NAME)
	_nm = get_node_or_null(autoload_path)

	_visible_overlay = start_visible
	panel.visible = _visible_overlay
	lbl_title.text = "Debug Overlay"
	_update_network()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_debug_toggle"):
		_visible_overlay = not _visible_overlay
		panel.visible = _visible_overlay
	if _visible_overlay:
		_update_network()

func _update_network() -> void:
	if _nm == null:
		# ggf. einmalig retry (z. B. wenn Overlay vor Autoload geladen wurde)
		_nm = get_node_or_null(autoload_path)
		if _nm == null:
			lbl_network.text = "No NetworkManager found at: %s" % [autoload_path]
			return

	# Defensive reads (Host/Client können früh null sein)
	var peer_id := 0
	var is_host := false
	var peers := []
	var ready := []

	if "get_unique_id" in _nm:
		peer_id = _nm.get_unique_id()
	if "is_host" in _nm:
		is_host = _nm.is_host
	if "multiplayer" in _nm and _nm.multiplayer and _nm.multiplayer.has_multiplayer_peer():
		peers = _nm.multiplayer.get_peers()
	if "_ready_peers" in _nm and typeof(_nm._ready_peers) == TYPE_DICTIONARY:
		ready = _nm._ready_peers.keys()

	lbl_network.text = "Peer ID: %s\nIs Host: %s\nConnected: %s\nReady: %s" % [
		peer_id, is_host, peers, ready
	]
