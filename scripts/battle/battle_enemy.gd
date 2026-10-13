class_name BattleEnemy
extends Node2D
## Lightweight fight enemy visual: appearance + name label. Moved by turn AI via unit.node.

## Greyed but still readable — must not sink behind the grid (z_index).
const CORPSE_MODULATE := Color(0.62, 0.62, 0.7, 0.95)

@onready var appearance: Node2D = $CharacterAppearance
@onready var name_label: Label = $NameLabel

## True after HP hits 0 — corpse stays visible but does not act / block (via BattleUnit.hp).
var is_corpse: bool = false


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
	# Defer once so CharacterAppearance._ready finished; apply then battle idle together.
	call_deferred("_apply_battle_appearance", appearance_data.duplicate(true))


## Apply roster appearance then battle idle (weapons only if equipped in data).
func _apply_battle_appearance(appearance_data: Dictionary) -> void:
	if appearance == null:
		appearance = get_node_or_null("CharacterAppearance") as Node2D
	if appearance == null:
		return
	if not appearance_data.is_empty() and appearance.has_method("apply_full_data"):
		appearance.apply_full_data(appearance_data)
	if appearance.has_method("play"):
		appearance.play("idle_front_battle", 1.0, true)


## Death clip (or freeze) + downed look. Idempotent; stays on the cell as a visible corpse.
func play_death() -> void:
	if is_corpse:
		refresh_corpse_modulate()
		return
	is_corpse = true
	set_meta("is_corpse", true)
	if appearance == null:
		appearance = get_node_or_null("CharacterAppearance") as Node2D
	if appearance != null and appearance.has_method("play_death"):
		appearance.play_death("front")
	# Tip over slightly — keep size readable (small races vanish if squashed hard).
	if appearance != null:
		appearance.rotation = deg_to_rad(70.0)
		appearance.position = Vector2(4.0, 6.0)
		appearance.modulate = Color(0.85, 0.85, 0.9, 1.0)
	# Keep above grid tiles so the corpse does not "turn off" under the map.
	z_index = 1
	refresh_corpse_modulate()
	if name_label == null:
		name_label = get_node_or_null("NameLabel") as Label
	if name_label != null:
		name_label.modulate = Color(0.9, 0.75, 0.75, 1.0)
		name_label.position.y = -42.0


## Re-apply corpse tint (e.g. after hit-flash tween restores modulate).
func refresh_corpse_modulate() -> void:
	modulate = CORPSE_MODULATE
	visible = true
