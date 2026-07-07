extends MarginContainer

var _waiting: bool = false
var _chosen: Dictionary = {}

var choice_button_scene = preload("res://scenes/ui/choice_button.tscn")

func show_choices(text: String, choices: Array, marker: Vector2, chars_per_second: float = 30.0) -> Dictionary:
	visible = false
	$VBoxContainer/MarginContainer2.visible = false

	for child in $VBoxContainer/MarginContainer2/Choices.get_children():
		child.queue_free()

	$VBoxContainer/MarginContainer/Label.text = ""
	await get_tree().process_frame

	for i in range(text.length()):
		$VBoxContainer/MarginContainer/Label.text = text.substr(0, i + 1)
		await get_tree().process_frame
		global_position = Vector2(
			marker.x - (size.x * 0.1166),
			marker.y - (size.y * 0.60)
		)
		Game.play_sfx("res://assets/sounds/a.ogg", 1, true, true, 0.9, 1.0)
		visible = true
		await get_tree().create_timer(1.0 / chars_per_second).timeout

	for i in range(choices.size()):
		var btn = choice_button_scene.instantiate()
		btn.text = "[%d] %s" % [i + 1, choices[i]["label"]]
		btn.choice = i + 1
		$VBoxContainer/MarginContainer2/Choices.add_child(btn)

	$VBoxContainer/MarginContainer2.visible = true

	_waiting = true
	_chosen = {}
	while _waiting:
		await get_tree().process_frame
		for i in range(choices.size()):
			if Input.is_action_just_pressed("ui_choice_%d" % [i + 1]):
				_chosen = choices[i]
				_waiting = false
				break

	return _chosen
