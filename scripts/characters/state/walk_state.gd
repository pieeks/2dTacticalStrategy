class_name WalkState
extends NodeState

## WalkState
##
## StateMachine state for handling walking animations.
## While in this state, the character is moving and the correct
## walk animation is selected based on movement direction.
##
## Features:
## - Dynamically updates facing direction while moving
## - Emits animation change events
## - Transitions back to Idle when movement stops

const FacingUtilScript := preload("res://scripts/characters/facing_util.gd")

## Cached reference to the owning PlayerCharacter.
var _player: PlayerCharacter


## Called when the state is entered.
## Resets last animation and starts the correct walk animation
## based on current movement or facing direction.
func _on_enter() -> void:
	_player = owner_actor as PlayerCharacter
	if _player:
		var v := _player.move_vec_for_anim()
		var card := FacingUtilScript.snap_to_cardinal(v)
		var facing := (card if card != Vector2.ZERO else FacingUtilScript.snap_to_cardinal(_player.facing_dir()))
		_player._last_anim = ""
		var animationName := "walk_" + FacingUtilScript.dir_name(facing)
		_emit_and_play(animationName)


## Called every physics frame while this state is active.
## Updates the walk animation dynamically to reflect current movement direction.
func _on_physics_process(_delta: float) -> void:
	if _player == null:
		return
	var v := _player.move_vec_for_anim()
	var card := FacingUtilScript.snap_to_cardinal(v)
	var facing := (card if card != Vector2.ZERO else FacingUtilScript.snap_to_cardinal(_player.facing_dir()))
	var animationName := "walk_" + FacingUtilScript.dir_name(facing)
	_emit_and_play(animationName)


## Called after physics to determine transitions.
## Transitions to Idle state when no movement is detected.
func _on_next_transitions() -> void:
	if _player and not _player.is_moving():
		request_transition("Idle")


## Emits animation change signal and plays the animation,
## but only if the animation differs from the last one.
##
## @param anim String: Name of the animation to play.
func _emit_and_play(anim: String) -> void:
	if _player and anim != _player._last_anim:
		_player._last_anim = anim
		_player.emit_signal("animation_state_changed", anim)
		_player.play_animation(anim)
