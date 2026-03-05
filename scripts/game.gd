extends Node

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC,
	DIVINE,
	SUPREME,
	SECRET
}

enum Category {
	RODS,
	UPGRADES,
	FISH,
	JUNK
}

enum Location {
	Crystalwater_Beach,
	Crystalwater_Shore # Instead of making a different system for trap fish, I'll just make a location that you can't fish in.
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
	VERY_DIFFICULT,
	INSANE,
	IMPOSSIBLE,
	SUPREME
}

enum TimeOfDay {
	MORNING,
	DAY,
	MIDDAY,
	EVENING,
	NIGHT
}

const DAY_COLOR := Color.WHITE
const NIGHT_COLOR := Color(135 / 255.0, 135 / 255.0, 242 / 255.0)
const TIME_IN_DAY = 1200 

var level: int = 0
var xp: float = 0.0
var catches: int = 0
var whiffs: int = 0
var balance: float = 0.0
var equipped_fishing_rod: FishingRod
var time: float = TIME_IN_DAY * 0.55
var days: int = 0
var bag = Inventory.new()
var inventory = Inventory.new() # Dumb solution because I don't feel like doing specific logic for permanent/temporary items in your inventory.
var game_loaded: bool = false

var game_scene = preload("res://scenes/game.tscn")
var main_menu_scene = preload("res://scenes/main_menu.tscn")

func _process(delta: float) -> void:
	time += delta
	if time >= TIME_IN_DAY: # 1200 = 20 minutes
		time = 0.0
		days += 1

func get_sky_color() -> Color:
	var t := time / TIME_IN_DAY # 0.0 - 1.0
	# convert to a 0.0 - 1.0 value that peaks at midday and dips at midnight
	var day_factor := sin(t * PI)
	return DAY_COLOR.lerp(NIGHT_COLOR, 1.0 - day_factor)

func get_time_string() -> String:
	var total_minutes := int((time / TIME_IN_DAY) * 1440)  # 1440 minutes in a day
	var hours := total_minutes / 60
	var minutes := total_minutes % 60
	minutes = (minutes / 10) * 10
	var suffix := "AM" if hours < 12 else "PM"
	if hours == 0:
		hours = 12
	elif hours > 12:
		hours -= 12
	return "%d:%02d %s" % [hours, minutes, suffix]

func get_day_time() -> TimeOfDay:
	var t := time / TIME_IN_DAY
	# 12:00 AM = 0.0, 6:00 AM = 0.25, 12:00 PM = 0.5, 6:00 PM = 0.75
	if t < 0.25 or t >= 0.875:	# 12:00 AM - 6:00 AM, 9:00 PM - 12:00 AM
		return TimeOfDay.NIGHT
	elif t < 0.375:				# 6:00 AM - 9:00 AM
		return TimeOfDay.MORNING
	elif t < 0.5:				# 9:00 AM - 12:00 PM
		return TimeOfDay.DAY
	elif t < 0.625:				# 12:00 PM - 3:00 PM
		return TimeOfDay.MIDDAY
	else:						# 3:00 PM - 9:00 PM
		return TimeOfDay.EVENING

func get_fishing_power() -> float:
	var fishing_power = 0.0
	if equipped_fishing_rod != null:
		fishing_power += equipped_fishing_rod.fishing_power
	return fishing_power

func calculate_xp_for_level(_level: int) -> float:
	var xp_scaling: float = 1.5
	# Formula: base_xp * (scaling ^ (level - 1))
	# Level 1->2: 100 XP
	# Level 2->3: 150 XP
	# Level 3->4: 225 XP, etc.
	return 100.0 * pow(xp_scaling, _level - 1)

func level_up():
	xp -= calculate_xp_for_level(level)
	level += 1
	Toast.add("You leveled up! You are now Level %d!" % [roundi(level)])
	print("Level up! Now level ", level)

@rpc("authority", "call_local")
func add_xp(amount: float) -> void:
	xp += amount
	while xp >= calculate_xp_for_level(level):
		level_up()

func get_max_inventory_size() -> int:
	return 25

func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"

func is_desktop() -> bool:
	return not is_mobile()
	
func set_fishing_rod(id: int) -> void:
	if id != -1:
		if Catalog.get_item(id) is FishingRod:
			LimboConsole.info("Set fishing rod to: " + str(Catalog.get_item(id)) + ", was " + str(equipped_fishing_rod))
			equipped_fishing_rod = Catalog.get_item(id)
		else:
			LimboConsole.error("This doesn't seem to be a fishing rod.")
	else:
		LimboConsole.info("Removed currently equipped fishing rod" + ", was " + str(equipped_fishing_rod))
		equipped_fishing_rod = null
	
func set_time(value: Variant) -> void:
	if value is int or value is float:
		time = clamp(float(value), 0.0, TIME_IN_DAY - 0.001)
	elif value is String:
		var upper = value.to_upper()
		match upper:
			"MORNING":  time = TIME_IN_DAY * 0.25
			"DAY":      time = TIME_IN_DAY * 0.45
			"MIDDAY":   time = TIME_IN_DAY * 0.55
			"EVENING":  time = TIME_IN_DAY * 0.7
			"NIGHT":    time = TIME_IN_DAY * 0.1
			_:          LimboConsole.error("Unknown time of day: " + value)
		LimboConsole.info("Time set to: " + get_time_string() + " (" + TimeOfDay.keys()[get_day_time()] + ")")

func host() -> void:
	var server_res = await Network.host_server(6466)
	if not server_res:
		LimboConsole.error("Couldn't create the server, something probably happened.")
	else:
		LimboConsole.info("Successfully created a server.")

func connect_to_server(address: String, username: String = "Player") -> void:
	var join_res = await Network.join_server(address, username)
	if not join_res:
		LimboConsole.error("Couldn't connect to the address.")
	else:
		LimboConsole.info("Successfully joined through the connection.")

func _ready() -> void:
	multiplayer.multiplayer_peer = null # TODO: REMOVE ME
	load_game()
	LimboConsole.register_command(set_fishing_rod, "set_fishing_rod", "Set your currently equipped fishing rod.")
	LimboConsole.add_argument_autocomplete_source("set_fishing_rod", 0,
		func(): 
		var list = []
		for item in Catalog.items:
			if item is FishingRod or item.category == Category.RODS:
				list.append(item.id)
		return list
	)
	LimboConsole.register_command(set_time, "set_time", "Set the time of day. Accepts a number or MORNING/DAY/MIDDAY/EVENING/NIGHT.")
	LimboConsole.add_argument_autocomplete_source("set_time", 0,
		func():
			return TimeOfDay.keys()
	)
	LimboConsole.register_command(set_holding_trap, "set_holding_trap", "Set yourself as holding a trap.")
	LimboConsole.add_argument_autocomplete_source("set_holding_trap", 0,
		func():
			return [true, false]
	)
	LimboConsole.register_command(host, "host", "Hosts a multiplayer server.")
	LimboConsole.register_command(connect_to_server, "connect", "Connect to the server using the connection address.")
	
func set_holding_trap(holding_trap: bool) -> void:
	if get_player() != null:
		get_player().holding_trap = holding_trap
		LimboConsole.info("You are now holding a trap." if holding_trap else "You are no longer holding a trap.")
	else:
		LimboConsole.error("Can't find a player.")
		
func load_game() -> void:
	game_loaded = true
	if not FileAccess.file_exists("user://save.april"):
		return
	var save_file: FileAccess = FileAccess.open("user://save.april", FileAccess.READ)
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue
		var data = json.get_data()
		if data.has("bag"):
			bag.set_list_from_save(data["bag"])
		if data.has("equipped_fishing_rod"):
			var rod_id = data["equipped_fishing_rod"]
			if rod_id != null:  # null means no rod equipped
				equipped_fishing_rod = Catalog.get_item(rod_id)
		if data.has("inventory"):
			inventory.set_list_from_save(data["inventory"])
		if data.has("balance"):
			balance = data["balance"]
		if data.has("whiffs"):
			whiffs = data["whiffs"]
		if data.has("catches"):
			catches = data["catches"]
		if data.has("days"):
			days = data["days"]
		if data.has("time"):
			time = data["time"]
		if data.has("level"):
			level = data["level"]
		if data.has("xp"):
			xp = data["xp"]
	print("Loaded save data.")
		
func get_save_data() -> Dictionary:
	return {
		"bag": bag.to_list(),
		"inventory": inventory.to_list(),
		"balance": balance,
		"whiffs": whiffs,
		"catches": catches,
		"equipped_fishing_rod": equipped_fishing_rod.id if equipped_fishing_rod else null,
		"days": days,
		"time": time,
		"xp": xp,
		"level": level
	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game_loaded:
			save_game("went to background")

func save_game(reason: String) -> void:
	var save_file: FileAccess = FileAccess.open("user://save.april", FileAccess.WRITE)
	save_file.store_line(JSON.stringify(get_save_data()))
	print("Saved the game. " + "(" + reason + ")")

func get_player() -> Node2D:
	for player in get_tree().get_nodes_in_group("players"):
		if multiplayer.has_multiplayer_peer():
			if player.name == str(multiplayer.get_unique_id()):
				return player
		else:
			if player.name == "Player":
				return player
	return null

@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	await Fade.fade_out()
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Main Menu") or child.name.begins_with("Game"):
			child.queue_free()
	get_tree().current_scene.add_child(game_scene.instantiate(), true)
	await Fade.fade_in()
	
@rpc("authority", "call_local", "reliable")
func end_game() -> void:
	await Fade.fade_in()	
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Game") or child.name.begins_with("Main Menu"):
			child.queue_free()
	get_tree().current_scene.add_child(main_menu_scene.instantiate(), true)
	await Fade.fade_out()
