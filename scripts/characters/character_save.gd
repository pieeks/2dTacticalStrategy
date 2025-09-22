class_name CharacterSave extends Node

## Base class that adds save/load functionality on top of CharacterNetworkEntity.
## Handles player identification, save data setup, and applying stored state.

## Unique player identifier, tied to multiplayer peer_id or save data.
var player_id: String = ""
## Player display name.
var player_name: String = ""
## Player Appearance.
var appearance: Dictionary = {}
var appearance_data: Dictionary = {}


# --- Save / Load ---

## Sets up the player state from save data or default remote data.
## - If this peer is the local authority: uses PlayerPartyState data.
## - If this is a remote peer: assigns a temporary ID and placeholder name.
func setup_player_from_save(peer_id: int, current_player: Node) -> void:
	var save_data := {}
	if peer_id == multiplayer.get_unique_id():
		# Local authority: load full save data
		save_data = {
			"player_id": PlayerPartyState.player_id,
			"name": PlayerPartyState.player_data.get("name"),
			"position": PlayerPartyState.position_data,
			"appearance": PlayerPartyState.player_data.get("appearance")
		}
	else: 
		# Remote peer: placeholder data until sync
		save_data = {
			"player_id": str(peer_id),
			"name": "Remote_" + str(peer_id),
			"position": Vector2.ZERO
		}
	apply_save_data(save_data, current_player)


## Applies save data to the character entity:
## - Updates player ID, name, position
## - Applies stored appearance to CharacterAppearance node
func apply_save_data(data: Dictionary, current_player: Node) -> void:
	# Apply core identifiers
	if data.has("player_id"):
		player_id = data["player_id"]
	if data.has("position"): 
		var vector2 = Vector2(float(data["position"]["x"]), float(data["position"]["y"]))
		current_player.global_position = vector2
	if data.has("name") and data["name"] != null: 
		player_name = data["name"]
	if data.has("appearance") and data["appearance"] != null: 
		appearance = data["appearance"]
		appearance_data = {
			"race_path": appearance.get("race_path", ""),
			"hair_path": appearance.get("hair_path", ""),
			"body_path": appearance.get("body_path", ""),
			"leg_path": appearance.get("leg_path", "")
		}
