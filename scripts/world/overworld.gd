extends Node2D

## LevelManager / Overworld
##
## Handles world/level loading, player spawning, and fight lifecycle hooks.

@onready var level_container: Node2D = $LevelContainer
@onready var multiplayer_spawner: MultiplayerSpawn = $MultiplayerSpawner
@onready var players: Node = $Players
@onready var fight_manager: Node = $FightManager

const DEFAULT_LEVEL = preload("res://scenes/world/levels/biom_1.tscn")


func _ready() -> void:
	if NetworkManagerTest.has_signal("peer_disconnected"):
		NetworkManagerTest.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		NetworkManagerTest.late_joiner_detected.connect(_on_later_joiner_detected)
		# Sync fights after the joiner finished loading Overworld (not at connect time).
		NetworkManagerTest.peer_ready.connect(_on_peer_ready_for_fight_sync)

	if fight_manager.has_signal("fight_ended_for_peer"):
		fight_manager.fight_ended_for_peer.connect(_on_fight_ended_for_peer)

	_load_level(DEFAULT_LEVEL)

	if not multiplayer.is_server():
		await get_tree().process_frame
		NetworkManagerTest.notify_server_level_ready()


func _on_peer_ready_for_fight_sync(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if peer_id == multiplayer.get_unique_id():
		return
	if fight_manager and fight_manager.has_method("sync_active_fights_to_peer"):
		fight_manager.sync_active_fights_to_peer(peer_id)
	# Snapshot all world players (incl. host in fight) to the late joiner.
	_push_all_world_player_state_to_peer(peer_id)


func _push_all_world_player_state_to_peer(peer_id: int) -> void:
	for child in players.get_children():
		if child.has_method("push_state_to_peer") and child.is_multiplayer_authority():
			child.push_state_to_peer(peer_id)


func is_peer_in_fight(peer_id: int) -> bool:
	if fight_manager and fight_manager.has_method("is_peer_in_fight"):
		return fight_manager.is_peer_in_fight(peer_id)
	return false


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server() and is_peer_in_fight(peer_id):
		fight_manager.end_fight_for_peer(peer_id)
	if multiplayer_spawner:
		multiplayer_spawner.remove_player(peer_id)


func _on_later_joiner_detected(new_peer_id: int) -> void:
	print("Overworld (Host): Synchronisiere Level-Zustand für neuen Spieler ", new_peer_id)
	await get_tree().create_timer(0.5).timeout

	if level_container.get_child_count() == 0:
		print("Overworld (Host): Kein Level zum Synchronisieren gefunden.")
		return
	var current_level = level_container.get_child(0)

	var npc_container = current_level.get_node_or_null("NPCContainer")
	if not npc_container:
		print("Overworld (Host): Kein NPCContainer im Level gefunden.")
		return

	for npc in npc_container.get_children():
		if npc is NPCCharacter and npc.is_awake:
			var current_anim = npc._last_anim
			if not current_anim.is_empty():
				print("Overworld (Host): Sende Init-Anim '", current_anim, "' für ", npc.name, " an Client ", new_peer_id)
				npc.play_animation_rpc.rpc_id(new_peer_id, current_anim)


func _on_fight_ended_for_peer(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	var my_player := _find_local_world_player()
	if my_player == null:
		return
	my_player.visible = true
	if my_player.has_method("restore_from_fight"):
		my_player.restore_from_fight()


func _find_local_world_player() -> Node:
	var my_id := multiplayer.get_unique_id()
	for child in players.get_children():
		if child.get_multiplayer_authority() == my_id:
			return child
	return null


func _on_level_ready() -> void:
	pass


func _load_level(level_scene: PackedScene) -> void:
	for child in level_container.get_children():
		child.queue_free()

	var level: Node2D = level_scene.instantiate()

	level.level_ready.connect(_on_level_ready)
	level_container.add_child(level)
	level.initialize_level_for_players(players)

	print("Level loaded: ", level_scene)
