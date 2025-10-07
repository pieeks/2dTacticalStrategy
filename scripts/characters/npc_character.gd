class_name NPCCharacter
extends CharacterController

## NPCCharacter
##
## Base class for all NPCs in the game.
## Inherits from CharacterController to reuse movement,
## facing direction, and animation handling logic.
##
## Features:
## - Contains state machine reference for behavior
## - Provides access to appearance node (sprites/animations)
## - Ready hook for initializing NPC-specific settings
## - Can be extended with interaction or AI logic later

## Reference to the finite state machine controlling this NPC.
@onready var state_machine: NodeStateMachine = $StateMachine

## Reference to the appearance node (shared with players).
@onready var appearance: CharacterAppearance = $CharacterAppearance

@onready var specification: NpcSpecification = $NPCSpecificatioinsContainer


## Called when the NPC enters the scene tree.
## Injects actor reference into the state machine.
func _ready() -> void:
	if "owner_actor" in state_machine and state_machine.owner_actor == null:
		state_machine.owner_actor = self


## Plays the given animation locally on the appearance node.
##
## @param anim String: Name of the animation to play.
func play_animation(anim: String) -> void:
	if is_instance_valid(appearance):
		appearance.play(anim)
