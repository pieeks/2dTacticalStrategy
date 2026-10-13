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

## Equipment intent from apply_full_data — battle AP must not reveal unequipped defaults.
var _equip_main_weapon: bool = false
var _equip_off_weapon: bool = false


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
	var resolved := _resolve_sprite_clip(anim)
	var master := _master_layer_for(resolved)
	var master_frame := 0
	var master_progress := 0.0
	if master != null and master.is_playing() and String(master.animation) == resolved:
		master_frame = master.frame
		master_progress = master.frame_progress
	play(anim, 1.0, true)
	if master_frame > 0 or master_progress > 0.0:
		for layer in _playback_layers():
			if not _layer_has_clip(layer, resolved):
				continue
			var last_frame := layer.sprite_frames.get_frame_count(resolved) - 1
			layer.set_frame_and_progress(mini(master_frame, last_frame), master_progress)


## True when the current clip is actively playing on at least one body layer.
func is_playing_current() -> bool:
	var resolved := _resolve_sprite_clip(current_animation)
	if resolved.is_empty():
		return false
	for layer in _playback_layers():
		if layer != null and layer.is_playing() and String(layer.animation) == resolved:
			return true
	return false


## Plays SpriteFrames on layers; `*_battle` also drives AnimationPlayer attachment pose.
## Falls back to the non-`_battle` clip when a layer set lacks the battle name.
## @param animation_name String: Requested clip (e.g. idle_front / idle_front_battle).
## @param speed float: Playback speed (default 1.0).
## @param force bool: Restart even if already on this clip (after layer swap).
func play(animation_name: String, speed: float = 1.0, force: bool = false) -> void:
	if not force and current_animation == animation_name and is_playing_current():
		return
	current_animation = animation_name
	var resolved := _resolve_sprite_clip(animation_name)
	var use_battle_pose := (
		animation_name.ends_with("_battle")
		and animation_player != null
		and animation_player.has_animation(animation_name)
	)
	if not use_battle_pose:
		_stop_battle_attachments()
	if resolved.is_empty():
		_stop_playback_layers()
		return
	_play_layers(resolved, speed, force)
	if use_battle_pose:
		animation_player.play(animation_name)
		# AP clips force weapon/hand visible — clamp back to equipped layers only.
		_enforce_equipment_visibility()
		_play_hand_if_visible(resolved, speed, force)


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


## Clip exists on any body layer or Hand (even if Hand is still hidden).
func _any_layer_has_clip(anim: String) -> bool:
	for layer in layers:
		if _layer_has_clip(layer, anim):
			return true
	var hand := get_node_or_null("HandSprite2D") as AnimatedSprite2D
	return _layer_has_clip(hand, anim)


## Prefer requested clip; strip `_battle` when SpriteFrames lack it.
func _resolve_sprite_clip(anim: String) -> String:
	if anim.is_empty():
		return ""
	if _any_layer_has_clip(anim):
		return anim
	if anim.ends_with("_battle"):
		var base := anim.trim_suffix("_battle")
		if _any_layer_has_clip(base):
			return base
	return ""


func _master_layer_for(anim: String) -> AnimatedSprite2D:
	if anim.is_empty():
		return null
	var race := $Race2DSprite as AnimatedSprite2D
	if _layer_has_clip(race, anim):
		return race
	for layer in _playback_layers():
		if _layer_has_clip(layer, anim):
			return layer
	return null


## Idle/Walk (incl. `*_battle`) must loop; many .tres still have loop=false from the AP era.
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


## After battle AP reveals Hand, start its SpriteFrames clip if present.
func _play_hand_if_visible(anim: String, speed: float, force: bool) -> void:
	var hand := get_node_or_null("HandSprite2D") as AnimatedSprite2D
	if hand == null or not hand.visible or not _layer_has_clip(hand, anim):
		return
	_ensure_movement_clip_loops(hand.sprite_frames, anim)
	hand.speed_scale = speed
	if force:
		hand.set_frame_and_progress(0, 0.0)
	hand.play(anim)


## Keep Hand/Weapons hidden unless appearance data equipped them (e.g. slime = race only).
func _enforce_equipment_visibility() -> void:
	var main_w := get_node_or_null("MainWeaponAttachmentPoint/MainWeapon2DSprite") as AnimatedSprite2D
	if main_w != null:
		main_w.visible = _equip_main_weapon
	var off_w := get_node_or_null("OffWeaponAttachmentPoint/OffWeapon2DSprite") as AnimatedSprite2D
	if off_w != null:
		off_w.visible = _equip_off_weapon
	var hand := get_node_or_null("HandSprite2D") as AnimatedSprite2D
	if hand != null:
		hand.visible = _equip_main_weapon or _equip_off_weapon


## True when battle idle should show a weapon/hand attachment.
func has_equipped_weapons() -> bool:
	return _equip_main_weapon or _equip_off_weapon


## Play `death_*` SpriteFrames when present; otherwise freeze current pose for corpse FX.
## Content can add `death_front` (etc.) later without call-site changes.
func play_death(facing: String = "front") -> void:
	_stop_battle_attachments()
	var candidates: Array[String] = [
		"death_%s" % facing,
		"death_front",
		"death",
	]
	var resolved := ""
	for clip in candidates:
		if _any_layer_has_clip(clip):
			resolved = clip
			break
	if resolved.is_empty():
		for layer in _playback_layers():
			if layer != null and layer.is_playing():
				layer.pause()
		return
	current_animation = resolved
	for layer in _playback_layers():
		if not _layer_has_clip(layer, resolved):
			continue
		if layer.sprite_frames.get_animation_loop(resolved):
			layer.sprite_frames.set_animation_loop(resolved, false)
		layer.speed_scale = 1.0
		layer.set_frame_and_progress(0, 0.0)
		layer.play(resolved)


## Stop AP and hide battle-only attachments (Overworld Idle/Walk).
func _stop_battle_attachments() -> void:
	if animation_player != null:
		animation_player.stop()
		if animation_player.has_animation(&"RESET"):
			animation_player.play(&"RESET")
			animation_player.seek(0.0, true)
			animation_player.stop()
	var hand := get_node_or_null("HandSprite2D") as AnimatedSprite2D
	if hand != null:
		hand.visible = false
	var main_w := get_node_or_null("MainWeaponAttachmentPoint/MainWeapon2DSprite") as AnimatedSprite2D
	if main_w != null:
		main_w.visible = false
	var off_w := get_node_or_null("OffWeaponAttachmentPoint/OffWeapon2DSprite") as AnimatedSprite2D
	if off_w != null:
		off_w.visible = false


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
	_equip_main_weapon = _data_has_layer_path(data, "main_weapon_path")
	_equip_off_weapon = _data_has_layer_path(data, "off_weapon_path")
	# No weapon keys (typical player save): keep scene loadout for humanoids.
	# Race-only kits (slime) leave body/hair/leg hidden → no default weapons.
	if not data.has("main_weapon_path") and not data.has("off_weapon_path"):
		if _has_visible_gear_layers():
			var main_w := $MainWeaponAttachmentPoint/MainWeapon2DSprite as AnimatedSprite2D
			var off_w := $OffWeaponAttachmentPoint/OffWeapon2DSprite as AnimatedSprite2D
			_equip_main_weapon = main_w != null and main_w.sprite_frames != null
			_equip_off_weapon = off_w != null and off_w.sprite_frames != null
	_resync_animation()


func _data_has_layer_path(data: Dictionary, key: String) -> bool:
	return data.has(key) and str(data.get(key, "")).strip_edges() != ""


## Body/hair/leg/head still shown → humanoid kit (not race-only enemy).
func _has_visible_gear_layers() -> bool:
	for node_path in ["Body2DSprite", "Hair2DSprite", "Leg2DSprite", "Head2DSprite"]:
		var layer := get_node_or_null(node_path) as CanvasItem
		if layer != null and layer.visible:
			return true
	return false


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
