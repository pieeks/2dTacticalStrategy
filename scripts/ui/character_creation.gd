## Character Creation UI — preview, validation, and save via PlayerPartyState.
extends Control

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
const AppearanceCatalogScript := preload("res://scripts/characters/appearance_catalog.gd")
const MAX_NAME_LEN := 24

@onready var character: CharacterAppearance = $CanvasLayer/UIRoot/CharacterPreview/CharacterAppearance
@onready var _error_label: Label = $CanvasLayer/UIRoot/ErrorLabel

var race_index := 0
var hair_index := 0
var body_index := 0
var leg_index := 0

signal character_created


func _ready() -> void:
	_apply_static_texts()
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)
	_apply_preview_from_indices()
	_set_error("")


func _on_language_changed(_locale: String) -> void:
	_apply_static_texts()


func _apply_static_texts() -> void:
	$CanvasLayer/UIRoot/Label.text = tr("ui.character_creation.title")
	$CanvasLayer/UIRoot/VBoxContainer/RaceHContainer/Label.text = tr("ui.character_creation.race")
	$CanvasLayer/UIRoot/VBoxContainer/HairHContainer/Label.text = tr("ui.character_creation.hair")
	$CanvasLayer/UIRoot/VBoxContainer/BodyHContainer/Label.text = tr("ui.character_creation.body")
	$CanvasLayer/UIRoot/VBoxContainer/LegHContainer/Label.text = tr("ui.character_creation.leg")
	$CanvasLayer/UIRoot/NameHContainer/Label.text = tr("ui.character_creation.name")
	$CanvasLayer/UIRoot/CreateButton.text = tr("ui.character_creation.create")
	$CanvasLayer/UIRoot/BackToMenu.text = tr("ui.character_creation.back")
	var rnd := $CanvasLayer/UIRoot.get_node_or_null("RandomizeButton") as Button
	if rnd:
		rnd.text = tr("ui.character_creation.randomize")


func _set_error(key: String) -> void:
	if _error_label == null:
		return
	_error_label.text = tr(key) if not key.is_empty() else ""
	_error_label.visible = not key.is_empty()


func _apply_preview_from_indices() -> void:
	var races: Array = AppearanceCatalogScript.race_sprites()
	var hairs: Array = AppearanceCatalogScript.hair_sprites()
	var bodies: Array = AppearanceCatalogScript.body_sprites()
	var legs: Array = AppearanceCatalogScript.leg_sprites()
	if races.is_empty() or hairs.is_empty() or bodies.is_empty() or legs.is_empty():
		return
	race_index = clampi(race_index, 0, races.size() - 1)
	hair_index = clampi(hair_index, 0, hairs.size() - 1)
	body_index = clampi(body_index, 0, bodies.size() - 1)
	leg_index = clampi(leg_index, 0, legs.size() - 1)
	character.set_race(races[race_index].resource_path)
	character.set_hair(hairs[hair_index].resource_path)
	character.set_body(bodies[body_index].resource_path)
	character.set_leg(legs[leg_index].resource_path)


func _on_race_left_button_pressed() -> void:
	var races: Array = AppearanceCatalogScript.race_sprites()
	if races.is_empty():
		return
	race_index = (race_index - 1 + races.size()) % races.size()
	character.set_race(races[race_index].resource_path)


func _on_race_right_button_pressed() -> void:
	var races: Array = AppearanceCatalogScript.race_sprites()
	if races.is_empty():
		return
	race_index = (race_index + 1) % races.size()
	character.set_race(races[race_index].resource_path)


func _on_hair_left_button_pressed() -> void:
	var hairs: Array = AppearanceCatalogScript.hair_sprites()
	if hairs.is_empty():
		return
	hair_index = (hair_index - 1 + hairs.size()) % hairs.size()
	character.set_hair(hairs[hair_index].resource_path)


func _on_hair_right_button_pressed() -> void:
	var hairs: Array = AppearanceCatalogScript.hair_sprites()
	if hairs.is_empty():
		return
	hair_index = (hair_index + 1) % hairs.size()
	character.set_hair(hairs[hair_index].resource_path)


func _on_body_left_button_pressed() -> void:
	var bodies: Array = AppearanceCatalogScript.body_sprites()
	if bodies.is_empty():
		return
	body_index = (body_index - 1 + bodies.size()) % bodies.size()
	character.set_body(bodies[body_index].resource_path)


func _on_body_right_button_pressed() -> void:
	var bodies: Array = AppearanceCatalogScript.body_sprites()
	if bodies.is_empty():
		return
	body_index = (body_index + 1) % bodies.size()
	character.set_body(bodies[body_index].resource_path)


func _on_leg_left_button_pressed() -> void:
	var legs: Array = AppearanceCatalogScript.leg_sprites()
	if legs.is_empty():
		return
	leg_index = (leg_index - 1 + legs.size()) % legs.size()
	character.set_leg(legs[leg_index].resource_path)


func _on_leg_right_button_pressed() -> void:
	var legs: Array = AppearanceCatalogScript.leg_sprites()
	if legs.is_empty():
		return
	leg_index = (leg_index + 1) % legs.size()
	character.set_leg(legs[leg_index].resource_path)


func _on_randomize_button_pressed() -> void:
	var races: Array = AppearanceCatalogScript.race_sprites()
	var hairs: Array = AppearanceCatalogScript.hair_sprites()
	var bodies: Array = AppearanceCatalogScript.body_sprites()
	var legs: Array = AppearanceCatalogScript.leg_sprites()
	if races.is_empty() or hairs.is_empty() or bodies.is_empty() or legs.is_empty():
		_set_error("ui.character_creation.catalog_incomplete")
		return
	race_index = randi() % races.size()
	hair_index = randi() % hairs.size()
	body_index = randi() % bodies.size()
	leg_index = randi() % legs.size()
	_apply_preview_from_indices()
	_set_error("")


func _sanitize_name(raw: String) -> String:
	var cleaned := raw.strip_edges()
	var out := ""
	for i in cleaned.length():
		var ch := cleaned[i]
		if ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
			continue
		out += ch
	if out.length() > MAX_NAME_LEN:
		out = out.substr(0, MAX_NAME_LEN)
	return out.strip_edges()


func _on_create_button_pressed() -> void:
	var char_name := _sanitize_name($CanvasLayer/UIRoot/NameHContainer/NameLineEdit.text)
	if char_name.is_empty():
		_set_error("ui.character_creation.name_required")
		return

	var races: Array = AppearanceCatalogScript.race_sprites()
	var hairs: Array = AppearanceCatalogScript.hair_sprites()
	var bodies: Array = AppearanceCatalogScript.body_sprites()
	var legs: Array = AppearanceCatalogScript.leg_sprites()
	if races.is_empty() or hairs.is_empty() or bodies.is_empty() or legs.is_empty():
		_set_error("ui.character_creation.catalog_incomplete")
		return

	var appearance := {
		"race_path": races[race_index].resource_path,
		"hair_path": hairs[hair_index].resource_path,
		"body_path": bodies[body_index].resource_path,
		"leg_path": legs[leg_index].resource_path,
	}

	if not PlayerPartyState.create_new_character(char_name, appearance):
		_set_error("ui.character_creation.save_failed")
		return

	var GameSettingsScript := preload("res://scripts/ui/game_settings.gd")
	GameSettingsScript.set_last_character_id(PlayerPartyState.player_id)
	emit_signal("character_created")
	_on_back_to_menu_pressed()


func _on_back_to_menu_pressed() -> void:
	PlayerPartyState.get_available_character()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
