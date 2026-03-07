extends CharacterBody2D

const BASE_WALKING_SPEED := 100.0
const BASE_TRAP_PLACE_DISTANCE = 50.0
const DIRECTIONS = {
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up": Vector2.UP,
	"down": Vector2.DOWN
}

var current_log_path: String
var original_zoom := Vector2(3.25, 3.25)
var intended_zoom := Vector2(3.25, 3.25)
var hantenjutsushiki: bool = false
var last_direction: String = "down"
var body_type: String = "cat0"
var state: FishState = FishState.INACTIVE
var bobber: RigidBody2D
var bobber_safe: bool = true # Makes sure you can spam fish or whatever.
var fish_control_safe: bool = true # Makes it so that you can't fish until you release the fish keybind.
var holding_trap: bool = false

var hookVelocity = 0
var hookAcceleration = .001
var hookDeceleration = .2
var maxVelocity = 2.0
var bounce = .6

enum FishState {
	FISHING, # When your bobber is out in the water, haven't found a fish.
	FOUND_FISH, # When your bobber is out in the water, you found a fish, the brief moment when the exclamation mark is on screen.
	REELING, # You're currently in the reeling minigame.
	REELING_BACK, # You're currently reeling the fish back in.
	INACTIVE # You're not doing anything.
}


func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	play_idle_animation()
	if multiplayer.has_multiplayer_peer():
		#for player in Network.players:
			#if player["id"] == name.to_int():
				#$Username.text = player["username"]
		#$Username.show()
		if is_multiplayer_authority():
			$Camera2D.make_current()
		else:
			$UI.hide()
			$InteractionMark.hide()
			$Trap.hide()
			$Minigame.hide()
			$FishPowerBar.hide()
	else:
		#$Username.hide()
		pass
	
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		if not DirAccess.dir_exists_absolute("user://chats"):
			DirAccess.make_dir_absolute("user://chats")
			
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
		current_log_path = "user://chats/%s.log" % timestamp
		
		var file = FileAccess.open(current_log_path, FileAccess.WRITE)
		if file:
			file.store_line("--- Chat session started at %s ---" % timestamp)
		file.close()
	
func add_fish(min_d, max_d, move_speed, move_time):
	#print("adding fish with " + str(min_d) + " " + str(max_d) + " " + str(move_speed) + " " + str(move_time))

	var f = preload("res://scenes/ui/minigame_fish_icon.tscn").instantiate()
	f.position = Vector2(0, 0)
	
	f.min_distance = abs(min_d)
	f.max_distance = abs(max_d)
	f.movement_speed = abs(move_speed)
	f.movement_time = abs(move_time)
	
	$Minigame/Column.add_child(f)
	$Minigame/Progress.value = 200
	
func get_rod_tip(fish_dir: String) -> Vector2:
	if fish_dir == "left":
		return Vector2(global_position.x - 14, global_position.y + 4.5)
	elif fish_dir == "right":
		return Vector2(global_position.x + 14, global_position.y + 4.5)
	elif fish_dir == "up":
		return Vector2(global_position.x, global_position.y - 5.5)
	elif fish_dir == "down":
		return Vector2(global_position.x, global_position.y + 22)
	return global_position

func play_idle_animation() -> void:
	play_animation(body_type + "_idle_" + last_direction)

func play_animation(_name: String, backwards: bool = false, speed: float = 1) -> void:
	if backwards == false:
		$Base.play(_name, speed)
		if _name == body_type + "_fish_down":
			$Base.position = Vector2(0, 3)
		else:
			$Base.position = Vector2(0, 0)
	else:
		$Base.play(_name, speed * -1, true)

func buy_item(id: int) -> void:
	print("buying " + str(id))
	var item = Catalog.get_item(id)
	if item.price > Game.balance:
		Toast.add("You don't have enough money for this!")
		return
	if item.purchase_limit != -1:
		for i in Game.inventory.list:
			if i.type == item and i.amount >= item.purchase_limit:
				Toast.add("You already have too many of this item!")
				return
	Game.inventory.add_item(ItemStack.new(item, 1))
	Game.balance -= item.price
	Toast.add("You bought: " + str(item.name) + "!")
	pass

func update_catalog() -> void:
	for children in $"UI/Vendor/TabContainer/Shop/Rods/ScrollContainer/HBoxContainer".get_children():
		children.queue_free()
	for children in $UI/Vendor/TabContainer/Sell/ScrollContainer/HBoxContainer.get_children():
		children.queue_free()
	for item in Catalog.items:
		if (item as ItemType).category == Game.Category.RODS:
			var shop_entry = preload("res://scenes/ui/shop_entry.tscn").instantiate()
			shop_entry.get_node("TextureRect").texture = item.texture
			shop_entry.get_node("Label").text = (item as ItemType).name + "\n" + str(roundi((item as ItemType).price)) + "g"
			shop_entry.get_node("Panel").connect("pressed", Callable(self, "buy_item").bind(item.id))
			$"UI/Vendor/TabContainer/Shop/Rods/ScrollContainer/HBoxContainer".add_child(shop_entry)
	for item in Game.bag.list:
		if item.type.category == Game.Category.JUNK or item.type.category == Game.Category.FISH:
			var sell_entry = preload("res://scenes/ui/sell_entry.tscn").instantiate()
			sell_entry.get_node("HBoxContainer/Label").text = str(item) + ": " + str(roundi(item.amount)) + " x " + str(roundi(item.type.sell_price)) + " = " + str(roundi(item.type.sell_price * item.amount)) + "g" 
			sell_entry.get_node("HBoxContainer/TextureRect").texture = item.type.texture
			$UI/Vendor/TabContainer/Sell/ScrollContainer/HBoxContainer.add_child(sell_entry)

func _process_input(delta: float) -> void:
	# Movement controls
	velocity = Input.get_vector("left", "right", "up", "down", 0.1)
	if (state == FishState.REELING or state == FishState.FISHING) or $UI/Vendor.visible or $UI/Inventory.visible:
		velocity = Vector2.ZERO
	var velocity_length = velocity.length_squared()
	var is_moving = velocity_length > 0

	if Input.is_action_just_pressed("zoom_in"):
		intended_zoom = Vector2(clamp(intended_zoom.x + 0.75, 1, 4.5), clamp(intended_zoom.y + 0.75, 1, 4.5))
	if Input.is_action_just_pressed("zoom_out"):
		intended_zoom = Vector2(clamp(intended_zoom.x - 0.75, 1, 4.5), clamp(intended_zoom.y - 0.75, 1, 4.5))
	

	if Input.is_action_just_released("interact") and state == FishState.INACTIVE and not $UI/Inventory.visible:
		if not $UI/Vendor.visible:
			for body in $Interaction.get_overlapping_areas():
				if body.is_in_group("shop"):
					$UI/Vendor.visible = true
					$UI/Inventory.visible = false
					$UI/Main.visible = false
					update_catalog()
		else:
			$UI/Vendor.visible = false
			$UI/Main.visible = true

	# Reel back in bobber if you're fishing.
	if Input.is_action_pressed("fish") and state == FishState.FISHING and not bobber_safe:
		if bobber != null:
			bobber.global_position = bobber.global_position.move_toward(
				get_rod_tip(get_fishing_direction()), 
				40.0 * delta
			)
			var tile_map = get_parent().get_node("Ground") as TileMapLayer
			var bobber_position = tile_map.to_local(bobber.global_position)
			var data = tile_map.get_cell_tile_data(tile_map.local_to_map(bobber_position))
			if data and data.get_custom_data("water"):
				pass
			else:
				state = FishState.INACTIVE
				bobber_safe = true
				fish_control_safe = false
				print("The bobber landed on an invalid location.")
				if bobber != null:
					bobber.queue_free()
				play_idle_animation()
			if round(bobber.global_position.distance_to(get_rod_tip(get_fishing_direction()))) == 0:
				print("Player reeled in their bobber.")
				state = FishState.INACTIVE
				bobber_safe = true
				fish_control_safe = false
				play_idle_animation()
				bobber.queue_free()

	# Hook minigame
	if (Input.is_action_pressed("fish")):
		if hookVelocity > -maxVelocity:
			hookVelocity -= hookAcceleration
	else:
		if hookVelocity < maxVelocity:
			hookVelocity += hookDeceleration

	if (Input.is_action_pressed("fish")):
		hookVelocity -= .2

	var target = $Minigame/Hook.position.y + hookVelocity
	if (target >= 33.5):
		hookVelocity *= -bounce
	elif (target <= -33.5):
		hookVelocity = 0
		$Minigame/Hook.position.y = -33.5
	else:
		$Minigame/Hook.position.y = target

	if state == FishState.REELING:
		$Minigame.visible = true
		if bobber != null and not bobber.get_node("Splashes").emitting:
			bobber.get_node("Splashes").restart()
			
		# Adjust Value
		if (len($Minigame/Hook/Area2D.get_overlapping_areas()) > 0):
			#var modifier = (Inventories.fishing_rods.equipped.deerraticness * 0.01) 
			$Minigame/Progress.value += 145 * delta
			$Minigame/Column.get_children()[0].set_vibrate(true)
			Input.vibrate_handheld(10)
			if ($Minigame/Progress.value >= $Minigame/Progress.max_value):
				print("Caught the fish.")
				if bobber != null:
					var stack = ItemStack.new(Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id")), 1)
					if Game.bag.total_size() > Game.get_max_inventory_size():
						Toast.add("Your inventory is full! You released the %s %s back into the water!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
					else:
						Game.bag.add_item(stack)
						Toast.add("You fished up a %s %s!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
				state = FishState.REELING_BACK
				bobber.get_node("Splashes").amount = 64
				Game.catches += 1
				var added_xp = 10.0
				Game.add_xp(added_xp)
				#_show_ui()
		else:
			$Minigame/Column.get_children()[0].set_vibrate(false)
			$Minigame/Progress.value -= 85 * delta
			if ($Minigame/Progress.value <= 0):
				state = FishState.INACTIVE
				bobber_safe = true
				play_idle_animation()
				print("Lost the fish.")
				Game.whiffs += 1
				#_show_ui()
	else:
		$Minigame.visible = false
		for children in $Minigame/Column.get_children():
			children.queue_free()

	# Highlight tiles for placing traps.
	if holding_trap:
		$Trap.show()
		var tilemap = get_parent().get_node("Ground") as TileMapLayer
		var mouse_tile = tilemap.local_to_map(tilemap.get_local_mouse_position())
		var data = tilemap.get_cell_tile_data(mouse_tile)
		if data and data.get_custom_data("water") and global_position.distance_to(tilemap.map_to_local(mouse_tile)) < BASE_TRAP_PLACE_DISTANCE:
			$Trap.global_position = tilemap.map_to_local(mouse_tile)
		else:
			$Trap.hide()	
	else:
		$Trap.hide()

	# Movement animations
	if is_moving:
		bobber_safe = true
		state = FishState.INACTIVE
		if bobber != null:
			bobber.queue_free()
			bobber = null
		velocity_length = min(1, 0.5 + velocity_length)

		# Determine last movement direction
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				last_direction = "right"
			else:
				last_direction = "left"
		else:
			if velocity.y > 0:
				last_direction = "down"
			else:
				last_direction = "up"
		if $Base.animation != body_type + "_walk_" + last_direction:
			play_animation(body_type + "_walk_" + last_direction, false, velocity_length)
	else:
		if $Base.animation.begins_with(body_type + "_walk"):
			play_idle_animation()
	velocity = velocity.normalized() * BASE_WALKING_SPEED
	
	# Confirm catch & start minigame
	if Input.is_action_just_pressed("fish") and state == FishState.FOUND_FISH and not $UI/Vendor.visible and not Input.is_action_just_released("inventory"):
		state = FishState.REELING
		$Minigame.visible = true
		$Minigame.position = Vector2(0, 0)
		$Minigame.scale = Vector2(0.1, 0.1)
		var fish: Fish = Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id"))
		if fish.difficulty == Game.Difficulty.EASY:
			add_fish(5, 40, 2, 6)
		elif fish.difficulty == Game.Difficulty.MEDIUM:
			add_fish(10, 50, 3, 4)
		elif fish.difficulty == Game.Difficulty.HARD:
			add_fish(20, 60, 4, 3.5)
		else: # TODO: FIX ME!
			print("Unsupported fish difficulty.")
		
	if $FishPowerBar.visible and $UI/Inventory.visible:
		$FishPowerBar.hide()
		hantenjutsushiki = false

	if not $UI/Inventory.visible and Game.equipped_fishing_rod != null and not $UI/Vendor.visible:
		# Charge up cast
		if Input.is_action_pressed("fish") and state == FishState.INACTIVE and fish_control_safe:
			if not $FishPowerBar.visible:
				$FishPowerBar.visible = true
				$FishPowerBar.value = 0
				hantenjutsushiki = false
			if hantenjutsushiki:
				$FishPowerBar.value -= randi_range(1, 3)
				if $FishPowerBar.value <= 0:
					hantenjutsushiki = false
			else:
				$FishPowerBar.value += randi_range(1, 3)
				if $FishPowerBar.value >= 100:
					hantenjutsushiki = true
					
		# Cast out charged up cast
		if Input.is_action_just_released("fish") and state == FishState.INACTIVE and fish_control_safe and not Input.is_action_just_released("inventory"):
			$FishPowerBar.visible = false
			hantenjutsushiki = false
			
			var mouse_pos = get_global_mouse_position()
			var direction_vec = (mouse_pos - global_position).normalized()
			var fish_dir := ""
			
			if abs(direction_vec.x) > abs(direction_vec.y):
				if direction_vec.x > 0.0:
					fish_dir = "right"
				else:
					fish_dir = "left"
			else:
				if direction_vec.y > 0.0:
					fish_dir = "down"
				else:
					fish_dir = "up"
			bobber_safe = true
			play_animation(body_type + "_fish_" + fish_dir)
			if bobber != null:
				bobber.queue_free()
		
		# Make it so you can fish after releasing the fish button, helpful for when you're reeling your line and don't want to immediately fish again.
		# This logic should also be RIGHT after the casting out the charged up cast.
		if Input.is_action_just_released("fish"):
			fish_control_safe = true
	else:
		if Input.is_action_just_pressed("fish") and not $UI/Vendor.visible and not $UI/Inventory.visible:
			Toast.add("You can't fish without a [img center region=0,0,16,16 width=16 height=16]res://assets/sprites/items.png[/img] Fishing Rod.")
	
	move_and_slide()
	global_position = round(global_position/ 2) * 2 # Needed to smooth out jittering on diagonal movement

var i_float_timer = 0.0

func set_fishing_rod(id: int) -> void:
	if id != -1:
		if Catalog.get_item(id) is FishingRod:
			Toast.add("Equipped " + str(Catalog.get_item(id).name) + ".")
			Game.equipped_fishing_rod = Catalog.get_item(id)
		else:
			LimboConsole.error("This doesn't seem to be a fishing rod.")
	else:
		Toast.add("Removed currently equipped fishing rod.")
		Game.equipped_fishing_rod = null
	update_inventory()

func update_inventory() -> void:
	for child in $UI/Inventory/ScrollContainer/VBoxContainer.get_children():
		child.queue_free()
	for child in $"UI/Inventory/Container/Fishing Rods/GridContainer".get_children():
		child.queue_free()
	$UI/Inventory/Title.text = "Your bag (" + str(Game.bag.total_size()) + "/" + str(Game.get_max_inventory_size()) + "):"
	var inventory_button = preload("res://scenes/ui/inventory_button.tscn").instantiate()
	inventory_button.get_node("Rarity").texture = null
	inventory_button.get_node("TextureRect").texture = load("res://assets/sprites/cross.png")
	if Game.equipped_fishing_rod != null:
		inventory_button.get_node("Equipped").hide()
	inventory_button.connect("pressed", Callable(self, "set_fishing_rod").bind(-1))
	$"UI/Inventory/Container/Fishing Rods/GridContainer".add_child(inventory_button)

	if Game.equipped_fishing_rod == null:
		$"UI/Inventory/Container/Fishing Rods/Equipped/Icon".texture = load("res://assets/sprites/cross.png")
		$"UI/Inventory/Container/Fishing Rods/Equipped/Name".text = "Nothing"
		$"UI/Inventory/Container/Fishing Rods/Equipped/Description".text = "You have no fishing rod equipped, buy one in the shop."
		$"UI/Inventory/Container/Fishing Rods/Equipped/Stats".text = "Nothing: +0"
	else:
		$"UI/Inventory/Container/Fishing Rods/Equipped/Icon".texture = Game.equipped_fishing_rod.texture
		$"UI/Inventory/Container/Fishing Rods/Equipped/Name".text = Game.equipped_fishing_rod.name
		$"UI/Inventory/Container/Fishing Rods/Equipped/Description".text = Game.equipped_fishing_rod.description
		$"UI/Inventory/Container/Fishing Rods/Equipped/Stats".text = ""
		var index = 0
		for key in Game.equipped_fishing_rod.data["extra_stats"].keys():
			index += 1
			$"UI/Inventory/Container/Fishing Rods/Equipped/Stats".text += str(key) + ": " + str(Game.equipped_fishing_rod.data["extra_stats"][key])
			if index < Game.equipped_fishing_rod.data["extra_stats"].keys().size():
				$"UI/Inventory/Container/Fishing Rods/Equipped/Stats".text += "\n"

	for item in Game.bag.list:
		var inventory_entry = preload("res://scenes/ui/inventory_entry.tscn").instantiate()
		inventory_entry.get_node("Label").text = str(item.amount) + "x " + str(item.type.name)
		inventory_entry.get_node("TextureRect").texture = item.type.texture
		$UI/Inventory/ScrollContainer/VBoxContainer.add_child(inventory_entry)
		
	for item in Game.inventory.list:
		if item.type.category == Game.Category.RODS:
			inventory_button = preload("res://scenes/ui/inventory_button.tscn").instantiate()
			inventory_button.get_node("TextureRect").texture = item.type.texture
			if Game.equipped_fishing_rod != item.type:
				inventory_button.get_node("Equipped").hide()
			inventory_button.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
			inventory_button.connect("pressed", Callable(self, "set_fishing_rod").bind(item.type.id))
			$"UI/Inventory/Container/Fishing Rods/GridContainer".add_child(inventory_button)

func _process_ui(delta: float) -> void:
	$InteractionMark.visible = false
	for child in $InteractionMark.get_children():
		child.visible = false
	for body in $Interaction.get_overlapping_areas():
		if body.is_in_group("shop"):
			$InteractionMark.visible = true
			$InteractionMark/Coin.visible = true
	$UI/Main/InventoryButton.text = "    Inventory (" + str(Game.bag.total_size()) + "/" +  str(Game.get_max_inventory_size()) + ") "
	i_float_timer += delta * 8.0
	$InteractionMark.position.y = -24 + (1.2 * sin(i_float_timer))
	if $Camera2D.zoom != intended_zoom:
		$Camera2D.zoom = lerp($Camera2D.zoom, intended_zoom, 0.2)
	
	if Game.equipped_fishing_rod != null:
		$UI/Main/LevelBar/TextureRect.texture = Game.equipped_fishing_rod.texture
	else:
		$UI/Main/LevelBar/TextureRect.texture = preload("res://assets/sprites/cross.png")
	var symbol
	match (Game.get_day_time()):
		Game.TimeOfDay.MORNING:
			symbol = preload("res://assets/sprites/sun.png")
		Game.TimeOfDay.DAY:
			symbol = preload("res://assets/sprites/sun.png")
		Game.TimeOfDay.MIDDAY:
			symbol = preload("res://assets/sprites/sun.png")
		Game.TimeOfDay.EVENING:
			symbol = preload("res://assets/sprites/moon.png")
		Game.TimeOfDay.NIGHT:
			symbol = preload("res://assets/sprites/moon.png")
	$UI/Main/Time/HBoxContainer/TextureRect.texture = symbol
	$UI/Main/Time/HBoxContainer/Label.text = str(Game.get_time_string())
	$UI/Main/Time/Days.text = "Day: " + str(Game.days)
	$UI/Main/LevelBar/Label.text = "Lv." + str(Game.level) 
	$UI/Main/Info/HBoxContainer/Label.text = "$" + str(roundi(Game.balance))
	$UI/Main/LevelBar.value = roundi(Game.xp)
	$UI/Main/LevelBar.max_value = roundi(Game.calculate_xp_for_level(Game.level))
	var debug_text = "Fishing rod: " + str(Game.equipped_fishing_rod) + "\n"
	debug_text += "Balance: " + str(Game.balance) + "\n"
	debug_text += "Inventory: " + str(Game.bag.total_size()) + "/" +  str(Game.get_max_inventory_size()) + "\n"
	debug_text += "Level: " + str(Game.level) + "\n"
	debug_text += "XP: " + str(roundi(Game.xp)) + "/" + str(roundi(Game.calculate_xp_for_level(Game.level))) + "\n" 
	debug_text += "Time: " + str(Game.get_time_string()) + " " + Game.TimeOfDay.keys()[Game.get_day_time()] + " R: " + str(roundi(Game.time)) + "\n"
	debug_text += "Day: " + str(Game.days) + "\n"
	if multiplayer.has_multiplayer_peer():
		debug_text += "MP ID: " + str(multiplayer.get_unique_id()) + "\n"
	if state == FishState.FISHING:
		debug_text += "\n"
		debug_text += "Num until catch: " + str(odds) + "\n"
		debug_text += "Your num: " + str(your_odds) + "\n"
		debug_text += "Rod power: " + str(Game.get_fishing_power()) + "\n"
	if state == FishState.REELING:
		debug_text += "\nFish: " +  str(Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id")))
	$UI/Main/Debug.text = debug_text
	
	if Input.is_action_just_released("inventory") and not $UI/Vendor.visible:
		$UI/Main/Debug.hide()
		$UI/Main/LevelBar.hide()
		$UI/Main/Time.hide()
		if not $UI/Inventory.visible:
			$UI/Inventory.show()
			$UI/Main/InventoryButton.hide()
			update_inventory()
		else:
			$UI/Main/LevelBar.show()
			$UI/Main/Time.show()
			#$UI/Main/Debug.show()
			$UI/Inventory.hide()
			$UI/Main/InventoryButton.show()
	
	if bobber != null:
		var line = bobber.get_node("Line2D")
		var rod_tip_global := get_rod_tip(get_fishing_direction())
		line.set_point_position(0, Vector2(0, -1.5))
		line.set_point_position(1, bobber.to_local(rod_tip_global))

		if state == FishState.REELING_BACK:
			bobber.global_position = lerp(bobber.global_position, get_rod_tip(get_fishing_direction()), 0.065)
			bobber.get_node("Bobber Fish").get_node("Sprite2D").visible = true
			bobber.get_node("Splashes").restart()
			if round(bobber.global_position.distance_to(get_rod_tip(get_fishing_direction()))) == 0:
				state = FishState.INACTIVE
				bobber_safe = true
				print("Player reeled in bobber.")
				if bobber != null:
					bobber.queue_free()
				play_idle_animation()


		$Camera2D.global_position = (bobber.global_position + global_position) / 2
		var z1 = abs(bobber.global_position.x - global_position.x) / (get_viewport_rect().size.x-25)
		var z2 = abs(bobber.global_position.y - global_position.y) / (get_viewport_rect().size.y-25)
		var zoom_factor = max(max(z1, z2), intended_zoom.x)
		$Camera2D.zoom = Vector2(zoom_factor, zoom_factor) 
	
		# Position minigame based on fishing direction
		var fishing_dir = get_fishing_direction()
		var minigame_offset = Vector2.ZERO
		
		match fishing_dir:
			"up":
				minigame_offset = Vector2(0, -47)  # top-right
			"down":
				minigame_offset = Vector2(0, 65)   # bottom-right
			"right":
				minigame_offset = Vector2(32, 0)  # top-right
			"left":
				minigame_offset = Vector2(-64, -0)  # top-left
		
		var target_pos = global_position + minigame_offset
		$Minigame.global_position = lerp($Minigame.global_position, target_pos, 0.2)
		$Minigame.scale = lerp($Minigame.scale, Vector2(1, 1), 0.1)
	else:
		$Camera2D.global_position = lerp($Camera2D.global_position, global_position, 0.05)
		$Camera2D.zoom = lerp($Camera2D.zoom, Vector2(3.5, 3.5), 0.05)
	 
var odds: int
var your_odds: int
	
func _fishing_timer(location: Game.Location) -> void:
	odds = randi_range(250, 850)
	your_odds = 0
	state = FishState.FISHING
	if Game.bag.total_size() > Game.get_max_inventory_size():
		Toast.add("Your inventory is full, you will release anything you catch.")
	
	var rod_power = Game.get_fishing_power()

	while (state == FishState.FISHING):
		if bobber != null and not bobber.get_node("Ripple").emitting:
			bobber.get_node("Ripple").restart()
		print("Odds: " + str(odds) + " | Your Odds: " + str(your_odds))
		if your_odds >= odds:	
			var fish = Catalog.get_fish_drop(location, rod_power)
			print(fish)
			var bobber_fish = preload("res://scenes/ui/bobber_fish.tscn").instantiate()
			bobber_fish.set_meta("fish_id", fish.id)
			bobber_fish.get_node("Sprite2D").texture = fish.texture
			bobber_fish.get_node("Sprite2D").visible = false
			if bobber != null:
				bobber.add_child(bobber_fish)
			if fish is Junk or rod_power >= fish.threshold:
				Game.add_xp(3)
				state = FishState.REELING_BACK
				if bobber != null:
					bobber.get_node("Splashes").amount = 64
					var stack = ItemStack.new(Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id")), 1)
					if Game.bag.total_size() > Game.get_max_inventory_size():
						Toast.add("Your inventory is full! You released the %s %s back into the water!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
					else:
						Game.bag.add_item(stack)
						Toast.add("You fished up a %s %s!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
				return
			else:
				$Exclaim.emitting = true
				if fish.rarity == Game.Rarity.COMMON:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-common.png")
				if fish.rarity == Game.Rarity.UNCOMMON:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-uncommon.png")
				if fish.rarity == Game.Rarity.RARE:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-rare.png")
				if fish.rarity == Game.Rarity.EPIC:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-epic.png")
				if fish.rarity == Game.Rarity.LEGENDARY:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-legendary.png")
				if fish.rarity == Game.Rarity.MYTHIC:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-mythic.png")
				if fish.rarity == Game.Rarity.DIVINE:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-divine.png")
				if fish.rarity == Game.Rarity.SUPREME:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-supreme.png")
				if fish.rarity == Game.Rarity.SECRET:
					$Exclaim.texture = preload("res://assets/sprites/caught-fish-secret.png")
				state = FishState.FOUND_FISH
			await get_tree().create_timer(1.5).timeout
			if state == FishState.FOUND_FISH:
				if bobber != null and bobber_fish != null:
					bobber_fish.queue_free()
				state = FishState.FISHING
				print("Player decided not to catch fish, continuing loop.")
				your_odds = 0
				odds = randi_range(250, 750)
			else:
				print("Player decided to catch fish, ending loop.")
				return
			
		await get_tree().create_timer(0.75).timeout
		your_odds += randi_range(15, 25) + ($FishPowerBar.value * 0.25)
	
func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	_process_ui(delta)
	_process_input(delta)
	
func get_fishing_direction() -> String:
	var prefix := body_type + "_fish_"
	if $Base.animation.begins_with(prefix):
		return $Base.animation.substr(prefix.length())
	return ""

func _on_base_animation_finished() -> void:
	var prefix := body_type + "_fish_"
	if $Base.animation.begins_with(prefix):
		bobber = preload("res://scenes/bobber.tscn").instantiate()
		bobber.position = to_local(get_rod_tip(get_fishing_direction()))
		bobber.get_node("Line2D").set_point_position(0, Vector2(0.0, -1.5))
		add_child(bobber)
		var dir = DIRECTIONS[get_fishing_direction()]
		last_direction = get_fishing_direction()
		if abs(dir.x) > 0.1:
			dir = (dir + Vector2(0, 0.15)).normalized()
		var mult = 80 + $FishPowerBar.value
		bobber.apply_impulse(dir * mult) 

		await get_tree().create_timer(0.95).timeout
		bobber_safe = false
		if bobber != null:
			bobber.sleeping = true
			var tile_map = get_parent().get_node("Ground") as TileMapLayer
			var bobber_position = tile_map.to_local(bobber.global_position)
			var data = tile_map.get_cell_tile_data(tile_map.local_to_map(bobber_position))
			if data and data.get_custom_data("water"):
				print("Valid tile to fish on, starting timer")
				#_fishing_timer(data.get_custom_data("location"))
				_fishing_timer(Game.Location.get(data.get_custom_data("location")))
			else:
				print("Invalid tile to fish on, stopping fishing")
				state = FishState.INACTIVE
				bobber_safe = true
				if bobber != null:
					bobber.queue_free()
					bobber = null
				play_idle_animation()

func _on_sell_pressed() -> void:
	var amount_earned = 0.0
	var to_remove = []
	print(Game.bag.list)
	for item in Game.bag.list:
		print(item)
		if item.type.category == Game.Category.FISH or item.type.category == Game.Category.JUNK:
			Game.balance += item.amount * item.type.sell_price
			amount_earned += item.amount * item.type.sell_price
			to_remove.append(item)
	if not to_remove.is_empty():
		print(to_remove)
		for item in to_remove:
			Game.bag.take_item(item.type, item.amount)
	
	if amount_earned > 0.0:
		Toast.add("Sold all your fish and earned " + str(amount_earned) + "g!")
	Input.action_release("interact")
	update_catalog()

func _on_inventory_button_pressed() -> void:
	Input.action_release("inventory")

func _on_close_inventory_pressed() -> void:
	Input.action_release("inventory")
