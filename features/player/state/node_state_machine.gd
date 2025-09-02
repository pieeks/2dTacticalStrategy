class_name NodeStateMachine
extends Node

@export var initial_node_state: NodeState
@export_node_path var owner_actor_path: NodePath  # ← im Inspector setzen

var owner_actor: Node = null
var node_states: Dictionary = {}
var current_node_state: NodeState = null
var current_node_state_name: String = ""

func _ready() -> void:
	# Actor via NodePath auflösen (Inspector-Weg)
	if owner_actor_path != NodePath():
		owner_actor = get_node(owner_actor_path)

	# States einsammeln + Actor injizieren + Signals verbinden
	for child in get_children():
		if child is NodeState:
			node_states[child.name.to_lower()] = child
			child.transition.connect(transition_to)
			child.owner_actor = owner_actor

	# Initial nur einmal setzen
	if initial_node_state:
		_change_state(initial_node_state)
	elif node_states.size() > 0:
		_change_state(node_states.values()[0])

func _process(delta: float) -> void:
	if current_node_state:
		current_node_state._on_process(delta)

func _physics_process(delta: float) -> void:
	if current_node_state:
		current_node_state._on_physics_process(delta)
		current_node_state._on_next_transitions()

func transition_to(node_state_name: String) -> void:
	if node_state_name.to_lower() == current_node_state_name.to_lower():
		return
	var next: NodeState = node_states.get(node_state_name.to_lower())
	if next == null:
		return
	if current_node_state:
		current_node_state._on_exit()
	_change_state(next)

func _change_state(next: NodeState) -> void:
	current_node_state = next
	current_node_state_name = next.name
	current_node_state._on_enter()
