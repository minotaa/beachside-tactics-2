extends Node

var PORT: int = 6466
const DEFAULT_SERVER_IP: String = "127.0.0.1"
const MAX_PLAYERS: int = 9
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var fishing_players = []
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

	temporary_save_data_sending_mechanic_probably_shouldnt_use_this.rpc_id(1, username, Game.get_save_data())

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
func request_sell_all(id: int = -1) -> void:
	id = multiplayer.get_remote_sender_id()
	var save_data = get_player_save_data(id)
	if save_data.is_empty():
		return

	var bag := Inventory.new()
	bag.set_list_from_save(save_data.get("bag", []))

	var amount_earned := 0.0
	var to_remove := []
	for item in bag.list:
		if item.type.category == Game.Category.FISH or item.type.category == Game.Category.JUNK:
			var mult = 1.0
			match int(item.data.get("stars", 0)):
				1: mult = 1.25
				2: mult = 1.5
				3: mult = 2.0
			amount_earned += item.amount * item.type.sell_price * mult
			to_remove.append(item)

	if to_remove.is_empty():
		return

	for item in to_remove:
		bag.remove_item(item)

	save_data["bag"] = bag.to_list()
	save_data["balance"] = save_data.get("balance", 0.0) + amount_earned

	sync_save_data.rpc_id(id, save_data)
	sell_all_confirmed.rpc_id(id, amount_earned)

@rpc("authority", "call_remote", "reliable")
func sell_all_confirmed(amount_earned: float) -> void:
	Game.play_sfx("res://assets/sounds/cashregister.ogg", 1.5)
	Toast.add("Sold all your fish and earned $" + str(roundi(amount_earned)) + "!")
	var player = Game.get_player()
	if player != null and player.get_node("UI/Vendor").visible:
		player.update_catalog()
		
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
			for entry in save_data.get("upgrades", []):
				if entry.get("id") == item_id:
					owned_amount = entry.get("amount", 0)
					break		
			if owned_amount >= item.purchase_limit:
				purchase_rejected.rpc_id(id, "You already have too many of this item!")
				return

		if item is Upgrade:
			var upgrades = Inventory.new()
			upgrades.set_list_from_save(save_data["upgrades"])
			if upgrades.has_item(item):
				var stack = upgrades.get_item_stack(item)
				if stack.data["level"] >= item.max_level:
					purchase_rejected.rpc_id(id, "You already have this upgrade maxed out!")
					return
				stack.data["level"] = stack.data["level"] + 1
				save_data["upgrades"] = upgrades.to_list()
				save_data["balance"] -= item.price
				purchase_confirmed_upgrade.rpc_id(id, item.id, stack.data["level"])
				sync_save_data.rpc_id(id, save_data)
			else:
				if item.max_level <= 0:
					purchase_rejected.rpc_id(id, "This item cannot be purchased.")
					return
				var stack = ItemStack.new(item, 1)
				stack.data["level"] = 1
				save_data["balance"] -= item.price
				upgrades.add_item(stack)
				save_data["upgrades"] = upgrades.to_list()
				purchase_confirmed_upgrade.rpc_id(id, item.id, stack.data["level"])
				sync_save_data.rpc_id(id, save_data)
		else:
			var added_amount = 8 if item.category == Game.Category.BAIT else 1
			var equipped_the_item = false
			update_player_save_data(id, func(sd):
				var inv := Inventory.new()

				inv.set_list_from_save(sd.get("inventory", []))
				inv.add_item(ItemStack.new(item, added_amount))
				if sd["equipped_bait"] == null and item is Bait:
					sd["equipped_bait"] = item.id
					equipped_the_item = true
				sd["inventory"] = inv.to_list()
				sd["balance"] = sd.get("balance", 0.0) - item.price
			)
			purchase_confirmed.rpc_id(id, item_id, added_amount, equipped_the_item)
		return

@rpc("authority", "call_remote", "reliable")
func purchase_rejected(reason: String) -> void:
	Toast.add(reason)

@rpc("authority", "call_remote", "reliable")
func purchase_confirmed_upgrade(item_id: int, level: int) -> void:
	var item = Catalog.get_item(item_id)
	Game.play_sfx("res://assets/sounds/cashregister.ogg", 1.5)
	Toast.add("You bought: " + str(item.name) + " " + str(Game.to_roman(level)) + "!")
	var local_player = Game.get_player()
	if local_player:
		local_player.update_catalog()
		local_player.select_item(item_id, true)

@rpc("authority", "call_remote", "reliable")
func purchase_confirmed(item_id: int, amount: int, equipped: bool = false) -> void:
	var item = Catalog.get_item(item_id)
	Game.play_sfx("res://assets/sounds/cashregister.ogg", 1.5)
	if not equipped:
		Toast.add("You bought: " + str(amount) + "x " + str(item.name) + "!")
	else:
		Toast.add("You bought and equipped: " + str(amount) + "x " + str(item.name) + "!")
	var local_player = Game.get_player()
	if local_player:
		local_player.update_catalog()
		local_player.select_item(item_id, true)

const TROPHY_TURTLE_IDS = {
	"regular": 29,
	"day": 30,
	"night": 31,
	"trap": 32,
	"glitch": 33,
}

@rpc("any_peer", "call_remote", "reliable")
func request_turn_in_trophy_turtle() -> void:
	var id := multiplayer.get_remote_sender_id()
	var save_data = get_player_save_data(id)
	if save_data.is_empty():
		return

	var flags = save_data.get("flags", {})
	var bag := Inventory.new()
	bag.set_list_from_save(save_data.get("bag", []))

	var turtle_key := ""
	var turtle_item = null
	for key in TROPHY_TURTLE_IDS.keys():
		if flags.get("trophy_%s_caught" % key, false):
			continue
		var item = Catalog.get_item(TROPHY_TURTLE_IDS[key])
		if bag.has_item(item):
			turtle_key = key
			turtle_item = item
			break

	if turtle_key == "":
		return

	bag.take_item(turtle_item, 1)
	save_data["bag"] = bag.to_list()

	flags["trophy_%s_caught" % turtle_key] = true
	save_data["flags"] = flags

	save_data["balance"] = save_data.get("balance", 0.0) + 500.0
	var levels_gained = Game.apply_xp(save_data, 50)

	sync_save_data.rpc_id(id, save_data)
	if levels_gained > 0:
		notify_level_up.rpc_id(id, save_data["level"])
	trophy_turtle_turned_in.rpc_id(id)

@rpc("authority", "call_remote", "reliable")
func trophy_turtle_turned_in() -> void:
	Toast.add("You received $500 and 50 XP!")

@rpc("authority", "call_remote", "reliable")
func sync_save_data(save_data: Dictionary) -> void:
	print("[client] sync_save_data: xp=", save_data.get("xp", 0.0), " level=", save_data.get("level", 1), " balance=", save_data.get("balance", 0.0), " bag_size=", save_data.get("bag", []).size())
	Game.apply_save(save_data)
	Game.save_game("saved")

const EQUIP_SLOTS = ["equipped_trap", "equipped_bait", "equipped_fishing_rod"]

@rpc("any_peer", "call_remote", "reliable")
func request_equip(slot: String, item_id) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not EQUIP_SLOTS.has(slot):
		return
	var save_data = get_player_save_data(id)
	if save_data.is_empty():
		return

	if item_id != null:
		var item = Catalog.get_item(item_id)
		if item == null:
			return
		var inv := Inventory.new()
		inv.set_list_from_save(save_data.get("inventory", []))
		if not inv.has_item(item):
			return # can't equip something you don't own

	save_data[slot] = item_id
	sync_save_data.rpc_id(id, save_data)

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
			var fish = Catalog.get_fish(trap_data["location"], trap.fishing_power, save_data, true)
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

func _find_trap(save_data: Dictionary, trap_id: int) -> Dictionary:
	for trap_data in save_data.get("traps", []):
		if trap_data["id"] == trap_id:
			return trap_data
	return {}

@rpc("any_peer", "call_remote", "reliable")
func request_insert_bait(trap_id: int, item_id: int, amount: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] != id:
			continue
		var save_data = player["save_data"]
		var trap_data = _find_trap(save_data, trap_id)
		if trap_data.is_empty():
			Toast.add.rpc_id(id, "Couldn't find this trap.")
			return
		var item = Catalog.get_item(item_id)
		if item == null or not item is Bait:
			Toast.add.rpc_id(id, "That's not bait.")
			return
		var trap := Catalog.get_item(trap_data["trap"]) as Trap
		var bait_inventory := Inventory.new()
		bait_inventory.set_list_from_save(trap_data["bait_inventory"])
		if bait_inventory.total_size() + amount > trap.bait_storage:
			Toast.add.rpc_id(id, "The trap's bait storage is full!")
			return
		var player_inventory := Inventory.new()
		player_inventory.set_list_from_save(save_data.get("inventory", []))
		var owned = player_inventory.get_item_stack(item)
		if owned == null or owned.amount < amount:
			Toast.add.rpc_id(id, "You don't have enough of that bait.")
			return
		player_inventory.take_item(item, amount)
		bait_inventory.add_item(ItemStack.new(item, amount))
		save_data["inventory"] = player_inventory.to_list()
		trap_data["bait_inventory"] = bait_inventory.to_list()
		sync_save_data.rpc_id(id, save_data)
		trap_ui_confirmed.rpc_id(id, trap_data, "res://assets/sounds/squelch.ogg")
		return

@rpc("any_peer", "call_remote", "reliable")
func request_remove_bait(trap_id: int, item_id: int, amount: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] != id:
			continue
		var save_data = player["save_data"]
		var trap_data = _find_trap(save_data, trap_id)
		if trap_data.is_empty():
			Toast.add.rpc_id(id, "Couldn't find this trap.")
			return
		var item = Catalog.get_item(item_id)
		if item == null:
			return
		var bait_inventory := Inventory.new()
		bait_inventory.set_list_from_save(trap_data["bait_inventory"])
		var owned = bait_inventory.get_item_stack(item)
		if owned == null or owned.amount < amount:
			Toast.add.rpc_id(id, "The trap doesn't have that much bait.")
			return
		bait_inventory.take_item(item, amount)
		var player_inventory := Inventory.new()
		player_inventory.set_list_from_save(save_data.get("inventory", []))
		player_inventory.add_item(ItemStack.new(item, amount))
		save_data["inventory"] = player_inventory.to_list()
		trap_data["bait_inventory"] = bait_inventory.to_list()
		sync_save_data.rpc_id(id, save_data)
		trap_ui_confirmed.rpc_id(id, trap_data, "")
		return

@rpc("authority", "call_remote", "reliable")
func notify_level_up(new_level: int) -> void:
	Toast.add("You leveled up! You are now Level %d!" % new_level)
	Game.play_sfx("res://assets/sounds/levelup.ogg", -8.0)

var xp_table := {
	Game.Rarity.COMMON:    50.0,
	Game.Rarity.UNCOMMON:  100.0,
	Game.Rarity.RARE:      750.0,
	Game.Rarity.EPIC:      2000.0,
	Game.Rarity.LEGENDARY: 7500.0
}

@rpc("any_peer", "call_remote", "reliable")
func request_collect_from_trap(trap_id: int, item_id: int, amount: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] != id:
			continue
		var save_data = player["save_data"]
		var trap_data = _find_trap(save_data, trap_id)
		if trap_data.is_empty():
			Toast.add.rpc_id(id, "Couldn't find this trap.")
			return
		var item = Catalog.get_item(item_id)
		if item == null:
			return
		var trap_inventory := Inventory.new()
		trap_inventory.set_list_from_save(trap_data["inventory"])
		var owned = trap_inventory.get_item_stack(item)
		if owned == null or owned.amount < amount:
			Toast.add.rpc_id(id, "The trap doesn't have that much.")
			return
		var bag := Inventory.new()
		bag.set_list_from_save(save_data.get("bag", []))
		if not bag.would_fit(ItemStack.new(item, amount), Game.get_max_inventory_size(save_data)):
			Toast.add.rpc_id(id, "Your tackle box doesn't have enough space!")
			return
		trap_inventory.take_item(item, amount)
		bag.add_item(ItemStack.new(item, amount))
		trap_data["inventory"] = trap_inventory.to_list()
		save_data["bag"] = bag.to_list()
		save_data["catches"] = save_data.get("catches", 0) + amount
		var levels_gained = Game.apply_xp(save_data, (xp_table.get(item.rarity, 0.0) * amount))
		if levels_gained > 0:
			notify_level_up.rpc_id(id, save_data["level"])
		sync_save_data.rpc_id(id, save_data)
		trap_ui_confirmed.rpc_id(id, trap_data, "")
		return

@rpc("any_peer", "call_remote", "reliable")
func request_collect_all_from_trap(trap_id: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] != id:
			continue
		var save_data = player["save_data"]
		var trap_data = _find_trap(save_data, trap_id)
		if trap_data.is_empty():
			Toast.add.rpc_id(id, "Couldn't find this trap.")
			return
		var trap_inventory := Inventory.new()
		trap_inventory.set_list_from_save(trap_data["inventory"])
		var bag := Inventory.new()
		bag.set_list_from_save(save_data.get("bag", []))
		var xp_gain := 0.0
		var full := false
		for item_stack in trap_inventory.list.duplicate():
			if bag.would_fit(ItemStack.new(item_stack.type, item_stack.amount), Game.get_max_inventory_size(save_data)):
				trap_inventory.take_item(item_stack.type, item_stack.amount)
				bag.add_item(ItemStack.new(item_stack.type, item_stack.amount))
				save_data["catches"] = save_data.get("catches", 0) + item_stack.amount
				xp_gain += xp_table.get(item_stack.type.rarity, 0.0) * item_stack.amount
			else:
				full = true
		trap_data["inventory"] = trap_inventory.to_list()
		save_data["bag"] = bag.to_list()
		var levels_gained = Game.apply_xp(save_data, xp_gain)
		if levels_gained > 0:
			notify_level_up.rpc_id(player["id"], save_data["level"])
		sync_save_data.rpc_id(id, save_data)
		if full:
			Toast.add.rpc_id(id, "Your tackle box is full, some fish were left behind!")
		trap_ui_confirmed.rpc_id(id, trap_data, "")
		return
		
@rpc("any_peer", "call_remote", "reliable")
func request_pickup_trap(trap_id: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	for player in players:
		if player["id"] != id:
			continue
		var save_data = player["save_data"]
		var trap_data = _find_trap(save_data, trap_id)
		if trap_data.is_empty():
			Toast.add.rpc_id(id, "Couldn't find this trap.")
			return
		var trap_inventory := Inventory.new()
		trap_inventory.set_list_from_save(trap_data["inventory"])
		var bag := Inventory.new()
		bag.set_list_from_save(save_data.get("bag", []))
		if not bag.would_fit_all(trap_inventory, Game.get_max_inventory_size(save_data)):
			Toast.add.rpc_id(id, "Your tackle box doesn't have enough space to pick up this trap!")
			return
		trap_inventory.transfer_limited_to(bag, Game.get_max_inventory_size(save_data))
		var player_inventory := Inventory.new()
		player_inventory.set_list_from_save(save_data.get("inventory", []))
		var bait_inventory := Inventory.new()
		bait_inventory.set_list_from_save(trap_data["bait_inventory"])
		bait_inventory.transfer_all_to(player_inventory)
		var trap_item := Catalog.get_item(trap_data["trap"])
		player_inventory.add_item(ItemStack.new(trap_item, 1))
		save_data["bag"] = bag.to_list()
		save_data["inventory"] = player_inventory.to_list()
		save_data["traps"] = save_data["traps"].filter(func(t): return t["id"] != trap_id)
		sync_save_data.rpc_id(id, save_data)
		Toast.add.rpc_id(id, "You picked up a: " + trap_item.name)
		trap_picked_up.rpc_id(id, trap_id)
		return
		
@rpc("authority", "call_remote", "reliable")
func trap_ui_confirmed(trap_data: Dictionary, sfx: String) -> void:
	if sfx != "":
		Game.play_sfx(sfx, 1.0)
	var p = Game.get_player()
	if p == null:
		return
	if p.open_trap_id == trap_data["id"]:
		p.last_trap = trap_data
		p.update_trap()

@rpc("authority", "call_remote", "reliable")
func trap_picked_up(trap_id: int) -> void:
	Game.play_sfx("res://assets/sounds/clang.ogg", 2.0)
	var trap_node = get_tree().current_scene.get_node_or_null(str(trap_id))
	if trap_node != null:
		trap_node.queue_free()
	var p = Game.get_player()
	if p == null:
		return
	if p.open_trap_id == trap_id:
		p.open_trap_id = -1
		p.get_node("UI/Trap").visible = false
		p.get_node("UI/Main").visible = true

@rpc("any_peer", "call_remote", "reliable")
func start_fishing_timer(location: Game.Location, fish_power_bonus: float, nailed_it: bool) -> void:
	if multiplayer.get_unique_id() != 1:
		return
	var id := multiplayer.get_remote_sender_id()
	var odds = randi_range(250, 1100)
	var tick_interval = max(0.2, 0.75 - (sqrt(Game.get_quick_bite(get_player_save_data(id))) * 0.025))

	var entry = {
		"id": id,
		"location": location,
		"them": 0,
		"us": odds,
		"fish_power_bonus": fish_power_bonus,
		"nailed_it": nailed_it,
		"next_tick": tick_interval
	}

	for i in range(fishing_players.size()):
		if fishing_players[i]["id"] == id:
			fishing_players[i] = entry
			return
	fishing_players.append(entry)
	print("Started fishing for " + str(id) + ".")

@rpc("any_peer", "call_remote", "reliable")
func stop_fishing_timer() -> void:
	var id = multiplayer.get_remote_sender_id()
	fishing_players = fishing_players.filter(func(p): return p["id"] != id)
	print("Stopped fishing for " + str(id) + ".")

@rpc("authority", "call_remote", "reliable")
func stop_fishing_for_player() -> void:
	var player = Game.get_player()
	if player == null:
		return
	if player.bobber != null:
		player.bobber.queue_free()
		player.bobber = null
	player.state = player.FishState.INACTIVE
	player.bobber_safe = true
	player.play_idle_animation()
	#Toast.add("The fish got away!")
	print("Stopped fishing for " + str(multiplayer.get_unique_id()) + ".")

@rpc("any_peer", "call_remote", "reliable")
func client_scene_ready() -> void:
	var id = multiplayer.get_remote_sender_id()
	var new_player_pos = _get_spawn_position(id)
	var username = "Player"
	for player in players:
		if player["id"] == id:
			username = player["username"]
			break
	spawn_player.rpc(id, new_player_pos, username)
	
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
			spawn_player.rpc_id(id, player["id"], pos, player["username"])

var bestiary_money_table := {
	Game.Rarity.COMMON:    50.0,
	Game.Rarity.UNCOMMON:  100.0,
	Game.Rarity.RARE:      250.0,
	Game.Rarity.EPIC:      500.0,
	Game.Rarity.LEGENDARY: 1000.0
}

var bestiary_xp_table := {
	Game.Rarity.COMMON:    250.0,
	Game.Rarity.UNCOMMON:  500.0,
	Game.Rarity.RARE:      1500.0,
	Game.Rarity.EPIC:      5000.0,
	Game.Rarity.LEGENDARY: 12500.0
}

@rpc("any_peer", "call_remote", "reliable")
func request_bestiary_reward() -> void:
	var id := multiplayer.get_remote_sender_id()
	var save_data = get_player_save_data(id)
	if save_data.is_empty():
		return

	var bestiary = save_data.get("bestiary", {})
	var acknowledged = save_data.get("acknowledged_bestiary", {})

	var to_ack := []
	var money_gain := 0.0
	var xp_gain := 0.0
	for item_id in bestiary:
		var catchable = Catalog.get_item(int(item_id))
		if catchable is Fish and catchable.location == Game.Location.Crystalwater_Beach:
			if acknowledged.get(item_id, null) == null:
				to_ack.append(item_id)
				money_gain += bestiary_money_table.get(catchable.rarity, 0.0)
				xp_gain += bestiary_xp_table.get(catchable.rarity, 0.0)

	if to_ack.size() < 5:
		return # server re-validates the threshold, doesn't trust the client's claim

	save_data["balance"] = save_data.get("balance", 0.0) + money_gain
	var levels_gained = Game.apply_xp(save_data, xp_gain)

	for item_id in to_ack:
		acknowledged[item_id] = true
	save_data["acknowledged_bestiary"] = acknowledged

	var before_bonus = save_data.get("inventory_upgrade_bestiary_bonus", 0)
	var new_bonus = int(acknowledged.size() / 5) * 5
	save_data["inventory_upgrade_bestiary_bonus"] = new_bonus

	sync_save_data.rpc_id(id, save_data)
	if levels_gained > 0:
		notify_level_up.rpc_id(id, save_data["level"])
	bestiary_reward_given.rpc_id(id, money_gain, xp_gain, new_bonus - before_bonus)

@rpc("authority", "call_remote", "reliable")
func bestiary_reward_given(money: float, xp: float, bonus_gained: int) -> void:
	Game.play_sfx("res://assets/sounds/reward2.ogg", -10)
	Toast.add("You received $%s and %s XP!" % [roundi(money), roundi(xp)])
	if bonus_gained > 0:
		Toast.add("Your tackle box grew! +%d slots." % bonus_gained)

@rpc("any_peer", "call_remote", "reliable")
func request_set_flag(flag_name: String, value: Variant) -> void:
	var id := multiplayer.get_remote_sender_id()
	var save_data = get_player_save_data(id)
	if save_data.is_empty():
		return
	var flags = save_data.get("flags", {})
	if flags.get(flag_name, null) == value:
		return
	flags[flag_name] = value
	save_data["flags"] = flags
	sync_save_data.rpc_id(id, save_data)

@rpc("any_peer", "call_remote", "reliable")
func request_starter_money() -> void:
	var id := multiplayer.get_remote_sender_id()
	var save_data = get_player_save_data(id)
	if save_data.is_empty():
		return
	var flags = save_data.get("flags", {})
	if flags.get("got_starter_money", false):
		return

	save_data["balance"] = save_data.get("balance", 0.0) + 100.0
	flags["got_starter_money"] = true
	save_data["flags"] = flags

	sync_save_data.rpc_id(id, save_data)
	starter_money_given.rpc_id(id)

@rpc("authority", "call_remote", "reliable")
func starter_money_given() -> void:
	Toast.add("You received $100!")

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
func spawn_player(id: int, spawn_position: Vector2, username: String) -> void:
	if multiplayer.get_unique_id() == 1:
		return
	if spawned_players.has(id):
		return
	var instance = PLAYER_SCENE.instantiate()
	instance.name = str(id)
	instance.get_node("Username").text = username
	instance.position = spawn_position
	get_tree().current_scene.add_child(instance, true)
	instance.set_multiplayer_authority(id)
	spawned_players[id] = instance
	
	if id == multiplayer.get_unique_id():
		local_player_spawned.emit()
		instance.get_node("Username").visible = false

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
	players = players.filter(func(p): return p["id"] != id)
	fishing_players = fishing_players.filter(func(p): return p["id"] != id)
	despawn_player.rpc(id)
	player_quit.emit(id)
	server_player_quit.rpc(id)
	for player in players:
		if str(player["id"]) == str(id):
			Toast.add.rpc(player["username"] + " left the server!")

@rpc("any_peer", "call_remote", "reliable")
func temporary_save_data_sending_mechanic_probably_shouldnt_use_this(username: String, save_data: Dictionary) -> void:
	players.append({
		"username": username,
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

@rpc("authority", "call_remote", "reliable")
func instantly_catch(stack_data: Dictionary, caught_it: bool) -> void:
	var stack = ItemStack.from_data(stack_data)
	var player = Game.get_player()
	if player == null:
		return
	print("[client] instantly_catch received: ", stack.type.name, " x", stack.amount, " stars: ", stack.data.get("stars", 0), " caught_it: ", caught_it)
	var bobber_fish = preload("res://scenes/ui/bobber_fish.tscn").instantiate()
	bobber_fish.name = "Bobber Fish"
	bobber_fish.set_meta("fish_id", stack.type.id)
	bobber_fish.get_node("Sprite2D").texture = stack.type.texture
	bobber_fish.get_node("Sprite2D").visible = false
	player.bobber.add_child(bobber_fish)
		
	player.state = player.FishState.REELING_BACK
	if player.bobber != null:
		player.bobber.get_node("Splashes").amount = 64
		if not caught_it:
			Toast.add("Your tackle box is full! You released the %s %s back into the water!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
		else:
			var speech_bubble = load("res://scenes/ui/speech_bubble.tscn").instantiate()
			add_child(speech_bubble)
			var star_icon = "[img width=16 height=16]res://assets/sprites/star.png[/img]"
			var stars = star_icon.repeat(stack.data.get("stars", 0)) + " " if stack.data.get("stars", 0) > 0 else ""
			speech_bubble.play_line("You caught a %s%s%s %s!" % [stars, Game.get_rarity_color(stack.type.rarity), Game.Rarity.find_key(stack.type.rarity), stack.type.name], Vector2(player.global_position.x, player.global_position.y - 8), 30)
			#Toast.add("You caught a %s %s!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
			Game.play_sfx("res://assets/sounds/catch.ogg", 2)

@rpc("authority", "call_remote", "reliable")
func fish_on_line(stack_data: Dictionary, fishing_player: Dictionary) -> void:
	var stack = ItemStack.from_data(stack_data)
	var player = Game.get_player()
	if player == null or player.bobber == null:
		return
	Game.play_sfx("res://assets/sounds/oh.ogg", 2.0)
	var bobber_fish = preload("res://scenes/ui/bobber_fish.tscn").instantiate()
	bobber_fish.name = "Bobber Fish"
	bobber_fish.set_meta("fish_id", stack.type.id)
	bobber_fish.get_node("Sprite2D").texture = stack.type.texture
	bobber_fish.get_node("Sprite2D").visible = false
	player.bobber.add_child(bobber_fish)

	player.bobber.get_node("Exclaim").emitting = true
	player.bobber.get_node("Exclaim").emitting = true
	if stack.type.rarity == Game.Rarity.COMMON:
		player.bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-common.png")
	if stack.type.rarity == Game.Rarity.UNCOMMON:
		player.bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-uncommon.png")
	if stack.type.rarity == Game.Rarity.RARE:
		player.bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-rare.png")
	if stack.type.rarity == Game.Rarity.EPIC:
		player.bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-epic.png")
	if stack.type.rarity == Game.Rarity.LEGENDARY:
		player.bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-legendary.png")
	player.state = player.FishState.FOUND_FISH
	await get_tree().create_timer(1.5).timeout
	if player.state == player.FishState.FOUND_FISH:
		if player.bobber != null and player.bobber.has_node("Bobber Fish"):
			player.bobber.get_node("Bobber Fish").queue_free()
		player.state = player.FishState.FISHING
		print("Player decided not to catch fish, continuing loop.")
		start_fishing_timer.rpc_id(1, fishing_player["location"], fishing_player["fish_power_bonus"], fishing_player["nailed_it"])
	else:
		print("Player decided to catch fish, ending loop.")
		return

func _resolve_catch(id: int, save_data: Dictionary, stack: ItemStack) -> void:
	print("_resolve_catch for ", id, " stack: ", stack.type.name, " x", stack.amount, " stars: ", stack.data.get("stars", 0))
	var xp_before = save_data.get("xp", 0.0)
	var level_before = save_data.get("level", 1)
	var catches_before = save_data.get("catches", 0)
	var inventory = Inventory.new()
	inventory.set_list_from_save(save_data["inventory"])
	var bag = Inventory.new()
	bag.set_list_from_save(save_data["bag"])

	var equipped_bait = save_data.get("equipped_bait", null)
	var equipped_rod = save_data.get("equipped_fishing_rod", null)
	if equipped_bait != null and equipped_rod != null and Catalog.get_item(equipped_rod).baitable:
		inventory.take_item(Catalog.get_item(equipped_bait), 1)
		if not inventory.has_item(Catalog.get_item(equipped_bait)):
			save_data["equipped_bait"] = null
			Toast.add.rpc_id(id, "You ran out of bait!")

	var released = bag.total_size() > Game.get_max_inventory_size(save_data)
	if not released:
		save_data["bestiary"][str(stack.type.id)] = save_data["bestiary"].get(str(stack.type.id), 0) + stack.amount
		save_data["highest_star"][str(stack.type.id)] = max(
			save_data["highest_star"].get(str(stack.type.id), 0),
			stack.data.get("stars", 0)
		)
		bag.add_item(stack)
		save_data["catches"] = save_data.get("catches", 0) + 1

	save_data["inventory"] = inventory.to_list()
	save_data["bag"] = bag.to_list()

	var xp_gained = (xp_table.get(stack.type.rarity, 0.0))
	var upgrades = Inventory.new()
	upgrades.set_list_from_save(save_data["upgrades"])
	if upgrades.has_item(Catalog.get_item(35)):
		var level = upgrades.get_item_stack(Catalog.get_item(35)).data["level"]
		var xp_increase = xp_table.get(stack.type.rarity, 0.0) * (0.1 * level)
		xp_gained += xp_increase

	var levels_gained = Game.apply_xp(save_data, xp_gained)
	print("  catches: ", catches_before, " -> ", save_data.get("catches", 0), " | xp: ", xp_before, " -> ", save_data.get("xp", 0.0), " | level: ", level_before, " -> ", save_data.get("level", 1))
	sync_save_data.rpc_id(id, save_data)
	if levels_gained > 0:
		notify_level_up.rpc_id(id, save_data["level"])
	instantly_catch.rpc_id(id, stack.to_data(), not released)
	fishing_players = fishing_players.filter(func(p): return p["id"] != id)

@rpc("any_peer", "call_remote", "reliable")
func minigame_result(success: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	print("minigame_result from ", id, " success: ", success)
	var found_player = false
	for i in range(fishing_players.size()):
		var player = fishing_players[i]
		if player["id"] == id and player.get("reeling", false):
			found_player = true
			print("  matched reeling player, stack: ", player.get("stack", null))
			if success:
				_resolve_catch(id, get_player_save_data(id), player["stack"])
			else:
				var save_data = get_player_save_data(id)
				save_data["whiffs"] = save_data.get("whiffs", 0) + 1
				sync_save_data.rpc_id(id, save_data)
				stop_fishing_for_player.rpc_id(id)
				Toast.add.rpc_id(id, "The fish got away!")
			fishing_players = fishing_players.filter(func(p): return p["id"] != player["id"])
			return
	if not found_player:
		var save_data = get_player_save_data(id)
		stop_fishing_for_player.rpc_id(id)
	

@rpc("authority", "call_remote", "reliable")
func bite_missed() -> void:
	var p = Game.get_player()
	if p == null:
		return
	if p.bobber != null and p.bobber.has_node("Bobber Fish"):
		p.bobber.get_node("Bobber Fish").queue_free()
	p.state = p.FishState.FISHING

@rpc("authority", "call_remote", "reliable")
func ripple_water() -> void:
	var p = Game.get_player()
	if p.bobber != null:
		if not p.bobber.get_node("Ripple").emitting:
			p.bobber.get_node("Ripple").restart()
	if randf() < 0.2:
		Game.play_sfx_briefly("res://assets/sounds/ripples.ogg", 1.3, -20)

# process
func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 1:
		return
	for player in players:
		var save_data = player["save_data"]
		if not save_data.has("traps"):
			continue
		for trap_data in save_data["traps"]:
			_tick_trap(player["id"], save_data, trap_data, delta)
	for player in fishing_players:
		if player.get("reeling", false):
			continue
		player["next_tick"] = player.get("next_tick", 0.0) - delta
		if player.get("next_tick", 0.0) <= 0.0:
			print("New tick for " + str(player["id"]) + ", us: " + str(player["us"]) + ", them: " + str(player["them"]))
			player["next_tick"] = max(0.2, 0.75 - (sqrt(Game.get_quick_bite(get_player_save_data(player["id"]))) * 0.025)) 
			ripple_water.rpc_id(player["id"])
			var fish_power_bar = player.get("fish_power_bonus", 0.0)
			var odds_to_tally = fish_power_bar * 0.3 if player.get("nailed_it", false) else fish_power_bar * 0.25
			odds_to_tally += randi_range(15, 25) 
			odds_to_tally += sqrt(Game.get_fishing_speed(get_player_save_data(player["id"]))) * 3.5 
			player["them"] += odds_to_tally
			if player["them"] >= player["us"]:
				# They caught it, should send notification now...
				var fish = Catalog.get_fish_drop(player.get("location", 0), Game.get_fishing_power(get_player_save_data(player["id"])), get_player_save_data(player["id"]))
				var stars = Game.roll_stars()
				var stack = ItemStack.new(fish, 1)
				var rod_power = Game.get_fishing_power(get_player_save_data(player["id"]))
				stack.data["stars"] = stars
				var save_data = get_player_save_data(player["id"])
				print("notifying player " + str(player["id"]) + " for fish on line, item: " + str(stack))
				if fish is Junk or fish.threshold <= rod_power:
					_resolve_catch(player["id"], save_data, stack)
				else:
					player["reeling"] = true
					player["stack"] = stack
					fish_on_line.rpc_id(player["id"], stack.to_data(), player)
				#fishing_players = fishing_players.filter(func(p): return p["id"] != player["id"])
