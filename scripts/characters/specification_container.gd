class_name NpcSpecification
extends NPCController

@onready var appearance: CharacterAppearance = $"../CharacterAppearance"

@export var npc_type: String

var base_eneymy_path: String = "res://resources/enemy/"

var npc_name: String
var npc_appearance: Dictionary
var npc_stats: Array
var npc_loot: Array
var npc_sync: Dictionary

func _ready() -> void:
	pass


func set_specifical_nodes() -> void: 
	if npc_sync.get("isActive") == true: 
		var sync := preload("res://scenes/characters/npc_specifications/npc_sync.tscn")
		var syncNode := sync.instantiate()
		$".".add_child(syncNode)
	
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


func load_npc_enemy_data(type: String) -> void:
	npc_type = type
	base_eneymy_path = base_eneymy_path + npc_type + ".json"
	if not FileAccess.file_exists(base_eneymy_path):
		push_error("No save found at: " + base_eneymy_path)
	
	var file := FileAccess.open(base_eneymy_path, FileAccess.READ)
	if file == null: 
		push_error("Could not open file: " + base_eneymy_path)
	
	var txt = file.get_as_text()
	file.close()
	
	var parsed := JSON.parse_string(txt) as Dictionary
	if typeof(parsed) != TYPE_DICTIONARY: 
		push_error("Save file invalid or corrupted: " + base_eneymy_path)
	
	npc_name = parsed.get("name")
	npc_appearance = parsed.get("appearance")
	npc_stats = parsed.get("stats")
	npc_loot = parsed.get("loot")
	npc_sync = parsed.get("sync")
	
	set_specifical_nodes()
