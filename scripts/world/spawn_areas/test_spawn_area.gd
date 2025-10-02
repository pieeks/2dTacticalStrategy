extends Area2D


var spwan_count: int
var npc_type: String

func set_patrol_points(npc: NPCCharacter, poly: Polygon2D) -> NPCCharacter: 
	var points = poly.polygon
	if points.size() < 3:
		return npc
	
	# Zufälligen Punkt im Polygon wählen
	var local_point = points[randi() % points.size()]
	
	# Lokale → globale Position umwandeln
	var global_point = poly.to_global(local_point)
	
	npc.global_position = global_point
	return npc
