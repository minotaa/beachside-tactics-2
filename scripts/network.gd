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

func update_player_save_data(id: int, mutator: Callable) -> void:
	for player in players:
		if player["id"] == id:
			mutator.call(player["save_data"])
			sync_save_data.rpc_id(id, player["save_data"])
			return

func get_player_save_data(id: int) -> Dictionary:
	for player in players:
		if player["id"] == id:
			return player["save_data"]
	return {}

@rpc("any_peer", "call_remote", "reliable")
func request_buy_item(item_id: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	var item = Catalog.get_item(item_id)

	if item == null:
		purchase_rejected.rpc_id(id, "That item doesn't exist.")
		return

	for player in players:
		if player["id"] != id:
			continue

		var save_data = player["save_data"]

		if item.price > save_data.get("balance", 0.0):
			purchase_rejected.rpc_id(id, "You don't have enough money for this!")
			return

		if item.purchase_limit != -1:
			var owned_amount := 0
			for entry in save_data.get("inventory", []):
				if entry.get("id") == item_id:
					owned_amount = entry.get("amount", 0)
					break
			if owned_amount >= item.purchase_limit:
				purchase_rejected.rpc_id(id, "You already have too many of this item!")
				return

		var added_amount = 8 if item.category == Game.Category.BAIT else 1

		update_player_save_data(id, func(sd):
			var inv := Inventory.new()

			inv.set_list_from_save(sd.get("inventory", []))
			inv.add_item(ItemStack.new(item, added_amount))
			sd["inventory"] = inv.to_list()
			sd["balance"] = sd.get("balance", 0.0) - item.price
		)
		purchase_confirmed.rpc_id(id, item_id, added_amount)
		return

@rpc("authority", "call_remote", "reliable")
func purchase_rejected(reason: String) -> void:
	Toast.add(reason)

@rpc("authority", "call_remote", "reliable")
func purchase_confirmed(item_id: int, amount: int) -> void:
	var item = Catalog.get_item(item_id)
	Game.play_sfx("res://assets/sounds/cashregister.ogg", 1.5)
	Toast.add("You bought: " + str(amount) + "x " + str(item.name) + "!")
	var local_player = Game.get_player()
	if local_player:
		local_player.update_catalog()
		local_player.select_item(item_id, true)

@rpc("authority", "call_remote", "reliable")
func sync_save_data(save_data: Dictionary) -> void:
	Game.apply_save(save_data)
	Game.save_game("saved")

@rpc("any_peer", "unreliable_ordered", "call_remote")
func relay_player_state(pos: Vector2, direction: String, animation: String, moving: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] != id:
			_forward_player_state.rpc_id(player["id"], id, pos, direction, animation, moving)

@rpc("authority", "unreliable_ordered", "call_remote")
func _forward_player_state(id: int, pos: Vector2, direction: String, animation: String, moving: bool) -> void:
	if spawned_players.has(id):
		spawned_players[id].apply_network_state(pos, direction, animation, moving)

func _tick_trap(id: int, save_data: Dictionary, trap_data: Dictionary, delta: float) -> void:
	var trap := Catalog.get_item(trap_data["trap"]) as Trap
	var trap_inventory := Inventory.new()
	trap_inventory.set_list_from_save(trap_data["inventory"])
	var bait_inventory := Inventory.new()
	bait_inventory.set_list_from_save(trap_data["bait_inventory"])

	var speed_bonus = trap.fishing_speed
	if bait_inventory.total_size() > 0:
		speed_bonus += (bait_inventory.get_item(0).type as Bait).extra_fishing_speed * 0.5

	trap_data["timer"] = trap_data.get("timer", Game.BASE_CATCH_TIME) - (delta + (sqrt(speed_bonus) * 3.5) * 0.001)

	if trap_data["timer"] < 0.0:
		trap_data["timer"] = Game.BASE_CATCH_TIME
		if trap_inventory.total_size() < trap.space:
			var fish = Catalog.get_fish(trap_data["location"], trap.fishing_power, true)
			trap_inventory.add_item(ItemStack.new(fish, 1))
			if bait_inventory.total_size() > 0:
				bait_inventory.take_item(bait_inventory.get_item(0).type, 1)
			trap_data["inventory"] = trap_inventory.to_list()
			trap_data["bait_inventory"] = bait_inventory.to_list()
			sync_save_data.rpc_id(id, save_data)
			var is_full := trap_inventory.total_size() >= trap.space
			relay_trap_data.rpc_id(id, trap_data["id"], is_full)
			trap_data_updated.rpc_id(id, trap_data)

@rpc("any_peer", "call_remote", "reliable")
func request_trap_data(trap_id: int) -> void:
	var id = multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] == id:
			for trap_data in player["save_data"].get("traps", []):
				if trap_data["id"] == trap_id:
					received_trap_data.rpc_id(id, trap_data)
					return
	Toast.add.rpc_id(id, "Couldn't find this specific trap.")

@rpc("authority", "call_remote", "reliable")
func received_trap_data(trap_data: Dictionary) -> void:
	var p = Game.get_player()
	p.get_node("UI/Main").visible = false
	p.get_node("UI/Trap").visible = true
	p.last_trap = trap_data
	p.open_trap_id = trap_data["id"]
	p.update_trap()

@rpc("authority", "call_remote", "reliable")
func trap_data_updated(trap_data: Dictionary) -> void:
	var p = Game.get_player()
	if p == null:
		return
	if p.open_trap_id == trap_data["id"] and p.get_node("UI/Trap").visible:
		p.last_trap = trap_data
		p.update_trap()

@rpc("authority", "call_remote", "reliable")
func relay_trap_data(id: int, is_full: bool) -> void:
	var trap_node = get_tree().current_scene.get_node_or_null(str(id))
	if trap_node == null:
		return
	trap_node.emit_signal("trap_updated")
	trap_node.get_node("InteractionMark").visible = is_full
	trap_node.get_node("InteractionMark/Fish").visible = is_full

# spawn funcs
@rpc("any_peer", "call_remote", "reliable")
func place_trap(x: float, y: float, location: Game.Location) -> void:
	var id = multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] == id:
			var save_data = player["save_data"]
			if save_data.get("traps", null) != null and save_data["traps"].size() >= Game.get_max_traps():
				Toast.add.rpc_id(id, "You have too many traps down!")
				return
			var equipped_trap = save_data.get("equipped_trap", null)
			if equipped_trap == null or Catalog.get_item(equipped_trap) == null or not Catalog.get_item(equipped_trap) is Trap:
				Toast.add.rpc_id(id, "You're not holding a trap!")
				return
			for existing_trap in save_data.get("traps", []):
				if existing_trap["x"] == x and existing_trap["y"] == y:
					Toast.add.rpc_id(id, "There's already a trap there!")
					return
			var inventory = Inventory.new()
			var equipped_trap_item = Catalog.get_item(equipped_trap)
			inventory.set_list_from_save(save_data.get("inventory", []))
			inventory.take_item(Catalog.get_item(equipped_trap_item.id), 1)
			save_data["inventory"] = inventory.to_list()
			save_data["equipped_trap"] = null
			
			var trap_data = {
				"id": randi(),
				"x": x,
				"y": y,
				"location": location,
				"inventory": Inventory.new().to_list(),
				"bait_inventory": Inventory.new().to_list(),
				"trap": equipped_trap_item.id,
				"timer": Game.BASE_CATCH_TIME
			}
			save_data["traps"].append(trap_data)
			Toast.add.rpc_id(id, "You placed down a: " + equipped_trap_item.name + "!")
			spawn_trap.rpc_id(id, trap_data)
			sync_save_data.rpc_id(id, save_data)

@rpc("authority", "call_remote", "reliable")
func spawn_trap(trap: Dictionary) -> void:
	print("spawning trap at x:" + str(trap["x"]) + ", y:" + str(trap["y"]))
	var placed_trap = preload("res://scenes/trap.tscn").instantiate()
	placed_trap.global_position = Vector2(trap["x"], trap["y"])
	placed_trap.name = str(trap["id"])
	placed_trap.trap = trap["trap"]
	get_tree().current_scene.add_child(placed_trap)

@rpc("any_peer", "call_remote", "reliable")
func client_scene_ready() -> void:
	var id = multiplayer.get_remote_sender_id()
	var new_player_pos = _get_spawn_position(id)
	spawn_player.rpc(id, new_player_pos)
	
	var save_data = get_player_save_data(id)
	var traps = []
	for trap in save_data["traps"]:
		var trap_object = {}
		var trap_inventory = Inventory.new()
		var bait_inventory = Inventory.new()
		trap_inventory.set_list_from_save(trap["inventory"])
		bait_inventory.set_list_from_save(trap["bait_inventory"])
		trap_object["inventory"] = trap_inventory
		trap_object["bait_inventory"] = bait_inventory
		trap_object["x"] = trap["x"]
		trap_object["y"] = trap["y"]
		trap_object["location"] = trap["location"]
		trap_object["trap"] = trap["trap"]
		trap_object["timer"] = trap["timer"]
		trap_object["id"] = trap["id"]
		traps.append(trap_object)
	for trap in traps:
		spawn_trap.rpc_id(id, trap)
	
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

# process
func _process(delta: float) -> void:
	for player in players:
		var save_data = player["save_data"]
		if not save_data.has("traps"):
			continue
		for trap_data in save_data["traps"]:
			_tick_trap(player["id"], save_data, trap_data, delta)
