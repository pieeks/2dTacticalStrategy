## Input Rebinding UI
##
## This script allows the player to rebind input keys via UI buttons.
## Each button is associated with an input action (via "action_name" metadata).
## When pressed, the script waits for the next key press and updates the binding
## in Godot's InputMap as well as the button label.
##
## Features:
## - Dynamically detects buttons with "action_name" metadata
## - Listens for key input when a button is pressed
## - Updates InputMap and button text immediately
##
## Usage:
## - Attach this script to a Control node that contains a container of rebind buttons.
## - Each button must have a metadata entry: `button.set_meta("action_name", "ui_accept")`.
## - The button's text will be updated to display the chosen key.

extends Control

## Name of the input action currently waiting for a new binding.
var waiting_for_key : String = ""

## Reference to the button that triggered the rebind process.
var rebind_button : Button = null


## Called when the node enters the scene tree.
## Iterates through all child containers and connects button signals.
func _ready() -> void:
	for container in $ControlSettingsButtonContainer.get_children(): 
		for button in container.get_children(): 
			if button is Button and button.has_meta("action_name"):
				# Bind button press to the rebind handler
				button.pressed.connect(_on_rebind_button_pressed.bind(button))


## Called when a rebind button is pressed.
## Prepares to listen for the next key press by storing the action name
## and the reference to the pressed button.
##
## @param button Button: The button that triggered the rebind.
func _on_rebind_button_pressed(button: Button): 
	waiting_for_key = button.get_meta("action_name")
	rebind_button = button


## Handles global input events.
## If waiting for a key, captures the pressed key and applies it:
## - Erases existing bindings for the action
## - Adds the new key event to the InputMap
## - Updates the button text to show the new key
##
## @param event InputEvent: The input event to process.
func _input(event): 
	if waiting_for_key != "" and event is InputEventKey and event.is_pressed():
		# Update InputMap with new key binding
		InputMap.action_erase_events(waiting_for_key)
		InputMap.action_add_event(waiting_for_key, event)
		
		# Update button text to show assigned key
		if rebind_button: 
			rebind_button.text = event.as_text()
		
		# Reset rebind state
		waiting_for_key = ""
		rebind_button = null
