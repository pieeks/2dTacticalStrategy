## IdleState
##
## StateMachine state for handling idle animations.
## While in this state, the character remains in place but
## updates facing direction animations based on last input.
##
## Features:
## - Chooses correct idle animation depending on facing_dir()
## - Emits animation change events only when animation actually changes
## - Transitions to Walk state when movement input is detected

class_name IdleState
extends NodeState

## Cached reference to the owning PlayerCharacter.
var _player: PlayerCharacter

## Cached reference to the AnimatedSprite2D used for visuals.
var _sprite: AnimatedSprite2D


## Called when the state is entered.
## Fetches references and plays the correct idle animation immediately.
func _on_enter() -> void:
	# References are resolved here to keep states network-agnostic.
	_player = owner_actor as PlayerCharacter
	if _player:
		_sprite = _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		# Reset last_anim so idle animation is guaranteed to trigger
		_player._last_anim = ""
		var animationName := "idle_" + _dir_name(_player.facing_dir())
		_emit_and_play(animationName)


## Called every physics frame while this state is active.
## Updates idle animation based on facing direction.
func _on_physics_process(_delta: float) -> void:
	if _player == null:
		return
	var animationName := "idle_" + _dir_name(_player.facing_dir())
	_emit_and_play(animationName)


## Called after physics to determine whether to transition.
## If movement is detected, transitions to Walk state.
func _on_next_transitions() -> void:
	if _player and _player.is_moving():
		request_transition("Walk")


## Called when exiting the state.
## Stops the sprite animation.
func _on_exit() -> void:
	if _sprite:
		_sprite.stop()


## Maps a facing vector to a string suffix used in animation names.
## @param v Vector2: Facing direction vector.
## @return String: One of "right", "left", "front", or "back".
func _dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	else:
		return "front" if v.y >= 0.0 else "back"


## Emits animation change signal and plays the animation,
## but only if the animation differs from the last one.
##
## @param anim String: Animation name to play.
func _emit_and_play(anim: String) -> void:
	if _player and anim != _player._last_anim:
		_player._last_anim = anim
		_player.emit_signal("animation_state_changed", anim)
		_player.play_animation(anim)
