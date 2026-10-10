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


func _has_multiplayer_peer() -> bool:
	return multiplayer != null and multiplayer.has_multiplayer_peer()


# --- RPCs ---

## Applies a full appearance dataset on all peers, including the sender.
## Called when a new player joins or when full data must be synchronized.
##
## @param data Dictionary: Contains appearance keys (race_path, hair_path, body_path, leg_path).
@rpc("any_peer", "reliable")
func rpc_sync_full_appearance(data: Dictionary) -> void:
	_store_appearance_data(data)
	if appearance_node:
		appearance_node.apply_full_data(data)


## Synchronizes the character's global position.
## Sent frequently by the authority using unreliable_ordered replication.
##
## @param pos Vector2: The global position of the player.
@rpc("any_peer", "unreliable_ordered")
func rpc_sync_position(pos: Vector2) -> void:
	_apply_authority_position(pos)


## Reliable one-shot pose for late-join / fight snapshots (must not be dropped).
@rpc("any_peer", "reliable")
func rpc_sync_pose(pos: Vector2) -> void:
	_apply_authority_position(pos)


func _apply_authority_position(pos: Vector2) -> void:
	if not _has_multiplayer_peer():
		return
	var sender := multiplayer.get_remote_sender_id()
	var actor := get_parent() # Expected to be PlayerCharacter
	if actor == null or sender != actor.get_multiplayer_authority():
		return
	actor.global_position = pos


## Synchronizes animation state across peers.
## Called by authority whenever animation changes (e.g. idle_left, walk_right).
##
## @param anim String: The animation name to play.
@rpc("any_peer", "call_local" ,"reliable")
func rpc_sync_animation(anim: String) -> void:
	if appearance_node:
		appearance_node.play(anim)


@rpc("any_peer", "call_local", "reliable")
func interaction_approved(npc_data: Dictionary, npc_path: String) -> void:
	var actor := get_parent()
	if actor == null or actor.player_ui == null:
		return
	actor.player_ui.show_interaction_menu(npc_data, npc_path)


@rpc("any_peer", "call_local", "reliable")
func request_interaction_player(player_name: String):
	if not _has_multiplayer_peer() or not multiplayer.is_server():
		return
	
	var player_node = get_tree().get_root().get_node_or_null("Overworld/Players/" + player_name)
	var actor := get_parent()
	
	if not is_instance_valid(player_node):
		printerr("Host: Konnte Spieler mit ID nicht finden: ", player_name)
		return 
	
	var interaction_range: float = 60.0 
	var dist_sq: float = player_node.global_position.distance_squared_to(actor.global_position)
	
	if dist_sq <= interaction_range * interaction_range:
		print("Host: Interaktion von Spieler ", player_name, " mit ", self.name, " genehmigt.")
		actor.is_interacting = true
		actor.player_ui.show_interaction_menu({}, "")
		#optional: Bestätigung senden an Spieler
	else:
		print("Host: Interaktion von Spieler ", player_name, " mit ", self.name, " abgelehnt (Distanz).")


@rpc("any_peer", "call_local", "reliable")
func end_interaction():
	if not _has_multiplayer_peer() or not multiplayer.is_server():
		return
	var actor := get_parent()
	if actor == null or not actor.is_interacting:
		return
		
	print("Host: ", self.name, " beendet Interaktion.")
	actor.is_interacting = false 


# --- Public API ---

## Applies new appearance data locally and, if authority, broadcasts to others.
##
## @param data Dictionary: Contains appearance data with resource paths.
func apply_and_sync_appearance(data: Dictionary) -> void:
	# 1) Always apply locally so the local player sees changes immediately
	_store_appearance_data(data)
	if appearance_node:
		appearance_node.apply_full_data(data)

	# 2) Broadcast only if this peer has authority and a session is active
	if NetworkManagerTest.is_authority(self) and _has_multiplayer_peer():
		rpc("rpc_sync_full_appearance", data)


func _store_appearance_data(data: Dictionary) -> void:
	appearance = data.duplicate(true)
	var save_node := get_parent().get_node_or_null("CharacterSave") if get_parent() else null
	if save_node != null:
		save_node.appearance = appearance.duplicate(true)
		save_node.appearance_data = {
			"race_path": appearance.get("race_path", ""),
			"hair_path": appearance.get("hair_path", ""),
			"body_path": appearance.get("body_path", ""),
			"leg_path": appearance.get("leg_path", ""),
		}
