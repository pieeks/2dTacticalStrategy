class_name BattleCharacter
extends CharacterBody2D
## Kampf-Charakter: komplett freie Kamera (Welt-fest) + WASD-Pan.
## Kamera am lokalen Leader (Legacy: Name == Peer-ID; §5b: meta is_party_leader).
## Pos-Sync weiter authority-gated. Overworld-Kamera unberührt.

const CORPSE_MODULATE := Color(0.62, 0.62, 0.7, 0.95)

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
## True after HP hits 0 — corpse stays visible; unit no longer blocks the grid.
var is_corpse: bool = false


func _enter_tree() -> void:
	# Legacy: name was peer_id. §5b names are player_<peer>_<member_id> (authority set by spawner).
	if str(name).is_valid_int():
		set_multiplayer_authority(int(str(name)))


## Local camera/pan owner: legacy peer-named node, or §5b party leader meta.
func _is_local_fighter() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var my_id := multiplayer.get_unique_id()
	if get_multiplayer_authority() != my_id:
		return false
	# Legacy single-avatar name == peer_id.
	if str(name).is_valid_int():
		return int(str(name)) == my_id
	# §5b: only the designated party leader claims the fight camera.
	return bool(get_meta("is_party_leader", false))


func _ready() -> void:
	if is_instance_valid(cam):
		# Ignore parent transform so character Move does not drag the view.
		cam.top_level = true
	if _is_local_fighter():
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
	appearance.play("idle_front_battle")


## Death clip (or freeze) + downed look. Idempotent; stays visible on the cell.
func play_death() -> void:
	if is_corpse:
		refresh_corpse_modulate()
		return
	is_corpse = true
	set_meta("is_corpse", true)
	if appearance == null:
		appearance = get_node_or_null("CharacterAppearance") as CharacterAppearance
	if appearance != null and appearance.has_method("play_death"):
		appearance.play_death("front")
	if appearance != null:
		appearance.rotation = deg_to_rad(70.0)
		appearance.position = Vector2(4.0, 6.0)
		appearance.modulate = Color(0.85, 0.85, 0.9, 1.0)
	z_index = 1
	refresh_corpse_modulate()


## Re-apply corpse tint (e.g. after hit-flash tween restores modulate).
func refresh_corpse_modulate() -> void:
	modulate = CORPSE_MODULATE
	visible = true


func setup_for_fight(grid_manager: GridManager) -> void:
	if grid_movement:
		grid_movement.grid_manager = grid_manager
		grid_movement.input_enabled = false
	if grid_manager:
		global_position = grid_manager.get_snap_global_position(global_position)
	_network_active = true
	if is_multiplayer_authority():
		_broadcast_position(true)
	if _is_local_fighter():
		_place_camera_once()


func set_turn_controller(controller: Node) -> void:
	turn_controller = controller


func activate_camera() -> void:
	if not _is_local_fighter():
		return
	_enable_free_camera(true)
	_place_camera_once()


func _place_camera_once() -> void:
	if _camera_placed or not _is_local_fighter() or not is_instance_valid(cam):
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
	if not _network_active or not _is_local_fighter():
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
