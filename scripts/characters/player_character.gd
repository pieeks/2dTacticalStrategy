class_name PlayerCharacter
extends CharacterController

## PlayerCharacter
##
## A controllable multiplayer character.
## Extends CharacterController for movement logic and connects to:
## - CharacterSave: manages persistence (save/load player data)
## - CharacterAppearance: handles visuals and animations
## - NodeStateMachine: drives animation and behavior states
## - CharacterSync: synchronizes appearance, position, and animations
## - Camera2D: provides a local camera for the authority player
##
## Features:
## - Loads player save data on authority
## - Handles late-join synchronization of appearance
## - Syncs position and animations across the network
## - Integrates with state machine for smooth animation handling

@onready var save: CharacterSave = $CharacterSave                           ## Handles player save/load
@onready var appearance: CharacterAppearance = $CharacterAppearance         ## Visual representation of the character
@onready var action: ActionTriggerArea = $ActionArea2D
@onready var sm: Node = $NodeStateMachine                                   ## State machine controlling behavior states
@onready var sync: CharacterSync = $CharacterSync                           ## Sync scene responsible for RPCs
@onready var cam: Camera2D = $Camera2D                                      ## Local camera for authority player

@export var player_name: String 

var is_interacting: bool = false
var player_ui: CanvasLayer

## Timer for periodically saving and broadcasting position updates.
var save_update_timer := 0.0
const SAVE_UPDATE_INTERVAL := 1.5


# --- Lifecycle ---

## Called when the node enters the scene tree.
## - Wires appearance node into sync
## - Loads player save and applies appearance if authority
## - Connects to peer_connected for late-join handling
## - Assigns owner_actor for state machine states
## - Configures camera for authority player
## - Connects animation signal to sync animations
func _ready() -> void:
	# Connect appearance with sync (required for applying visuals)
	if sync and appearance:
		sync.set_appearance_node(appearance)

	# Setup save + initial appearance (authority only)
	if NetworkManagerTest.is_authority(self):
		if save:
			save.setup_player_from_save(multiplayer.get_unique_id(), self)
			if not save.appearance_data.is_empty():
				sync.apply_and_sync_appearance(save.appearance_data)
				player_name = save.player_name
	
	# Late-join: peer_connected (forwarded to clients) + peer_ready (nodes exist / better timing)
	if not NetworkManagerTest.peer_connected.is_connected(_on_new_peer_connected):
		NetworkManagerTest.peer_connected.connect(_on_new_peer_connected)
	if not NetworkManagerTest.peer_ready.is_connected(_on_new_peer_connected):
		NetworkManagerTest.peer_ready.connect(_on_new_peer_connected)
	
	# Assign self as owner_actor for states (fallback)
	if "owner_actor" in sm and sm.owner_actor == null:
		sm.owner_actor = self
		for child in sm.get_children():
			if child is NodeState:
				child.owner_actor = self
	
	# Camera enabled only for authority player
	if NetworkManagerTest.is_authority(self):
		cam.enabled = true
		cam.make_current()
		if not save.appearance_data.is_empty():
			sync.rpc("rpc_sync_full_appearance", save.appearance_data)
	else:
		cam.enabled = false
	
	# Root must stay visible for remotes (invisible roots skip _physics_process
	# and MultiplayerSpawner can replicate visible=false to late joiners).
	visible = true
	if appearance:
		appearance.visible = true
	
	add_to_group("Players")
	# Connect animation change signal
	connect("animation_state_changed", Callable(self, "_on_animation_state_changed"))
	action.end_interaction_signal.connect(end_interaction)
	_apply_fight_world_gate()


func _notification(what: int) -> void:
	# If spawn/sync forces visible=false onto a puppet, undo it immediately.
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_multiplayer_authority() and not visible:
			visible = true
			if appearance:
				appearance.visible = true


func _get_fight_manager() -> Node:
	var overworld := get_tree().get_root().get_node_or_null("Overworld")
	if overworld == null:
		return null
	return overworld.get_node_or_null("FightManager")


func _is_local_peer_in_fight() -> bool:
	var fm := _get_fight_manager()
	if fm == null or not fm.has_method("is_peer_in_fight"):
		return false
	return fm.is_peer_in_fight(get_multiplayer_authority())


## Local authority hides only their Appearance while in a fight (battle cam).
## Never set root `visible = false` — that breaks late-join replication/processing.
func _apply_fight_world_gate() -> void:
	var fm := _get_fight_manager()
	var in_fight := false
	if fm != null and fm.has_method("is_peer_in_fight"):
		in_fight = fm.is_peer_in_fight(get_multiplayer_authority())

	# Always keep root visible for networking / puppet processing.
	visible = true

	if not NetworkManagerTest.is_authority(self):
		if appearance:
			appearance.visible = true
		return

	if appearance:
		appearance.visible = not in_fight
	if in_fight:
		cam.enabled = false
		velocity = Vector2.ZERO
	else:
		if cam:
			cam.enabled = true
			cam.make_current()


## Called by Overworld when this peer leaves a fight.
func restore_from_fight() -> void:
	_apply_fight_world_gate()
	if NetworkManagerTest.is_authority(self) and cam:
		cam.enabled = true
		cam.make_current()


func end_interaction(target: Node) -> void:
	if target.is_in_group("NPCs") && target.is_interacting == true:
		target.end_interaction.rpc_id(1)
	elif target.is_in_group("Players") && target.is_interacting == true:
		target.sync.end_interaction.rpc_id(1)
	print("end interaction")


# --- Physics ---

## Called every physics frame.
## - Authority: processes input, moves character, updates replicated state,
##   and broadcasts position
## - Non-authority (puppets): interpolates display velocity for smooth movement
func _physics_process(delta: float) -> void:
	_apply_fight_world_gate()

	if NetworkManagerTest.is_authority(self):
		if _is_local_peer_in_fight():
			velocity = Vector2.ZERO
			net_is_moving = false
			# Keep world pose flowing so late joiners see the correct Overworld spot.
			if multiplayer != null and multiplayer.has_multiplayer_peer():
				sync.rpc("rpc_sync_position", global_position)
			return

		# Update position save timer
		save_update_timer += delta
		if save_update_timer >= SAVE_UPDATE_INTERVAL:
			save_update_timer = 0.0
			PlayerPartyState.update_position(global_position)
		
		## 8 Richtungen Laufen
		# Input + movement
		var raw := _read_move_input()
		
		# Bewegung darf diagonal sein
		velocity = raw.normalized() * speed
		move_and_slide()
		
		# Animation/Richtungsdaten bleiben auf 4 Richtungen beschränkt
		var dir_for_anim = _snap_to_cardinal(raw)
		
		net_input = dir_for_anim
		net_is_moving = raw.length() > 0.01
		if net_is_moving:
			net_facing = dir_for_anim
	
		# Broadcast position (skip while session is tearing down)
		if multiplayer != null and multiplayer.has_multiplayer_peer():
			sync.rpc("rpc_sync_position", global_position)
	else:
		# Puppet smoothing (interpolates remote motion)
		_display_velocity = _display_velocity.lerp(net_input * speed, 1.0 - pow(0.001, delta))


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if _is_local_peer_in_fight():
		return
	
	if event.is_action_pressed("Action"):
		var target: Node = null
		target = action.get_closest_target(self.global_position)
		if target != null: 
			if target.is_in_group("NPCs"):
				target.request_interaction.rpc_id(1, self.name)
			if target.is_in_group("Players"): 
				print("is in Group: Players")
				sync.interaction_approved.rpc_id(multiplayer.get_unique_id(), {}, "")
				#target.sync.request_interaction_player.rpc_id(1, self.name)

# --- Networking ---

## Called when a new peer joins / becomes ready.
## Deferred so MultiplayerSpawner has time to create this player on the remote.
func _on_new_peer_connected(new_peer_id: int) -> void:
	if not NetworkManagerTest.is_authority(self):
		return
	if new_peer_id == multiplayer.get_unique_id():
		return
	push_state_to_peer(new_peer_id)


## Sends appearance + reliable pose to one peer (late-join / fight snapshot).
func push_state_to_peer(peer_id: int) -> void:
	if not NetworkManagerTest.is_authority(self):
		return
	if peer_id == multiplayer.get_unique_id():
		return
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	_push_state_to_peer_deferred(peer_id)


func _push_state_to_peer_deferred(peer_id: int) -> void:
	# Wait so the remote has spawned this player node before targeted RPCs.
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or sync == null:
		return
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if save != null and not save.appearance_data.is_empty():
		sync.rpc_id(peer_id, "rpc_sync_full_appearance", save.appearance_data)
	sync.rpc_id(peer_id, "rpc_sync_pose", global_position)
	print("PlayerCharacter: resync to peer ", peer_id, " pos=", global_position)


# --- Animation ---

## Plays the given animation locally on the appearance node.
##
## @param anim String: Name of the animation to play.
func play_animation(anim: String) -> void:
	if is_instance_valid(appearance):
		appearance.play(anim)

## Handles animation change events.
## Authority peers broadcast the animation to all other peers.
##
## @param anim String: Name of the animation to synchronize.
func _on_animation_state_changed(anim: String) -> void:
	if NetworkManagerTest.is_authority(self):
		sync.rpc("rpc_sync_animation", anim)
