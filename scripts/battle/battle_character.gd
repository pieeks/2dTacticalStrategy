class_name BattleCharacter
extends CharacterBody2D
## Schlanker Kampf-Charakter (Authority + Kamera). Grid-Movement folgt in §3.

@onready var cam: Camera2D = $Camera2D
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	if is_multiplayer_authority():
		cam.enabled = true
		cam.make_current()
	else:
		cam.enabled = false
	# Distinct tint per peer for debug visibility
	var peer_id := get_multiplayer_authority()
	visual.color = Color.from_hsv(fmod(float(peer_id) * 0.17, 1.0), 0.7, 0.95)


func activate_camera() -> void:
	if is_multiplayer_authority() and is_instance_valid(cam):
		cam.enabled = true
		cam.make_current()
