class_name NPCCharacter
extends CharacterBody2D

const FacingUtilScript := preload("res://scripts/characters/facing_util.gd")

## Multiplayer & Performance
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
var is_awake: bool = false
var active_player_bubbles: int = 0

## States & Aussehen
@onready var state_machine: NodeStateMachine = $StateMachine
@onready var appearance: CharacterAppearance = $CharacterAppearance
@onready var specification: NpcSpecification = $NPCSpecificationsContainer

## Patrouillen-Daten
@onready var patrol_pause_timer: Timer = $PatrolPauseTimer
var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var patrol_direction: int = 1
var speed: float = 60.0
var pause_time: float = 2.0
var path_follower: PathFollow2D

var is_interacting: bool = false

var _last_anim: String
var facing_direction: Vector2 = Vector2.DOWN

enum PatrolBehavior { LOOP, PING_PONG, RANDOM, FOLLOW_PATH }
var patrol_behavior: PatrolBehavior = PatrolBehavior.LOOP

var _initialization_data: Dictionary
var force_fight_area: Area2D

var npc_data: Dictionary
## True while this NPC is tied to an active Overworld fight (visible, frozen).
var _fight_locked: bool = false
## Peers that must leave ForceFightArea before they can re-trigger (after Leave/Unlock).
var _force_fight_suppressed_peers: Dictionary = {}
var _force_fight_exit_connected: bool = false
## Blocks Force-Fight until overlapping peers are snapshotted after unlock.
var _awaiting_force_fight_rearm: bool = false
var _suppress_snapshot_retries: int = 0


# --- Godot Lebenszyklus-Funktionen ---

func _ready() -> void:
	# Verarbeite die Daten, bevor irgendetwas anderes passiert.
	if _initialization_data:
		_initialize_npc()
	
	# Initial sleep without touching bubble counter (stays at 0).
	_force_sleep()
	state_machine.owner_actor = self
	patrol_pause_timer.timeout.connect(_on_patrol_pause_finished)


func _physics_process(_delta: float):
	if not is_awake:
		return
	if _fight_locked:
		velocity = Vector2.ZERO
		return

	# Der NPC führt einfach die Bewegung aus, die der aktive State in `velocity` geschrieben hat.
	move_and_slide()

	var current_velocity = get_real_velocity()
	if current_velocity.length_squared() > 0.1:
		facing_direction = current_velocity.normalized()

	# Der Host ist für die Animationen zuständig, basierend auf dem aktuellen Zustand und der Bewegung.
	if multiplayer.is_server():
		update_animation()


# --- Initialisierungs-Funktionen ---

func initialize_npc(data: Dictionary) -> void:
	self._initialization_data = data


func set_force_fight_area(force_fight_area_node: Area2D) -> void:
	self.force_fight_area = force_fight_area_node


## Force-Fight entry: open encounter prompt (fight/flee) instead of instant combat.
func start_battle_with(player: Node2D) -> void:
	if _fight_locked or _awaiting_force_fight_rearm:
		return
	if not is_instance_valid(player) or not player.is_in_group("Players"):
		return
	var peer_id := player.get_multiplayer_authority()
	# Spawn-overlap: treat as suppress until the peer leaves the area.
	if player.get("spawn_force_fight_suppressed") == true:
		_force_fight_suppressed_peers[peer_id] = true
		return
	if _force_fight_suppressed_peers.get(peer_id, false):
		return
	var fm := _get_fight_manager()
	if fm == null:
		return
	if fm.has_method("is_peer_in_fight") and fm.is_peer_in_fight(peer_id):
		return
	if fm.has_method("is_peer_on_fight_cooldown") and fm.is_peer_on_fight_cooldown(peer_id):
		return
	# Clients only report their own player; host owns the prompt flow (avoids double UI).
	if not multiplayer.is_server():
		if not player.is_multiplayer_authority():
			return
		var seed_enc := _build_encounter()
		seed_enc["party_roster"] = PlayerPartyState.build_party_roster_snapshot()
		rpc_id(1, "rpc_request_encounter_prompt", peer_id, seed_enc)
		return

	_open_encounter_prompt_for_peer(peer_id, player, {})


## Host: open prompt for peer (optional client seed with party_roster).
func _open_encounter_prompt_for_peer(peer_id: int, player: Node2D, client_seed: Dictionary) -> void:
	if _fight_locked or _awaiting_force_fight_rearm:
		return
	if _force_fight_suppressed_peers.get(peer_id, false):
		return
	_begin_encounter_prompt_pending(peer_id)

	var encounter := EncounterResolver.attach_enemy_roster(_build_encounter())
	if client_seed.get("party_roster") is Array:
		encounter["party_roster"] = (client_seed["party_roster"] as Array).duplicate(true)
	elif peer_id == multiplayer.get_unique_id():
		encounter["party_roster"] = PlayerPartyState.build_party_roster_snapshot()

	if peer_id == multiplayer.get_unique_id():
		if is_instance_valid(player):
			_deliver_encounter_prompt(player, encounter)
		else:
			_deliver_encounter_prompt(_find_player_by_peer(peer_id), encounter)
	else:
		rpc_id(peer_id, "rpc_show_encounter_prompt", encounter)


@rpc("any_peer", "reliable")
func rpc_request_encounter_prompt(peer_id: int, client_seed: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender > 0 and sender != peer_id:
		return
	var player := _find_player_by_peer(peer_id)
	if player == null:
		return
	var fm := _get_fight_manager()
	if fm != null:
		if fm.has_method("is_peer_in_fight") and fm.is_peer_in_fight(peer_id):
			return
		if fm.has_method("is_peer_on_fight_cooldown") and fm.is_peer_on_fight_cooldown(peer_id):
			return
	_open_encounter_prompt_for_peer(peer_id, player, client_seed)


func _find_player_by_peer(peer_id: int) -> Node2D:
	var players := get_tree().get_root().get_node_or_null("Overworld/Players")
	if players == null:
		return null
	for child in players.get_children():
		if child is Node2D and child.get_multiplayer_authority() == peer_id:
			return child as Node2D
	return null


## Soft-lock peer while the encounter prompt is open (no re-trigger / chase).
func _begin_encounter_prompt_pending(peer_id: int) -> void:
	_force_fight_suppressed_peers[peer_id] = true
	_ensure_force_fight_exit_connected()
	stop_patrol()
	var aggro_ctrl: Node = get_node_or_null("AggroController")
	if aggro_ctrl != null and aggro_ctrl.has_method("stop_chase"):
		aggro_ctrl.stop_chase()
	if state_machine and NetworkManagerTest.is_authority(self):
		state_machine.transition_to("IdleNPC")


func _deliver_encounter_prompt(player: Node2D, encounter: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var ui: Node = player.get("player_ui") as Node
	if ui == null:
		var overworld := get_tree().get_root().get_node_or_null("Overworld")
		if overworld:
			ui = overworld.get_node_or_null("PlayerUi")
	if ui != null and ui.has_method("show_encounter_prompt"):
		ui.show_encounter_prompt(encounter, str(get_path()))
	else:
		# Fallback: no UI → start fight immediately.
		_start_fight_from_prompt(encounter)


## Host → target peer: show local encounter prompt for this NPC.
@rpc("any_peer", "reliable")
func rpc_show_encounter_prompt(encounter: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 and sender != 0:
		return
	var local_player := _find_player_by_peer(multiplayer.get_unique_id())
	if local_player == null:
		return
	var enc: Dictionary = encounter.duplicate(true)
	if not enc.has("party_roster"):
		enc["party_roster"] = PlayerPartyState.build_party_roster_snapshot()
	_deliver_encounter_prompt(local_player, enc)


## Called from PlayerUI after Fight or failed Flee.
func confirm_encounter_fight(encounter: Dictionary) -> void:
	_start_fight_from_prompt(encounter)


## Keep peer suppressed after successful flee (cleared on ForceFight exit).
func confirm_encounter_flee_success(peer_id: int) -> void:
	_force_fight_suppressed_peers[peer_id] = true
	_ensure_force_fight_exit_connected()
	if multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		# Host already suppressed in _begin_encounter_prompt_pending; ensure replicas know via path.
		pass
	elif not multiplayer.is_server():
		rpc_id(1, "rpc_confirm_flee_success", peer_id)


@rpc("any_peer", "reliable")
func rpc_confirm_flee_success(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_force_fight_suppressed_peers[peer_id] = true
	_ensure_force_fight_exit_connected()


func _start_fight_from_prompt(encounter: Dictionary) -> void:
	var fm := _get_fight_manager()
	if fm == null:
		return
	var peer_id := multiplayer.get_unique_id()
	var enc: Dictionary = encounter.duplicate(true)
	if not enc.has("party_roster"):
		enc["party_roster"] = PlayerPartyState.build_party_roster_snapshot()
	if multiplayer.is_server():
		if fm.has_method("start_fight_with_encounter"):
			fm.start_fight_with_encounter(peer_id, enc)
		elif fm.has_method("start_fight_for_peer"):
			fm.start_fight_for_peer(peer_id)
	else:
		fm.rpc_id(1, "rpc_request_start_fight_encounter", peer_id, enc)


## After player spawn: if already overlapping, require leave before Force-Fight.
func suppress_force_fight_for_player(player: Node2D) -> void:
	if not is_instance_valid(player) or not player.is_in_group("Players"):
		return
	var force: Area2D = get_node_or_null("ForceFightArea2D") as Area2D
	if force == null and is_instance_valid(force_fight_area):
		force = force_fight_area
	if force == null or not force.monitoring:
		return
	if not force.get_overlapping_bodies().has(player):
		return
	_force_fight_suppressed_peers[player.get_multiplayer_authority()] = true
	_ensure_force_fight_exit_connected()


func _build_encounter() -> Dictionary:
	var enc: Dictionary = {
		"npc_path": str(get_path()),
		"spawn_id": str(get_meta("spawn_id", "")),
		"npc_type": "",
		"npc_name": name,
		"stats": {},
		"world_position": global_position,
		"group_size": 1,
		"appearance": {},
	}
	if is_instance_valid(specification):
		enc["npc_type"] = specification.npc_type
		if specification.npc_name != "":
			enc["npc_name"] = specification.npc_name
		else:
			enc["npc_name"] = str(name)
		enc["stats"] = specification.npc_stats.duplicate(true)
		enc["group_size"] = maxi(1, int(specification.npc_group_size))
		if specification.npc_encounter_id != "":
			enc["encounter_id"] = specification.npc_encounter_id
		if not specification.npc_encounter_units.is_empty():
			enc["units"] = specification.npc_encounter_units.duplicate(true)
	# Prefer Spec-JSON appearance (only defined layers) — not live sprites with hidden defaults.
	if is_instance_valid(specification) and not specification.npc_appearance.is_empty():
		enc["appearance"] = specification.npc_appearance.duplicate(true)
	elif is_instance_valid(appearance) and appearance.has_method("get_full_data"):
		enc["appearance"] = appearance.get_full_data()
	return enc


func _get_fight_manager() -> Node:
	var overworld := get_tree().get_root().get_node_or_null("Overworld")
	if overworld == null:
		return null
	return overworld.get_node_or_null("FightManager")


func is_fight_locked() -> bool:
	return _fight_locked


## Keep NPC visible in Overworld but freeze chase/patrol/areas during a fight.
func enter_fight_lock() -> void:
	if _fight_locked:
		return
	_fight_locked = true
	_force_fight_suppressed_peers.clear()
	velocity = Vector2.ZERO
	visible = true
	if is_instance_valid(appearance):
		appearance.visible = true
	if patrol_pause_timer != null and is_instance_valid(patrol_pause_timer) and patrol_pause_timer.is_inside_tree():
		patrol_pause_timer.stop()
	_ensure_force_fight_exit_connected()
	_set_combat_areas_monitoring(false)
	var aggro_ctrl: Node = get_node_or_null("AggroController")
	if aggro_ctrl != null and aggro_ctrl.has_method("stop_chase"):
		aggro_ctrl.stop_chase()
	if state_machine:
		state_machine.transition_to("IdleNPC")


func exit_fight_lock() -> void:
	if not _fight_locked:
		return
	_fight_locked = false
	_awaiting_force_fight_rearm = true
	_suppress_snapshot_retries = 0
	_ensure_force_fight_exit_connected()
	_set_combat_areas_monitoring(true)
	# After monitoring is back, snapshot who is still overlapping and suppress them.
	call_deferred("_suppress_overlapping_force_fight_peers")
	if not is_awake:
		return
	if not patrol_points.is_empty() or is_instance_valid(path_follower):
		if state_machine:
			state_machine.transition_to("WalkNPC")
	elif state_machine:
		state_machine.transition_to("IdleNPC")


func _ensure_force_fight_exit_connected() -> void:
	if _force_fight_exit_connected:
		return
	var force: Area2D = get_node_or_null("ForceFightArea2D") as Area2D
	if force == null and is_instance_valid(force_fight_area):
		force = force_fight_area
	if force == null:
		return
	if force.has_signal("force_fight_exit") and not force.force_fight_exit.is_connected(_on_force_fight_area_exit):
		force.force_fight_exit.connect(_on_force_fight_area_exit)
	_force_fight_exit_connected = true


func _suppress_overlapping_force_fight_peers() -> void:
	var force: Area2D = get_node_or_null("ForceFightArea2D") as Area2D
	if force == null and is_instance_valid(force_fight_area):
		force = force_fight_area
	var aggro: Area2D = get_node_or_null("AggroArea2D") as Area2D
	if force == null:
		_awaiting_force_fight_rearm = false
		_suppress_aggro_after_unlock()
		return
	# monitoring itself is set_deferred — retry a few frames if not active yet.
	if not force.monitoring or (aggro != null and not aggro.monitoring):
		_suppress_snapshot_retries += 1
		if _suppress_snapshot_retries < 8:
			call_deferred("_suppress_overlapping_force_fight_peers")
			return
		_awaiting_force_fight_rearm = false
		_suppress_aggro_after_unlock()
		return
	_force_fight_suppressed_peers.clear()
	for body in force.get_overlapping_bodies():
		if body is Node2D and body.is_in_group("Players"):
			_force_fight_suppressed_peers[body.get_multiplayer_authority()] = true
	_awaiting_force_fight_rearm = false
	_suppress_aggro_after_unlock()


func _suppress_aggro_after_unlock() -> void:
	var aggro_ctrl: Node = get_node_or_null("AggroController")
	if aggro_ctrl != null and aggro_ctrl.has_method("suppress_currently_overlapping"):
		aggro_ctrl.suppress_currently_overlapping()


func _on_force_fight_area_exit(body: Node2D) -> void:
	if not is_instance_valid(body) or not body.is_in_group("Players"):
		return
	_force_fight_suppressed_peers.erase(body.get_multiplayer_authority())


func _set_combat_areas_monitoring(enabled: bool) -> void:
	# Must be deferred: lock often runs inside body_entered of ForceFightArea.
	var aggro: Area2D = get_node_or_null("AggroArea2D") as Area2D
	if aggro:
		aggro.set_deferred("monitoring", enabled)
	var force: Area2D = get_node_or_null("ForceFightArea2D") as Area2D
	if force:
		force.set_deferred("monitoring", enabled)
	elif is_instance_valid(force_fight_area):
		force_fight_area.set_deferred("monitoring", enabled)


func _initialize_npc() -> void:
	if _initialization_data.has("initial_position"):
		global_position = _initialization_data["initial_position"]
	if _initialization_data.has("patrol_points"):
		self.patrol_points = _initialization_data["patrol_points"]
	if _initialization_data.has("patrol_behavior"):
		self.patrol_behavior = _initialization_data["patrol_behavior"]
	if _initialization_data.has("spawn_id"):
		set_meta("spawn_id", str(_initialization_data["spawn_id"]))
	if _initialization_data.has("npc_type") and _initialization_data.has("spawn_index"):
		var npc_type = _initialization_data['npc_type']
		var spawn_index = _initialization_data['spawn_index']
		specification.load_npc_enemy_data(npc_type, spawn_index)
		add_to_group("NPCs")

# --- Netzwerk- & Zustands-Funktionen ---

func wake_up():
	active_player_bubbles += 1
	if is_awake: return
	is_awake = true
	set_physics_process(true)
	multiplayer_synchronizer.set_process(true)
	state_machine.set_physics_process(true)
	# Players already standing in ForceFight when this NPC wakes must leave first.
	call_deferred("_suppress_overlapping_force_fight_peers_keep_existing")
	match patrol_behavior:
		PatrolBehavior.LOOP, PatrolBehavior.PING_PONG:
			if not patrol_points.is_empty():
				state_machine.transition_to("WalkNPC")
			else:
				state_machine.transition_to("IdleNPC")
		PatrolBehavior.FOLLOW_PATH:
			if is_instance_valid(path_follower):
				state_machine.transition_to("WalkNPC")
			else:
				state_machine.transition_to("IdleNPC")
		_:
			state_machine.transition_to("IdleNPC")


func _suppress_overlapping_force_fight_peers_keep_existing() -> void:
	var force: Area2D = get_node_or_null("ForceFightArea2D") as Area2D
	if force == null and is_instance_valid(force_fight_area):
		force = force_fight_area
	if force == null or not force.monitoring:
		return
	_ensure_force_fight_exit_connected()
	for body in force.get_overlapping_bodies():
		if body is Node2D and body.is_in_group("Players"):
			_force_fight_suppressed_peers[body.get_multiplayer_authority()] = true


func go_to_sleep():
	active_player_bubbles -= 1
	if active_player_bubbles > 0 or not is_awake:
		return
	_force_sleep()


## Puts the NPC to sleep without changing active_player_bubbles.
## Authority stops AI + outbound sync; puppets keep the synchronizer receiving.
func _force_sleep() -> void:
	is_awake = false
	state_machine.transition_to("IdleNPC")
	set_physics_process(false)
	state_machine.set_physics_process(false)
	if multiplayer_synchronizer == null:
		return
	if NetworkManagerTest.is_authority(self):
		multiplayer_synchronizer.set_process(false)
	else:
		multiplayer_synchronizer.set_process(true)


# --- Patrouillen-Werkzeuge für States ---

## Stop patrol pause timer while chasing / interrupted (AggroController).
func stop_patrol() -> void:
	if patrol_pause_timer != null and is_instance_valid(patrol_pause_timer) and patrol_pause_timer.is_inside_tree():
		patrol_pause_timer.stop()


## Clear patrol pause before AggroController resumes WalkNPC.
func resume_patrol() -> void:
	stop_patrol()


func start_patrol_pause():
	# Nur der Host soll den Pausen-Timer starten.
	if not is_multiplayer_authority():
		return
	if not is_inside_tree() or _fight_locked or is_interacting:
		return
	if patrol_pause_timer == null or not is_instance_valid(patrol_pause_timer):
		return
	if not patrol_pause_timer.is_inside_tree():
		return
	patrol_pause_timer.start(pause_time)


func _on_patrol_pause_finished():
	if not is_inside_tree() or _fight_locked or is_interacting:
		return
	if state_machine == null or not is_instance_valid(state_machine):
		return
	if state_machine.current_node_state_name == "FollowTargetNPC":
		return
	update_next_patrol_index()
	state_machine.transition_to("WalkNPC")


## Stop AI/patrol before queue_free (victory remove) — do not resume Walk.
func prepare_for_removal() -> void:
	_fight_locked = true
	if patrol_pause_timer != null and is_instance_valid(patrol_pause_timer):
		if patrol_pause_timer.is_inside_tree():
			patrol_pause_timer.stop()
	set_physics_process(false)
	if state_machine:
		state_machine.set_physics_process(false)
		state_machine.transition_to("IdleNPC")
	if multiplayer_synchronizer and NetworkManagerTest.is_authority(self):
		multiplayer_synchronizer.set_process(false)


func update_next_patrol_index():
	match patrol_behavior:
		PatrolBehavior.LOOP:
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		PatrolBehavior.PING_PONG:
			if current_patrol_index >= patrol_points.size() - 1 and patrol_direction == 1:
				patrol_direction = -1
			elif current_patrol_index <= 0 and patrol_direction == -1:
				patrol_direction = 1
			current_patrol_index += patrol_direction
		PatrolBehavior.RANDOM:
			var new_index = current_patrol_index
			while new_index == current_patrol_index:
				new_index = randi() % patrol_points.size()
			current_patrol_index = new_index

# --- Animations-Logik & RPCs ---

func update_animation():
	var anim_prefix = "idle"
	var current_state = state_machine.current_node_state_name.to_lower()
	
	# Bestimme den Animations-Typ basierend auf dem State und der Bewegung
	if velocity.length_squared() > 0.1 and (current_state.contains("walk") or current_state.contains("follow")):
		anim_prefix = "walk"
	
	# Sende den Befehl zum Abspielen der Animation
	set_play_animation(anim_prefix + "_" + _dir_name(facing_direction))


func set_play_animation(anim_name: String) -> void:
	if anim_name != _last_anim:
		play_animation_rpc.rpc(anim_name)


# --- RPC ---

@rpc("any_peer", "call_local", "reliable")
func play_animation_rpc(anim: String) -> void:
	if anim == _last_anim and is_instance_valid(appearance) and appearance.is_playing_current():
		return
	_last_anim = anim
	if is_instance_valid(appearance):
		appearance.play(anim)


@rpc("any_peer", "call_local", "reliable")
func request_interaction(player_name: String):
	if not multiplayer.is_server():
		return
	# Fight-locked NPCs are joined via FightJoinMenu (client-local), not Talk/Leave.
	if _fight_locked:
		return
	
	var player_node = get_tree().get_root().get_node_or_null("Overworld/Players/" + player_name)
	
	if not is_instance_valid(player_node):
		printerr("Host: Konnte Spieler mit ID nicht finden: ", player_name)
		return 
	
	var interaction_range: float = 60.0 
	var dist_sq: float = player_node.global_position.distance_squared_to(global_position)
	
	if dist_sq <= interaction_range * interaction_range:
		is_interacting = true
		stop_patrol()
		state_machine.transition_to('IdleNPC')
		var peer_id_to_reply_to = player_node.get_multiplayer_authority()
		player_node.sync.interaction_approved.rpc_id(peer_id_to_reply_to, self.npc_data, self.get_path())


@rpc("any_peer", "call_local", "reliable")
func end_interaction():
	if not multiplayer.is_server():
		return

	if not is_interacting:
		return

	is_interacting = false

	if active_player_bubbles <= 0:
		_force_sleep()
	elif not patrol_points.is_empty() or is_instance_valid(path_follower):
		state_machine.transition_to("WalkNPC")
	else:
		state_machine.transition_to("IdleNPC")


# --- Hilfsfunktionen ---

func facing_dir() -> Vector2:
	return facing_direction


func _dir_name(v: Vector2) -> String:
	return FacingUtilScript.dir_name(v)
