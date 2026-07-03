extends CharacterBody2D

const BASE_WALKING_SPEED := 100.0
const BASE_TRAP_PLACE_DISTANCE = 35.0
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
var holding_trap: bool = true
var selected_tile: Vector2i
var interacting: bool = false
var immersive_interact: NPC
var step_timer = 0.0
var step_interval = 0.5

var hook_velocity = 0
var hook_acceleration = 1.75
var hook_deceleration = 2.45
var hook_press_acceleration = 1.75
var max_velocity = 6.0
var bounce = 0.3

# ROPE PHYSICS VARIABLES
var line_segments = 15  # More segments = smoother curve
var line_points = []  # Array of Vector2 positions
var line_velocities = []  # Physics velocities for each point
var line_gravity = 80.0  # Sag amount (reduced from 150 for less droop)
var line_damping = 0.92  # How quickly line settles
var line_stiffness = 0.5  # How much line resists bending (increased from 0.3 for less sag)

enum FishState {
	FISHING, # When your bobber is out in the water, haven't found a fish.
	FOUND_FISH, # When your bobber is out in the water, you found a fish, the brief moment when the exclamation mark is on screen.
	REELING, # You're currently in the reeling minigame.
	REELING_BACK, # You're currently reeling the fish back in.
	INACTIVE # You're not doing anything.
}

func play_sfx_briefly(path: String, duration: float = 4.0, volume: float = -20.0, from_position: float = -1.0) -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = load(path)
	player.pitch_scale = randf_range(0.92, 1.08)
	player.volume_db = volume
	var stream_length := player.stream.get_length()
	var start := from_position if from_position >= 0.0 else randf_range(0.0, stream_length - duration)
	player.play(start)
	await get_tree().create_timer(duration).timeout
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -80.0, 1.5)
	await tween.finished
	player.queue_free()

func play_sfx(path: String, volume: float = -20.0) -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = load(path)
	player.volume_db = volume
	player.pitch_scale = randf_range(0.92, 1.08)
	player.play()
	await player.finished
	player.queue_free()

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	# Initialize line physics
	for i in range(line_segments):
		line_points.append(Vector2.ZERO)
		line_velocities.append(Vector2.ZERO)
	
	# Initialize traps
	for trap in Game.traps:
		var placed_trap = preload("res://scenes/trap.tscn").instantiate()
		placed_trap.trap = trap["trap"]
		placed_trap.location = trap["location"]
		placed_trap.global_position = Vector2(trap["x"], trap["y"])
		placed_trap.inventory = trap["inventory"]
		placed_trap.bait_inventory = trap["bait_inventory"]
		get_parent().add_child(placed_trap, true)
	
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

func update_fishing_line(delta):
	if bobber == null:
		return
	
	var rod_tip = get_rod_tip(get_fishing_direction())
	var bobber_pos = bobber.global_position
	
	# Safety check: ensure line physics is initialized at rod tip
	if line_points.is_empty():
		for i in range(line_segments):
			# Initialize all points along a straight line from rod to bobber
			var t = float(i) / float(line_segments - 1)
			line_points.append(lerp(rod_tip, bobber_pos, t))
			line_velocities.append(Vector2.ZERO)
		
	# Set endpoints
	line_points[0] = rod_tip
	line_points[line_segments - 1] = bobber_pos
	
	# Physics simulation for middle points
	for i in range(1, line_segments - 1):
		# Apply gravity (makes line sag)
		line_velocities[i].y += line_gravity * delta
		
		# Apply velocity
		line_points[i] += line_velocities[i] * delta
		
		# Damping (air resistance)
		line_velocities[i] *= line_damping
	
	# Constraint pass - keep segments connected (run multiple times for stability)
	# More iterations = stiffer, fewer = more loose
	var iterations = 5 if state == FishState.REELING or state == FishState.REELING_BACK else 3
	for iteration in range(iterations):
		for i in range(line_segments - 1):
			var segment_length = rod_tip.distance_to(bobber_pos) / (line_segments - 1)
			var current_point = line_points[i]
			var next_point = line_points[i + 1]
			
			var delta_pos = next_point - current_point
			var current_distance = delta_pos.length()
			if current_distance < 0.01:  # Prevent division by zero
				continue
			var difference = (current_distance - segment_length) / current_distance
			
			var offset = delta_pos * difference * line_stiffness
			
			# Don't move endpoints, apply smooth interpolation to middle points
			if i > 0:
				line_points[i] += offset * 0.5
			if i < line_segments - 2:
				line_points[i + 1] -= offset * 0.5
	
	# Update Line2D visual with smooth interpolation
	if bobber.has_node("Line2D"):
		var line = bobber.get_node("Line2D")
		line.clear_points()
		for point in line_points:
			line.add_point(bobber.to_local(point))
	
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
		return Vector2(global_position.x, global_position.y - 5.6)
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

var selected_item

func select_item(id: int, ignore: bool = false) -> void:
	var item = Catalog.get_item(id)
	if item == null:
		Toast.add("huh?")
		return
	if item == selected_item and not ignore:
		if $UI/Vendor/ItemPreview.visible:
			$UI/Vendor/ItemPreview.visible = false
		else:
			$UI/Vendor/ItemPreview.visible = true
		return
	selected_item = item
	$UI/Vendor/ItemPreview/Price.text = "Price: $" + str(roundi(item.price))
	$UI/Vendor/ItemPreview/Description.text = item.description + "\n\n"
	if randf() > 0.2:
		$UI/Vendor/ItemPreview/Description.text = $UI/Vendor/ItemPreview/Description.text.replace("Flimsy Fishing Rod", "Flismy Fshing Bod")
	var index = 0
	if item.data.has("extra_stats"):
		for key in item.data["extra_stats"].keys():
			index += 1
			$UI/Vendor/ItemPreview/Description.text += str(key) + ": " + str(item.data["extra_stats"][key])
			if index < item.data["extra_stats"].keys().size():
				$UI/Vendor/ItemPreview/Description.text += "\n"

	
	$UI/Vendor/ItemPreview/Name.text = item.name
	$UI/Vendor/ItemPreview/Item/TextureRect.texture = item.texture
	$UI/Vendor/ItemPreview/Item/Rarity.texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.rarity).to_lower() + ".png")
	if item.price > Game.balance:
		$UI/Vendor/ItemPreview/Buy.disabled = true
		$UI/Vendor/ItemPreview/Buy.text = "Can't afford"
	else:
		$UI/Vendor/ItemPreview/Buy.disabled = false
		$UI/Vendor/ItemPreview/Buy.text = "Buy"
	$UI/Vendor/ItemPreview.visible = true

func buy_item() -> void:
	play_sfx("res://assets/sounds/cashregister.ogg", 5)
	print("buying " + str(selected_item))
	var item = selected_item
	if item.price > Game.balance:
		Toast.add("You don't have enough money for this!")
		return
	if item.purchase_limit != -1:
		for i in Game.inventory.list:
			if i.type == item and i.amount >= item.purchase_limit:
				Toast.add("You already have too many of this item!")
				return
	var added_amount = 1
	if item.category == Game.Category.BAIT:
		added_amount = 8
	Game.inventory.add_item(ItemStack.new(item, added_amount))
	Game.balance -= item.price
	Toast.add("You bought: " + str(added_amount) + "x " + str(item.name) + "!")
	update_catalog()
	select_item(selected_item.id, true)
	pass

func update_bestiary() -> void:
	for children in $UI/Bestiary/List/ScrollContainer/GridContainer.get_children():
		children.queue_free()
	var not_unlocked_fish = []
	for item in Catalog.items:
		if item is Fish:
			not_unlocked_fish.append(item)
	
	for id in Game.bestiary.keys():
		var bestiary_item = preload("res://scenes/ui/inventory_button.tscn").instantiate()
		var item = Catalog.get_item(int(id))
		if item is Fish:
			not_unlocked_fish = not_unlocked_fish.filter(func(f): return f.id != item.id)
			bestiary_item.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.rarity).to_lower() + ".png")
			bestiary_item.get_node("TextureRect").texture = item.texture
			bestiary_item.get_node("Equipped").visible = false
			bestiary_item.get_node("Label").visible = true
			bestiary_item.get_node("Label").text = "x" + str(int(Game.bestiary.get(id, 0)))
			bestiary_item.connect("pressed", Callable(self, "preview_item").bind(int(id)))
			$UI/Bestiary/List/ScrollContainer/GridContainer.add_child(bestiary_item)
	for fish in not_unlocked_fish:
		var bestiary_item = preload("res://scenes/ui/inventory_button.tscn").instantiate()
		bestiary_item.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(fish.rarity).to_lower() + ".png")
		bestiary_item.get_node("TextureRect").texture = fish.texture
		bestiary_item.get_node("TextureRect").material = load("res://scenes/ui/blackout.tres")
		bestiary_item.get_node("Equipped").visible = false
		bestiary_item.disabled = true
		$UI/Bestiary/List/ScrollContainer/GridContainer.add_child(bestiary_item)
	# TODO: Add percentage of completed bestiary in current loc
	
	
var previewed_item
	
func preview_item(id: int) -> void:
	var item = Catalog.get_item(id)
	if item == null:
		Toast.add("huh?")
		return
	if item == previewed_item:
		$UI/Bestiary/ItemPreview.visible = not $UI/Bestiary/ItemPreview.visible
		return
	previewed_item = item
	$UI/Bestiary/ItemPreview/Item/Rarity.texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.rarity).to_lower() + ".png")
	$UI/Bestiary/ItemPreview/Item/TextureRect.texture = item.texture
	$UI/Bestiary/ItemPreview/Name.text = item.name

	var catches = Game.bestiary.get(str(item.id), 0)
	var rarity_name = Game.Rarity.find_key(item.rarity).capitalize()
	var location_name = Game.Location.find_key(item.location).replace("_", " ")

	var info = ""
	var best_stars = Game.highest_star.get(str(item.id), 0)
	if best_stars > 0:
		var star_icon = "[img width=16 height=16]res://assets/sprites/star.png[/img]"
		info += "Best Catch: " + star_icon.repeat(best_stars) + "\n"
	info += "Sell Price: $" + str(roundi(item.sell_price)) + "\n"
	info += "Location: " + location_name + "\n"
	info += "Rod Power Needed: " + str(item.power_needed) + "\n"

	if item is Fish:
		var hour_start = Game.get_time_string(item.hour_start)
		var hour_end = Game.get_time_string(item.hour_end)
		if item.hour_start == 0.0 and item.hour_end == 0.0:
			info += "Active: Anytime\n"
		else:
			info += "Active: " + str(hour_start) + " - " + str(hour_end) + "\n"
		info += "Difficulty: " + Game.Difficulty.find_key(item.difficulty).capitalize() + "\n"

	$UI/Bestiary/ItemPreview/Description.text = item.description + "\n\n" + info
	$UI/Bestiary/ItemPreview.visible = true

func update_catalog() -> void:
	for children in $"UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Rods/ScrollContainer/HBoxContainer".get_children():
		children.queue_free()
	for children in $"UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Bait/ScrollContainer/HBoxContainer".get_children():
		children.queue_free()
	for children in $"UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Traps/ScrollContainer/HBoxContainer".get_children():
		children.queue_free()
	for children in $UI/Vendor/TabContainer/Sell/ScrollContainer/HBoxContainer.get_children():
		children.queue_free()
	if Game.level < 5:
		$UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Bait.visible = false
	else:
		$UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Bait.visible = true
	$UI/Vendor/TabContainer/Shop/Balance.text = "Your balance: $" + str(roundi(Game.balance))
	for item in Catalog.items:
		if (item as ItemType).category == Game.Category.RODS:
			var cant_buy = false
			if item.purchase_limit != -1:
				for i in Game.inventory.list:
					if i.type == item and i.amount >= item.purchase_limit:
						cant_buy = true
			var shop_entry = preload("res://scenes/ui/shop_entry.tscn").instantiate()
			#if roundi((item as ItemType).price) > Game.balance:
				#shop_entry.get_node("Panel").disabled = true
			#else:
				#shop_entry.get_node("Panel").disabled = false
			shop_entry.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.rarity).to_lower() + ".png")
			shop_entry.get_node("TextureRect").texture = item.texture
			shop_entry.get_node("Label").text = (item as ItemType).name + "\n" + str(roundi((item as ItemType).price)) + "g"
			shop_entry.get_node("Panel").connect("pressed", Callable(self, "select_item").bind(item.id))
			if not cant_buy:
				$"UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Rods/ScrollContainer/HBoxContainer".add_child(shop_entry)
		if (item as ItemType).category == Game.Category.BAIT:
			var cant_buy = false
			if item.purchase_limit != -1:
				for i in Game.inventory.list:
					if i.type == item and i.amount >= item.purchase_limit:
						cant_buy = true
			var shop_entry = preload("res://scenes/ui/shop_entry.tscn").instantiate()
			#if roundi((item as ItemType).price) > Game.balance:
				#shop_entry.get_node("Panel").disabled = true
			#else:
				#shop_entry.get_node("Panel").disabled = false
			shop_entry.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.rarity).to_lower() + ".png")
			shop_entry.get_node("TextureRect").texture = item.texture
			shop_entry.get_node("Label").text = (item as ItemType).name + "\n" + str(roundi((item as ItemType).price)) + "g"
			shop_entry.get_node("Panel").connect("pressed", Callable(self, "select_item").bind(item.id))
			if not cant_buy:
				$"UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Bait/ScrollContainer/HBoxContainer".add_child(shop_entry)
		if (item as ItemType).category == Game.Category.TRAPS:
			var cant_buy = false
			if item.purchase_limit != -1:
				for i in Game.inventory.list:
					if i.type == item and i.amount >= item.purchase_limit:
						cant_buy = true
			var shop_entry = preload("res://scenes/ui/shop_entry.tscn").instantiate()
			#if roundi((item as ItemType).price) > Game.balance:
				#shop_entry.get_node("Panel").disabled = true
			#else:
				#shop_entry.get_node("Panel").disabled = false
			shop_entry.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.rarity).to_lower() + ".png")
			shop_entry.get_node("TextureRect").texture = item.texture
			shop_entry.get_node("Label").text = (item as ItemType).name + "\n" + str(roundi((item as ItemType).price)) + "g"
			shop_entry.get_node("Panel").connect("pressed", Callable(self, "select_item").bind(item.id))
			if not cant_buy:
				$"UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Traps/ScrollContainer/HBoxContainer".add_child(shop_entry)
			
	await get_tree().process_frame
	if $UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Rods/ScrollContainer/HBoxContainer.get_children().size() == 0:
		$UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Rods.visible = false
	else:
		$UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Rods.visible = true
	if $UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Traps/ScrollContainer/HBoxContainer.get_children().size() == 0 or Game.level < 10:
		$UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Traps.visible = false
	else:
		$UI/Vendor/TabContainer/Shop/ScrollContainer/VBoxContainer/Traps.visible = true
	var total = 0.0
	var bag = Game.bag.list.duplicate()
	bag.sort_custom(func(a, b): return a.type.rarity > b.type.rarity)
	for item in bag:
		if item.type.category == Game.Category.JUNK or item.type.category == Game.Category.FISH:
			var mult = 1.0
			match int(item.data.get("stars", 0)):
				1: mult = 1.25
				2: mult = 1.5
				3: mult = 2.0
			print(item.type.name)
			print(str(mult))
			print(str(item.data.get("stars", 0)))
			var unit_price = item.type.sell_price * mult
			var stack_price = unit_price * item.amount
			total += stack_price
			var star_icon = "[img width=24 height=24]res://assets/sprites/star.png[/img]"
			var stars_str = star_icon.repeat(item.data.get("stars", 0))
			var sell_entry = preload("res://scenes/ui/sell_entry.tscn").instantiate()
			var separator = " " if item.data.get("stars", 0) > 0 else ""
			sell_entry.get_node("HBoxContainer/Label").text = stars_str + separator + str(item) + ": $" + str(roundi(unit_price)) + " = $" + str(roundi(stack_price))
			sell_entry.get_node("HBoxContainer/TextureRect").texture = item.type.texture
			sell_entry.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
			$UI/Vendor/TabContainer/Sell/ScrollContainer/HBoxContainer.add_child(sell_entry)
	$UI/Vendor/TabContainer/Sell/Total.text = "Total: $" + str(roundi(total))
	
func _on_interaction_started(npc: NPC) -> void:
	$UI/Main.hide()
	interacting = true
	immersive_interact = npc
	print("interaction started")
	
func _on_interaction_ended() -> void:
	$UI/Main.show()
	interacting = false
	immersive_interact = null
	print("interaction ended")

func _on_dialogue_finished(npc: NPC) -> void:
	interacting = false
	immersive_interact = null
	if npc.npc_name == "Sheldon":
		if not $UI/Vendor.visible:
			play_sfx("res://assets/sounds/jingle.ogg", 15)
			$UI/Vendor.visible = true
			$UI/Vendor/ItemPreview.visible = false
			$UI/Inventory.visible = false
			$UI/Main.visible = false
			update_catalog()
	if npc.npc_name == "Shelly":
		if not $UI/Bestiary.visible:
			play_sfx("res://assets/sounds/bookopen.ogg", 10)
			$UI/Bestiary.visible = true
			$UI/Bestiary/ItemPreview.visible = false
			$UI/Inventory.visible = false
			$UI/Main.visible = false
			update_bestiary()

var last_trap: Node2D

func update_trap() -> void:
	for child in $UI/Trap/Container/Inventory/ScrollContainer/GridContainer.get_children():
		child.queue_free()
	for child in $UI/Trap/Container/Bait/ScrollContainer/GridContainer.get_children():
		child.queue_free()
	for child in $UI/Trap/Container/Bait/ScrollContainer2/GridContainer.get_children():
		child.queue_free()
	$UI/Trap/Container/Inventory/Title.text = "Trap (" + str(roundi(last_trap.inventory.total_size())) + "/" + str(roundi(last_trap.trap.space)) + ")"
	$UI/Trap/Container/Bait/Title.text = "Bait (" + str(roundi(last_trap.bait_inventory.total_size())) + "/" + str(roundi(last_trap.trap.bait_storage)) + ")"
	for item in last_trap.inventory.list:
		var fish = preload("res://scenes/ui/inventory_button.tscn").instantiate()
		
		fish.get_node("TextureRect").texture = item.type.texture
		fish.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
		fish.connect("pressed", Callable(self, "collect_from_trap").bind(item.type, item.amount))
		fish.get_node("Equipped").hide()
		fish.get_node("Label").show()
		fish.get_node("Label").text = "x" + str(roundi(item.amount))
		$UI/Trap/Container/Inventory/ScrollContainer/GridContainer.add_child(fish)
	
	for item in last_trap.bait_inventory.list:
		var btn = preload("res://scenes/ui/inventory_button.tscn").instantiate()
		btn.get_node("TextureRect").texture = item.type.texture
		btn.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
		btn.connect("pressed", Callable(self, "remove_bait_from_trap").bind(item.type, item.amount))
		btn.get_node("Equipped").hide()
		btn.get_node("Label").show()
		btn.get_node("Label").text = "x" + str(roundi(item.amount))
		$UI/Trap/Container/Bait/ScrollContainer/GridContainer.add_child(btn)

	for item in Game.inventory.list:
		if not item.type is Bait:
			continue
		var btn = preload("res://scenes/ui/inventory_button.tscn").instantiate()
		btn.get_node("TextureRect").texture = item.type.texture
		btn.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
		btn.connect("pressed", Callable(self, "insert_bait_into_trap").bind(item.type, item.amount))
		btn.get_node("Equipped").hide()
		btn.get_node("Label").show()
		btn.get_node("Label").text = "x" + str(roundi(item.amount))
		$UI/Trap/Container/Bait/ScrollContainer2/GridContainer.add_child(btn)
	
func insert_bait_into_trap(item: ItemType, amount: int) -> void:
	var take_amount = amount if Input.is_key_pressed(KEY_SHIFT) else 1
	if last_trap.bait_inventory.total_size() + take_amount > last_trap.trap.bait_storage:
		Toast.add("The trap's bait storage is full!")
		return
	play_sfx("res://assets/sounds/squelch.ogg", 1.0)
	Game.inventory.take_item(item, take_amount)
	last_trap.bait_inventory.add_item(ItemStack.new(item, take_amount))
	update_trap()

func remove_bait_from_trap(item: ItemType, amount: int) -> void:
	var take_amount = amount if Input.is_key_pressed(KEY_SHIFT) else 1
	last_trap.bait_inventory.take_item(item, take_amount)
	Game.inventory.add_item(ItemStack.new(item, take_amount))
	update_trap()
	
var xp_table := {
	Game.Rarity.COMMON:    50.0,
	Game.Rarity.UNCOMMON:  100.0,
	Game.Rarity.RARE:      750.0,
	Game.Rarity.EPIC:      2000.0,
	Game.Rarity.LEGENDARY: 7500.0
}
	
func collect_all_from_trap() -> void:
	var full = false
	for item in last_trap.inventory.list.duplicate():
		if Game.bag.would_fit(ItemStack.new(item.type, item.amount), Game.get_max_inventory_size()):
			last_trap.inventory.take_item(item.type, item.amount)
			Game.catches += item.amount
			Game.add_xp(xp_table.get(item.type.rarity, 0.0) * item.amount)
			Game.bag.add_item(ItemStack.new(item.type, item.amount))
		else:
			full = true
	if full:
		Toast.add("Your tackle box is full, some fish were left behind!")
	update_trap()
	
func collect_from_trap(item: ItemType, amount: int) -> void:
	var take_amount = amount if Input.is_key_pressed(KEY_SHIFT) else 1
	if not Game.bag.would_fit(ItemStack.new(item, take_amount), Game.get_max_inventory_size()):
		Toast.add("Your tackle box doesn't have enough space!")
		return
	last_trap.inventory.take_item(item, take_amount)
	Game.catches += take_amount
	Game.bag.add_item(ItemStack.new(item, take_amount))
	Game.add_xp(xp_table.get(item.rarity, 0.0) * take_amount)
	update_trap()
	
func pickup_trap() -> void:
	if not Game.bag.would_fit_all(last_trap.inventory, Game.get_max_inventory_size()):
		Toast.add("Your tackle box doesn't have enough space to pick up this trap!")
		return
	last_trap.inventory.transfer_limited_to(Game.bag, Game.get_max_inventory_size())
	last_trap.bait_inventory.transfer_all_to(Game.inventory)
	Game.inventory.add_item(ItemStack.new(last_trap.trap, 1))
	Toast.add("You picked up a: " + last_trap.trap.name)
	play_sfx("res://assets/sounds/clang.ogg", 10.0)
	Game.traps = Game.traps.filter(func(t): return t["x"] != last_trap.global_position.x or t["y"] != last_trap.global_position.y)
	last_trap.queue_free()
	$UI/Trap.hide()
	$UI/Main.show()
	
func _input(event: InputEvent) -> void:
	# Zoom
	if event.is_action_pressed("zoom_in"):
		intended_zoom = Vector2(
			clamp(intended_zoom.x + 0.75, 1, 4.5),
			clamp(intended_zoom.y + 0.75, 1, 4.5)
		)
	elif event.is_action_pressed("zoom_out"):
		intended_zoom = Vector2(
			clamp(intended_zoom.x - 0.75, 1, 4.5),
			clamp(intended_zoom.y - 0.75, 1, 4.5)
		)

	# Shop interaction toggle
	if event.is_action_released("interact") and not interacting:
		if state == FishState.INACTIVE and not $UI/Inventory.visible:
			if not $UI/Vendor.visible:
				for body in $Interaction.get_overlapping_areas():
					if body.is_in_group("shop"):
						var npc = body.get_node("..") as NPC
						if not npc.dialogue_finished.is_connected(_on_dialogue_finished):
							npc.dialogue_finished.connect(_on_dialogue_finished.bind(npc), CONNECT_ONE_SHOT)
						if not npc.interaction_started.is_connected(_on_interaction_started):
							npc.interaction_started.connect(_on_interaction_started.bind(npc), CONNECT_ONE_SHOT)
						if not npc.interaction_ended.is_connected(_on_interaction_ended):
							npc.interaction_ended.connect(_on_interaction_ended, CONNECT_ONE_SHOT)
		
						npc.start_dialogue()
						interacting = true
			else:
				$UI/Vendor.visible = false
				$UI/Main.visible = true
			if not $UI/Bestiary.visible:
				for body in $Interaction.get_overlapping_areas():
					if body.is_in_group("bestiary"):
						var npc = body.get_node("..") as NPC
						if not npc.dialogue_finished.is_connected(_on_dialogue_finished):
							npc.dialogue_finished.connect(_on_dialogue_finished.bind(npc), CONNECT_ONE_SHOT)
						if not npc.interaction_started.is_connected(_on_interaction_started):
							npc.interaction_started.connect(_on_interaction_started.bind(npc), CONNECT_ONE_SHOT)
						if not npc.interaction_ended.is_connected(_on_interaction_ended):
							npc.interaction_ended.connect(_on_interaction_ended, CONNECT_ONE_SHOT)
		
						npc.start_dialogue()
						interacting = true
			else:
				$UI/Bestiary.visible = false
				$UI/Main.visible = true
			if not $UI/Trap.visible:
				var closest_trap = null
				var closest_distance = INF

				for body in $Interaction.get_overlapping_areas():
					if body.is_in_group("trap"):
						var distance = global_position.distance_squared_to(body.global_position)

						if distance < closest_distance:
							closest_distance = distance
							closest_trap = body

				if closest_trap:
					play_sfx("res://assets/sounds/cageopen.ogg", 12.0)
					last_trap = closest_trap.get_node("..")
					if not last_trap.is_connected("trap_updated", update_trap):
						last_trap.connect("trap_updated", update_trap)
					else:
						last_trap.disconnect("trap_updated", update_trap)
						last_trap.connect("trap_updated", update_trap)
					update_trap()
					$UI/Main.visible = false
					$UI/Trap.visible = true
			else:
				$UI/Trap.visible = false
				$UI/Main.visible = true

	# Let UI consume input first
	if _is_ui_blocking():
		return

	# --- Fishing actions (blocked if no rod equipped) ---
	if Game.equipped_fishing_rod == null:
		if event.is_action_pressed("fish"):
			Toast.add("You can't fish without a [img center region=0,0,16,16 width=16 height=16]res://assets/sprites/items.png[/img] Fishing Rod.")
		return

	if near_shop():
		return

	# Confirm catch & start minigame
	if event.is_action_pressed("fish") and state == FishState.FOUND_FISH:
		state = FishState.REELING
		$Minigame.visible = true
		$Minigame.position = Vector2(0, 0)
		$Minigame.scale = Vector2(0.1, 0.1)
		var fish: Fish = Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id"))
		if fish.difficulty == Game.Difficulty.EASY:
			add_fish(10, 40, 3, 3)
		elif fish.difficulty == Game.Difficulty.MEDIUM:
			add_fish(20, 50, 5, 2.5)
		elif fish.difficulty == Game.Difficulty.HARD:
			add_fish(30, 60, 6, 2.0)
		elif fish.difficulty == Game.Difficulty.INSANE:
			add_fish(40, 70, 8, 1.2)
		else:
			print("Unsupported fish difficulty.")

	# Begin charging cast
	if event.is_action_pressed("fish") and state == FishState.INACTIVE and fish_control_safe and Game.equipped_trap == null:
		$FishPowerBar.visible = true
		$FishPowerBar.value = 0
		hantenjutsushiki = false

	# Release cast
	if event.is_action_released("fish") and state == FishState.INACTIVE and fish_control_safe and Game.equipped_trap == null:
		$FishPowerBar.visible = false
		hantenjutsushiki = false
		var fish_dir := last_direction
		bobber_safe = true
		play_animation(body_type + "_fish_" + fish_dir)
		fish_control_safe = false
		if bobber != null:
			bobber.queue_free()

	# Allow fishing again after any fish button release (prevents accidental re-cast)
	if event.is_action_released("fish"):
		fish_control_safe = true


## Continuous per-frame logic: movement, physics, hold-to-reel, power bar charge.
func _process_input(delta: float) -> void:
	# Movement
	velocity = Vector2.ZERO if _is_ui_blocking() else Input.get_vector("left", "right", "up", "down", 0.1)
	var velocity_length := velocity.length_squared()
	var is_moving := velocity_length > 0

	# Hold fish button to reel bobber back manually
	if Input.is_action_pressed("fish") and state == FishState.FISHING and not bobber_safe:
		if bobber != null:
			if randf() < 0.2:
				play_sfx_briefly("res://assets/sounds/reeling.ogg", 0.2, -2)
			bobber.global_position = bobber.global_position.move_toward(
				get_rod_tip(get_fishing_direction()),
				40.0 * delta
			)
			var tile_map := get_parent().get_node("Ground") as TileMapLayer
			var bobber_pos := tile_map.to_local(bobber.global_position)
			var data := tile_map.get_cell_tile_data(tile_map.local_to_map(bobber_pos))
			var aboveground = get_parent().get_node("Aboveground") as TileMapLayer
			var aboveground2 = get_parent().get_node("Aboveground2") as TileMapLayer
			if aboveground.get_cell_source_id(tile_map.local_to_map(bobber_pos)) != -1:
				data = aboveground.get_cell_tile_data(tile_map.local_to_map(bobber_pos))
			if aboveground2.get_cell_source_id(tile_map.local_to_map(bobber_pos)) != -1:
				data = aboveground2.get_cell_tile_data(tile_map.local_to_map(bobber_pos))
			if not (data and data.get_custom_data("water")):
				_cancel_bobber("The bobber landed on an invalid location.")
			elif round(bobber.global_position.distance_to(get_rod_tip(get_fishing_direction()))) == 0:
				print("Player reeled in their bobber.")
				_cancel_bobber()

	# Hook minigame physics
	if Input.is_action_pressed("fish"):
		if hook_velocity > -max_velocity:
			hook_velocity -= hook_acceleration * delta
		hook_velocity -= hook_press_acceleration * delta
	else:
		if hook_velocity < max_velocity:
			hook_velocity += hook_deceleration * delta

	var target = $Minigame/Hook.position.y + hook_velocity
	if target >= 33.5:
		hook_velocity *= -bounce
	elif target <= -33.5:
		hook_velocity = 0
		$Minigame/Hook.position.y = -33.5
	else:
		$Minigame/Hook.position.y = target

	# Reeling minigame progress
	if state == FishState.REELING:
		$Minigame.visible = true
		if bobber != null and not bobber.get_node("Splashes").emitting:
			bobber.get_node("Splashes").restart()

		if len($Minigame/Hook/Area2D.get_overlapping_areas()) > 0:
			$Minigame/Progress.value += 145 * delta
			$Minigame/Column.get_children()[0].set_vibrate(true)
			Input.vibrate_handheld(10)
			if randf() < 0.1:
				play_sfx_briefly("res://assets/sounds/squeak.ogg", 0.2, 1)
			if $Minigame/Progress.value >= $Minigame/Progress.max_value:
				_on_fish_caught()
		else:
			$Minigame/Column.get_children()[0].set_vibrate(false)
			$Minigame/Progress.value -= 85 * delta
			if randf() < 0.1:
				play_sfx_briefly("res://assets/sounds/swim.ogg", 0.3, 1.5)
			if $Minigame/Progress.value <= 0:
				_on_fish_lost()
	else:
		$Minigame.visible = false
		for child in $Minigame/Column.get_children():
			child.queue_free()

	# Trap placement highlight
	if Game.equipped_trap != null:
		$Trap.show()
		var tilemap := get_parent().get_node("Ground") as TileMapLayer
		var mouse_tile := tilemap.local_to_map(tilemap.get_local_mouse_position())
		var data := tilemap.get_cell_tile_data(mouse_tile)
		var aboveground = get_parent().get_node("Aboveground") as TileMapLayer
		var aboveground2 = get_parent().get_node("Aboveground2") as TileMapLayer
		var no_aboveground = aboveground.get_cell_source_id(mouse_tile) == -1 and aboveground2.get_cell_source_id(mouse_tile) == -1
		var tile_occupied = Game.traps.any(func(t): return tilemap.local_to_map(tilemap.to_local(Vector2(t["x"], t["y"]))) == mouse_tile)
		if no_aboveground and data and data.get_custom_data("water") and not tile_occupied and global_position.distance_to(tilemap.map_to_local(mouse_tile)) < BASE_TRAP_PLACE_DISTANCE:
			$Trap.global_position = tilemap.map_to_local(mouse_tile)
			selected_tile = mouse_tile
		else:
			$Trap.hide()
			selected_tile = Vector2i(0, 0)
	else:
		$Trap.hide()
		selected_tile = Vector2i(0, 0)


	# Movement animations & state reset on move
	if is_moving:
		bobber_safe = true
		state = FishState.INACTIVE
		if bobber != null:
			bobber.queue_free()
			bobber = null
		velocity_length = min(1, 0.5 + velocity_length)

		if abs(velocity.x) > abs(velocity.y):
			last_direction = "right" if velocity.x > 0 else "left"
		else:
			last_direction = "down" if velocity.y > 0 else "up"

		if $Base.animation != body_type + "_walk_" + last_direction:
			play_animation(body_type + "_walk_" + last_direction, false, velocity_length * 1.2)
	else:
		if $Base.animation.begins_with(body_type + "_walk"):
			play_idle_animation()

	velocity = velocity.normalized() * BASE_WALKING_SPEED

	# Power bar charge (held fish button while idle)
	if not near_shop() and not _is_ui_blocking() and Game.equipped_fishing_rod != null:
		if Input.is_action_pressed("fish") and state == FishState.INACTIVE and fish_control_safe:
			if hantenjutsushiki:
				$FishPowerBar.value -= randi_range(1, 3)
				if $FishPowerBar.value <= 0:
					hantenjutsushiki = false
			else:
				$FishPowerBar.value += randi_range(1, 3)
				if $FishPowerBar.value >= 100:
					hantenjutsushiki = true

	# Hide power bar if inventory opens mid-charge
	if $FishPowerBar.visible and ($UI/Inventory.visible or Game.equipped_trap != null or bobber != null):
		$FishPowerBar.hide()
		hantenjutsushiki = false

	# Trap placement
	if Game.equipped_trap != null and selected_tile != Vector2i(0, 0) and Input.is_action_just_pressed("fish"):
		if Game.traps.size() >= Game.get_max_traps():
			Toast.add("You have too many traps down!")
			return
		var placed_trap = preload("res://scenes/trap.tscn").instantiate()
		placed_trap.trap = Game.equipped_trap
		var tilemap := get_parent().get_node("Ground") as TileMapLayer
		var data := tilemap.get_cell_tile_data(selected_tile)
		placed_trap.location = Game.Location.get(data.get_custom_data("location"))
		placed_trap.global_position = tilemap.map_to_local(selected_tile)
		get_parent().add_child(placed_trap, true)
		Game.inventory.take_item(Game.equipped_trap, 1)
		Game.traps.append({
			"x": placed_trap.global_position.x,
			"y": placed_trap.global_position.y,
			"location": placed_trap.location,
			"inventory": placed_trap.inventory,
			"bait_inventory": placed_trap.bait_inventory,
			"trap": placed_trap.trap
		})
		play_sfx("res://assets/sounds/dunk.ogg", 8)
		Toast.add("You placed down a: " + Game.equipped_trap.name + "!")
		Game.equipped_trap = null
		fish_control_safe = false

	if velocity.length() > 0:
		step_timer -= delta
		if step_timer <= 0.0:
			var footsteps = [
				"res://assets/sounds/walk1.wav",
				"res://assets/sounds/walk2.wav",
				"res://assets/sounds/walk3.wav",
				"res://assets/sounds/walk4.wav"
			]
			play_sfx(footsteps.pick_random(), -5)
			step_timer = step_interval + randf_range(0.02, 0.08)
	else:
		step_timer = 0.0

	move_and_slide()
	global_position = round(global_position / 2) * 2


# --- Helpers ---

## Returns true whenever UI should block all gameplay input.
func _is_ui_blocking() -> bool:
	return (
		state == FishState.REELING
		or state == FishState.FISHING
		or $UI/Vendor.visible
		or $UI/Bestiary.visible
		or $UI/Inventory.visible
		or $UI/Trap.visible
		or immersive_interact != null
	)

## Frees the bobber and returns the player to INACTIVE.
func _cancel_bobber(message: String = "") -> void:
	if message != "":
		print(message)
	state = FishState.INACTIVE
	bobber_safe = true
	fish_control_safe = false
	play_idle_animation()
	if bobber != null:
		bobber.queue_free()

func _on_fish_caught() -> void:
	print("Caught the fish.")
	if bobber != null:
		var stack := ItemStack.new(Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id")), 1)
		stack.data["stars"] = Game.roll_stars()
		if Game.bag.total_size() > Game.get_max_inventory_size():
			Toast.add("Your tackle box is full! You released the %s %s back into the water!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
		else:
			Game.bag.add_item(stack)
			var speech_bubble = load("res://scenes/ui/speech_bubble.tscn").instantiate()
			add_child(speech_bubble)
			var star_icon = "[img width=16 height=16]res://assets/sprites/star.png[/img]"
			var stars = star_icon.repeat(stack.data.get("stars", 0)) + " " if stack.data.get("stars", 0) > 0 else ""
			speech_bubble.play_line("You caught a %s%s%s %s!" % [stars, Game.get_rarity_color(stack.type.rarity), Game.Rarity.find_key(stack.type.rarity), stack.type.name], Vector2(global_position.x, global_position.y - 8), 30)
			#Toast.add("You caught a %s %s!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
			Game.bestiary[str(stack.type.id)] = Game.bestiary.get(str(stack.type.id), 0) + stack.amount
			Game.highest_star[str(stack.type.id)] = max(
				Game.highest_star.get(str(stack.type.id), 0),
				stack.data.get("stars", 0)
			)
			play_sfx("res://assets/sounds/catch.ogg", 2)
	state = FishState.REELING_BACK
	bobber.get_node("Splashes").amount = 64
	Game.catches += 1

	var fish := Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id"))
	var xp_table := {
		Game.Rarity.COMMON:    50.0,
		Game.Rarity.UNCOMMON:  100.0,
		Game.Rarity.RARE:      750.0,
		Game.Rarity.EPIC:      2000.0,
		Game.Rarity.LEGENDARY: 7500.0
	}
	Game.add_xp(xp_table.get(fish.rarity, 0.0))

func _on_fish_lost() -> void:
	state = FishState.INACTIVE
	bobber_safe = true
	play_idle_animation()
	print("Lost the fish.")
	Game.whiffs += 1
var i_float_timer = 0.0

func set_trap(id: int) -> void:
	if state != FishState.INACTIVE:
		Toast.add("You can't equip a trap while fishing.")
		return
	if id != -1:
		if Catalog.get_item(id) is Trap:
			if Game.equipped_trap != Catalog.get_item(id):
				Toast.add("Equipped " + str(Catalog.get_item(id).name) + ".")
			Game.equipped_trap = Catalog.get_item(id)
			play_sfx("res://assets/sounds/cageopen.ogg", 12)
		else:
			LimboConsole.error("This doesn't seem to be a trap.")
	else:
		Toast.add("Unequipped your trap.")
		Game.equipped_trap = null
	update_inventory()

func set_bait(id: int) -> void:
	if state != FishState.INACTIVE:
		Toast.add("You can't switch bait while fishing.")
		return
	if id != -1:
		if Catalog.get_item(id) is Bait:
			if Game.equipped_bait != Catalog.get_item(id):
				Toast.add("Equipped " + str(Catalog.get_item(id).name) + ".")
				if not Game.equipped_fishing_rod.baitable:
					Toast.add("The bait won't work unless you have a [img center region=0,0,16,16 width=16 height=16]res://assets/sprites/items.png[/img] Fishing Rod that can be baited.")
			Game.equipped_bait = Catalog.get_item(id)
			play_sfx("res://assets/sounds/squelch.ogg", 20.0)
		else:
			LimboConsole.error("This doesn't seem to be bait.")
	else:
		Toast.add("Removed currently equipped bait.")
		Game.equipped_bait = null
	update_inventory()

func set_fishing_rod(id: int) -> void:
	if state != FishState.INACTIVE:
		Toast.add("You can't switch [img center region=0,0,16,16 width=16 height=16]res://assets/sprites/items.png[/img] Fishing Rods while fishing.")
		return
	if id != -1:
		if Catalog.get_item(id) is FishingRod:
			play_sfx("res://assets/sounds/clunk.ogg", 1.0)
			if Game.equipped_fishing_rod != Catalog.get_item(id):
				Toast.add("Equipped: [img center region=" + str(Game.equipped_fishing_rod.texture.region.position.x) + "," + str(Game.equipped_fishing_rod.texture.region.position.y) + "," + str(16) + "," + str(16) + "width=16 height=16]res://assets/sprites/items.png[/img] " + str(Catalog.get_item(id).name))
			Game.equipped_fishing_rod = Catalog.get_item(id)
		else:
			LimboConsole.error("This doesn't seem to be a [img center region=0,0,16,16 width=16 height=16]res://assets/sprites/items.png[/img] Fishing Rod.")
	else:
		if Game.equipped_fishing_rod != null:
			Toast.add("Removed currently equipped [img center region=" + str(Game.equipped_fishing_rod.texture.region.position.x) + "," + str(Game.equipped_fishing_rod.texture.region.position.y) + "," + str(16) + "," + str(16) + "width=16 height=16]res://assets/sprites/items.png[/img] Fishing Rod.")
		Game.equipped_fishing_rod = null
	update_inventory()

func update_inventory() -> void:
	for child in $UI/Inventory/ScrollContainer/VBoxContainer.get_children():
		child.queue_free()
	for child in $"UI/Inventory/Container/Fishing Rods/GridContainer".get_children():
		child.queue_free()
	for child in $"UI/Inventory/Container/Bait/GridContainer".get_children():
		child.queue_free()
	for child in $"UI/Inventory/Container/Traps/GridContainer".get_children():
		child.queue_free()
	for i in range($UI/Inventory/Container.get_tab_count()):
		if $UI/Inventory/Container.get_tab_title(i) == "Bait":
			if Game.level < 5:
				$UI/Inventory/Container.set_tab_hidden(i, true)
			else:
				$UI/Inventory/Container.set_tab_hidden(i, false)
		if $UI/Inventory/Container.get_tab_title(i) == "Traps":
			if Game.level < 10:
				$UI/Inventory/Container.set_tab_hidden(i, true)
			else:
				$UI/Inventory/Container.set_tab_hidden(i, false)
	$UI/Inventory/Title.text = "Tackle Box (" + str(Game.bag.total_size()) + "/" + str(Game.get_max_inventory_size()) + "):"
	var inventory_button = preload("res://scenes/ui/inventory_button.tscn").instantiate()
	inventory_button.get_node("Rarity").texture = null
	inventory_button.get_node("TextureRect").texture = load("res://assets/sprites/cross.png")
	if Game.equipped_fishing_rod != null:
		inventory_button.get_node("Equipped").hide()
	inventory_button.connect("pressed", Callable(self, "set_fishing_rod").bind(-1))
	$"UI/Inventory/Container/Fishing Rods/GridContainer".add_child(inventory_button)

	inventory_button = preload("res://scenes/ui/inventory_button.tscn").instantiate()
	inventory_button.get_node("Rarity").texture = null
	inventory_button.get_node("TextureRect").texture = load("res://assets/sprites/cross.png")
	if Game.equipped_bait != null:
		inventory_button.get_node("Equipped").hide()
	inventory_button.connect("pressed", Callable(self, "set_bait").bind(-1))
	$"UI/Inventory/Container/Bait/GridContainer".add_child(inventory_button)
	
	inventory_button = preload("res://scenes/ui/inventory_button.tscn").instantiate()
	inventory_button.get_node("Rarity").texture = null
	inventory_button.get_node("TextureRect").texture = load("res://assets/sprites/cross.png")
	if Game.equipped_bait != null:
		inventory_button.get_node("Equipped").hide()
	inventory_button.connect("pressed", Callable(self, "set_trap").bind(-1))
	$"UI/Inventory/Container/Traps/GridContainer".add_child(inventory_button)

	if Game.equipped_bait == null:
		$"UI/Inventory/Container/Bait/Equipped/Icon".texture = load("res://assets/sprites/cross.png")
		$"UI/Inventory/Container/Bait/Equipped/Name".text = "Nothing"
		$"UI/Inventory/Container/Bait/Equipped/Description".text = "You have no bait equipped, buy some in the shop."
		$"UI/Inventory/Container/Bait/Equipped/Stats".text = "Nothing: +0"
	else:
		$"UI/Inventory/Container/Bait/Equipped/Icon".texture = Game.equipped_bait.texture
		$"UI/Inventory/Container/Bait/Equipped/Name".text = Game.equipped_bait.name
		$"UI/Inventory/Container/Bait/Equipped/Description".text = Game.equipped_bait.description
		$"UI/Inventory/Container/Bait/Equipped/Stats".text = ""
		var index = 0
		for key in Game.equipped_bait.data["extra_stats"].keys():
			index += 1
			$"UI/Inventory/Container/Bait/Equipped/Stats".text += str(key) + ": " + str(Game.equipped_bait.data["extra_stats"][key])
			if index < Game.equipped_bait.data["extra_stats"].keys().size():
				$"UI/Inventory/Container/Bait/Equipped/Stats".text += "\n"

	if Game.equipped_trap == null:
		$"UI/Inventory/Container/Traps/Equipped/Icon".texture = load("res://assets/sprites/cross.png")
		$"UI/Inventory/Container/Traps/Equipped/Name".text = "Nothing"
		$"UI/Inventory/Container/Traps/Equipped/Description".text = "You have no trap equipped, they're probably all being cast, but if you don't have any, buy one in the shop."
		$"UI/Inventory/Container/Traps/Equipped/Stats".text = "Nothing: +0"
	else:
		$"UI/Inventory/Container/Traps/Equipped/Icon".texture = Game.equipped_trap.texture
		$"UI/Inventory/Container/Traps/Equipped/Name".text = Game.equipped_trap.name
		$"UI/Inventory/Container/Traps/Equipped/Description".text = Game.equipped_trap.description
		if randf() < 0.2:
			$"UI/Inventory/Container/Traps/Equipped/Description".text = $"UI/Inventory/Container/Traps/Equipped/Description".text.replace("flimsy", "flismy")
		$"UI/Inventory/Container/Traps/Equipped/Stats".text = ""
		var index = 0
		for key in Game.equipped_trap.data["extra_stats"].keys():
			index += 1
			$"UI/Inventory/Container/Traps/Equipped/Stats".text += str(key) + ": " + str(Game.equipped_trap.data["extra_stats"][key])
			if index < Game.equipped_trap.data["extra_stats"].keys().size():
				$"UI/Inventory/Container/Traps/Equipped/Stats".text += "\n"
				
	if Game.equipped_fishing_rod == null:
		$"UI/Inventory/Container/Fishing Rods/Equipped/Icon".texture = load("res://assets/sprites/cross.png")
		$"UI/Inventory/Container/Fishing Rods/Equipped/Name".text = "Nothing"
		$"UI/Inventory/Container/Fishing Rods/Equipped/Description".text = "You have no Fishing Rod equipped, buy one in the shop."
		$"UI/Inventory/Container/Fishing Rods/Equipped/Stats".text = "Nothing: +0"
	else:
		$"UI/Inventory/Container/Fishing Rods/Equipped/Icon".texture = Game.equipped_fishing_rod.texture
		$"UI/Inventory/Container/Fishing Rods/Equipped/Name".text = Game.equipped_fishing_rod.name
		$"UI/Inventory/Container/Fishing Rods/Equipped/Description".text = Game.equipped_fishing_rod.description
		if randf() < 0.2:
			$"UI/Inventory/Container/Fishing Rods/Equipped/Description".text = $"UI/Inventory/Container/Fishing Rods/Equipped/Description".text.replace("Flimsy Fishing Rod", "Flismy Fshing Bod")
		$"UI/Inventory/Container/Fishing Rods/Equipped/Stats".text = ""
		var index = 0
		for key in Game.equipped_fishing_rod.data["extra_stats"].keys():
			index += 1
			$"UI/Inventory/Container/Fishing Rods/Equipped/Stats".text += str(key) + ": " + str(Game.equipped_fishing_rod.data["extra_stats"][key])
			if index < Game.equipped_fishing_rod.data["extra_stats"].keys().size():
				$"UI/Inventory/Container/Fishing Rods/Equipped/Stats".text += "\n"

	var bag = Game.bag.list.duplicate()
	bag.sort_custom(func(a, b): return a.type.rarity > b.type.rarity)
	var total = 0.0
	for item in bag:
		var mult = 1.0
		match int(item.data.get("stars", 0)):
			1: mult = 1.25
			2: mult = 1.5
			3: mult = 2.0
		var star_icon = "[img width=16 height=16]res://assets/sprites/star.png[/img]"
		var stars_str = star_icon.repeat(item.data.get("stars", 0))
		var separator = " " if item.data.get("stars", 0) > 0 else ""
		var inventory_entry = preload("res://scenes/ui/inventory_entry.tscn").instantiate()
		inventory_entry.get_node("Label").text = stars_str + separator + str(item.amount) + "x " + str(item.type.name)
		inventory_entry.get_node("TextureRect").texture = item.type.texture
		inventory_entry.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
		total += item.type.sell_price * mult * item.amount
		$UI/Inventory/ScrollContainer/VBoxContainer.add_child(inventory_entry)
	$UI/Inventory/Amount.text = "Total: $" + str(roundi(total))
	var inventory = Game.inventory.list.duplicate()
	inventory.sort_custom(func(a, b): return a.type.rarity > b.type.rarity)
	for item in inventory:
		if item.type.category == Game.Category.RODS:
			inventory_button = preload("res://scenes/ui/inventory_button.tscn").instantiate()
			inventory_button.get_node("TextureRect").texture = item.type.texture
			if Game.equipped_fishing_rod != item.type:
				inventory_button.get_node("Equipped").hide()
			inventory_button.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
			inventory_button.connect("pressed", Callable(self, "set_fishing_rod").bind(item.type.id))
			$"UI/Inventory/Container/Fishing Rods/GridContainer".add_child(inventory_button)
		if item.type.category == Game.Category.BAIT:
			inventory_button = preload("res://scenes/ui/inventory_button.tscn").instantiate()
			inventory_button.get_node("TextureRect").texture = item.type.texture
			if Game.equipped_bait != item.type:
				inventory_button.get_node("Equipped").hide()
			if item.amount == 1:
				inventory_button.get_node("Label").visible = false
			else:	
				inventory_button.get_node("Label").visible = true
				inventory_button.get_node("Label").text = "x" + str(item.amount)
			inventory_button.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
			inventory_button.connect("pressed", Callable(self, "set_bait").bind(item.type.id))
			$"UI/Inventory/Container/Bait/GridContainer".add_child(inventory_button)
		if item.type.category == Game.Category.TRAPS:
			inventory_button = preload("res://scenes/ui/inventory_button.tscn").instantiate()
			inventory_button.get_node("TextureRect").texture = item.type.texture
			if Game.equipped_trap != item.type:
				inventory_button.get_node("Equipped").hide()
			if item.amount == 1:
				inventory_button.get_node("Label").visible = false
			else:	
				inventory_button.get_node("Label").visible = true
				inventory_button.get_node("Label").text = "x" + str(item.amount)
			inventory_button.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
			inventory_button.connect("pressed", Callable(self, "set_trap").bind(item.type.id))
			$"UI/Inventory/Container/Traps/GridContainer".add_child(inventory_button)

func near_shop() -> bool:
	for body in $Interaction.get_overlapping_areas():
		if body.is_in_group("shop"):
			return true
	return false

func _process_ui(delta: float) -> void:
	$InteractionMark.visible = false
	var t = Game.time / Game.TIME_IN_DAY
	var day_factor = sin(t * PI)
	var light_energy = lerp(0.2, 0.0, day_factor)
	$PointLight2D.energy = light_energy
	$PointLight2D2.energy = light_energy
	if Game.equipped_bait != null and Game.equipped_fishing_rod != null and Game.equipped_fishing_rod.baitable and not _is_ui_blocking():
		$UI/Main/Bait.visible = true
		$UI/Main/Bait/HBoxContainer/TextureRect.texture = Game.equipped_bait.texture
		$UI/Main/Bait/HBoxContainer/Label.text = "x" + str(Game.inventory.get_item_stack(Game.equipped_bait).amount)
	else:
		$UI/Main/Bait.visible = false
	if $UI/Vendor.visible:
		var panel_width = -$UI/Vendor/TabContainer.size.x
		var offset = (panel_width / 2.0) / $Camera2D.zoom.x
		var target_pos = global_position + Vector2(offset, 0)
		$Camera2D.global_position = $Camera2D.global_position.lerp(target_pos, 5.0 * delta)
	elif $UI/Bestiary.visible:
		var panel_width = -$UI/Bestiary/List.size.x
		var offset = (panel_width / 2.0) / $Camera2D.zoom.x
		var target_pos = global_position + Vector2(offset, 0)
		$Camera2D.global_position = $Camera2D.global_position.lerp(target_pos, 5.0 * delta)
	elif $UI/Trap.visible:
		var panel_width = -$UI/Trap/Container.size.x
		var offset = (panel_width / 2.0) / $Camera2D.zoom.x
		var target_pos = global_position + Vector2(offset, 0)
		$Camera2D.global_position = $Camera2D.global_position.lerp(target_pos, 5.0 * delta)
	elif immersive_interact != null:
		$Camera2D.global_position = $Camera2D.global_position.lerp(immersive_interact.global_position, 5.0 * delta)
		$Camera2D.zoom = lerp($Camera2D.zoom, Vector2(intended_zoom.x + 0.35, intended_zoom.y + 0.35), 0.002)
	else:
		$Camera2D.global_position = $Camera2D.global_position.lerp(global_position, 5.0 * delta)
	if $Camera2D.zoom != intended_zoom and immersive_interact == null:
		$Camera2D.zoom = lerp($Camera2D.zoom, intended_zoom, 0.2)

	for child in $InteractionMark.get_children():
		child.visible = false
	for body in $Interaction.get_overlapping_areas():
		if body.is_in_group("shop"):
			$InteractionMark.visible = true
			$InteractionMark/Coin.visible = true
			$InteractionMark/Fish.visible = false
			$InteractionMark/Book.visible = false
		if body.is_in_group("bestiary"):
			$InteractionMark.visible = true
			$InteractionMark/Coin.visible = false
			$InteractionMark/Fish.visible = false
			$InteractionMark/Book.visible = true
		if body.is_in_group("trap"):
			$InteractionMark.visible = true
			$InteractionMark/Coin.visible = false
			$InteractionMark/Fish.visible = true
			$InteractionMark/Book.visible = false
	if interacting or $UI/Vendor.visible or $UI/Bestiary.visible:
		$InteractionMark.visible = false
	var percentage_filled = (float(Game.bag.total_size()) / float(Game.get_max_inventory_size())) * 100.0
	if percentage_filled < 50.0:
		$UI/Main/InventoryButton/TextureRect.texture = preload("res://assets/sprites/backpack.png")
	elif percentage_filled > 50.0 and percentage_filled < 90.0:
		$UI/Main/InventoryButton/TextureRect.texture = preload("res://assets/sprites/backpack-bloated.png")
	else:
		$UI/Main/InventoryButton/TextureRect.texture = preload("res://assets/sprites/backpack-full.png")
	#$UI/Main/InventoryButton.text = "   Inventory (" + str(Game.bag.total_size()) + "/" +  str(Game.get_max_inventory_size()) + ")"
	i_float_timer += delta * 8.0
	$InteractionMark.position.y = -24 + (1.2 * sin(i_float_timer))
	$UI/Main/LevelBar/Label.text = "Lv." + str(Game.level) 
	$UI/Main/LevelBar.value = roundi(Game.xp)
	$UI/Main/LevelBar.max_value = roundi(Game.calculate_xp_for_level(Game.level))
	if Game.equipped_fishing_rod != null:
		$UI/Main/LevelBar/TextureRect.texture = Game.equipped_fishing_rod.texture
	else:
		$UI/Main/LevelBar/TextureRect.texture = preload("res://assets/sprites/cross.png")
	if Game.equipped_trap != null:
		$UI/Main/LevelBar/TextureRect.texture = Game.equipped_trap.texture
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
	$UI/Main/Combination/Time/TextureRect.texture = symbol
	$UI/Main/Combination/Time/Label.text = str(Game.get_time_string())
	#$UI/Main/Time/Days.text = "Day: " + str(Game.days)
	$UI/Main/LevelBar/Label.text = "Lv." + str(Game.level) 
	$UI/Main/Combination/Balance/Label.text = "$" + str(roundi(Game.balance))
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
	
	if Input.is_action_just_released("inventory") and (not $UI/Vendor.visible and not $UI/Bestiary.visible and not $UI/Trap.visible):
		if not $UI/Inventory.visible:
			$UI/Main/Combination.hide()
			$UI/Main/LevelBar.hide()
			$UI/Main/InventoryButton.hide()
			$UI/Inventory.show()
			play_sfx("res://assets/sounds/open.ogg", 5.0)
			update_inventory()
		else:
			$UI/Main/Combination.show()
			$UI/Main/LevelBar.show()
			$UI/Main/InventoryButton.show()
			$UI/Inventory.hide()
	
	# Update rope physics for fishing line
	if bobber != null:
		# Adjust line tension based on state
		if state == FishState.FOUND_FISH or state == FishState.REELING:
			# Line goes TAUT when fish is hooked
			line_gravity = 2.0
			line_stiffness = 1.0
		elif state == FishState.FISHING:
			# Gentle sag when passively fishing
			line_gravity = 5.1
			line_stiffness = 0.5
		
		update_fishing_line(delta)

		if state == FishState.REELING_BACK:
			# Tighten line when reeling back
			line_gravity = 0.01
			line_stiffness = 0.95
			
			var distance_to_rod = bobber.global_position.distance_to(get_rod_tip(get_fishing_direction()))
			if distance_to_rod > 30:
				line_gravity = 0.01 
				line_stiffness = 0.98 
			else:
				line_gravity = 0.01
				line_stiffness = 0.95
			var direction_to_rod = (get_rod_tip(get_fishing_direction()) - bobber.global_position).normalized()
			if Game.bestiary.get(bobber.get_node("Bobber Fish").get_meta("fish_id"), 0) > 9:
				bobber.global_position += direction_to_rod * 160.0 * delta
			else:
				bobber.global_position += direction_to_rod * 80.0 * delta
			bobber.get_node("Bobber Fish").get_node("Sprite2D").visible = true
			bobber.get_node("Splashes").restart()
			if randf() < 0.3:
				play_sfx_briefly("res://assets/sounds/reeling.ogg", 0.2, 0.25)
			if round(bobber.global_position.distance_to(get_rod_tip(get_fishing_direction()))) <= 10:
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
	odds = randi_range(250, 1100)
	your_odds = 0
	state = FishState.FISHING
	if Game.bag.total_size() > Game.get_max_inventory_size():
		Toast.add("Your tackle box is full, you will release anything you catch.")
	
	var rod_power = Game.get_fishing_power()

	while (state == FishState.FISHING):
		if bobber != null:
			if not bobber.get_node("Ripple").emitting:
				bobber.get_node("Ripple").restart()
		if randf() < 0.2:
			play_sfx_briefly("res://assets/sounds/ripples.ogg", 1.3, -20)
		
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
					if Game.equipped_bait != null and Game.equipped_fishing_rod.baitable:
						Game.inventory.take_item(Game.equipped_bait, 1)
						if not Game.inventory.has_item(Game.equipped_bait):
							Game.equipped_bait = null
							Toast.add("You ran out of bait!")		
					bobber.get_node("Splashes").amount = 64
					var stack = ItemStack.new(Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id")), 1)
					stack.data["stars"] = Game.roll_stars()
					if Game.bag.total_size() > Game.get_max_inventory_size():
						Toast.add("Your tackle box is full! You released the %s %s back into the water!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
					else:
						Game.bag.add_item(stack)
						var speech_bubble = load("res://scenes/ui/speech_bubble.tscn").instantiate()
						add_child(speech_bubble)
						var star_icon = "[img width=16 height=16]res://assets/sprites/star.png[/img]"
						var stars = star_icon.repeat(stack.data.get("stars", 0)) + " " if stack.data.get("stars", 0) > 0 else ""
						speech_bubble.play_line("You caught a %s%s%s %s!" % [stars, Game.get_rarity_color(stack.type.rarity), Game.Rarity.find_key(stack.type.rarity), stack.type.name], Vector2(global_position.x, global_position.y - 8), 30)
						#Toast.add("You caught a %s %s!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
						Game.bestiary[str(stack.type.id)] = Game.bestiary.get(str(stack.type.id), 0) + stack.amount
						Game.highest_star[str(stack.type.id)] = max(
							Game.highest_star.get(str(stack.type.id), 0),
							stack.data.get("stars", 0)
						)
						play_sfx("res://assets/sounds/catch.ogg", 2)
				return
			else:
				play_sfx("res://assets/sounds/oh.ogg", 2.0)
				bobber.get_node("Exclaim").emitting = true
				if fish.rarity == Game.Rarity.COMMON:
					bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-common.png")
				if fish.rarity == Game.Rarity.UNCOMMON:
					bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-uncommon.png")
				if fish.rarity == Game.Rarity.RARE:
					bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-rare.png")
				if fish.rarity == Game.Rarity.EPIC:
					bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-epic.png")
				if fish.rarity == Game.Rarity.LEGENDARY:
					bobber.get_node("Exclaim").texture = preload("res://assets/sprites/caught-fish-legendary.png")
				state = FishState.FOUND_FISH
			await get_tree().create_timer(1.5).timeout
			if state == FishState.FOUND_FISH:
				if bobber != null and bobber_fish != null:
					bobber_fish.queue_free()
				state = FishState.FISHING
				print("Player decided not to catch fish, continuing loop.")
				your_odds = 0
				odds = randi_range(250, 1000)
			else:
				if Game.equipped_bait != null and Game.equipped_fishing_rod.baitable:
					Game.inventory.take_item(Game.equipped_bait, 1)
					if not Game.inventory.has_item(Game.equipped_bait):
						Game.equipped_bait = null
						Toast.add("You ran out of bait!")
				print("Player decided to catch fish, ending loop.")
				return
		var tick_interval = max(0.2, 0.75 - (sqrt(Game.get_quick_bite()) * 0.025))
		await get_tree().create_timer(tick_interval).timeout
		var tick_bonus = sqrt(Game.get_fishing_speed()) * 3.5
		your_odds += randi_range(15, 25) + ($FishPowerBar.value * 0.25) + tick_bonus

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
	if $UI/Bestiary.visible or $UI/Vendor.visible or $UI/Inventory.visible:
		play_idle_animation()
		return
	if $Base.animation.begins_with(prefix):
		play_sfx("res://assets/sounds/whoosh.ogg", 1.0)
		bobber = preload("res://scenes/bobber.tscn").instantiate()
		bobber.position = to_local(get_rod_tip(get_fishing_direction()))
		bobber.get_node("Line2D").set_point_position(0, Vector2(0.0, -1.5))
		add_child(bobber)
		var dir = DIRECTIONS[get_fishing_direction()]
		last_direction = get_fishing_direction()
		
		# Reset line physics for new cast
		line_points.clear()
		line_velocities.clear()
		var rod_tip = get_rod_tip(get_fishing_direction())
		for i in range(line_segments):
			line_points.append(rod_tip)  # Start all points at rod tip
			line_velocities.append(Vector2.ZERO)
		
		# NATURAL ARC CAST
		var power_normalized = $FishPowerBar.value / 100.0
		var baser_distance = 20
		if not Game.equipped_fishing_rod.shoddy:
			baser_distance += 40
		var base_distance = baser_distance + (power_normalized * 100)  # How far it goes
		
		bobber.rotation = 0
		bobber.gravity_scale = 0  # We'll handle gravity manually for better control
		
		# Determine cast type based on direction
		var fishing_dir = get_fishing_direction()
		var is_sideways = (fishing_dir == "left" or fishing_dir == "right")
		
		# Calculate target position
		var target_pos = get_rod_tip(fishing_dir) + (dir * base_distance)
		
		# Initialize line to be taut during cast
		line_gravity = 20.0
		line_stiffness = 0.85
		
		# Natural tumble rotation
		var rotation_impulse = (15 + power_normalized * 25) * (-1 if dir.x > 0 else 1)
		bobber.angular_velocity = rotation_impulse
		
		# Decay rotation naturally
		var rotation_tween = create_tween()
		rotation_tween.tween_property(bobber, "angular_velocity", 0.0, 0.6).set_ease(Tween.EASE_OUT)
		
		if is_sideways:
			# SIDEWAYS: Arc trajectory
			var cast_duration = 0.7 + (power_normalized * 0.4)  # Slower, more visible
			var arc_height = 15 + (power_normalized * 20)  # Much gentler arc
			
			# Animate position with arc using a custom tween
			var cast_tween = create_tween()
			cast_tween.set_trans(Tween.TRANS_QUAD)
			cast_tween.set_ease(Tween.EASE_OUT)
			
			# Track progress for arc calculation 
			var start_pos = bobber.global_position
			cast_tween.tween_method(
				func(t):
					if bobber == null:
						return
					# Parabolic arc: x moves linearly, y follows arc
					var current_x = lerp(start_pos.x, target_pos.x, t)
					var current_y_base = lerp(start_pos.y, target_pos.y, t)
					# Arc peaks at t=0.5, using sine for smooth curve
					var arc_offset = (-sin(t * PI) * arc_height) + 10.0
					bobber.global_position = Vector2(current_x, current_y_base + arc_offset)
					# Simulate velocity for line physics
					bobber.linear_velocity = (bobber.global_position - start_pos) / max(t, 0.01)
					start_pos = bobber.global_position
			, 0.0, 1.0, cast_duration
			)
			
			await cast_tween.finished
			
		else:
			# UP/DOWN: Bounce trajectory (goes up first, then comes down)
			var cast_duration = 0.8 + (power_normalized * 0.3)  # Slower
			var bounce_height = 25 + (power_normalized * 35)  # Gentler bounce
			
			var cast_tween = create_tween()
			cast_tween.set_trans(Tween.TRANS_QUAD)
			
			var start_pos = bobber.global_position
			var is_down = (fishing_dir == "down")
			
			# First: bounce UP
			var up_pos = start_pos + Vector2(0, -bounce_height)
			cast_tween.tween_property(bobber, "global_position", up_pos, cast_duration * 0.3).set_ease(Tween.EASE_OUT)
			
			# Then: fall to target with gravity feel
			cast_tween.tween_property(bobber, "global_position", target_pos, cast_duration * 0.7).set_ease(Tween.EASE_IN)
			
			await cast_tween.finished
		
		# Landing: loosen line to passive fishing state
		line_gravity = 20.0
		line_stiffness = 0.5
		
		if bobber != null:
			bobber.angular_velocity = 0.0
			bobber.rotation = 0.0
			bobber.linear_velocity = Vector2.ZERO
			bobber.gravity_scale = 1.5  # Re-enable normal physics

		bobber_safe = false
		if bobber != null:
			bobber.sleeping = true
			var tile_map = get_parent().get_node("Ground") as TileMapLayer
			var bobber_position = tile_map.to_local(bobber.global_position)
			var data = tile_map.get_cell_tile_data(tile_map.local_to_map(bobber_position))
			var aboveground = get_parent().get_node("Aboveground") as TileMapLayer
			var aboveground2 = get_parent().get_node("Aboveground2") as TileMapLayer
			if aboveground.get_cell_source_id(tile_map.local_to_map(bobber_position)) != -1:
				data = aboveground.get_cell_tile_data(tile_map.local_to_map(bobber_position))
			if aboveground2.get_cell_source_id(tile_map.local_to_map(bobber_position)) != -1:
				data = aboveground2.get_cell_tile_data(tile_map.local_to_map(bobber_position))
			if data and data.get_custom_data("water"):
				print("Valid tile to fish on, starting timer")
				_fishing_timer(Game.Location.get(data.get_custom_data("location")))
				play_sfx("res://assets/sounds/bobberland.ogg", 1)
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
	for item in Game.bag.list:
		if item.type.category == Game.Category.FISH or item.type.category == Game.Category.JUNK:
			var mult = 1.0
			match item.data.get("stars", 0):
				1: mult = 1.25
				2: mult = 1.5
				3: mult = 2.0
			var earned = item.amount * item.type.sell_price * mult
			Game.balance += earned
			amount_earned += earned
			to_remove.append(item)
	if not to_remove.is_empty():
		for item in to_remove:
			Game.bag.remove_item(item)
	
	if amount_earned > 0.0:
		play_sfx("res://assets/sounds/cashregister.ogg", 5)
		Toast.add("Sold all your fish and earned $" + str(roundi(amount_earned)) + "!")
	_on_close_shop_pressed()
	update_catalog()

func _on_close_shop_pressed() -> void:
	var release_interact = InputEventAction.new()
	release_interact.action = "interact"
	release_interact.pressed = false
	Input.parse_input_event(release_interact)

func _on_inventory_button_pressed() -> void:
	Input.action_release("inventory")

func _on_close_inventory_pressed() -> void:
	Input.action_release("inventory")
