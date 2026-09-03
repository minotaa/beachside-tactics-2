extends Label

var should_fade := true

func _on_timer_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(Callable(self, "_hide"))

func _hide() -> void:
	visible = false
	should_fade = false
