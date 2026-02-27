extends Node2D

func _ready():
	$AnimatedSprite2D.play("default")
	$UI/Control/Label.modulate = Color(0, 0, 0, 0)
	$AnimatedSprite2D.global_position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2)
	Fade.fade_in(1.0)
	await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	var tween = get_tree().create_tween()
	tween.tween_property($AnimatedSprite2D, "position", Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2 - 60), 1.2) \
		.set_trans(Tween.TRANS_QUINT) \
		.set_ease(Tween.EASE_OUT)
	tween = get_tree().create_tween()
	tween.tween_property($UI/Control/Label, "modulate:a", 1.0, 1.5) \
			.set_trans(Tween.TRANS_QUINT) \
			.set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(2.0).timeout
	await Fade.fade_to_scene("res://scenes/game.tscn", 1.0)
