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
	# AnimationPlayer is the sole driver; per-layer autoplay desyncs on frame swaps.
	for layer in layers:
		if layer != null:
			layer.autoplay = ""
	var hand := get_node_or_null("HandSprite2D") as AnimatedSprite2D
	if hand != null:
		hand.autoplay = ""
	play(current_animation, 1.0, true)


## Returns the resource path of the currently active race SpriteFrames.
## @return String: Resource path if valid, otherwise empty string.
func get_race() -> String:
	var race := $Race2DSprite as AnimatedSprite2D
	if race.sprite_frames:
		return race.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the race layer and re-syncs animation frames.
func set_race(resource_path: String) -> void:
	_set_layer_frames($Race2DSprite as AnimatedSprite2D, resource_path)


## Returns the resource path of the current hair SpriteFrames.
func get_hair() -> String: 
	var hair := $Hair2DSprite as AnimatedSprite2D
	if hair.sprite_frames:
		return hair.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the hair layer and re-syncs animation frames.
func set_hair(resource_path: String) -> void: 
	_set_layer_frames($Hair2DSprite as AnimatedSprite2D, resource_path)


## Returns the resource path of the current leg SpriteFrames.
func get_leg() -> String:
	var leg := $Leg2DSprite as AnimatedSprite2D
	if leg.sprite_frames:
		return leg.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the leg layer and re-syncs animation frames.
func set_leg(resource_path: String) -> void:
	_set_layer_frames($Leg2DSprite as AnimatedSprite2D, resource_path)


## Returns the resource path of the current body SpriteFrames.
func get_body() -> String:
	var body := $Body2DSprite as AnimatedSprite2D
	if body.sprite_frames:
		return body.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the body layer and re-syncs animation frames.
func set_body(resource_path: String) -> void:
	_set_layer_frames($Body2DSprite as AnimatedSprite2D, resource_path)


## Returns the resource path of the current head SpriteFrames.
func get_head() -> String:
	var head := $Head2DSprite as AnimatedSprite2D
	if head.sprite_frames:
		return head.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the head layer and re-syncs animation frames.
func set_head(resource_path: String) -> void:
	_set_layer_frames($Head2DSprite as AnimatedSprite2D, resource_path)


## Returns the resource path of the main weapon SpriteFrames.
func get_main_weapon() -> String:
	var weapon := $MainWeaponAttachmentPoint/MainWeapon2DSprite as AnimatedSprite2D
	if weapon.sprite_frames:
		return weapon.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the main weapon layer and re-syncs animation frames.
func set_main_weapon(resource_path: String) -> void:
	_set_layer_frames($MainWeaponAttachmentPoint/MainWeapon2DSprite as AnimatedSprite2D, resource_path)


## Returns the resource path of the off-hand weapon SpriteFrames.
func get_off_weapon() -> String:
	var weapon := $OffWeaponAttachmentPoint/OffWeapon2DSprite as AnimatedSprite2D
	if weapon.sprite_frames:
		return weapon.sprite_frames.resource_path
	return ""


## Assigns new SpriteFrames to the off-hand weapon layer and re-syncs animation frames.
func set_off_weapon(resource_path: String) -> void:
	_set_layer_frames($OffWeaponAttachmentPoint/OffWeapon2DSprite as AnimatedSprite2D, resource_path)


## Swap SpriteFrames on one layer, then force all layers back onto the same anim time.
func _set_layer_frames(layer: AnimatedSprite2D, resource_path: String) -> void:
	if layer == null or resource_path == "" or resource_path == null:
		return
	var frames = load(resource_path)
	if frames is SpriteFrames:
		layer.autoplay = ""
		layer.sprite_frames = frames
		_resync_animation()


## Re-apply current AnimationPlayer clip at the same timestamp so layered frames match.
func _resync_animation() -> void:
	if animation_player == null:
		return
	var anim := current_animation
	if anim.is_empty() or not animation_player.has_animation(anim):
		return
	var pos := 0.0
	if String(animation_player.current_animation) == anim and animation_player.is_playing():
		pos = animation_player.current_animation_position
	for layer in layers:
		if layer != null and layer.sprite_frames != null and layer.sprite_frames.has_animation(anim):
			layer.animation = anim
	animation_player.play(anim)
	animation_player.seek(pos, true)


## Plays an animation on all available layers.
## @param animation_name String: Name of the animation (must exist in SpriteFrames).
## @param speed float: Playback speed (default 1.0).
## @param force bool: Replay/seek even if already on this animation (after layer swap).
func play(animation_name: String, speed: float = 1.0, force: bool = false) -> void:
	if not force and current_animation == animation_name and animation_player.is_playing():
		return
	current_animation = animation_name
	if not animation_player.has_animation(animation_name):
		animation_player.stop()
		return
	animation_player.speed_scale = speed
	animation_player.play(animation_name)
	if force:
		animation_player.seek(0.0, true)


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
	# Apply frames without per-layer resync; one seek at the end.
	_apply_layer_frames_only($Race2DSprite as AnimatedSprite2D, data, "race_path")
	_apply_layer_frames_only($Hair2DSprite as AnimatedSprite2D, data, "hair_path")
	_apply_layer_frames_only($Body2DSprite as AnimatedSprite2D, data, "body_path")
	_apply_layer_frames_only($Leg2DSprite as AnimatedSprite2D, data, "leg_path")
	_apply_layer_frames_only($Head2DSprite as AnimatedSprite2D, data, "head_path")
	_apply_layer_frames_only(
		$MainWeaponAttachmentPoint/MainWeapon2DSprite as AnimatedSprite2D,
		data,
		"main_weapon_path"
	)
	_apply_layer_frames_only(
		$OffWeaponAttachmentPoint/OffWeapon2DSprite as AnimatedSprite2D,
		data,
		"off_weapon_path"
	)
	_resync_animation()


func _apply_layer_frames_only(layer: AnimatedSprite2D, data: Dictionary, key: String) -> void:
	var path := str(data.get(key, "")).strip_edges()
	if data.has(key) and path != "":
		if layer != null:
			var frames = load(path)
			if frames is SpriteFrames:
				layer.autoplay = ""
				layer.sprite_frames = frames
			layer.visible = true
	elif layer != null:
		layer.visible = false
