class_name GameSettings
extends RefCounted
## Shared settings store for audio/video/input/session in user://settings.cfg.
## Locale stays in LocaleManager (same file, section [locale]).

const SETTINGS_PATH := "user://settings.cfg"
const WALK_ACTIONS: PackedStringArray = ["walk_up", "walk_down", "walk_left", "walk_right"]

static var _applied_boot: bool = false


## Load CFG and apply audio/video/input once per process (safe to call repeatedly).
static func apply_boot_settings() -> void:
	if _applied_boot:
		return
	_applied_boot = true
	ensure_audio_buses()
	apply_audio_from_cfg()
	apply_video_from_cfg()
	apply_input_from_cfg()


## Ensure Master / Music / SFX buses exist (Music+SFX send to Master).
static func ensure_audio_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")


static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


static func get_master_linear() -> float:
	return float(_cfg().get_value("audio", "master_linear", 0.2))


static func get_music_linear() -> float:
	return float(_cfg().get_value("audio", "music_linear", 0.8))


static func get_sfx_linear() -> float:
	return float(_cfg().get_value("audio", "sfx_linear", 0.8))


static func set_master_linear(value: float, persist: bool = true) -> void:
	value = clampf(value, 0.0, 1.0)
	_set_bus_linear("Master", value)
	if persist:
		_set_and_save("audio", "master_linear", value)


static func set_music_linear(value: float, persist: bool = true) -> void:
	value = clampf(value, 0.0, 1.0)
	ensure_audio_buses()
	_set_bus_linear("Music", value)
	if persist:
		_set_and_save("audio", "music_linear", value)


static func set_sfx_linear(value: float, persist: bool = true) -> void:
	value = clampf(value, 0.0, 1.0)
	ensure_audio_buses()
	_set_bus_linear("SFX", value)
	if persist:
		_set_and_save("audio", "sfx_linear", value)


static func apply_audio_from_cfg() -> void:
	ensure_audio_buses()
	_set_bus_linear("Master", get_master_linear())
	_set_bus_linear("Music", get_music_linear())
	_set_bus_linear("SFX", get_sfx_linear())


static func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var v := clampf(linear, 0.0001, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(v))


static func get_video_size() -> Vector2i:
	var cfg := _cfg()
	return Vector2i(
		int(cfg.get_value("video", "width", 1280)),
		int(cfg.get_value("video", "height", 720))
	)


static func is_fullscreen() -> bool:
	return bool(_cfg().get_value("video", "fullscreen", false))


static func save_video(width: int, height: int, fullscreen: bool) -> void:
	var cfg := _cfg()
	cfg.set_value("video", "width", width)
	cfg.set_value("video", "height", height)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


static func apply_video_from_cfg() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var window := tree.root
	var fullscreen := is_fullscreen()
	if fullscreen:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = get_video_size()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_factor = 1.0
	window.content_scale_size = Vector2i(640, 360)


## Persist current InputMap bindings for walk actions.
static func save_walk_bindings() -> void:
	var cfg := _cfg()
	for action in WALK_ACTIONS:
		var events: Array = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				events.append({
					"type": "key",
					"keycode": (ev as InputEventKey).keycode,
					"physical_keycode": (ev as InputEventKey).physical_keycode,
				})
		cfg.set_value("input", action, events)
	cfg.save(SETTINGS_PATH)


static func apply_input_from_cfg() -> void:
	var cfg := _cfg()
	for action in WALK_ACTIONS:
		if not cfg.has_section_key("input", action):
			continue
		var raw: Variant = cfg.get_value("input", action, [])
		if raw is not Array:
			continue
		InputMap.action_erase_events(action)
		for item in raw:
			if item is not Dictionary:
				continue
			var d: Dictionary = item
			if str(d.get("type", "")) != "key":
				continue
			var ev := InputEventKey.new()
			ev.keycode = int(d.get("keycode", 0)) as Key
			ev.physical_keycode = int(d.get("physical_keycode", 0)) as Key
			InputMap.action_add_event(action, ev)


## Restore project.godot defaults for walk actions, then persist.
static func reset_walk_bindings_to_defaults() -> void:
	var defaults := {
		"walk_up": KEY_W,
		"walk_down": KEY_S,
		"walk_left": KEY_A,
		"walk_right": KEY_D,
	}
	for action in WALK_ACTIONS:
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.keycode = defaults[action]
		ev.physical_keycode = defaults[action]
		InputMap.action_add_event(action, ev)
	save_walk_bindings()


static func get_last_character_id() -> String:
	return str(_cfg().get_value("session", "last_character_id", "")).strip_edges()


static func set_last_character_id(character_id: String) -> void:
	_set_and_save("session", "last_character_id", character_id.strip_edges())


static func clear_last_character_id_if(character_id: String) -> void:
	if get_last_character_id() == character_id:
		set_last_character_id("")


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # ignore missing
	return cfg


static func _set_and_save(section: String, key: String, value: Variant) -> void:
	var cfg := _cfg()
	cfg.set_value(section, key, value)
	cfg.save(SETTINGS_PATH)
