# Biom.gd (Finale, wiederverwendbare Version)
extends Node2D

# Die Definition, was wo gespawnt wird.
# Diese wird für jedes Level (Biom, Dungeon etc.) einzigartig sein.
@export var npc_spawn_information: Dictionary = {
	"TestPath": {"count": 1, "type": "test_npc_basic"},
	"TestSpawnArea": {"count": 4, "type": "slime_basic"}
}
@export var modular_npc_scene: PackedScene

@onready var multiplayer_spawner: MultiplayerSpawner = $NPCSpawner
@onready var spawn_definitions_node: Node = $NPCSpawnDefinition

var players_container: Node

signal level_ready


func _ready() -> void:
	multiplayer_spawner.spawn_function = _spawn_npc_function
	
	if not multiplayer.is_server(): 
		return
	
	spawn_all_npcs()
	emit_signal("level_ready")


func _spawn_npc_function(data: Dictionary) -> Node:
	if modular_npc_scene == null:
		push_error("Spawn-Funktion aufgerufen, aber keine 'modular_npc_scene' im Biom zugewiesen!")
		return null

	var npc_instance = modular_npc_scene.instantiate()
	npc_instance.initialize_npc(data)
	return npc_instance


func initialize_level_for_players(p_container: Node):
	self.players_container = p_container
	
	# Nur der Host soll die Signale verbinden.
	if not multiplayer.is_server():
		return
		
	# Verbinde die Signale für Spieler, die bereits da sind.
	for player in players_container.get_children():
		connect_player_activation_signals(player)
		
	# Lausche auf neue Spieler.
	players_container.child_entered_tree.connect(connect_player_activation_signals)


# Verbindet die Host-Logik mit den Signalen der Spieler-Aktivierungs-Blase.
func connect_player_activation_signals(player_node: Node):
	if not player_node.has_node("ActivationArea"):
		push_warning("Spieler %s hat keine ActivationArea!" % player_node.name)
		return
		
	var activation_area = player_node.get_node("ActivationArea")
	
	# Wir verbinden uns mit den sauberen, vordefinierten Signalen aus dem ActivationArea.gd Skript.
	activation_area.connect("enter_activation_area", _on_npc_entered_player_activation_area)
	activation_area.connect("exit_activation_area", _on_npc_exited_activation_area)


func _on_npc_entered_player_activation_area(npc_body: NPCCharacter) -> void:
	npc_body.wake_up()


func _on_npc_exited_activation_area(npc_body: NPCCharacter) -> void:
	npc_body.go_to_sleep()


func spawn_all_npcs() -> void:
	if modular_npc_scene == null:
		push_error("Im Biom-Skript wurde keine 'modular_npc_scene' zugewiesen!")
		return
	# Gehe durch die Spawn-Definitionen
	for spawn_node_name in npc_spawn_information:
		var spawn_info: Dictionary = npc_spawn_information[spawn_node_name]
		var spawn_node: Node = spawn_definitions_node.get_node_or_null(spawn_node_name)
		
		if spawn_node == null:
			push_warning("Spawn-Node '%s' nicht gefunden!" % spawn_node_name)
			continue
			
		var count: int = spawn_info.get("count", 1)
		var npc_type: String = spawn_info.get("type", "generic_enemy")
		
		# Spawne die angegebene Anzahl von NPCs
		for i in range(count):
			var custom_data: Dictionary = { 
				"npc_type": npc_type,
				"spawn_index": i
				}
			var patrol_points: Array[Vector2] = []
			
			# --- Intelligente Datensammlung basierend auf dem Node-Typ ---
			if spawn_node is Path2D:
				var path_follower = PathFollow2D.new()
				path_follower.loop = false
				
				custom_data["patrol_behavior"] = NPCCharacter.PatrolBehavior.FOLLOW_PATH
				custom_data["initial_position"] = spawn_node.curve.get_point_position(0)
				
				var npc_instance = multiplayer_spawner.spawn(custom_data)
				
				spawn_node.add_child(path_follower)
				npc_instance.path_follower = path_follower
				
				
			elif spawn_node is Area2D:
				# 1. Lasse die Area die Punkte für uns generieren
				if spawn_node.has_method("generate_patrol_points"):
					patrol_points = spawn_node.generate_patrol_points(4) # z.B. 4 Punkte
				# 2. Weise das korrekte Verhalten zu
				custom_data["patrol_behavior"] = NPCCharacter.PatrolBehavior.PING_PONG
			
				# --- Bündelung der Daten ---
				if not patrol_points.is_empty():
					custom_data["initial_position"] = patrol_points[0]
					custom_data["patrol_points"] = patrol_points
				else:
					# Fallback, falls keine Punkte gefunden wurden, spawne am Node selbst
					custom_data["initial_position"] = spawn_node.global_position
					
				multiplayer_spawner.spawn(custom_data)
