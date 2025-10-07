extends Node2D

var npc_information: Dictionary = {
	"TestPath": {"count": 1, "type": "slime_basic"},
	"TestSpawnArea": {"count": 4, "type": "slime_basic"}
}

var npc_spawn_definition: Node

signal level_ready(npc_spawn_definition: Node, npc_information: Dictionary)

func _ready() -> void:
	npc_spawn_definition = $NPCSpawnDefinition
	emit_signal("level_ready", self, npc_information)
