class_name NpcSpecification
extends NPCController

const NpcArchetypeScript := preload("res://scripts/characters/npc_archetype.gd")

@onready var appearance: CharacterAppearance = $"../CharacterAppearance"

@export var npc_type: String

var npc_count: int
var npc_name: String
var npc_appearance: Dictionary
var npc_stats: Dictionary
var npc_loot: Dictionary
var npc_is_hostile: bool = false
var npc_group_size: int = 1
## Optional reusable encounter composition id (`resources/encounters/<id>.json`).
var npc_encounter_id: String = ""
## Optional inline composition units: [{ "npc_type", "count" }, ...].
var npc_encounter_units: Array = []
var npc_quests: Dictionary = {}

func _ready() -> void:
	pass


func set_specifical_nodes() -> void: 
	$"..".name = npc_name + "_" + str(npc_count)
	if npc_is_hostile == true: 
		var aggro_shape_2d := preload("res://scenes/characters/npc_specifications/aggro_area_2d.tscn")
		var aggro_node := aggro_shape_2d.instantiate()
		var force_fight_shape_2d := preload("res://scenes/characters/npc_specifications/force_fight_area_2d.tscn")
		var force_fight_node := force_fight_shape_2d.instantiate()
		var aggro_controller := preload("res://scenes/characters/npc_specifications/aggro_controller.tscn")
		var aggro_controller_node := aggro_controller.instantiate()
		
		$"..".add_child(aggro_node)
		$"..".add_child(force_fight_node)
		$"..".set_force_fight_area(force_fight_node)
		$"..".add_child(aggro_controller_node)
	
	if npc_appearance.size() > 0 and appearance != null and appearance.has_method("apply_full_data"):
		appearance.apply_full_data(npc_appearance)


func load_npc_enemy_data(type: String, count: int) -> void:
	npc_type = type
	npc_count = (count + 1)
	var parsed := NpcArchetypeScript.load_type(npc_type)
	if parsed.is_empty():
		push_error("NpcSpecification: missing or invalid archetype for npc_type=%s" % npc_type)
		return
	
	npc_name = str(parsed.get("name", ""))
	npc_appearance = parsed.get("appearance", {}) if parsed.get("appearance", {}) is Dictionary else {}
	npc_stats = parsed.get("stats", {}) if parsed.get("stats", {}) is Dictionary else {}
	npc_loot = parsed.get("loot", {}) if parsed.get("loot", {}) is Dictionary else {}
	npc_is_hostile = bool(parsed.get("is_hostile", false))
	npc_group_size = maxi(1, int(parsed.get("group_size", 1)))
	npc_encounter_id = str(parsed.get("encounter_id", "")).strip_edges()
	npc_encounter_units = []
	var encounter_block: Variant = parsed.get("encounter", {})
	if encounter_block is Dictionary:
		var enc_dict: Dictionary = encounter_block as Dictionary
		if npc_encounter_id.is_empty():
			npc_encounter_id = str(enc_dict.get("id", "")).strip_edges()
		var enc_units: Variant = enc_dict.get("units", [])
		if enc_units is Array:
			npc_encounter_units = (enc_units as Array).duplicate(true)
	var top_units: Variant = parsed.get("units", [])
	if npc_encounter_units.is_empty() and top_units is Array:
		npc_encounter_units = (top_units as Array).duplicate(true)
	var quests_raw = parsed.get("quests", {})
	npc_quests = quests_raw if typeof(quests_raw) == TYPE_DICTIONARY else {}
	
	set_specifical_nodes()
	_publish_npc_data_to_owner()


## Fill parent NPCCharacter.npc_data for interaction / quests.
func _publish_npc_data_to_owner() -> void:
	var owner_npc := get_parent()
	if owner_npc == null:
		return
	if "npc_data" in owner_npc:
		owner_npc.npc_data = {
			"name": npc_name,
			"npc_type": npc_type,
			"quests": npc_quests.duplicate(true),
			"is_hostile": npc_is_hostile,
		}
