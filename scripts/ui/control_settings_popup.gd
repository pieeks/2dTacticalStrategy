## Input rebinding UI with persistence and reset-to-defaults.
extends Control

const GameSettingsScript := preload("res://scripts/ui/game_settings.gd")

var waiting_for_key: String = ""
var rebind_button: Button = null


func _ready() -> void:
	for container in $ControlSettingsButtonContainer.get_children():
		for button in container.get_children():
			if button is Button and button.has_meta("action_name"):
				button.pressed.connect(_on_rebind_button_pressed.bind(button))
	var reset_btn := get_node_or_null("ControlSettingsButtonContainer/ResetControls") as Button
	if reset_btn != null and not reset_btn.pressed.is_connected(_on_reset_controls_pressed):
		reset_btn.pressed.connect(_on_reset_controls_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_button_labels()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_button_labels()


## Refresh rebind button texts from the current InputMap.
func _refresh_button_labels() -> void:
	for container in $ControlSettingsButtonContainer.get_children():
		for button in container.get_children():
			if button is Button and button.has_meta("action_name"):
				var action: String = str(button.get_meta("action_name"))
				button.text = _action_key_label(action)


func _action_key_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			return (ev as InputEventKey).as_text()
	return "-"


func _on_rebind_button_pressed(button: Button) -> void:
	waiting_for_key = button.get_meta("action_name")
	rebind_button = button
	button.text = "..."


func _input(event: InputEvent) -> void:
	if waiting_for_key != "" and event is InputEventKey and event.is_pressed():
		InputMap.action_erase_events(waiting_for_key)
		InputMap.action_add_event(waiting_for_key, event)
		GameSettingsScript.save_walk_bindings()
		if rebind_button:
			rebind_button.text = event.as_text()
		waiting_for_key = ""
		rebind_button = null


func _on_reset_controls_pressed() -> void:
	GameSettingsScript.reset_walk_bindings_to_defaults()
	_refresh_button_labels()
