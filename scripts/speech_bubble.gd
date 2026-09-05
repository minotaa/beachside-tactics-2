extends MarginContainer

func _ready() -> void:
	$MarginContainer/Label.text = "test"

func play_line(line: String, marker: Vector2, text_speed: float = 20.0, immersive: bool = false, display_duration: float = 1.5, dialogue: bool = false) -> void:
	visible = false
	$MarginContainer/TextureRect.visible = false
	$MarginContainer/Label.text = ""
	await get_tree().process_frame
	
	$MarginContainer/TextureRect.visible = false
	$MarginContainer/Label.text = ""
	await get_tree().process_frame

	var i = 0
	while i < line.length():
		if Input.is_action_just_pressed("interact"):
			$MarginContainer/Label.text = line
			break

		if line[i] == "[":
			var close = line.find("]", i)
			if close != -1:
				var tag = line.substr(i + 1, close - i - 1).strip_edges()
				if tag.begins_with("img"):
					# Skip the entire [img...]...[/img] block
					var end_tag = line.find("[/img]", close)
					if end_tag != -1:
						i = end_tag + 6
						$MarginContainer/Label.text = line.substr(0, i)
						await get_tree().process_frame
						global_position = Vector2(
							marker.x - (size.x * 0.1166),
							marker.y - (size.y * 0.25)
						)
						visible = true
						continue

				$MarginContainer/Label.text = line.substr(0, close + 1)
				await get_tree().process_frame
				global_position = Vector2(
					marker.x - (size.x * 0.1166),
					marker.y - (size.y * 0.25)
				)
				i = close + 1
				visible = true
				continue

		$MarginContainer/Label.text = line.substr(0, i + 1)
		await get_tree().process_frame

		global_position = Vector2(
			marker.x - (size.x * 0.1166),
			marker.y - (size.y * 0.25)
		)

		visible = true

		var timer := get_tree().create_timer(1.0 / text_speed)

		while timer.time_left > 0:
			if Input.is_action_just_pressed("interact"):
				$MarginContainer/Label.text = line
				i = line.length()
				break

			await get_tree().process_frame

		if i >= line.length():
			break

		i += 1

		if dialogue:
			Game.play_sfx("res://assets/sounds/a.ogg", 1, true, true, 0.9, 1.0)

	if immersive:
		var indicator = $MarginContainer/TextureRect
		indicator.visible = true
		var tween = create_tween().set_loops()
		tween.tween_property(indicator, "modulate:a", 0.0, 0.4)
		tween.tween_property(indicator, "modulate:a", 1.0, 0.4)

		while not Input.is_action_just_pressed("interact") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			await get_tree().process_frame
	else:
		await get_tree().create_timer(display_duration).timeout

	queue_free()
