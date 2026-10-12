class_name AppearanceCatalog
extends RefCounted
## Loads SpriteFrames catalogs used by character creation (not by ingame Appearance).

const RACE_DIR := "res://features/character/race/"
const HAIR_DIR := "res://features/character/hair/basic/"
const BODY_DIR := "res://features/character/body/basic/"
const LEG_DIR := "res://features/character/leg/basic/"

static var _race_sprites: Array = []
static var _hair_sprites: Array = []
static var _body_sprites: Array = []
static var _leg_sprites: Array = []
static var _loaded: bool = false


## Ensures catalogs are loaded once, then returns race SpriteFrames.
static func race_sprites() -> Array:
	_ensure_loaded()
	return _race_sprites


## Hair SpriteFrames for creation cycling.
static func hair_sprites() -> Array:
	_ensure_loaded()
	return _hair_sprites


## Body SpriteFrames for creation cycling.
static func body_sprites() -> Array:
	_ensure_loaded()
	return _body_sprites


## Leg SpriteFrames for creation cycling.
static func leg_sprites() -> Array:
	_ensure_loaded()
	return _leg_sprites


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_race_sprites = load_files(RACE_DIR, ".tres")
	_hair_sprites = load_files(HAIR_DIR, ".tres")
	_body_sprites = load_files(BODY_DIR, ".tres")
	_leg_sprites = load_files(LEG_DIR, ".tres")
	_loaded = true


## Loads all SpriteFrames resources in a directory matching a file extension.
static func load_files(path: String, end_with: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(end_with):
			var frames = load(path + file_name)
			if frames is SpriteFrames:
				files.append(frames)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files
