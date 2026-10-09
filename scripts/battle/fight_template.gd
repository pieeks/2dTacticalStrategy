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

	# Only toggle Fight root — never mask child.visible (breaks remotes / sync paths).
	visible = participants.has(my_id)
	_ensure_participant_characters()


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
	# Ensure every participant char exists locally (incl. host when client joins).
	_ensure_participant_characters()
	if peer_id == multiplayer.get_unique_id():
		var my_char: Node = player_container.get_node_or_null(str(peer_id))
		if my_char != null and my_char.has_method("activate_camera"):
			my_char.activate_camera()


func _ensure_participant_characters() -> void:
	for p in participants:
		_spawn_battle_character(p)


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
	# Spread peers onto neighboring hex cells (deterministic from participant index).
	var spacing: float = 40.0
	if grid_manager is GridManager:
		spacing = (grid_manager as GridManager).spacing
	var idx := participants.find(peer_id)
	if idx < 0:
		idx = participants.size()
	@warning_ignore("integer_division")
	var cell := Vector2i(idx % 5, idx / 5)
	var local_cell := Vector2(float(cell.x) * spacing, float(cell.y) * spacing * 0.75)
	if cell.y % 2 == 1:
		local_cell.x += spacing / 2.0
	var world_pos: Vector2 = grid_manager.to_global(local_cell) if grid_manager else local_cell
	player_container.add_child(character)
	character.global_position = world_pos
	if character.has_method("setup_for_fight") and grid_manager is GridManager:
		character.setup_for_fight(grid_manager as GridManager)
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
