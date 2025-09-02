class_name NodeState
extends Node

signal transition(target: String)

var owner_actor: Node = null

func _on_enter() -> void: pass
func _on_exit() -> void: pass
func _on_process(_delta: float) -> void: pass
func _on_physics_process(_delta: float) -> void: pass
func _on_next_transitions() -> void: pass

func request_transition(target: String) -> void:
	transition.emit(target)
