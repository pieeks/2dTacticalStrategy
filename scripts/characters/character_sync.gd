## CharacterSync
##
## Synchronization helper for networked characters.
## This node is responsible for keeping appearance, position, and animation
## in sync across the network using RPCs.
##
## Usage:
## - Attach CharacterSync as a child of PlayerCharacter.
## - Call `set_appearance_node()` in PlayerCharacter._ready() to link the
##   CharacterAppearance node.
## - Use `apply_and_sync_appearance()` when changing appearance locally;
##   it will update both local visuals and broadcast to other peers.
##
## Replication rules:
## - Appearance is sent reliably to ensure consistency.
## - Position and animations are sent with unreliable_ordered for efficiency
##   (older packets can be dropped in favor of newer updates).

class_name CharacterSync
extends Node

## Stores the current appearance dataset (e.g. paths for race, hair, body, legs).
var appearance: Dictionary = {}

## Reference to the CharacterAppearance node that actually renders visuals.
## Must be set by the parent (PlayerCharacter).
var appearance_node: CharacterAppearance = null

## Definition from max interaction distance
const INTERACTION_RANGE: float = 60.0 
const INTERACTION_RANGE_SQUARED: float = INTERACTION_RANGE * INTERACTION_RANGE

## Links the CharacterAppearance node to this sync node.
## Must be called once by the parent in _ready().
##
## @param node CharacterAppearance: The node responsible for visuals.
func set_appearance_node(node: CharacterAppearance) -> void:
	appearance_node = node


# --- RPCs ---

## Applies a full appearance dataset on all peers, including the sender.
## Called when a new player joins or when full data must be synchronized.
##
## @param data Dictionary: Contains appearance keys (race_path, hair_path, body_path, leg_path).
@rpc("any_peer", "reliable")
func rpc_sync_full_appearance(data: Dictionary) -> void:
	if appearance_node:
		appearance_node.apply_full_data(data)


## Synchronizes the character's global position.
## Sent frequently by the authority using unreliable_ordered replication.
##
## @param pos Vector2: The global position of the player.
@rpc("any_peer", "unreliable_ordered")
func rpc_sync_position(pos: Vector2) -> void:
	var actor := get_parent() # Expected to be PlayerCharacter
	if actor:
		actor.global_position = pos


## Synchronizes animation state across peers.
## Called by authority whenever animation changes (e.g. idle_left, walk_right).
##
## @param anim String: The animation name to play.
@rpc("any_peer", "call_local" ,"reliable")
func rpc_sync_animation(anim: String) -> void:
	if appearance_node:
		appearance_node.play(anim)


# --- Public API ---

## Applies new appearance data locally and, if authority, broadcasts to others.
##
## @param data Dictionary: Contains appearance data with resource paths.
func apply_and_sync_appearance(data: Dictionary) -> void:
	# 1) Always apply locally so the local player sees changes immediately
	if appearance_node:
		appearance_node.apply_full_data(data)

	# 2) Broadcast only if this peer has authority
	if NetworkManagerTest.is_authority(self):
		rpc("rpc_sync_full_appearance", data)
