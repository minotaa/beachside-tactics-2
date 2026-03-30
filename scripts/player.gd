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


func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	# Initialize line physics
	for i in range(line_segments):
		line_points.append(Vector2.ZERO)
		line_velocities.append(Vector2.ZERO)
	
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
		return Vector2(global_position.x, global_position.y - 7.6)
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

func select_item(id: int) -> void:
	var item = Catalog.get_item(id)
	if item == null:
		Toast.add("huh?")
		return
	if item == selected_item:
		if $UI/Vendor/ItemPreview.visible:
			$UI/Vendor/ItemPreview.visible = false
		else:
			$UI/Vendor/ItemPreview.visible = true
		return
	selected_item = item
	$UI/Vendor/ItemPreview/Price.text = "Price: $" + str(roundi(item.price))
	$UI/Vendor/ItemPreview/Description.text = item.description
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
				$"UI/Vendor/TabContainer/Shop/Rods/ScrollContainer/HBoxContainer".add_child(shop_entry)
	var total = 0.0
	for item in Game.bag.list:
		if item.type.category == Game.Category.JUNK or item.type.category == Game.Category.FISH:
			total += roundi(item.type.sell_price)
			var sell_entry = preload("res://scenes/ui/sell_entry.tscn").instantiate()
			sell_entry.get_node("HBoxContainer/Label").text = str(item) + ": $" + str(roundi(item.type.sell_price)) + " = $" + str(roundi(item.type.sell_price * item.amount)) 
			sell_entry.get_node("HBoxContainer/TextureRect").texture = item.type.texture
			$UI/Vendor/TabContainer/Sell/ScrollContainer/HBoxContainer.add_child(sell_entry)
	$UI/Vendor/TabContainer/Sell/Total.text = "Total: $" + str(roundi(total))

## Discrete action handling — no delta needed here.
## UI checks are centralized so fishing input is naturally blocked.
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
	if event.is_action_released("interact"):
		if state == FishState.INACTIVE:
			if not $UI/Vendor.visible:
				for body in $Interaction.get_overlapping_areas():
					if body.is_in_group("shop"):
						body.get_node("..").start_dialogue()
						await body.get_node("..").dialogue_finished
						$UI/Vendor.visible = true
						$UI/Vendor/ItemPreview.visible = false
						$UI/Inventory.visible = false
						$UI/Main.visible = false
						update_catalog()
			else:
				$UI/Vendor.visible = false
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
			add_fish(5, 40, 2, 6)
		elif fish.difficulty == Game.Difficulty.MEDIUM:
			add_fish(10, 50, 3, 4)
		elif fish.difficulty == Game.Difficulty.HARD:
			add_fish(20, 60, 4, 3.5)
		else:
			print("Unsupported fish difficulty.")

	# Begin charging cast
	if event.is_action_pressed("fish") and state == FishState.INACTIVE and fish_control_safe:
		$FishPowerBar.visible = true
		$FishPowerBar.value = 0
		hantenjutsushiki = false

	# Release cast
	if event.is_action_released("fish") and state == FishState.INACTIVE and fish_control_safe:
		$FishPowerBar.visible = false
		hantenjutsushiki = false
		var fish_dir := last_direction
		bobber_safe = true
		play_animation(body_type + "_fish_" + fish_dir)
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
			bobber.global_position = bobber.global_position.move_toward(
				get_rod_tip(get_fishing_direction()),
				40.0 * delta
			)
			var tile_map := get_parent().get_node("Ground") as TileMapLayer
			var bobber_pos := tile_map.to_local(bobber.global_position)
			var data := tile_map.get_cell_tile_data(tile_map.local_to_map(bobber_pos))
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
			if $Minigame/Progress.value >= $Minigame/Progress.max_value:
				_on_fish_caught()
		else:
			$Minigame/Column.get_children()[0].set_vibrate(false)
			$Minigame/Progress.value -= 85 * delta
			if $Minigame/Progress.value <= 0:
				_on_fish_lost()
	else:
		$Minigame.visible = false
		for child in $Minigame/Column.get_children():
			child.queue_free()

	# Trap placement highlight
	if holding_trap:
		$Trap.show()
		var tilemap := get_parent().get_node("Ground") as TileMapLayer
		var mouse_tile := tilemap.local_to_map(tilemap.get_local_mouse_position())
		var data := tilemap.get_cell_tile_data(mouse_tile)
		if data and data.get_custom_data("water") and global_position.distance_to(tilemap.map_to_local(mouse_tile)) < BASE_TRAP_PLACE_DISTANCE:
			$Trap.global_position = tilemap.map_to_local(mouse_tile)
		else:
			$Trap.hide()
	else:
		$Trap.hide()

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
	if $FishPowerBar.visible and $UI/Inventory.visible:
		$FishPowerBar.hide()
		hantenjutsushiki = false

	move_and_slide()
	global_position = round(global_position / 2) * 2


# --- Helpers ---

## Returns true whenever UI should block all gameplay input.
func _is_ui_blocking() -> bool:
	return (
		state == FishState.REELING
		or state == FishState.FISHING
		or $UI/Vendor.visible
		or $UI/Inventory.visible
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
		if Game.bag.total_size() > Game.get_max_inventory_size():
			Toast.add("Your tackle box is full! You released the %s %s back into the water!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
		else:
			Game.bag.add_item(stack)
			Toast.add("You caught a %s %s!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
			Game.bestiary[str(stack.type.id)] = Game.bestiary.get(str(stack.type.id), 0) + stack.amount

	state = FishState.REELING_BACK
	bobber.get_node("Splashes").amount = 64
	Game.catches += 1

	var fish := Catalog.get_item(bobber.get_node("Bobber Fish").get_meta("fish_id"))
	var xp_table := {
		Game.Rarity.COMMON:    5.0,
		Game.Rarity.UNCOMMON:  10.0,
		Game.Rarity.RARE:      15.0,
		Game.Rarity.EPIC:      25.0,
		Game.Rarity.LEGENDARY: 50.0,
		Game.Rarity.MYTHIC:    125.0,
		Game.Rarity.DIVINE:    250.0,
		Game.Rarity.SUPREME:   500.0,
		Game.Rarity.SECRET:    1000.0,
	}
	Game.add_xp(xp_table.get(fish.rarity, 0.0))

func _on_fish_lost() -> void:
	state = FishState.INACTIVE
	bobber_safe = true
	play_idle_animation()
	print("Lost the fish.")
	Game.whiffs += 1
var i_float_timer = 0.0

func set_fishing_rod(id: int) -> void:
	if state != FishState.INACTIVE:
		Toast.add("You can't switch fishing rods while fishing.")
		return
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
	$UI/Inventory/Title.text = "Tackle Box (" + str(Game.bag.total_size()) + "/" + str(Game.get_max_inventory_size()) + "):"
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

	var bag = Game.bag.list.duplicate()
	bag.sort_custom(func(a, b): return a.type.rarity > b.type.rarity)
	var total = 0.0
	for item in bag:
		var inventory_entry = preload("res://scenes/ui/inventory_entry.tscn").instantiate()
		inventory_entry.get_node("Label").text = str(item.amount) + "x " + str(item.type.name)
		inventory_entry.get_node("TextureRect").texture = item.type.texture
		inventory_entry.get_node("Rarity").texture = load("res://assets/sprites/panel-" + Game.Rarity.find_key(item.type.rarity).to_lower() + ".png")
		total += item.type.sell_price
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

func near_shop() -> bool:
	for body in $Interaction.get_overlapping_areas():
		if body.is_in_group("shop"):
			return true
	return false

func _process_ui(delta: float) -> void:
	$InteractionMark.visible = false
	if Game.get_day_time() == Game.TimeOfDay.MORNING or Game.get_day_time() == Game.TimeOfDay.MIDDAY or Game.get_day_time() == Game.TimeOfDay.DAY:
		$PointLight2D.visible = false
	else:
		$PointLight2D.visible = true
	if $UI/Vendor.visible:
		var panel_width = -$UI/Vendor/TabContainer.size.x
		var offset = (panel_width / 2.0) / $Camera2D.zoom.x
		var target_pos = global_position + Vector2(offset, 0)
		$Camera2D.global_position = $Camera2D.global_position.lerp(target_pos, 5.0 * delta)
	else:
		$Camera2D.global_position = $Camera2D.global_position.lerp(global_position, 5.0 * delta)

	for child in $InteractionMark.get_children():
		child.visible = false
	for body in $Interaction.get_overlapping_areas():
		if body.is_in_group("shop"):
			$InteractionMark.visible = true
			$InteractionMark/Coin.visible = true
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
	if $Camera2D.zoom != intended_zoom:
		$Camera2D.zoom = lerp($Camera2D.zoom, intended_zoom, 0.2)
	$UI/Main/LevelBar/Label.text = "Lv." + str(Game.level) 
	$UI/Main/LevelBar.value = roundi(Game.xp)
	$UI/Main/LevelBar.max_value = roundi(Game.calculate_xp_for_level(Game.level))
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
	
	if Input.is_action_just_released("inventory") and not $UI/Vendor.visible:
		if not $UI/Inventory.visible:
			$UI/Main/Combination.hide()
			$UI/Main/LevelBar.hide()
			$UI/Main/InventoryButton.hide()
			$UI/Inventory.show()
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
			bobber.global_position += direction_to_rod * 80.0 * delta
			bobber.get_node("Bobber Fish").get_node("Sprite2D").visible = true
			bobber.get_node("Splashes").restart()
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
						Toast.add("Your tackle box is full! You released the %s %s back into the water!" % [Game.Rarity.find_key(stack.type.rarity), stack.type.name])
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
	if $UI/Vendor.visible or $UI/Inventory.visible:
		play_idle_animation()
		return
	if $Base.animation.begins_with(prefix):
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
		var base_distance = 20 + (power_normalized * 100)  # How far it goes
		
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
					var arc_offset = -sin(t * PI) * arc_height
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
			if data and data.get_custom_data("water"):
				print("Valid tile to fish on, starting timer")
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
		Toast.add("Sold all your fish and earned $" + str(roundi(amount_earned)) + "!")
	Input.action_release("interact")
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
