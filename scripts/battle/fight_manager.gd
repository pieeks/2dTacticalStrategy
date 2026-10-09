extends Node
## Host-Autorität: Start/Ende/Join von Kämpfen, RPCs, Join-in-Progress-Sync.

signal fight_ended_for_peer(peer_id: int)

@export var fight_scene: PackedScene

@onready var fight_layer: Node = $"../FightLayer"

var is_fight_active: bool = false
var peers_in_fight: Dictionary = {}


func is_peer_in_fight(peer_id: int) -> bool:
	return peers_in_fight.get(peer_id, false) == true


func notify_peer_left_fight(peer_id: int) -> void:
	rpc_end_fight_for_peer.rpc(peer_id)


func start_fight_for_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if is_peer_in_fight(peer_id):
		return
	print("FightManager: start_fight_for_peer ", peer_id)
	peers_in_fight[peer_id] = true
	rpc_start_fight.rpc(peer_id)


func end_fight_for_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_process_end_request(peer_id)


func sync_active_fights_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for child in fight_layer.get_children():
		if child.has_method("get_owner_peer_id") and child.get("participants") != null:
			var participants_list: Array = []
			for p in child.participants:
				participants_list.append(p)
			rpc_create_existing_fight.rpc_id(peer_id, child.get_owner_peer_id(), participants_list)


func _process_end_request(requester_id: int) -> void:
	for child in fight_layer.get_children():
		if not child.has_method("has_participant"):
			continue
		if not child.has_participant(requester_id):
			continue
		var owner_id: int = child.get_owner_peer_id() if child.has_method("get_owner_peer_id") else 0
		if requester_id == owner_id:
			child.request_end_fight()
		else:
			child.request_leave_peer(requester_id)
		return


func _process_join_request(requester_id: int) -> void:
	if is_peer_in_fight(requester_id):
		return
	for child in fight_layer.get_children():
		if not child.has_method("add_participant"):
			continue
		if child.has_method("has_participant") and child.has_participant(requester_id):
			return
		var owner_id := 0
		if child.has_method("get_owner_peer_id"):
			owner_id = child.get_owner_peer_id()
		var participants_list: Array = []
		if child.get("participants") != null:
			for p in child.participants:
				participants_list.append(int(p))
		if not participants_list.has(requester_id):
			participants_list.append(requester_id)
		rpc_sync_join_fight.rpc(owner_id, requester_id, participants_list)
		return


func _on_fight_ready_to_remove(owner_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var fight_node: Node = null
	for child in fight_layer.get_children():
		if child.has_method("get_owner_peer_id") and child.get_owner_peer_id() == owner_peer_id:
			fight_node = child
			break
	if fight_node == null:
		return
	var participants_snapshot: Array = []
	if fight_node.get("participants") != null:
		for p in fight_node.participants:
			participants_snapshot.append(p)
	for p in participants_snapshot:
		rpc_end_fight_for_peer.rpc(p)
	fight_node.queue_free()
	rpc_destroy_fight_instance.rpc(owner_peer_id)
	if fight_layer.get_child_count() == 0:
		is_fight_active = false


@rpc("any_peer", "call_local", "reliable")
func rpc_start_fight(owner_peer_id: int) -> void:
	if fight_scene == null:
		push_error("FightManager: fight_scene ist nicht gesetzt.")
		return
	if fight_layer.get_node_or_null("Fight_%d" % owner_peer_id) != null:
		return
	var fight_instance: Node2D = fight_scene.instantiate()
	fight_instance.name = "Fight_%d" % owner_peer_id
	if fight_instance.has_method("set_owner_peer_id"):
		fight_instance.set_owner_peer_id(owner_peer_id)
	fight_layer.add_child(fight_instance)
	if fight_instance.has_signal("fight_ready_to_remove"):
		fight_instance.fight_ready_to_remove.connect(_on_fight_ready_to_remove)
	is_fight_active = true
	peers_in_fight[owner_peer_id] = true


@rpc("any_peer", "reliable")
func rpc_create_existing_fight(owner_peer_id: int, participants_list: Array) -> void:
	if fight_scene == null:
		push_error("FightManager: rpc_create_existing_fight - fight_scene ist null.")
		return
	if fight_layer.get_node_or_null("Fight_%d" % owner_peer_id) != null:
		return
	var fight_instance: Node2D = fight_scene.instantiate()
	fight_instance.name = "Fight_%d" % owner_peer_id
	if fight_instance.has_method("set_owner_peer_id"):
		fight_instance.set_owner_peer_id(owner_peer_id)
	if fight_instance.has_method("set_participants"):
		fight_instance.set_participants(participants_list)
	fight_layer.add_child(fight_instance)
	if fight_instance.has_signal("fight_ready_to_remove"):
		fight_instance.fight_ready_to_remove.connect(_on_fight_ready_to_remove)
	is_fight_active = true
	for p in participants_list:
		peers_in_fight[int(p)] = true


@rpc("any_peer", "reliable")
func rpc_request_start_fight() -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	start_fight_for_peer(requester_id)


@rpc("any_peer", "reliable")
func rpc_request_join_fight() -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	_process_join_request(requester_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_sync_join_fight(owner_peer_id: int, peer_id: int, participants_list: Array = []) -> void:
	peers_in_fight[peer_id] = true
	var fight_node: Node = fight_layer.get_node_or_null("Fight_%d" % owner_peer_id)
	if fight_node == null:
		# Late-join race: fight not yet on this peer — create from snapshot then join.
		if fight_scene == null:
			push_error("FightManager: rpc_sync_join_fight - fight_scene ist null.")
			return
		var snapshot: Array = participants_list.duplicate()
		if not snapshot.has(peer_id):
			snapshot.append(peer_id)
		if not snapshot.has(owner_peer_id) and owner_peer_id != 0:
			snapshot.append(owner_peer_id)
		var fight_instance: Node2D = fight_scene.instantiate()
		fight_instance.name = "Fight_%d" % owner_peer_id
		if fight_instance.has_method("set_owner_peer_id"):
			fight_instance.set_owner_peer_id(owner_peer_id)
		if fight_instance.has_method("set_participants"):
			fight_instance.set_participants(snapshot)
		fight_layer.add_child(fight_instance)
		if fight_instance.has_signal("fight_ready_to_remove"):
			fight_instance.fight_ready_to_remove.connect(_on_fight_ready_to_remove)
		is_fight_active = true
		for p in snapshot:
			peers_in_fight[int(p)] = true
		if fight_instance.has_method("add_participant"):
			fight_instance.add_participant(peer_id)
		return
	if fight_node.has_method("add_participant"):
		fight_node.add_participant(peer_id)


@rpc("any_peer", "reliable")
func rpc_request_end_fight_for_peer() -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	end_fight_for_peer(requester_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_end_fight_for_peer(peer_id: int) -> void:
	peers_in_fight[peer_id] = false
	if fight_layer.get_child_count() == 0:
		is_fight_active = false
	fight_ended_for_peer.emit(peer_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_destroy_fight_instance(owner_peer_id: int) -> void:
	if multiplayer.is_server():
		return
	var fight_node: Node = fight_layer.get_node_or_null("Fight_%d" % owner_peer_id)
	if fight_node:
		fight_node.queue_free()
	if fight_layer.get_child_count() == 0:
		is_fight_active = false
