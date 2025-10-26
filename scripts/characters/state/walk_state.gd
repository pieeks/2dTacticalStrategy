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

## Cached reference to the owning PlayerCharacter.
var _player: PlayerCharacter


## Called when the state is entered.
## Resets last animation and starts the correct walk animation
## based on current movement or facing direction.
func _on_enter() -> void:
	_player = owner_actor as PlayerCharacter
	if _player:
		var v := _player.move_vec_for_anim()
		var card := _snap_to_cardinal(v)
		var facing := (card if card != Vector2.ZERO else _snap_to_cardinal(_player.facing_dir()))
		_player._last_anim = ""
		var animationName := "walk_" + _dir_name(facing)
		_emit_and_play(animationName)


## Called every physics frame while this state is active.
## Updates the walk animation dynamically to reflect current movement direction.
func _on_physics_process(_delta: float) -> void:
	if _player == null:
		return
	var v := _player.move_vec_for_anim()
	var card := _snap_to_cardinal(v)
	var facing := (card if card != Vector2.ZERO else _snap_to_cardinal(_player.facing_dir()))
	var animationName := "walk_" + _dir_name(facing)
	_emit_and_play(animationName)


## Called after physics to determine transitions.
## Transitions to Idle state when no movement is detected.
func _on_next_transitions() -> void:
	if _player and not _player.is_moving():
		request_transition("Idle")


## Maps a movement vector to a string suffix for animation naming.
## @param v Vector2: Movement or facing vector.
## @return String: One of "right", "left", "front", or "back".
func _dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	else:
		return "front" if v.y >= 0.0 else "back"


## Snaps an input vector to a cardinal direction (no diagonals).
## Returns Vector2.ZERO if below movement threshold.
##
## @param v Vector2: The raw movement vector.
## @return Vector2: Snapped unit vector or ZERO.
func _snap_to_cardinal(v: Vector2) -> Vector2:
	if v.length() < 0.01:
		return Vector2.ZERO
	if abs(v.x) >= abs(v.y): 
		return Vector2(signf(v.x), 0.0)
	else:
		return Vector2(0.0, signf(v.y))


## Emits animation change signal and plays the animation.
## Does not check `_last_anim`, so repeated emissions may occur.
##
## @param anim String: Name of the animation to play.
func _emit_and_play(anim: String) -> void:
	if _player:
		_player.emit_signal("animation_state_changed", anim)
		_player.play_animation(anim)
