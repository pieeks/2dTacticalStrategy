extends Control

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
const GameEntryScript := preload("res://scripts/ui/game_entry.gd")

const LEVEL_SCENE_PATH := "res://scenes/world/overworld.tscn"
const JOIN_DIALOG_SCENE := preload("res://scenes/ui/confirmation_join_dialog.tscn")

var level_scene: PackedScene
var _join_dialog: Node
var _status_label: Label


func _ready() -> void:
	level_scene = preload(LEVEL_SCENE_PATH)
	if NetworkManagerTest.has_signal("lobby_joined_finished"):
		NetworkManagerTest.connect("lobby_joined_finished", Callable(self, "_on_lobby_joined"))
	if NetworkManagerTest.has_signal("lobby_join_failed"):
		NetworkManagerTest.connect("lobby_join_failed", Callable(self, "_on_lobby_join_failed"))

	_join_dialog = JOIN_DIALOG_SCENE.instantiate()
	add_child(_join_dialog)
	_join_dialog.connect("join_confirmed", Callable(self, "_on_join_confirmed"))
	_status_label = $CanvasLayer/UIRoot.get_node_or_null("StatusLabel") as Label
	_apply_static_texts()
	_set_status("")
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	_apply_static_texts()


func _apply_static_texts() -> void:
	$CanvasLayer/UIRoot/Label.text = tr("ui.world_selection.title")
	$CanvasLayer/UIRoot/Panel/VBoxContainer/StartWorld.text = tr("ui.world_selection.start")
	$CanvasLayer/UIRoot/Panel/VBoxContainer/JoinWorld.text = tr("ui.world_selection.join")
	$CanvasLayer/UIRoot/Panel/VBoxContainer/BackToMenu.text = tr("ui.world_selection.back")


func _set_status(key: String) -> void:
	if _status_label == null:
		return
	_status_label.text = tr(key) if not key.is_empty() else ""
	_status_label.visible = not key.is_empty()


func _show_error(key: String) -> void:
	_set_status(key)
	var dialog := AcceptDialog.new()
	dialog.title = tr("ui.entry.error_title")
	dialog.dialog_text = tr(key)
	dialog.ok_button_text = tr("ui.net.ok")
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()


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
	if _join_dialog and _join_dialog.has_method("popup_join"):
		_join_dialog.popup_join()
	elif _join_dialog:
		_join_dialog.popup_centered()


func _on_join_confirmed(ip: String, port: int = 4242) -> void:
	_set_status("ui.entry.connecting")
	var err := GameEntryScript.start_join(PlayerPartyState.selected_character_id, ip, port)
	if not err.is_empty():
		_show_error(err)
