## CharacterAppearance
##
## This node manages the visual representation of a character by layering multiple
## AnimatedSprite2D nodes (race, body, hair, head, legs, weapon). Each layer can
## be swapped dynamically at runtime to reflect equipment, customization, or networked changes.
##
## Features:
## - Dynamically loads SpriteFrames resources for each layer
## - Plays animations across all layers in sync
## - Synchronizes frame index and progress across layers
## - Provides API for applying full appearance data from dictionaries (used in networking)
##
## Usage:
## Attach this node to a PlayerCharacter or NPC scene, and call the provided
## setters (e.g. set_race(), set_body()) or apply_full_data() to update visuals.

class_name CharacterAppearance
extends Node2D

## References to all sprite layers that form the character's appearance.
## The order matches how they are visually stacked (Race → Body → Hair → Head → Legs → Weapon).
@onready var layers : Array[AnimatedSprite2D] = [
	$Race2DSprite,
	$Body2DSprite,
	$Hair2DSprite,
	$Head2DSprite,
	$Leg2DSprite,
	$MainWeaponAttachmentPoint/MainWeapon2DSprite,
	$OffWeaponAttachmentPoint/OffWeapon2DSprite
]

@onready var animation_player : AnimationPlayer = $AnimationPlayer

## Currently active animation across all layers (e.g. "idle_front", "walk_left").
var current_animation : String = "idle_front"


## Cached SpriteFrames resources for different categories.
## Loaded at runtime from the filesystem.
var raceSprites : Array = []
var headSprites : Array = []
var hairSprites : Array = []
var bodySprites : Array = []
var legSprites : Array = []
var weaponSprites : Array = []


## Called when the node enters the scene tree.
## Loads SpriteFrames resources from predefined directories.
func _ready() -> void:
	raceSprites = load_files("res://features/character/race/", ".tres")
	hairSprites = load_files("res://features/character/hair/basic/", ".tres")
	bodySprites = load_files("res://features/character/body/basic/", ".tres")
	legSprites = load_files("res://features/character/leg/basic/", ".tres")
	animation_player.play(current_animation)


## Returns the resource path of the currently active race SpriteFrames.
## @return String: Resource path if valid, otherwise empty string.
func get_race() -> String:
	var race := $Race2DSprite as AnimatedSprite2D
	if race.sprite_frames:
		return race.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the race layer.
## Also re-synchronizes all layers to the same animation.
## @param resource_path String: Path to a SpriteFrames resource.
func set_race(resource_path: String) -> void:
	if resource_path != "" and resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var race := $Race2DSprite as AnimatedSprite2D
			race.sprite_frames = frames


## Returns the resource path of the current hair SpriteFrames.
func get_hair() -> String: 
	var hair := $Hair2DSprite as AnimatedSprite2D
	if hair.sprite_frames:
		return hair.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the hair layer and synchronizes with current animation.
func set_hair(resource_path: String) -> void: 
	if resource_path != "" and resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var hair := $Hair2DSprite as AnimatedSprite2D
			hair.sprite_frames = frames


## Returns the resource path of the current leg SpriteFrames.
func get_leg() -> String:
	var leg := $Leg2DSprite as AnimatedSprite2D
	if leg.sprite_frames:
		return leg.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the leg layer and synchronizes with current animation.
func set_leg(resource_path: String) -> void:
	if resource_path != "" and resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var leg := $Leg2DSprite as AnimatedSprite2D
			leg.sprite_frames = frames


## Returns the resource path of the current body SpriteFrames.
func get_body() -> String:
	var body := $Body2DSprite as AnimatedSprite2D
	if body.sprite_frames:
		return body.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the body layer and synchronizes with current animation.
func set_body(resource_path: String) -> void:
	if resource_path != "" and resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var body := $Body2DSprite as AnimatedSprite2D
			body.sprite_frames = frames


## Returns the resource path of the current head SpriteFrames.
func get_head() -> String:
	var head := $Head2DSprite as AnimatedSprite2D
	if head.sprite_frames:
		return head.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the head layer.
func set_head(resource_path: String) -> void:
	if resource_path != "" and resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var head := $Head2DSprite as AnimatedSprite2D
			head.sprite_frames = frames


## Returns the resource path of the main weapon SpriteFrames.
func get_main_weapon() -> String:
	var weapon := $MainWeaponAttachmentPoint/MainWeapon2DSprite as AnimatedSprite2D
	if weapon.sprite_frames:
		return weapon.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the main weapon layer.
func set_main_weapon(resource_path: String) -> void:
	if resource_path != "" and resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var weapon := $MainWeaponAttachmentPoint/MainWeapon2DSprite as AnimatedSprite2D
			weapon.sprite_frames = frames


## Returns the resource path of the off-hand weapon SpriteFrames.
func get_off_weapon() -> String:
	var weapon := $OffWeaponAttachmentPoint/OffWeapon2DSprite as AnimatedSprite2D
	if weapon.sprite_frames:
		return weapon.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the off-hand weapon layer.
func set_off_weapon(resource_path: String) -> void:
	if resource_path != "" and resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var weapon := $OffWeaponAttachmentPoint/OffWeapon2DSprite as AnimatedSprite2D
			weapon.sprite_frames = frames


## Plays an animation on all available layers.
## @param animation_name String: Name of the animation (must exist in SpriteFrames).
## @param speed float: Playback speed (default 1.0).
## Prevents replaying if the animation is already active.
func play(animation_name: String, speed: float = 1.0) -> void: 
	if current_animation == animation_name:
		return
	current_animation = animation_name
	
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		animation_player.speed_scale = speed
	else:
		animation_player.stop()


## Loads all SpriteFrames resources in a directory matching a file extension.
## @param path String: Directory to scan.
## @param endWith String: File suffix filter (e.g. ".tres").
## @return Array: All loaded SpriteFrames.
func load_files(path: String, endWith: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(endWith): 
				var full_path = path + file_name
				var frames = load(full_path)
				if frames is SpriteFrames:
					files.append(frames)
			file_name = dir.get_next()
		dir.list_dir_end()
	return files


## Returns the name of the currently active animation.
func get_current_animation() -> StringName:
	return current_animation


## Returns the current layer paths as a dictionary (for fight spawn / sync).
## Only includes layers that are currently visible (matches NPC Spec style).
func get_full_data() -> Dictionary:
	var data: Dictionary = {}
	var race := $Race2DSprite as AnimatedSprite2D
	var hair := $Hair2DSprite as AnimatedSprite2D
	var body := $Body2DSprite as AnimatedSprite2D
	var leg := $Leg2DSprite as AnimatedSprite2D
	var head := $Head2DSprite as AnimatedSprite2D
	var main_weapon := $MainWeaponAttachmentPoint/MainWeapon2DSprite as AnimatedSprite2D
	var off_weapon := $OffWeaponAttachmentPoint/OffWeapon2DSprite as AnimatedSprite2D
	if race.visible and race.sprite_frames:
		data["race_path"] = race.sprite_frames.resource_path
	if hair.visible and hair.sprite_frames:
		data["hair_path"] = hair.sprite_frames.resource_path
	if body.visible and body.sprite_frames:
		data["body_path"] = body.sprite_frames.resource_path
	if leg.visible and leg.sprite_frames:
		data["leg_path"] = leg.sprite_frames.resource_path
	if head.visible and head.sprite_frames:
		data["head_path"] = head.sprite_frames.resource_path
	if main_weapon.visible and main_weapon.sprite_frames:
		data["main_weapon_path"] = main_weapon.sprite_frames.resource_path
	if off_weapon.visible and off_weapon.sprite_frames:
		data["off_weapon_path"] = off_weapon.sprite_frames.resource_path
	return data


## Applies a full appearance dataset from a dictionary.
## Present keys → set layer + show; missing/empty keys → hide layer (NPC Spec pattern).
func apply_full_data(data: Dictionary) -> void:
	_apply_layer($Race2DSprite as AnimatedSprite2D, data, "race_path", set_race)
	_apply_layer($Hair2DSprite as AnimatedSprite2D, data, "hair_path", set_hair)
	_apply_layer($Body2DSprite as AnimatedSprite2D, data, "body_path", set_body)
	_apply_layer($Leg2DSprite as AnimatedSprite2D, data, "leg_path", set_leg)
	_apply_layer($Head2DSprite as AnimatedSprite2D, data, "head_path", set_head)
	_apply_layer(
		$MainWeaponAttachmentPoint/MainWeapon2DSprite as AnimatedSprite2D,
		data,
		"main_weapon_path",
		set_main_weapon
	)
	_apply_layer(
		$OffWeaponAttachmentPoint/OffWeapon2DSprite as AnimatedSprite2D,
		data,
		"off_weapon_path",
		set_off_weapon
	)


func _apply_layer(layer: AnimatedSprite2D, data: Dictionary, key: String, setter: Callable) -> void:
	var path := str(data.get(key, "")).strip_edges()
	if data.has(key) and path != "":
		setter.call(path)
		layer.visible = true
	else:
		layer.visible = false
