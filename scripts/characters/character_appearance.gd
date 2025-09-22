class_name CharacterAppearance
extends Node2D


@onready var layers : Array[AnimatedSprite2D] = [
	$Race2DSprite,
	$Body2DSprite,
	$Hair2DSprite,
	$Head2DSprite,
	$Leg2DSprite,
	$Weapon2DSprite
]

var current_animation : String = "idle_front"
var raceSprites : Array = []
var headSprites : Array = []
var hairSprites : Array = []
var bodySprites : Array = []
var legSprites : Array = []
var weaponSprites : Array = []


func _ready() -> void:
	raceSprites = load_files("res://features/character/race/", ".tres")
	hairSprites = load_files("res://features/character/hair/basic/", ".tres")
	bodySprites = load_files("res://features/character/body/basic/", ".tres")
	legSprites = load_files("res://features/character/leg/basic/", ".tres")
	
	print(hairSprites[0].resource_path)
	print(bodySprites[0].resource_path)
	print(legSprites[0].resource_path)


func get_race() -> String:
	var race := $Race2DSprite as AnimatedSprite2D
	if race.sprite_frames:
		return race.sprite_frames.resource_path
	return ""


func set_race(resource_path: String) -> void:
	if resource_path != "" && resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var race := $Race2DSprite as AnimatedSprite2D
			race.sprite_frames = frames
			synchronize_all_animation(race.animation)


func get_hair() -> String: 
	var hair := $Hair2DSprite as AnimatedSprite2D
	if hair.sprite_frames:
		return hair.sprite_frames.resource_path
	return ""


func set_hair(resource_path: String) -> void: 
	if resource_path != "" && resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var hair := $Hair2DSprite as AnimatedSprite2D
			hair.sprite_frames = frames
			synchronize_animation(hair)


func get_leg() -> String:
	var leg := $Leg2DSprite as AnimatedSprite2D
	if leg.sprite_frames:
		return leg.sprite_frames.resource_path
	return ""


func set_leg(resource_path: String) -> void:
	if resource_path != "" && resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var leg := $Leg2DSprite as AnimatedSprite2D
			leg.sprite_frames = frames
			synchronize_animation(leg)


func get_body() -> String:
	var body := $Body2DSprite as AnimatedSprite2D
	if body.sprite_frames:
		return body.sprite_frames.resource_path
	return ""


func set_body(resource_path: String) -> void:
	if resource_path != "" && resource_path != null:
		var frames = load(resource_path)
		if frames is SpriteFrames:
			var body := $Body2DSprite as AnimatedSprite2D
			body.sprite_frames = frames
			synchronize_animation(body)


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


func synchronize_animation(new_animated_sprite: AnimatedSprite2D) -> void:
	print("Current Anima: ", current_animation)
	if current_animation != "" and new_animated_sprite.sprite_frames.has_animation(current_animation): 
		var base = $Race2DSprite
		new_animated_sprite.play(current_animation)
		new_animated_sprite.frame = base.frame
		new_animated_sprite.frame_progress = base.frame_progress
		new_animated_sprite.speed_scale = base.speed_scale


func synchronize_all_animation(new_anim_name: String) -> void:
	for layer in layers:
		if layer and layer.sprite_frames.has_animation(new_anim_name):
			layer.play(new_anim_name)
			layer.frame = 0
			layer.frame_progress = 0.0


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


func get_current_animation() -> StringName:
	return current_animation


func apply_full_data(data: Dictionary) -> void:
	if data.has("race_path"):
		set_race(data["race_path"])
	if data.has("hair_path"):
		set_hair(data["hair_path"])
	if data.has("body_path"):
		set_body(data["body_path"])
	if data.has("leg_path"):
		set_leg(data["leg_path"])
