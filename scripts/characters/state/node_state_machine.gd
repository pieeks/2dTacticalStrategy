class_name NodeStateMachine
extends Node

## NodeStateMachine
##
## A finite state machine (FSM) manager for NodeState-based states.
## Manages state transitions, processes state logic every frame,
## and injects the owning actor reference into each state.
##
## Features:
## - Automatically collects all child NodeStates
## - Injects owner_actor into each state for context
## - Connects transition signals between states
## - Calls appropriate lifecycle methods (_on_enter, _on_exit, etc.)
##
## Usage:
## - Add this node as parent of multiple NodeState children (e.g. IdleState, WalkState).
## - Set `initial_node_state` via Inspector to define starting state.
## - Optionally set `owner_actor_path` to provide actor reference (e.g. PlayerCharacter).
## - States call `request_transition("StateName")` to trigger transitions.

## The state to enter when the state machine starts.
@export var initial_node_state: NodeState

## NodePath to the actor (e.g. PlayerCharacter) this state machine belongs to.
## Will be resolved in _ready() and injected into states.
@export_node_path var owner_actor_path: NodePath

## Reference to the resolved actor node (set in _ready()).
var owner_actor: Node = null

## Dictionary of all child states, keyed by lowercase state name.
var node_states: Dictionary = {}

## Reference to the currently active state.
var current_node_state: NodeState = null

## Name of the currently active state.
var current_node_state_name: String = ""


## Called when the node enters the scene tree.
## - Resolves owner actor if path is set
## - Collects child NodeStates and connects signals
## - Activates initial state
func _ready() -> void:
	# Resolve actor via NodePath (Inspector-set)
	if owner_actor_path != NodePath():
		owner_actor = get_node(owner_actor_path)

	# Collect states, inject actor, and connect transitions
	for child in get_children():
		if child is NodeState:
			node_states[child.name.to_lower()] = child
			child.transition.connect(transition_to)
			child.owner_actor = owner_actor

	# Enter initial state (Inspector or first child fallback)
	if initial_node_state:
		_change_state(initial_node_state)
	elif node_states.size() > 0:
		_change_state(node_states.values()[0])


## Called every frame.
## Delegates processing to current state.
func _process(delta: float) -> void:
	if current_node_state:
		current_node_state._on_process(delta)


## Called every physics frame.
## Delegates physics and transition checks to current state.
func _physics_process(delta: float) -> void:
	if current_node_state:
		current_node_state._on_physics_process(delta)
		current_node_state._on_next_transitions()


## Handles state transition request.
## Checks for invalid transitions and calls exit/enter lifecycle methods.
##
## @param node_state_name String: Name of the state to transition to.
func transition_to(node_state_name: String, msg := {}) -> void:
	if node_state_name.to_lower() == current_node_state_name.to_lower():
		return
	var next: NodeState = node_states.get(node_state_name.to_lower())
	if next == null:
		return
	if current_node_state:
		current_node_state._on_exit()
	_change_state(next, msg)


## Changes current state to the given one.
## Updates state references and calls enter lifecycle method.
##
## @param next NodeState: The state node to switch to.
func _change_state(next: NodeState, msg := {}) -> void:
	current_node_state = next
	current_node_state_name = next.name
	if "_on_enter" in next and current_node_state.has_method("_on_enter"):
		var arg_count := current_node_state.get_method_argument_count("_on_enter")
		if arg_count > 0: 
			current_node_state.call("_on_enter", msg)
		else:
			current_node_state._on_enter()
	
