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
	UPGRADES
}

enum Location {
	Crystalwater_Beach
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

var level: int = 0
var xp: float = 0.0
var catches: int = 0
var whiffs: int = 0
var balance: float = 0.0
var equipped_fishing_rod: FishingRod
var bag = Inventory.new()
var upgrades = Inventory.new() # Dumb solution because I don't feel like doing specific logic for permanent/temporary items in your inventory.
var game_loaded: bool = false

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
	Toast.add("You leveled up! You are now Level %f!" % [level])
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
	
func _ready() -> void:
	load_game()
	
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
		if data.has("upgrades"):
			upgrades.set_list_from_save(data["upgrades"])
		if data.has("balance"):
			balance = data["balance"]
		if data.has("whiffs"):
			whiffs = data["whiffs"]
		if data.has("catches"):
			catches = data["catches"]
	print("Loaded save data.")
		
func get_save_data() -> Dictionary:
	return {
		"bag": bag.to_list(),
		"upgrades": upgrades.to_list(),
		"balance": balance,
		"whiffs": whiffs,
		"catches": catches,
		"equipped_fishing_rod": equipped_fishing_rod.id if equipped_fishing_rod else null
	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game_loaded:
			save_game("went to background")

func save_game(reason: String) -> void:
	var save_file: FileAccess = FileAccess.open("user://save.april", FileAccess.WRITE)
	save_file.store_line(JSON.stringify(get_save_data()))
	print("Saved the game. " + "(" + reason + ")")
