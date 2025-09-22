class_name PlayerCharacter
extends CharacterController

## Playable character using a separate CharacterSync scene.
## Keeps the same flow as the abstract setup; no function removals.

@onready var save: CharacterSave = $CharacterSave                           ## optional save scene (kept)
@onready var appearance: CharacterAppearance = $CharacterAppearance         ## visual node
@onready var sm: Node = $NodeStateMachine                                   ## state machine
@onready var sync: CharacterSync = $CharacterSync                           ## sync scene (MultiplayerSynchronizer + script)
@onready var cam: Camera2D = $Camera2D                                      ## local camera

## Periodic position update (kept)
var save_update_timer := 0.0
const SAVE_UPDATE_INTERVAL := 1.5


# --- Lifecycle (kept structure) ---

func _ready() -> void:
	# Wire appearance to sync (critical in scene-based setup)
	if sync and appearance:
		sync.set_appearance_node(appearance)

	# Setup save + initial appearance on authority (kept behavior)
	if NetworkManagerTest.is_authority(self):
		if save:
			save.setup_player_from_save(multiplayer.get_unique_id(), self)
			if save.appearance.size() > 0:
				sync.apply_and_sync_appearance(save.appearance)
	# Late-join handling (kept)
	if NetworkManagerTest.has_signal("peer_connected"):
		NetworkManagerTest.connect("peer_connected", Callable(self, "_on_new_peer_connected"))

	# State machine fallback (kept)
	if "owner_actor" in sm and sm.owner_actor == null:
		sm.owner_actor = self
		for child in sm.get_children():
			if child is NodeState:
				child.owner_actor = self
	
	# Camera only for authority (kept)
	if NetworkManagerTest.is_authority(self):
		cam.enabled = true
		cam.make_current()
		sync.rpc("rpc_sync_full_appearance", save.appearance_data)
	else:
		cam.enabled = false
	
	connect("animation_state_changed", Callable(self, "_on_animation_state_changed"))


# --- Physics (kept) ---

func _physics_process(delta: float) -> void:
	if NetworkManagerTest.is_authority(self):
		save_update_timer += delta
		if save_update_timer >= SAVE_UPDATE_INTERVAL:
			save_update_timer = 0.0
			PlayerPartyState.update_position(global_position)

		var raw := _read_move_input()
		var dir := _snap_to_cardinal(raw)
		velocity = dir * speed
		move_and_slide()

		net_input = dir
		net_is_moving = dir.length() > 0.01
		if net_is_moving:
			net_facing = dir.normalized()
		sync.rpc("rpc_sync_position", global_position)
	else:
		_display_velocity = _display_velocity.lerp(net_input * speed, 1.0 - pow(0.001, delta))


# --- Networking (kept signature/flow) ---

## Send full appearance to late-join peer (kept two-arg RPC call)
func _on_new_peer_connected(_new_peer_id: int) -> void:
	if NetworkManagerTest.is_authority(self):
		# Keep original signature: (owner_peer_id, full_data)
		sync.apply_and_sync_appearance(save.appearance_data)


# --- Animation (kept) ---

func play_animation(anim: String) -> void:
	if is_instance_valid(appearance):
		appearance.play(anim)

func _on_animation_state_changed(anim: String) -> void:
	# Authority broadcastet Animationen
	if NetworkManagerTest.is_authority(self):
		sync.rpc("rpc_sync_animation", anim)
