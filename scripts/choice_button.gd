extends Button

var choice = 1

func _on_pressed() -> void:
	Input.action_press("ui_choice_" + choice)
