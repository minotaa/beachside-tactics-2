extends Node2D


var movement_speed = 4
var movement_time = 1

var min_distance = 10
var max_distance = 72

var min_position = 33.5
var max_position = -33.5
var is_vibrating: bool = false
var vibrate_timer: float = 0.0
var original_position: Vector2

func set_vibrate(vibrate: bool) -> void:
	is_vibrating = vibrate
	if not vibrate:
		$Sprite2D.position = original_position

func _process(delta: float) -> void:
	if is_vibrating:
		vibrate_timer += delta
		# Vibrate with small random offset
		var vibrate_strength = 0.6
		$Sprite2D.position = original_position + Vector2(
			randf_range(-vibrate_strength, vibrate_strength),
			randf_range(-vibrate_strength, vibrate_strength)
		)

func _ready():
	plan_move()
	original_position = $Sprite2D.position
	
func plan_move():
	var target = randf_range(min_position, max_position)
	while (abs(self.position.y - target) < min_distance or abs(self.position.y - target) > max_distance):
		target = randf_range(min_position, max_position)
		
	move(Vector2(self.position.x, target))

func move(target):
	var tween = create_tween()
	
	#tween.interpolate_value(self, "position", position, target, Tween.TRANS_QUINT, Tween.EASE_OUT)
	tween.tween_property(self, "position", target, movement_speed).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()
	
	$MoveTimer.set_wait_time(movement_time)
	$MoveTimer.start()

func destroy():
	get_parent().remove_child(self)
	queue_free()

func timeout():
	plan_move()
