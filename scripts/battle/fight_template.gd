extends Node2D
## Einzelner Kampf: Teilnehmer, Battle-Characters, Encounter-Gegner, Sichtbarkeit nur für Teilnehmer.
## Parallel fights are spatially isolated so non-participants never share a camera view.

signal fight_ready_to_remove(owner_peer_id: int)

@onready var grid_manager: Node2D = $GridManager
@onready var player_container: Node = $PlayerContainer
@onready var npc_container: Node = $NpcContainer

@export var battle_character_scene: PackedScene
@export var owner_peer_id: int = 0

var participants: Array[int] = []
var encounter: Dictionary = {}
var _is_ending: bool = false
var _home_position: Vector2 = Vector2.ZERO

const _FREE_DELAY_SECONDS: float = 0.15
## World offset between parallel Fight instances (keeps cameras from overlapping).
const _FIGHT_SLOT_SPACING: float = 5000.0
const _PARK_OFFSET := Vector2(80000, 80000)


func _ready() -> void:
	var my_id := multiplayer.get_unique_id()
	if owner_peer_id != 0 and not participants.has(owner_peer_id):
		participants.append(owner_peer_id)
	if owner_peer_id == 0:
		owner_peer_id = my_id
		if not participants.has(owner_peer_id):
			participants.append(owner_peer_id)

	_home_position = _compute_home_position(owner_peer_id)
	_apply_local_view()
	_ensure_participant_characters()
	_spawn_battle_enemy()


func _compute_home_position(owner_id: int) -> Vector2:
	var slot := absi(owner_id) % 64
	@warning_ignore("integer_division")
	return Vector2(float(slot % 8) * _FIGHT_SLOT_SPACING, float(slot / 8) * _FIGHT_SLOT_SPACING)


## Participants see this fight at its slot; everyone else parks it far off-camera.
func _apply_local_view() -> void:
	var am_in := participants.has(multiplayer.get_unique_id()) and not _is_ending
	visible = am_in
	position = _home_position if am_in else _home_position + _PARK_OFFSET


func set_owner_peer_id(peer_id: int) -> void:
	owner_peer_id = peer_id


func get_owner_peer_id() -> int:
	return owner_peer_id


func set_participants(participants_list: Array) -> void:
	participants.clear()
	for p in participants_list:
		participants.append(int(p))


func set_encounter(encounter_data: Dictionary) -> void:
	encounter = encounter_data.duplicate(true)


func get_encounter() -> Dictionary:
	return encounter


func has_participant(peer_id: int) -> bool:
	return participants.has(peer_id)


func add_participant(peer_id: int) -> void:
	if not participants.has(peer_id):
		participants.append(peer_id)
	_apply_local_view()
	_ensure_participant_characters()
	_spawn_battle_enemy()
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


func _spawn_battle_enemy() -> void:
	if encounter.is_empty():
		return
	if not is_instance_valid(npc_container):
		return
	if npc_container.get_node_or_null("Enemy_0") != null:
		return
	var enemy := Node2D.new()
	enemy.name = "Enemy_0"
	enemy.set_meta("npc_type", str(encounter.get("npc_type", "")))
	enemy.set_meta("npc_name", str(encounter.get("npc_name", "Enemy")))
	enemy.set_meta("stats", encounter.get("stats", {}))
	var visual := Polygon2D.new()
	visual.color = Color(0.85, 0.25, 0.3, 1.0)
	visual.polygon = PackedVector2Array([-10, -10, 10, -10, 10, 10, -10, 10])
	enemy.add_child(visual)
	var label := Label.new()
	label.text = str(encounter.get("npc_name", "Enemy"))
	label.position = Vector2(-20, -24)
	label.add_theme_font_size_override("font_size", 10)
	enemy.add_child(label)
	npc_container.add_child(enemy)
	var spacing: float = 40.0
	var grid_w := 9
	var grid_h := 3
	if grid_manager is GridManager:
		spacing = (grid_manager as GridManager).spacing
		grid_w = maxi((grid_manager as GridManager).width - 1, 0)
		@warning_ignore("integer_division")
		grid_h = maxi((grid_manager as GridManager).height / 2, 0)
	var local_cell := Vector2(float(grid_w) * spacing, float(grid_h) * spacing * 0.75)
	if grid_h % 2 == 1:
		local_cell.x += spacing / 2.0
	if grid_manager:
		enemy.global_position = grid_manager.to_global(local_cell)
		if grid_manager is GridManager:
			enemy.global_position = (grid_manager as GridManager).get_snap_global_position(
				enemy.global_position
			)
	else:
		enemy.position = local_cell


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
	if not is_instance_valid(node):
		return
	if node.has_method("stop_network"):
		node.stop_network()
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
	if participants.is_empty():
		request_end_fight()


@rpc("any_peer", "call_local", "reliable")
func rpc_remove_battle_character(peer_id: int) -> void:
	participants.erase(peer_id)
	var char_node: Node = player_container.get_node_or_null(str(peer_id))
	if char_node != null:
		if char_node.has_method("stop_network"):
			char_node.stop_network()
		char_node.queue_free()
	# Leaving peer should no longer see this fight.
	_apply_local_view()


func _notify_fight_manager_peer_left(peer_id: int) -> void:
	var overworld: Node = get_parent().get_parent()
	var fm: Node = overworld.get_node_or_null("FightManager")
	if fm != null and fm.has_method("notify_peer_left_fight"):
		fm.notify_peer_left_fight(peer_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_notify_fight_ending() -> void:
	_is_ending = true
	_stop_all_battle_networks()
	_apply_local_view()


func _stop_all_battle_networks() -> void:
	if is_instance_valid(player_container):
		for child in player_container.get_children():
			if child.has_method("stop_network"):
				child.stop_network()
