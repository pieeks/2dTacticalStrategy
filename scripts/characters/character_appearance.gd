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

## Body/gear layers used for appearance data and movement playback.
## HandSprite2D is battle-only (not in this list / get_full_data); play() includes it when visible.
@onready var layers : Array[AnimatedSprite2D] = [
	$Race2DSprite,
	$Body2DSprite,
	$Hair2DSprite,
	$Head2DSprite,
	$Leg2DSprite,
	$MainWeaponAttachmentPoint/MainWeapon2DSprite,
	$OffWeaponAttachmentPoint/OffWeapon2DSprite
]

## Kept for battle attachment clips; Idle/Walk no longer drive frames through it.
@onready var animation_player : AnimationPlayer = $AnimationPlayer

## Currently active animation across all layers (e.g. "idle_front", "walk_left").
var current_animation : String = "idle_front"


## Starts the default clip via SpriteFrames (scene autoplay must stay empty).
func _ready() -> void:
	if animation_player != null:
		animation_player.stop()
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
		layer.sprite_frames = frames
		_resync_animation()


## Re-apply current clip after a layer swap (restart + align to master frame).
func _resync_animation() -> void:
	var anim := current_animation
	if anim.is_empty():
		return
	var master := _master_layer_for(anim)
	var master_frame := 0
	var master_progress := 0.0
	if master != null and master.is_playing() and String(master.animation) == anim:
		master_frame = master.frame
		master_progress = master.frame_progress
	play(anim, 1.0, true)
	if master_frame > 0 or master_progress > 0.0:
		for layer in _playback_layers():
			if not _layer_has_clip(layer, anim):
				continue
			var last_frame := layer.sprite_frames.get_frame_count(anim) - 1
			layer.set_frame_and_progress(mini(master_frame, last_frame), master_progress)


## True when the current clip is actively playing on at least one body layer.
func is_playing_current() -> bool:
	var anim := current_animation
	if anim.is_empty():
		return false
	for layer in _playback_layers():
		if layer != null and layer.is_playing() and String(layer.animation) == anim:
			return true
	return false


## Plays a SpriteFrames clip on all layers that have it (Variante B).
## @param animation_name String: Clip name (must exist on at least one layer).
## @param speed float: Playback speed (default 1.0).
## @param force bool: Restart even if already on this clip (after layer swap).
func play(animation_name: String, speed: float = 1.0, force: bool = false) -> void:
	if not force and current_animation == animation_name and is_playing_current():
		return
	current_animation = animation_name
	if animation_player != null:
		animation_player.stop()
	if not _any_layer_has_clip(animation_name):
		_stop_playback_layers()
		return
	_play_layers(animation_name, speed, force)


## Layers that receive movement/idle playback (body layers + visible Hand).
func _playback_layers() -> Array[AnimatedSprite2D]:
	var result: Array[AnimatedSprite2D] = []
	for layer in layers:
		if layer != null:
			result.append(layer)
	var hand := get_node_or_null("HandSprite2D") as AnimatedSprite2D
	if hand != null and hand.visible:
		result.append(hand)
	return result


func _layer_has_clip(layer: AnimatedSprite2D, anim: String) -> bool:
	return layer != null and layer.sprite_frames != null and layer.sprite_frames.has_animation(anim)


func _any_layer_has_clip(anim: String) -> bool:
	for layer in _playback_layers():
		if _layer_has_clip(layer, anim):
			return true
	return false


func _master_layer_for(anim: String) -> AnimatedSprite2D:
	var race := $Race2DSprite as AnimatedSprite2D
	if _layer_has_clip(race, anim):
		return race
	for layer in _playback_layers():
		if _layer_has_clip(layer, anim):
			return layer
	return null


## Idle/Walk must loop; many .tres still have loop=false from the AnimationPlayer era.
func _ensure_movement_clip_loops(frames: SpriteFrames, anim: String) -> void:
	if frames == null or not frames.has_animation(anim):
		return
	if anim.begins_with("idle_") or anim.begins_with("walk_"):
		if not frames.get_animation_loop(anim):
			frames.set_animation_loop(anim, true)


func _play_layers(anim: String, speed: float, force: bool) -> void:
	for layer in _playback_layers():
		if not _layer_has_clip(layer, anim):
			continue
		_ensure_movement_clip_loops(layer.sprite_frames, anim)
		layer.speed_scale = speed
		if force:
			layer.set_frame_and_progress(0, 0.0)
		layer.play(anim)


func _stop_playback_layers() -> void:
	for layer in _playback_layers():
		if layer != null and layer.is_playing():
			layer.stop()


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
				layer.sprite_frames = frames
			layer.visible = true
	elif layer != null:
		layer.visible = false
