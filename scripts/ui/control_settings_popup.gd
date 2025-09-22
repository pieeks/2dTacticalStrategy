extends Control

var waiting_for_key : String = ""
var rebind_button : Button = null

func _ready() -> void:
	for container in $ControlSettingsButtonContainer.get_children(): 
		for button in container.get_children(): 
			if button is Button and button.has_meta("action_name"):
				button.pressed.connect(_on_rebind_button_pressed.bind(button))


func _on_rebind_button_pressed(button: Button): 
	waiting_for_key = button.get_meta("action_name")
	rebind_button = button


func _input(event): 
	if waiting_for_key != "" and event is InputEventKey and event.is_pressed():
		InputMap.action_erase_events(waiting_for_key)
		InputMap.action_add_event(waiting_for_key, event)
		
		if rebind_button: 
			rebind_button.text = event.as_text()
		
		#Reset
		waiting_for_key = ""
		rebind_button = null
