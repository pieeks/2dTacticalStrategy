class_name CharacterSync
extends Node

## Current appearance state (paths per layer)
var appearance: Dictionary = {}

## Reference to the visual CharacterAppearance node (set by parent)
var appearance_node: CharacterAppearance = null

## Parent must call this once in _ready().
func set_appearance_node(node: CharacterAppearance) -> void:
	appearance_node = node


@rpc("any_peer", "reliable")
func rpc_sync_full_appearance(data: Dictionary) -> void:
	# Jeder Peer (inkl. Sender) wendet die Daten an
	if appearance_node:
		appearance_node.apply_full_data(data)


@rpc("any_peer", "unreliable_ordered")
func rpc_sync_position(pos: Vector2) -> void:
	var actor := get_parent() # = PlayerCharacter
	if actor:
		actor.global_position = pos


@rpc("any_peer", "unreliable_ordered")
func rpc_sync_animation(anim: String) -> void:
	if appearance_node:
		appearance_node.play(anim)


# --- Public API für Lokales Anwenden + Sync ---

func apply_and_sync_appearance(data: Dictionary) -> void:
	# 1) Lokal sofort anwenden
	if appearance_node:
		appearance_node.apply_full_data(data)

	# 2) Falls Authority: RPC an alle anderen
	if NetworkManagerTest.is_authority(self):
		rpc("rpc_sync_full_appearance", data)
