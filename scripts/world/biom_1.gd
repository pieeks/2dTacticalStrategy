
class_name Biom1
extends LevelLoadManager

# Die Definition, was wo gespawnt wird.
# Diese wird für jedes Level (Biom, Dungeon etc.) einzigartig sein.
@export var level_npc_spawn_information: Dictionary = {
	"TestPath": {"count": 1, "type": "test_npc_basic"},
	"TestSpawnArea": {"count": 4, "type": "slime_basic"}
}


signal level_ready


func _ready() -> void:
	npc_spawn_information = level_npc_spawn_information
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
