extends Control

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
const GameEntryScript := preload("res://scripts/ui/game_entry.gd")

const LEVEL_SCENE_PATH := "res://scenes/world/overworld.tscn"
const DEFAULT_IP := "127.0.0.1"
const DEFAULT_PORT := 4242

var level_scene: PackedScene
var _status_label: Label
var _join_overlay: ColorRect
var _ip_edit: LineEdit
var _port_edit: LineEdit
var _join_title: Label
var _ip_label: Label
var _port_label: Label
var _join_confirm: Button
var _join_cancel: Button


func _ready() -> void:
	level_scene = preload(LEVEL_SCENE_PATH)
	if NetworkManagerTest.has_signal("lobby_joined_finished"):
		NetworkManagerTest.connect("lobby_joined_finished", Callable(self, "_on_lobby_joined"))
	if NetworkManagerTest.has_signal("lobby_join_failed"):
		NetworkManagerTest.connect("lobby_join_failed", Callable(self, "_on_lobby_join_failed"))

	_status_label = $StatusLabel as Label
	_join_overlay = $JoinOverlay as ColorRect
	_ip_edit = $JoinOverlay/JoinPanel/JoinVBox/IpLineEdit as LineEdit
	_port_edit = $JoinOverlay/JoinPanel/JoinVBox/PortLineEdit as LineEdit
	_join_title = $JoinOverlay/JoinPanel/JoinVBox/JoinTitle as Label
	_ip_label = $JoinOverlay/JoinPanel/JoinVBox/IpLabel as Label
	_port_label = $JoinOverlay/JoinPanel/JoinVBox/PortLabel as Label
	_join_confirm = $JoinOverlay/JoinPanel/JoinVBox/JoinButtons/JoinConfirm as Button
	_join_cancel = $JoinOverlay/JoinPanel/JoinVBox/JoinButtons/JoinCancel as Button

	_connect_menu_buttons()
	_hide_join_overlay()
	_apply_static_texts()
	_set_status("")
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _join_overlay and _join_overlay.visible:
			_hide_join_overlay()
			get_viewport().set_input_as_handled()
		else:
			_on_back_to_menu_pressed()
			get_viewport().set_input_as_handled()


## Wire primary buttons in code (scene connections remain).
func _connect_menu_buttons() -> void:
	var start_btn := $Panel/ButtonContainer/StartWorld as Button
	var join_btn := $Panel/ButtonContainer/JoinWorld as Button
	var back_btn := $Panel/ButtonContainer/BackToMenu as Button
	if start_btn and not start_btn.pressed.is_connected(_on_start_world_pressed):
		start_btn.pressed.connect(_on_start_world_pressed)
	if join_btn and not join_btn.pressed.is_connected(_on_join_world_pressed):
		join_btn.pressed.connect(_on_join_world_pressed)
	if back_btn and not back_btn.pressed.is_connected(_on_back_to_menu_pressed):
		back_btn.pressed.connect(_on_back_to_menu_pressed)
	if _join_confirm and not _join_confirm.pressed.is_connected(_on_join_confirm_pressed):
		_join_confirm.pressed.connect(_on_join_confirm_pressed)
	if _join_cancel and not _join_cancel.pressed.is_connected(_on_join_cancel_pressed):
		_join_cancel.pressed.connect(_on_join_cancel_pressed)


func _on_language_changed(_locale: String) -> void:
	_apply_static_texts()


func _apply_static_texts() -> void:
	$Label.text = tr("ui.world_selection.title")
	$Panel/ButtonContainer/StartWorld.text = tr("ui.world_selection.start")
	$Panel/ButtonContainer/JoinWorld.text = tr("ui.world_selection.join")
	$Panel/ButtonContainer/BackToMenu.text = tr("ui.world_selection.back")
	if _join_title:
		_join_title.text = tr("ui.join.title")
	if _ip_label:
		_ip_label.text = tr("ui.join.host_ip")
	if _port_label:
		_port_label.text = tr("ui.join.port")
	if _join_confirm:
		_join_confirm.text = tr("ui.join.ok")
	if _join_cancel:
		_join_cancel.text = tr("ui.join.cancel")
	if _ip_edit:
		_ip_edit.placeholder_text = DEFAULT_IP
	if _port_edit:
		_port_edit.placeholder_text = str(DEFAULT_PORT)


func _set_status(key: String) -> void:
	if _status_label == null:
		return
	_status_label.text = tr(key) if not key.is_empty() else ""
	_status_label.visible = not key.is_empty()


## Show error in status label only (no Window/AcceptDialog — those block export input).
func _show_error(key: String) -> void:
	_set_status(key)


func _hide_join_overlay() -> void:
	if _join_overlay:
		_join_overlay.visible = false


func _show_join_overlay() -> void:
	_apply_static_texts()
	if _ip_edit and _ip_edit.text.strip_edges().is_empty():
		_ip_edit.text = DEFAULT_IP
	if _port_edit and _port_edit.text.strip_edges().is_empty():
		_port_edit.text = str(DEFAULT_PORT)
	if _join_overlay:
		_join_overlay.visible = true
	if _ip_edit:
		_ip_edit.grab_focus()
		_ip_edit.select_all()


func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_lobby_joined() -> void:
	_set_status("")
	get_tree().change_scene_to_packed(level_scene)


func _on_lobby_join_failed() -> void:
	_show_error(GameEntryScript.ERR_JOIN_FAILED)


func _on_start_world_pressed() -> void:
	_set_status("")
	var err := GameEntryScript.start_host(PlayerPartyState.selected_character_id)
	if not err.is_empty():
		_show_error(err)


func _on_join_world_pressed() -> void:
	_set_status("")
	_show_join_overlay()


func _on_join_cancel_pressed() -> void:
	_hide_join_overlay()


func _on_join_confirm_pressed() -> void:
	var ip := DEFAULT_IP
	if _ip_edit:
		ip = _ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = DEFAULT_IP
	var port := DEFAULT_PORT
	if _port_edit:
		var parsed := int(_port_edit.text.strip_edges())
		if parsed > 0 and parsed < 65536:
			port = parsed
	_hide_join_overlay()
	_set_status("ui.entry.connecting")
	var err := GameEntryScript.start_join(PlayerPartyState.selected_character_id, ip, port)
	if not err.is_empty():
		_show_error(err)
