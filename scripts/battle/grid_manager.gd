class_name GridManager
extends Node2D
## Hex-Grid (AStar2D), Punkte und Nachbarn; [method get_action_path] für Bewegung.

@export_group("Grid Settings")
@export var width: int = 10:
	set(v): width = v; setup_grid()
@export var height: int = 8:
	set(v): height = v; setup_grid()
@export var spacing: float = 40.0:
	set(v): spacing = v; setup_grid()

var astar = AStar2D.new()

func _ready() -> void:
	setup_grid()



func setup_grid() -> void:
	astar.clear()
	var points_dict: Dictionary = {}
	var id := 0
	for y in height:
		for x in width:
			var grid_pos = Vector2i(x, y)
			var pos = Vector2(x * spacing, y * spacing * 0.75)
			if y % 2 == 1:
				pos.x += spacing / 2
				
			astar.add_point(id, pos)
			points_dict[grid_pos] = id
			id += 1
	for y in height:
		for x in width:
			var current_id = points_dict[Vector2i(x, y)]
			var neighbor_coords: Array = []
			if y % 2 == 0:
				neighbor_coords = [
					Vector2i(x, y - 1), Vector2i(x - 1, y - 1),
					Vector2i(x - 1, y), Vector2i(x + 1, y),
					Vector2i(x, y + 1), Vector2i(x - 1, y + 1),
				]
			else:
				neighbor_coords = [
					Vector2i(x, y - 1), Vector2i(x + 1, y - 1),
					Vector2i(x - 1, y), Vector2i(x + 1, y),
					Vector2i(x, y + 1), Vector2i(x + 1, y + 1),
				]
			for n_coord in neighbor_coords:
				if points_dict.has(n_coord):
					astar.connect_points(current_id, points_dict[n_coord])
	
	queue_redraw()


func _draw() -> void:
	if not astar: 
		return
	
	for id in astar.get_point_ids():
		var pos = astar.get_point_position(id)
		draw_circle(pos, 3.0, Color.CYAN)
		
		for connection_id in astar.get_point_connections(id):
			var target_pos = astar.get_point_position(connection_id)
			draw_line(pos, target_pos, Color(1,1,1,0.1), 1.0)


func get_action_path(start_world_pos: Vector2, target_world_pos: Vector2) -> PackedVector2Array:
	var local_start: Vector2 = to_local(start_world_pos)
	var local_target: Vector2 = to_local(target_world_pos)
	var start_id := astar.get_closest_point(local_start)
	var target_id := astar.get_closest_point(local_target)
	var local_path: PackedVector2Array = astar.get_point_path(start_id, target_id)
	var world_path := PackedVector2Array()
	for p in local_path:
		world_path.append(to_global(p))
	
	return world_path
