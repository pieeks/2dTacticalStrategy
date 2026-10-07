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
	
	add_to_group("Players")
	# Connect animation change signal
	connect("animation_state_changed", Callable(self, "_on_animation_state_changed"))
	action.end_interaction_signal.connect(end_interaction)



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
	if NetworkManagerTest.is_authority(self):
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

## Called when a new peer joins.
## Ensures the new peer receives this player's appearance data.
func _on_new_peer_connected(new_peer_id: int) -> void:
	if not NetworkManagerTest.is_authority(self):
		return
	if save == null or save.appearance_data.is_empty():
		return
	if new_peer_id == multiplayer.get_unique_id():
		return
	sync.rpc_id(new_peer_id, "rpc_sync_full_appearance", save.appearance_data)


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
