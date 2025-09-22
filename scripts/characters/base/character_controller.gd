@abstract
class_name CharacterController
extends CharacterBody2D

## Base class for all controllable/movable characters (Player, NPC, Enemy).
## Handles movement, input processing, and replicated states for multiplayer.
## This class should not be instantiated directly.

@export var speed: float = 180.0  ## Movement speed of the character
@export var input_deadzone: float = 0.15  ## Minimum input threshold before movement is registered

signal animation_state_changed(anim: String)

var _last_anim: String = ""

## Replicated movement state (Authority -> Puppets)
var net_input: Vector2 = Vector2.ZERO        ## Last input direction (normalized)
var net_is_moving: bool = false              ## Whether the character is currently moving
var net_facing: Vector2 = Vector2.DOWN       ## Facing direction of the character

## For puppets only: smoothed display velocity (interpolation)
var _display_velocity: Vector2 = Vector2.ZERO


# --- API for States ---

## Returns true if the character is currently moving.
func is_moving() -> bool:
	return net_is_moving

## Returns the current facing direction (normalized, e.g. Vector2.LEFT).
func facing_dir() -> Vector2:
	return net_facing

## Returns the movement vector used for animations.
## Authority → real velocity, Puppet → smoothed display velocity.
func move_vec_for_anim() -> Vector2:
	return velocity if NetworkManagerTest.is_authority(self) else _display_velocity


# --- Input Handling ---

## Reads the player's movement input (actions: walk_left, walk_right, walk_up, walk_down).
## Returns a normalized Vector2.
func _read_move_input() -> Vector2:
	var v := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	return v.normalized()

## Snaps input to cardinal directions (up, down, left, right).
## Prevents diagonal input and respects the input deadzone.
func _snap_to_cardinal(v: Vector2) -> Vector2:
	if v.length() < input_deadzone:
		return Vector2.ZERO

	var ax := absf(v.x)
	var ay := absf(v.y)
	var eps := 0.0001

	if ax > ay + eps:
		return Vector2(float(signf(v.x)), 0.0)
	elif ay > ax + eps:
		return Vector2(0.0, float(signf(v.y)))
	else:
		# Tie-break: prefer the current facing axis to avoid jitter
		if absf(net_facing.x) >= absf(net_facing.y):
			return Vector2(float(signf(v.x)), 0.0)
		else:
			return Vector2(0.0, float(signf(v.y)))
