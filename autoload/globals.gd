extends Node

## Global Script
##
## Autoload for shared game state placeholders and optional Steam hooks.
## Display scaling is configured in project.godot:
## canvas_items + aspect keep (fractional scale fills the window), Nearest texture filter.
##
## Usage:
## - Registered as Autoload `Globals` in Project Settings.
## - Uncomment Steam-related code to enable Steamworks integration.

## Steam user ID (assigned after successful Steam init).
var steam_id: int

## Steam display name of the current user.
var steam_username: String

## Number of members in the current Steam lobby.
var steam_lobby_member: int = 0

## Steam AppID (default 480 = Spacewar test ID).
var steamAppId: int = 480

## Steam GameID (default 480 = Spacewar test ID).
var steamGameId: int = 480


func _ready() -> void:
	print("Global script loaded")
