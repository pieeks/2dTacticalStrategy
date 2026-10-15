class_name AggroController
extends Node

@onready var npc = get_parent()
@onready var aggro_area: AggroArea = npc.get_node("AggroArea2D")
@onready var force_fight_area: ForceFightArea = npc.get_node("ForceFightArea2D")

var target: Node2D = null
var exit_timer: Timer
var is_chasing: bool = false
## Peers already inside Aggro after fight unlock — ignore until they leave the area.
var _aggro_suppressed_peers: Dictionary = {}


func _ready() -> void:
	exit_timer = Timer.new()
	exit_timer.one_shot = true
	exit_timer.wait_time = 2.0
	exit_timer.timeout.connect(_on_exit_timer_timeout)
	add_child(exit_timer)

	aggro_area.body_entered.connect(_on_aggro_enter)
	aggro_area.body_exited.connect(_on_aggro_exit)
	force_fight_area.force_fight.connect(_on_force_fight)


## Chase AI belongs on the NPC authority (host); Force-Fight may still fire on clients.
func _owns_chase_ai() -> bool:
	return NetworkManagerTest.is_authority(npc)


func _on_aggro_enter(body: Node2D) -> void:
	if not _owns_chase_ai():
		return
	if not body.is_in_group("Players"):
		return
	if npc.get("_fight_locked") == true:
		return
	var peer_id := body.get_multiplayer_authority()
	if _aggro_suppressed_peers.get(peer_id, false):
		return

	# Already chasing a valid target — keep it (multiplayer: do not steal mid-chase).
	if is_chasing and is_instance_valid(target):
		return

	_begin_chase(body)


func _on_aggro_exit(body: Node2D) -> void:
	if body.is_in_group("Players"):
		_aggro_suppressed_peers.erase(body.get_multiplayer_authority())
	if not _owns_chase_ai():
		return
	if body != target:
		return

	var next := _pick_best_target()
	if next != null:
		_begin_chase(next)
		return

	exit_timer.start()


func _on_exit_timer_timeout() -> void:
	if not _owns_chase_ai():
		return
	if npc.get("_fight_locked") == true:
		return

	var next := _pick_best_target()
	if next != null:
		_begin_chase(next)
		return

	target = null
	is_chasing = false

	if npc.has_method("resume_patrol"):
		npc.resume_patrol()

	if npc.state_machine:
		if npc.patrol_points.size() > 0 or is_instance_valid(npc.path_follower):
			npc.state_machine.transition_to("WalkNPC")
		else:
			npc.state_machine.transition_to("IdleNPC")


func _on_force_fight(body: Node2D) -> void:
	if npc.get("_fight_locked") == true:
		return
	if is_instance_valid(body):
		target = body
	if not is_instance_valid(target):
		return
	if npc.has_method("start_battle_with"):
		npc.start_battle_with(target)


## Start or retarget chase toward `body`.
func _begin_chase(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	if exit_timer:
		exit_timer.stop()
	target = body
	is_chasing = true

	if npc.has_method("stop_patrol"):
		npc.stop_patrol()

	if npc.state_machine:
		npc.state_machine.transition_to("FollowTargetNPC", {"target": target})


## Closest non-suppressed player still overlapping the aggro area.
func _pick_best_target() -> Node2D:
	if aggro_area == null or not aggro_area.monitoring:
		return null
	var best: Node2D = null
	var best_dist_sq := INF
	for body in aggro_area.get_overlapping_bodies():
		if not (body is Node2D) or not body.is_in_group("Players"):
			continue
		var peer_id: int = body.get_multiplayer_authority()
		if _aggro_suppressed_peers.get(peer_id, false):
			continue
		var dist_sq: float = npc.global_position.distance_squared_to(body.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = body
	return best


## FollowTarget lost its target — retarget or end chase.
func retarget_or_end_chase() -> void:
	if not _owns_chase_ai():
		return
	if npc.get("_fight_locked") == true:
		return
	var next := _pick_best_target()
	if next != null:
		_begin_chase(next)
		return
	target = null
	is_chasing = false
	if npc.has_method("resume_patrol"):
		npc.resume_patrol()
	if npc.state_machine:
		if npc.patrol_points.size() > 0 or is_instance_valid(npc.path_follower):
			npc.state_machine.transition_to("WalkNPC")
		else:
			npc.state_machine.transition_to("IdleNPC")


## Stop chase without resuming patrol (fight lock).
func stop_chase() -> void:
	if exit_timer:
		exit_timer.stop()
	target = null
	is_chasing = false


## After unlock: peers already inside Aggro must leave before chase starts again.
func suppress_currently_overlapping() -> void:
	_aggro_suppressed_peers.clear()
	if aggro_area == null or not aggro_area.monitoring:
		return
	for body in aggro_area.get_overlapping_bodies():
		if body is Node2D and body.is_in_group("Players"):
			_aggro_suppressed_peers[body.get_multiplayer_authority()] = true
	stop_chase()
	if not _owns_chase_ai():
		return
	if npc.state_machine and npc.get("_fight_locked") != true:
		if npc.patrol_points.size() > 0 or is_instance_valid(npc.path_follower):
			npc.state_machine.transition_to("WalkNPC")
		else:
			npc.state_machine.transition_to("IdleNPC")
