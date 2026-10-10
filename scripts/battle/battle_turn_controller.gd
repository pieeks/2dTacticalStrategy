extends Node
## Host-authoritative turn order: Move / Attack / Wait. Clients request; host validates.

signal turn_state_changed
signal battle_ended(result: String) ## "victory" | "defeat"

enum Phase { WAITING, ACTIVE, RESOLVING, ENDED }

var fight: Node2D
var grid_manager: GridManager

var units: Dictionary = {} ## unit_id -> BattleUnit
var turn_order: Array[String] = []
var active_index: int = 0
var phase: int = Phase.WAITING
var attack_mode: bool = false

const _ENEMY_AI_DELAY := 0.35
const _ENEMY_AI_WATCHDOG := 2.0

var _ai_watchdog_token: int = 0


func setup(fight_node: Node2D, grid: GridManager) -> void:
	fight = fight_node
	grid_manager = grid
	process_mode = Node.PROCESS_MODE_ALWAYS


func clear_units() -> void:
	## Only clears the unit map. Does not reset turn phase (rebuild mid-fight safe).
	units.clear()


func reset_battle_state() -> void:
	units.clear()
	turn_order.clear()
	active_index = 0
	phase = Phase.WAITING
	attack_mode = false


func register_unit(unit: BattleUnit) -> void:
	units[unit.unit_id] = unit


func get_unit(unit_id: String) -> BattleUnit:
	return units.get(unit_id) as BattleUnit


func get_active_unit() -> BattleUnit:
	if turn_order.is_empty() or active_index < 0 or active_index >= turn_order.size():
		return null
	return get_unit(turn_order[active_index])


func is_local_players_turn() -> bool:
	var u := get_active_unit()
	if u == null or phase != Phase.ACTIVE:
		return false
	return u.is_player() and u.owner_peer_id == multiplayer.get_unique_id()


func build_turn_order() -> void:
	var entries: Array = []
	for unit_id in units.keys():
		var u: BattleUnit = units[unit_id]
		if not u.is_alive():
			continue
		entries.append(u)
	entries.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		if a.is_player() != b.is_player():
			return a.is_player()
		return a.unit_id < b.unit_id
	)
	turn_order.clear()
	for u in entries:
		turn_order.append(u.unit_id)


func start_battle() -> void:
	if not multiplayer.is_server():
		return
	build_turn_order()
	if turn_order.is_empty():
		push_warning("BattleTurnController.start_battle: turn_order leer, units=", units.keys())
		return
	active_index = 0
	print("BattleTurnController: Order=", turn_order, " first=", turn_order[0])
	_begin_active_turn()


func _begin_active_turn() -> void:
	phase = Phase.ACTIVE
	attack_mode = false
	# Ensure index points at a living unit.
	if get_active_unit() == null or not get_active_unit().is_alive():
		build_turn_order()
		active_index = 0
		if turn_order.is_empty():
			phase = Phase.ENDED
			_broadcast_state()
			turn_state_changed.emit()
			battle_ended.emit("victory")
			return
	var u := get_active_unit()
	if u:
		u.reset_turn_flags()
	_broadcast_state()
	turn_state_changed.emit()
	# Defer highlights one frame so unit nodes/cameras are ready.
	call_deferred("_refresh_local_highlights")
	if u != null and u.is_enemy() and multiplayer.is_server():
		_schedule_enemy_ai(u.unit_id)


func _schedule_enemy_ai(expected_unit_id: String) -> void:
	_ai_watchdog_token += 1
	var token := _ai_watchdog_token
	get_tree().create_timer(_ENEMY_AI_DELAY, true, false, true).timeout.connect(
		_on_enemy_ai_timer.bind(token), CONNECT_ONE_SHOT
	)
	# If AI stalls (pause/timer/path), force the turn forward.
	get_tree().create_timer(_ENEMY_AI_WATCHDOG, true, false, true).timeout.connect(
		_on_enemy_ai_watchdog.bind(token, expected_unit_id), CONNECT_ONE_SHOT
	)


func _on_enemy_ai_timer(token: int) -> void:
	if token != _ai_watchdog_token:
		return
	_run_enemy_ai()


func _on_enemy_ai_watchdog(token: int, expected_unit_id: String) -> void:
	if token != _ai_watchdog_token:
		return
	if phase != Phase.ACTIVE:
		return
	var active := get_active_unit()
	if active == null or active.unit_id != expected_unit_id or not active.is_enemy():
		return
	push_warning("BattleTurnController: Enemy-AI Watchdog — force advance")
	_ai_watchdog_token += 1
	_advance_turn()


func _advance_turn() -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.RESOLVING
	var result := _check_battle_end()
	if result != "":
		phase = Phase.ENDED
		_broadcast_state()
		turn_state_changed.emit()
		battle_ended.emit(result)
		return
	# Skip dead units
	var guard := 0
	while guard < turn_order.size() + 2:
		active_index = (active_index + 1) % maxi(turn_order.size(), 1)
		var next_u := get_active_unit()
		if next_u != null and next_u.is_alive():
			break
		guard += 1
		# Rebuild if all dead filtered
		if guard == turn_order.size():
			build_turn_order()
			active_index = 0
			if turn_order.is_empty():
				phase = Phase.ENDED
				_broadcast_state()
				battle_ended.emit("victory")
				return
	_begin_active_turn()


func _check_battle_end() -> String:
	var players_alive := false
	var enemies_alive := false
	var had_enemy := false
	for unit_id in units.keys():
		var u: BattleUnit = units[unit_id]
		if u.is_enemy():
			had_enemy = true
		if not u.is_alive():
			continue
		if u.is_player():
			players_alive = true
		else:
			enemies_alive = true
	if had_enemy and not enemies_alive and players_alive:
		return "victory"
	if had_enemy and not players_alive:
		return "defeat"
	return ""


func get_blocked_point_ids(except_unit_id: String = "") -> Array:
	var blocked: Array = []
	if grid_manager == null:
		return blocked
	for unit_id in units.keys():
		if unit_id == except_unit_id:
			continue
		var u: BattleUnit = units[unit_id]
		if u == null or not u.is_alive() or u.node == null:
			continue
		blocked.append(grid_manager.get_point_id_at_world(u.node.global_position))
	return blocked


func get_reachable_for_active() -> PackedVector2Array:
	var u := get_active_unit()
	if u == null or u.node == null or grid_manager == null or u.has_moved:
		return PackedVector2Array()
	return grid_manager.get_reachable_positions(
		u.node.global_position, u.move_range, get_blocked_point_ids(u.unit_id)
	)


func get_attack_target_positions() -> PackedVector2Array:
	var u := get_active_unit()
	if u == null or u.node == null or grid_manager == null:
		return PackedVector2Array()
	var result := PackedVector2Array()
	for unit_id in units.keys():
		var other: BattleUnit = units[unit_id]
		if other == null or not other.is_alive() or other.node == null:
			continue
		if other.side == u.side:
			continue
		var steps := grid_manager.get_path_step_count(u.node.global_position, other.node.global_position)
		if steps > 0 and steps <= u.attack_range:
			result.append(other.node.global_position)
	return result


func _refresh_local_highlights() -> void:
	if grid_manager == null:
		return
	grid_manager.clear_action_highlights()
	grid_manager.clear_preview_path()
	if not is_local_players_turn():
		return
	if attack_mode:
		grid_manager.set_attack_highlights(get_attack_target_positions())
	else:
		grid_manager.set_move_highlights(get_reachable_for_active())


func set_attack_mode(enabled: bool) -> void:
	if not is_local_players_turn():
		return
	attack_mode = enabled
	_refresh_local_highlights()
	turn_state_changed.emit()


func request_move_to(target_world: Vector2) -> void:
	var u := get_active_unit()
	if u == null or not is_local_players_turn() or u.has_moved or attack_mode:
		return
	if multiplayer.is_server():
		_host_try_move(u.unit_id, target_world, multiplayer.get_unique_id())
	else:
		rpc_id(1, "rpc_request_move", u.unit_id, target_world)


func request_attack_unit(target_unit_id: String) -> void:
	var u := get_active_unit()
	if u == null or not is_local_players_turn():
		return
	if multiplayer.is_server():
		_host_try_attack(u.unit_id, target_unit_id, multiplayer.get_unique_id())
	else:
		rpc_id(1, "rpc_request_attack", u.unit_id, target_unit_id)


func request_wait() -> void:
	var u := get_active_unit()
	if u == null or not is_local_players_turn():
		return
	if multiplayer.is_server():
		_host_try_wait(u.unit_id, multiplayer.get_unique_id())
	else:
		rpc_id(1, "rpc_request_wait", u.unit_id)


@rpc("any_peer", "reliable")
func rpc_request_move(unit_id: String, target_world: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var req := get_unit(unit_id)
	if req == null or req.is_enemy():
		return
	_host_try_move(unit_id, target_world, multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func rpc_request_attack(unit_id: String, target_unit_id: String) -> void:
	if not multiplayer.is_server():
		return
	var req := get_unit(unit_id)
	if req == null or req.is_enemy():
		return
	_host_try_attack(unit_id, target_unit_id, multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func rpc_request_wait(unit_id: String) -> void:
	if not multiplayer.is_server():
		return
	var req := get_unit(unit_id)
	if req == null or req.is_enemy():
		return
	_host_try_wait(unit_id, multiplayer.get_remote_sender_id())


func _host_try_move(unit_id: String, target_world: Vector2, sender_id: int) -> void:
	if phase != Phase.ACTIVE:
		return
	var u := get_unit(unit_id)
	var active := get_active_unit()
	if u == null or active == null or u.unit_id != active.unit_id:
		return
	if u.is_player() and u.owner_peer_id != sender_id:
		return
	if u.has_moved or u.node == null or grid_manager == null:
		return
	var snap_world := grid_manager.get_snap_global_position(target_world)
	var target_id := grid_manager.get_point_id_at_world(snap_world)
	var reachable := grid_manager.get_reachable_positions(
		u.node.global_position, u.move_range, get_blocked_point_ids(u.unit_id)
	)
	var ok := false
	for pos in reachable:
		if grid_manager.get_point_id_at_world(pos) == target_id:
			ok = true
			break
	if not ok:
		return
	u.has_moved = true
	rpc_apply_unit_position.rpc(unit_id, snap_world)
	_broadcast_state()
	turn_state_changed.emit()
	_refresh_local_highlights()


func _host_try_attack(unit_id: String, target_unit_id: String, sender_id: int) -> void:
	if phase != Phase.ACTIVE:
		return
	var u := get_unit(unit_id)
	var target := get_unit(target_unit_id)
	var active := get_active_unit()
	if u == null or target == null or active == null or u.unit_id != active.unit_id:
		return
	if u.is_player() and u.owner_peer_id != sender_id:
		return
	if not target.is_alive() or u.node == null or target.node == null or grid_manager == null:
		return
	if u.side == target.side:
		return
	var steps := grid_manager.get_path_step_count(u.node.global_position, target.node.global_position)
	if steps <= 0 or steps > u.attack_range:
		return
	var dmg := randi_range(u.atk_min, u.atk_max)
	target.hp = maxi(target.hp - dmg, 0)
	rpc_apply_unit_hp.rpc(target_unit_id, target.hp)
	_broadcast_state()
	turn_state_changed.emit()
	# Attack ends the turn.
	_advance_turn()


func _host_try_wait(unit_id: String, sender_id: int) -> void:
	if phase != Phase.ACTIVE:
		return
	var u := get_unit(unit_id)
	var active := get_active_unit()
	if u == null or active == null or u.unit_id != active.unit_id:
		return
	if u.is_player() and u.owner_peer_id != sender_id:
		return
	_advance_turn()


func _run_enemy_ai() -> void:
	if not multiplayer.is_server() or phase != Phase.ACTIVE:
		return
	var u := get_active_unit()
	if u == null or not u.is_enemy() or not u.is_alive():
		_advance_turn()
		return
	if u.node == null or grid_manager == null:
		_advance_turn()
		return
	# Prefer attack if anyone in range.
	var best_target: BattleUnit = null
	var best_steps := 999
	for unit_id in units.keys():
		var other: BattleUnit = units[unit_id]
		if other == null or not other.is_alive() or not other.is_player():
			continue
		if other.node == null:
			continue
		var steps := grid_manager.get_path_step_count(u.node.global_position, other.node.global_position)
		if steps > 0 and steps <= u.attack_range:
			_host_try_attack(u.unit_id, other.unit_id, 1)
			# Attack advances; invalidate watchdog.
			_ai_watchdog_token += 1
			return
		if steps > 0 and steps < best_steps:
			best_steps = steps
			best_target = other
	# Move closer if possible.
	if best_target != null and not u.has_moved:
		var reachable := grid_manager.get_reachable_positions(
			u.node.global_position, u.move_range, get_blocked_point_ids(u.unit_id)
		)
		var best_pos := Vector2.INF
		var best_dist := 999999
		for pos in reachable:
			var d := grid_manager.get_path_step_count(pos, best_target.node.global_position)
			if d < best_dist and d >= 0:
				best_dist = d
				best_pos = pos
		if best_pos != Vector2.INF:
			_host_try_move(u.unit_id, best_pos, 1)
			if u.has_moved:
				get_tree().create_timer(_ENEMY_AI_DELAY, true, false, true).timeout.connect(
					_enemy_ai_after_move.bind(u.unit_id), CONNECT_ONE_SHOT
				)
				return
	# Always end the enemy turn.
	_ai_watchdog_token += 1
	_host_try_wait(u.unit_id, 1)


func _enemy_ai_after_move(enemy_unit_id: String) -> void:
	if not multiplayer.is_server() or phase != Phase.ACTIVE:
		return
	var again := get_active_unit()
	if again == null or again.unit_id != enemy_unit_id:
		_advance_turn()
		return
	if again.node == null or grid_manager == null:
		_advance_turn()
		return
	for unit_id2 in units.keys():
		var other2: BattleUnit = units[unit_id2]
		if other2 == null or not other2.is_alive() or not other2.is_player():
			continue
		if other2.node == null:
			continue
		var steps2 := grid_manager.get_path_step_count(
			again.node.global_position, other2.node.global_position
		)
		if steps2 > 0 and steps2 <= again.attack_range:
			_host_try_attack(again.unit_id, other2.unit_id, 1)
			_ai_watchdog_token += 1
			return
	_ai_watchdog_token += 1
	_host_try_wait(enemy_unit_id, 1)


@rpc("authority", "call_local", "reliable")
func rpc_apply_unit_position(unit_id: String, pos: Vector2) -> void:
	var u := get_unit(unit_id)
	if u == null or u.node == null:
		return
	var target := pos
	if grid_manager:
		target = grid_manager.get_snap_global_position(pos)
	# Animate BattleCharacters along the hex path; enemies snap.
	if u.node.has_method("setup_for_fight") and u.node.get("grid_movement") != null:
		var gm: Node = u.node.grid_movement
		if grid_manager and gm.has_method("play_path"):
			var path := grid_manager.get_action_path(u.node.global_position, target)
			if path.size() > 1:
				gm.play_path(u.node, path)
				return
	u.node.global_position = target


@rpc("authority", "call_local", "reliable")
func rpc_apply_unit_hp(unit_id: String, hp: int) -> void:
	var u := get_unit(unit_id)
	if u == null:
		return
	u.hp = hp
	_update_enemy_label(u)
	turn_state_changed.emit()


func _update_enemy_label(u: BattleUnit) -> void:
	if u == null or u.node == null:
		return
	for child in u.node.get_children():
		if child is Label:
			(child as Label).text = "%s (%d)" % [u.display_name, u.hp]


func _broadcast_state() -> void:
	if not multiplayer.is_server():
		return
	var unit_list: Array = []
	for unit_id in units.keys():
		unit_list.append(units[unit_id].to_sync_dict())
	# Untyped Array — Array[String] can arrive empty via RPC (incl. call_local).
	var order_payload: Array = []
	for id in turn_order:
		order_payload.append(str(id))
	rpc_sync_turn_state.rpc(order_payload, active_index, phase, unit_list, attack_mode)


@rpc("authority", "call_local", "reliable")
func rpc_sync_turn_state(
	order: Array, index: int, phase_val: int, unit_list: Array, atk_mode: bool = false
) -> void:
	turn_order.clear()
	for id in order:
		turn_order.append(str(id))
	active_index = index
	phase = phase_val
	attack_mode = atk_mode
	for data in unit_list:
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var synced := BattleUnit.from_sync_dict(data)
		var existing: BattleUnit = units.get(synced.unit_id) as BattleUnit
		if existing != null:
			existing.hp = synced.hp
			existing.max_hp = synced.max_hp
			existing.has_moved = synced.has_moved
			existing.initiative = synced.initiative
			existing.move_range = synced.move_range
			existing.attack_range = synced.attack_range
			existing.display_name = synced.display_name
			_update_enemy_label(existing)
			BattleUnit.sync_position_from_dict(existing, data)
		else:
			units[synced.unit_id] = synced
	_rebind_unit_nodes()
	for data2 in unit_list:
		if typeof(data2) != TYPE_DICTIONARY:
			continue
		var uid := str(data2.get("unit_id", ""))
		var u2: BattleUnit = units.get(uid) as BattleUnit
		BattleUnit.sync_position_from_dict(u2, data2)
	# Recover if typed-array RPC dropped the order but units + ACTIVE remain.
	if turn_order.is_empty() and not units.is_empty() and phase == Phase.ACTIVE:
		build_turn_order()
		active_index = clampi(index, 0, maxi(turn_order.size() - 1, 0))
	turn_state_changed.emit()
	_refresh_local_highlights()


func _rebind_unit_nodes() -> void:
	if fight == null:
		return
	var players: Node = fight.get_node_or_null("PlayerContainer")
	var npcs: Node = fight.get_node_or_null("NpcContainer")
	for unit_id in units.keys():
		var u: BattleUnit = units[unit_id]
		if u == null:
			continue
		if u.is_player() and players != null:
			u.node = players.get_node_or_null(str(u.owner_peer_id)) as Node2D
			if u.node != null and u.node.has_method("set_turn_controller"):
				u.node.set_turn_controller(self)
		elif u.is_enemy() and npcs != null:
			var suffix := u.unit_id.get_slice("_", 1)
			if suffix == "":
				suffix = "0"
			u.node = npcs.get_node_or_null("Enemy_%s" % suffix) as Node2D
			_update_enemy_label(u)


func export_state_for_late_join() -> Dictionary:
	var unit_list: Array = []
	for unit_id in units.keys():
		unit_list.append(units[unit_id].to_sync_dict())
	return {
		"turn_order": turn_order.duplicate(),
		"active_index": active_index,
		"phase": phase,
		"units": unit_list,
	}


func apply_late_join_state(data: Dictionary) -> void:
	rpc_sync_turn_state(
		data.get("turn_order", []),
		int(data.get("active_index", 0)),
		int(data.get("phase", Phase.WAITING)),
		data.get("units", []),
		false
	)


func update_hover_preview(world_pos: Vector2) -> void:
	if grid_manager == null:
		return
	if not is_local_players_turn() or attack_mode:
		grid_manager.clear_preview_path()
		return
	var u := get_active_unit()
	if u == null or u.node == null or u.has_moved:
		grid_manager.clear_preview_path()
		return
	var reachable := get_reachable_for_active()
	if reachable.is_empty():
		grid_manager.clear_preview_path()
		return
	var snap_world := grid_manager.get_snap_global_position(world_pos)
	var snap_id := grid_manager.get_point_id_at_world(snap_world)
	var ok := false
	for pos in reachable:
		if grid_manager.get_point_id_at_world(pos) == snap_id:
			ok = true
			break
	if not ok:
		grid_manager.clear_preview_path()
		return
	grid_manager.set_preview_path(grid_manager.get_action_path(u.node.global_position, snap_world))


func handle_world_click(world_pos: Vector2) -> bool:
	if not is_local_players_turn():
		return false
	if attack_mode:
		var target_id := _find_unit_at_world(world_pos)
		if target_id != "":
			request_attack_unit(target_id)
			return true
		# Consume click in attack mode so it does not fall through as move.
		return true
	# Move click — reachable cell, or nearest reachable within one hex spacing.
	var reachable := get_reachable_for_active()
	if reachable.is_empty():
		_refresh_local_highlights()
		return false
	var snap_world := grid_manager.get_snap_global_position(world_pos)
	var snap_id := grid_manager.get_point_id_at_world(snap_world)
	for pos in reachable:
		if grid_manager.get_point_id_at_world(pos) == snap_id:
			request_move_to(snap_world)
			return true
	var max_dist: float = grid_manager.spacing * 0.65
	var best_pos := Vector2.INF
	var best_d := max_dist
	for pos in reachable:
		var d: float = pos.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best_pos = pos
	if best_pos != Vector2.INF:
		request_move_to(best_pos)
		return true
	_refresh_local_highlights()
	return false


func _find_unit_at_world(world_pos: Vector2) -> String:
	if grid_manager == null:
		return ""
	var click_id := grid_manager.get_point_id_at_world(world_pos)
	for unit_id in units.keys():
		var u: BattleUnit = units[unit_id]
		if u == null or not u.is_alive() or u.node == null:
			continue
		if grid_manager.get_point_id_at_world(u.node.global_position) == click_id:
			return unit_id
	return ""
