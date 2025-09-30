class_name NPCContainer
extends Node

var npc_scene := preload("res://scenes/characters/npc_character.tscn")

func _ready() -> void:
	pass

func register_level(level: Node, npc_information: Dictionary) -> void:
	var defs = level.npc_spawn_definition
	if defs == null: 
		push_error("No NPCSpawnDefinition node found in biom %s" % level.name)
		return 
	
	for key in npc_information.keys(): 
		var def = npc_information[key]
		var node = defs.get_node_or_null(key)
		
		if node == null:
			push_warning("Spawn Node %s not found in %s" % [key, level.name])
			continue
		
		var count = def.get("count", 1)
		var npc_type = def.get("type", "generic")
		
		for i in range(count):
			if node is Path2D:
				_spawn_npc_at_path(node, npc_type)
			elif node is Area2D:
				_spawn_npc_at_area(node, npc_type)
			else:
				push_warning("Unsupported spawn node type: %s" % node)
		


func _spawn_npc_at_path(path: Path2D, npc_type: String) -> void: 
	var follower = path.get_node('PathFollow2D')
	if follower == null:
		push_warning("No PathFollow2D under %s" % path.name)
		return
	
	var npc = npc_scene.instantiate()
	follower.add_child(npc)
	#TODO: NPC-Spezifikation anhand von npc_type setzen
	print("Spawned %s on path %s" % [npc_type, path.name])
	

func _spawn_npc_at_area(node: Node, npc_type: String) -> void:
	pass 
