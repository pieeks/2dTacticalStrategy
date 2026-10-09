class_name BattleCharacter
extends CharacterBody2D
## Kampf-Charakter: Hex-Klickbewegung, Kamera Follow + WASD-Pan, Position per RPC.

@onready var cam: Camera2D = $Camera2D
@onready var visual: Polygon2D = $Visual
@onready var grid_movement: Node = $GridMovement

@export var free_camera_pan_speed: float = 400.0

## Offset relativ zur Charakter-Position (WASD-Pan).
var _camera_pan_offset: Vector2 = Vector2.ZERO
var _last_synced_pos: Vector2 = Vector2.INF


func _ready() -> void:
	if is_multiplayer_authority():
		cam.enabled = true
		cam.make_current()
	else:
		cam.enabled = false
	var peer_id := get_multiplayer_authority()
	visual.color = Color.from_hsv(fmod(float(peer_id) * 0.17, 1.0), 0.7, 0.95)


func setup_for_fight(grid_manager: GridManager) -> void:
	if grid_movement:
		grid_movement.grid_manager = grid_manager
	if grid_manager:
		global_position = grid_manager.get_snap_global_position(global_position)
	_camera_pan_offset = Vector2.ZERO
	if is_multiplayer_authority():
		_broadcast_position(true)


func activate_camera() -> void:
	if is_multiplayer_authority() and is_instance_valid(cam):
		cam.enabled = true
		cam.make_current()
		_camera_pan_offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if grid_movement:
		grid_movement.process_movement(self, delta)
	_broadcast_position(false)


func _broadcast_position(force: bool) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not force and global_position.distance_squared_to(_last_synced_pos) < 0.25:
		return
	_last_synced_pos = global_position
	rpc_sync_battle_position.rpc(global_position)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_battle_position(pos: Vector2) -> void:
	global_position = pos


func _process(delta: float) -> void:
	if not is_multiplayer_authority():
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
		_camera_pan_offset += move.normalized() * free_camera_pan_speed * delta
	cam.global_position = global_position + _camera_pan_offset
