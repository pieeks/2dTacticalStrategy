class_name NpcSpecification
extends NPCController

@onready var appearance: CharacterAppearance = $"../CharacterAppearance"

@export var npc_type: String

var base_npc_path: String = "res://resources/npcs/"

var npc_count: int
var npc_name: String
var npc_appearance: Dictionary
var npc_stats: Dictionary
var npc_loot: Dictionary
var npc_sync: Dictionary
var npc_is_hostile: bool = false

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
	
	if NetworkManagerTest.is_host == true: 
		if npc_sync.get("isActive") == true: 
			var sync := preload("res://scenes/characters/npc_specifications/npc_sync.tscn")
			var syncNode := sync.instantiate()
			$".".add_child(syncNode)
			$"..".set_npc_sync(syncNode)
	
	if npc_appearance.size() > 0: 
		if npc_appearance.has("race_path"):
			appearance.set_race(npc_appearance["race_path"])
		else:
			appearance.get_node("Race2DSprite").visible = false
		
		if npc_appearance.has("hair_path"):
			appearance.set_hair(npc_appearance["hair_path"])
		else: 
			appearance.get_node("Hair2DSprite").visible = false
		
		if npc_appearance.has("body_path"):
			appearance.set_body(npc_appearance["body_path"])
		else:
			appearance.get_node("Body2DSprite").visible = false
		
		if npc_appearance.has("leg_path"):
			appearance.set_leg(npc_appearance["leg_path"])
		else: 
			appearance.get_node("Leg2DSprite").visible = false


func load_npc_enemy_data(type: String, count: int) -> void:
	npc_type = type
	npc_count = (count + 1)
	base_npc_path = base_npc_path + npc_type + ".json"
	if not FileAccess.file_exists(base_npc_path):
		push_error("No save found at: " + base_npc_path)
	
	var file := FileAccess.open(base_npc_path, FileAccess.READ)
	if file == null: 
		push_error("Could not open file: " + base_npc_path)
	
	var txt = file.get_as_text()
	file.close()
	
	var parsed := JSON.parse_string(txt) as Dictionary
	if typeof(parsed) != TYPE_DICTIONARY: 
		push_error("Save file invalid or corrupted: " + base_npc_path)
	
	npc_name = parsed.get("name", "")
	npc_appearance = parsed.get("appearance", {})
	npc_stats = parsed.get("stats", {})
	npc_loot = parsed.get("loot", {})
	npc_sync = parsed.get("sync", {})
	npc_is_hostile = parsed.get("is_hostile", false)
	
	set_specifical_nodes()
