extends Node2D

var npc_information: Dictionary = {
	"TestPath": {"count": 1},
	"TestSpawnArea": {"count": 2}
}

var npc_spawn_definition: Node

signal level_ready(npc_spawn_definition: Node, npc_information: Dictionary)

func _ready() -> void:
	npc_spawn_definition = $NPCSpawnDefinition
	emit_signal("level_ready", self, npc_information)
