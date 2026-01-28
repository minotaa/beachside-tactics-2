extends CharacterBody2D

const BASE_WALKING_SPEED := 100.0
const DIRECTIONS = {
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up": Vector2.UP,
	"down": Vector2.DOWN
}

var hantenjutsushiki: bool = false
var last_direction: String = "down"
var body_type: String = "cat0"
var state: FishState = FishState.INACTIVE
var bobber: RigidBody2D

var hookVelocity = 0
var hookAcceleration = .001
var hookDeceleration = .2
var maxVelocity = 2.0
var bounce = .6

enum FishState {
	FISHING,
	FOUND_FISH,
	REELING,
	REELING_BACK,
	INACTIVE
}

func _ready() -> void:
	play_idle_animation()
	
func add_fish(min_d, max_d, move_speed, move_time):
	#print("adding fish with " + str(min_d) + " " + str(max_d) + " " + str(move_speed) + " " + str(move_time))

	var f = preload("res://scenes/minigame_fish_icon.tscn").instantiate()
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

func play_animation(name: String, backwards: bool = false, speed: float = 1) -> void:
	if backwards == false:
		$Base.play(name, speed)
		if name == body_type + "_fish_down":
			$Base.position = Vector2(0, 3)
		else:
			$Base.position = Vector2(0, 0)
	else:
		$Base.play(name, speed * -1, true)

func _process_input(delta: float) -> void:
	# Movement controls
	velocity = Input.get_vector("left", "right", "up", "down", 0.1)
	if state == FishState.REELING:
		velocity = Vector2.ZERO
	var velocity_length = velocity.length_squared()
	var is_moving = velocity_length > 0

	if (Input.is_action_pressed("fish")):
		if hookVelocity > -maxVelocity:
			hookVelocity -= hookAcceleration
	else:
		if hookVelocity < maxVelocity:
			hookVelocity += hookDeceleration

	if (Input.is_action_pressed("fish")):
		hookVelocity -= .3

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
			
		# Adjust Value
		if (len($Minigame/Hook/Area2D.get_overlapping_areas()) > 0):
			#var modifier = (Inventories.fishing_rods.equipped.deerraticness * 0.01) 
			$Minigame/Progress.value += 145 * delta
			$Minigame/Column.get_children()[0].set_vibrate(true)
			Input.vibrate_handheld(10)
			if ($Minigame/Progress.value >= 999):
				print("Caught the fish.")
				if bobber != null:
					print(bobber.get_node("Bobber Fish").get_meta("fish_id")) # ACTUALLY ADD FISH TO INVENTORY
				state = FishState.REELING_BACK
				Game.catches += 1
				#_show_ui()
		else:
			$Minigame/Column.get_children()[0].set_vibrate(false)
			$Minigame/Progress.value -= 85 * delta
			if ($Minigame/Progress.value <= 0):
				state = FishState.INACTIVE
				play_idle_animation()
				print("Lost the fish.")
				Game.whiffs += 1
				#_show_ui()
	else:
		$Minigame.visible = false
		for children in $Minigame/Column.get_children():
			children.queue_free()

	if is_moving:
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
	
	if Input.is_action_just_pressed("fish") and state == FishState.FOUND_FISH:
		state = FishState.REELING
		$Minigame.visible = true
		$Minigame.position = Vector2(0, 0)
		$Minigame.scale = Vector2(0.1, 0.1)
		add_fish(30, 80, 3, 3)
	
	if Input.is_action_pressed("fish") and state == FishState.INACTIVE:
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
				
	if Input.is_action_just_released("fish") and state == FishState.INACTIVE:
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
		play_animation(body_type + "_fish_" + fish_dir)
		state = FishState.FISHING
		if bobber != null:
			bobber.queue_free()
	
	move_and_slide()
	global_position = round(global_position/ 2) * 2

func _process_ui(delta: float) -> void:
	if bobber != null:
		var line = bobber.get_node("Line2D")
		var rod_tip_global := get_rod_tip(get_fishing_direction())
		line.set_point_position(0, Vector2(0, -1.5))
		line.set_point_position(1, bobber.to_local(rod_tip_global))

		if state == FishState.REELING_BACK:
			bobber.global_position = lerp(bobber.global_position, get_rod_tip(get_fishing_direction()), 0.065)
			if round(bobber.global_position.distance_to(get_rod_tip(get_fishing_direction()))) == 0:
				state = FishState.INACTIVE
				if bobber != null:
					bobber.queue_free()
				play_idle_animation()


		$Camera2D.global_position = (bobber.global_position + global_position) / 2
		var z1 = abs(bobber.global_position.x - global_position.x) / (1280-25)
		var z2 = abs(bobber.global_position.y - global_position.y) / (720-25)
		var zoom_factor = max(max(z1, z2), 3.5)
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
	
func _fishing_timer(location: Game.Location) -> void:
	var odds = randi_range(250, 850)
	var your_odds = 0
	
	var rod_power = 0 # FIXME

	while (state == FishState.FISHING):
		print("Odds: " + str(odds) + " | Your Odds: " + str(your_odds))
		if your_odds >= odds:	
			var fish = Catalog.get_fish(location, rod_power)
			var bobber_fish = preload("res://scenes/bobber_fish.tscn").instantiate()
			bobber_fish.set_meta("fish_id", fish.id)
			bobber_fish.get_node("Sprite2D").texture = fish.texture
			if bobber != null:
				bobber.add_child(bobber_fish)
			$Exclaim.emitting = true
			state = FishState.FOUND_FISH
			await get_tree().create_timer(1.5).timeout
			if state == FishState.FOUND_FISH:
				if bobber != null and bobber_fish != null:
					bobber_fish.queue_free()
				state = FishState.FISHING
				print("User decided not to catch fish, continuing loop.")
				your_odds = 0
				odds = randi_range(250, 850)
			else:
				print("User decided to catch fish, ending loop.")
				return
			
		await get_tree().create_timer(0.75).timeout
		your_odds += randi_range(15, 25) + ($FishPowerBar.value * 0.25)
	
func _physics_process(delta: float) -> void:
	_process_input(delta)
	_process_ui(delta)

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
				if bobber != null:
					bobber.queue_free()
					bobber = null
				play_idle_animation()
