extends Node

## Global Script
##
## This script serves as a global autoload for initializing display settings
## (integer scaling) and, optionally, Steamworks integration.
##
## Features:
## - Adjusts content scale to keep pixel-perfect integer scaling
## - Placeholder for Steam initialization and callbacks
## - Stores basic Steam information (ID, username, lobby members)
##
## Usage:
## - Add this script as an autoload (singleton) in Project Settings.
## - Uncomment Steam-related code to enable Steamworks integration.

## Steam user ID (assigned after successful Steam init).
var steam_id : int

## Steam display name of the current user.
var steam_username : String 

## Number of members in the current Steam lobby.
var steam_lobby_member: int = 0

## Steam AppID (default 480 = Spacewar test ID).
var steamAppId : int = 480

## Steam GameID (default 480 = Spacewar test ID).
var steamGameId : int = 480


# Optional init hook for setting Steam environment variables.
# These must be set before initializing Steam.
# func _init(): 
#	OS.set_environment("SteamAppID", str(480))
#	OS.set_environment("SteamGameID", str(480))


## Called when the node enters the scene tree.
## - Prints a debug message to confirm global load.
## - Configures integer display scaling based on the window size.
## - (Optional) Initializes Steamworks and fetches user information.
func _ready() -> void:
	print("Global script loaded")
	
	# --- Display scaling ---
	var base_size = Vector2i(640, 360)   # base logical resolution
	var window_size = DisplayServer.window_get_size()

	# Calculate integer scaling factor (avoid fractional scaling)
	var scale_x = floor(window_size.x / base_size.x)
	var scale_y = floor(window_size.y / base_size.y)
	var scale = min(scale_x, scale_y)

	if scale < 1:
		scale = 1

	# Apply scaling to root viewport
	get_tree().root.content_scale_size = base_size * scale
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	# --- Steamworks integration (commented out by default) ---
	# Steam.steamInit()
	# steam_id = Steam.getSteamID()
	# steam_username = Steam.getPersonaName()


# Called every frame.
# Runs Steam callbacks to keep the client updated.
# func _process(_delta):
#	Steam.run_callbacks()
