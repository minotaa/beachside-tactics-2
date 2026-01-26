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

enum FishState {
	FISHING,
	FOUND_FISH,
	REELING,
	INACTIVE
}

func _ready() -> void:
	play_idle_animation()
	
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
	var velocity_length = velocity.length_squared()
	var is_moving = velocity_length > 0

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
	
	if Input.is_action_pressed("fish"):
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
				
	if Input.is_action_just_released("fish"):
		$FishPowerBar.visible = false
		$FishPowerBar.value = 0
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

		$Camera2D.global_position = (bobber.global_position + global_position) / 2
		var z1 = abs(bobber.global_position.x - global_position.x) / (1280-25)
		var z2 = abs(bobber.global_position.y - global_position.y) / (720-25)
		var zoom_factor = max(max(z1, z2), 3.5)
		$Camera2D.zoom = Vector2(zoom_factor, zoom_factor) 
	else:
		$Camera2D.global_position = lerp($Camera2D.global_position, global_position, 0.05)
		$Camera2D.zoom = lerp($Camera2D.zoom, Vector2(3.5, 3.5), 0.05)
	
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
		var power = min(100.0, $FishPowerBar.value) / 100.0

		if abs(dir.x) > 0.1:
			dir = (dir + Vector2(0, 0.15)).normalized()

		var mult = 100.0 + (power * 550.0)
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
			else:
				print("Invalid tile to fish on, stopping fishing")
				state = FishState.INACTIVE
				if bobber != null:
					bobber.queue_free()
					bobber = null
				play_idle_animation()
