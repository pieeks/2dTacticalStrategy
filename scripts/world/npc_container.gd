class_name NPCContainer
extends Node

var npc_scene := preload("res://scenes/characters/npc_character.tscn")

var patrol_counter: int = 0

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
	var follower = path.get_node('PathFollow2D') as PathFollow2D
	if follower == null:
		push_warning("No PathFollow2D under %s" % path.name)
		return
	
	var npc = npc_scene.instantiate()
	follower.add_child(npc)
	npc.specification.load_npc_enemy_data(npc_type)
	
	print("Spawned %s on path %s" % [npc_type, path.name])
	


func _spawn_npc_at_area(area: Area2D, npc_type: String) -> void:
	if area == null:
		push_warning("No Area2D under %s" % area.name)
		return
	
	var poly = area.get_node("CollisionPolygon2D") as CollisionPolygon2D
	if poly == null: 
		push_warning("No CollisionPolygon2D under %s" % area.name)
		return
	
	var patrol = Path2D.new()
	patrol.name = area.name + "Patrol" + str(patrol_counter)
	patrol_counter = patrol_counter + 1
	
	var followNode = PathFollow2D.new()
	var script := load("res://scripts/world/patrols/biom_1/test_patrol.gd")
	var npc = npc_scene.instantiate()
	
	followNode.add_child(npc)
	followNode.set_script(script)
	followNode.rotates = false
	patrol.add_child(followNode)
	
	patrol = area.set_patrol_points(patrol, poly)
	$".".add_child(patrol)
	npc.specification.load_npc_enemy_data(npc_type)
	
	print("Spawned %s on path %s" % [npc_type, area.name])
