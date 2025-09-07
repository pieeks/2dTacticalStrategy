class_name Player
extends CharacterBody2D

@onready var cam: Camera2D = $Camera2D
@onready var characterSprite: Node2D = $Character
@onready var sm: Node = $NodeStateMachine
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var speed: float = 180.0  
@export var input_deadzone: float = 0.15

# Player save Daten
var player_id: String = ""
var player_name: String = ""
var appearance: Dictionary = {}

# Replizierter Bewegungszustand (Authority -> Puppets)
var net_input: Vector2 = Vector2.ZERO
var net_is_moving: bool = false
var net_facing: Vector2 = Vector2.DOWN

# Nur Darstellung bei Puppets glätten
var _display_velocity: Vector2 = Vector2.ZERO

# Update Position Timer
var save_update_timer := 0.0
const SAVE_UPDATE_INTERVAL := 2.0


func _ready() -> void:
	if _is_authority(): 
		setup_player_from_save(multiplayer.get_unique_id())
	if NetworkManagerTest.has_signal("peer_connected"):
		NetworkManagerTest.connect("peer_connected", Callable(self, "_on_new_peer_connected"))
	# Fallback: SM den Actor geben, falls nicht über NodePath gesetzt
	if "owner_actor" in sm and sm.owner_actor == null:
		sm.owner_actor = self
		for child in sm.get_children():
			if child is NodeState:
				child.owner_actor = self


func _physics_process(delta: float) -> void:
	if _is_authority():
		save_update_timer += delta
		if save_update_timer >= SAVE_UPDATE_INTERVAL:
			save_update_timer = 0.0
			PlayerPartyState.update_position(global_position)
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


func _on_new_peer_connected(new_peer_id: int) -> void:
	if _is_authority(): 
		var full_data := {
			"appearance": appearance,
			"name": player_name,
			"player_id": player_id
		}
		rpc_id(new_peer_id, "rpc_sync_full_appearance_change", get_multiplayer_authority(), full_data)


# ----- API für States -----
func is_moving() -> bool:
	return net_is_moving


func facing_dir() -> Vector2:
	return net_facing


func move_vec_for_anim() -> Vector2:
	# Warum: States bekommen sinnvolle Bewegungsgröße je nach Rolle
	return velocity if _is_authority() else _display_velocity


func play_animation(name: String) -> void:
	if is_instance_valid(characterSprite):
		characterSprite.play(name)


# ----- Authority / Input -----
func _is_authority() -> bool:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
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


# Aktualisierungen und Save / Load
func setup_player_from_save(peer_id: int) -> void:
	var save_data := {}
	if peer_id == multiplayer.get_unique_id():
		save_data = {
			"player_id": PlayerPartyState.player_id,
			"name": PlayerPartyState.player_data.get("name"),
			"position":PlayerPartyState.position_data,
			"appearance": PlayerPartyState.player_data.get("appearance")
		}
	else: 
		save_data = {
			"player_id": str(peer_id),
			"name": "Remote_" + str(peer_id),
			"position": Vector2.ZERO
		}
	apply_save_data(save_data)


func apply_save_data(data: Dictionary) -> void:
		# Lokale Kamera nur für Authority
	if _is_authority():
		cam.enabled = true
		cam.make_current()
	else:
		cam.enabled = false
	
	if data.has("player_id"):
		player_id = data["player_id"]
	if data.has("position"): 
		var vector2 = Vector2(float(data["position"]["x"]), float(data["position"]["y"]))
		global_position = vector2
	if data.has("name") and data["name"] != null: 
		player_name = data["name"]
	if data.has("appearance") and data["appearance"] != null: #TODO Erweitern bei mehr SpriteSheets
		appearance = data["appearance"]
		if appearance.has("hair_path"): 
			equip_item("hair", appearance["hair_path"])
		

func equip_item(layer: String, frames_path: String) -> void:
	if not _is_authority(): 
		return
	_apply_sprite_frames(frames_path, layer)
	rpc("rpc_sync_appearance_change", multiplayer.get_unique_id(), {"path": frames_path, "layer": layer})
	

func _apply_sprite_frames(path: String, layer: String) -> void:
	if path == "": 
		return
	var char_node: Character = $Character
	match layer:
		"hair":
			char_node.set_hair(path) #TODO erweitern bei mehr SpritesSheets

# RPCs
@rpc("any_peer", "reliable")
func rpc_sync_appearance_change(peer_id: int, data: Dictionary) -> void:
	if peer_id == get_multiplayer_authority():
		if data.has("path") and data.has("layer"):
			_apply_sprite_frames(data["path"], data["layer"])

@rpc("any_peer", "reliable")
func rpc_sync_full_appearance_change(owner_peer_id: int, full_data: Dictionary) -> void:
	if owner_peer_id == get_multiplayer_authority():
		if full_data.has("appearance") and full_data["appearance"] != null:
			appearance = full_data["appearance"]
			if appearance.has("hair_path"):
				_apply_sprite_frames(appearance["hair_path"], "hair")
