extends Node

var steam_id :  int
var steam_username : String 
var steam_lobby_member: int = 0
var steamAppId : int = 480
var steamGameId : int = 480

func _init(): 
	OS.set_environment("SteamAppID", str(480))
	OS.set_environment("SteamGameID", str(480))



func _ready() -> void:
	print("Global script loaded")
	var base_size = Vector2i(640, 360)
	var window_size = DisplayServer.window_get_size()

	# Ganzzahligen Faktor berechnen
	var scale_x = floor(window_size.x / base_size.x)
	var scale_y = floor(window_size.y / base_size.y)
	var scale = min(scale_x, scale_y)

	if scale < 1:
		scale = 1

	# Auflösung anpassen → Integer factor
	get_tree().root.content_scale_size = base_size * scale
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	Steam.steamInit()
	
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()


func _process(_delta):
	Steam.run_callbacks()
