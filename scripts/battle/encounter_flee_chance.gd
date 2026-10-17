class_name EncounterFleeChance
extends RefCounted
## Pre-fight flee chance + enemy composition summary for the encounter prompt.
##
## v1 formula: clamp(0.15, 0.85, 0.5 + 0.05 * (player_level - max_enemy_level))
## Extra keys under ctx.modifiers (e.g. initiative_delta) can be applied later.

const BASE_CHANCE := 0.5
const LEVEL_GAP_FACTOR := 0.05
const CHANCE_MIN := 0.15
const CHANCE_MAX := 0.85


## Build a flee context. `extras.modifiers` is a Dictionary reserved for future stats.
static func build_context(player_level: int, enemy_levels: Array, extras: Dictionary = {}) -> Dictionary:
	var levels: Array = []
	for v in enemy_levels:
		levels.append(maxi(1, int(v)))
	var mods: Dictionary = {}
	if extras.get("modifiers") is Dictionary:
		mods = (extras["modifiers"] as Dictionary).duplicate(true)
	return {
		"player_level": maxi(1, player_level),
		"enemy_levels": levels,
		"max_enemy_level": _max_level(levels),
		"modifiers": mods,
	}


## Chance in 0..1 after level gap and optional modifier hooks.
static func compute_chance(ctx: Dictionary) -> float:
	var player_lvl := maxi(1, int(ctx.get("player_level", 1)))
	var max_enemy := maxi(1, int(ctx.get("max_enemy_level", 1)))
	var chance := BASE_CHANCE + LEVEL_GAP_FACTOR * float(player_lvl - max_enemy)
	var mods: Variant = ctx.get("modifiers", {})
	if mods is Dictionary:
		# Future: initiative_delta, status flags, gear — applied as flat additives for now.
		if (mods as Dictionary).has("initiative_delta"):
			chance += 0.01 * float((mods as Dictionary)["initiative_delta"])
		if (mods as Dictionary).has("flat"):
			chance += float((mods as Dictionary)["flat"])
	return clampf(chance, CHANCE_MIN, CHANCE_MAX)


## True if the flee attempt succeeds.
static func roll(chance: float) -> bool:
	return randf() < clampf(chance, 0.0, 1.0)


## Localized composition string, e.g. "3× Slime" / "2× A, 1× B".
static func composition_text(roster: Array) -> String:
	var counts: Dictionary = {} # display_name -> count
	var order: Array[String] = []
	for entry in roster:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var display := str((entry as Dictionary).get("display_name", "")).strip_edges()
		if display.is_empty():
			display = str((entry as Dictionary).get("npc_type", "Enemy"))
		if not counts.has(display):
			counts[display] = 0
			order.append(display)
		counts[display] = int(counts[display]) + 1
	if order.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for display in order:
		var template := TranslationServer.translate("battle.encounter.unit_count")
		parts.append(template % [int(counts[display]), display])
	return ", ".join(parts)


## Collect enemy levels from roster entries (stats.level, default 1).
static func enemy_levels_from_roster(roster: Array) -> Array:
	var levels: Array = []
	for entry in roster:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stats: Variant = (entry as Dictionary).get("stats", {})
		var lvl := 1
		if stats is Dictionary:
			lvl = maxi(1, int((stats as Dictionary).get("level", 1)))
		levels.append(lvl)
	if levels.is_empty():
		levels.append(1)
	return levels


## Local party leader level (fallback 1).
static func player_level_from_party() -> int:
	if PlayerPartyState == null:
		return 1
	var members: Array = PlayerPartyState.get_members() if PlayerPartyState.has_method("get_members") else []
	if members.is_empty() and PlayerPartyState.get("party_data") is Dictionary:
		members = (PlayerPartyState.party_data as Dictionary).get("members", [])
	if members.is_empty():
		return 1
	var leader: Variant = members[0]
	if typeof(leader) != TYPE_DICTIONARY:
		return 1
	var stats: Variant = (leader as Dictionary).get("stats", {})
	if stats is Dictionary:
		return maxi(1, int((stats as Dictionary).get("level", 1)))
	return 1


static func _max_level(levels: Array) -> int:
	var best := 1
	for v in levels:
		best = maxi(best, int(v))
	return best
