extends Node2D
## Einzelner Kampf: Participants, Units, Turn-Controller, HUD.

signal fight_ready_to_remove(owner_peer_id: int)

const BattleTurnControllerScript = preload("res://scripts/battle/battle_turn_controller.gd")
const BattleHudScene = preload("res://scenes/battle/battle_hud.tscn")
const AppearanceDataScript := preload("res://scripts/characters/appearance_data.gd")
const BattleEnemyScene := preload("res://scenes/battle/battle_enemy.tscn")

@onready var grid_manager: Node2D = $GridManager
@onready var player_container: Node = $PlayerContainer
@onready var npc_container: Node = $NpcContainer

@export var battle_character_scene: PackedScene
@export var owner_peer_id: int = 0

var participants: Array[int] = []
var encounter: Dictionary = {}
var _is_ending: bool = false
var _home_position: Vector2 = Vector2.ZERO
var turn_controller: Node = null
var battle_hud: CanvasLayer = null
var _turns_started: bool = false
var _turn_start_retries: int = 0

const _FREE_DELAY_SECONDS: float = 0.15
const _FIGHT_SLOT_SPACING: float = 5000.0
const _MAX_TURN_START_RETRIES: int = 20


func _ready() -> void:
	var my_id := multiplayer.get_unique_id()
	if owner_peer_id != 0 and not participants.has(owner_peer_id):
		participants.append(owner_peer_id)
	if owner_peer_id == 0:
		owner_peer_id = my_id
		if not participants.has(owner_peer_id):
			participants.append(owner_peer_id)

	_home_position = _compute_home_position(owner_peer_id)
	_setup_turn_controller()
	_apply_local_view()
	_ensure_participant_characters()
	_spawn_battle_enemies()
	_rebuild_units_from_nodes()
	if participants.has(my_id):
		_ensure_battle_hud()
	call_deferred("_try_start_turns")


func _compute_home_position(owner_id: int) -> Vector2:
	var slot := absi(owner_id) % 64
	return Vector2(float(slot % 8) * _FIGHT_SLOT_SPACING, float(slot / 8) * _FIGHT_SLOT_SPACING)


func _setup_turn_controller() -> void:
	turn_controller = BattleTurnControllerScript.new()
	turn_controller.name = "BattleTurnController"
	add_child(turn_controller)
	turn_controller.set_multiplayer_authority(1)
	if grid_manager is GridManager:
		turn_controller.setup(self, grid_manager as GridManager)
	if turn_controller.has_signal("battle_ended"):
		turn_controller.battle_ended.connect(_on_battle_ended)


func _ensure_battle_hud() -> void:
	if battle_hud != null:
		return
	battle_hud = BattleHudScene.instantiate()
	# Parent under Overworld so CanvasLayer stacks above PlayerUi / DebugOverlay.
	var overworld: Node = get_parent().get_parent() if get_parent() else null
	if overworld != null:
		overworld.add_child(battle_hud)
	else:
		add_child(battle_hud)
	if battle_hud.has_method("bind_controller"):
		battle_hud.bind_controller(turn_controller)
	if battle_hud.has_method("bind_fight"):
		battle_hud.bind_fight(self)
	_suppress_overworld_ui(true)


func _apply_local_view() -> void:
	var am_in := participants.has(multiplayer.get_unique_id()) and not _is_ending
	# Always keep the fight on its home slot so Host/Client share world positions.
	# Parking non-viewers with a huge offset broke client Force-Fights: Host simulated
	# at park coords and synced those absolutes → Client units teleported off-camera.
	visible = am_in
	position = _home_position
	if battle_hud:
		battle_hud.visible = am_in
	if am_in:
		_suppress_overworld_ui(true)


func _suppress_overworld_ui(hide_ui: bool) -> void:
	var overworld: Node = get_parent().get_parent() if get_parent() else null
	if overworld == null:
		return
	var pui: CanvasLayer = overworld.get_node_or_null("PlayerUi") as CanvasLayer
	if pui != null and participants.has(multiplayer.get_unique_id()):
		pui.visible = not hide_ui


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


func get_turn_state() -> Dictionary:
	if turn_controller != null and turn_controller.has_method("export_state_for_late_join"):
		return turn_controller.export_state_for_late_join()
	return {}


func apply_turn_state(data: Dictionary) -> void:
	if turn_controller != null and turn_controller.has_method("apply_late_join_state"):
		turn_controller.apply_late_join_state(data)
	if not data.is_empty():
		_turns_started = true


func add_participant(peer_id: int) -> void:
	var was_already := participants.has(peer_id)
	if not was_already:
		participants.append(peer_id)
	_apply_local_view()
	_ensure_participant_characters()
	_spawn_battle_enemies()
	_rebuild_units_from_nodes()
	if peer_id == multiplayer.get_unique_id():
		_ensure_battle_hud()
		_activate_local_leader_camera()
	# Mid-fight join: queue all party units until next full round.
	if multiplayer.is_server() and _turns_started and turn_controller and not was_already:
		for unit_id in _party_unit_ids_for_peer(peer_id):
			turn_controller.queue_unit_for_next_round(unit_id)
		turn_controller._broadcast_state()
	elif multiplayer.is_server() and _turns_started and turn_controller:
		turn_controller.build_turn_order()
		turn_controller._broadcast_state()


func _try_start_turns() -> void:
	if _turns_started or _is_ending:
		return
	if not multiplayer.is_server():
		return
	if turn_controller == null:
		return
	_rebuild_units_from_nodes()
	if turn_controller.units.is_empty():
		_turn_start_retries += 1
		if _turn_start_retries <= _MAX_TURN_START_RETRIES:
			# Characters/enemy may not be ready on the first deferred frame.
			get_tree().create_timer(0.05, true, false, true).timeout.connect(
				_try_start_turns, CONNECT_ONE_SHOT
			)
		else:
			push_warning("FightTemplate: Turn-Start fehlgeschlagen — keine Units.")
		return
	_turns_started = true
	print(
		"FightTemplate: starte Turns mit ",
		turn_controller.units.size(),
		" Units, participants=",
		participants
	)
	turn_controller.start_battle()


func _rebuild_units_from_nodes() -> void:
	if turn_controller == null:
		return
	var previous: Dictionary = turn_controller.units.duplicate()
	# Preserve phase/order while refreshing node links (clear_units must not reset turn).
	turn_controller.clear_units()
	for p in participants:
		var roster: Array = _get_party_roster_for_peer(p)
		for member_i in range(roster.size()):
			var entry: Dictionary = roster[member_i] as Dictionary
			var member_id := str(entry.get("member_id", str(p)))
			var unit_id := BattleUnit.party_unit_id(p, member_id)
			var char_node: Node2D = player_container.get_node_or_null(unit_id) as Node2D
			if char_node == null:
				continue
			var unit: BattleUnit = previous.get(unit_id) as BattleUnit
			if unit == null:
				var stats: Dictionary = {}
				if entry.get("stats") is Dictionary:
					stats = entry["stats"] as Dictionary
				else:
					stats = _get_player_stats_for_peer(p)
				unit = BattleUnit.make_party_member(
					p, member_id, stats, str(entry.get("name", "Player %d" % p))
				)
			unit.node = char_node
			turn_controller.register_unit(unit)
			if char_node.has_method("set_turn_controller"):
				char_node.set_turn_controller(turn_controller)
	for child in npc_container.get_children():
		if not str(child.name).begins_with("Enemy_"):
			continue
		var suffix := str(child.name).get_slice("_", 1)
		if not suffix.is_valid_int():
			continue
		var enemy_idx := int(suffix)
		var enemy_node: Node2D = child as Node2D
		var enemy: BattleUnit = previous.get("enemy_%d" % enemy_idx) as BattleUnit
		if enemy == null:
			enemy = BattleUnit.make_enemy(enemy_idx, encounter)
		enemy.node = enemy_node
		turn_controller.register_unit(enemy)
		_refresh_enemy_label(enemy)


func _refresh_enemy_label(enemy: BattleUnit) -> void:
	if enemy == null or enemy.node == null:
		return
	for child in enemy.node.get_children():
		if child is Label:
			(child as Label).text = "%s (%d)" % [enemy.display_name, enemy.hp]


func _ensure_participant_characters() -> void:
	for p in participants:
		var roster: Array = _get_party_roster_for_peer(p)
		for member_i in range(roster.size()):
			_spawn_party_member(p, roster[member_i] as Dictionary, member_i)
	if participants.has(multiplayer.get_unique_id()):
		_activate_local_leader_camera()


## Party roster for peer from encounter snapshot, or single-leader fallback.
func _get_party_roster_for_peer(peer_id: int) -> Array:
	var map: Variant = encounter.get("party_rosters", {})
	if map is Dictionary:
		var raw: Variant = (map as Dictionary).get(str(peer_id), [])
		if raw is Array and not (raw as Array).is_empty():
			var cleaned: Array = []
			for entry in raw as Array:
				if entry is Dictionary:
					cleaned.append(entry)
			if not cleaned.is_empty():
				return cleaned
	# Legacy fallback: one avatar from player_appearances / player_stats.
	return [{
		"member_id": str(peer_id),
		"role": "leader",
		"name": "Player %d" % peer_id,
		"appearance": _get_player_appearance_for_peer(peer_id),
		"stats": _get_player_stats_for_peer(peer_id),
	}]


func _party_unit_ids_for_peer(peer_id: int) -> Array[String]:
	var ids: Array[String] = []
	for entry in _get_party_roster_for_peer(peer_id):
		if entry is Dictionary:
			ids.append(BattleUnit.party_unit_id(peer_id, str(entry.get("member_id", peer_id))))
	return ids


func _activate_local_leader_camera() -> void:
	var my_id := multiplayer.get_unique_id()
	var roster: Array = _get_party_roster_for_peer(my_id)
	var leader_id := ""
	for entry in roster:
		if entry is Dictionary and str(entry.get("role", "")) == "leader":
			leader_id = str(entry.get("member_id", ""))
			break
	if leader_id.is_empty() and not roster.is_empty() and roster[0] is Dictionary:
		leader_id = str((roster[0] as Dictionary).get("member_id", my_id))
	if leader_id.is_empty():
		leader_id = str(my_id)
	var node_name := BattleUnit.party_unit_id(my_id, leader_id)
	var my_char: Node = player_container.get_node_or_null(node_name)
	if my_char != null and my_char.has_method("activate_camera"):
		my_char.activate_camera()


func _get_player_stats_for_peer(peer_id: int) -> Dictionary:
	var synced: Variant = encounter.get("player_stats", {})
	if synced is Dictionary:
		var from_enc: Variant = (synced as Dictionary).get(str(peer_id), {})
		if from_enc is Dictionary and not (from_enc as Dictionary).is_empty():
			return (from_enc as Dictionary).duplicate(true)
	if peer_id == multiplayer.get_unique_id():
		var members: Array = PlayerPartyState.party_data.get("members", [])
		if not members.is_empty() and members[0] is Dictionary:
			var member_stats: Variant = (members[0] as Dictionary).get("stats", {})
			if member_stats is Dictionary and not (member_stats as Dictionary).is_empty():
				return (member_stats as Dictionary).duplicate(true)
	return BattleUnit.DEFAULT_PLAYER_STATS.duplicate(true)


func _get_player_appearance_for_peer(peer_id: int) -> Dictionary:
	# 1) Host-synced snapshot in encounter (works on all peers, no Overworld timing).
	var synced: Variant = encounter.get("player_appearances", {})
	if synced is Dictionary:
		var from_enc: Variant = (synced as Dictionary).get(str(peer_id), {})
		if from_enc is Dictionary and AppearanceDataScript.is_usable(from_enc as Dictionary):
			return (from_enc as Dictionary).duplicate(true)
	# 2) Live Overworld player node / local party.
	return _get_overworld_player_appearance(peer_id)


func _get_overworld_player_appearance(peer_id: int) -> Dictionary:
	var overworld: Node = get_parent().get_parent() if get_parent() else null
	var players: Node = overworld.get_node_or_null("Players") if overworld != null else null
	return AppearanceDataScript.collect_for_peer(peer_id, players)


## Spawn one party member node named player_<peer>_<member_id>.
func _spawn_party_member(peer_id: int, entry: Dictionary, member_index: int) -> void:
	if battle_character_scene == null:
		push_error("FightTemplate: battle_character_scene ist nicht gesetzt.")
		return
	if not is_instance_valid(player_container):
		return
	var member_id := str(entry.get("member_id", peer_id))
	var unit_id := BattleUnit.party_unit_id(peer_id, member_id)
	if player_container.get_node_or_null(unit_id) != null:
		return
	var character: CharacterBody2D = battle_character_scene.instantiate()
	character.name = unit_id
	character.set_multiplayer_authority(peer_id)
	var is_leader := str(entry.get("role", "")) == "leader" or member_index == 0
	if is_leader:
		character.set_meta("is_party_leader", true)
	var spacing: float = 40.0
	if grid_manager is GridManager:
		spacing = (grid_manager as GridManager).spacing
	var peer_idx := participants.find(peer_id)
	if peer_idx < 0:
		peer_idx = participants.size()
	# Staffel Members desselben Peers nebeneinander; Peers in Zeilen.
	var cell_x := (peer_idx % 3) * 2 + (member_index % 2)
	var cell_y: int = int(peer_idx / 3) + int(member_index / 2)
	var local_cell := Vector2(float(cell_x) * spacing, float(cell_y) * spacing * 0.75)
	if cell_y % 2 == 1:
		local_cell.x += spacing / 2.0
	var world_pos: Vector2 = grid_manager.to_global(local_cell) if grid_manager else local_cell
	player_container.add_child(character)
	character.global_position = world_pos
	var appearance_data: Dictionary = {}
	if entry.get("appearance") is Dictionary and AppearanceDataScript.is_usable(entry["appearance"]):
		appearance_data = AppearanceDataScript.normalize(entry["appearance"])
	if not AppearanceDataScript.is_usable(appearance_data):
		appearance_data = AppearanceDataScript.normalize(_get_player_appearance_for_peer(peer_id))
	if not AppearanceDataScript.is_usable(appearance_data):
		push_warning(
			"FightTemplate: no usable appearance for %s — battle scene defaults will show"
			% unit_id
		)
	if character.has_method("apply_appearance"):
		character.apply_appearance(appearance_data)
	if character.has_method("setup_for_fight") and grid_manager is GridManager:
		character.setup_for_fight(grid_manager as GridManager)
	if character.has_method("set_turn_controller") and turn_controller:
		character.set_turn_controller(turn_controller)


func _spawn_battle_enemies() -> void:
	if not is_instance_valid(npc_container):
		return
	# Prefer host enemy_roster snapshot; fall back to group_size × encounter appearance.
	var roster: Array = []
	if encounter.get("enemy_roster") is Array:
		roster = encounter["enemy_roster"] as Array
	var spawn_count: int = roster.size() if not roster.is_empty() else maxi(1, int(encounter.get("group_size", 1)))
	var fallback_appearance: Dictionary = {}
	if encounter.has("appearance") and encounter["appearance"] is Dictionary:
		fallback_appearance = (encounter["appearance"] as Dictionary).duplicate(true)
	var spacing: float = 40.0
	var grid_w := 9
	var grid_h := 3
	if grid_manager is GridManager:
		spacing = (grid_manager as GridManager).spacing
		grid_w = maxi((grid_manager as GridManager).width - 1, 0)
		grid_h = maxi(int((grid_manager as GridManager).height / 2), 0)
	for i in range(spawn_count):
		var enemy_name := "Enemy_%d" % i
		if npc_container.get_node_or_null(enemy_name) != null:
			continue
		var entry: Dictionary = {}
		if i < roster.size() and roster[i] is Dictionary:
			entry = roster[i] as Dictionary
		var npc_type := str(entry.get("npc_type", encounter.get("npc_type", "")))
		var display_name := str(entry.get("display_name", encounter.get("npc_name", "Enemy")))
		var stats: Dictionary = {}
		if entry.get("stats") is Dictionary:
			stats = (entry["stats"] as Dictionary).duplicate(true)
		elif encounter.get("stats") is Dictionary:
			stats = (encounter["stats"] as Dictionary).duplicate(true)
		var appearance_data: Dictionary = {}
		if entry.get("appearance") is Dictionary and not (entry["appearance"] as Dictionary).is_empty():
			appearance_data = (entry["appearance"] as Dictionary).duplicate(true)
		else:
			appearance_data = fallback_appearance.duplicate(true)
		var enemy: Node2D = BattleEnemyScene.instantiate()
		enemy.name = enemy_name
		npc_container.add_child(enemy)
		if enemy.has_method("setup"):
			enemy.setup(npc_type, display_name, stats, appearance_data)
		# Offset along columns so multiple enemies do not stack.
		var cell_x := grid_w - (i % 3)
		var cell_y: int = grid_h + int(i / 3)
		var local_cell := Vector2(float(cell_x) * spacing, float(cell_y) * spacing * 0.75)
		if cell_y % 2 == 1:
			local_cell.x += spacing / 2.0
		if grid_manager:
			enemy.global_position = grid_manager.to_global(local_cell)
			if grid_manager is GridManager:
				enemy.global_position = (grid_manager as GridManager).get_snap_global_position(
					enemy.global_position
				)
		else:
			enemy.position = local_cell


func _on_battle_ended(result: String) -> void:
	if not multiplayer.is_server():
		return
	print("FightTemplate: battle ended with ", result)
	if result == "victory":
		_credit_kills_from_roster()
		var npc_path := str(encounter.get("npc_path", ""))
		if npc_path != "":
			var fm := _get_fight_manager()
			if fm != null and fm.has_method("rpc_remove_overworld_npc"):
				fm.rpc_remove_overworld_npc.rpc(npc_path)
	request_end_fight()


## Aggregate enemy_roster npc_types and credit each once with count.
func _credit_kills_from_roster() -> void:
	var counts: Dictionary = {}
	var roster: Variant = encounter.get("enemy_roster", [])
	if roster is Array:
		for entry in roster as Array:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var npc_type := str((entry as Dictionary).get("npc_type", "")).strip_edges()
			if npc_type.is_empty():
				continue
			counts[npc_type] = int(counts.get(npc_type, 0)) + 1
	if counts.is_empty():
		var fallback := str(encounter.get("npc_type", "")).strip_edges()
		if fallback != "":
			counts[fallback] = 1
	for npc_type in counts.keys():
		rpc_quest_kill_credit.rpc(str(npc_type), int(counts[npc_type]))


## Credit kill quest progress to fight participants (local apply).
@rpc("authority", "call_local", "reliable")
func rpc_quest_kill_credit(npc_type: String, amount: int = 1) -> void:
	if npc_type.is_empty() or amount <= 0:
		return
	var my_id := multiplayer.get_unique_id()
	if not participants.has(my_id):
		return
	var qm := get_tree().root.get_node_or_null("QuestManager")
	if qm == null:
		return
	qm.report_progress({
		"type": "kill",
		"target": npc_type,
		"amount": amount,
	})


func _get_fight_manager() -> Node:
	var overworld: Node = get_parent().get_parent()
	return overworld.get_node_or_null("FightManager")


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


func _accept_host_broadcast() -> bool:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	var sender := multiplayer.get_remote_sender_id()
	if sender == 1:
		return true
	if sender == 0:
		return multiplayer.is_server()
	return false


@rpc("any_peer", "call_local", "reliable")
func rpc_remove_battle_character(peer_id: int) -> void:
	if not _accept_host_broadcast():
		return
	participants.erase(peer_id)
	var prefix := "player_%d_" % peer_id
	var to_free: Array[Node] = []
	for child in player_container.get_children():
		if str(child.name).begins_with(prefix) or str(child.name) == str(peer_id):
			to_free.append(child)
	for char_node in to_free:
		if char_node.has_method("stop_network"):
			char_node.stop_network()
		char_node.queue_free()
	if turn_controller:
		var erase_ids: Array[String] = []
		for unit_id in turn_controller.units.keys():
			var uid := str(unit_id)
			if uid.begins_with(prefix) or uid == "player_%d" % peer_id:
				erase_ids.append(uid)
		for uid2 in erase_ids:
			turn_controller.units.erase(uid2)
		if multiplayer.is_server() and int(turn_controller.phase) != 3:
			turn_controller.build_turn_order()
			if turn_controller.turn_order.is_empty():
				request_end_fight()
			else:
				turn_controller._broadcast_state()
	_apply_local_view()


func _notify_fight_manager_peer_left(peer_id: int) -> void:
	var fm := _get_fight_manager()
	if fm != null and fm.has_method("notify_peer_left_fight"):
		fm.notify_peer_left_fight(peer_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_notify_fight_ending() -> void:
	if not _accept_host_broadcast():
		return
	_is_ending = true
	_stop_all_battle_networks()
	if battle_hud != null and is_instance_valid(battle_hud):
		battle_hud.queue_free()
		battle_hud = null
	_suppress_overworld_ui(false)
	_apply_local_view()


func _stop_all_battle_networks() -> void:
	if is_instance_valid(player_container):
		for child in player_container.get_children():
			if child.has_method("stop_network"):
				child.stop_network()
