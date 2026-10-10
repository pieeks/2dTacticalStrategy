extends Node
## Host-Autorität: Start/Ende/Join von Kämpfen, Encounter-Lock, Join-in-Progress-Sync.

signal fight_ended_for_peer(peer_id: int)

@export var fight_scene: PackedScene

@onready var fight_layer: Node = $"../FightLayer"

var is_fight_active: bool = false
var peers_in_fight: Dictionary = {}
## peer_id -> ticks_msec until a new Start/Join/Encounter is allowed (Leave/Niederlage).
var _peer_fight_cooldown_until: Dictionary = {}

const FIGHT_LEAVE_COOLDOWN_MS: int = 1500


func is_peer_in_fight(peer_id: int) -> bool:
	return peers_in_fight.get(peer_id, false) == true


func is_peer_on_fight_cooldown(peer_id: int) -> bool:
	var until_ms: int = int(_peer_fight_cooldown_until.get(peer_id, 0))
	return Time.get_ticks_msec() < until_ms


func _arm_fight_leave_cooldown(peer_id: int) -> void:
	_peer_fight_cooldown_until[peer_id] = Time.get_ticks_msec() + FIGHT_LEAVE_COOLDOWN_MS


func notify_peer_left_fight(peer_id: int) -> void:
	rpc_end_fight_for_peer.rpc(peer_id)


func start_fight_for_peer(peer_id: int) -> void:
	start_fight_with_encounter(peer_id, {})


func start_fight_with_encounter(peer_id: int, encounter: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if is_peer_in_fight(peer_id):
		return
	if is_peer_on_fight_cooldown(peer_id):
		return
	print("FightManager: start_fight_with_encounter ", peer_id, " ", encounter.get("npc_type", ""))
	peers_in_fight[peer_id] = true
	rpc_start_fight.rpc(peer_id, encounter)
	var npc_path := str(encounter.get("npc_path", ""))
	if npc_path != "":
		rpc_lock_overworld_npc.rpc(npc_path)


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
			var encounter: Dictionary = {}
			if child.has_method("get_encounter"):
				encounter = child.get_encounter()
			var turn_state: Dictionary = {}
			if child.has_method("get_turn_state"):
				turn_state = child.get_turn_state()
			rpc_create_existing_fight.rpc_id(
				peer_id, child.get_owner_peer_id(), participants_list, encounter, turn_state
			)


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


## Find fight instance that currently includes peer_id.
func find_fight_for_peer(peer_id: int) -> Node:
	for child in fight_layer.get_children():
		if child.has_method("has_participant") and child.has_participant(peer_id):
			return child
	return null


func get_fight_owner_for_peer(peer_id: int) -> int:
	var fight := find_fight_for_peer(peer_id)
	if fight != null and fight.has_method("get_owner_peer_id"):
		return int(fight.get_owner_peer_id())
	return 0


func _find_nearest_fight_for_requester(requester_id: int) -> Node:
	var players: Node = get_tree().get_root().get_node_or_null("Overworld/Players")
	var requester: Node2D = null
	if players != null:
		requester = players.get_node_or_null(str(requester_id)) as Node2D
	var best: Node = null
	var best_d := INF
	for child in fight_layer.get_children():
		if not child.has_method("add_participant"):
			continue
		if child.has_method("has_participant") and child.has_participant(requester_id):
			continue
		var anchor := Vector2.ZERO
		var encounter: Dictionary = {}
		if child.has_method("get_encounter"):
			encounter = child.get_encounter()
		if encounter.has("world_position"):
			anchor = encounter["world_position"] as Vector2
		elif players != null and child.has_method("get_owner_peer_id"):
			var owner_node: Node2D = players.get_node_or_null(str(child.get_owner_peer_id())) as Node2D
			if owner_node != null:
				anchor = owner_node.global_position
		var d := 0.0
		if requester != null:
			d = requester.global_position.distance_squared_to(anchor)
		if d < best_d:
			best_d = d
			best = child
	return best


func _process_join_request(
	requester_id: int, target_peer_id: int = 0, side: String = "player"
) -> void:
	if is_peer_in_fight(requester_id):
		return
	if is_peer_on_fight_cooldown(requester_id):
		return
	# v1: only ally / player side is accepted.
	if side != "player" and side != "ally":
		push_warning("FightManager: Join-Seite '%s' noch nicht unterstützt." % side)
		return
	var fight: Node = null
	if target_peer_id != 0:
		fight = find_fight_for_peer(target_peer_id)
	if fight == null:
		fight = _find_nearest_fight_for_requester(requester_id)
	if fight == null:
		return
	if fight.has_method("has_participant") and fight.has_participant(requester_id):
		return
	var owner_id := 0
	if fight.has_method("get_owner_peer_id"):
		owner_id = fight.get_owner_peer_id()
	var participants_list: Array = []
	if fight.get("participants") != null:
		for p in fight.participants:
			participants_list.append(int(p))
	if not participants_list.has(requester_id):
		participants_list.append(requester_id)
	var encounter: Dictionary = {}
	if fight.has_method("get_encounter"):
		encounter = fight.get_encounter()
	var turn_state: Dictionary = {}
	if fight.has_method("get_turn_state"):
		turn_state = fight.get_turn_state()
	rpc_sync_join_fight.rpc(owner_id, requester_id, participants_list, encounter, turn_state)


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
	var encounter: Dictionary = {}
	if fight_node.has_method("get_encounter"):
		encounter = fight_node.get_encounter()
	var npc_path := str(encounter.get("npc_path", ""))
	var participants_snapshot: Array = []
	if fight_node.get("participants") != null:
		for p in fight_node.participants:
			participants_snapshot.append(p)
	for p in participants_snapshot:
		rpc_end_fight_for_peer.rpc(p)
	fight_node.queue_free()
	rpc_destroy_fight_instance.rpc(owner_peer_id)
	if npc_path != "":
		rpc_unlock_overworld_npc.rpc(npc_path)
	if fight_layer.get_child_count() == 0:
		is_fight_active = false


func _apply_encounter_to_fight(fight_instance: Node, encounter: Dictionary) -> void:
	if encounter.is_empty():
		return
	if fight_instance.has_method("set_encounter"):
		fight_instance.set_encounter(encounter)


@rpc("any_peer", "call_local", "reliable")
func rpc_start_fight(owner_peer_id: int, encounter: Dictionary = {}) -> void:
	if fight_scene == null:
		push_error("FightManager: fight_scene ist nicht gesetzt.")
		return
	if fight_layer.get_node_or_null("Fight_%d" % owner_peer_id) != null:
		return
	var fight_instance: Node2D = fight_scene.instantiate()
	fight_instance.name = "Fight_%d" % owner_peer_id
	if fight_instance.has_method("set_owner_peer_id"):
		fight_instance.set_owner_peer_id(owner_peer_id)
	_apply_encounter_to_fight(fight_instance, encounter)
	fight_layer.add_child(fight_instance)
	if fight_instance.has_signal("fight_ready_to_remove"):
		fight_instance.fight_ready_to_remove.connect(_on_fight_ready_to_remove)
	is_fight_active = true
	peers_in_fight[owner_peer_id] = true


@rpc("any_peer", "reliable")
func rpc_create_existing_fight(
	owner_peer_id: int,
	participants_list: Array,
	encounter: Dictionary = {},
	turn_state: Dictionary = {}
) -> void:
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
	_apply_encounter_to_fight(fight_instance, encounter)
	fight_layer.add_child(fight_instance)
	if fight_instance.has_signal("fight_ready_to_remove"):
		fight_instance.fight_ready_to_remove.connect(_on_fight_ready_to_remove)
	if not turn_state.is_empty() and fight_instance.has_method("apply_turn_state"):
		fight_instance.apply_turn_state(turn_state)
	is_fight_active = true
	for p in participants_list:
		peers_in_fight[int(p)] = true
	var npc_path := str(encounter.get("npc_path", ""))
	if npc_path != "":
		_lock_npc_by_path(npc_path)


@rpc("any_peer", "reliable")
func rpc_request_start_fight() -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	start_fight_for_peer(requester_id)


@rpc("any_peer", "reliable")
func rpc_request_start_fight_encounter(peer_id: int, encounter: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	# Client may only request a fight for themselves.
	if sender_id != peer_id:
		return
	start_fight_with_encounter(peer_id, encounter)


@rpc("any_peer", "reliable")
func rpc_request_join_fight(
	target_peer_id: int = 0, side: String = "player"
) -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	_process_join_request(requester_id, target_peer_id, side)


## Local/host helper used by UI and debug overlay.
func request_join_fight_as_local(target_peer_id: int = 0, side: String = "player") -> void:
	if multiplayer.is_server():
		_process_join_request(multiplayer.get_unique_id(), target_peer_id, side)
	else:
		rpc_id(1, "rpc_request_join_fight", target_peer_id, side)


@rpc("any_peer", "call_local", "reliable")
func rpc_sync_join_fight(
	owner_peer_id: int,
	peer_id: int,
	participants_list: Array = [],
	encounter: Dictionary = {},
	turn_state: Dictionary = {}
) -> void:
	peers_in_fight[peer_id] = true
	var fight_node: Node = fight_layer.get_node_or_null("Fight_%d" % owner_peer_id)
	if fight_node == null:
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
		_apply_encounter_to_fight(fight_instance, encounter)
		fight_layer.add_child(fight_instance)
		if fight_instance.has_signal("fight_ready_to_remove"):
			fight_instance.fight_ready_to_remove.connect(_on_fight_ready_to_remove)
		if not turn_state.is_empty() and fight_instance.has_method("apply_turn_state"):
			fight_instance.apply_turn_state(turn_state)
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
	_arm_fight_leave_cooldown(peer_id)
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


@rpc("any_peer", "call_local", "reliable")
func rpc_lock_overworld_npc(npc_path: String) -> void:
	_lock_npc_by_path(npc_path)


@rpc("any_peer", "call_local", "reliable")
func rpc_unlock_overworld_npc(npc_path: String) -> void:
	_unlock_npc_by_path(npc_path)


@rpc("any_peer", "call_local", "reliable")
func rpc_remove_overworld_npc(npc_path: String) -> void:
	var npc := get_tree().root.get_node_or_null(npc_path)
	if npc == null:
		return
	# Do not exit_fight_lock (that resumes patrol) — stop quietly, then free.
	if npc.has_method("prepare_for_removal"):
		npc.prepare_for_removal()
	npc.queue_free()


func _lock_npc_by_path(npc_path: String) -> void:
	var npc := get_tree().root.get_node_or_null(npc_path)
	if npc != null and npc.has_method("enter_fight_lock"):
		npc.enter_fight_lock()


func _unlock_npc_by_path(npc_path: String) -> void:
	var npc := get_tree().root.get_node_or_null(npc_path)
	if npc != null and npc.has_method("exit_fight_lock"):
		npc.exit_fight_lock()
