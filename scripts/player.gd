extends CharacterBody2D

const BASE_WALKING_SPEED := 100.0

var last_direction: String = "down"
var body_type: String = "cat0"

func play_idle_animation() -> void:
	play_animation(body_type + "_idle_" + last_direction)

func play_animation(name: String, backwards: bool = false, speed: float = 1) -> void:
	if backwards == false:
		$Base.play(name, speed)
	else:
		$Base.play(name, speed * -1, true)

func _process_input(delta: float) -> void:
	
	# Movement controls
	velocity = Input.get_vector("left", "right", "up", "down", 0.1)
	var velocity_length = velocity.length_squared()
	var is_moving = velocity_length > 0

	if is_moving:
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
		play_idle_animation()
	velocity = velocity.normalized() * BASE_WALKING_SPEED
	move_and_slide()
	global_position = round(global_position/ 2) * 2

func _physics_process(delta: float) -> void:
	_process_input(delta)
