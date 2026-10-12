class_name AppearanceData
extends RefCounted
## Shared helpers to collect / validate character appearance dictionaries.

const PATH_KEYS: Array[String] = [
	"race_path",
	"hair_path",
	"body_path",
	"leg_path",
	"head_path",
	"main_weapon_path",
	"off_weapon_path",
]


## True if dict has at least one known non-empty layer path.
static func is_usable(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	for key in PATH_KEYS:
		if str(data.get(key, "")).strip_edges() != "":
			return true
	return false


## Appearance from an Overworld player node: sync → save → visual.
static func from_player_node(player: Node) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	var sync_node = player.get("sync")
	if sync_node != null and sync_node.get("appearance") is Dictionary:
		var from_sync: Dictionary = sync_node.appearance
		if is_usable(from_sync):
			return from_sync.duplicate(true)
	var save_node = player.get("save")
	if save_node != null and save_node.get("appearance_data") is Dictionary:
		var from_save: Dictionary = save_node.appearance_data
		if is_usable(from_save):
			return from_save.duplicate(true)
	var app = player.get("appearance")
	if app != null and app.has_method("get_full_data"):
		var from_visual: Dictionary = app.get_full_data()
		if is_usable(from_visual):
			return from_visual
	return {}


## Local party leader appearance, then legacy player_data.appearance.
static func from_local_party() -> Dictionary:
	var leader: Dictionary = PlayerPartyState.get_leader()
	if not leader.is_empty():
		var leader_app: Variant = leader.get("appearance", {})
		if leader_app is Dictionary and is_usable(leader_app as Dictionary):
			return (leader_app as Dictionary).duplicate(true)
	var party_app: Variant = PlayerPartyState.player_data.get("appearance", {})
	if party_app is Dictionary and is_usable(party_app as Dictionary):
		return (party_app as Dictionary).duplicate(true)
	return {}


## Collect appearance for peer: Overworld Players/<id> then local party if peer is local.
static func collect_for_peer(peer_id: int, players_root: Node) -> Dictionary:
	if players_root != null and is_instance_valid(players_root):
		var player: Node = players_root.get_node_or_null(str(peer_id))
		if player != null:
			var from_node := from_player_node(player)
			if is_usable(from_node):
				return from_node
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and peer_id == tree.get_multiplayer().get_unique_id():
		return from_local_party()
	return {}
