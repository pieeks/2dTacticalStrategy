class_name AggroController
extends Node

@onready var npc = get_parent()
@onready var aggro_area: AggroArea = npc.get_node("AggroArea2D")
@onready var force_fight_area: ForceFightArea = npc.get_node("ForceFightArea2D")

var target: Node2D = null
var exit_timer: Timer
var is_chasing: bool = false


func _ready() -> void:
	# Timer Setup
	exit_timer = Timer.new()
	exit_timer.one_shot = true
	exit_timer.wait_time = 2.0
	exit_timer.timeout.connect(_on_exit_timer_timeout)
	add_child(exit_timer)

	# Signale verbinden
	aggro_area.body_entered.connect(_on_aggro_enter)
	aggro_area.body_exited.connect(_on_aggro_exit)
	force_fight_area.force_fight.connect(_on_force_fight)


# -- Wird aufgerufen, wenn Spieler in AggroRange kommt
func _on_aggro_enter(body: Node2D) -> void:
	if not body.is_in_group("Players"):
		return

	print("[AggroController]: Player entered aggro range of", npc.name)
	target = body
	is_chasing = true

	# Stoppe Patrol und starte Follow-State
	if npc.has_method("stop_patrol"):
		npc.stop_patrol()

	if npc.state_machine:
		npc.state_machine.transition_to("FollowTargetNPC", {"target": target})


# -- Wenn Spieler AggroRange verlässt
func _on_aggro_exit(body: Node2D) -> void:
	if body == target:
		print("[AggroController]: Player left aggro range, starting exit timer")
		exit_timer.start()


# -- Wenn Timer abläuft und Spieler nicht zurückkam
func _on_exit_timer_timeout() -> void:
	print("[AggroController]: Aggro timeout, returning to patrol")
	target = null
	is_chasing = false

	if npc.has_method("resume_patrol"):
		npc.resume_patrol()

	if npc.state_machine:
		npc.state_machine.transition_to("WalkNPC") # zurück in Patrol-Modus


# -- Wenn Spieler ForceFightArea betritt
func _on_force_fight() -> void:
	print("[AggroController]: Force fight triggered by", npc.name)
	if npc.has_method("start_battle_with"):
		npc.start_battle_with(target)
