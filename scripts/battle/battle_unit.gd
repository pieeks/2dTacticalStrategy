class_name BattleUnit
extends RefCounted
## One combatant in a fight (player peer avatar or encounter enemy).

const SIDE_PLAYER := "player"
const SIDE_ENEMY := "enemy"

## Placeholder defaults when Save/Spec omit a field.
const DEFAULT_PLAYER_STATS := {
	"health": 100,
	"minDamage": 8,
	"maxDamage": 14,
	"initiative": 10,
	"move": 3,
	"attack_range": 1,
	"level": 1,
}
const DEFAULT_ENEMY_STATS := {
	"health": 80,
	"minDamage": 2,
	"maxDamage": 10,
	"initiative": 5,
	"move": 2,
	"attack_range": 1,
}

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
## True after a successful attack this turn (Attack greys; Wait ends the turn).
var has_attacked: bool = false
## True when mid-fight join: unit exists but acts only from next full round.
var joins_next_round: bool = false
var node: Node2D


func is_alive() -> bool:
	return hp > 0


func is_player() -> bool:
	return side == SIDE_PLAYER


func is_enemy() -> bool:
	return side == SIDE_ENEMY


func reset_turn_flags() -> void:
	has_moved = false
	has_attacked = false


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
		"has_attacked": has_attacked,
		"joins_next_round": joins_next_round,
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
	u.has_attacked = bool(data.get("has_attacked", false))
	u.joins_next_round = bool(data.get("joins_next_round", false))
	return u


static func sync_position_from_dict(u: BattleUnit, data: Dictionary) -> void:
	if u == null or u.node == null:
		return
	if not data.has("pos_x"):
		return
	u.node.global_position = Vector2(float(data.get("pos_x", 0.0)), float(data.get("pos_y", 0.0)))


static func _apply_combat_stats(u: BattleUnit, stats: Dictionary, defaults: Dictionary) -> void:
	u.hp = int(stats.get("health", defaults.get("health", 100)))
	u.max_hp = u.hp
	u.atk_min = int(stats.get("minDamage", defaults.get("minDamage", 5)))
	u.atk_max = int(stats.get("maxDamage", defaults.get("maxDamage", 10)))
	u.initiative = int(stats.get("initiative", defaults.get("initiative", 10)))
	u.move_range = int(stats.get("move", defaults.get("move", 3)))
	u.attack_range = int(stats.get("attack_range", defaults.get("attack_range", 1)))


## Sanitize member_id for node / unit_id suffixes.
static func sanitize_member_id(member_id: String) -> String:
	var raw := member_id.strip_edges()
	if raw.is_empty():
		return "member"
	return raw.validate_node_name()


static func party_unit_id(peer_id: int, member_id: String) -> String:
	return "player_%d_%s" % [peer_id, sanitize_member_id(member_id)]


static func make_player(peer_id: int, stats: Dictionary = {}) -> BattleUnit:
	return make_party_member(peer_id, str(peer_id), stats, "Player %d" % peer_id)


## Party member unit; unit_id = player_<peer>_<member_id>.
static func make_party_member(
	peer_id: int,
	member_id: String,
	stats: Dictionary = {},
	unit_display_name: String = ""
) -> BattleUnit:
	var u := BattleUnit.new()
	var mid := sanitize_member_id(member_id if member_id != "" else str(peer_id))
	u.unit_id = party_unit_id(peer_id, mid)
	u.display_name = unit_display_name if unit_display_name != "" else "Player %d" % peer_id
	u.side = SIDE_PLAYER
	u.owner_peer_id = peer_id
	_apply_combat_stats(u, stats, DEFAULT_PLAYER_STATS)
	return u


static func make_enemy(index: int, encounter: Dictionary) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = "enemy_%d" % index
	u.side = SIDE_ENEMY
	u.owner_peer_id = 0
	var entry: Dictionary = {}
	var roster: Variant = encounter.get("enemy_roster", [])
	if roster is Array and index >= 0 and index < (roster as Array).size():
		var raw: Variant = (roster as Array)[index]
		if raw is Dictionary:
			entry = raw as Dictionary
	u.display_name = str(entry.get("display_name", encounter.get("npc_name", "Enemy")))
	var stats: Dictionary = {}
	if entry.get("stats") is Dictionary:
		stats = entry["stats"] as Dictionary
	elif encounter.get("stats") is Dictionary:
		stats = encounter["stats"] as Dictionary
	_apply_combat_stats(u, stats, DEFAULT_ENEMY_STATS)
	return u
