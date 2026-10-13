extends CanvasLayer
const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
## Fight HUD: turn status, Attack/Wait, and fullscreen click-catch for grid Move.

@onready var root: Control = $Root
@onready var panel: PanelContainer = $Root/Panel
@onready var status_label: Label = $Root/Panel/VBox/StatusLabel
@onready var btn_attack: Button = $Root/Panel/VBox/Buttons/AttackButton
@onready var btn_wait: Button = $Root/Panel/VBox/Buttons/WaitButton

var turn_controller: Node = null
var fight: Node2D = null
var _feedback_token: int = 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Root catches world clicks; Panel/Buttons sit on top and keep their own input.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_attack.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_wait.mouse_filter = Control.MOUSE_FILTER_STOP
	# Same cursor over panel + buttons avoids "invisible wall" flicker in the gap.
	panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	btn_attack.mouse_default_cursor_shape = Control.CURSOR_ARROW
	btn_wait.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var buttons: HBoxContainer = $Root/Panel/VBox/Buttons
	if buttons:
		buttons.add_theme_constant_override("separation", 8)
		buttons.mouse_filter = Control.MOUSE_FILTER_STOP
	if not root.gui_input.is_connected(_on_root_gui_input):
		root.gui_input.connect(_on_root_gui_input)
	btn_attack.pressed.connect(_on_attack_pressed)
	btn_wait.pressed.connect(_on_wait_pressed)
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)
	_refresh()


func _on_language_changed(_locale: String) -> void:
	_refresh()


func bind_controller(controller: Node) -> void:
	if turn_controller != null and turn_controller.has_signal("turn_state_changed"):
		if turn_controller.turn_state_changed.is_connected(_refresh):
			turn_controller.turn_state_changed.disconnect(_refresh)
	turn_controller = controller
	if turn_controller != null and turn_controller.has_signal("turn_state_changed"):
		turn_controller.turn_state_changed.connect(_refresh)
	if turn_controller != null and turn_controller.has_method("_refresh_local_highlights"):
		turn_controller.call_deferred("_refresh_local_highlights")
	_refresh()


func bind_fight(fight_node: Node2D) -> void:
	fight = fight_node


func _on_root_gui_input(event: InputEvent) -> void:
	if turn_controller == null:
		return
	# Hover preview while moving mouse over the battlefield catcher.
	if event is InputEventMouseMotion:
		var world_hover := _mouse_world_pos()
		if turn_controller.has_method("update_hover_preview"):
			turn_controller.update_hover_preview(world_hover)
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# Clicks on Panel/Buttons are handled by those controls (not bubbled as Root target
	# when they stop). Still guard: ignore if pointer is over the panel rect.
	if _pointer_over_panel():
		return
	var world_pos := _mouse_world_pos()
	var my_turn := false
	if turn_controller.has_method("is_local_players_turn"):
		my_turn = bool(turn_controller.is_local_players_turn())
	if not my_turn:
		root.accept_event()
		_flash_status(tr("battle.hud.not_your_turn"))
		return
	var handled := false
	if turn_controller.has_method("handle_world_click"):
		handled = bool(turn_controller.handle_world_click(world_pos))
	root.accept_event()
	if handled:
		_flash_status(tr("battle.hud.move_flash"))
	else:
		_flash_status(tr("battle.hud.invalid_target"))


func _pointer_over_panel() -> bool:
	if panel == null:
		return false
	return panel.get_global_rect().has_point(panel.get_global_mouse_position())


func _mouse_world_pos() -> Vector2:
	if fight != null and fight.get("grid_manager") != null:
		var grid: Node2D = fight.grid_manager as Node2D
		if grid != null:
			return grid.get_global_mouse_position()
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()


func _flash_status(msg: String) -> void:
	_feedback_token += 1
	var token := _feedback_token
	status_label.text = msg
	get_tree().create_timer(0.5).timeout.connect(
		_on_flash_timeout.bind(token), CONNECT_ONE_SHOT
	)


func _on_flash_timeout(token: int) -> void:
	if token != _feedback_token:
		return
	_refresh()


func _on_attack_pressed() -> void:
	if turn_controller == null:
		return
	if turn_controller.has_method("set_attack_mode"):
		var enabled: bool = not bool(turn_controller.get("attack_mode"))
		turn_controller.set_attack_mode(enabled)


func _on_wait_pressed() -> void:
	if turn_controller != null and turn_controller.has_method("request_wait"):
		turn_controller.request_wait()


func _refresh() -> void:
	btn_wait.text = tr("battle.hud.wait")
	if turn_controller == null:
		status_label.text = tr("battle.hud.fighting")
		btn_attack.text = tr("battle.hud.attack")
		btn_attack.disabled = true
		btn_wait.disabled = true
		return
	var phase: int = int(turn_controller.get("phase"))
	var queued := false
	if turn_controller.has_method("is_local_unit_queued"):
		queued = bool(turn_controller.is_local_unit_queued())
	if queued:
		status_label.text = tr("battle.hud.queued")
		btn_attack.text = tr("battle.hud.attack")
		btn_attack.disabled = true
		btn_wait.disabled = true
		return
	var active = null
	if turn_controller.has_method("get_active_unit"):
		active = turn_controller.get_active_unit()
	var my_turn := false
	if turn_controller.has_method("is_local_players_turn"):
		my_turn = turn_controller.is_local_players_turn()
	if phase == 3: # ENDED
		status_label.text = tr("battle.hud.ended")
		btn_attack.text = tr("battle.hud.attack")
		btn_attack.disabled = true
		btn_wait.disabled = true
		return
	if active == null:
		var phase_names: Array[String] = ["WAITING", "ACTIVE", "RESOLVING", "ENDED"]
		var pname: String = str(phase)
		if phase >= 0 and phase < phase_names.size():
			pname = phase_names[phase]
		var order_n := 0
		if turn_controller.get("turn_order") != null:
			order_n = (turn_controller.turn_order as Array).size()
		var unit_n := 0
		if turn_controller.get("units") != null:
			unit_n = (turn_controller.units as Dictionary).size()
		status_label.text = tr("battle.hud.waiting") % [pname, unit_n, order_n]
		btn_attack.text = tr("battle.hud.attack")
		btn_attack.disabled = true
		btn_wait.disabled = true
		return
	var name_str := str(active.display_name)
	var hp_str := "%d/%d" % [active.hp, active.max_hp]
	var has_attacked := bool(active.has_attacked)
	if my_turn:
		var mode: String
		if has_attacked:
			mode = tr("battle.hud.mode_attacked")
		elif bool(turn_controller.get("attack_mode")):
			mode = tr("battle.hud.mode_attack")
		else:
			mode = tr("battle.hud.mode_move")
		status_label.text = tr("battle.hud.your_turn") % [name_str, hp_str, mode]
	else:
		status_label.text = tr("battle.hud.their_turn") % [name_str, hp_str]
	btn_attack.disabled = not my_turn or has_attacked
	btn_wait.disabled = not my_turn
	if has_attacked:
		btn_attack.text = tr("battle.hud.attack")
	else:
		btn_attack.text = (
			tr("battle.hud.attack_on")
			if bool(turn_controller.get("attack_mode"))
			else tr("battle.hud.attack")
		)
