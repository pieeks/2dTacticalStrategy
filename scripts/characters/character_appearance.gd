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
	$Weapon2DSprite
]

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
	
	print(hairSprites[0].resource_path)
	print(bodySprites[0].resource_path)
	print(legSprites[0].resource_path)


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
			synchronize_all_animation(race.animation)


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
			synchronize_animation(hair)


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
			synchronize_animation(leg)


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
			synchronize_animation(body)


## Plays an animation on all available layers.
## @param animation_name String: Name of the animation (must exist in SpriteFrames).
## @param speed float: Playback speed (default 1.0).
## Prevents replaying if the animation is already active.
func play(animation_name: String, speed: float = 1.0) -> void: 
	if current_animation == animation_name:
		return
	current_animation = animation_name
	
	for layer in layers: 
		if layer.sprite_frames and layer.sprite_frames.has_animation(animation_name):
			layer.play(animation_name)
			layer.speed_scale = speed
		else:
			layer.stop()
			layer.frame = 0


## Synchronizes a new AnimatedSprite2D layer with the currently active animation.
## Copies frame index, frame progress, and speed scale from the base (race) layer.
func synchronize_animation(new_animated_sprite: AnimatedSprite2D) -> void:
	print("Current Anima: ", current_animation)
	if current_animation != "" and new_animated_sprite.sprite_frames.has_animation(current_animation): 
		var base = $Race2DSprite
		new_animated_sprite.play(current_animation)
		new_animated_sprite.frame = base.frame
		new_animated_sprite.frame_progress = base.frame_progress
		new_animated_sprite.speed_scale = base.speed_scale


## Synchronizes all layers to a new animation name.
## Resets frame index and progress to 0 for consistency.
func synchronize_all_animation(new_anim_name: String) -> void:
	for layer in layers:
		if layer and layer.sprite_frames.has_animation(new_anim_name):
			layer.play(new_anim_name)
			layer.frame = 0
			layer.frame_progress = 0.0


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


## Applies a full appearance dataset from a dictionary.
## Keys supported: race_path, hair_path, body_path, leg_path.
func apply_full_data(data: Dictionary) -> void:
	if data.has("race_path"):
		set_race(data["race_path"])
	if data.has("hair_path"):
		set_hair(data["hair_path"])
	if data.has("body_path"):
		set_body(data["body_path"])
	if data.has("leg_path"):
		set_leg(data["leg_path"])
