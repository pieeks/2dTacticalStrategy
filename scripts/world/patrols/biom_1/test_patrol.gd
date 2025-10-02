extends PathFollow2D

@export var speed: float = 60.0            ## Geschwindigkeit in Pixel pro Sekunde
@export var pause_time: float = 2.0        ## Pause an Endpunkten

var npc: NPCCharacter
var curve: Curve2D
var current_index: int = 0
var direction: int = 1
var pause_timer: float = 0.0
var points: Array[Vector2] = []

func _ready() -> void:
	var path := get_parent() as Path2D
	if path and path.curve:
		curve = path.curve
		for i in range(curve.point_count):
			points.append(curve.get_point_position(i))
	
	if points.is_empty():
		push_error("PathPatrol: Keine Punkte im Pfad gefunden!")

func _process(delta: float) -> void:
	# NPC cachen, sobald er existiert
	if npc == null and get_child_count() > 0:
		npc = get_child(0) as NPCCharacter
		print("NPC assigned to patrol:", npc.name)
	
	if npc == null or points.size() < 2:
		return
	
	# Pausenlogik
	if pause_timer > 0.0:
		pause_timer -= delta
		if npc.state_machine:
			npc.state_machine.transition_to("IdleNPC")
		return
	
	var target_index = current_index + direction
	if target_index < 0 or target_index >= points.size():
		# Am Ende angekommen → Richtung wechseln
		direction *= -1
		pause_timer = pause_time
		if npc.state_machine:
			npc.state_machine.transition_to("IdleNPC")
		return
	
	# Bewegung zum nächsten Punkt
	var target_pos = get_parent().to_global(points[target_index])
	var move_vec = target_pos - npc.global_position
	var dist = move_vec.length()
	
	if dist < speed * delta:
		# Punkt erreicht
		npc.global_position = target_pos
		current_index = target_index
	
		# Wenn es einen nächsten Punkt gibt → Richtung/Animation aktualisieren
		var next_target = current_index + direction
		if next_target >= 0 and next_target < points.size():
			_update_npc_direction(points[next_target] - points[current_index])
	else:
		# Normale Bewegung
		var step = move_vec.normalized() * speed * delta
		npc.global_position += step
		_update_npc_direction(move_vec)


func _update_npc_direction(dir: Vector2) -> void:
	if npc == null:
		return
	
	npc.net_facing = dir.normalized()
	#print("Facing:", npc.net_facing)
	
	if dir.length() > 0.1:
		if npc.state_machine:
			npc.state_machine.transition_to("WalkNPC")
	else:
		if npc.state_machine:
			npc.state_machine.transition_to("IdleNPC")
