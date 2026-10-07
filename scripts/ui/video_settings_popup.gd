extends Control

## VideoSettings
##
## Handles resolution and fullscreen settings from the video options menu.
## Applies size on the root Window and refreshes content scale so downscaling
## (e.g. 2560x1440 -> 1280x720) does not leave a stale scale factor.
##
## Features:
## - Reads resolution strings (e.g. "1920x1080") from a dropdown
## - Changes window size based on selected resolution
## - Toggles fullscreen mode on/off
##
## Usage:
## - Attach this script to your Video Settings UI root node
## - Ensure there is a `ResolutionDropDown` OptionButton inside
##   `$VideoSettingsButtonContainer`
## - Connect dropdown's `item_selected` to `_on_resolution_drop_down_item_selected`
## - Connect fullscreen toggle's `toggled` to `_on_fullscreen_toggled`

const BASE_SIZE := Vector2i(640, 360)

@onready var _dropdown: OptionButton = $VideoSettingsButtonContainer/ResolutionDropDown
@onready var _fullscreen: CheckBox = $VideoSettingsButtonContainer/Fullscreen

var _syncing_ui: bool = false


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_sync_ui_from_window()


func _on_visibility_changed() -> void:
	if visible:
		_sync_ui_from_window()


func _sync_ui_from_window() -> void:
	if _dropdown == null:
		return
	_syncing_ui = true
	var window := get_window()
	var current := window.size
	var matched := false
	for i in _dropdown.item_count:
		var parts: PackedStringArray = _dropdown.get_item_text(i).split("x")
		if parts.size() != 2:
			continue
		if int(parts[0]) == current.x and int(parts[1]) == current.y:
			_dropdown.select(i)
			matched = true
			break
	if not matched and _dropdown.item_count > 0:
		# Fallback: pick closest so something is always shown.
		var best_i := 0
		var best_dist: float = INF
		for i in _dropdown.item_count:
			var parts: PackedStringArray = _dropdown.get_item_text(i).split("x")
			if parts.size() != 2:
				continue
			var option_size := Vector2i(int(parts[0]), int(parts[1]))
			var dist: float = absf(float(option_size.x - current.x)) + absf(float(option_size.y - current.y))
			if dist < best_dist:
				best_dist = dist
				best_i = i
		_dropdown.select(best_i)
	if _fullscreen:
		_fullscreen.set_pressed_no_signal(
			window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
			or window.mode == Window.MODE_FULLSCREEN
		)
	_syncing_ui = false


func _on_resolution_drop_down_item_selected(index: int) -> void:
	if _syncing_ui:
		return
	var res_text: String = _dropdown.get_item_text(index)
	var parts: PackedStringArray = res_text.split("x")

	if parts.size() != 2:
		push_warning("Invalid resolution entry: %s" % res_text)
		return

	var width := int(parts[0])
	var height := int(parts[1])
	if width <= 0 or height <= 0:
		push_warning("Invalid resolution values: %s" % res_text)
		return

	await _apply_windowed_resolution(Vector2i(width, height))
	_sync_ui_from_window()


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if _syncing_ui:
		return
	var window := get_window()
	if toggled_on:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_refresh_content_scale(window)
	else:
		window.mode = Window.MODE_WINDOWED
		_refresh_content_scale(window)
		await get_tree().process_frame
		_center_window()
	_sync_ui_from_window()


func _apply_windowed_resolution(target_size: Vector2i) -> void:
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = target_size
	_refresh_content_scale(window)
	# Size/position may apply one frame later (esp. on Wayland).
	await get_tree().process_frame
	await get_tree().process_frame
	if window.size != target_size:
		window.size = target_size
		_refresh_content_scale(window)
		await get_tree().process_frame
	_center_window()


func _refresh_content_scale(window: Window) -> void:
	# Factor must stay 1.0: Godot already fits content_scale_size into the window.
	# A computed factor (window/base) would double-scale and look "zoomed in".
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_factor = 1.0
	window.content_scale_size = BASE_SIZE


func _center_window() -> void:
	var window := get_window()
	var screen := window.current_screen
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var window_size := window.size
	var offset := screen_size - window_size
	window.position = screen_pos + Vector2i(int(offset.x / 2.0), int(offset.y / 2.0))
