class_name GridManager
extends Node2D
## Hex-Grid (AStar2D), Pfadfindung, Reachable-Set und Highlights.

@export_group("Grid Settings")
@export var width: int = 10:
	set(v):
		width = v
		if is_inside_tree():
			setup_grid()
@export var height: int = 8:
	set(v):
		height = v
		if is_inside_tree():
			setup_grid()
@export var spacing: float = 40.0:
	set(v):
		spacing = v
		if is_inside_tree():
			setup_grid()

var astar := AStar2D.new()
var _preview_path: PackedVector2Array = PackedVector2Array()
var _highlight_move: PackedVector2Array = PackedVector2Array()
var _highlight_attack: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	setup_grid()


func setup_grid() -> void:
	astar.clear()
	var points_dict: Dictionary = {}
	var id := 0
	for y in height:
		for x in width:
			var grid_pos := Vector2i(x, y)
			var pos := Vector2(x * spacing, y * spacing * 0.75)
			if y % 2 == 1:
				pos.x += spacing / 2.0
			astar.add_point(id, pos)
			points_dict[grid_pos] = id
			id += 1
	for y in height:
		for x in width:
			var current_id: int = points_dict[Vector2i(x, y)]
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


func get_point_id_at_world(world_pos: Vector2) -> int:
	if astar.get_point_count() == 0:
		return -1
	return astar.get_closest_point(to_local(world_pos))


func get_snap_global_position(world_pos: Vector2) -> Vector2:
	var closest_id := get_point_id_at_world(world_pos)
	if closest_id < 0:
		return world_pos
	return to_global(astar.get_point_position(closest_id))


func get_action_path(start_world_pos: Vector2, target_world_pos: Vector2) -> PackedVector2Array:
	var start_id := get_point_id_at_world(start_world_pos)
	var target_id := get_point_id_at_world(target_world_pos)
	if start_id < 0 or target_id < 0:
		return PackedVector2Array()
	var local_path: PackedVector2Array = astar.get_point_path(start_id, target_id)
	var world_path := PackedVector2Array()
	for p in local_path:
		world_path.append(to_global(p))
	return world_path


## Hex steps along A* path (path points - 1). Same cell => 0.
func get_path_step_count(start_world_pos: Vector2, target_world_pos: Vector2) -> int:
	var path := get_action_path(start_world_pos, target_world_pos)
	if path.size() <= 1:
		return 0
	return path.size() - 1


## BFS reachable world positions within max_steps. blocked_point_ids cannot be entered (start ok).
func get_reachable_positions(
	start_world_pos: Vector2, max_steps: int, blocked_point_ids: Array = []
) -> PackedVector2Array:
	var start_id := get_point_id_at_world(start_world_pos)
	if start_id < 0 or max_steps < 0:
		return PackedVector2Array()
	var blocked: Dictionary = {}
	for bid in blocked_point_ids:
		blocked[int(bid)] = true
	var dist: Dictionary = {start_id: 0}
	var queue: Array[int] = [start_id]
	var qi := 0
	while qi < queue.size():
		var current: int = queue[qi]
		qi += 1
		var d: int = int(dist[current])
		if d >= max_steps:
			continue
		for nid in astar.get_point_connections(current):
			var next_id: int = int(nid)
			if blocked.has(next_id) and next_id != start_id:
				continue
			if dist.has(next_id):
				continue
			dist[next_id] = d + 1
			queue.append(next_id)
	var result := PackedVector2Array()
	for pid in dist.keys():
		if int(pid) == start_id:
			continue
		result.append(to_global(astar.get_point_position(int(pid))))
	return result


func set_preview_path(path: PackedVector2Array) -> void:
	_preview_path = path
	queue_redraw()


func clear_preview_path() -> void:
	_preview_path = PackedVector2Array()
	queue_redraw()


func set_move_highlights(positions: PackedVector2Array) -> void:
	_highlight_move = positions
	queue_redraw()


func set_attack_highlights(positions: PackedVector2Array) -> void:
	_highlight_attack = positions
	queue_redraw()


func clear_action_highlights() -> void:
	_highlight_move = PackedVector2Array()
	_highlight_attack = PackedVector2Array()
	queue_redraw()


func _draw() -> void:
	if not astar:
		return
	for id in astar.get_point_ids():
		var pos := astar.get_point_position(id)
		draw_circle(pos, 3.0, Color.CYAN)
		for connection_id in astar.get_point_connections(id):
			var target_pos := astar.get_point_position(connection_id)
			draw_line(pos, target_pos, Color(1, 1, 1, 0.1), 1.0)
	for world_p in _highlight_move:
		var lp := to_local(world_p)
		draw_circle(lp, 14.0, Color(0.1, 0.95, 0.35, 0.35))
		draw_circle(lp, 7.0, Color(0.2, 1.0, 0.4, 0.75))
	for world_p in _highlight_attack:
		var ap := to_local(world_p)
		draw_circle(ap, 14.0, Color(0.95, 0.2, 0.15, 0.4))
		draw_circle(ap, 8.0, Color(1.0, 0.3, 0.2, 0.8))
	if _preview_path.size() > 0:
		for i in range(_preview_path.size()):
			var world_p: Vector2 = _preview_path[i]
			var local_p := to_local(world_p)
			draw_circle(local_p, 6.0, Color(1.0, 0.9, 0.15, 0.95))
			if i + 1 < _preview_path.size():
				draw_line(local_p, to_local(_preview_path[i + 1]), Color(1.0, 0.85, 0.2, 0.85), 3.0)
