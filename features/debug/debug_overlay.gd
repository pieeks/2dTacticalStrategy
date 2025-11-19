extends CanvasLayer
class_name DebugOverlay

## DebugOverlay
##
## A simple in-game debug HUD for network information.
## Displays peer ID, host/client status, connected peers, and "ready" peers.
## Can be toggled on/off via F3 (configurable in InputMap).
##
## Features:
## - Autoload reference configurable via `autoload_path`
## - Displays live network info if a NetworkManager is present
## - Toggle visibility with "ui_debug_toggle" action (default = F3)
## - Useful for development/testing of multiplayer sessions

## NodePath to the NetworkManager autoload (adjustable in Inspector).
@export var autoload_path: NodePath = NodePath("/root/NetworkManagerTest")

## Whether the overlay starts visible when the game launches.
@export var start_visible: bool = false

## Cached references to UI elements inside the overlay.
@onready var panel: PanelContainer = $UIRoot/PanelContainer
@onready var vbox: VBoxContainer = $UIRoot/PanelContainer/VBoxContainer
@onready var lbl_title: Label = $UIRoot/PanelContainer/VBoxContainer/DebugOverlay
@onready var lbl_network: Label = $UIRoot/PanelContainer/VBoxContainer/NetworkInfo

## Cached reference to the NetworkManager autoload (if found).
var _nm: Node = null

## Tracks whether the overlay is currently visible.
var _visible_overlay := true


## Called when the node enters the scene tree.
## Sets up the toggle action, grabs the autoload reference,
## and initializes overlay visibility.
func _ready() -> void:
	# Ensure toggle action exists (default = F3)
	if not InputMap.has_action("ui_debug_toggle"):
		InputMap.add_action("ui_debug_toggle")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F3
		InputMap.action_add_event("ui_debug_toggle", ev)

	# Try to fetch the autoload instance
	_nm = get_node_or_null(autoload_path)

	_visible_overlay = start_visible
	panel.visible = _visible_overlay
	lbl_title.text = "Debug Overlay"
	_update_network()


## Called every frame.
## Checks for toggle input and updates the overlay if visible.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_debug_toggle"):
		_visible_overlay = not _visible_overlay
		panel.visible = _visible_overlay
	if _visible_overlay:
		_update_network()


## Updates the network information displayed on the overlay.
## Retrieves data from the NetworkManager if available:
## - Peer ID
## - Host/Client status
## - List of connected peers
## - List of ready peers
func _update_network() -> void:
	if _nm == null:
		# Retry in case NetworkManager was not ready at _ready()
		_nm = get_node_or_null(autoload_path)
		if _nm == null:
			lbl_network.text = "No NetworkManager found at: %s" % [autoload_path]
			return

	# Defensive reads: only query properties if they exist
	var peer_id := 0
	var is_host := false
	var peers := []
	var readyList := []

	if "get_unique_id" in _nm:
		peer_id = _nm.get_unique_id()
	if "is_host" in _nm:
		is_host = _nm.is_host
	if "multiplayer" in _nm and _nm.multiplayer and _nm.multiplayer.has_multiplayer_peer():
		peers = _nm.multiplayer.get_peers()
	if "_ready_peers" in _nm and typeof(_nm._ready_peers) == TYPE_DICTIONARY:
		readyList = _nm._ready_peers.keys()

	# Update overlay label with network info
	lbl_network.text = "Peer ID: %s\nIs Host: %s\nConnected: %s\nReady: %s" % [
		peer_id, is_host, peers, readyList
	]
