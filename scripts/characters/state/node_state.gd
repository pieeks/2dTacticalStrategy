class_name NodeState
extends Node

## NodeState
##
## Base class for implementing states in a finite state machine (FSM).
## Each state should extend NodeState and override lifecycle methods
## such as `_on_enter`, `_on_exit`, `_on_process`, `_on_physics_process`, 
## and `_on_next_transitions`.
##
## Features:
## - Provides a unified interface for state behavior
## - Defines signals for requesting state transitions
## - Stores a reference to the owning actor (e.g. PlayerCharacter)
##
## Usage:
## - Extend this class to implement specific states (IdleState, WalkState, etc.)
## - Override lifecycle methods as needed
## - Use `request_transition("TargetStateName")` to signal a state change

## Emitted when this state requests a transition to another state.
## @param target String: The name of the state to transition to.
signal transition(target: String)

## Reference to the node (actor) that owns this state.
## Typically set by the state machine when states are initialized.
var owner_actor: Node = null


## Called when the state is entered.
## Override this in derived classes to set up state-specific behavior.
func _on_enter() -> void: 
	pass

## Called when the state is exited.
## Override this in derived classes to clean up or stop animations.
func _on_exit() -> void: 
	pass

## Called every frame (process loop) while this state is active.
## Override for non-physics updates.
func _on_process(_delta: float) -> void: 
	pass

## Called every physics frame while this state is active.
## Override for movement, collisions, or physics-driven updates.
func _on_physics_process(_delta: float) -> void: 
	pass

## Called after physics to check whether the state should transition.
## Override to evaluate conditions for leaving this state.
func _on_next_transitions() -> void: 
	pass


## Requests a transition to another state by emitting the signal.
##
## @param target String: The name of the state to transition to.
func request_transition(target: String) -> void:
	transition.emit(target)
