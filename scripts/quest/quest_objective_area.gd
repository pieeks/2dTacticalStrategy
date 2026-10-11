extends Area2D

## Quest reach objective trigger. Credits local player only.

@export var objective_target_id: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = false


func _on_body_entered(body: Node2D) -> void:
	if objective_target_id.is_empty():
		return
	if body == null or not body.is_in_group("Players"):
		return
	if not body.is_multiplayer_authority():
		return
	var qm := get_tree().root.get_node_or_null("QuestManager")
	if qm == null:
		return
	qm.report_progress({
		"type": "reach",
		"target": objective_target_id,
		"amount": 1,
	})
