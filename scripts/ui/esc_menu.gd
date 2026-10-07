extends CanvasLayer

## Pause Menu UI
##
## This script manages the in-game pause menu.
## It handles toggling visibility with ESC, pausing/unpausing the game tree,
## and showing the settings popup. It also provides save + quit functionality.
##
## Features:
## - ESC key toggles the pause menu (uses "ui_cancel" action)
## - Game pauses only when appropriate (depends on multiplayer state)
## - Resume, Options, Back, and Save + Quit buttons
## - Integrates with PlayerPartyState for saving game data

## Reference to the settings popup control.
@onready var settings_popup: Control = $SettingsPopup


## Called when the node enters the scene tree.
## Initializes visibility, process mode, and popup connections.
func _ready() -> void:
	visible = false
	settings_popup.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_popup.connect("popup_closed", Callable(self, "_on_back_pressed"))


## Handles input events for toggling the pause menu.
## Uses "ui_cancel" (default = ESC) to open/close.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): 
		if visible: 
			_close_menu()
		else:
			_open_menu()


## Opens the pause menu and pauses the game if allowed.
func _open_menu() -> void:
	visible = true
	if _can_pause():
		get_tree().paused = true
	else: 
		get_tree().paused = false


## Closes the pause menu and unpauses the game.
func _close_menu() -> void:
	visible = false
	get_tree().paused = false


## Determines whether the game can be paused.
## Multiplayer servers should not be paused while peers are connected.
##
## @return bool: True if pausing is allowed, false otherwise.
func _can_pause() -> bool:
	if not multiplayer.is_server():
		return false
	
	var peers := multiplayer.get_peers()
	return peers.size() == 0


## Saves the current game state.
## Uses PlayerPartyState to persist data to disk.
func _save_game() -> void:
	if PlayerPartyState:
		PlayerPartyState.save_to_disk()
	# TODO: Add WorldState saving when JSON load/save is ready
	#if WorldState:
	#	WorldState.save_to_disk()


## Button callback: resumes the game without closing the application.
func _on_resume_pressed() -> void:
	_close_menu()


## Button callback: shows the settings popup.
func _on_options_pressed() -> void:
	$UIRoot/Panel/VBoxContainer.visible = false
	$SettingsPopup.visible = true


## Button callback: hides the settings popup and shows the main pause menu.
func _on_back_pressed() -> void:
	$UIRoot/Panel/VBoxContainer.visible = true
	$SettingsPopup.visible = false


## Button callback: saves game state, disconnects from multiplayer if active,
## and returns to the main menu.
func _on_save_and_quit_pressed() -> void:
	print("Save and Quit Button pressed!")
	get_tree().paused = false
	_save_game()
	# Close peer first so clients get server_disconnected and leave cleanly
	# (avoids empty Overworld after host despawns MultiplayerSpawner).
	NetworkManagerTest.reset_session()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
