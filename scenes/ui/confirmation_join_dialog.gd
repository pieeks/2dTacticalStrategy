extends ConfirmationDialog

@onready var label: RichTextLabel = $Label as RichTextLabel

var _queue: Array[Dictionary] = []
var _current_peer_id: int = -1

func _ready() -> void:
	# nur beim Host aktiv
	if not multiplayer.is_server():
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		return

	get_ok_button().text = "Annehmen"
	get_cancel_button().text = "Ablehnen"

	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)

	NetworkManagerTest.join_request_received.connect(_on_join_request)
	NetworkManagerTest.join_request_decided.connect(_on_decided)

func _on_join_request(peer_id: int, player_name: String, meta: Dictionary) -> void:
	_queue.append({"peer_id": peer_id, "player_name": player_name, "meta": meta})
	if not visible:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_current_peer_id = -1
		hide()
		return

	var item: Dictionary = _queue.pop_front() as Dictionary
	_current_peer_id = int(item["peer_id"])
	var meta: Dictionary = item["meta"] as Dictionary
	var player_name: String = String(item["player_name"])
	var ver: String = str(meta.get("godot_version", "?"))

	label.clear()
	label.append_text("%s möchte beitreten.\nPeer-ID: %d\nGodot: %s" % [player_name, _current_peer_id, ver])
	popup_centered()

func _on_confirmed() -> void:
	if _current_peer_id != -1:
		NetworkManagerTest.host_accept_peer(_current_peer_id)
	_show_next()

func _on_canceled() -> void:
	if _current_peer_id != -1:
		NetworkManagerTest.host_deny_peer(_current_peer_id, "Host hat abgelehnt")
	_show_next()

func _on_decided(_peer_id: int, _accepted: bool, _reason: String) -> void:
	# optional: toast/log
	pass
