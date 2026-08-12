extends Node

var PORT: int = 6466
const DEFAULT_SERVER_IP: String = "127.0.0.1"
const MAX_PLAYERS: int = 9
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var players = []
var player_name: String
var spawned_players: Dictionary = {} # peer_id -> Node

signal player_joined(peer_id)
signal update_players(players)
signal player_quit(peer_id)
signal local_player_spawned

# conn funcs
func join_server(address: String, username: String = "Player") -> bool:
	if not username.is_valid_identifier():
		username = "Player"
	player_name = username
	if address == "localhost":
		address = "127.0.0.1"
	var split_address = address.split(":")
	var valid_address: String
	var port: int
	if split_address.size() == 1:
		valid_address = split_address[0]
		port = PORT
	elif split_address.size() > 2:
		print("Too many address segments")
		return false
	else:
		valid_address = split_address[0]
		port = split_address[1].to_int()

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(valid_address, port)
	print("Connecting to " + valid_address + ":" + str(port))
	if error != OK:
		print("Error occurred while connecting: " + str(error))
		return false

	multiplayer.multiplayer_peer = peer
	if multiplayer.server_disconnected.is_connected(server_disconnected):
		multiplayer.server_disconnected.disconnect(server_disconnected)
	multiplayer.server_disconnected.connect(server_disconnected)
	if multiplayer.connection_failed.is_connected(connection_failed):
		multiplayer.connection_failed.disconnect(connection_failed)
	multiplayer.connection_failed.connect(connection_failed)

	# Wait a moment for connection to establish
	var ticks = 0
	var max_ticks = 50 # 5 seconds
	while multiplayer.multiplayer_peer != null and (not multiplayer.multiplayer_peer.get_connection_status() == 2 or multiplayer.get_unique_id() == 1):
		if ticks >= max_ticks:
			Toast.add("Timed out.")
			print("Timed out, reached maximum ticks.")
			return false
		print("Stalling...")
		ticks += 1
		await get_tree().create_timer(0.1).timeout

	if multiplayer.multiplayer_peer == null:
		return false

	temporary_save_data_sending_mechanic_probably_shouldnt_use_this.rpc_id(1, Game.get_save_data())

	print("[" + str(multiplayer.get_unique_id()) + "] Connected to the server")
	return true

func host_server(port: int) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("Error while starting server: " + str(error))
		Toast.add("An error occurred while starting server.")
		return false

	print("Created server with IP " + DEFAULT_SERVER_IP + " on port " + str(PORT))
	multiplayer.multiplayer_peer = peer
	if multiplayer.peer_connected.is_connected(_player_joined):
		multiplayer.peer_connected.disconnect(_player_joined)
	multiplayer.peer_connected.connect(_player_joined)
	if multiplayer.peer_disconnected.is_connected(_player_quit):
		multiplayer.peer_disconnected.disconnect(_player_quit)
	multiplayer.peer_disconnected.connect(_player_quit)

	# Host DOES not join as ID 1, Woah.

	return true

# server funcs
@rpc("authority", "call_local", "reliable")
func server_player_joined(id: int) -> void:
	print("[" + str(multiplayer.get_unique_id()) + "] [client] Player joined: " + str(id))
	player_joined.emit(id)

	if multiplayer.get_unique_id() == 1:
		# no levels yet so only load the one level we got lol
		load_scene.rpc_id(id, "res://scenes/levels/beach.tscn")

@rpc("authority", "call_local", "reliable")
func server_player_quit(id: int) -> void:
	print("[" + str(multiplayer.get_unique_id()) + "] [client] Player quit: " + str(id))
	player_quit.emit(id)

@rpc("authority", "call_local", "reliable")
func load_scene(scene: String) -> void:
	await Fade.fade_out()

	var new_scene = load(scene).instantiate()
	get_tree().current_scene.free()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	if multiplayer.get_unique_id() != 1:
		local_player_spawned.connect(_on_local_player_spawned, CONNECT_ONE_SHOT)
		client_scene_ready.rpc_id(1)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func relay_player_state(pos: Vector2, direction: String, moving: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] != id:
			_forward_player_state.rpc_id(player["id"], id, pos, direction, moving)

@rpc("authority", "unreliable_ordered", "call_remote")
func _forward_player_state(id: int, pos: Vector2, direction: String, moving: bool) -> void:
	if spawned_players.has(id):
		spawned_players[id].apply_network_state(pos, direction, moving)

# spawn funcs
@rpc("any_peer", "call_remote", "reliable")
func client_scene_ready() -> void:
	var id = multiplayer.get_remote_sender_id()
	var new_player_pos = _get_spawn_position(id)
	spawn_player.rpc(id, new_player_pos)
	for player in players:
		if player["id"] != id:
			var pos = _get_spawn_position(player["id"])
			spawn_player.rpc_id(id, player["id"], pos)

func _on_local_player_spawned() -> void:
	await Fade.fade_in()

func _get_spawn_position(id: int) -> Vector2:
	for player in players:
		if player["id"] == id:
			var save_data = player.get("save_data", {})
			var island = save_data.get("last_island", null)
			if island != null and Game.SPAWN_POINTS.has(island):
				return Game.SPAWN_POINTS[island]
			break
	return Vector2.ZERO

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, spawn_position: Vector2) -> void:
	if multiplayer.get_unique_id() == 1:
		return
	if spawned_players.has(id):
		return
	var instance = PLAYER_SCENE.instantiate()
	instance.name = str(id)
	instance.position = spawn_position
	get_tree().current_scene.add_child(instance, true)
	instance.set_multiplayer_authority(id)
	spawned_players[id] = instance
	
	if id == multiplayer.get_unique_id():
		local_player_spawned.emit()

@rpc("authority", "call_local", "reliable")
func despawn_player(id: int) -> void:
	if spawned_players.has(id):
		spawned_players[id].queue_free()
		spawned_players.erase(id)

# client funcs
func _player_joined(id: int) -> void:
	print("[server] Player joined with ID " + str(id))
	server_player_joined.rpc(id)

func _player_quit(id: int) -> void:
	print("[server] Player quit with ID " + str(id))
	for player in players:
		if str(player["id"]) == str(id):
			Toast.add.rpc(player["username"] + " left the server!")
	players = players.filter(func(p): return p["id"] != id)
	despawn_player.rpc(id)
	player_quit.emit(id)
	server_player_quit.rpc(id)

@rpc("any_peer", "call_remote", "reliable")
func temporary_save_data_sending_mechanic_probably_shouldnt_use_this(save_data: Dictionary) -> void:
	players.append({
		"id": multiplayer.get_remote_sender_id(),
		"save_data": save_data
	})

func server_disconnected() -> void:
	print("Disconnected from server")
	Toast.add("Disconnected from the server.")
	spawned_players.clear()
	players.clear()
	if multiplayer.server_disconnected.is_connected(server_disconnected):
		multiplayer.server_disconnected.disconnect(server_disconnected)
	multiplayer.server_disconnected.connect(server_disconnected)
	if multiplayer.connection_failed.is_connected(connection_failed):
		multiplayer.connection_failed.disconnect(connection_failed)
	multiplayer.connection_failed.connect(connection_failed)

func connection_failed() -> void:
	print("Connection failed")
	Toast.add("Connection failed.")
	if multiplayer.server_disconnected.is_connected(server_disconnected):
		multiplayer.server_disconnected.disconnect(server_disconnected)
	multiplayer.server_disconnected.connect(server_disconnected)
	if multiplayer.connection_failed.is_connected(connection_failed):
		multiplayer.connection_failed.disconnect(connection_failed)
	multiplayer.connection_failed.connect(connection_failed)
