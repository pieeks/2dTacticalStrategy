class_name GameEntry
extends RefCounted
## Thin helper: load party/world save then host or join a lobby.

const GameSettingsScript := preload("res://scripts/ui/game_settings.gd")

const ERR_NO_CHARACTER := "ui.entry.error_no_character"
const ERR_LOAD_FAILED := "ui.entry.error_load_failed"
const ERR_JOIN_FAILED := "ui.entry.error_join_failed"


## Load character + world and create a host lobby. Returns empty string on success, else tr-key.
static func start_host(character_id: String) -> String:
	var err := _load_character(character_id)
	if not err.is_empty():
		return err
	GameSettingsScript.set_last_character_id(character_id)
	if not NetworkManagerTest.create_lobby():
		return "ui.net.host_port_busy"
	return ""


## Load character + world and join lobby. Returns empty string on OK start, else tr-key.
static func start_join(character_id: String, ip: String, port: int = 4242) -> String:
	var err := _load_character(character_id)
	if not err.is_empty():
		return err
	GameSettingsScript.set_last_character_id(character_id)
	if not NetworkManagerTest.join_lobby(ip, port):
		return ERR_JOIN_FAILED
	return ""


static func _load_character(character_id: String) -> String:
	var pid := character_id.strip_edges()
	if pid.is_empty():
		return ERR_NO_CHARACTER
	if not PlayerPartyState.load_from_disk(pid):
		return ERR_LOAD_FAILED
	if WorldState.has_method("load_from_disk"):
		WorldState.load_from_disk(pid)
	return ""
