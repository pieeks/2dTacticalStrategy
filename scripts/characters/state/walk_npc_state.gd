## NPCWalkState
##
## StateMachine state for handling walking animations of NPCs.
## While in this state, the NPC is moving and the correct
## walk animation is selected based on facing direction.
##
## Features:
## - Uses facing_dir() from NPCCharacter (set by PathPatrol or AI)
## - Updates animation dynamically each frame
## - Transitions back to Idle when no movement is detected

class_name NPCWalkState
extends NodeState

## Cached reference to the owning NPCCharacter.
var _npc: NPCCharacter
## Cached reference to the AnimatedSprite2D inside CharacterAppear.
var _sprite: AnimatedSprite2D


## Called when the state is entered.
## Resets last animation and plays the correct walk animation.
func _on_enter() -> void:
	_npc = owner_actor as NPCCharacter
	if _npc:
		_sprite = _npc.get_node_or_null("CharacterAppearance") as AnimatedSprite2D
		_npc._last_anim = ""
		var facing = _snap_to_cardinal(_npc.facing_dir())
		if facing != Vector2.ZERO:
			var animationName := "walk_" + _dir_name(facing)
			_emit_and_play(animationName)


## Called every physics frame while this state is active.
## Updates walk animation to match current facing direction.
func _on_physics_process(_delta: float) -> void:
	if _npc == null:
		return

	var facing = _snap_to_cardinal(_npc.facing_dir())
	if facing == Vector2.ZERO:
		request_transition("idle")   
		return

	var animationName := "walk_" + _dir_name(facing)
	_emit_and_play(animationName)


## Called when exiting the state.
## Stops the sprite animation.
func _on_exit() -> void:
	if _sprite:
		_sprite.stop()


## Maps a direction vector to a string suffix for animation names.
func _dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	else:
		return "front" if v.y >= 0.0 else "back"


## Snaps a vector to a cardinal direction (up, down, left, right).
func _snap_to_cardinal(v: Vector2) -> Vector2:
	if v.length() < 0.01:
		return Vector2.ZERO
	if abs(v.x) >= abs(v.y): 
		return Vector2(signf(v.x), 0.0)
	else:
		return Vector2(0.0, signf(v.y))


## Emits animation change signal and plays animation.
func _emit_and_play(anim: String) -> void:
	if _npc and anim != _npc._last_anim:
		_npc._last_anim = anim
		_npc.emit_signal("animation_state_changed", anim)
		_npc.play_animation(anim)
