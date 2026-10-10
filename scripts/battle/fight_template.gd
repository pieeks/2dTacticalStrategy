extends Node2D
## Einzelner Kampf: Participants, Units, Turn-Controller, HUD.

signal fight_ready_to_remove(owner_peer_id: int)

const BattleTurnControllerScript = preload("res://scripts/battle/battle_turn_controller.gd")
const BattleHudScene = preload("res://scenes/battle/battle_hud.tscn")
const CharacterAppearanceScene = preload("res://scenes/characters/character_appearance.tscn")

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
const _PARK_OFFSET := Vector2(80000, 80000)
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
	@warning_ignore("integer_division")
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
	visible = am_in
	position = _home_position if am_in else _home_position + _PARK_OFFSET
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
		var my_char: Node = player_container.get_node_or_null(str(peer_id))
		if my_char != null and my_char.has_method("activate_camera"):
			my_char.activate_camera()
	# Mid-fight join: queue until next full round (do not insert into current order).
	if multiplayer.is_server() and _turns_started and turn_controller and not was_already:
		turn_controller.queue_unit_for_next_round("player_%d" % peer_id)
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
		var char_node: Node2D = player_container.get_node_or_null(str(p)) as Node2D
		if char_node == null:
			continue
		var unit: BattleUnit = previous.get("player_%d" % p) as BattleUnit
		if unit == null:
			unit = BattleUnit.make_player(p)
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
		_spawn_battle_character(p)


func _appearance_dict_usable(data: Dictionary) -> bool:
	return not data.is_empty() and str(data.get("race_path", "")) != ""


func _get_player_appearance_for_peer(peer_id: int) -> Dictionary:
	# 1) Host-synced snapshot in encounter (works on all peers, no Overworld timing).
	var synced: Variant = encounter.get("player_appearances", {})
	if synced is Dictionary:
		var from_enc: Variant = (synced as Dictionary).get(str(peer_id), {})
		if from_enc is Dictionary and _appearance_dict_usable(from_enc):
			return (from_enc as Dictionary).duplicate(true)
	# 2) Live Overworld player node.
	return _get_overworld_player_appearance(peer_id)


func _get_overworld_player_appearance(peer_id: int) -> Dictionary:
	var overworld: Node = get_parent().get_parent() if get_parent() else null
	if overworld == null:
		return {}
	var players: Node = overworld.get_node_or_null("Players")
	if players == null:
		return {}
	var player: Node = players.get_node_or_null(str(peer_id))
	if player == null:
		# Local authority fallback when node not found yet.
		if peer_id == multiplayer.get_unique_id():
			var local_app: Variant = PlayerPartyState.player_data.get("appearance", {})
			if local_app is Dictionary and _appearance_dict_usable(local_app):
				return (local_app as Dictionary).duplicate(true)
		return {}
	var sync_node = player.get("sync")
	if sync_node != null and sync_node.get("appearance") is Dictionary:
		var from_sync: Dictionary = sync_node.appearance
		if _appearance_dict_usable(from_sync):
			return from_sync.duplicate(true)
	var save_node = player.get("save")
	if save_node != null and not save_node.appearance_data.is_empty():
		if _appearance_dict_usable(save_node.appearance_data):
			return save_node.appearance_data.duplicate(true)
	var app = player.get("appearance")
	if app != null and app.has_method("get_full_data"):
		var from_visual: Dictionary = app.get_full_data()
		if _appearance_dict_usable(from_visual):
			return from_visual
	if peer_id == multiplayer.get_unique_id():
		var party_app: Variant = PlayerPartyState.player_data.get("appearance", {})
		if party_app is Dictionary and _appearance_dict_usable(party_app):
			return (party_app as Dictionary).duplicate(true)
	return {}


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
	if character.has_method("apply_appearance"):
		character.apply_appearance(_get_player_appearance_for_peer(peer_id))
	if character.has_method("setup_for_fight") and grid_manager is GridManager:
		character.setup_for_fight(grid_manager as GridManager)
	if character.has_method("set_turn_controller") and turn_controller:
		character.set_turn_controller(turn_controller)
	if character.has_method("activate_camera") and peer_id == multiplayer.get_unique_id():
		character.activate_camera()


func _spawn_battle_enemies() -> void:
	if not is_instance_valid(npc_container):
		return
	# Default 1; Debug-Start ohne Encounter spawnt einen Platzhalter mit Scene-Default-Look.
	var group_size: int = maxi(1, int(encounter.get("group_size", 1)))
	var appearance_data: Dictionary = {}
	if encounter.has("appearance") and encounter["appearance"] is Dictionary:
		appearance_data = (encounter["appearance"] as Dictionary).duplicate(true)
	var spacing: float = 40.0
	var grid_w := 9
	var grid_h := 3
	if grid_manager is GridManager:
		spacing = (grid_manager as GridManager).spacing
		grid_w = maxi((grid_manager as GridManager).width - 1, 0)
		@warning_ignore("integer_division")
		grid_h = maxi((grid_manager as GridManager).height / 2, 0)
	for i in range(group_size):
		var enemy_name := "Enemy_%d" % i
		if npc_container.get_node_or_null(enemy_name) != null:
			continue
		var enemy := Node2D.new()
		enemy.name = enemy_name
		enemy.set_meta("npc_type", str(encounter.get("npc_type", "")))
		enemy.set_meta("npc_name", str(encounter.get("npc_name", "Enemy")))
		enemy.set_meta("stats", encounter.get("stats", {}))
		var app: Node2D = CharacterAppearanceScene.instantiate()
		enemy.add_child(app)
		if not appearance_data.is_empty() and app.has_method("apply_full_data"):
			app.call_deferred("apply_full_data", appearance_data)
		if app.has_method("play"):
			app.call_deferred("play", "idle_front")
		var label := Label.new()
		label.text = str(encounter.get("npc_name", "Enemy"))
		label.position = Vector2(-24, -36)
		label.add_theme_font_size_override("font_size", 10)
		enemy.add_child(label)
		npc_container.add_child(enemy)
		# Offset along columns so group_size > 1 does not stack.
		var cell_x := grid_w - (i % 3)
		@warning_ignore("integer_division")
		var cell_y := grid_h + (i / 3)
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
		var npc_path := str(encounter.get("npc_path", ""))
		if npc_path != "":
			var fm := _get_fight_manager()
			if fm != null and fm.has_method("rpc_remove_overworld_npc"):
				fm.rpc_remove_overworld_npc.rpc(npc_path)
	request_end_fight()


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


@rpc("any_peer", "call_local", "reliable")
func rpc_remove_battle_character(peer_id: int) -> void:
	participants.erase(peer_id)
	var char_node: Node = player_container.get_node_or_null(str(peer_id))
	if char_node != null:
		if char_node.has_method("stop_network"):
			char_node.stop_network()
		char_node.queue_free()
	if turn_controller:
		turn_controller.units.erase("player_%d" % peer_id)
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
