extends MultiplayerSpawner

@export var playerScene: PackedScene
var players := {}

# Funktion, die entscheidet, wie ein Player gespawnt wird
#var spawn_function: Callable

func _ready() -> void:
	spawn_function = spawnPlayer

	if is_multiplayer_authority():
		# Host selbst spawnen
		spawn(multiplayer.get_unique_id())
		# Auf neue Peers reagieren
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# ---------------- Spawn / Remove ----------------
func spawnPlayer(peer_id: int) -> Node:
	var p = playerScene.instantiate()
	p.set_multiplayer_authority(peer_id)
	players[peer_id] = p

	# Optional: Player ins aktuelle Level einfügen
	var level = get_tree().current_scene
	level.add_child(p)

	return p

func removePlayer(peer_id: int) -> void:
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)

# ---------------- Callbacks ----------------
func _on_peer_connected(peer_id: int) -> void:
	if spawn_function:
		spawn_function.call(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	removePlayer(peer_id)
