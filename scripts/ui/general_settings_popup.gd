extends Control

const _LocaleAccess = preload("res://scripts/ui/locale_access.gd")
## General settings: language selection (instant via LocaleManager).

@onready var _language_dropdown: OptionButton = $GeneralSettingsButtonContainer/LanguageDropDown

var _locales: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_rebuild_language_items()
	if not _language_dropdown.item_selected.is_connected(_on_language_item_selected):
		_language_dropdown.item_selected.connect(_on_language_item_selected)
	var lm := _LocaleAccess.get_lm(self)
	if lm != null and not lm.language_changed.is_connected(_on_language_changed):
		lm.language_changed.connect(_on_language_changed)


func _rebuild_language_items() -> void:
	var lm := _LocaleAccess.get_lm(self)
	if lm == null:
		return
	_locales = lm.get_supported_locales()
	_language_dropdown.clear()
	var selected := 0
	for i in range(_locales.size()):
		var loc := _locales[i]
		_language_dropdown.add_item(lm.display_name_for(loc), i)
		if loc == lm.current_locale:
			selected = i
	_language_dropdown.select(selected)


func _on_language_item_selected(index: int) -> void:
	if index < 0 or index >= _locales.size():
		return
	var lm := _LocaleAccess.get_lm(self)
	if lm != null:
		lm.set_language(_locales[index])


func _on_language_changed(_locale: String) -> void:
	# Keep dropdown selection in sync if locale changed elsewhere.
	var lm := _LocaleAccess.get_lm(self)
	if lm == null:
		return
	for i in range(_locales.size()):
		if _locales[i] == lm.current_locale:
			_language_dropdown.select(i)
			break
