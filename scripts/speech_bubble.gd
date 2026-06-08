extends MarginContainer

func _ready() -> void:
	print("Speech bubble ready, size: ", size)
	$MarginContainer/Label.text = "test"

func play_line(line: String, marker: Vector2, text_speed: float = 20.0, display_duration: float = 1.5) -> void:
	$MarginContainer/Label.text = ""
	await get_tree().process_frame

	for i in range(line.length()):
		$MarginContainer/Label.text = line.substr(0, i + 1)
		await get_tree().process_frame
		global_position = Vector2(
			marker.x - (size.x * 0.1166),
			marker.y - (size.y * 0.25)
		)
		await get_tree().create_timer(1.0 / text_speed).timeout
	await get_tree().create_timer(display_duration).timeout
	queue_free()
