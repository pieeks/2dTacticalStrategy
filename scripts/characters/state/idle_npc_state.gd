class_name NPCIdleState
extends NodeState

## NPCIdleState
##
## StateMachine state for handling idle animations of NPCs.
## While in this state, the NPC remains in place and plays
## the correct idle animation based on facing direction.
##
## Features:
## - Chooses correct idle animation depending on facing_dir()
## - Guarantees idle animation is triggered on state enter
## - Remains in idle until a transition is triggered externally

## Cached reference to the owning NPCCharacter.
@onready var _character: NPCCharacter

## Cached reference to the AnimatedSprite2D used for visuals.
@onready var _sprite: AnimatedSprite2D


## Called when the state is entered.
## Fetches references and plays the correct idle animation immediately.
func _on_enter() -> void:
	_character = owner_actor as NPCCharacter
	if _character:
		_sprite = _character.get_node_or_null("CharacterAppearance/AnimatedSprite2D") as AnimatedSprite2D
		# Reset last_anim so idle animation is guaranteed to trigger
		_character._last_anim = ""
		var animationName := "idle_" + _dir_name(_character.facing_dir())
		_character.play_animation(animationName)


## Called every frame while this state is active.
## NPC remains idle and does not perform updates.
func _on_process(_delta: float) -> void:
	pass


## Called when exiting the state.
## Currently does nothing, but may later be used for cleanup.
func _on_exit() -> void:
	pass


## Maps a facing vector to a string suffix used in animation names.
## @param v Vector2: Facing direction vector.
## @return String: One of "right", "left", "front", or "back".
func _dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	else:
		return "front" if v.y >= 0.0 else "back"
