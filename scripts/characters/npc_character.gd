class_name NPCCharacter
extends CharacterBody2D

## Multiplayer & Performance
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
var is_awake: bool = false
var active_player_bubbles: int = 0

## States & Aussehen
@onready var state_machine: NodeStateMachine = $StateMachine
@onready var appearance: CharacterAppearance = $CharacterAppearance
@onready var specification: NpcSpecification = $NPCSpecificatioinsContainer

## Patrouillen-Daten
@onready var patrol_pause_timer: Timer = $PatrolPauseTimer
var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var patrol_direction: int = 1
var speed: float = 60.0
var pause_time: float = 2.0
var path_follower: PathFollow2D

var is_interacting: bool = false

var _last_anim: String
var facing_direction: Vector2 = Vector2.DOWN

enum PatrolBehavior { LOOP, PING_PONG, RANDOM, FOLLOW_PATH }
var patrol_behavior: PatrolBehavior = PatrolBehavior.LOOP

var _initialization_data: Dictionary
var force_fight_area: Area2D

var npc_data: Dictionary


# --- Godot Lebenszyklus-Funktionen ---

func _ready() -> void:
	# Verarbeite die Daten, bevor irgendetwas anderes passiert.
	if _initialization_data:
		_initialize_npc()
	
	# Lege den NPC schlafen, nachdem alles konfiguriert ist.
	go_to_sleep()
	state_machine.owner_actor = self
	patrol_pause_timer.timeout.connect(_on_patrol_pause_finished)


func _physics_process(_delta: float):
	if not is_awake:
		return

	# Der NPC führt einfach die Bewegung aus, die der aktive State in `velocity` geschrieben hat.
	move_and_slide()
	
	var current_velocity = get_real_velocity()
	if current_velocity.length_squared() > 0.1:
		facing_direction = current_velocity.normalized()
	
	# Der Host ist für die Animationen zuständig, basierend auf dem aktuellen Zustand und der Bewegung.
	if multiplayer.is_server():
		update_animation()


# --- Initialisierungs-Funktionen ---

func initialize_npc(data: Dictionary) -> void:
	self._initialization_data = data


func set_force_fight_area(force_fight_area_node: Area2D) -> void:
	self.force_fight_area = force_fight_area_node


func _initialize_npc() -> void:
	if _initialization_data.has("initial_position"):
		global_position = _initialization_data["initial_position"]
	if _initialization_data.has("patrol_points"):
		self.patrol_points = _initialization_data["patrol_points"]
	if _initialization_data.has("patrol_behavior"):
		self.patrol_behavior = _initialization_data["patrol_behavior"]
	if _initialization_data.has("npc_type") and _initialization_data.has("spawn_index"):
		var npc_type = _initialization_data['npc_type']
		var spawn_index = _initialization_data['spawn_index']
		specification.load_npc_enemy_data(npc_type, spawn_index)
		add_to_group("NPCs")

# --- Netzwerk- & Zustands-Funktionen ---

func wake_up():
	active_player_bubbles += 1
	if is_awake: return
	is_awake = true
	set_physics_process(true)
	multiplayer_synchronizer.set_process(true)
	state_machine.set_physics_process(true)
	match patrol_behavior: 
		PatrolBehavior.LOOP, PatrolBehavior.PING_PONG, PatrolBehavior.LOOP:
			if not patrol_points.is_empty():
				state_machine.transition_to("WalkNPC")
			else:
				state_machine.transition_to("IdleNPC")
		PatrolBehavior.FOLLOW_PATH:
			if is_instance_valid(path_follower): 
				state_machine.transition_to("WalkNPC")
			else:
				state_machine.transition_to("IdleNPC")
		_: 
			state_machine.transition_to("IdleNPC")


func go_to_sleep():
	active_player_bubbles -= 1
	if active_player_bubbles > 0 or not is_awake: return
	is_awake = false
	state_machine.transition_to("IdleNPC")
	set_physics_process(false)
	multiplayer_synchronizer.set_process(false)
	state_machine.set_physics_process(false)


# --- Patrouillen-Werkzeuge für States ---

func start_patrol_pause():
	# Nur der Host soll den Pausen-Timer starten.
	if is_multiplayer_authority():
		patrol_pause_timer.start(pause_time)


func _on_patrol_pause_finished():
	if state_machine.current_node_state_name == "FollowTargetNPC":
		return
	update_next_patrol_index()
	state_machine.transition_to("WalkNPC")


func update_next_patrol_index():
	match patrol_behavior:
		PatrolBehavior.LOOP:
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		PatrolBehavior.PING_PONG:
			if current_patrol_index >= patrol_points.size() - 1 and patrol_direction == 1:
				patrol_direction = -1
			elif current_patrol_index <= 0 and patrol_direction == -1:
				patrol_direction = 1
			current_patrol_index += patrol_direction
		PatrolBehavior.RANDOM:
			var new_index = current_patrol_index
			while new_index == current_patrol_index:
				new_index = randi() % patrol_points.size()
			current_patrol_index = new_index

# --- Animations-Logik & RPCs ---

func update_animation():
	var anim_prefix = "idle"
	var current_state = state_machine.current_node_state_name.to_lower()
	
	# Bestimme den Animations-Typ basierend auf dem State und der Bewegung
	if velocity.length_squared() > 0.1 and (current_state.contains("walk") or current_state.contains("follow")):
		anim_prefix = "walk"
	
	# Sende den Befehl zum Abspielen der Animation
	set_play_animation(anim_prefix + "_" + _dir_name(facing_direction))


func set_play_animation(anim_name: String) -> void:
	if anim_name != _last_anim:
		play_animation_rpc.rpc(anim_name)


# --- RPC ---

@rpc("any_peer", "call_local", "reliable")
func play_animation_rpc(anim: String) -> void:
	if anim == _last_anim and appearance.animation_player.is_playing():
		return
	_last_anim = anim
	if is_instance_valid(appearance):
		appearance.play(anim)


@rpc("any_peer", "call_local", "reliable")
func request_interaction(player_name: String):
	if not multiplayer.is_server():
		return
	
	var player_node = get_tree().get_root().get_node_or_null("Overworld/Players/" + player_name)
	
	if not is_instance_valid(player_node):
		printerr("Host: Konnte Spieler mit ID nicht finden: ", player_name)
		return 
	
	var interaction_range: float = 60.0 
	var dist_sq: float = player_node.global_position.distance_squared_to(global_position)
	
	if dist_sq <= interaction_range * interaction_range:
		print("Host: Interaktion von Spieler ", player_name, " mit ", self.name, " genehmigt.")
		is_interacting = true
		state_machine.transition_to('IdleNPC')
		var peer_id_to_reply_to = player_node.get_multiplayer_authority()
		player_node.sync.interaction_approved.rpc_id(peer_id_to_reply_to, self.npc_data, self.get_path())
	else:
		print("Host: Interaktion von Spieler ", player_name, " mit ", self.name, " abgelehnt (Distanz).")


@rpc("any_peer", "call_local", "reliable")
func end_interaction():
	if not multiplayer.is_server():
		return
		
	if not is_interacting:
		return
		
	print("Host: ", self.name, " beendet Interaktion.")
	is_interacting = false 
	
	if is_awake:
		# Hat er eine Patrouillenroute?
		if not patrol_points.is_empty() or is_instance_valid(path_follower):
			print("Host: ", self.name, " setzt Patrouille fort.")
			# Ja -> Wechsle zurück in den Walk-State
			state_machine.transition_to("WalkNPC")
		else:
			# Nein -> Bleibe im Idle-State (aber wach)
			state_machine.transition_to("IdleNPC")
	else:
		# Wenn der NPC eigentlich schlafen sollte (keine Spieler mehr da),
		# sorge dafür, dass er auch wirklich schläft.
		go_to_sleep()


# --- Hilfsfunktionen ---

func facing_dir() -> Vector2:
	return facing_direction


func _dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	else:
		return "front" if v.y >= 0.0 else "back"
