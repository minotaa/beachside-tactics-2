extends Node2D

const CENTER_X := 960.0
const LEFT_X := 688.0
const RIGHT_X := 1229.0
const BASE_HOOK_WIDTH := 20.0  # fallback if no Sprite2D found

@export var movement_speed: float = 1.0
@export var movement_time: float = 1.0
@export var min_distance: float = 40.0

func _ready() -> void:
	plan_move()

func _get_half_width() -> float:
	if has_node("Sprite2D") and $Sprite2D.texture != null:
		return ($Sprite2D.texture.get_width() * scale.x) / 2.0
	return (BASE_HOOK_WIDTH * scale.x) / 2.0

func start_minigame() -> void:
	var half_width = _get_half_width()
	var left = LEFT_X + half_width
	var right = RIGHT_X - half_width
	if left > right:
		left = CENTER_X
		right = CENTER_X

	position.x = randf_range(left, right)
	plan_move()

func plan_move() -> void:
	var half_width = _get_half_width()
	var left = LEFT_X + half_width
	var right = RIGHT_X - half_width
	if left > right:
		left = CENTER_X
		right = CENTER_X

	var target_x := randf_range(left, right)
	while abs(position.x - target_x) < min_distance:
		target_x = randf_range(left, right)

	move(Vector2(target_x, position.y))

func move(target: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", target, movement_speed).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	$Timer.wait_time = movement_time
	$Timer.start()

func _on_timer_timeout() -> void:
	plan_move()
