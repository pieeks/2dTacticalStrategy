class_name BattleUnit
extends RefCounted
## One combatant in a fight (player peer avatar or encounter enemy).

const SIDE_PLAYER := "player"
const SIDE_ENEMY := "enemy"

var unit_id: String = ""
var display_name: String = ""
var side: String = SIDE_PLAYER
var owner_peer_id: int = 0
var initiative: int = 10
var move_range: int = 3
var attack_range: int = 1
var hp: int = 100
var max_hp: int = 100
var atk_min: int = 5
var atk_max: int = 10
var has_moved: bool = false
var node: Node2D


func is_alive() -> bool:
	return hp > 0


func is_player() -> bool:
	return side == SIDE_PLAYER


func is_enemy() -> bool:
	return side == SIDE_ENEMY


func reset_turn_flags() -> void:
	has_moved = false


func to_sync_dict() -> Dictionary:
	var pos := Vector2.ZERO
	if node != null:
		pos = node.global_position
	return {
		"unit_id": unit_id,
		"display_name": display_name,
		"side": side,
		"owner_peer_id": owner_peer_id,
		"initiative": initiative,
		"move_range": move_range,
		"attack_range": attack_range,
		"hp": hp,
		"max_hp": max_hp,
		"atk_min": atk_min,
		"atk_max": atk_max,
		"has_moved": has_moved,
		"pos_x": pos.x,
		"pos_y": pos.y,
	}


static func from_sync_dict(data: Dictionary) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = str(data.get("unit_id", ""))
	u.display_name = str(data.get("display_name", u.unit_id))
	u.side = str(data.get("side", SIDE_PLAYER))
	u.owner_peer_id = int(data.get("owner_peer_id", 0))
	u.initiative = int(data.get("initiative", 10))
	u.move_range = int(data.get("move_range", 3))
	u.attack_range = int(data.get("attack_range", 1))
	u.hp = int(data.get("hp", 100))
	u.max_hp = int(data.get("max_hp", u.hp))
	u.atk_min = int(data.get("atk_min", 5))
	u.atk_max = int(data.get("atk_max", 10))
	u.has_moved = bool(data.get("has_moved", false))
	return u


static func sync_position_from_dict(u: BattleUnit, data: Dictionary) -> void:
	if u == null or u.node == null:
		return
	if not data.has("pos_x"):
		return
	u.node.global_position = Vector2(float(data.get("pos_x", 0.0)), float(data.get("pos_y", 0.0)))


static func make_player(peer_id: int) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = "player_%d" % peer_id
	u.display_name = "Player %d" % peer_id
	u.side = SIDE_PLAYER
	u.owner_peer_id = peer_id
	u.initiative = 10
	u.move_range = 3
	u.attack_range = 1
	u.hp = 100
	u.max_hp = 100
	u.atk_min = 8
	u.atk_max = 14
	return u


static func make_enemy(index: int, encounter: Dictionary) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = "enemy_%d" % index
	u.display_name = str(encounter.get("npc_name", "Enemy"))
	u.side = SIDE_ENEMY
	u.owner_peer_id = 0
	u.initiative = 5
	u.move_range = 2
	u.attack_range = 1
	var stats: Dictionary = encounter.get("stats", {})
	u.hp = int(stats.get("health", 80))
	u.max_hp = u.hp
	u.atk_min = int(stats.get("minDamage", 2))
	u.atk_max = int(stats.get("maxDamage", 10))
	return u
