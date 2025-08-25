class_name Player
extends CharacterBody2D

@onready var cam: Camera2D = $Camera2D
@onready var sprite: Node2D = $Character
@onready var sm: Node = $NodeStateMachine
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var speed: float = 180.0  
@export var input_deadzone: float = 0.15

# Replizierter Bewegungszustand (Authority -> Puppets)
var net_input: Vector2 = Vector2.ZERO
var net_is_moving: bool = false
var net_facing: Vector2 = Vector2.DOWN

# Nur Darstellung bei Puppets glätten
var _display_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Lokale Kamera nur für Authority
	if _is_authority():
		cam.enabled = true
		cam.make_current()
	else:
		cam.enabled = false

	# Fallback: SM den Actor geben, falls nicht über NodePath gesetzt
	if "owner_actor" in sm and sm.owner_actor == null:
		sm.owner_actor = self
		for child in sm.get_children():
			if child is NodeState:
				child.owner_actor = self

func _physics_process(delta: float) -> void:
	if _is_authority():
		# Nur Authority liest Eingabe + bewegt
		var raw := _read_move_input()  # nutzt walk_* Actions
		var dir := _snap_to_cardinal(raw)
		
		velocity = dir * speed
		move_and_slide()

		# Replizierbarer Zustand für States/Animation
		net_input = dir
		net_is_moving = dir.length() > 0.01
		if net_is_moving:
			net_facing = dir.normalized()
	else:
		# Puppet: Anzeige glätten (Position kommt vom Synchronizer)
		_display_velocity = _display_velocity.lerp(net_input * speed, 1.0 - pow(0.001, delta))

# ----- API für States -----
func is_moving() -> bool:
	return net_is_moving

func facing_dir() -> Vector2:
	return net_facing

func move_vec_for_anim() -> Vector2:
	# Warum: States bekommen sinnvolle Bewegungsgröße je nach Rolle
	return velocity if _is_authority() else _display_velocity

func play_animation(name: String) -> void:
	if is_instance_valid(sprite):
		sprite.play(name)

# ----- Authority / Input -----
func _is_authority() -> bool:
	# Warum: Einzelspieler/ohne Peer testbar halten
	if not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.get_unique_id() == get_multiplayer_authority()

func _read_move_input() -> Vector2:
	var v := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	return v.normalized()


func _snap_to_cardinal(v: Vector2) -> Vector2:
	# Deadzone
	if v.length() < input_deadzone:
		return Vector2.ZERO

	var ax := absf(v.x)
	var ay := absf(v.y)
	var eps := 0.0001

	# Dominante Achse wählen; bei Gleichstand letzte Blickachse bevorzugen (Warum: Jitter vermeiden).
	if ax > ay + eps:
		return Vector2(float(signf(v.x)), 0.0)
	elif ay > ax + eps:
		return Vector2(0.0, float(signf(v.y)))
	else:
		# Tie-Break anhand aktueller Facing-Achse
		if absf(net_facing.x) >= absf(net_facing.y):
			return Vector2(float(signf(v.x)), 0.0)
		else:
			return Vector2(0.0, float(signf(v.y)))
