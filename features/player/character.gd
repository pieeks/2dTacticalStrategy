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

var current_animation : String = ""

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


func equip_torso(new_frames: SpriteFrames) -> void: 
	var torso := $Body2DSprite as AnimatedSprite2D
	torso.sprite_frames = new_frames
	
	if current_animation != "" and torso.sprite_frames.has_animation(current_animation):
		torso.play(current_animation)
		torso.frame = $Character2DSprite.frame
