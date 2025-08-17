class_name Player
extends CharacterBody2D

@onready var cam: Camera2D = $Camera2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sm: Node = $NodeStateMachine
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var speed: float = 180.0  # Warum: leicht im Inspector anpassbar

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
		var dir := _read_move_input()  # nutzt walk_* Actions
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
	# Warum: Animationen nur instanzlokal triggern
	if is_instance_valid(sprite) and sprite.animation != name:
		sprite.play(name)

# ----- Authority / Input -----
func _is_authority() -> bool:
	# Warum: Einzelspieler/ohne Peer testbar halten
	if not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.get_unique_id() == get_multiplayer_authority()

func _read_move_input() -> Vector2:
	# Achtung: Nur deine Actions (kein ui_* Fallback)
	# get_vector(left, right, up, down)
	var v := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	return v.normalized()
