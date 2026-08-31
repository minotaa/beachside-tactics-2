extends Node

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum Category {
	RODS,
	UPGRADES,
	FISH,
	JUNK,
	BAIT,
	TRAPS
}

enum Island {
	Crystalwater_Beach # Supposed to be different from the Locations, there can be multiple Locations in a single island.
}

enum Location {
	Crystalwater_Beach,
	Crystalwater_Void
}

enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
	INSANE
}

enum TimeOfDay {
	MORNING,
	DAY,
	MIDDAY,
	EVENING,
	NIGHT
}

const SPAWN_POINTS = {
	Island.Crystalwater_Beach: Vector2(-248, 0)
}
const BASE_CATCH_TIME = 1200.0
const DAY_COLOR := Color.WHITE
const NIGHT_COLOR := Color(0.192, 0.149, 0.502, 1.0)
const TIME_IN_DAY = 1200 

var sfx_volume: float = 100.0
var fullscreen: bool = false
var dev_mode: bool = false
var level: int = 0
var xp: float = 0.0
var catches: int = 0
var whiffs: int = 0
var balance: float = 0.0
var equipped_fishing_rod: FishingRod
var equipped_bait: Bait
var equipped_trap: Trap
var time: float = TIME_IN_DAY * 0.55
var days: int = 0
var bag = Inventory.new()
var inventory = Inventory.new() # Dumb solution because I don't feel like doing specific logic for permanent/temporary items in your inventory.
var game_loaded: bool = false
var bestiary = {}
var acknowledged_bestiary = {}
var highest_star = {}
var flags = {}
var traps = []
var inventory_upgrade_bestiary_bonus = 0
var last_island: Island = Island.Crystalwater_Beach
var _sfx_in_progress: Dictionary = {}

var game_scene = preload("res://scenes/levels/beach.tscn")
var main_menu_scene = preload("res://scenes/main_menu.tscn")

func stop_sfx(path: String) -> void:
	for child in get_children():
		if child is AudioStreamPlayer and child.get_meta("sfx_path", "") == path:
			child.stop()
			child.queue_free()
	if _sfx_in_progress.has(path):
		_sfx_in_progress[path] = false

func play_sfx(path: String, volume: float = -20.0, pitch_rand: bool = true, no_overlap: bool = false, pitch_lower: float = 0.92, pitch_higher: float = 1.08) -> void:
	if no_overlap and _sfx_in_progress.get(path, false):
		return
	if no_overlap:
		_sfx_in_progress[path] = true
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.bus = "SFX"
	player.set_meta("sfx_path", path)
	player.stream = load(path)
	player.volume_db = volume
	if pitch_rand:
		player.pitch_scale = randf_range(pitch_lower, pitch_higher)
	player.play()
	var wait_time = player.stream.get_length() / player.pitch_scale
	await get_tree().create_timer(wait_time).timeout
	if no_overlap:
		_sfx_in_progress[path] = false
	if is_instance_valid(player):
		player.queue_free()

func play_sfx_briefly(path: String, duration: float = 4.0, volume: float = -20.0, from_position: float = -1.0, pitch_rand: bool = true, no_overlap: bool = false, pitch_lower: float = 0.92, pitch_higher: float = 1.08) -> void:
	if no_overlap and _sfx_in_progress.get(path, false):
		return
	if no_overlap:
		_sfx_in_progress[path] = true
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.bus = "SFX"
	player.set_meta("sfx_path", path)
	player.stream = load(path)
	if pitch_rand:
		player.pitch_scale = randf_range(pitch_lower, pitch_higher)
	player.volume_db = volume
	var stream_length := player.stream.get_length()
	var start := from_position if from_position >= 0.0 else randf_range(0.0, stream_length - duration)
	player.play(start)
	await get_tree().create_timer(duration).timeout
	if no_overlap:
		_sfx_in_progress[path] = false
	if not is_instance_valid(player):
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -80.0, 1.5)
	await tween.finished
	if is_instance_valid(player):
		player.queue_free()

func get_rarity_color(rarity: Rarity) -> String:
	match rarity:
		Game.Rarity.COMMON:
			return "[color=#ffffffff]"	
		Game.Rarity.UNCOMMON:
			return "[color=#23ff48]"
		Game.Rarity.RARE:
			return "[color=#226acf]"
		Game.Rarity.EPIC:
			return "[color=#6818d7]"
		Game.Rarity.LEGENDARY:
			return "[color=#f68533]"
		_:
			return ""

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

func get_time_string(_time: float = time) -> String:
	var total_minutes := int((_time / TIME_IN_DAY) * 1440)  # 1440 minutes in a day
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

func get_star_chance() -> float:
	return 10.0

func get_one_star_chance() -> float:
	return 60.0

func get_two_star_chance() -> float:
	return 30.0

func get_three_star_chance() -> float:
	return 10.0

func roll_stars() -> int:
	if randf() * 100.0 < get_star_chance():
		var roll = randf() * 100.0
		if roll < get_three_star_chance():
			return 3
		elif roll < get_three_star_chance() + get_two_star_chance():
			return 2
		elif roll < get_three_star_chance() + get_two_star_chance() + get_one_star_chance():
			return 1
	return 0

func get_junk_chance(save_data: Dictionary) -> float:
	var junk_chance = 0.0
	if save_data["equipped_fishing_rod"] != null and Catalog.get_item(save_data["equipped_fishing_rod"]) != null:
		junk_chance += Catalog.get_item(save_data["equipped_fishing_rod"]).junk_chance * 0.01
	return junk_chance

func get_trophy_fish_chance(save_data: Dictionary) -> float:
	var trophy_chance = 0.0
	if save_data["equipped_bait"] != null and Catalog.get_item(save_data["equipped_bait"]) != null:
		trophy_chance += Catalog.get_item(save_data["equipped_bait"]).trophy_fish_chance * 0.01
	return trophy_chance

func get_fishing_speed(save_data: Dictionary) -> float:
	var fishing_speed = 0.0
	if save_data["equipped_bait"] != null and \
	Catalog.get_item(save_data["equipped_bait"]) != null and \
	save_data["equipped_fishing_rod"] != null and \
	Catalog.get_item(save_data["equipped_fishing_rod"]) != null and \
	(Catalog.get_item(save_data["equipped_fishing_rod"]) as FishingRod).baitable:
		fishing_speed += Catalog.get_item(save_data["equipped_bait"]).extra_fishing_speed
	return fishing_speed

func get_quick_bite(save_data: Dictionary) -> float:
	var quick_bite = 0.0
	if save_data["equipped_bait"] != null and \
	Catalog.get_item(save_data["equipped_bait"]) != null and \
	save_data["equipped_fishing_rod"] != null and \
	Catalog.get_item(save_data["equipped_fishing_rod"]) != null and \
	(Catalog.get_item(save_data["equipped_fishing_rod"]) as FishingRod).baitable:
		quick_bite += Catalog.get_item(save_data["equipped_bait"]).extra_quick_bite
	return quick_bite

func get_fishing_power(save_data: Dictionary) -> float:
	var fishing_power = 0.0
	if save_data["equipped_fishing_rod"] != null and Catalog.get_item(save_data["equipped_fishing_rod"]) != null:
		fishing_power += Catalog.get_item(save_data["equipped_fishing_rod"]).fishing_power
	return fishing_power

func calculate_xp_for_level(_level: int) -> float:
	var xp_scaling: float = 1.5
	# Level 1->2: 100 XP, 2->3: 150 XP, 3->4: 225 XP, etc.
	return 100.0 * pow(xp_scaling, _level - 1)

func apply_xp(save_data: Dictionary, amount: float) -> int:
	save_data["xp"] = save_data.get("xp", 0.0) + amount
	save_data["level"] = save_data.get("level", 1)
	var levels_gained := 0
	while save_data["xp"] >= calculate_xp_for_level(save_data["level"]):
		save_data["xp"] -= calculate_xp_for_level(save_data["level"])
		save_data["level"] += 1
		levels_gained += 1
	return levels_gained

func get_max_traps() -> int:
	return 5

func get_max_inventory_size(save_data: Dictionary) -> int:
	var size = 25
	size += save_data["inventory_upgrade_bestiary_bonus"]
	return size

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

func _ready() -> void:	
	var arguments = OS.get_cmdline_args()
	for arg in arguments:
		if arg == "--dev":
			dev_mode = true
			print("Dev mode detected.")
	multiplayer.multiplayer_peer = null # TODO: REMOVE ME
	if DisplayServer.get_name() != "headless": 
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
	LimboConsole.register_command(set_xp, "set_xp", "Sets your XP.")
	LimboConsole.register_command(set_balance, "set_balance", "Sets your balance.")
	
func set_balance(balance: float) -> void:
	self.balance = balance
	LimboConsole.info("Your balance has been set to: " + str(roundi(self.balance)))
	
func set_xp(xp: float) -> void:
	self.xp = xp
	LimboConsole.info("Your XP has been set to: " + str(roundi(xp)))
	
func set_holding_trap(holding_trap: bool) -> void:
	if get_player() != null:
		get_player().holding_trap = holding_trap
		LimboConsole.info("You are now holding a trap." if holding_trap else "You are no longer holding a trap.")
	else:
		LimboConsole.error("Can't find a player.")
		
func apply_save(data: Dictionary, is_initial_load: bool = false) -> void:
	if data.has("bag"):
		bag.list.clear()
		bag.set_list_from_save(data["bag"])
	if data.has("bestiary"):
		bestiary = data["bestiary"]
	if data.has("acknowledged_bestiary"):
		acknowledged_bestiary = data["acknowledged_bestiary"]
	if data.has("flags"):
		flags = data["flags"]
	if data.has("traps"):
		traps.clear()
		for trap in data["traps"]:
			var trap_object = {}
			var inventory_ = Inventory.new()
			var bait_inventory = Inventory.new()
			inventory_.set_list_from_save(trap["inventory"])
			bait_inventory.set_list_from_save(trap["bait_inventory"])
			trap_object["inventory"] = inventory_
			trap_object["bait_inventory"] = bait_inventory
			trap_object["x"] = trap["x"]
			trap_object["y"] = trap["y"]
			trap_object["location"] = trap["location"]
			trap_object["trap"] = Catalog.get_item(trap["trap"])
			traps.append(trap_object)
	if data.has("inventory_upgrade_bestiary_bonus"):
		inventory_upgrade_bestiary_bonus = data["inventory_upgrade_bestiary_bonus"]
	if data.has("last_island"):
		last_island = data["last_island"]
	if data.has("equipped_bait"):
		var bait_id = data["equipped_bait"]
		equipped_bait = Catalog.get_item(bait_id) if bait_id != null else null
	if data.has("equipped_trap"):
		var trap_id = data["equipped_trap"]
		equipped_trap = Catalog.get_item(trap_id) if trap_id != null else null
	if data.has("equipped_fishing_rod"):
		var rod_id = data["equipped_fishing_rod"]
		equipped_fishing_rod = Catalog.get_item(rod_id) if rod_id != null else null
	if data.has("inventory"):
		inventory.list.clear()
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
	if data.has("highest_star"):
		highest_star = data["highest_star"]

	if is_initial_load:
		if data.has("fullscreen"):
			fullscreen = data["fullscreen"]
			if fullscreen:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if data.has("sfx_volume"):
			sfx_volume = data["sfx_volume"]
			if sfx_volume <= 0.0:
				AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
			else:
				AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
				var db_value = lerp(-55.0, 0.0, sfx_volume / 100.0)
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db_value)

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
		apply_save(data, true)
	print("Loaded save data.")
		
func get_save_data() -> Dictionary:
	var traps_data = []
	for trap in traps:
		var trap_object = {}
		trap_object["x"] = trap["x"]
		trap_object["y"] = trap["y"]
		trap_object["trap"] = trap["trap"].id
		trap_object["inventory"] = trap["inventory"].to_list()
		trap_object["bait_inventory"] = trap["bait_inventory"].to_list()
		trap_object["location"] = trap["location"]
		traps_data.append(trap_object)
	var save_data = {
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"bag": bag.to_list(),
		"inventory": inventory.to_list(),
		"balance": balance,
		"whiffs": whiffs,
		"catches": catches,
		"equipped_fishing_rod": equipped_fishing_rod.id if equipped_fishing_rod else null,
		"equipped_bait": equipped_bait.id if equipped_bait else null,
		"equipped_trap": equipped_trap.id if equipped_trap else null,
		"days": days,
		"time": time,
		"xp": xp,
		"level": level,
		"bestiary": bestiary,
		"acknowledged_bestiary": acknowledged_bestiary,
		"flags": flags,
		"inventory_upgrade_bestiary_bonus": inventory_upgrade_bestiary_bonus,
		"highest_star": highest_star,
		"traps": traps_data,
		"last_island": last_island
	}
	return save_data

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
