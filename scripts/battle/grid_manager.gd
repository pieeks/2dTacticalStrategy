class_name GridManager
extends Node2D
## Hex-Grid (AStar2D), Pfadfindung, Reachable-Set und Highlights.

@export_group("Grid Settings")
@export var width: int = 18:
	set(v):
		width = v
		if is_inside_tree():
			setup_grid()
@export var height: int = 14:
	set(v):
		height = v
		if is_inside_tree():
			setup_grid()
@export var spacing: float = 40.0:
	set(v):
		spacing = v
		if is_inside_tree():
			setup_grid()
## Visual inset so hex outlines leave ~1–2 px gap (does not affect A* spacing).
@export var hex_gap_px: float = 2.0

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


func set_move_highlights(positions: PackedVector2Array, _origin_world: Vector2 = Vector2.INF) -> void:
	_highlight_move = positions
	queue_redraw()


func set_attack_highlights(positions: PackedVector2Array) -> void:
	_highlight_attack = positions
	queue_redraw()


func clear_action_highlights() -> void:
	_highlight_move = PackedVector2Array()
	_highlight_attack = PackedVector2Array()
	queue_redraw()


## Flat-top hex radius with a small visual gap to neighbors (layout spacing unchanged).
func _hex_radius() -> float:
	var gap := maxf(hex_gap_px, 0.0)
	# Vertical neighbors are closer (spacing * 0.75) — that limits radius first.
	var max_from_vert := (spacing * 0.75 - gap) / sqrt(3.0)
	var max_from_horiz := spacing * 0.5 - gap * 0.5
	return maxf(mini(max_from_vert, max_from_horiz), 1.0)


## Six flat-top vertices around a local cell center.
func _hex_polygon(center: Vector2, radius: float = -1.0) -> PackedVector2Array:
	var r := radius if radius > 0.0 else _hex_radius()
	var pts := PackedVector2Array()
	for i in 6:
		var angle := TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	return pts


func _draw_hex(
	center: Vector2,
	fill: Color,
	outline: Color,
	outline_width: float = 1.5,
	radius: float = -1.0
) -> void:
	var pts := _hex_polygon(center, radius)
	if fill.a > 0.001:
		draw_colored_polygon(pts, fill)
	if outline.a > 0.001:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, outline, outline_width, true)


func _draw() -> void:
	if not astar:
		return
	var r := _hex_radius()
	# Base field: hex outline per cell (no debug dots / full connection mesh).
	for id in astar.get_point_ids():
		_draw_hex(
			astar.get_point_position(id),
			Color(0.15, 0.35, 0.55, 0.08),
			Color(0.55, 0.75, 0.95, 0.35),
			1.0,
			r
		)
	# Move-reachable: green hexes only (path links stay on yellow hover preview).
	for world_p in _highlight_move:
		_draw_hex(
			to_local(world_p),
			Color(0.1, 0.95, 0.35, 0.28),
			Color(0.25, 1.0, 0.45, 0.9),
			2.0,
			r
		)
	# Attack targets: red hexes (no link mesh).
	for world_p in _highlight_attack:
		_draw_hex(
			to_local(world_p),
			Color(0.95, 0.2, 0.15, 0.32),
			Color(1.0, 0.35, 0.25, 0.95),
			2.0,
			r
		)
	# Hover path preview (unchanged feel: path line + waypoints).
	if _preview_path.size() > 0:
		for i in range(_preview_path.size()):
			var local_p := to_local(_preview_path[i])
			_draw_hex(
				local_p,
				Color(1.0, 0.9, 0.15, 0.22),
				Color(1.0, 0.85, 0.2, 0.95),
				2.0,
				r * 0.92
			)
			if i + 1 < _preview_path.size():
				draw_line(
					local_p,
					to_local(_preview_path[i + 1]),
					Color(1.0, 0.85, 0.2, 0.9),
					3.0,
					true
				)
