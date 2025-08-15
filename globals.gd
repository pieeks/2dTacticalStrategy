extends Node

var steam_id :  int
var steam_username : String 
var steamAppId : int = 480
var steamGameId : int = 480

func _init(): 
	OS.set_environment("SteamAppID", str(480))
	OS.set_environment("SteamGameID", str(480))


func _ready() -> void:
	Steam.steamInit()
	
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()


func _process(_delta):
	Steam.run_callbacks()
