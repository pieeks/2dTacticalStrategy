#class_name CharacterSync
extends MultiplayerSynchronizer

## Drop-in replacement for the former abstract network entity.
## Lives as its own scene (root = MultiplayerSynchronizer) and applies appearance changes.

## Current appearance state (paths per layer)
var appearance: Dictionary = {}

## Reference to the visual CharacterAppearance node (set by parent)
var appearance_node: CharacterAppearance = null


# --- Setup ---

## Parent must call this once in _ready().
func set_appearance_node(node: CharacterAppearance) -> void:
	appearance_node = node


# --- RPCs (keep signatures unchanged) ---

## Syncs a single appearance layer (race, hair, body, leg) across peers.
## NOTE: No authority gating here; authority is checked on send. All peers apply the change.
@rpc("any_peer", "reliable")
func rpc_sync_appearance_change(_peer_id: int, data: Dictionary) -> void:
	if data.has("path") and data.has("layer"):
		_apply_sprite_frames(data["path"], data["layer"])

## Syncs the full appearance data for late-join peers.
## NOTE: Signature kept (owner_peer_id, full_data) but we do not gate by owner here.
@rpc("any_peer", "reliable")
func rpc_sync_full_appearance_change(_owner_peer_id: int, full_data: Dictionary) -> void:
	if full_data.has("appearance") and full_data["appearance"] != null:
		appearance = full_data["appearance"]
		if appearance.has("race_path"):
			_apply_sprite_frames(appearance["race_path"], "race")
		if appearance.has("hair_path"):
			_apply_sprite_frames(appearance["hair_path"], "hair")
		if appearance.has("body_path"):
			_apply_sprite_frames(appearance["body_path"], "body")
		if appearance.has("leg_path"):
			_apply_sprite_frames(appearance["leg_path"], "leg")


# --- Public API (unchanged) ---

## Equip locally and replicate to all peers.
func equip_item(layer: String, frames_path: String) -> void:
	if not NetworkManagerTest.is_authority(self):
		return
	_apply_sprite_frames(frames_path, layer)
	rpc("rpc_sync_appearance_change", multiplayer.get_unique_id(), {"path": frames_path, "layer": layer})


# --- Internal Helpers (unchanged name/behavior) ---

## Applies a single layer to the bound CharacterAppearance node.
func _apply_sprite_frames(path: String, layer: String) -> void:
	if path == "" or appearance_node == null:
		return
	match layer:
		"race": appearance_node.set_race(path)
		"hair": appearance_node.set_hair(path)
		"body": appearance_node.set_body(path)
		"leg":  appearance_node.set_leg(path)
