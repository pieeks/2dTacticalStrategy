
extends Area2D

## generate_patrol_points
##
## Die einzige öffentliche Funktion dieses Skripts.
## Sie wird vom Biom-Skript aufgerufen, um eine Liste
## von zufälligen Patrouillenpunkten innerhalb dieser Area zu erhalten.
##
## @param num_points int: Die Anzahl der zu generierenden Punkte.
## @return Array[Vector2]: Eine Liste von globalen Weltkoordinaten.
func generate_patrol_points(num_points: int) -> Array[Vector2]:
	var points_array: Array[Vector2] = []
	
	# Finde den CollisionPolygon2D-Node, egal wie er heißt.
	var poly = find_child("CollisionPolygon2D") as CollisionPolygon2D
	if not poly:
		push_error("Kein CollisionPolygon2D als Kind von '%s' gefunden!" % self.name)
		return points_array # Gib ein leeres Array zurück, um Abstürze zu vermeiden.
		
	# Generiere die gewünschte Anzahl von Punkten.
	for i in range(num_points):
		var random_point = _get_random_point_in_polygon(poly)
		points_array.append(random_point)
		
	return points_array


## _get_random_point_in_polygon
##
## Private Hilfsfunktion, um einen einzelnen, validen, zufälligen Punkt
## innerhalb der Grenzen des Polygons zu finden.
##
## @param poly CollisionPolygon2D: Der Polygon-Node, in dem gesucht wird.
## @return Vector2: Eine einzelne globale Weltkoordinate.
func _get_random_point_in_polygon(poly: CollisionPolygon2D) -> Vector2:
	var polygon_local: PackedVector2Array = poly.polygon
	if polygon_local.size() < 3:
		return poly.global_position # Fallback, falls Polygon ungültig ist.
	
	# Berechne die Bounding Box für eine effiziente Suche.
	var rect := _polygon_bounding_rect(polygon_local)
	
	var tries := 0
	while tries < 100: # Max. 100 Versuche, um einen Punkt zu finden.
		tries += 1
		# Erstelle einen zufälligen Punkt innerhalb der Bounding Box.
		var p_local = Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		)
		# Prüfe, ob der Punkt wirklich innerhalb des (nicht-rechteckigen) Polygons liegt.
		if Geometry2D.is_point_in_polygon(p_local, polygon_local):
			# Wenn ja, wandle ihn in globale Koordinaten um und gib ihn zurück.
			return poly.to_global(p_local)
	
	# Fallback, falls nach 100 Versuchen kein Punkt gefunden wurde.
	return poly.global_position


## _polygon_bounding_rect
##
## Deine bestehende, gute Hilfsfunktion, um die Bounding Box zu berechnen.
##
## @param points PackedVector2Array: Die Eckpunkte des Polygons.
## @return Rect2: Das umschließende Rechteck.
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
