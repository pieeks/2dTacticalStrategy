extends Area2D


var spwan_count: int
var npc_type: String

func set_patrol_points(path2D: Path2D, poly: CollisionPolygon2D) -> Path2D: 
	var points = poly.polygon
	if points.size() < 3:
		return path2D
	
	var local_point = points[randi() % points.size()]
	var global_point = poly.to_global(local_point)
	
	var curve = Curve2D.new()
	
	curve.add_point(_create_random_marker_point(poly, global_point))
	
	var number_of_spawn_points = randi_range(1, 3)
	for i in range(number_of_spawn_points):
		var last_index = curve.get_point_count() - 1 
		curve.add_point(_create_random_marker_point(poly, curve.get_point_position(last_index)))
	
	path2D.curve = curve
	return path2D

func _create_random_marker_point(poly: CollisionPolygon2D, spawn_point: Vector2) -> Vector2:
	var polygon_local: PackedVector2Array = poly.polygon
	if polygon_local.size() < 3:
		return spawn_point  # fallback
	
	# bounding box berechnen
	var rect := _polygon_bounding_rect(polygon_local)
	
	var tries := 0
	while tries < 200: # max. 200 Versuche
		tries += 1
		var p_local = Vector2(
			randf_range(rect.position.x, rect.position.x + rect.size.x),
			randf_range(rect.position.y, rect.position.y + rect.size.y)
		)
		if Geometry2D.is_point_in_polygon(p_local, polygon_local):
			var p_global = poly.to_global(p_local)
			if p_global.distance_to(spawn_point) <= 400.0:
				return p_global
	
	# Fallback: spawn_point zurückgeben
	return spawn_point


# Hilfsfunktion: BoundingRect eines Polygons
func _polygon_bounding_rect(points: PackedVector2Array) -> Rect2:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for p in points:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
