extends Node2D
## Einzelner Kampf: Teilnehmer, Battle-Characters, Sichtbarkeit nur für Teilnehmer.
## Battle-Chars werden lokal auf jedem Peer gespawnt (Fight-Instanz ist bereits call_local).

signal fight_ready_to_remove(owner_peer_id: int)

@onready var grid_manager: Node2D = $GridManager
@onready var player_container: Node = $PlayerContainer
@onready var npc_container: Node = $NpcContainer

@export var battle_character_scene: PackedScene
@export var owner_peer_id: int = 0

var participants: Array[int] = []
var _is_ending: bool = false

const _FREE_DELAY_SECONDS: float = 0.15


func _ready() -> void:
	var my_id := multiplayer.get_unique_id()
	if owner_peer_id != 0 and not participants.has(owner_peer_id):
		participants.append(owner_peer_id)
	if owner_peer_id == 0:
		owner_peer_id = my_id
		if not participants.has(owner_peer_id):
			participants.append(owner_peer_id)

	visible = participants.has(my_id)
	_sync_player_container_visibility()

	# Fight exists on every peer via call_local — spawn chars locally on all.
	for p in participants:
		_spawn_battle_character(p)


func _sync_player_container_visibility() -> void:
	for child in player_container.get_children():
		child.visible = visible


func set_owner_peer_id(peer_id: int) -> void:
	owner_peer_id = peer_id


func get_owner_peer_id() -> int:
	return owner_peer_id


func set_participants(participants_list: Array) -> void:
	participants.clear()
	for p in participants_list:
		participants.append(int(p))


func has_participant(peer_id: int) -> bool:
	return participants.has(peer_id)


func add_participant(peer_id: int) -> void:
	if not participants.has(peer_id):
		participants.append(peer_id)
	if peer_id == multiplayer.get_unique_id():
		visible = true
		_sync_player_container_visibility()
	# call_local join — every peer spawns the new battle char locally
	call_deferred("_spawn_battle_character", peer_id)


func _spawn_battle_character(peer_id: int) -> void:
	if battle_character_scene == null:
		push_error("FightTemplate: battle_character_scene ist nicht gesetzt.")
		return
	if not is_instance_valid(player_container):
		return
	if player_container.get_node_or_null(str(peer_id)) != null:
		return
	var character: CharacterBody2D = battle_character_scene.instantiate()
	character.name = str(peer_id)
	character.set_multiplayer_authority(peer_id)
	@warning_ignore("integer_division")
	var row := peer_id / 5
	var offset := Vector2(float(peer_id % 5) * 24.0, float(row % 5) * 24.0)
	character.position = grid_manager.position + offset
	player_container.add_child(character)
	_sync_player_container_visibility()
	if character.has_method("activate_camera") and peer_id == multiplayer.get_unique_id():
		character.activate_camera()


func request_end_fight() -> void:
	if not multiplayer.is_server():
		return
	if _is_ending:
		return
	_is_ending = true
	rpc_notify_fight_ending.rpc()
	for child in npc_container.get_children():
		get_tree().create_timer(_FREE_DELAY_SECONDS).timeout.connect(_delayed_free_node.bind(child))
	for child in player_container.get_children():
		get_tree().create_timer(_FREE_DELAY_SECONDS).timeout.connect(_delayed_free_node.bind(child))
	var timer: SceneTreeTimer = get_tree().create_timer(_FREE_DELAY_SECONDS + 0.05)
	timer.timeout.connect(_check_containers_empty_and_emit_ready)


func _delayed_free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


func _check_containers_empty_and_emit_ready() -> void:
	if not multiplayer.is_server():
		return
	if player_container.get_child_count() > 0 or npc_container.get_child_count() > 0:
		var timer: SceneTreeTimer = get_tree().create_timer(0.05)
		timer.timeout.connect(_check_containers_empty_and_emit_ready)
		return
	fight_ready_to_remove.emit(owner_peer_id)


func request_leave_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not has_participant(peer_id):
		return
	participants.erase(peer_id)
	rpc_remove_battle_character.rpc(peer_id)
	_notify_fight_manager_peer_left(peer_id)
	if participants.is_empty() and npc_container.get_child_count() == 0:
		request_end_fight()


@rpc("any_peer", "call_local", "reliable")
func rpc_remove_battle_character(peer_id: int) -> void:
	var char_node: Node = player_container.get_node_or_null(str(peer_id))
	if char_node:
		char_node.queue_free()


func _notify_fight_manager_peer_left(peer_id: int) -> void:
	var overworld: Node = get_parent().get_parent()
	var fm: Node = overworld.get_node_or_null("FightManager")
	if fm != null and fm.has_method("notify_peer_left_fight"):
		fm.notify_peer_left_fight(peer_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_notify_fight_ending() -> void:
	visible = false
	_sync_player_container_visibility()
