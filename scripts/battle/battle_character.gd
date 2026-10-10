class_name BattleCharacter
extends CharacterBody2D
## Kampf-Charakter: komplett freie Kamera (Welt-fest) + WASD-Pan.
## Kein Auto-Follow / kein Zug-Recenter. Overworld-Kamera unberührt.

@onready var cam: Camera2D = $Camera2D
@onready var appearance: CharacterAppearance = $CharacterAppearance
@onready var grid_movement: Node = $GridMovement

@export var free_camera_pan_speed: float = 400.0

var _last_synced_pos: Vector2 = Vector2.INF
var _network_active: bool = true
var turn_controller: Node = null
var _pending_appearance: Dictionary = {}
## Place camera on the character only once when entering the fight.
var _camera_placed: bool = false


func _ready() -> void:
	if is_instance_valid(cam):
		# Ignore parent transform so character Move does not drag the view.
		cam.top_level = true
	if is_multiplayer_authority():
		_enable_free_camera(true)
	else:
		if is_instance_valid(cam):
			cam.enabled = false
	if grid_movement:
		grid_movement.input_enabled = false
	_apply_pending_appearance()


func apply_appearance(data: Dictionary) -> void:
	_pending_appearance = data.duplicate(true) if not data.is_empty() else {}
	_apply_pending_appearance()


func _apply_pending_appearance() -> void:
	if appearance == null:
		appearance = get_node_or_null("CharacterAppearance") as CharacterAppearance
	if appearance == null:
		return
	if not _pending_appearance.is_empty():
		appearance.apply_full_data(_pending_appearance)
	appearance.play("idle_front")


func setup_for_fight(grid_manager: GridManager) -> void:
	if grid_movement:
		grid_movement.grid_manager = grid_manager
		grid_movement.input_enabled = false
	if grid_manager:
		global_position = grid_manager.get_snap_global_position(global_position)
	_network_active = true
	if is_multiplayer_authority():
		_broadcast_position(true)
		_place_camera_once()


func set_turn_controller(controller: Node) -> void:
	turn_controller = controller


func activate_camera() -> void:
	if not is_multiplayer_authority():
		return
	_enable_free_camera(true)
	_place_camera_once()


func _place_camera_once() -> void:
	if _camera_placed or not is_multiplayer_authority() or not is_instance_valid(cam):
		return
	cam.top_level = true
	cam.global_position = global_position
	_camera_placed = true


func _enable_free_camera(make_active: bool) -> void:
	if not is_instance_valid(cam):
		return
	cam.top_level = true
	cam.enabled = make_active
	if make_active:
		cam.make_current()


func stop_network() -> void:
	_network_active = false
	set_physics_process(false)
	set_process(false)
	_camera_placed = false
	if is_instance_valid(cam):
		cam.enabled = false


func _physics_process(_delta: float) -> void:
	if not _network_active:
		return
	# Path animation must run on all peers; only authority broadcasts.
	if grid_movement and grid_movement.is_moving:
		grid_movement.process_movement(self, _delta)
	if is_multiplayer_authority():
		_broadcast_position(false)


func _broadcast_position(force: bool) -> void:
	if not _network_active or not is_inside_tree():
		return
	if not multiplayer.has_multiplayer_peer():
		return
	if not force and global_position.distance_squared_to(_last_synced_pos) < 0.25:
		return
	_last_synced_pos = global_position
	rpc_sync_battle_position.rpc(global_position)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_battle_position(pos: Vector2) -> void:
	if not _network_active or not is_inside_tree():
		return
	global_position = pos


func _process(delta: float) -> void:
	if not _network_active or not is_multiplayer_authority():
		return
	if cam == null or not cam.is_current():
		return
	var move := Vector2.ZERO
	if Input.is_action_pressed("walk_left"):
		move.x -= 1.0
	if Input.is_action_pressed("walk_right"):
		move.x += 1.0
	if Input.is_action_pressed("walk_up"):
		move.y -= 1.0
	if Input.is_action_pressed("walk_down"):
		move.y += 1.0
	if move != Vector2.ZERO:
		cam.global_position += move.normalized() * free_camera_pan_speed * delta
