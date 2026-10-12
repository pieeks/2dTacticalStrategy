class_name BattleEnemy
extends Node2D
## Lightweight fight enemy visual: appearance + name label. Moved by turn AI via unit.node.

@onready var appearance: Node2D = $CharacterAppearance
@onready var name_label: Label = $NameLabel


## Apply roster/meta data and visuals for this enemy unit.
func setup(npc_type: String, display_name: String, stats: Dictionary, appearance_data: Dictionary) -> void:
	set_meta("npc_type", npc_type)
	set_meta("npc_name", display_name)
	set_meta("stats", stats.duplicate(true) if not stats.is_empty() else {})
	if name_label == null:
		name_label = get_node_or_null("NameLabel") as Label
	if name_label != null:
		name_label.text = display_name if display_name != "" else "Enemy"
	if appearance == null:
		appearance = get_node_or_null("CharacterAppearance") as Node2D
	if appearance == null:
		return
	if not appearance_data.is_empty() and appearance.has_method("apply_full_data"):
		appearance.call_deferred("apply_full_data", appearance_data)
	if appearance.has_method("play"):
		appearance.call_deferred("play", "idle_front")
