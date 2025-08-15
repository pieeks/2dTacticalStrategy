#extends MultiplayerSpawner
#
#@export var playerScene: PackedScene
#var players := {}
#
## Funktion, die entscheidet, wie ein Player gespawnt wird
##var spawn_function: Callable
#
#func _ready() -> void:
	#spawn_function = spawnPlayer
#
	#if is_multiplayer_authority():
		## Host selbst spawnen
		#spawn(multiplayer.get_unique_id())
		## Auf neue Peers reagieren
		#multiplayer.peer_connected.connect(_on_peer_connected)
		#multiplayer.peer_disconnected.connect(_on_peer_disconnected)
#
## ---------------- Spawn / Remove ----------------
#func spawnPlayer(peer_id: int) -> Node:
	#var p = playerScene.instantiate()
	#p.set_multiplayer_authority(peer_id)
	#players[peer_id] = p
#
	## Optional: Player ins aktuelle Level einfügen
	#var level = get_tree().current_scene
	#level.add_child(p)
#
	#return p
#
#func removePlayer(peer_id: int) -> void:
	#if players.has(peer_id):
		#players[peer_id].queue_free()
		#players.erase(peer_id)
#
## ---------------- Callbacks ----------------
#func _on_peer_connected(peer_id: int) -> void:
	#if spawn_function:
		#spawn_function.call(peer_id)
#
#func _on_peer_disconnected(peer_id: int) -> void:
	#removePlayer(peer_id)
	#
	# MultiplayerSpawner.gd
	
	
extends MultiplayerSpawner

@export var playerScene: PackedScene
var players := {}

func _ready() -> void:
	spawn_function = spawnPlayer
	# keine Multiplayer-Initialisierung hier, nur Setup für Spawner

# Öffentliche Funktion für NetworkManager
func setup_multiplayer(peer_id: int) -> void:
	if is_multiplayer_authority():
		# Host selbst spawnen
		spawn(peer_id)
		# auf Peers reagieren
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func spawnPlayer(id: int) -> void:
	if players.has(id):
		return  # Spieler existiert schon

	var p = playerScene.instantiate()
	p.set_multiplayer_authority(id)
	get_tree().current_scene.add_child(p)
	players[id] = p

#func spawnPlayer(data = null) -> Node:
	#var id = data
	#if data is Dictionary:
		#id = data.get("id", multiplayer.get_unique_id())
	#
	#var player = playerScene.instantiate()
	#player.set_multiplayer_authority(id)
	#players[id] = player
	#get_tree().current_scene.add_child(player)
	#return player

func removePlayer(peer_id: int) -> void:
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)

func _on_peer_connected(peer_id: int) -> void:
	if spawn_function:
		spawn_function.call(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	removePlayer(peer_id)
