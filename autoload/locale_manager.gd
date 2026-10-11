extends Node

## LocaleManager (Autoload)
##
## Applies locale via TranslationServer and persists the choice.
## Translations come from Godot's CSV import
## (`localization/translations.*.translation`).

signal language_changed(locale: String)

const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "de"]

var current_locale: String = "en"


func _ready() -> void:
	var saved := _load_saved_locale()
	if saved.is_empty():
		var sys := OS.get_locale_language()
		saved = sys if SUPPORTED_LOCALES.has(sys) else "en"
	set_language(saved, false)


## Apply locale immediately. Persist to settings.cfg unless persist=false.
func set_language(locale: String, persist: bool = true) -> void:
	if not SUPPORTED_LOCALES.has(locale):
		locale = "en"
	current_locale = locale
	TranslationServer.set_locale(locale)
	if persist:
		_save_locale(locale)
	language_changed.emit(locale)


func get_supported_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES


func display_name_for(locale: String) -> String:
	match locale:
		"de":
			return "Deutsch"
		"en":
			return "English"
		_:
			return locale


func _load_saved_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	var loc := str(cfg.get_value("locale", "language", ""))
	return loc if SUPPORTED_LOCALES.has(loc) else ""


func _save_locale(locale: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # ignore missing
	cfg.set_value("locale", "language", locale)
	cfg.save(SETTINGS_PATH)
