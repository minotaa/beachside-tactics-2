extends MarginContainer

func _ready() -> void:
	print("Speech bubble ready, size: ", size)
	$MarginContainer/Label.text = "test"

func play_line(line: String, marker: Vector2, text_speed: float = 20.0, immersive: bool = false, display_duration: float = 1.5) -> void:
	$MarginContainer/TextureRect.visible = false
	$MarginContainer/Label.text = ""
	await get_tree().process_frame

	var i = 0
	while i < line.length():
		if line[i] == "[":
			var close = line.find("]", i)
			if close != -1:
				$MarginContainer/Label.text = line.substr(0, close + 1)
				await get_tree().process_frame
				global_position = Vector2(
					marker.x - (size.x * 0.1166),
					marker.y - (size.y * 0.25)
				)
				i = close + 1
				continue
		$MarginContainer/Label.text = line.substr(0, i + 1)
		await get_tree().process_frame
		global_position = Vector2(
			marker.x - (size.x * 0.1166),
			marker.y - (size.y * 0.25)
		)
		await get_tree().create_timer(1.0 / text_speed).timeout
		i += 1
	
	if immersive:
		var indicator = $MarginContainer/TextureRect
		indicator.visible = true
		var tween = create_tween().set_loops()
		tween.tween_property(indicator, "modulate:a", 0.0, 0.4)
		tween.tween_property(indicator, "modulate:a", 1.0, 0.4)
		while not Input.is_action_just_pressed("interact"):
			await get_tree().process_frame
	else:
		await get_tree().create_timer(display_duration).timeout

	queue_free()
