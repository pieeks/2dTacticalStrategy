extends PanelContainer

## Quest offer / turn-in panel (shared layout).

signal accepted(quest_id: String)
signal declined
signal turned_in(quest_id: String)
signal cancelled

enum Mode { OFFER, TURN_IN }

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")

@onready var title_label: Label = $Margin/VBox/Title
@onready var desc_label: Label = $Margin/VBox/Description
@onready var objective_label: Label = $Margin/VBox/Objective
@onready var reward_label: Label = $Margin/VBox/Reward
@onready var btn_primary: Button = $Margin/VBox/Buttons/Primary
@onready var btn_secondary: Button = $Margin/VBox/Buttons/Secondary

var _quest_id: String = ""
var _mode: Mode = Mode.OFFER


func _ready() -> void:
	visible = false
	btn_primary.pressed.connect(_on_primary_pressed)
	btn_secondary.pressed.connect(_on_secondary_pressed)
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	if visible and _quest_id != "":
		_refresh_texts()


## Show accept layout for a quest offer.
func show_offer(quest_id: String) -> void:
	_quest_id = quest_id
	_mode = Mode.OFFER
	_refresh_texts()
	visible = true


## Show turn-in layout for a ready quest.
func show_turn_in(quest_id: String) -> void:
	_quest_id = quest_id
	_mode = Mode.TURN_IN
	_refresh_texts()
	visible = true


func hide_panel() -> void:
	visible = false
	_quest_id = ""


func _qm() -> Node:
	return get_tree().root.get_node_or_null("QuestManager")


func _refresh_texts() -> void:
	var qm := _qm()
	if qm == null:
		return
	var def: Dictionary = qm.get_definition(_quest_id)
	title_label.text = tr(str(def.get("title_key", _quest_id)))
	desc_label.text = tr(str(def.get("description_key", "")))
	var obj_lines: PackedStringArray = PackedStringArray()
	for obj in def.get("objectives", []):
		if typeof(obj) != TYPE_DICTIONARY:
			continue
		var key := str(obj.get("text_key", ""))
		var line := tr(key) if key != "" else str(obj.get("id", ""))
		obj_lines.append(line)
	objective_label.text = "%s %s" % [tr("quest.objective_label"), "\n".join(obj_lines)]
	var gold := int(def.get("rewards", {}).get("gold", 0))
	reward_label.text = "%s %s" % [tr("quest.reward_label"), tr("quest.reward_gold") % gold]
	if _mode == Mode.OFFER:
		btn_primary.text = tr("quest.accept")
		btn_secondary.text = tr("quest.decline")
	else:
		btn_primary.text = tr("quest.turn_in")
		btn_secondary.text = tr("quest.cancel")


func _on_primary_pressed() -> void:
	if _quest_id.is_empty():
		return
	if _mode == Mode.OFFER:
		accepted.emit(_quest_id)
	else:
		turned_in.emit(_quest_id)


func _on_secondary_pressed() -> void:
	if _mode == Mode.OFFER:
		declined.emit()
	else:
		cancelled.emit()
	hide_panel()
