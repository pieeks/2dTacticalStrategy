class_name Character
extends Node2D


@onready var layers : Array[AnimatedSprite2D] = [
	$Character2DSprite,
	$Body2DSprite,
	$Hair2DSprite,
	$Head2DSprite,
	$Leg2DSprite,
	$Weapon2DSprite
]

var current_animation : String = "idle_front"
var headSprites : Array = []
var hairSprites : Array = []
var bodySprites : Array = []
var legSprites : Array = []
var weaponSprites : Array = []


func _ready() -> void:
	hairSprites = load_files("res://features/player/hair/", ".tres")
	bodySprites = load_files("res://features/player/body/", ".tres")
	legSprites = load_files("res://features/player/leg/", ".tres")
	
	print(hairSprites[1].resource_path)


func get_hair() -> String: 
	var hair := $Hair2DSprite as AnimatedSprite2D
	if hair.sprite_frames:
		return hair.sprite_frames.resource_path
	return ""


func set_hair(resource_path: String) -> void: 
	var frames = load(resource_path)
	if frames is SpriteFrames:
		var hair := $Hair2DSprite as AnimatedSprite2D
		hair.sprite_frames = frames
		synchronize_animation(hair)


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
		var base = $Character2DSprite
		new_animated_sprite.play(current_animation)
		new_animated_sprite.frame = base.frame
		new_animated_sprite.frame_progress = base.frame_progress
		new_animated_sprite.speed_scale = base.speed_scale


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
